/// Phiếu xuất kho thiết bị IoT: logic thuần (parse, lọc, nhãn) dùng cho màn "Phiếu xuất kho" của kỹ thuật viên,
/// theo trang Quản lý Nhập & Xuất Kho trên web (`StockOutsPage`): mã phiếu, Zone nhận, "N loại thiết bị (M cái)", người lập,
/// ngày lập, trạng thái, bộ lọc trạng thái và tìm kiếm theo mã / Zone / ghi chú.
library;

/// Trạng thái phiếu theo backend (tên enum hoặc số 0–4).
enum StockOutStatus {
  draft('Bản nháp'),
  pending('Chờ duyệt'),
  approved('Đã duyệt'),
  completed('Hoàn thành'),
  cancelled('Đã hủy');

  final String label;
  const StockOutStatus(this.label);

  static StockOutStatus parse(Object? raw) {
    switch ('${raw ?? ''}'.toLowerCase()) {
      case 'pending' || '1':
        return StockOutStatus.pending;
      case 'approved' || '2':
        return StockOutStatus.approved;
      case 'completed' || '3':
        return StockOutStatus.completed;
      case 'cancelled' || '4':
        return StockOutStatus.cancelled;
      default:
        return StockOutStatus.draft;
    }
  }
}

class StockOutLine {
  final String itemName;
  final String unit;
  final num quantity;
  final num currentStock;
  final String? notes;
  const StockOutLine({
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.currentStock,
    this.notes,
  });

  factory StockOutLine.fromJson(Map<String, dynamic> j) => StockOutLine(
    itemName: '${j['itemName'] ?? 'Thiết bị'}',
    unit: '${j['unit'] ?? 'Cái'}',
    quantity: (j['quantity'] as num?) ?? 0,
    currentStock: (j['currentStock'] as num?) ?? 0,
    notes: _text(j['notes']),
  );
}

class StockOutDoc {
  final String id;
  final String code;
  final StockOutStatus status;
  final String? zoneId;
  final String? zoneName;
  final String createdByName;
  final String? approvedByName;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? notes;
  final String? serviceRequestId;
  final List<StockOutLine> lines;
  const StockOutDoc({
    required this.id,
    required this.code,
    required this.status,
    required this.zoneId,
    required this.zoneName,
    required this.createdByName,
    required this.approvedByName,
    required this.createdAt,
    required this.completedAt,
    required this.notes,
    required this.serviceRequestId,
    required this.lines,
  });

  factory StockOutDoc.fromJson(Map<String, dynamic> j) => StockOutDoc(
    id: '${j['id']}',
    code: '${j['stockOutCode'] ?? ''}',
    status: StockOutStatus.parse(j['status']),
    zoneId: _text(j['zoneId']),
    zoneName: _text(j['zoneName']),
    createdByName: '${j['createdByName'] ?? 'N/A'}',
    approvedByName: _text(j['approvedByName']),
    createdAt: DateTime.tryParse('${j['createdAtUtc'] ?? ''}')?.toLocal(),
    completedAt: DateTime.tryParse('${j['completedAtUtc'] ?? ''}')?.toLocal(),
    notes: _text(j['notes']),
    serviceRequestId: _text(j['serviceRequestId']),
    lines: [
      for (final d in (j['details'] as List? ?? const []))
        if (d is Map) StockOutLine.fromJson(Map<String, dynamic>.from(d)),
    ],
  );

  num get totalQuantity => lines.fold<num>(0, (s, l) => s + l.quantity);

  /// "3 loại thiết bị (7 cái)" như cột "Số loại thiết bị" trên web.
  String get summary =>
      '${lines.length} loại thiết bị (${fmtQty(totalQuantity)} cái)';

  /// Zone nhận; không chọn Zone thì như web: "Toàn trang trại / Kỹ thuật viên".
  String get zoneText => (zoneName == null || zoneName!.isEmpty)
      ? 'Toàn trang trại / Kỹ thuật viên'
      : zoneName!;

  /// Kỹ thuật viên được xóa khi Bản nháp hoặc Đã hủy; gửi duyệt khi Bản nháp; hủy khi Chờ duyệt.
  /// (Duyệt và hoàn thành xuất kho là việc của Admin trên web: app không gọi.)
  bool get canDelete =>
      status == StockOutStatus.draft || status == StockOutStatus.cancelled;
  bool get canSend => status == StockOutStatus.draft;
  bool get canCancel => status == StockOutStatus.pending;
}

String? _text(Object? v) {
  final t = '${v ?? ''}'.trim();
  return t.isEmpty || t == 'null' ? null : t;
}

/// 3 → "3", 2.5 → "2.5".
String fmtQty(num v) =>
    v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

/// "15/11/2026 21:49" như cột "Ngày lập" trên web.
String fmtDateTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Bộ lọc trạng thái (null = Tất cả) và tìm kiếm theo mã phiếu / Zone / ghi chú, không phân biệt hoa thường.
List<StockOutDoc> filterStockOuts(
  Iterable<StockOutDoc> all, {
  String query = '',
  StockOutStatus? status,
}) {
  final q = query.trim().toLowerCase();
  return [
    for (final s in all)
      if ((status == null || s.status == status) &&
          (q.isEmpty ||
              s.code.toLowerCase().contains(q) ||
              (s.zoneName ?? '').toLowerCase().contains(q) ||
              (s.notes ?? '').toLowerCase().contains(q)))
        s,
  ];
}

/// Tồn kho sau xuất; âm = vượt tồn (form tạo phiếu báo đỏ, backend cũng từ chối).
num stockAfterIssue(num onHand, num quantity) => onHand - quantity;

/// Hàng theo serial: Gateway/Node CÓ số serial, mỗi dòng là MỘT thiết bị (chỉ xuất từng cái, số lượng 1). Gateway/Node không có serial
/// (danh mục tồn kho theo số lượng) xuất theo số lượng như hàng thường.
bool isSerialTracked(Map<String, dynamic> h) {
  final c = '${h['category'] ?? ''}'.toUpperCase();
  final serial = '${h['serialNumber'] ?? ''}'.trim();
  return serial.isNotEmpty && (c.contains('GATEWAY') || c.contains('NODE'));
}

num _stockOf(Map<String, dynamic> h) =>
    (h['quantityInStock'] as num?) ?? (h['quantity'] as num?) ?? 0;

/// Còn nằm ở KHO CHÍNH và xuất được: còn hàng, không lỗi/bảo trì/đã triển khai/ngừng dùng/đang ở kho KTV. Xét theo TRẠNG THÁI chứ
/// không theo người giữ (dữ liệu cũ có dòng InStock mang người giữ thừa vẫn là hàng kho chính).
bool isWarehouseIssuable(Map<String, dynamic> h) =>
    _stockOf(h) > 0 &&
    !const {
      'faulty',
      'maintenance',
      'deployed',
      'retired',
      'intechnicianstock',
    }.contains('${h['status'] ?? ''}'.toLowerCase());

/// Hàng theo serial phải có tồn đúng 1 mới xuất được (backend từ chối nếu khác; Admin cần tách từng serial).
bool isIssuableAsIs(Map<String, dynamic> h) =>
    isWarehouseIssuable(h) && (!isSerialTracked(h) || _stockOf(h) == 1);

/// Danh sách cho ô chọn thiết bị khi lập phiếu: chỉ hàng của kho chính, xếp theo tên (không lẫn hàng của KTV/hàng lỗi).
List<Map<String, dynamic>> warehouseChoices(
  Iterable<Map<String, dynamic>> hardware,
) =>
    [
      for (final h in hardware)
        if (isWarehouseIssuable(h)) h,
    ]..sort(
      (a, b) =>
          '${a['name']}'.toLowerCase().compareTo('${b['name']}'.toLowerCase()),
    );
