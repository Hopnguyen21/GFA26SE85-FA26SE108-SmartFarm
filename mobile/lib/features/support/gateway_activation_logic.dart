/// Kích hoạt Gateway cho yêu cầu lắp đặt. Backend đã tắt cấp phát Gateway thủ công (`POST /gateways` trả 410): Gateway phần cứng nằm
/// trong kho của KTV, tự đăng ký (enrollment) khi bật nguồn + có mạng, rồi KTV kích hoạt cho đúng yêu cầu.
/// Chưa có phần cứng thật thì dùng MÔ PHỎNG: app đóng vai thiết bị gọi API tự đăng ký bằng MAC của Gateway có trong kho KTV.
library;

/// Một Gateway trong kho của KTV kèm trạng thái đăng ký.
class GatewayChoice {
  final String hardwareItemId;
  final String code;
  final String name;
  final String? serial;
  final String? mac;

  /// Đăng ký của thiết bị này (null = chưa tự đăng ký).
  final String? enrollmentId;
  final String? enrollmentStatus;
  final String? gatewayId;
  const GatewayChoice({
    required this.hardwareItemId,
    required this.code,
    required this.name,
    this.serial,
    this.mac,
    this.enrollmentId,
    this.enrollmentStatus,
    this.gatewayId,
  });

  /// Chỉ Gateway đã đăng ký nhưng chưa kích hoạt mới kích hoạt được.
  bool get canActivate =>
      enrollmentId != null &&
      (enrollmentStatus ?? '').toLowerCase() == 'enrolled';

  bool get activated => (enrollmentStatus ?? '').toLowerCase() == 'activated';

  /// Mô phỏng được khi chưa kích hoạt và có MAC (cần MAC để khớp kho khi tự đăng ký).
  bool get canSimulate => !activated && (mac ?? '').isNotEmpty;

  String get statusText {
    if (enrollmentId == null) {
      return 'Chưa đăng ký: cấp nguồn, kết nối mạng để Gateway tự đăng ký rồi bấm Làm mới (hoặc dùng Mô phỏng)';
    }
    return switch ((enrollmentStatus ?? '').toLowerCase()) {
      'enrolled' => 'Đã đăng ký, sẵn sàng kích hoạt',
      'activated' => 'Đã kích hoạt cho một yêu cầu',
      final s => 'Trạng thái đăng ký: $s',
    };
  }
}

bool _isGatewayItem(Map<String, dynamic> p) =>
    '${p['category'] ?? ''}'.toUpperCase().contains('GATEWAY');

String? _text(Object? v) {
  final s = '${v ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

/// Gateway trong kho của KTV (loại phần cứng chứa "Gateway"); [enrollments] = hardwareItemId → JSON đăng ký (nếu có).
List<GatewayChoice> gatewayChoices(
  Iterable<Map<String, dynamic>> spareParts,
  Map<String, Map<String, dynamic>?> enrollments,
) {
  return [
    for (final p in spareParts)
      if (_isGatewayItem(p) && '${p['id'] ?? ''}'.isNotEmpty)
        GatewayChoice(
          hardwareItemId: '${p['id']}',
          code: '${p['code'] ?? ''}',
          name: '${p['name'] ?? 'Gateway'}',
          serial: _text(p['serialNumber']),
          mac: _text(p['macAddress']),
          enrollmentId: _text(enrollments['${p['id']}']?['id']),
          enrollmentStatus: _text(enrollments['${p['id']}']?['status']),
          gatewayId: _text(enrollments['${p['id']}']?['gatewayId']),
        ),
  ];
}

/// Gateway dùng cho mô phỏng: ưu tiên cái đã đăng ký (chỉ còn kích hoạt), rồi cái chưa đăng ký nhưng có MAC.
GatewayChoice? pickGatewayToSimulate(Iterable<GatewayChoice> all) {
  final list = all.toList();
  return list.where((g) => g.canActivate).firstOrNull ??
      list.where((g) => g.enrollmentId == null && g.canSimulate).firstOrNull;
}

/// Lý do không mô phỏng được (kho KTV không có Gateway dùng được).
String noGatewayToSimulateMessage(Iterable<GatewayChoice> all) {
  final list = all.toList();
  if (list.isEmpty) {
    return 'Kho của bạn chưa có Gateway nào. Nhờ Admin giao Gateway cho tài khoản kỹ thuật viên (Kho linh kiện → Giao cho KTV) rồi mô phỏng lại.';
  }
  if (list.every((g) => g.activated)) {
    return 'Mọi Gateway trong kho của bạn đã được kích hoạt cho yêu cầu khác. Nhờ Admin giao thêm Gateway.';
  }
  return 'Gateway trong kho chưa có địa chỉ MAC nên không mô phỏng được. Nhờ Admin bổ sung MAC cho Gateway.';
}
