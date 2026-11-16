import '../../core/models/models.dart';

/// Trạng thái actuator mà backend coi là chưa nhận được lệnh (node offline/cần bảo trì...): bấm điều khiển chỉ nhận lỗi 409.
const _notReadyStatuses = {
  'MAINTENANCE',
  'OFFLINE',
  'FAULT',
  'ERROR',
  'DECOMMISSIONED',
};

/// Lý do chưa điều khiển được (tiếng Việt), null khi thiết bị sẵn sàng.
String? actuatorNotReadyReason(ActuatorModel a) {
  final s = a.status.toUpperCase();
  if (!_notReadyStatuses.contains(s)) return null;
  return switch (s) {
    'MAINTENANCE' => 'Đang bảo trì/node chưa sẵn sàng nhận lệnh',
    'OFFLINE' => 'Node đang offline',
    _ => 'Thiết bị đang lỗi hoặc đã ngừng',
  };
}

/// Mô tả vị trí vật lý của kênh điều khiển: "Node 2 · Cổng 3". Một node van 4 cổng sinh ra 4 actuator cùng tên
/// ("… #1".."#4"), nên Zone có nhiều node thì tên bị trùng; số node (theo thứ tự ổn định) + cổng relay giúp phân biệt.
/// null khi backend không trả đủ thông tin.
String? actuatorPlaceLabel(ActuatorModel a, Iterable<ActuatorModel> all) {
  final nodes = {
    for (final x in all)
      if (x.deviceId.isNotEmpty) x.deviceId.toLowerCase(),
  }.toList()..sort();
  final parts = <String>[];
  if (nodes.length > 1 && a.deviceId.isNotEmpty) {
    parts.add(
      'Node ${nodes.indexOf(a.deviceId.toLowerCase()) + 1}/${nodes.length}',
    );
  }
  if (a.relayChannel != null) parts.add('Cổng relay ${a.relayChannel}');
  return parts.isEmpty ? null : parts.join(' · ');
}

/// "8 kênh · 2 node": số kênh relay điều khiển và số node chứa chúng (không gọi mỗi kênh là một "thiết bị").
String relaySummary(Iterable<ActuatorModel> acts) {
  final list = acts.toList();
  if (list.isEmpty) return '0 kênh';
  final nodes = {
    for (final a in list)
      if (a.deviceId.isNotEmpty) a.deviceId.toLowerCase(),
  };
  return nodes.isEmpty
      ? '${list.length} kênh'
      : '${list.length} kênh · ${nodes.length} node';
}

/// Số node thật của Zone từ danh sách node (telemetry/latest-by-device hoặc /devices): tổng, cảm biến, điều khiển, giả lập, online.
({int total, int sensors, int actuators, int simulated, int online})
countZoneNodes(Iterable<Map<String, dynamic>> nodes) {
  var sensors = 0, actuators = 0, sim = 0, online = 0, total = 0;
  for (final n in nodes) {
    total++;
    final type = '${n['deviceType']}'.toLowerCase();
    if (type == 'sensornode') sensors++;
    if (type == 'actuatornode') actuators++;
    if ('${n['hardwareAddress'] ?? ''}'.toUpperCase().startsWith('SIM-')) sim++;
    if ('${n['status']}' == 'Online') online++;
  }
  return (
    total: total,
    sensors: sensors,
    actuators: actuators,
    simulated: sim,
    online: online,
  );
}
