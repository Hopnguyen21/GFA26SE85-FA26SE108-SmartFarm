import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gps_service.dart';
import 'node_provisioning_sheet.dart';

/// Một Node trong KHO CỦA KỸ THUẬT VIÊN (hàng nhận từ kho chính qua phiếu xuất kho hoặc Admin giao).
/// Gắn Node = lấy thiết bị này ra khỏi kho KTV (backend trừ tồn / chuyển sang "đã triển khai").
class NodeChoice {
  final String hardwareItemId;
  final String code;
  final String name;
  final String category;
  final String? serial;
  final String? deviceModelId;
  final int quantity;

  /// Vai trò dự toán của hàng trong kho (SensorNode / ActuatorNode / Gateway …) do Admin gán; ưu tiên hơn đoán theo tên.
  final String? estimateRole;

  /// Địa chỉ gợi ý đã đảm bảo chưa dùng (hàng không serial: mã-01, mã-02…); null = dùng serial/mã.
  final String? suggested;
  const NodeChoice({
    required this.hardwareItemId,
    required this.code,
    required this.name,
    required this.category,
    this.serial,
    this.deviceModelId,
    this.quantity = 1,
    this.estimateRole,
    this.suggested,
  });

  /// Node chấp hành (rơ-le/van/bơm) hay cảm biến, suy từ chủng loại kho.
  /// Admin đã gán vai trò rõ (SensorNode/ActuatorNode): loại Node theo HÀNG TRONG KHO, không theo dòng hợp đồng.
  bool get roleKnown => nodeType != null;

  /// Loại Node của hàng (SensorNode/ActuatorNode): vai trò Admin gán, chưa gán thì suy từ chủng loại kho như backend
  /// (VALVE/PUMP/RELAY/ACTUATOR → điều khiển, SENSOR → cảm biến). null = không xác định được.
  String? get nodeType => inferNodeType(estimateRole, category);

  /// Loại thiết bị gửi lên backend khi hàng có vai trò rõ.
  String? get roleDeviceType => nodeType;

  bool get isActuator {
    if (nodeType != null) return nodeType == 'ActuatorNode';
    final c = '$category $name'.toUpperCase();
    if (c.contains('CHẤP HÀNH') || c.contains('CHAP HANH')) return true;
    // So khớp theo TỪ nguyên (không theo chuỗi con) để "ADVANCED" hay "CARAVAN" không bị coi là van.
    final words = c.split(RegExp(r'[^A-ZÀ-Ỹ0-9]+')).toSet();
    return const {
      'ACTUATOR',
      'RELAY',
      'VAN',
      'BƠM',
      'VALVE',
      'PUMP',
    }.any(words.contains);
  }

  /// Địa chỉ phần cứng gợi ý: serial in trên thiết bị, không có thì mã kho.
  String get suggestedAddress => (suggested ?? serial ?? code).trim();
}

/// Suy loại Node: vai trò Admin gán nếu là SensorNode/ActuatorNode; không thì theo chủng loại kho (khớp backend `HardwareStockRules`).
String? inferNodeType(String? estimateRole, String category) {
  if (estimateRole == 'SensorNode' || estimateRole == 'ActuatorNode') {
    return estimateRole;
  }
  if (estimateRole == 'ValveNode' || estimateRole == 'PumpNode') {
    return 'ActuatorNode'; // Van/Bơm là Node điều khiển
  }
  if (estimateRole == 'Gateway' || estimateRole == 'InstallKit') return null;
  final c = category.toUpperCase();
  if (c.contains('ACTUATOR') ||
      c.contains('VALVE') ||
      c.contains('PUMP') ||
      c.contains('RELAY')) {
    return 'ActuatorNode';
  }
  if (c.contains('SENSOR')) return 'SensorNode';
  return null;
}

/// Là Node: vai trò dự toán SensorNode/ActuatorNode (hàng như "SN-SOIL-01" thuộc loại SOIL_SENSOR vẫn là Node cảm biến), hoặc loại có chữ NODE.
bool _isNode(Map<String, dynamic> p) {
  final role = '${p['estimateRole'] ?? ''}';
  final c = '${p['category'] ?? ''}'.toUpperCase();
  // Gateway, bộ lắp đặt, camera, phụ kiện không bao giờ là Node (backend cũng từ chối).
  if (role == 'Gateway' ||
      role == 'InstallKit' ||
      c.contains('GATEWAY') ||
      c.contains('CAMERA') ||
      c.contains('PERIPHERAL')) {
    return false;
  }
  if (inferNodeType(role, '') != null) return true;
  // Hàng chưa gán vai trò chỉ liệt kê khi chủng loại có chữ NODE (van/tủ bơm rời không phải Node).
  return c.contains('NODE');
}

String? _t(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

/// Node còn trong kho KTV (tồn > 0). Hàng theo SERIAL (mỗi dòng một thiết bị) ẩn khi serial đã được cấp phát. Hàng theo SỐ LƯỢNG
/// (không serial) KHÔNG bao giờ bị ẩn khi còn tồn: mỗi lần gắn một Node mới nên gợi ý địa chỉ kế tiếp chưa dùng (mã-01, mã-02…).
List<NodeChoice> nodeChoices(
  Iterable<Map<String, dynamic>> spareParts, {
  Set<String> usedAddresses = const {},
}) {
  final used = usedAddresses.map((e) => e.toUpperCase()).toSet();
  // Địa chỉ hợp lệ 3–64 ký tự: cắt mã dài, mã rỗng dùng "NODE".
  String nextFree(String code) {
    final base = code.trim().isEmpty
        ? 'NODE'
        : (code.trim().length > 58
              ? code.trim().substring(0, 58)
              : code.trim());
    var n = 1;
    String cand() => '$base-${n.toString().padLeft(2, '0')}';
    while (used.contains(cand().toUpperCase())) {
      n++;
    }
    return cand();
  }

  final out = <NodeChoice>[];
  for (final p in spareParts) {
    if (!_isNode(p) ||
        '${p['id'] ?? ''}'.isEmpty ||
        ((p['quantityInStock'] ?? p['quantity'] ?? 1) as num) <= 0) {
      continue;
    }
    final serial = _t(p['serialNumber']);
    final code = '${p['code'] ?? ''}';
    if (serial != null && used.contains(serial.toUpperCase())) continue;
    out.add(
      NodeChoice(
        hardwareItemId: '${p['id']}',
        code: code,
        name: '${p['name'] ?? 'Node'}',
        category: '${p['category'] ?? ''}',
        serial: serial,
        deviceModelId: _t(p['deviceModelDefinitionId']),
        estimateRole: _t(p['estimateRole']),
        quantity: ((p['quantityInStock'] ?? p['quantity'] ?? 1) as num).toInt(),
        suggested: serial == null ? nextFree(code) : null,
      ),
    );
  }
  return out;
}

Future<List<NodeChoice>> loadNodeChoices({
  Set<String> usedAddresses = const {},
}) async => nodeChoices(
  await DeploymentApi.getTechnicianSpareParts(),
  usedAddresses: usedAddresses,
);

/// Địa chỉ phần cứng hợp lệ cho backend: 3–64 ký tự, không khoảng trắng.
String? validateNodeAddress(String v) {
  final s = v.trim();
  if (s.length < 3 || s.length > 64 || s.contains(RegExp(r'\s'))) {
    return 'Nhập địa chỉ phần cứng 3–64 ký tự, không có khoảng trắng.';
  }
  return null;
}

/// Mở bảng chọn Node từ kho KTV; [provision] nhận Node đã chọn, địa chỉ phần cứng và địa chỉ nơi lắp đặt (tuỳ chọn), gọi API cấp phát (backend trừ kho KTV).
/// Trả true khi đã cấp phát được.
Future<bool> showNodeProvisionSheet(
  BuildContext context, {
  required String slotLabel,
  required bool actuator,
  String? slotCode,
  Map<String, bool> contractKinds = const {},
  required Set<String> usedAddresses,
  required Future<void> Function(
    NodeChoice node,
    String address,
    String? installAddress,
  )
  provision,
  GpsProvider gps = const GeolocatorGpsProvider(),
  Future<GeocodeResult> Function(double lat, double lng)? addressLookup,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => NodeProvisionSheet(
        slotLabel: slotLabel,
        actuator: actuator,
        slotCode: slotCode,
        contractKinds: contractKinds,
        // [taken] = địa chỉ backend đã báo trùng ở nơi khác (địa chỉ phần cứng là duy nhất toàn hệ thống).
        load: (taken) =>
            loadNodeChoices(usedAddresses: {...usedAddresses, ...taken}),
        provision: provision,
        gps: gps,
        addressLookup: addressLookup,
      ),
    ) ??
    false;

/// Backend báo địa chỉ phần cứng đã được cấp phát ở nơi khác (duy nhất toàn hệ thống).
bool isAddressConflict(Object error) {
  final t = '$error'.toLowerCase();
  return t.contains('already provisioned') ||
      (t.contains('hardware address') && t.contains('already'));
}
