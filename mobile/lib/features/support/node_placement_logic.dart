/// Logic thuần cho màn Chấm Node: thiết bị cần chấm lấy từ dòng hợp đồng, kiểm tra điểm trong Zone / độ chính xác GPS,
/// và điều kiện hoàn tất lắp đặt. Tách khỏi giao diện để kiểm thử.
library;

import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart' show BusinessParameters;

String get _dep => BusinessParameters.active.depositLabel;
String get _rem => BusinessParameters.active.remainingLabel;

enum NodeKind { gateway, sensor, actuator }

extension NodeKindX on NodeKind {
  String get label => switch (this) {
    NodeKind.gateway => 'Gateway',
    NodeKind.sensor => 'Node cảm biến',
    NodeKind.actuator => 'Node điều khiển',
  };
}

/// Loại thiết bị của một dòng hợp đồng; null nếu là vật tư, thi công hoặc hạng mục không phải thiết bị chấm điểm.
/// Chỉ nhận đúng nhóm GATEWAY, SENSOR*, ACTUATOR*: không biến mọi dòng "thiết bị" thành Node.
NodeKind? nodeKindOfCategory(String category) {
  final c = category.toUpperCase();
  if (c.contains('GATEWAY')) return NodeKind.gateway;
  if (c.contains('SENSOR') || c.contains('PROBE')) return NodeKind.sensor;
  // Hợp đồng cũ/nhập tay dùng nhiều tên: ACTUATOR_NODE, VALVE, PUMP, RELAY, CONTROLLER...
  if (c.contains('ACTUATOR') ||
      c.contains('VALVE') ||
      c.contains('PUMP') ||
      c.contains('RELAY') ||
      c.contains('CONTROLLER')) {
    return NodeKind.actuator;
  }
  return null;
}

/// Loại thiết bị của một DÒNG hợp đồng: theo danh mục; danh mục không rõ (HARDWARE, nhập tay...) thì suy theo mã (GW-, SN-, ACT-)
/// rồi theo tên (Gateway, Cảm biến, Điều khiển, Van). Vật tư, phụ kiện, thi công, công lắp đặt không bao giờ thành thiết bị chấm.
NodeKind? nodeKindOfItem(QuotationItem i) {
  final byCategory = nodeKindOfCategory(i.category);
  if (byCategory != null) return byCategory;
  final c = i.category.toUpperCase();
  const notDevice = [
    'ACCESSORY',
    'SERVICE',
    'LABOR',
    'KIT',
    'CABLE',
    'INSTALL',
  ];
  if (notDevice.any(c.contains)) return null;
  final code = i.code.toUpperCase();
  if (code.startsWith('GW')) return NodeKind.gateway;
  if (code.startsWith('SN')) return NodeKind.sensor;
  if (code.startsWith('ACT')) return NodeKind.actuator;
  final name = i.name.toLowerCase();
  if (name.contains('gateway')) return NodeKind.gateway;
  if (name.contains('cảm biến') || name.contains('sensor')) {
    return NodeKind.sensor;
  }
  if (name.contains('điều khiển') ||
      name.contains('van ') ||
      name.contains('valve')) {
    return NodeKind.actuator;
  }
  return null;
}

/// Loại thiết bị đã cấp phát theo `deviceType` của backend (SensorNode, ActuatorNode); null nếu không rõ.
NodeKind? nodeKindOfDeviceType(String deviceType) {
  final t = deviceType.toUpperCase();
  if (t.contains('SENSOR')) return NodeKind.sensor;
  if (t.contains('ACTUATOR')) return NodeKind.actuator;
  return null;
}

/// Số thiết bị mỗi loại theo hợp đồng (cộng số lượng các dòng cùng loại); chỉ gồm loại có trong hợp đồng.
Map<NodeKind, int> contractUnitsByKind(List<QuotationItem> items) {
  final out = <NodeKind, int>{};
  for (final i in items) {
    final k = nodeKindOfItem(i);
    if (k == null || i.quantity <= 0) continue;
    out[k] = (out[k] ?? 0) + i.quantity;
  }
  return out;
}

/// Số thiết bị đã cấp phát theo loại (Node cảm biến, Node điều khiển); Gateway tính riêng vì là thực thể khác.
Map<NodeKind, int> provisionedUnitsByKind({
  required List<IotDevice> devices,
  required int gateways,
}) {
  final out = <NodeKind, int>{if (gateways > 0) NodeKind.gateway: gateways};
  for (final d in devices) {
    final k = nodeKindOfDeviceType(d.deviceType);
    if (k != null) out[k] = (out[k] ?? 0) + 1;
  }
  return out;
}

/// Điểm có nằm trong đa giác không (ray casting trên toạ độ lat/lng; đủ chính xác với Zone nhỏ).
bool pointInPolygon(
  double lat,
  double lng,
  List<({double lat, double lng})> polygon,
) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    final crosses =
        (a.lat > lat) != (b.lat > lat) &&
        lng < (b.lng - a.lng) * (lat - a.lat) / (b.lat - a.lat) + a.lng;
    if (crosses) inside = !inside;
  }
  return inside;
}

/// Ngưỡng sai số GPS coi là đủ tốt để chốt điểm Node (mét).
const double gpsGoodAccuracyM = 15;

/// Sai số tệ hơn mức này thì không cho chốt điểm (mét).
const double gpsRejectAccuracyM = 50;

enum FixVerdict { ok, poorAccuracy, tooInaccurate, outsideZone, noBoundary }

/// Đánh giá một điểm GPS: ngoài ranh giới Zone thì chặn; sai số lớn thì cảnh báo hoặc chặn.
/// Zone chưa có ranh giới ([noBoundary]) thì không kiểm tra được điểm có thuộc Zone không.
FixVerdict evaluateFix({
  required double lat,
  required double lng,
  required double accuracyM,
  required List<({double lat, double lng})>? polygon,
}) {
  if (polygon == null || polygon.length < 3) return FixVerdict.noBoundary;
  if (!pointInPolygon(lat, lng, polygon)) return FixVerdict.outsideZone;
  if (accuracyM > gpsRejectAccuracyM) return FixVerdict.tooInaccurate;
  if (accuracyM > gpsGoodAccuracyM) return FixVerdict.poorAccuracy;
  return FixVerdict.ok;
}

/// Vì sao chưa thể bấm "Hoàn tất lắp đặt" (rỗng = đủ điều kiện phía app; backend vẫn kiểm tra lại).
/// [placed] là tập deviceId đã có vị trí trên máy chủ; kiểm tra kết nối lấy từ `latestTest` của thiết bị.
List<String> completionBlockers({
  required String deploymentStatus,
  required List<IotDevice> devices,
  required Set<String> placed,
  required Map<NodeKind, int> contractUnits,
  required Map<NodeKind, int> provisioned,
}) {
  final out = <String>[];
  if (deploymentStatus != 'Installing') {
    out.add('Triển khai chưa ở bước Đang lắp đặt (hiện: $deploymentStatus).');
    return out;
  }
  for (final e in contractUnits.entries) {
    final have = provisioned[e.key] ?? 0;
    if (have < e.value) {
      out.add('${e.key.label}: mới cấp phát $have/${e.value} theo hợp đồng.');
    }
  }
  if (devices.isEmpty) {
    out.add('Chưa có thiết bị nào được cấp phát.');
  }
  for (final d in devices) {
    final id = d.deviceId;
    if (!placed.contains(id.toLowerCase())) {
      out.add('${d.hardwareAddress}: chưa có vị trí trên máy chủ.');
    }
    final t = d.latestTest;
    if (t == null) {
      out.add('${d.hardwareAddress}: chưa ghi kiểm tra kết nối.');
    } else if (!t.succeeded) {
      out.add('${d.hardwareAddress}: kiểm tra kết nối gần nhất không đạt.');
    }
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Điều kiện được mở "Gắn Node": MỘT nơi duy nhất cho thẻ, chi tiết, hàm điều hướng và màn Gắn Node.
// ─────────────────────────────────────────────────────────────────────────────

/// Trạng thái báo giá mà backend đặt cùng lúc với khoản cọc 30%: `SignContractDepositAsync` ghi `SignedByOwner`,
/// tạo thanh toán DEPOSIT_30 (Confirmed) và bật IsContractSigned + IsDepositPaid trong MỘT giao dịch.
/// `DepositPaid` là tên trạng thái backend nhận diện nhưng hiện không phát ra. `Completed` = đã nghiệm thu 70%
/// (kết thúc), KHÔNG dùng để mở gắn Node. API không trả riêng cờ IsDepositPaid, nên trạng thái báo giá là căn cứ duy nhất.
const depositConfirmedQuotationStatuses = {'SignedByOwner', 'DepositPaid'};

/// Phiếu dịch vụ đã kết thúc.
const terminalServiceStatuses = {'Closed', 'Resolved', 'Cancelled'};

/// Triển khai đã kết thúc (hoàn tất, hủy, hoặc chuyển bảo trì): không gắn thêm Node dù đã cọc.
const terminalDeploymentStatuses = {
  'Completed',
  'Cancelled',
  'MaintenanceRequired',
};

enum NodePlacementBlock {
  /// Chưa đọc được báo giá/phiếu (lỗi, đang tải, dữ liệu cũ): khoá, không đoán.
  unknown,

  /// Chưa có báo giá, hoặc chưa ký + cọc 30%.
  unpaid,

  /// Phiếu dịch vụ đã đóng / báo giá đã nghiệm thu.
  serviceFinished,

  /// Triển khai đã hoàn tất, hủy hoặc chuyển bảo trì.
  deploymentFinished,

  /// Triển khai gắn kèm không đọc được hoặc sai Farm/Zone/mã liên kết.
  wrongLink,
}

class NodePlacementGate {
  final bool allowed;
  final NodePlacementBlock? block;
  final String message;
  const NodePlacementGate.allow() : allowed = true, block = null, message = '';
  const NodePlacementGate.deny(NodePlacementBlock this.block, this.message)
    : allowed = false;
}

/// Liên kết triển khai của phiếu hợp lệ: có mã, không phải mã rỗng/0, đọc được và cùng Farm + Zone + mã với phiếu.
bool deploymentLinkValid({
  required String serviceFarmId,
  required String serviceZoneId,
  required String serviceDeploymentId,
  required String? deploymentId,
  required String? deploymentFarmId,
  required String? deploymentZoneId,
}) {
  bool ok(String? v) =>
      v != null && v.isNotEmpty && !v.startsWith('00000000-0000-0000-0000-');
  if (!ok(serviceDeploymentId) || !ok(serviceZoneId)) return false;
  if (deploymentId == null ||
      deploymentFarmId == null ||
      deploymentZoneId == null) {
    return false;
  }
  return serviceDeploymentId.toLowerCase() == deploymentId.toLowerCase() &&
      serviceZoneId.toLowerCase() == deploymentZoneId.toLowerCase() &&
      (serviceFarmId.isEmpty ||
          serviceFarmId.toLowerCase() == deploymentFarmId.toLowerCase());
}

/// Quyết định có được mở/giữ màn Gắn Node. Chỉ dựa trên dữ liệu backend vừa đọc:
/// - báo giá: [quotationLoaded] phải true (đọc lỗi/chưa đọc = khoá), trạng thái phải là ký + cọc 30%;
/// - phiếu và triển khai chưa kết thúc; triển khai gắn đúng ([linkValid]);
/// - KHÔNG phụ thuộc triển khai đã Xác nhận kế hoạch/Đang lắp đặt hay chưa, và không tự đẩy trạng thái nào.
NodePlacementGate checkNodePlacement({
  required String? serviceStatus,
  required bool quotationLoaded,
  required String? quotationStatus,
  required String? deploymentStatus,
  required bool linkValid,
  String? depositLabel,
  String? remainingLabel,
}) {
  if (serviceStatus == null || !quotationLoaded) {
    return NodePlacementGate.deny(
      NodePlacementBlock.unknown,
      'Chưa xác nhận được hợp đồng và khoản cọc $_dep từ backend. Hãy tải lại.',
    );
  }
  if (terminalServiceStatuses.contains(serviceStatus) ||
      quotationStatus == 'Completed') {
    return const NodePlacementGate.deny(
      NodePlacementBlock.serviceFinished,
      'Công việc đã kết thúc, không thể gắn thêm Node.',
    );
  }
  if (!depositConfirmedQuotationStatuses.contains(quotationStatus)) {
    return NodePlacementGate.deny(
      NodePlacementBlock.unpaid,
      'Chờ Owner ký hợp đồng và thanh toán cọc $_dep (backend chưa xác nhận) mới gắn Node.',
    );
  }
  if (!linkValid || deploymentStatus == null) {
    return const NodePlacementGate.deny(
      NodePlacementBlock.wrongLink,
      'Yêu cầu triển khai gắn với phiếu không đọc được hoặc sai Farm/Zone. Cần kiểm tra liên kết trước khi gắn Node.',
    );
  }
  if (terminalDeploymentStatuses.contains(deploymentStatus)) {
    return NodePlacementGate.deny(
      NodePlacementBlock.deploymentFinished,
      deploymentStatus == 'Completed'
          ? 'Đã hoàn tất lắp đặt. Owner thanh toán $_rem và nghiệm thu ở bước tiếp theo; không thể gắn thêm Node.'
          : 'Triển khai đã ${deploymentStatus == 'Cancelled' ? 'bị hủy' : 'chuyển sang bảo trì'}, không thể gắn thêm Node.',
    );
  }
  return const NodePlacementGate.allow();
}

// ─────────────────────────────────────────────────────────────────────────────
// Danh sách thiết bị theo HỢP ĐỒNG: mỗi đơn vị Gateway / Node cảm biến / Node điều khiển trong dòng hợp đồng là một "chỗ".
// Chỗ nào có thiết bị đã cấp phát thì gắn vào (chấm vị trí được); chưa cấp phát thì hiện là chưa có (không tạo thiết bị giả).
// ─────────────────────────────────────────────────────────────────────────────

class ContractSlot {
  final NodeKind kind;
  final String code;
  final String name;

  /// Thứ tự trong dòng hợp đồng (1..[of]).
  final int ordinal;
  final int of;
  const ContractSlot({
    required this.kind,
    required this.code,
    required this.name,
    required this.ordinal,
    required this.of,
  });

  String get label => of > 1 ? '$name ($ordinal/$of)' : name;
}

/// Tách các dòng hợp đồng Gateway/Node thành từng đơn vị; vật tư, thi công và số lượng ≤ 0 bị bỏ.
/// [maxUnits] chặn dòng có số lượng quá lớn làm treo giao diện.
List<ContractSlot> contractSlots(
  List<QuotationItem> items, {
  int maxUnits = 200,
}) {
  final out = <ContractSlot>[];
  for (final i in items) {
    final k = nodeKindOfItem(i);
    if (k == null || i.quantity <= 0) continue;
    for (var n = 1; n <= i.quantity && out.length < maxUnits; n++) {
      out.add(
        ContractSlot(
          kind: k,
          code: i.code,
          name: i.name,
          ordinal: n,
          of: i.quantity,
        ),
      );
    }
  }
  return out;
}

class SlotMatch {
  final ContractSlot slot;
  final IotDevice? device;
  const SlotMatch(this.slot, this.device);
}

/// Ghép Node đã cấp phát vào các chỗ Node cảm biến / điều khiển của hợp đồng theo loại, theo thứ tự (địa chỉ phần cứng tăng dần).
/// Trả về từng chỗ (có thể chưa có thiết bị) và các thiết bị dư không có chỗ trong hợp đồng.
({List<SlotMatch> slots, List<IotDevice> extras}) matchNodeSlots(
  List<ContractSlot> slots,
  List<IotDevice> devices,
) {
  final pool = <NodeKind, List<IotDevice>>{
    for (final k in [NodeKind.sensor, NodeKind.actuator])
      k: [
        for (final d in devices)
          if (nodeKindOfDeviceType(d.deviceType) == k) d,
      ]..sort((a, b) => a.hardwareAddress.compareTo(b.hardwareAddress)),
  };
  final matches = <SlotMatch>[];
  for (final s in slots) {
    if (s.kind == NodeKind.gateway) continue;
    final list = pool[s.kind]!;
    matches.add(SlotMatch(s, list.isEmpty ? null : list.removeAt(0)));
  }
  final extras = <IotDevice>[
    ...pool[NodeKind.sensor]!,
    ...pool[NodeKind.actuator]!,
    for (final d in devices)
      if (nodeKindOfDeviceType(d.deviceType) == null) d,
  ];
  return (slots: matches, extras: extras);
}

/// Ghép Gateway đã cấp phát vào các chỗ Gateway của hợp đồng theo thứ tự.
List<({ContractSlot slot, Map<String, dynamic>? gateway})> matchGatewaySlots(
  List<ContractSlot> slots,
  List<Map<String, dynamic>> gateways,
) {
  final pool = [...gateways];
  return [
    for (final s in slots)
      if (s.kind == NodeKind.gateway)
        (slot: s, gateway: pool.isEmpty ? null : pool.removeAt(0)),
  ];
}

/// Các dòng hợp đồng KHÔNG chấm vị trí được (vật tư, phụ kiện, thi công…): hiện để KTV thấy đủ hạng mục hợp đồng, chỉ xem.
List<QuotationItem> contractNonPlaceableLines(List<QuotationItem> items) => [
  for (final i in items)
    if (nodeKindOfItem(i) == null && i.quantity > 0) i,
];
