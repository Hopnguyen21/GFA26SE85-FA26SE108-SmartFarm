import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class FarmProvider with ChangeNotifier, WidgetsBindingObserver {
  // Current active role: 'FARMER', 'OWNER', 'TECHNICIAN'
  String _currentRole = 'OWNER';

  String get currentRole => _currentRole;

  void switchRole(String role) {
    _currentRole = role;
    notifyListeners();
  }

  bool _isApiConnected = false;

  bool _isLoadingApi = false;

  Map<String, dynamic>? _farmWeather;

  Map<String, dynamic>? _me;

  /// Dữ liệu mẫu không bao giờ được hiển thị như dữ liệu thật của trang trại.
  void _clearSeedData() {
    _farmWeather = null;
    _farms.clear();
    _fields.clear();
    _zones.clear();
    _farmers.clear();
    _actuators.clear();
    _alerts.clear();
    _notifications.clear();
    _tasks.clear();
    _automationRules.clear();
    _inspectionRequests.clear();
    _equipmentOrders.clear();
    _inventoryItems.clear();
  }

  Future<void> _loadInventoryAndRules() async {
    try {
      final items = await ApiService.getInventory(_selectedFarmId);
      _inventoryItems
        ..clear()
        ..addAll(items);
    } catch (_) {
      _inventoryItems.clear();
    }
    final rules = <AutomationRuleModel>[];
    for (final z in _zones) {
      try {
        for (final r in await ApiService.getAutoRules(z.zoneId)) {
          final actuator = _actuators.where((a) => a.actuatorId == r['actuatorId']?.toString()).firstOrNull;
          rules.add(AutomationRuleModel.fromJson(r, actuatorName: actuator?.name, defaultZoneName: z.name));
        }
      } catch (_) {}
    }
    _automationRules
      ..clear()
      ..addAll(rules);
  }

  FarmProvider() {
    _clearSeedData();
    _startRealtimeSensorTimer();
    fetchFromApi();
  }

  /// Đồng bộ dữ liệu thực tế từ backend API
  Future<void> fetchFromApi() async {
    _isLoadingApi = true;
    notifyListeners();
    try {
      // 1. Lấy danh sách Farms
      _me = await ApiService.getMe();
      final apiFarms = await ApiService.getFarms();
      if (apiFarms.isEmpty) {
        _clearSeedData();
      } else {
        _isApiConnected = true;
        _farms.clear();
        _farms.addAll(apiFarms);
        // Once API data is authoritative, discard seeded hierarchy entries from demo state.
        _fields.clear();
        _zones.clear();
        if (!_farms.any((f) => f.farmId == _selectedFarmId)) {
          _selectedFarmId = _farms.first.farmId;
        }

        // 1.1. Lấy dữ liệu thời tiết theo vị trí hiệu lực của Farm
        try {
          _farmWeather = await ApiService.getFarmWeather(_selectedFarmId);
        } catch (_) {
          _farmWeather = null;
        }

        // 2. Lấy Fields của farm được chọn
        final apiFields = await ApiService.getFields(_selectedFarmId);
        _fields.addAll(apiFields);

        // 3. Lấy Zones cho từng field; an empty DB response means no zones.
        for (var field in apiFields) {
          final apiZones = await ApiService.getZones(
            field.fieldId,
            farmId: _selectedFarmId,
            farmName: currentFarm.name,
            fieldName: field.name,
          );
          _zones.addAll(apiZones);
        }

        // 3.1. Đồng bộ Thiết bị chấp hành và Cây trồng từ DB cho từng Zone
        if (_zones.isNotEmpty) {
          _actuators.clear();
          for (int i = 0; i < _zones.length; i++) {
            final z = _zones[i];
            try {
              // Lấy thiết bị chấp hành thực tế
              final zoneActs = await ApiService.getZoneActuators(z.zoneId);
              if (zoneActs.isNotEmpty) {
                _actuators.addAll(zoneActs);
              }
              // Lấy thông tin mùa vụ & cây trồng từ bối cảnh AI / DB
              final ctx = await ApiService.getAiContext(z.zoneId);
              if (ctx != null && ctx['cropName'] != null) {
                final crop = ctx['cropName'].toString();
                final stage = ctx['growthStageName']?.toString() ?? z.currentStage;
                _zones[i] = z.copyWith(
                  currentCrop: crop,
                  currentStage: stage,
                  cropContextIsDbBacked: true,
                );
              }
            } catch (_) {}
          }
        }

        // 4. Lấy danh sách Farmers
        final apiFarmers = await ApiService.getFarmers();
        _farmers.clear();
        _farmers.addAll(apiFarmers);

        // 5. Lấy danh sách Alerts
        final apiAlerts = await ApiService.getAlerts(_selectedFarmId);
        _alerts.clear();
        _alerts.addAll(apiAlerts);

        // 6. Lấy danh sách Tasks
        final apiTasks = await ApiService.getTasks(_selectedFarmId);
        _tasks.clear();
        _tasks.addAll(apiTasks.map(_withZoneName));

        await _loadInventoryAndRules();

        // 7. Lấy danh sách Thông báo hệ thống & số lượng chưa đọc
        await fetchNotifications();
      }
    } catch (e) {
      // Không có dữ liệu thật thì màn hình hiển thị trạng thái rỗng.
      _clearSeedData();
    } finally {
      _isLoadingApi = false;
      notifyListeners();
    }
  }

  Timer? _realtimeTimer;

  DateTime _lastTelemetryReceivedAt = DateTime.now();

  bool _pollInFlight = false;

  bool _lifecycleObserverAdded = false;

  // Ứng dụng ở nền thì ngừng hỏi số đo (tiết kiệm pin/dữ liệu) và hỏi lại ngay khi quay lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isApiConnected && _realtimeTimer == null) _startRealtimeSensorTimer();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _realtimeTimer?.cancel();
      _realtimeTimer = null;
    }
  }

  void _startRealtimeSensorTimer() {
    _realtimeTimer?.cancel();
    if (!_lifecycleObserverAdded) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAdded = true;
    }
    // Cập nhật vi khí hậu thực tế từ trạm cảm biến LoRa mỗi 5 giây
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Lần hỏi trước chưa xong (mạng chậm) thì bỏ lượt này, tránh dồn nhiều yêu cầu chồng nhau.
      if (_pollInFlight) return;
      // Nếu đang kết nối API, thử lấy số liệu đo từ API cho Zone hiện tại
      if (_isApiConnected && _zones.isNotEmpty) {
        _pollInFlight = true;
        try {
          final curZ = currentZone;
          final telemetry = await ApiService.getLatestTelemetry(curZ.zoneId);
          if (telemetry != null) {
            final idx = _zones.indexWhere((z) => z.zoneId == curZ.zoneId);
            if (idx != -1) {
              final hasFresh = telemetry['__hasFreshTelemetry'] == 1.0 &&
                  telemetry.containsKey('TEMPERATURE') &&
                  telemetry.containsKey('SOILMOISTURE') &&
                  telemetry.containsKey('AIRHUMIDITY') &&
                  (telemetry.containsKey('LIGHTINTENSITY') || telemetry.containsKey('LIGHT'));
              final newTemp = telemetry['TEMPERATURE'] ?? curZ.currentTemp;
              final newMoist = telemetry['SOILMOISTURE'] ?? curZ.currentSoilMoisture;
              final newHumid = telemetry['AIRHUMIDITY'] ?? curZ.currentHumidity;
              final newLux = telemetry['LIGHTINTENSITY'] ?? telemetry['LIGHT'] ?? curZ.currentLux;

              final changed = newTemp != curZ.currentTemp ||
                  newMoist != curZ.currentSoilMoisture ||
                  newHumid != curZ.currentHumidity ||
                  newLux != curZ.currentLux ||
                  hasFresh != curZ.telemetryIsFresh;
              _lastTelemetryReceivedAt = DateTime.now();
              // Số đo không đổi thì không dựng lại giao diện.
              if (changed) {
                _zones[idx] = curZ.copyWith(
                  currentTemp: newTemp,
                  currentSoilMoisture: newMoist,
                  currentHumidity: newHumid,
                  currentLux: newLux,
                  telemetryIsFresh: hasFresh,
                );
                notifyListeners();
              }
              return;
            }
          }
        } catch (_) {
        } finally {
          _pollInFlight = false;
        }
        // API connected: stale or missing readings must not be replaced by generated values.
        return;
      }

    });
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    if (_lifecycleObserverAdded) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Multi-Farm & Multi-Field Hierarchy State
  String _selectedFarmId = 'farm-01';

  String? _selectedFieldId;

  FarmModel get currentFarm => _farms.firstWhere(
    (f) => f.farmId == _selectedFarmId,
    orElse: () => _farms.isNotEmpty
        ? _farms.first
        : FarmModel(farmId: '', name: 'Chưa có nông trại', address: '', totalAreaM2: 0, latitude: 0, longitude: 0),
  );

  // Selected Zone
  int _selectedZoneIndex = 0;

  int get selectedZoneIndex => _selectedZoneIndex;

  void selectZone(int index) {
    _selectedZoneIndex = index;
    notifyListeners();
  }

  final List<FarmModel> _farms = [
    FarmModel(
      farmId: 'farm-01',
      name: 'Nông trại Thông minh Đà Lạt',
      address: 'Đường Tuyền Lâm, Phường 3, TP. Đà Lạt',
      totalAreaM2: 50000,
    ),
    FarmModel(
      farmId: 'farm-02',
      name: 'Nông trại Rau Thủy canh Đức Trọng',
      address: 'Xã Hiệp An, Huyện Đức Trọng, Lâm Đồng',
      totalAreaM2: 32000,
    ),
  ];

  final List<FieldModel> _fields = [
    FieldModel(
      fieldId: 'field-01',
      farmId: 'farm-01',
      name: 'Lô đất A1 (Khu Trồng Rau Củ Quả CNC)',
      description: 'Đất phù sa cao nguyên, lắp hệ thống tưới nhỏ giọt Israel',
      areaM2: 25000,
      polygon: [
        LatLng(11.9422, 108.4565),
        LatLng(11.9422, 108.4601),
        LatLng(11.9406, 108.4601),
        LatLng(11.9406, 108.4565),
      ],
    ),
    FieldModel(
      fieldId: 'field-02',
      farmId: 'farm-01',
      name: 'Lô đất B2 (Phân khu Ớt ngọt & Dâu tây)',
      description: 'Nhà màng màng kính cảm biến vi khí hậu tự động',
      areaM2: 18000,
      polygon: [
        LatLng(11.9402, 108.4565),
        LatLng(11.9402, 108.4601),
        LatLng(11.9386, 108.4601),
        LatLng(11.9386, 108.4565),
      ],
    ),
    FieldModel(
      fieldId: 'field-03',
      farmId: 'farm-02',
      name: 'Lô đất K1 (Khu Giàn Thủy Canh Hồi Lưu)',
      description: 'Hệ thống máng NFT hiện đại và kho dinh dưỡng trung tâm',
      areaM2: 20000,
      polygon: [
        LatLng(11.9414, 108.4569),
        LatLng(11.9414, 108.4597),
        LatLng(11.9394, 108.4597),
        LatLng(11.9394, 108.4569),
      ],
    ),
  ];

  final List<ZoneModel> _zones = [
    ZoneModel(
      zoneId: 'zone-01',
      farmId: 'farm-01',
      farmName: 'Nông trại Thông minh Đà Lạt',
      fieldId: 'field-01',
      fieldName: 'Lô đất A1 (Khu Trồng Rau Củ Quả CNC)',
      name: 'Nhà màng 01 - Cà chua Beefsteak',
      currentCrop: 'Cà chua Beefsteak F1',
      currentStage: 'Ra hoa (Flowering)',
      areaM2: 5000,
      currentSoilMoisture: 68.4,
      currentTemp: 24.8,
      currentHumidity: 71.5,
      currentLux: 740,
      assignedWorkerName: 'Trần Văn Bình',
      workerRole: 'Nông dân Thực địa (CF2)',
      polygon: [
        LatLng(11.9419, 108.4568),
        LatLng(11.9419, 108.4582),
        LatLng(11.9408, 108.4582),
        LatLng(11.9408, 108.4568),
      ],
    ),
    ZoneModel(
      zoneId: 'zone-02',
      farmId: 'farm-01',
      farmName: 'Nông trại Thông minh Đà Lạt',
      fieldId: 'field-01',
      fieldName: 'Lô đất A1 (Khu Trồng Rau Củ Quả CNC)',
      name: 'Nhà màng 02 - Dâu tây New Zealand',
      currentCrop: 'Dâu tây New Zealand',
      currentStage: 'Nuôi trái (Fruiting)',
      areaM2: 4500,
      currentSoilMoisture: 62.1,
      currentTemp: 22.3,
      currentHumidity: 75.0,
      currentLux: 820,
      assignedWorkerName: 'Trần Thị Lan',
      workerRole: 'Nông dân Thực địa (CF2)',
      polygon: [
        LatLng(11.9419, 108.4585),
        LatLng(11.9419, 108.4598),
        LatLng(11.9408, 108.4598),
        LatLng(11.9408, 108.4585),
      ],
    ),
    ZoneModel(
      zoneId: 'zone-03',
      farmId: 'farm-01',
      farmName: 'Nông trại Thông minh Đà Lạt',
      fieldId: 'field-02',
      fieldName: 'Lô đất B2 (Phân khu Ớt ngọt & Dâu tây)',
      name: 'Nhà màng 03 - Ớt chuông Sweet Pepper',
      currentCrop: 'Ớt chuông F1',
      currentStage: 'Sinh trưởng (Vegetative)',
      areaM2: 6000,
      currentSoilMoisture: 74.0,
      currentTemp: 26.5,
      currentHumidity: 65.2,
      currentLux: 950,
      assignedWorkerName: 'Phạm Minh Tuấn',
      workerRole: 'Kỹ thuật viên IoT (CF1)',
      polygon: [
        LatLng(11.9400, 108.4570),
        LatLng(11.9400, 108.4595),
        LatLng(11.9388, 108.4595),
        LatLng(11.9388, 108.4570),
      ],
    ),
    // Thêm Zone cho Farm-02 (Đức Trọng)
    ZoneModel(
      zoneId: 'zone-04',
      farmId: 'farm-02',
      farmName: 'Nông trại Rau Thủy canh Đức Trọng',
      fieldId: 'field-03',
      fieldName: 'Lô đất K1 (Khu Giàn Thủy Canh Hồi Lưu)',
      name: 'Nhà màng 04 - Xà lách Thủy Canh Batavia',
      currentCrop: 'Xà lách Batavia',
      currentStage: 'Cây non (Seedling)',
      areaM2: 4000,
      currentSoilMoisture: 80.0,
      currentTemp: 23.5,
      currentHumidity: 68.0,
      currentLux: 850,
      assignedWorkerName: 'Lê Hoàng Nam',
      workerRole: 'Nông dân Thực địa (CF2)',
    ),
    ZoneModel(
      zoneId: 'zone-05',
      farmId: 'farm-02',
      farmName: 'Nông trại Rau Thủy canh Đức Trọng',
      fieldId: 'field-03',
      fieldName: 'Lô đất K1 (Khu Giàn Thủy Canh Hồi Lưu)',
      name: 'Nhà màng 05 - Cải Kale Thủy Canh',
      currentCrop: 'Cải Kale',
      currentStage: 'Sinh trưởng (Vegetative)',
      areaM2: 3500,
      currentSoilMoisture: 78.5,
      currentTemp: 22.8,
      currentHumidity: 70.0,
      currentLux: 900,
      assignedWorkerName: 'Nguyễn Văn Phúc',
      workerRole: 'Kỹ thuật viên IoT (CF1)',
    ),
  ];

  // Danh sách Nông dân / Kỹ thuật viên (Farmer) thuộc quyền quản lý của Chủ trại (Owner)
  final List<FarmerModel> _farmers = [
    FarmerModel(
      farmerId: 'farmer-01',
      name: 'Trần Văn Bình',
      role: 'Nông dân Thực địa (CF2)',
      phone: '0912 345 678',
      email: 'binh.tran@greenvalley.agri',
      username: 'farmer_binh',
      password: '',
      farmId: 'farm-01',
      isActive: true,
      joinedDate: '15/01/2026',
      assignedZoneNames: ['Nhà màng 01 - Cà chua Beefsteak', 'Nhà màng 02 - Dưa leo Baby'],
      permissions: ['CAN_CONTROL_PUMP', 'CAN_LOG_DIARY', 'CAN_VIEW_REPORTS'],
    ),
    FarmerModel(
      farmerId: 'farmer-02',
      name: 'Trần Thị Lan',
      role: 'Nông dân Thực địa (CF2)',
      phone: '0987 654 321',
      email: 'lan.tran@greenvalley.agri',
      username: 'farmer_lan',
      password: '',
      farmId: 'farm-01',
      isActive: true,
      joinedDate: '20/01/2026',
      assignedZoneNames: ['Nhà màng 03 - Ớt chuông Sweet Pepper'],
      permissions: ['CAN_LOG_DIARY', 'CAN_VIEW_REPORTS'],
    ),
    FarmerModel(
      farmerId: 'farmer-03',
      name: 'Phạm Minh Tuấn',
      role: 'Kỹ thuật viên IoT (CF1)',
      phone: '0903 112 233',
      email: 'tuan.iot@greenvalley.agri',
      username: 'tech_tuan',
      password: '',
      farmId: 'farm-01',
      isActive: true,
      joinedDate: '05/02/2026',
      assignedZoneNames: ['Hệ thống LoRa Gateway Farm 01', 'Tủ điều khiển Actuator A1'],
      permissions: ['CAN_CONTROL_PUMP', 'CAN_CONFIG_SCHEDULE', 'CAN_MANAGE_HARDWARE'],
    ),
    FarmerModel(
      farmerId: 'farmer-04',
      name: 'Nguyễn Văn Toàn',
      role: 'Kỹ thuật viên Thổ nhưỡng',
      phone: '0934 556 778',
      email: 'toan.soil@greenvalley.agri',
      username: 'soil_toan',
      password: '',
      farmId: 'farm-01',
      isActive: true,
      joinedDate: '10/02/2026',
      assignedZoneNames: ['Phân tích NPK Lô đất 01'],
      permissions: ['CAN_LOG_DIARY', 'CAN_VIEW_REPORTS'],
    ),
    FarmerModel(
      farmerId: 'farmer-05',
      name: 'Lê Hoàng Nam',
      role: 'Nông dân Thực địa (CF2)',
      phone: '0978 998 877',
      email: 'nam.le@greenvalley.agri',
      username: 'farmer_nam',
      password: '',
      farmId: 'farm-02',
      isActive: true,
      joinedDate: '01/03/2026',
      assignedZoneNames: ['Nhà màng 04 - Xà lách Thủy Canh Batavia'],
      permissions: ['CAN_CONTROL_PUMP', 'CAN_LOG_DIARY'],
    ),
    FarmerModel(
      farmerId: 'farmer-06',
      name: 'Nguyễn Văn Phúc',
      role: 'Kỹ thuật viên IoT (CF1)',
      phone: '0945 667 889',
      email: 'phuc.iot@greenvalley.agri',
      username: 'tech_phuc',
      password: '',
      farmId: 'farm-02',
      isActive: true,
      joinedDate: '12/03/2026',
      assignedZoneNames: ['Nhà màng 05 - Cải Kale Thủy Canh'],
      permissions: ['CAN_CONTROL_PUMP', 'CAN_CONFIG_SCHEDULE', 'CAN_MANAGE_HARDWARE'],
    ),
  ];

  /// Lấy danh sách các farmer thuộc về Farm của Owner hiện tại
  List<FarmerModel> get farmersForCurrentFarm =>
      _farmers.where((f) => f.farmId == _selectedFarmId).toList();

  // Filtered zones according to currently selected farm and field
  List<ZoneModel> get zones {
    return _zones.where((z) {
      if (z.farmId != _selectedFarmId) return false;
      if (_selectedFieldId != null && z.fieldId != _selectedFieldId) return false;
      return true;
    }).toList();
  }

  ZoneModel get currentZone {
    final filtered = zones;
    if (filtered.isEmpty) {
      return ZoneModel(
        zoneId: '',
        farmId: _selectedFarmId,
        name: 'Chưa có Zone được phân quyền',
        currentCrop: 'Chưa gán cây',
        currentStage: 'Chưa có vụ đang canh tác',
        areaM2: 0,
        currentSoilMoisture: 0,
        currentTemp: 0,
        currentHumidity: 0,
        currentLux: 0,
      );
    }
    if (_selectedZoneIndex >= filtered.length) {
      _selectedZoneIndex = 0;
    }
    return filtered[_selectedZoneIndex];
  }

  final List<ActuatorModel> _actuators = [
    ActuatorModel(
      actuatorId: 'act-01',
      zoneId: 'zone-01',
      name: 'Bơm Tưới Nhỏ Giọt Zone 01',
      actuatorType: 'PUMP',
      isRunning: false,
    ),
    ActuatorModel(
      actuatorId: 'act-02',
      zoneId: 'zone-01',
      name: 'Van Solenoid Nhánh A',
      actuatorType: 'VALVE',
      isRunning: false,
    ),
    ActuatorModel(
      actuatorId: 'act-03',
      zoneId: 'zone-01',
      name: 'Quạt Thông Gió Đối Lưu',
      actuatorType: 'FAN',
      isRunning: true,
      remainingMinutes: 45,
    ),
    ActuatorModel(
      actuatorId: 'act-04',
      zoneId: 'zone-01',
      name: 'Đèn LED Quang Hợp Bổ Sung',
      actuatorType: 'GROW_LIGHT',
      isRunning: false,
    ),
    // Actuators for Zone 02
    ActuatorModel(
      actuatorId: 'act-05',
      zoneId: 'zone-02',
      name: 'Bơm Tưới Phun Sương Zone 02',
      actuatorType: 'PUMP',
      isRunning: true,
      remainingMinutes: 10,
    ),
    ActuatorModel(
      actuatorId: 'act-06',
      zoneId: 'zone-02',
      name: 'Quạt Thông Gió Làm Mát',
      actuatorType: 'FAN',
      isRunning: false,
    ),
    ActuatorModel(
      actuatorId: 'act-07',
      zoneId: 'zone-02',
      name: 'Hệ Thống Rèm Che Nắng Tự Động',
      actuatorType: 'VALVE',
      isRunning: false,
    ),
    // Actuators for Zone 03
    ActuatorModel(
      actuatorId: 'act-08',
      zoneId: 'zone-03',
      name: 'Bơm Tưới Nhỏ Giọt Zone 03',
      actuatorType: 'PUMP',
      isRunning: false,
    ),
    ActuatorModel(
      actuatorId: 'act-09',
      zoneId: 'zone-03',
      name: 'Quạt Thông Gió Công Suất Cao',
      actuatorType: 'FAN',
      isRunning: true,
      remainingMinutes: 25,
    ),
    ActuatorModel(
      actuatorId: 'act-10',
      zoneId: 'zone-03',
      name: 'Đèn LED Chiếu Sáng Ban Đêm',
      actuatorType: 'GROW_LIGHT',
      isRunning: false,
    ),
  ];

  List<ActuatorModel> get actuators => _actuators;

  final List<AlertModel> _alerts = [
    AlertModel(
      alertId: 'alt-01',
      title: 'Độ ẩm đất thấp dưới ngưỡng VietGAP',
      message: 'Zone 01 độ ẩm đất đạt 58.2% (Ngưỡng yêu cầu: 60-80%). AutoRule đã tự động kích hoạt bơm nhỏ giọt 15 phút.',
      severity: 'WARNING',
      time: '10 phút trước',
    ),
    AlertModel(
      alertId: 'alt-02',
      title: 'Cảnh báo nhiệt độ buổi trưa',
      message: 'Zone 03 nhiệt độ chạm 29.5°C vượt ngưỡng 28°C. AutoRule đã bật quạt thông gió tự động.',
      severity: 'CRITICAL',
      time: '25 phút trước',
    ),
  ];

  // ── Thông báo Hệ Thống (Notifications) ──
  final List<AppNotificationModel> _notifications = [
    const AppNotificationModel(
      notificationId: 'notif-01',
      title: 'Hệ thống vận hành bình thường',
      message: 'Các cảm biến IoT và Gateway LoRa tại phân khu Đà Lạt đang hoạt động ổn định.',
      type: 'IoT',
      severity: 'Info',
      isRead: false,
      createdAt: '15 phút trước',
    ),
    const AppNotificationModel(
      notificationId: 'notif-02',
      title: 'Cảnh báo đo lường vi khí hậu',
      message: 'Zone 01 phát hiện độ ẩm đất thấp dưới ngưỡng tối ưu 60%.',
      type: 'Alert',
      severity: 'Warning',
      isRead: false,
      createdAt: '30 phút trước',
    ),
  ];

  Future<void> fetchNotifications() async {
    try {
      final apiNotifs = await ApiService.getNotifications();
      if (apiNotifs.isNotEmpty) {
        _notifications.clear();
        _notifications.addAll(apiNotifs);
        notifyListeners();
      }
    } catch (_) {}
  }

  final List<TaskModel> _tasks = [
    TaskModel(
      taskId: 'tsk-01',
      title: 'Kiểm tra đường ống tưới nhỏ giọt Zone 01',
      zoneName: 'Nhà màng 01',
      priority: 'HIGH',
      dueDate: 'Hôm nay, 16:00',
      assignedFarmerId: 'farmer-01',
      assignedFarmerName: 'Trần Văn Bình',
      description: 'Kiểm tra áp lực ống nhánh và vệ sinh màng lọc cặn đầu nguồn.',
    ),
    TaskModel(
      taskId: 'tsk-02',
      title: 'Tỉa lá già và chồi nách cây Cà chua',
      zoneName: 'Nhà màng 01',
      priority: 'MEDIUM',
      dueDate: 'Ngày mai, 08:30',
      assignedFarmerId: 'farmer-01',
      assignedFarmerName: 'Trần Văn Bình',
      description: 'Tỉa bớt cành nhánh phía dưới gốc để thông thoáng tán lá, phòng ngừa nấm.',
    ),
    TaskModel(
      taskId: 'tsk-03',
      title: 'Châm phân bón N-P-K vi lượng theo quy chuẩn',
      zoneName: 'Nhà màng 02',
      priority: 'HIGH',
      dueDate: 'Ngày 28/09, 09:00',
      assignedFarmerId: 'farmer-04',
      assignedFarmerName: 'Nguyễn Văn Toàn',
      description: 'Pha theo tỷ lệ dinh dưỡng EC 1.8 mS/cm, kiểm tra pH trước khi cấp vào đường ống.',
    ),
  ];

  TaskModel _withZoneName(TaskModel t) {
    final zone = _zones.where((z) => z.zoneId == t.zoneId).firstOrNull;
    return zone == null
        ? t
        : TaskModel(
            taskId: t.taskId,
            title: t.title,
            zoneName: zone.name,
            priority: t.priority,
            dueDate: t.dueDate,
            assignedFarmerName: t.assignedFarmerName,
            assignedFarmerId: t.assignedFarmerId,
            description: t.description,
            isCompleted: t.isCompleted,
            status: t.status,
            zoneId: t.zoneId,
            assignments: t.assignments,
          );
  }

  /// Thao tác thật trên công việc. Trả về thông báo lỗi, hoặc null khi thành công.
  Future<String?> performTaskAction(
    String taskId,
    String action, {
    String? result,
    String? failureReason,
    int? progressPercent,
    String? farmerId,
  }) async {
    try {
      final updated = await ApiService.updateTaskAction(_selectedFarmId, taskId, {
        'action': action,
        if (result != null) 'result': result,
        if (failureReason != null) 'failureReason': failureReason,
        if (progressPercent != null) 'progressPercent': progressPercent,
        if (farmerId != null) 'farmerId': farmerId,
      });
      final idx = _tasks.indexWhere((t) => t.taskId == taskId);
      if (idx != -1) _tasks[idx] = _withZoneName(updated);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  final List<ChatMessageModel> _chatMessages = [
    ChatMessageModel(
      id: 'msg-01',
      text:
          'Xin chào! Tôi là Trợ lý Nông học AI SmartFarm, được hỗ trợ bởi Gemini + dữ liệu cảm biến thực tế.\n\nHỏi tôi về độ ẩm, bệnh lá, lịch tưới, hoặc bất kỳ vấn đề nào về cây trồng theo chuẩn VietGAP!',
      isUser: false,
      time: '00:00',
    ),
  ];

  List<ChatMessageModel> get chatMessages => _chatMessages;

  /// Đặt lại toàn bộ danh sách tin nhắn (khôi phục từ API)
  void setChatMessages(List<ChatMessageModel> msgs) {
    _chatMessages.clear();
    _chatMessages.addAll(msgs);
    notifyListeners();
  }

  /// Thêm tin nhắn vào chat (dùng bởi AiAssistantScreen sau khi gọi API thực)
  void addChatMessage(ChatMessageModel msg) {
    _chatMessages.add(msg);
    notifyListeners();
  }

  void refreshChatState() {
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // Vấn đề 4: Device Health (Timeout-based)
  // ─────────────────────────────────────────
  final List<DeviceHealthModel> deviceHealthList = [
    DeviceHealthModel(
      nodeId: 'gw-001',
      name: 'Gateway LoRa Nhà màng 01',
      type: 'GATEWAY',
      lastSeenAt: DateTime.now().subtract(const Duration(seconds: 45)),
      expectedIntervalSeconds: 60,
      signalRssi: -68.0,
      batteryPercent: 100,
    ),
    DeviceHealthModel(
      nodeId: 'node-01',
      name: 'Sensor Node Zone 01',
      type: 'SENSOR_NODE',
      lastSeenAt: DateTime.now().subtract(const Duration(seconds: 12)),
      expectedIntervalSeconds: 30,
      signalRssi: -72.0,
      batteryPercent: 87,
    ),
    DeviceHealthModel(
      nodeId: 'node-02',
      name: 'Sensor Node Zone 02',
      type: 'SENSOR_NODE',
      lastSeenAt: DateTime.now().subtract(const Duration(minutes: 8)),
      expectedIntervalSeconds: 300,
      signalRssi: -85.0,
      batteryPercent: 54,
    ),
    DeviceHealthModel(
      nodeId: 'node-act-01',
      name: 'Actuator Node Bơm Zone 01',
      type: 'ACTUATOR_NODE',
      lastSeenAt: DateTime.now().subtract(const Duration(hours: 2)),
      expectedIntervalSeconds: 300,
      signalRssi: -91.0,
      batteryPercent: 23,
    ),
  ];

  // ─────────────────────────────────────────
  // Automation Rules & Schedules State
  // ─────────────────────────────────────────
  final List<AutomationRuleModel> _automationRules = [
    AutomationRuleModel(
      ruleId: 'rule-01',
      name: 'Tự động bù ẩm đất khi khô hạn',
      zoneName: 'Nhà màng 01 - Cà chua',
      parameterCode: 'Độ ẩm đất (SOIL_MOISTURE)',
      operator: '<',
      thresholdValue: 60.0,
      actuatorName: 'Bơm Tưới Nhỏ Giọt',
      actionType: 'BẬT (ON)',
      actionDurationMinutes: 15,
      isActive: true,
    ),
    AutomationRuleModel(
      ruleId: 'rule-02',
      name: 'Thông gió giải nhiệt trưa hè',
      zoneName: 'Nhà màng 01 - Cà chua',
      parameterCode: 'Nhiệt độ không khí (AIR_TEMP)',
      operator: '>',
      thresholdValue: 30.0,
      actuatorName: 'Quạt Thông Gió Đối Lưu',
      actionType: 'BẬT (ON)',
      actionDurationMinutes: 30,
      isActive: true,
    ),
    AutomationRuleModel(
      ruleId: 'rule-03',
      name: 'Ngắt tưới khi đất quá ẩm',
      zoneName: 'Nhà màng 01 - Cà chua',
      parameterCode: 'Độ ẩm đất (SOIL_MOISTURE)',
      operator: '>=',
      thresholdValue: 80.0,
      actuatorName: 'Bơm Tưới Nhỏ Giọt',
      actionType: 'TẮT (OFF)',
      actionDurationMinutes: 0,
      isActive: true,
    ),
    AutomationRuleModel(
      ruleId: 'rule-04',
      name: 'Chiếu sáng bù quang kỳ mùa mưa',
      zoneName: 'Nhà màng 02 - Dâu tây',
      parameterCode: 'Cường độ sáng (LIGHT_LUX)',
      operator: '<',
      thresholdValue: 500.0,
      actuatorName: 'Đèn LED Quang Hợp',
      actionType: 'BẬT (ON)',
      actionDurationMinutes: 60,
      isActive: false,
    ),
  ];

  // ─────────────────────────────────────────
  // Quản lý Yêu cầu Kiểm tra Thực địa (Field Inspections)
  // ─────────────────────────────────────────
  final List<FieldInspectionRequestModel> _inspectionRequests = [
    const FieldInspectionRequestModel(
      requestId: 'REQ-2026-001',
      farmId: 'farm-01',
      farmName: 'Nông trại Thông minh Đà Lạt',
      zoneId: 'zone-01',
      zoneName: 'Nhà màng 01 - Cà chua Beefsteak',
      areaM2: 5000,
      cropName: 'Cà chua Beefsteak F1',
      estimatedCostVND: 38500000,
      contactName: 'Lê Văn An (Chủ trại)',
      contactPhone: '0908 123 456',
      preferredDate: '10/10/2026 (08:30)',
      note: 'Khảo sát thực địa đo đạc áp lực đường ống và lắp thêm 1 trạm LoRa Node đa tầng.',
      status: 'APPROVED',
      createdAt: '01/10/2026',
      assignedTechnicianName: 'Trần Minh Trí',
      technicianPhone: '0909 888 777',
      adminNote: 'Admin đã duyệt: Điều Kỹ thuật viên Trí chuẩn bị 1 bộ Gateway dự phòng và máy đo áp lực.',
    ),
  ];

  // ─────────────────────────────────────────
  // Quản lý Đơn Hàng Mua Sắm & Lắp Đặt Thiết Bị (Cọc 30%)
  // ─────────────────────────────────────────
  final List<EquipmentOrderModel> _equipmentOrders = [
    EquipmentOrderModel(
      orderId: 'ORD-2026-001',
      requestId: 'REQ-2026-001',
      farmId: 'farm-01',
      farmName: 'Nông trại Thông minh Đà Lạt',
      zoneId: 'zone-01',
      zoneName: 'Nhà màng 01 - Cà chua Beefsteak',
      items: [
        const ZoneEquipmentItem(
          name: 'Trạm LoRa Sensor Node 4-trong-1',
          category: 'SENSOR',
          quantity: 4,
          unit: 'Bộ',
          unitPriceVND: 2450000,
          description: 'Đo ẩm đất 3 độ sâu, nhiệt ẩm không khí, quang kỳ PAR',
        ),
        const ZoneEquipmentItem(
          name: 'Máy bơm tưới tăng áp tự động 1.5HP',
          category: 'ACTUATOR',
          quantity: 2,
          unit: 'Chiếc',
          unitPriceVND: 3800000,
          description: 'Lưu lượng 12-15 m³/h, tích hợp khởi động mềm',
        ),
        const ZoneEquipmentItem(
          name: 'Van điện từ Solenoid DC 24V',
          category: 'ACTUATOR',
          quantity: 7,
          unit: 'Chiếc',
          unitPriceVND: 420000,
          description: 'Chia phân khu tưới luân phiên chống tụt áp',
        ),
        const ZoneEquipmentItem(
          name: 'Tủ điều khiển IoT Actuator Driver Box',
          category: 'NETWORK',
          quantity: 1,
          unit: 'Tủ',
          unitPriceVND: 4500000,
          description: 'Vỏ chống nước IP66, kết nối LoRa/RS485 Modbus',
        ),
      ],
      totalAmountVND: 24840000,
      depositAmountVND: 7452000, // 30%
      remainingAmountVND: 17388000, // 70%
      status: 'AWAITING_PAYMENT',
      createdAt: '02/10/2026',
    ),
  ];

  // ─────────────────────────────────────────
  // KHO VẬT TƯ & PHÂN BÓN NÔNG NGHIỆP (INVENTORY)
  // ─────────────────────────────────────────
  final List<MaterialInventoryModel> _inventoryItems = [
    const MaterialInventoryModel(
      inventoryId: 'inv-01',
      farmId: 'farm-01',
      materialName: 'Phân bón NPK 16-16-8 Hòa tan',
      code: 'MAT-NPK-01',
      category: 'FERTILIZER',
      quantity: 450,
      unit: 'kg',
      minimumStock: 100,
      storageLocation: 'Kho Vật tư A1 (Trại Đà Lạt)',
      updatedAt: '2026-09-20',
    ),
    const MaterialInventoryModel(
      inventoryId: 'inv-02',
      farmId: 'farm-01',
      materialName: 'Hạt giống Cà chua Beefsteak F1',
      code: 'MAT-SEED-TOM',
      category: 'SEED',
      quantity: 1200,
      unit: 'hạt',
      minimumStock: 500,
      storageLocation: 'Tủ lạnh bảo quản S1',
      updatedAt: '2026-09-18',
    ),
    const MaterialInventoryModel(
      inventoryId: 'inv-03',
      farmId: 'farm-01',
      materialName: 'Chế phẩm Sinh học Trichoderma',
      code: 'MAT-BIO-TRI',
      category: 'PESTICIDE',
      quantity: 25,
      unit: 'lít',
      minimumStock: 30,
      storageLocation: 'Kho Hóa chất B2',
      updatedAt: '2026-09-15',
    ),
    const MaterialInventoryModel(
      inventoryId: 'inv-04',
      farmId: 'farm-01',
      materialName: 'Dây tưới nhỏ giọt bù áp 16mm (cuộn 500m)',
      code: 'MAT-IRR-DRIP',
      category: 'EQUIPMENT',
      quantity: 8,
      unit: 'cuộn',
      minimumStock: 10,
      storageLocation: 'Kho Thiết bị C3',
      updatedAt: '2026-09-22',
    ),
    const MaterialInventoryModel(
      inventoryId: 'inv-05',
      farmId: 'farm-01',
      materialName: 'Đầu béc phun sương 4 hướng chống nhỏ giọt',
      code: 'MAT-IRR-NOZZLE',
      category: 'EQUIPMENT',
      quantity: 120,
      unit: 'cái',
      minimumStock: 50,
      storageLocation: 'Kệ phụ tùng C1',
      updatedAt: '2026-09-25',
    ),
  ];
}



