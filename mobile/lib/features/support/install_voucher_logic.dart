/// Phiếu xuất kho của hợp đồng lắp đặt (Luồng 1): kỹ thuật viên tạo phiếu chứa các thiết bị trong hợp đồng và gửi Admin duyệt;
/// chỉ khi Admin duyệt mới được chấm/gắn Node. Phiếu liên kết với luồng qua `StockOuts.ServiceRequestId` → `service_requests`
/// (API trả `serviceRequestId`), nên biết chắc phiếu thuộc yêu cầu nào. Phiếu cũ chưa có liên kết vẫn được nhận ra theo MÃ HỢP ĐỒNG
/// ghi trong ghi chú (`HD-SR-<8 ký tự đầu của id báo giá>`).
library;

/// Giai đoạn của phiếu xuất kho theo hợp đồng.
enum VoucherPhase {
  /// Chưa có phiếu nào cho hợp đồng.
  none,

  /// Bản nháp (đã tạo, chưa gửi duyệt).
  draft,

  /// Đã gửi, chờ Admin duyệt.
  pending,

  /// Admin đã duyệt (hoặc đã xuất kho xong).
  approved,

  /// Phiếu bị hủy (cần tạo phiếu mới).
  cancelled,
}

/// Mã hợp đồng dùng trong ghi chú phiếu, trùng backend (`HD-SR-` + 8 ký tự đầu id báo giá, chữ hoa).
String installContractNumber(String quotationId) {
  final head = quotationId.length >= 8
      ? quotationId.substring(0, 8)
      : quotationId;
  return 'HD-SR-${head.toUpperCase()}';
}

class InstallVoucher {
  final String id;
  final String code;
  final VoucherPhase phase;
  final String statusText;
  final String? notes;
  final String? serviceRequestId;
  final List<String> itemLines;
  const InstallVoucher({
    required this.id,
    required this.code,
    required this.phase,
    required this.statusText,
    this.notes,
    this.serviceRequestId,
    this.itemLines = const [],
  });

  factory InstallVoucher.fromJson(Map<String, dynamic> j) => InstallVoucher(
    id: '${j['id']}',
    code: '${j['stockOutCode'] ?? ''}',
    phase: phaseOfStatus('${j['status']}'),
    statusText: '${j['statusText'] ?? j['status']}',
    notes: j['notes'] as String?,
    serviceRequestId: _nonEmpty(j['serviceRequestId']),
    itemLines: [
      for (final d in (j['details'] as List? ?? const []))
        if (d is Map) '${d['itemName']} × ${_q(d['quantity'])}',
    ],
  );
}

String? _nonEmpty(Object? v) {
  final t = '${v ?? ''}'.trim();
  return t.isEmpty || t == 'null' ? null : t;
}

String _q(Object? v) => v is num
    ? (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1))
    : '$v';

/// Trạng thái backend (tên enum, hoặc số: 0 Draft, 1 Pending, 2 Approved, 3 Completed, 4 Cancelled) → giai đoạn.
VoucherPhase phaseOfStatus(String raw) {
  switch (raw.toLowerCase()) {
    case 'draft' || '0':
      return VoucherPhase.draft;
    case 'pending' || '1':
      return VoucherPhase.pending;
    case 'approved' || '2' || 'completed' || '3':
      return VoucherPhase.approved;
    case 'cancelled' || '4':
      return VoucherPhase.cancelled;
    default:
      return VoucherPhase.none;
  }
}

/// Chọn phiếu của luồng trong danh sách phiếu của Farm: khớp theo `serviceRequestId` mà backend trả; phiếu cũ chưa gắn yêu cầu
/// thì theo mã [contractNumber] trong ghi chú. Nhiều phiếu: ưu tiên đã duyệt > chờ duyệt > nháp > hủy,
/// rồi mới nhất (phiếu hủy chỉ được chọn khi không còn phiếu nào khác).
InstallVoucher? pickInstallVoucher(
  Iterable<Map<String, dynamic>> stockOuts,
  String contractNumber, {
  String? zoneId,
  String? serviceRequestId,
}) {
  final marker = contractNumber.toUpperCase();
  bool linked(Map<String, dynamic> s) {
    // Liên kết yêu cầu dịch vụ là căn cứ chắc chắn nhất: đã gắn yêu cầu nào thì CHỈ thuộc yêu cầu đó.
    final sid = _nonEmpty(s['serviceRequestId']);
    if (sid != null && serviceRequestId != null) {
      return sid.toLowerCase() == serviceRequestId.toLowerCase();
    }
    // Phiếu cũ chưa gắn yêu cầu dịch vụ: nhận theo mã hợp đồng trong ghi chú.
    return '${s['notes'] ?? ''}'.toUpperCase().contains(marker);
  }

  final mine = [
    for (final s in stockOuts)
      if (linked(s) &&
          (zoneId == null ||
              zoneId.isEmpty ||
              '${s['zoneId'] ?? ''}'.isEmpty ||
              '${s['zoneId']}'.toLowerCase() == zoneId.toLowerCase()))
        s,
  ];
  if (mine.isEmpty) return null;
  int rank(Map<String, dynamic> s) => switch (phaseOfStatus('${s['status']}')) {
    VoucherPhase.approved => 0,
    VoucherPhase.pending => 1,
    VoucherPhase.draft => 2,
    VoucherPhase.cancelled => 3,
    VoucherPhase.none => 4,
  };
  mine.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return '${b['createdAtUtc']}'.compareTo('${a['createdAtUtc']}');
  });
  return InstallVoucher.fromJson(mine.first);
}

/// Dòng thiết bị của phiếu dựng từ các dòng hợp đồng: khớp theo MÃ với danh mục thiết bị phần cứng.
/// Dòng không khớp (không có mã trong kho) được trả riêng để báo, không bịa ID.
({List<Map<String, dynamic>> details, List<String> unmatched})
buildVoucherDetails(
  Iterable<({String code, String name, int quantity})> contractItems,
  Iterable<Map<String, dynamic>> hardwareItems,
) {
  final byCode = {
    for (final h in hardwareItems)
      if ('${h['code'] ?? ''}'.trim().isNotEmpty)
        '${h['code']}'.trim().toUpperCase(): h,
  };
  final details = <Map<String, dynamic>>[];
  final unmatched = <String>[];
  for (final it in contractItems) {
    if (it.quantity <= 0) continue;
    final hw = byCode[it.code.trim().toUpperCase()];
    final id = hw == null ? null : '${hw['id'] ?? hw['hardwareItemId'] ?? ''}';
    if (id == null || id.isEmpty || id == 'null') {
      unmatched.add('${it.code.isEmpty ? it.name : it.code} × ${it.quantity}');
      continue;
    }
    // Cùng mã xuất hiện ở nhiều dòng hợp đồng thì cộng dồn.
    final existing = details
        .where((d) => d['inventoryItemId'] == id)
        .firstOrNull;
    if (existing != null) {
      existing['quantity'] = (existing['quantity'] as int) + it.quantity;
    } else {
      details.add({
        'inventoryItemId': id,
        'quantity': it.quantity,
        'notes': 'Theo hợp đồng: ${it.name}',
      });
    }
  }
  return (details: details, unmatched: unmatched);
}

/// Ghi chú phiếu: chứa mã hợp đồng để nhận lại phiếu của đúng hợp đồng.
String installVoucherNotes(String contractNumber) =>
    '[Kỹ thuật viên tạo từ HĐ #$contractNumber] Xuất thiết bị IoT theo hợp đồng lắp đặt, gửi Admin duyệt trước khi gắn Node.';

/// Lý do chưa được gắn Node theo giai đoạn phiếu; null khi đã được duyệt. [phase] null = chưa đọc được phiếu.
String? voucherBlockMessage(VoucherPhase? phase, {String? code}) {
  final c = code == null || code.isEmpty ? '' : ' $code';
  return switch (phase) {
    null =>
      'Chưa xác nhận được phiếu xuất kho của hợp đồng từ backend. Hãy tải lại.',
    VoucherPhase.none =>
      'Cần tạo phiếu xuất kho các thiết bị trong hợp đồng và gửi Admin duyệt trước khi gắn Node.',
    VoucherPhase.draft =>
      'Phiếu xuất kho$c mới ở bản nháp: hãy gửi Admin duyệt để được gắn Node.',
    VoucherPhase.pending =>
      'Phiếu xuất kho$c đang chờ Admin duyệt. Admin duyệt xong mới gắn Node được.',
    VoucherPhase.cancelled =>
      'Phiếu xuất kho$c đã bị hủy. Hãy tạo phiếu mới và gửi Admin duyệt.',
    VoucherPhase.approved => null,
  };
}
