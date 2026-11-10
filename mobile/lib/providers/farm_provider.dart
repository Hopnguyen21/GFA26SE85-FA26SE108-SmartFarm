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
  bool get isApiConnected => _isApiConnected;

  bool _isLoadingApi = false;
  bool get isLoadingApi => _isLoadingApi;

  Map<String, dynamic>? _farmWeather;
  Map<String, dynamic>? get farmWeather => _farmWeather;
  bool _isLoadingWeather = false;
  bool get isLoadingWeather => _isLoadingWeather;

  Map<String, dynamic>? _me;
  /// Hồ sơ của tài khoản đang đăng nhập (GET /users/me).
  Map<String, dynamic>? get me => _me;

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
  String? _syncError;
  /// Lỗi đồng bộ gần nhất (mạng/máy chủ); null nếu lần đồng bộ cuối thành công.
  String? get syncError => _syncError;

  Future<void> fetchFromApi() async {
    _isLoadingApi = true;
    _syncError = null;
    notifyListeners();
    try {
      // 1. Lấy danh sách Farms
      _me = await ApiService.getMe();
      unawaited(loadCropProfiles());
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
      // Lỗi mạng/máy chủ: GIỮ dữ liệu đang có, báo lỗi thay vì xoá như thể tài khoản trống.
      _syncError = e.toString().replaceFirst('Exception: ', '');
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

              // Đồng bộ trạng thái rơ-le chấp hành của zone hiện tại
              try {
                final freshActs = await ApiService.getZoneActuators(curZ.zoneId);
                final zIdLower = curZ.zoneId.toLowerCase();
                final oldActs = _actuators.where((a) => a.zoneId.toLowerCase() == zIdLower).toList();
                bool actsChanged = oldActs.length != freshActs.length;
                if (!actsChanged) {
                  for (int j = 0; j < oldActs.length; j++) {
                    if (oldActs[j].actuatorId != freshActs[j].actuatorId ||
                        oldActs[j].isRunning != freshActs[j].isRunning ||
                        oldActs[j].remainingMinutes != freshActs[j].remainingMinutes ||
                        oldActs[j].name != freshActs[j].name) {
                      actsChanged = true;
                      break;
                    }
                  }
                }
                if (actsChanged) {
                  _actuators.removeWhere((a) => a.zoneId.toLowerCase() == zIdLower);
                  _actuators.addAll(freshActs);
                  notifyListeners();
                }
              } catch (_) {}

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

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _realtimeTimer?.cancel();
    if (_lifecycleObserverAdded) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Multi-Farm & Multi-Field Hierarchy State
  String _selectedFarmId = '';
  String? _selectedFieldId; // null = all fields in the selected farm

  String get selectedFarmId => _selectedFarmId;
  String? get selectedFieldId => _selectedFieldId;

  FarmModel get currentFarm => _farms.firstWhere(
    (f) => f.farmId == _selectedFarmId,
    orElse: () => _farms.isNotEmpty
        ? _farms.first
        : FarmModel(farmId: '', name: 'Chưa có nông trại', address: '', totalAreaM2: 0, latitude: 0, longitude: 0),
  );

  FieldModel? get currentField => _selectedFieldId == null
    ? null
    : _fields.where((f) => f.fieldId == _selectedFieldId).firstOrNull;

  Future<void> fetchWeatherForCurrentFarm() async {
    if (_selectedFarmId.isEmpty) return;
    _isLoadingWeather = true;
    notifyListeners();
    try {
      _farmWeather = await ApiService.getFarmWeather(_selectedFarmId);
    } catch (_) {
      _farmWeather = null;
    } finally {
      _isLoadingWeather = false;
      notifyListeners();
    }
  }

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

  void selectField(String? fieldId) {
    _selectedFieldId = fieldId;
    _selectedZoneIndex = 0;
    notifyListeners();
  }

  // Selected Zone
  int _selectedZoneIndex = 0;
  int get selectedZoneIndex => _selectedZoneIndex;

  void selectZone(int index) {
    if (index >= 0 && index < _zones.length) {
      _selectedZoneIndex = index;
      notifyListeners();
      refreshCurrentZoneActuators();
    }
  }

  Future<void> refreshCurrentZoneActuators() async {
    if (!_isApiConnected || _zones.isEmpty) return;
    try {
      final curZ = currentZone;
      final zoneActs = await ApiService.getZoneActuators(curZ.zoneId);
      final zIdLower = curZ.zoneId.toLowerCase();
      _actuators.removeWhere((a) => a.zoneId.toLowerCase() == zIdLower);
      _actuators.addAll(zoneActs);
      notifyListeners();
    } catch (_) {}
  }

  final List<FarmModel> _farms = [];
  List<FarmModel> get farms => _farms;

  final List<FieldModel> _fields = [];
  List<FieldModel> get fields => _fields;

  List<FieldModel> get fieldsForCurrentFarm =>
      _fields.where((f) => f.farmId == _selectedFarmId).toList();

  final List<ZoneModel> _zones = [];

  // Danh sách Nông dân / Kỹ thuật viên (Farmer) thuộc quyền quản lý của Chủ trại (Owner)
  final List<FarmerModel> _farmers = [];

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

  /// Đặt lại mật khẩu tài khoản Farmer (thực thi an toàn qua API, không lưu plaintext)
  /// Backend chưa có API đặt lại mật khẩu Farmer: không giả lập thành công, không lưu mật khẩu cục bộ.
  Future<bool> resetFarmerPassword(String farmerId, String newPassword) async {
    return false;
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

  /// Tạo trang trại thật qua API rồi đồng bộ lại; trả về thông báo lỗi (null nếu thành công).
  Future<String?> addFarm({
    required String name,
    required String address,
    required double totalAreaM2,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final created = await ApiService.createFarm(
        name: name,
        locationText: address.isEmpty ? null : address,
        latitude: latitude,
        longitude: longitude,
        totalAreaM2: totalAreaM2,
      );
      final id = '${created['farmId'] ?? created['id'] ?? ''}';
      if (id.isNotEmpty) _selectedFarmId = id;
      _selectedFieldId = null;
      _selectedZoneIndex = 0;
      await fetchFromApi();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Tạo thửa đất thật qua API (bắt buộc có ranh giới); trả về thông báo lỗi (null nếu thành công).
  Future<String?> addField({
    required String farmId,
    required String name,
    required String description,
    required double areaM2,
    List<LatLng>? polygon,
  }) async {
    if (polygon == null || polygon.length < 3) return 'Cần vẽ ranh giới thửa đất trên bản đồ (tối thiểu 3 điểm).';
    try {
      final created = await ApiService.createField(
        farmId: farmId,
        name: name,
        areaM2: areaM2,
        boundaryGeoJson: ApiService.polygonGeoJson([for (final p in polygon) [p.latitude, p.longitude]]),
      );
      final id = '${created['fieldId'] ?? created['id'] ?? ''}';
      if (id.isNotEmpty) _selectedFieldId = id;
      await fetchFromApi();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Tạo Zone thật qua API (bắt buộc có thửa đất và ranh giới); trả về thông báo lỗi (null nếu thành công).
  /// Cây trồng không gắn khi tạo Zone: backend gán cây thông qua Vụ mùa (Farming Season).
  Future<String?> addNewZone({
    required String name,
    required double areaM2,
    String? cropProfileId,
    String? assignedWorkerName,
    String? workerRole,
    String? customFarmId,
    String? customFieldId,
    List<LatLng>? polygon,
  }) async {
    final fieldId = customFieldId ?? _selectedFieldId ?? fieldsForCurrentFarm.firstOrNull?.fieldId;
    if (fieldId == null || fieldId.isEmpty) return 'Chưa có thửa đất để tạo Zone.';
    if (polygon == null || polygon.length < 3) return 'Cần vẽ ranh giới Zone trên bản đồ (tối thiểu 3 điểm).';
    try {
      await ApiService.createZone(
        fieldId: fieldId,
        name: name,
        areaM2: areaM2,
        polygonGeoJson: ApiService.polygonGeoJson([for (final p in polygon) [p.latitude, p.longitude]]),
      );
      await fetchFromApi();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  final List<ActuatorModel> _actuators = [];
  List<ActuatorModel> get actuators => _actuators;

  List<ActuatorModel> get currentZoneActuators {
    if (_zones.isEmpty || _selectedZoneIndex >= _zones.length) return [];
    final currentZId = currentZone.zoneId.toLowerCase();
    return _actuators.where((a) => a.zoneId.toLowerCase() == currentZId).toList();
  }

  Future<bool> toggleActuator(String actuatorId, {int? durationMinutes}) async {
    final actIndex = _actuators.indexWhere((a) => a.actuatorId == actuatorId);
    if (actIndex == -1) return false;
    final act = _actuators[actIndex];
    final prevRunning = act.isRunning;
    final prevRemaining = act.remainingMinutes;

    final targetRunning = !prevRunning;
    final targetRemaining = targetRunning ? (durationMinutes ?? 15) : 0;

    act.isRunning = targetRunning;
    act.remainingMinutes = targetRemaining;
    notifyListeners();

    // Gửi lệnh điều khiển xuống Backend API nếu có kết nối
    if (_isApiConnected) {
      final action = targetRunning ? 'TurnOn' : 'TurnOff';
      final duration = targetRunning ? (targetRemaining * 60) : 1;
      try {
        final success = await ApiService.sendActuatorCommand(
          zoneId: act.zoneId,
          actuatorId: act.actuatorId,
          action: action,
          durationSeconds: duration,
        );
        if (!success) {
          // Rollback state on failure
          act.isRunning = prevRunning;
          act.remainingMinutes = prevRemaining;
          notifyListeners();
          return false;
        } else {
          await refreshCurrentZoneActuators();
        }
      } catch (_) {
        // Rollback state on network/server error
        act.isRunning = prevRunning;
        act.remainingMinutes = prevRemaining;
        notifyListeners();
        return false;
      }
    }
    return true;
  }

  final List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => _alerts;

  void acknowledgeAlert(String alertId) {
    final idx = _alerts.indexWhere((a) => a.alertId == alertId);
    if (idx != -1) {
      _alerts[idx].isAcknowledged = true;
      notifyListeners();
    }

    if (_isApiConnected) {
      ApiService.acknowledgeAlert(alertId);
    }
  }

  // ── Thông báo Hệ Thống (Notifications) ──
  final List<AppNotificationModel> _notifications = [];

  List<AppNotificationModel> get notifications => _notifications;
  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

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

  Future<void> markNotificationAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.notificationId == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
      await ApiService.markNotificationAsRead(id);
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    notifyListeners();
    await ApiService.markAllNotificationsAsRead();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.notificationId == id);
    notifyListeners();
    await ApiService.deleteNotification(id);
  }

  Future<void> deleteAllReadNotifications() async {
    _notifications.removeWhere((n) => n.isRead);
    notifyListeners();
    await ApiService.deleteAllReadNotifications();
  }

  final List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => _tasks;

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
        'result': ?result,
        'failureReason': ?failureReason,
        'progressPercent': ?progressPercent,
        'farmerId': ?farmerId,
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

  /// Cập nhật trạng thái khuyến nghị của tin nhắn
  void updateChatMessageStatus(String messageId, String newStatus) {
    final idx = _chatMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _chatMessages[idx].recommendationStatus = newStatus;
      notifyListeners();
    }
  }

  void refreshChatState() {
    notifyListeners();
  }


  /// Cũ – vẫn giữ để không break code khác, nhưng giờ dùng addChatMessage
  void sendChatMessage(String text) {
    addChatMessage(ChatMessageModel(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: true,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    ));
  }

  // ─────────────────────────────────────────
  // Schedules (lịch tưới) – Seeded + loaded from API
  // ─────────────────────────────────────────
  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> get schedules => _schedules;
  bool _schedulesLoading = false;
  bool get schedulesLoading => _schedulesLoading;

  Future<void> fetchSchedules({String? zoneId, String? farmId}) async {
    _schedulesLoading = true;
    notifyListeners();
    try {
      // Lịch tưới lấy theo từng Zone (backend không có API theo Farm); không chỉ định Zone thì gộp các Zone của Farm.
      final targetFarm = farmId ?? _selectedFarmId;
      final zoneIds = zoneId != null
          ? [zoneId]
          : _zones.where((z) => z.farmId == targetFarm).map((z) => z.zoneId).toList();
      final lists = await Future.wait(zoneIds.map((id) => ApiService.getSchedules(zoneId: id)));
      final list = lists.expand((x) => x).toList();
      if (list.isNotEmpty) {
        _schedules = list;
      }
    } catch (_) {}
    _schedulesLoading = false;
    notifyListeners();
  }

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

  Future<bool> toggleScheduleEnabled(String scheduleId, bool enable) async {
    final idx = _schedules.indexWhere((s) => s.scheduleId == scheduleId);
    final sch = idx != -1 ? _schedules[idx] : null;
    final targetZoneId = sch?.zoneId.isNotEmpty == true ? sch!.zoneId : currentZone.zoneId;
    final ok = await ApiService.toggleSchedule(
      scheduleId,
      enable,
      zoneId: targetZoneId,
      name: sch?.name,
      cronExpression: sch?.cronExpression,
      durationSeconds: sch != null && sch.durationSeconds > 0 ? sch.durationSeconds : 900,
      enableRainDelay: sch?.enableRainDelay ?? true,
      rainThresholdPercent: sch?.rainThresholdPercent ?? 70.0,
    );
    if (ok) {
      if (idx != -1) {
        final s = _schedules[idx];
        s.isActive = enable;
        notifyListeners();
      }
    }
    return ok;
  }

  void addSchedule(ScheduleModel schedule) {
    _schedules.insert(0, schedule);
    notifyListeners();
  }

  void removeSchedule(String scheduleId) {
    _schedules.removeWhere((s) => s.scheduleId == scheduleId);
    notifyListeners();
  }




  // ─────────────────────────────────────────
  // Vấn đề 6: Default Crop Profiles (Seed Data)
  // ─────────────────────────────────────────
  String? _appliedCropId;
  String? get appliedCropId => _appliedCropId;

  /// Áp dụng cây cho Zone bằng cách tạo Vụ trồng thật (planting season) qua API; trả về lỗi (null nếu thành công).
  Future<String?> applyCropProfile(String profileId, {String? targetZoneId, String? farmingSeasonId}) async {
    final profile = defaultCropProfiles.where((p) => p.cropId == profileId).firstOrNull;
    if (profile == null) return 'Không tìm thấy hồ sơ cây trồng.';
    final zId = targetZoneId ?? (_zones.isEmpty ? '' : currentZone.zoneId);
    if (zId.isEmpty) return 'Chưa chọn Zone.';
    String d2(int v) => v.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${d.year}-${d2(d.month)}-${d2(d.day)}';
    final start = DateTime.now();
    final end = start.add(Duration(days: profile.totalCycleDays > 0 ? profile.totalCycleDays : 1));
    try {
      await ApiService.createPlantingSeason(zId, {
        'cropId': profile.realCropId,
        'varietyId': ?profile.varietyId,
        'growthProfileId': profile.profileId,
        'name': '${profile.name} ${start.year}',
        'startDate': fmt(start),
        'expectedEndDate': fmt(end),
        'farmingSeasonId': ?farmingSeasonId,
        'setZoneCrop': true,
      });
      _appliedCropId = profileId;
      await fetchFromApi();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Thư viện cây trồng: nạp từ API (hồ sơ sinh trưởng), không còn danh sách cứng trong ứng dụng.
  final List<DefaultCropProfile> defaultCropProfiles = [];

  Future<void> loadCropProfiles() async {
    try {
      final r = await Future.wait([ApiService.getGrowthProfiles(), ApiService.getCropsForProfiles()]);
      final cropsById = {for (final c in r[1]) '${c['cropId']}': c};
      final list = [
        for (final p in r[0]) defaultCropProfileFromApi(p, cropsById['${p['cropId']}']),
      ].where((p) => p.growthStages.isNotEmpty).toList();
      defaultCropProfiles
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // Giữ danh sách hiện có; lỗi mạng chung đã được báo qua syncError.
    }
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
  final List<AutomationRuleModel> _automationRules = [];
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

  /// Cập nhật dải ngưỡng tự động cho Zone và tự động sinh / cập nhật AutoRule tương ứng
  Future<String?> updateZoneThresholds({
    required String zoneId,
    required double maxTemp,
    required double minSoil,
    required double maxSoil,
  }) async {
    try {
      await ApiService.updateEnvironmentalThresholds(zoneId, minSoil: minSoil, maxSoil: maxSoil, maxTemp: maxTemp);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ─────────────────────────────────────────
  // Quản lý Yêu cầu Kiểm tra Thực địa (Field Inspections)
  // ─────────────────────────────────────────
  final List<FieldInspectionRequestModel> _inspectionRequests = [];
  List<FieldInspectionRequestModel> get inspectionRequests => _inspectionRequests;

  List<FieldInspectionRequestModel> get inspectionRequestsForCurrentFarm =>
      _inspectionRequests.where((r) => r.farmId == _selectedFarmId).toList();

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
  final List<EquipmentOrderModel> _equipmentOrders = [];

  List<EquipmentOrderModel> get equipmentOrders => _equipmentOrders;

  List<EquipmentOrderModel> get equipmentOrdersForCurrentFarm =>
      _equipmentOrders.where((o) => o.farmId == _selectedFarmId).toList();

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

  void rejectInspectionRequest(String requestId, {String? reason}) {
    final idx = _inspectionRequests.indexWhere((r) => r.requestId == requestId);
    if (idx != -1) {
      _inspectionRequests[idx] = _inspectionRequests[idx].copyWith(
        status: 'REJECTED',
        adminNote: reason ?? 'Admin từ chối yêu cầu. Vui lòng bổ sung thông tin và gửi lại.',
      );
      notifyListeners();
    }
  }

  void approveInspectionRequest(String requestId, {String? technicianName, String? technicianPhone, String? adminNote}) {
    final idx = _inspectionRequests.indexWhere((r) => r.requestId == requestId);
    if (idx != -1) {
      final current = _inspectionRequests[idx];
      _inspectionRequests[idx] = current.copyWith(
        status: 'DISPATCHED',
        assignedTechnicianName: technicianName ?? 'Trần Minh Trí (KTV IoT)',
        technicianPhone: technicianPhone ?? '0909 888 777',
        adminNote: adminNote ?? 'Admin đã phê duyệt yêu cầu. Kỹ thuật viên đã tiếp nhận và sẽ có mặt theo lịch hẹn.',
      );
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────
  // KHO VẬT TƯ & PHÂN BÓN NÔNG NGHIỆP (INVENTORY)
  // ─────────────────────────────────────────
  final List<MaterialInventoryModel> _inventoryItems = [];

  List<MaterialInventoryModel> get inventoryItems => _inventoryItems;

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

  /// Xóa toàn bộ dữ liệu phiên khi đăng xuất (Clean state on logout)
  void resetState() {
    _isApiConnected = false;
    _chatMessages.clear();
    _schedules.clear();
    _alerts.clear();
    _tasks.clear();
    _notifications.clear();
    _clearSeedData();
    _selectedFarmId = '';
    _syncError = null;
    _selectedFieldId = null;
    _selectedZoneIndex = 0;
    notifyListeners();
  }

  Future<bool> updateProfile({required String fullName, String? phone}) async {
    final updated = await ApiService.updateProfile(fullName, phone);
    if (updated != null) {
      _me = updated;
      notifyListeners();
      return true;
    }
    return false;
  }
}



