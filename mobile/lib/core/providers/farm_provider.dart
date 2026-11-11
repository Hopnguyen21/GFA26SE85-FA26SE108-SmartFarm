import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:latlong2/latlong.dart';
import '../models/models.dart';
import '../services/api_service.dart';

part 'parts/farm_provider_sync.dart';
part 'parts/farm_provider_structure.dart';
part 'parts/farm_provider_control.dart';
part 'parts/farm_provider_alerts_tasks.dart';
part 'parts/farm_provider_chat_schedules.dart';
part 'parts/farm_provider_crops_automation.dart';
part 'parts/farm_provider_inventory_profile.dart';

class FarmProvider with ChangeNotifier, WidgetsBindingObserver {
  /// Cho phép code trong các file part (extension) báo thay đổi.
  void _notify() => notifyListeners();

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
  bool _creatingFarm = false;
  bool get isLoadingApi => _isLoadingApi;

  Map<String, dynamic>? _farmWeather;
  Map<String, dynamic>? get farmWeather => _farmWeather;
  bool _isLoadingWeather = false;
  bool get isLoadingWeather => _isLoadingWeather;

  Map<String, dynamic>? _me;

  /// Tổ chức của tài khoản (GET /tenants/me); null nếu chưa tải được hoặc tài khoản không thuộc tenant.
  Map<String, dynamic>? _tenant;
  String? get tenantName {
    final n = _tenant?['companyName']?.toString().trim();
    return (n == null || n.isEmpty) ? null : n;
  }

  /// Hồ sơ của tài khoản đang đăng nhập (GET /users/me).
  Map<String, dynamic>? get me => _me;

  @visibleForTesting
  void setMeForTesting(Map<String, dynamic>? data) {
    _me = data;
    notifyListeners();
  }

  @visibleForTesting
  void setSelectedFarmIdForTesting(String farmId) {
    _selectedFarmId = farmId;
    notifyListeners();
  }

  @visibleForTesting
  void setFarmersForTesting(List<FarmerModel> farmers) {
    _farmers
      ..clear()
      ..addAll(farmers);
    notifyListeners();
  }

  @visibleForTesting
  void setZonesForTesting(List<ZoneModel> zones) {
    _zones.clear();
    _zones.addAll(zones);
    notifyListeners();
  }

  @visibleForTesting
  void setStructureForTesting({List<FieldModel> fields = const [], List<ZoneModel> zones = const [], String? error}) {
    _fields
      ..clear()
      ..addAll(fields);
    _zones
      ..clear()
      ..addAll(zones);
    _structureError = error;
    _syncError = null;
    _isLoadingApi = false;
    notifyListeners();
  }

  void updateZonePolygon(String zoneId, List<LatLng> newPolygon) {
    final idx = _zones.indexWhere((z) => z.zoneId.toLowerCase() == zoneId.toLowerCase());
    if (idx != -1) {
      _zones[idx] = _zones[idx].copyWith(polygon: newPolygon);
      notifyListeners();
    }
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

  /// Lỗi tải riêng cho cấu trúc Thửa đất/Zone (null nếu tải đủ). Tách khỏi 'chưa có ranh giới'.
  String? _structureError;
  String? get structureError => _structureError;

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

  FieldModel? get currentField =>
      _selectedFieldId == null ? null : _fields.where((f) => f.fieldId == _selectedFieldId).firstOrNull;

  // Selected Zone
  int _selectedZoneIndex = 0;
  int get selectedZoneIndex => _selectedZoneIndex;

  final List<FarmModel> _farms = [];
  List<FarmModel> get farms => _farms;

  final List<FieldModel> _fields = [];
  List<FieldModel> get fields => _fields;

  List<FieldModel> get fieldsForCurrentFarm => _fields.where((f) => f.farmId == _selectedFarmId).toList();

  final List<ZoneModel> _zones = [];

  // Danh sách Nông dân / Kỹ thuật viên (Farmer) thuộc quyền quản lý của Chủ trại (Owner)
  final List<FarmerModel> _farmers = [];

  List<FarmerModel> get allFarmers => _farmers;

  /// Lấy danh sách các farmer thuộc về Farm của Owner hiện tại
  List<FarmerModel> get farmersForCurrentFarm =>
      _farmers.where((f) => f.farmId != null && f.farmId!.toLowerCase() == _selectedFarmId.toLowerCase()).toList();

  /// Nhân công đang hoạt động của một Farm CỤ THỂ (theo `farmId` của Zone), không phụ thuộc Farm đang chọn toàn cục.
  List<FarmerModel> farmersForFarm(String farmId) => [
    for (final f in _farmers)
      if (f.isActive && f.farmId != null && f.farmId!.toLowerCase() == farmId.toLowerCase()) f,
  ];

  /// Lấy danh sách nhân công phụ trách một Zone cụ thể.
  List<FarmerModel> getWorkersForZone(String zoneId) {
    if (zoneId.isEmpty) return const [];
    final targetId = zoneId.toLowerCase();
    if (_currentRole == 'OWNER') {
      return _farmers.where((f) => f.zoneAccess.any((a) => a.zoneId.toLowerCase() == targetId)).toList();
    }
    if (_currentRole == 'FARMER') {
      final me = currentUserFarmer;
      if (me != null && me.zoneAccess.any((a) => a.zoneId.toLowerCase() == targetId)) {
        return [me];
      }
    }
    return const [];
  }

  /// Nông dân đang đăng nhập (lấy từ GET /api/v1/users/me).
  FarmerModel? get currentUserFarmer => _me != null ? FarmerModel.fromJson(_me!) : null;

  /// Danh sách các khu vực được phân công cho Farmer đang đăng nhập.
  /// Tuyệt đối không fallback sang toàn bộ vùng hay danh sách của Farmer khác.
  List<ZoneModel> get assignedZonesForCurrentFarmer {
    final farmer = currentUserFarmer;
    if (farmer == null || farmer.zoneAccess.isEmpty) return const [];
    final allowedZoneIds = farmer.zoneAccess.map((z) => z.zoneId.toLowerCase()).toSet();
    final seen = <String>{};
    final result = <ZoneModel>[];
    for (final z in _zones) {
      final id = z.zoneId.toLowerCase();
      if (allowedZoneIds.contains(id) && seen.add(id)) {
        result.add(z);
      }
    }
    return result;
  }

  /// Chỉ FarmOwner được tạo/sửa Farm, Field, Zone (khớp backend). Farmer và Kỹ thuật viên chỉ xem.
  bool get canManageFarmStructure => _currentRole == 'OWNER';

  /// Kiểm tra tài khoản hiện tại có quyền điều khiển khu vực này không.
  /// Khớp backend: lệnh điều khiển thiết bị chỉ cho FarmOwner và Farmer (Technician không ra lệnh điều khiển).
  /// Owner điều khiển mọi Zone của tenant; Farmer chỉ khi zoneAccess có zoneId tương ứng và canControl == true.
  bool canControlZone(String zoneId) {
    if (_currentRole == 'OWNER') return true;
    if (_currentRole == 'FARMER') {
      final farmer = currentUserFarmer;
      if (farmer == null) return false;
      return farmer.zoneAccess.any((z) => z.zoneId.toLowerCase() == zoneId.toLowerCase() && z.canControl);
    }
    return false;
  }

  // Sửa hồ sơ / khóa / xóa / đặt lại mật khẩu Farmer: backend không có API cho Owner,
  // nên app không giả lập. Quản lý nhân công thật nằm ở WorkforceScreen (mời qua email, phân quyền Zone).

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

  final List<ActuatorModel> _actuators = [];

  /// Lỗi tải thiết bị chấp hành theo Zone (zoneId chữ thường). Có lỗi nghĩa là danh sách thiết bị CHƯA đáng tin, không phải "không có thiết bị".
  final Map<String, String> _actuatorErrors = {};
  String? actuatorErrorFor(String zoneId) => _actuatorErrors[zoneId.toLowerCase()];
  List<ActuatorModel> get actuators => _actuators;

  List<ActuatorModel> get currentZoneActuators {
    if (_zones.isEmpty || _selectedZoneIndex >= _zones.length) return [];
    final currentZId = currentZone.zoneId.toLowerCase();
    return _actuators.where((a) => a.zoneId.toLowerCase() == currentZId).toList();
  }

  /// Owner và Farmer được gọi dừng khẩn cấp (khớp [Authorize(Roles = "FarmOwner,Farmer")] ở backend).
  bool get canEmergencyStop => _currentRole == 'OWNER' || _currentRole == 'FARMER';

  bool _isEmergencyStopping = false;
  bool get isEmergencyStopping => _isEmergencyStopping;

  final List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => _alerts;

  // ── Thông báo Hệ Thống (Notifications) ──
  final List<AppNotificationModel> _notifications = [];

  List<AppNotificationModel> get notifications => _notifications;
  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;

  final List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => _tasks;

  /// Owner giao thêm Farmer cho task (POST .../assignees). Trả về lỗi hoặc null.
  Future<String?> addTaskAssignees(String taskId, List<String> farmerIds) =>
      _replaceTask(taskId, () => TaskApi.addTaskAssignees(_selectedFarmId, taskId, farmerIds));

  /// Owner gỡ một Farmer khỏi task (DELETE .../assignees/{farmerId}). Trả về lỗi hoặc null.
  Future<String?> removeTaskAssignee(String taskId, String farmerId) =>
      _replaceTask(taskId, () => TaskApi.removeTaskAssignee(_selectedFarmId, taskId, farmerId));

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

  // ─────────────────────────────────────────
  // Schedules (lịch tưới) – Seeded + loaded from API
  // ─────────────────────────────────────────
  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> get schedules => _schedules;
  bool _schedulesLoading = false;
  bool get schedulesLoading => _schedulesLoading;

  // ─────────────────────────────────────────
  // Vấn đề 6: Default Crop Profiles (Seed Data)
  // ─────────────────────────────────────────
  String? _appliedCropId;
  String? get appliedCropId => _appliedCropId;

  /// Thư viện cây trồng: nạp từ API (hồ sơ sinh trưởng), không còn danh sách cứng trong ứng dụng.
  final List<DefaultCropProfile> defaultCropProfiles = [];

  // ─────────────────────────────────────────
  // Automation Rules & Schedules State
  // ─────────────────────────────────────────
  final List<AutomationRuleModel> _automationRules = [];
  List<AutomationRuleModel> get automationRules => _automationRules;

  // ─────────────────────────────────────────
  // KHO VẬT TƯ & PHÂN BÓN NÔNG NGHIỆP (INVENTORY)
  // ─────────────────────────────────────────
  final List<MaterialInventoryModel> _inventoryItems = [];

  List<MaterialInventoryModel> get inventoryItems => _inventoryItems;

  List<MaterialInventoryModel> get inventoryItemsForCurrentFarm =>
      _inventoryItems.where((i) => i.farmId == _selectedFarmId).toList();

  int get lowStockCount => inventoryItemsForCurrentFarm.where((i) => i.isLowStock).length;
}
