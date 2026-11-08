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

  DateTime get lastTelemetryReceivedAt => _lastTelemetryReceivedAt;

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

  // null = all fields in the selected farm

  String get selectedFarmId => _selectedFarmId;

  String? get selectedFieldId => _selectedFieldId;

  FarmModel get currentFarm => _farms.firstWhere(
    (f) => f.farmId == _selectedFarmId,
    orElse: () => _farms.isNotEmpty
        ? _farms.first
        : FarmModel(farmId: '', name: 'Chưa có nông trại', address: '', totalAreaM2: 0, latitude: 0, longitude: 0),
  );

  void selectFarm(String farmId) {
    if (_selectedFarmId != farmId) {
      _selectedFarmId = farmId;
      _selectedFieldId = null; // reset field filter when changing farm
      _selectedZoneIndex = 0;
      notifyListeners();
      if (_isApiConnected) {
        fetchFromApi();
      }
    }
  }

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

  List<FarmModel> get farms => _farms;

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

  List<FieldModel> get fields => _fields;

  List<FieldModel> get fieldsForCurrentFarm =>
      _fields.where((f) => f.farmId == _selectedFarmId).toList();

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

  List<FarmerModel> get allFarmers => _farmers;

  /// Lấy danh sách các farmer thuộc về Farm của Owner hiện tại
  List<FarmerModel> get farmersForCurrentFarm =>
      _farmers.where((f) => f.farmId == _selectedFarmId).toList();

  /// Thêm tài khoản Farmer mới
  void addFarmer({
    required String name,
    required String role,
    required String phone,
    required String email,
    required String username,
    required String password,
    String? farmId,
    List<String> assignedZoneNames = const [],
    List<String> permissions = const ['CAN_CONTROL_PUMP', 'CAN_LOG_DIARY'],
  }) {
    final newId = 'farmer-0${_farmers.length + 1}';
    final targetFarmId = farmId ?? _selectedFarmId;
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    _farmers.add(
      FarmerModel(
        farmerId: newId,
        name: name,
        role: role,
        phone: phone,
        email: email,
        username: username,
        password: password,
        farmId: targetFarmId,
        isActive: true,
        joinedDate: dateStr,
        assignedZoneNames: assignedZoneNames,
        permissions: permissions,
      ),
    );
    notifyListeners();
  }

  /// Cập nhật thông tin / phân công của Farmer
  void updateFarmer(FarmerModel updated) {
    final idx = _farmers.indexWhere((f) => f.farmerId == updated.farmerId);
    if (idx != -1) {
      _farmers[idx] = updated;
      notifyListeners();
    }
  }

  /// Khóa hoặc mở khóa tài khoản Farmer
  void toggleFarmerStatus(String farmerId) {
    final idx = _farmers.indexWhere((f) => f.farmerId == farmerId);
    if (idx != -1) {
      final current = _farmers[idx];
      _farmers[idx] = current.copyWith(isActive: !current.isActive);
      notifyListeners();
    }
  }

  /// Reset mật khẩu tài khoản Farmer
  void resetFarmerPassword(String farmerId, String newPassword) {
    final idx = _farmers.indexWhere((f) => f.farmerId == farmerId);
    if (idx != -1) {
      final current = _farmers[idx];
      _farmers[idx] = current.copyWith(password: newPassword);
      notifyListeners();
    }
  }

  /// Xóa tài khoản Farmer
  void deleteFarmer(String farmerId) {
    _farmers.removeWhere((f) => f.farmerId == farmerId);
    notifyListeners();
  }

  // All zones
  List<ZoneModel> get allZones => _zones;

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

  void addNewZone({
    required String name,
    required double areaM2,
    required String cropProfileId,
    String? assignedWorkerName,
    String? workerRole,
    String? customFarmId,
    String? customFieldId,
    List<LatLng>? polygon,
  }) {
    final profile = defaultCropProfiles.firstWhere(
      (p) => p.cropId == cropProfileId,
      orElse: () => defaultCropProfiles.first,
    );

    final newZoneIndex = _zones.length + 1;
    final zId = 'zone-0$newZoneIndex';

    final firstStage = profile.growthStages.first;

    final fId = customFarmId ?? _selectedFarmId;
    final farmObj = _farms.firstWhere((f) => f.farmId == fId, orElse: () => _farms.first);
    final fieldList = _fields.where((f) => f.farmId == fId).toList();
    final fldId = customFieldId ?? (fieldList.isNotEmpty ? fieldList.first.fieldId : 'field-01');
    final fieldObj = _fields.firstWhere((f) => f.fieldId == fldId, orElse: () => fieldList.isNotEmpty ? fieldList.first : _fields.first);

    final newZone = ZoneModel(
      zoneId: zId,
      farmId: fId,
      farmName: farmObj.name,
      fieldId: fldId,
      fieldName: fieldObj.name,
      name: name,
      currentCrop: '${profile.name} (${profile.variety.split(' / ').first})',
      currentStage: firstStage.name,
      areaM2: areaM2,
      currentSoilMoisture: firstStage.requirements.soilMoistureMin + 5.0,
      currentTemp: (firstStage.requirements.tempMin + firstStage.requirements.tempMax) / 2,
      currentHumidity: (firstStage.requirements.humidityMin + firstStage.requirements.humidityMax) / 2,
      currentLux: 750,
      assignedWorkerName: assignedWorkerName ?? 'Chưa phân công',
      workerRole: workerRole ?? 'Nông dân Thực địa',
      polygon: polygon,
    );

    _zones.add(newZone);

    // Bổ sung thiết bị chấp hành mẫu cho zone mới
    _actuators.addAll([
      ActuatorModel(
        actuatorId: 'act-new-$zId-1',
        zoneId: zId,
        name: 'Bơm Tưới Nhỏ Giọt $name',
        actuatorType: 'PUMP',
        isRunning: false,
      ),
      ActuatorModel(
        actuatorId: 'act-new-$zId-2',
        zoneId: zId,
        name: 'Quạt Thông Gió Đối Lưu $name',
        actuatorType: 'FAN',
        isRunning: false,
      ),
    ]);


    // Tự động chọn Zone vừa tạo
    _selectedZoneIndex = _zones.length - 1;
    notifyListeners();
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

  List<AlertModel> get alerts => _alerts;

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

  /// Giao việc qua API. Trả về thông báo lỗi, hoặc null khi thành công; không tạo công việc cục bộ.
  Future<String?> addTask({
    required String title,
    required String zoneName,
    required String priority,
    required String dueDate,
    String? assignedFarmerId,
    String? assignedFarmerName,
    String? description,
    String? zoneId,
    DateTime? dueAt,
  }) async {
    if (assignedFarmerId == null || zoneId == null) return 'Hãy chọn Zone và nhân công.';
    try {
      final created = await ApiService.createTask(_selectedFarmId, {
        'zoneId': zoneId,
        'title': title,
        'description': description ?? '',
        'dueAtUtc': (dueAt ?? DateTime.now().add(const Duration(days: 1))).toUtc().toIso8601String(),
        'farmerIds': [assignedFarmerId],
      });
      _tasks.insert(0, _withZoneName(created));
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
  // Schedules (lịch tưới) – Seeded + loaded from API
  // ─────────────────────────────────────────
  List<ScheduleModel> _schedules = [
    ScheduleModel(
      scheduleId: 'sch-01',
      name: 'Tưới dinh dưỡng nhỏ giọt buổi sáng',
      zoneName: 'Nhà màng 01 - Cà chua',
      actuatorName: 'Bơm Tưới Nhỏ Giọt',
      startTime: '06:30',
      durationMinutes: 20,
      daysOfWeek: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      isActive: true,
      isEnabled: true,
    ),
    ScheduleModel(
      scheduleId: 'sch-02',
      name: 'Tưới dặm hạ nhiệt đầu giờ chiều',
      zoneName: 'Nhà màng 01 - Cà chua',
      actuatorName: 'Bơm Tưới Nhỏ Giọt',
      startTime: '14:00',
      durationMinutes: 10,
      daysOfWeek: ['T2', 'T4', 'T6'],
      isActive: true,
      isEnabled: true,
    ),
    ScheduleModel(
      scheduleId: 'sch-03',
      name: 'Lịch quạt thông khí định kỳ đêm',
      zoneName: 'Nhà màng 02 - Dâu tây',
      actuatorName: 'Quạt Thông Gió Đối Lưu',
      startTime: '22:00',
      durationMinutes: 45,
      daysOfWeek: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      isActive: false,
      isEnabled: false,
    ),
  ];

  List<ScheduleModel> get schedules => _schedules;

  void toggleSchedule(String scheduleId) {
    final idx = _schedules.indexWhere((s) => s.scheduleId == scheduleId);
    if (idx != -1) {
      final sch = _schedules[idx];
      sch.isActive = !sch.isActive;
      notifyListeners();
      // Sync with backend asynchronously
      final targetZoneId = sch.zoneId.isNotEmpty ? sch.zoneId : currentZone.zoneId;
      ApiService.toggleSchedule(
        scheduleId,
        sch.isActive,
        zoneId: targetZoneId,
        name: sch.name,
        cronExpression: sch.cronExpression,
        durationSeconds: sch.durationSeconds > 0 ? sch.durationSeconds : (sch.durationMinutes * 60),
        enableRainDelay: sch.enableRainDelay,
        rainThresholdPercent: sch.rainThresholdPercent,
      );
    }
  }

  void addSchedule(ScheduleModel schedule) {
    _schedules.insert(0, schedule);
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // Vấn đề 6: Default Crop Profiles (Seed Data)
  // ─────────────────────────────────────────
  String? _appliedCropId;

  void applyCropProfile(String cropId, {String? targetZoneId, String? farmingSeasonId}) {
    final profile = defaultCropProfiles.firstWhere((p) => p.cropId == cropId);
    for (final p in defaultCropProfiles) {
      p.isApplied = p.cropId == cropId;
    }
    _appliedCropId = cropId;

    final zId = targetZoneId ?? currentZone.zoneId;
    final targetZone = _zones.firstWhere((z) => z.zoneId == zId);

    targetZone.currentCrop = '${profile.name} (${profile.variety.split(' / ').first})';
    if (farmingSeasonId != null) {
      targetZone.farmingSeasonId = farmingSeasonId;
    }
    if (farmingSeasonId != null) {
      targetZone.farmingSeasonId = farmingSeasonId;
    }
    targetZone.currentStage = profile.growthStages.first.name;


    notifyListeners();
  }

  final List<DefaultCropProfile> defaultCropProfiles = [
    // ── CÀ CHUA ──
    DefaultCropProfile(
      cropId: 'crop-tomato',
      name: 'Cà Chua',
      nameEn: 'Tomato',
      variety: 'Beefsteak F1 / Cherry / Bi',
      emoji: '🍅',
      standardType: 'VietGAP',
      totalCycleDays: 90,
      description: 'Cây trồng phổ biến nhất tại Đà Lạt. Thích hợp khí hậu mát mẻ, yêu cầu ánh sáng cao và thoát nước tốt.',
      origin: 'Nam Mỹ – Được trồng rộng rãi tại Lâm Đồng, Đà Lạt',
      difficulty: 'TRUNG BÌNH',
      suitableRegion: 'Cao nguyên Lâm Đồng, Đà Lạt',
      compatibleActuators: ['PUMP', 'FAN', 'GROW_LIGHT'],
      commonPests: ['Sâu xanh bướm trắng', 'Bệnh phấn trắng', 'Rệp sáp', 'Nấm thán thư'],
      growthStages: [
        GrowthStageProfile(
          stageId: 'tomato-s1',
          name: 'Nảy mầm & Cây con',
          nameEn: 'Germination & Seedling',
          startDayFromPlanting: 0,
          endDayFromPlanting: 21,
          description: 'Giai đoạn quan trọng nhất. Giữ ẩm đều, tránh úng nước. Ánh sáng 12-14h/ngày.',
          iconEmoji: '🌱',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 80,
            tempMin: 20, tempMax: 25,
            humidityMin: 70, humidityMax: 85,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Gieo hạt vào khay ươm', 'Tưới nhẹ 2 lần/ngày', 'Bổ sung ánh sáng LED', 'Theo dõi độ ẩm 65-80%'],
        ),
        GrowthStageProfile(
          stageId: 'tomato-s2',
          name: 'Sinh trưởng thân lá',
          nameEn: 'Vegetative Growth',
          startDayFromPlanting: 21,
          endDayFromPlanting: 45,
          description: 'Cây phát triển nhanh, cần nhiều dinh dưỡng N-P-K. Bấm ngọn chính.',
          iconEmoji: '🌿',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 60, soilMoistureMax: 75,
            tempMin: 22, tempMax: 28,
            humidityMin: 65, humidityMax: 80,
            irrigationDurationMin: 15,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Bón phân N cao (đạm)', 'Bấm ngọn cành phụ', 'Buộc cây vào dây', 'Phun phòng bệnh nấm'],
        ),
        GrowthStageProfile(
          stageId: 'tomato-s3',
          name: 'Ra hoa & Thụ phấn',
          nameEn: 'Flowering',
          startDayFromPlanting: 45,
          endDayFromPlanting: 65,
          description: 'Giảm độ ẩm không khí để hạn chế nấm. Rung cây nhẹ để hỗ trợ thụ phấn.',
          iconEmoji: '🌸',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 75,
            tempMin: 20, tempMax: 27,
            humidityMin: 55, humidityMax: 70,
            irrigationDurationMin: 12,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Giảm tưới, tăng thoát khí', 'Rung thân cây hỗ trợ thụ phấn', 'Bổ sung P-K (lân-kali)', 'Bật quạt thông gió 14:00-16:00'],
        ),
        GrowthStageProfile(
          stageId: 'tomato-s4',
          name: 'Đậu quả & Nuôi trái',
          nameEn: 'Fruit Development',
          startDayFromPlanting: 65,
          endDayFromPlanting: 85,
          description: 'Tưới đều đặn, không để đất khô đột ngột gây nứt quả. Tăng K bổ sung.',
          iconEmoji: '🍅',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 62, soilMoistureMax: 75,
            tempMin: 18, tempMax: 26,
            humidityMin: 60, humidityMax: 75,
            irrigationDurationMin: 15,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Tưới đều không để khô đột ngột', 'Bổ sung Kali Canxi chống nứt quả', 'Loại bỏ lá già phía dưới', 'Theo dõi màu sắc quả'],
        ),
        GrowthStageProfile(
          stageId: 'tomato-s5',
          name: 'Thu hoạch',
          nameEn: 'Harvest',
          startDayFromPlanting: 85,
          endDayFromPlanting: 90,
          description: 'Thu hoạch khi quả chuyển màu đỏ 70-80%. Hái vào sáng sớm khi nhiệt độ mát.',
          iconEmoji: '✂️',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 55, soilMoistureMax: 70,
            tempMin: 18, tempMax: 26,
            humidityMin: 55, humidityMax: 70,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 1,
          ),
          keyActivities: ['Thu hoạch lúc 6:00-8:00 sáng', 'Phân loại theo kích thước', 'Bảo quản 10-12°C', 'Dọn vệ sinh nhà màng sau vụ'],
        ),
      ],
    ),

    // ── DƯA CHUỘT / DƯA LEO ──
    DefaultCropProfile(
      cropId: 'crop-cucumber',
      name: 'Dưa Leo',
      nameEn: 'Cucumber',
      variety: 'Caroui / Kim Cô Nương F1',
      emoji: '🥒',
      standardType: 'VietGAP',
      totalCycleDays: 60,
      description: 'Cây ngắn ngày, sinh trưởng nhanh. Cần nhiều nước và dinh dưỡng. Phù hợp trồng nhà màng.',
      origin: 'Châu Á nhiệt đới – Thích nghi tốt ở miền Nam Việt Nam',
      difficulty: 'DỄ',
      suitableRegion: 'Toàn quốc, đặc biệt ĐBSCL và Đông Nam Bộ',
      compatibleActuators: ['PUMP', 'FAN'],
      commonPests: ['Bọ trĩ', 'Bệnh phấn trắng', 'Sương mai', 'Nhện đỏ'],
      growthStages: [
        GrowthStageProfile(
          stageId: 'cucumber-s1',
          name: 'Nảy mầm',
          nameEn: 'Germination',
          startDayFromPlanting: 0,
          endDayFromPlanting: 7,
          description: 'Hạt nảy mầm trong 3-5 ngày. Cần nhiệt độ ấm và độ ẩm cao.',
          iconEmoji: '🌱',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 70, soilMoistureMax: 85,
            tempMin: 25, tempMax: 32,
            humidityMin: 75, humidityMax: 90,
            irrigationDurationMin: 8,
            irrigationFrequencyPerDay: 3,
          ),
          keyActivities: ['Gieo hạt ngâm ủ trước 8h', 'Giữ ẩm đều 70-85%', 'Nhiệt độ 25-32°C'],
        ),
        GrowthStageProfile(
          stageId: 'cucumber-s2',
          name: 'Sinh trưởng thân lá',
          nameEn: 'Vegetative',
          startDayFromPlanting: 7,
          endDayFromPlanting: 25,
          description: 'Cây leo dây nhanh. Cần giàn và nhiều dinh dưỡng đạm.',
          iconEmoji: '🌿',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 80,
            tempMin: 22, tempMax: 30,
            humidityMin: 70, humidityMax: 85,
            irrigationDurationMin: 12,
            irrigationFrequencyPerDay: 3,
          ),
          keyActivities: ['Cắm giàn leo', 'Bón đạm N cao', 'Tỉa nhánh phụ sớm', 'Tưới 3 lần/ngày'],
        ),
        GrowthStageProfile(
          stageId: 'cucumber-s3',
          name: 'Ra hoa & Nuôi quả',
          nameEn: 'Flowering & Fruiting',
          startDayFromPlanting: 25,
          endDayFromPlanting: 55,
          description: 'Giai đoạn cho năng suất. Tưới đều tránh sốc nước gây đắng quả.',
          iconEmoji: '🌼',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 68, soilMoistureMax: 80,
            tempMin: 22, tempMax: 28,
            humidityMin: 65, humidityMax: 80,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 3,
          ),
          keyActivities: ['Bổ sung K-Ca', 'Tưới đều không để đất khô', 'Thu hoạch quả đạt kích thước', 'Phòng bệnh phấn trắng'],
        ),
        GrowthStageProfile(
          stageId: 'cucumber-s4',
          name: 'Thu hoạch',
          nameEn: 'Harvest',
          startDayFromPlanting: 55,
          endDayFromPlanting: 60,
          description: 'Thu hoạch khi quả dài 15-20cm. Thu 2-3 ngày/lần.',
          iconEmoji: '✂️',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 60, soilMoistureMax: 75,
            tempMin: 20, tempMax: 28,
            humidityMin: 60, humidityMax: 78,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Thu hoạch 2-3 ngày/lần', 'Cắt bằng kéo không vặn', 'Bảo quản mát 10-15°C'],
        ),
      ],
    ),

    // ── ỚT CHUÔNG ──
    DefaultCropProfile(
      cropId: 'crop-bellpepper',
      name: 'Ớt Chuông',
      nameEn: 'Bell Pepper',
      variety: 'Sweet Pepper F1 / Yolo Wonder',
      emoji: '🫑',
      standardType: 'VietGAP',
      totalCycleDays: 120,
      description: 'Cây trồng giá trị cao, chu kỳ dài. Cần quản lý vi khí hậu nghiêm ngặt để đạt chuẩn xuất khẩu.',
      origin: 'Trung Mỹ – Thích hợp cao nguyên mát mẻ Việt Nam',
      difficulty: 'KHÓ',
      suitableRegion: 'Đà Lạt, Mộc Châu, Sa Pa',
      compatibleActuators: ['PUMP', 'FAN', 'GROW_LIGHT'],
      commonPests: ['Bọ trĩ', 'Bệnh thán thư', 'Héo rũ Fusarium', 'Virus khảm'],
      growthStages: [
        GrowthStageProfile(
          stageId: 'pepper-s1',
          name: 'Ươm giống',
          nameEn: 'Seedling',
          startDayFromPlanting: 0,
          endDayFromPlanting: 30,
          description: 'Thời gian ươm dài. Cần kiểm soát nhiệt độ và ánh sáng chặt chẽ.',
          iconEmoji: '🌱',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 78,
            tempMin: 22, tempMax: 28,
            humidityMin: 68, humidityMax: 82,
            irrigationDurationMin: 8,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Ươm hạt trong khay 128 lỗ', 'Tưới nhỏ giọt 2 lần/ngày', 'Chiếu sáng 14h/ngày', 'Kiểm tra cây yếu bỏ sớm'],
        ),
        GrowthStageProfile(
          stageId: 'pepper-s2',
          name: 'Trồng ra nhà màng',
          nameEn: 'Transplanting & Establishment',
          startDayFromPlanting: 30,
          endDayFromPlanting: 55,
          description: 'Giai đoạn bén rễ sau khi trồng chuyển. Hạn chế tưới quá nhiều.',
          iconEmoji: '🌿',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 60, soilMoistureMax: 72,
            tempMin: 22, tempMax: 27,
            humidityMin: 62, humidityMax: 75,
            irrigationDurationMin: 12,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Trồng cây con ra luống', 'Phủ bạt nông nghiệp', 'Bón lót NPK 16-16-8', 'Dưỡng cây 5-7 ngày đầu'],
        ),
        GrowthStageProfile(
          stageId: 'pepper-s3',
          name: 'Ra hoa & Đậu quả',
          nameEn: 'Flowering & Fruit Set',
          startDayFromPlanting: 55,
          endDayFromPlanting: 90,
          description: 'Điều chỉnh vi khí hậu kỹ lưỡng. Nhiệt độ cao làm rụng hoa.',
          iconEmoji: '🌺',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 75,
            tempMin: 20, tempMax: 26,
            humidityMin: 58, humidityMax: 68,
            irrigationDurationMin: 15,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Kiểm soát nhiệt < 26°C', 'Tăng K-Ca-Mg', 'Cắt bớt lá già tăng thông gió', 'Phun phòng Thán thư'],
        ),
        GrowthStageProfile(
          stageId: 'pepper-s4',
          name: 'Chín màu & Thu hoạch',
          nameEn: 'Ripening & Harvest',
          startDayFromPlanting: 90,
          endDayFromPlanting: 120,
          description: 'Thu hoạch liên tục mỗi 5-7 ngày. Màu quả đặc trưng theo giống.',
          iconEmoji: '🫑',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 60, soilMoistureMax: 72,
            tempMin: 18, tempMax: 25,
            humidityMin: 55, humidityMax: 68,
            irrigationDurationMin: 12,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Thu hoạch 5-7 ngày/lần', 'Đóng gói theo chuẩn VietGAP', 'Duy trì cây cho vụ tiếp', 'Ghi nhật ký thu hoạch'],
        ),
      ],
    ),

    // ── DÂU TÂY ──
    DefaultCropProfile(
      cropId: 'crop-strawberry',
      name: 'Dâu Tây',
      nameEn: 'Strawberry',
      variety: 'New Zealand / Mỹ Đen / Albion',
      emoji: '🍓',
      standardType: 'VietGAP',
      totalCycleDays: 180,
      description: 'Cây đặc sản cao cấp Đà Lạt. Yêu cầu kỹ thuật cao, kiểm soát vi khí hậu nghiêm ngặt để đạt chất lượng xuất khẩu.',
      origin: 'Ôn đới – Thuần hóa thành công tại Đà Lạt từ 1950',
      difficulty: 'KHÓ',
      suitableRegion: 'Đà Lạt (độ cao > 1400m), Mộc Châu',
      compatibleActuators: ['PUMP', 'FAN'],
      commonPests: ['Nhện đỏ', 'Bệnh xám Botrytis', 'Thán thư', 'Sương mai'],
      growthStages: [
        GrowthStageProfile(
          stageId: 'strawberry-s1',
          name: 'Bén rễ ban đầu',
          nameEn: 'Establishment',
          startDayFromPlanting: 0,
          endDayFromPlanting: 30,
          description: 'Dây runner cần bén rễ vào giá thể. Giữ ẩm đều và tránh ánh nắng trực tiếp mạnh.',
          iconEmoji: '🌱',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 68, soilMoistureMax: 80,
            tempMin: 15, tempMax: 22,
            humidityMin: 70, humidityMax: 85,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 3,
          ),
          keyActivities: ['Trồng runner vào giá thể', 'Che lưới 50% ánh sáng', 'Tưới nhẹ 3 lần/ngày', 'Phòng nấm với Mancozeb'],
        ),
        GrowthStageProfile(
          stageId: 'strawberry-s2',
          name: 'Phát triển tán lá',
          nameEn: 'Vegetative',
          startDayFromPlanting: 30,
          endDayFromPlanting: 80,
          description: 'Giai đoạn tích lũy chất dinh dưỡng. Kiểm soát nhiệt độ là yếu tố quyết định.',
          iconEmoji: '🌿',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 78,
            tempMin: 14, tempMax: 20,
            humidityMin: 65, humidityMax: 80,
            irrigationDurationMin: 12,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Bón phân cân đối N-P-K', 'Tỉa lá già và runner phụ', 'Kiểm soát nhiệt < 20°C', 'Phun vi lượng Bo-Ca'],
        ),
        GrowthStageProfile(
          stageId: 'strawberry-s3',
          name: 'Ra hoa & Đậu quả',
          nameEn: 'Flowering',
          startDayFromPlanting: 80,
          endDayFromPlanting: 130,
          description: 'Cần ong thụ phấn hoặc rung động. Hoa rất nhạy cảm với nhiệt độ cao.',
          iconEmoji: '🌸',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 75,
            tempMin: 13, tempMax: 18,
            humidityMin: 60, humidityMax: 72,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Giảm đạm, tăng lân-kali', 'Thả ong thụ phấn', 'Tránh tưới lên hoa', 'Phòng xám Botrytis'],
        ),
        GrowthStageProfile(
          stageId: 'strawberry-s4',
          name: 'Nuôi trái & Thu hoạch',
          nameEn: 'Fruit Development & Harvest',
          startDayFromPlanting: 130,
          endDayFromPlanting: 180,
          description: 'Thu hoạch liên tục mỗi 2-3 ngày. Quả chín 80% màu đỏ là thu hoạch tốt nhất.',
          iconEmoji: '🍓',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 62, soilMoistureMax: 72,
            tempMin: 12, tempMax: 18,
            humidityMin: 58, humidityMax: 70,
            irrigationDurationMin: 8,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Thu hoạch sáng sớm 5:00-7:00', 'Không chạm tay trực tiếp vào quả', 'Bảo quản 4-6°C ngay sau hái', 'Ghi nhật ký theo tiêu chuẩn VietGAP'],
        ),
      ],
    ),

    // ── DƯA LƯỚI ──
    DefaultCropProfile(
      cropId: 'crop-melon',
      name: 'Dưa Lưới',
      nameEn: 'Cantaloup Melon',
      variety: 'TL-3 / Kim Cô Nương / Taki',
      emoji: '🍈',
      standardType: 'VietGAP',
      totalCycleDays: 75,
      description: 'Sản phẩm cao cấp thị trường nội địa. Phải kiểm soát độ ẩm đất rất chính xác để quả lưới đẹp.',
      origin: 'Trung Đông – Thích nghi tốt với nhà màng Việt Nam',
      difficulty: 'KHÓ',
      suitableRegion: 'Ninh Thuận, Bình Thuận, Đà Lạt (nhà màng)',
      compatibleActuators: ['PUMP', 'FAN', 'GROW_LIGHT'],
      commonPests: ['Bọ trĩ', 'Bệnh phấn trắng', 'Héo rũ', 'Mosaic virus'],
      growthStages: [
        GrowthStageProfile(
          stageId: 'melon-s1',
          name: 'Nảy mầm',
          nameEn: 'Germination',
          startDayFromPlanting: 0,
          endDayFromPlanting: 7,
          description: 'Hạt dưa lưới cần nhiệt độ ấm để nảy mầm đồng đều.',
          iconEmoji: '🌱',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 70, soilMoistureMax: 82,
            tempMin: 28, tempMax: 35,
            humidityMin: 72, humidityMax: 85,
            irrigationDurationMin: 8,
            irrigationFrequencyPerDay: 3,
          ),
          keyActivities: ['Ươm hạt vào bầu', 'Nhiệt độ 28-35°C', 'Tưới phun sương 3 lần/ngày'],
        ),
        GrowthStageProfile(
          stageId: 'melon-s2',
          name: 'Phát triển thân lá',
          nameEn: 'Vegetative',
          startDayFromPlanting: 7,
          endDayFromPlanting: 28,
          description: 'Cây leo nhanh, cần giàn và bấm ngọn đúng kỹ thuật để lấy quả đẹp.',
          iconEmoji: '🌿',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 78,
            tempMin: 25, tempMax: 32,
            humidityMin: 65, humidityMax: 80,
            irrigationDurationMin: 12,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Cắm giàn và buộc dây', 'Bấm ngọn cành chính ở đốt 22-25', 'Bón NPK 20-20-15', 'Giữ 1 thân chính'],
        ),
        GrowthStageProfile(
          stageId: 'melon-s3',
          name: 'Ra hoa & Chọn quả',
          nameEn: 'Flowering & Fruit Selection',
          startDayFromPlanting: 28,
          endDayFromPlanting: 45,
          description: 'Chỉ giữ 1 quả/cây ở đốt 12-14. Loại tất cả quả còn lại để tập trung dinh dưỡng.',
          iconEmoji: '🌼',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 65, soilMoistureMax: 72,
            tempMin: 24, tempMax: 30,
            humidityMin: 60, humidityMax: 72,
            irrigationDurationMin: 10,
            irrigationFrequencyPerDay: 2,
          ),
          keyActivities: ['Chọn 1 quả đẹp ở đốt 12-14', 'Loại bỏ tất cả quả còn lại', 'Thụ phấn nhân tạo bằng cọ', 'Tăng K-Ca-B'],
        ),
        GrowthStageProfile(
          stageId: 'melon-s4',
          name: 'Phát triển quả & Lên lưới',
          nameEn: 'Fruit Development',
          startDayFromPlanting: 45,
          endDayFromPlanting: 65,
          description: 'Giai đoạn quyết định chất lượng lưới. Giảm tưới để tăng độ ngọt và kích thích lên lưới.',
          iconEmoji: '🍈',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 55, soilMoistureMax: 68,
            tempMin: 24, tempMax: 30,
            humidityMin: 55, humidityMax: 68,
            irrigationDurationMin: 8,
            irrigationFrequencyPerDay: 1,
          ),
          keyActivities: ['Giảm tưới xuống 1 lần/ngày', 'Đặt lưới đỡ quả', 'Đo độ Brix định kỳ', 'Kiểm tra vết nứt lưới'],
        ),
        GrowthStageProfile(
          stageId: 'melon-s5',
          name: 'Chín & Thu hoạch',
          nameEn: 'Maturation & Harvest',
          startDayFromPlanting: 65,
          endDayFromPlanting: 75,
          description: 'Thu hoạch khi cuống có vết nứt li ti và mùi thơm đặc trưng. Brix phải ≥ 14°.',
          iconEmoji: '✂️',
          requirements: const EnvironmentalRange(
            soilMoistureMin: 45, soilMoistureMax: 58,
            tempMin: 22, tempMax: 28,
            humidityMin: 50, humidityMax: 65,
            irrigationDurationMin: 5,
            irrigationFrequencyPerDay: 1,
          ),
          keyActivities: ['Đo Brix ≥ 14°', 'Kiểm tra vết nứt cuống', 'Thu hoạch buổi sáng sớm', 'Đóng gói theo VietGAP'],
        ),
      ],
    ),
  ];

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

  List<AutomationRuleModel> get automationRules => _automationRules;

  /// Bật/tắt rule qua API. Trả về thông báo lỗi, hoặc null khi thành công.
  Future<String?> toggleAutomationRule(String ruleId) async {
    final rule = _automationRules.firstWhere((r) => r.ruleId == ruleId);
    final raw = rule.raw;
    if (raw == null || rule.zoneId == null) return 'Rule này chưa có trên hệ thống.';
    try {
      await ApiService.updateAutoRule(rule.zoneId!, ruleId, {...raw, 'isActive': !rule.isActive});
      rule.isActive = !rule.isActive;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> addAutomationRule(String zoneId, Map<String, dynamic> body) async {
    try {
      await ApiService.createAutoRule(zoneId, body);
      await _loadInventoryAndRules();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

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

  List<FieldInspectionRequestModel> get inspectionRequests => _inspectionRequests;

  void submitInspectionRequest({
    required String zoneId,
    required String zoneName,
    required double areaM2,
    required String cropName,
    required double estimatedCostVND,
    required String contactName,
    required String contactPhone,
    required String preferredDate,
    required String note,
    List<ZoneEquipmentItem>? customEquipmentItems,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final newId = 'REQ-2026-00${_inspectionRequests.length + 1}';

    final newReq = FieldInspectionRequestModel(
      requestId: newId,
      farmId: _selectedFarmId,
      farmName: currentFarm.name,
      zoneId: zoneId,
      zoneName: zoneName,
      areaM2: areaM2,
      cropName: cropName,
      estimatedCostVND: estimatedCostVND,
      contactName: contactName,
      contactPhone: contactPhone,
      preferredDate: preferredDate,
      note: note,
      status: 'PENDING',
      createdAt: dateStr,
      adminNote: 'Đã gửi đến Quản trị viên hệ thống (Admin). Đang chờ phê duyệt và phân công Kỹ thuật viên IoT.',
      customEquipmentItems: customEquipmentItems,
    );

    _inspectionRequests.insert(0, newReq);

    // Tự động tạo 1 Task thông báo cho Kỹ thuật viên
    _tasks.insert(
      0,
      TaskModel(
        taskId: 'tsk-req-${now.millisecondsSinceEpoch}',
        title: 'Khảo sát thực địa: $zoneName ($contactName)',
        zoneName: zoneName.split(' - ').first,
        priority: 'HIGH',
        dueDate: preferredDate,
      ),
    );

    notifyListeners();
  }

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

  List<EquipmentOrderModel> get equipmentOrders => _equipmentOrders;

  /// KTV hoặc Admin tạo Đơn hàng (Order) gửi cho Owner xác nhận & đặt cọc 30%
  String createOrderFromInspection(FieldInspectionRequestModel req, {List<ZoneEquipmentItem>? overrideItems}) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final orderId = 'ORD-2026-00${_equipmentOrders.length + 1}';

    final items = overrideItems ?? req.customEquipmentItems ?? ZoneCostSimulation.calculate(
      areaM2: req.areaM2,
      cropName: req.cropName,
    ).equipmentItems;

    double total = 0;
    for (final it in items) {
      total += it.totalPriceVND;
    }
    final deposit = (total * 0.30).roundToDouble();
    final remaining = total - deposit;

    final newOrder = EquipmentOrderModel(
      orderId: orderId,
      requestId: req.requestId,
      farmId: req.farmId,
      farmName: req.farmName,
      zoneId: req.zoneId,
      zoneName: req.zoneName,
      items: items,
      totalAmountVND: total,
      depositAmountVND: deposit,
      remainingAmountVND: remaining,
      status: 'AWAITING_PAYMENT',
      createdAt: dateStr,
    );

    _equipmentOrders.insert(0, newOrder);

    // Tạo thông báo nhiệm vụ cho Owner
    _tasks.insert(
      0,
      TaskModel(
        taskId: 'tsk-ord-${now.millisecondsSinceEpoch}',
        title: 'Xác nhận đơn hàng & Cọc 30%: ${req.zoneName}',
        zoneName: req.zoneName.split(' - ').first,
        priority: 'HIGH',
        dueDate: 'Trong 48 giờ',
      ),
    );

    notifyListeners();
    return orderId;
  }

  /// Owner xác nhận và thanh toán cọc 30%
  void confirmOrderWithDeposit(String orderId, {required String paymentMethod, String? proofNote}) {
    final idx = _equipmentOrders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1) {
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour}:${now.minute}';
      _equipmentOrders[idx] = _equipmentOrders[idx].copyWith(
        status: 'CONFIRMED',
        paymentMethod: paymentMethod,
        paymentProofNote: proofNote ?? 'Đã thanh toán cọc 30% thành công qua $paymentMethod. Kho hàng SmartFarm đang đóng gói thiết bị và xếp lịch kỹ thuật viên lắp đặt.',
        confirmedAt: dateStr,
      );
      notifyListeners();
    }
  }

  /// KTV bắt đầu giao hàng & lắp đặt sau khi Owner đã cọc 30%
  void startOrderInstallation(String orderId) {
    final idx = _equipmentOrders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1 && _equipmentOrders[idx].status == 'CONFIRMED') {
      _equipmentOrders[idx] = _equipmentOrders[idx].copyWith(
        status: 'DISPATCHING',
        paymentProofNote: 'KTV đã nhận hàng từ kho và đang lắp đặt thiết bị tại ${_equipmentOrders[idx].zoneName}.',
      );
      notifyListeners();
    }
  }

  /// KTV bàn giao nghiệm thu, chuyển Owner thanh toán 70% còn lại
  void handoverOrder(String orderId) {
    final idx = _equipmentOrders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1 && _equipmentOrders[idx].status == 'DISPATCHING') {
      _equipmentOrders[idx] = _equipmentOrders[idx].copyWith(
        status: 'AWAITING_FINAL_PAYMENT',
        paymentProofNote: 'KTV đã lắp đặt xong và bàn giao. Chủ trại vui lòng nghiệm thu & thanh toán 70% còn lại.',
      );
      final now = DateTime.now();
      _tasks.insert(
        0,
        TaskModel(
          taskId: 'tsk-ord-final-${now.millisecondsSinceEpoch}',
          title: 'Nghiệm thu & thanh toán 70% đơn hàng: ${_equipmentOrders[idx].zoneName}',
          zoneName: _equipmentOrders[idx].zoneName.split(' - ').first,
          priority: 'HIGH',
          dueDate: 'Trong 7 ngày',
        ),
      );
      notifyListeners();
    }
  }

  /// Owner nghiệm thu và thanh toán 70% còn lại
  void payFinalOrder(String orderId, {required String paymentMethod}) {
    final idx = _equipmentOrders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1 && _equipmentOrders[idx].status == 'AWAITING_FINAL_PAYMENT') {
      _equipmentOrders[idx] = _equipmentOrders[idx].copyWith(
        status: 'COMPLETED',
        paymentMethod: paymentMethod,
        paymentProofNote: 'Đã nghiệm thu và thanh toán đủ 100% qua $paymentMethod.',
      );
      notifyListeners();
    }
  }

  /// Owner hủy đơn khi chưa đặt cọc
  void cancelOrder(String orderId) {
    final idx = _equipmentOrders.indexWhere((o) => o.orderId == orderId);
    if (idx != -1 && _equipmentOrders[idx].status == 'AWAITING_PAYMENT') {
      _equipmentOrders[idx] = _equipmentOrders[idx].copyWith(
        status: 'CANCELLED',
        paymentProofNote: 'Chủ trại đã hủy đơn hàng trước khi đặt cọc.',
      );
      notifyListeners();
    }
  }

  void completeInspectionRequest(
    String requestId, {
    String? result,
    String? inspectionNotes,
    List<String>? inspectionFindings,
  }) {
    final idx = _inspectionRequests.indexWhere((r) => r.requestId == requestId);
    if (idx != -1) {
      final req = _inspectionRequests[idx];
      _inspectionRequests[idx] = req.copyWith(
        status: 'COMPLETED',
        adminNote: result ?? 'KTV đã khảo sát xong thực địa, biên bản được gửi về Admin.',
        inspectionNotes: inspectionNotes ?? 'Đã hoàn tất đo đạc hiện trường, nguồn điện ổn định, đủ điều kiện lắp đặt.',
        inspectionFindings: inspectionFindings ?? [
          'Nguồn điện: 220V 1 pha ổn định',
          'Nguồn nước: Áp lực 2.5 bar đạt chuẩn',
          'Sóng LoRa: RSSI -82 dBm (Tốt)',
          'Vị trí tủ điều khiển: Góc nhà màng, có mái che',
        ],
      );

      // Tự động tạo Đơn hàng (Order) gửi cho Owner xác nhận nếu chưa có
      if (!_equipmentOrders.any((o) => o.requestId == requestId)) {
        createOrderFromInspection(_inspectionRequests[idx]);
      }

      notifyListeners();
    }
  }

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

  List<MaterialInventoryModel> get inventoryItemsForCurrentFarm =>
      _inventoryItems.where((i) => i.farmId == _selectedFarmId).toList();

  int get lowStockCount =>
      inventoryItemsForCurrentFarm.where((i) => i.isLowStock).length;

  Future<String?> _inventoryCall(Future<void> Function() call) async {
    try {
      await call();
      await _loadInventoryAndRules();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> addInventoryItem({
    required String materialName,
    required String category,
    required double quantity,
    required String unit,
    required double minimumStock,
  }) => _inventoryCall(() => ApiService.createInventoryItem(_selectedFarmId, {
    'name': materialName,
    'materialType': switch (category) {
      'SEED' => 'Seed',
      'FERTILIZER' => 'Fertilizer',
      'PESTICIDE' => 'Pesticide',
      _ => 'Tool',
    },
    'unit': unit,
    'lowStockThreshold': minimumStock,
    'initialQuantity': quantity,
  }));

  Future<String?> receiveStock(String itemId, double quantity) =>
      _inventoryCall(() => ApiService.receiveInventory(_selectedFarmId, itemId, quantity));

  Future<String?> issueStock(String itemId, double quantity, String zoneId) =>
      _inventoryCall(() => ApiService.issueInventory(_selectedFarmId, itemId, quantity, zoneId));
}



