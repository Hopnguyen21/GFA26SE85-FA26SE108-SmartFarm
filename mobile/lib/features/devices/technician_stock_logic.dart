/// Kho thiết bị của kỹ thuật viên: phân loại, thống kê, lọc và sắp xếp danh sách hàng đang giữ (dữ liệu từ
/// `GET /platform/technicians/me/spare-parts`). Thuần logic để kiểm thử, không phụ thuộc giao diện.
library;

enum StockCategory { all, gateway, node, sensor, other }

extension StockCategoryX on StockCategory {
  String get label => switch (this) {
    StockCategory.all => 'Tất cả',
    StockCategory.gateway => 'Gateway',
    StockCategory.node => 'Node',
    StockCategory.sensor => 'Cảm biến',
    StockCategory.other => 'Khác',
  };
}

final _sensorRe = RegExp(r'SENSOR|CẢM BIẾN|DHT|SHT|CO2|RS485|NHIỆT|ẨM');

String _s(Object? v) => '${v ?? ''}';

/// Loại hàng suy từ chủng loại + tên (Gateway trước, rồi Node, cảm biến, còn lại là khác).
StockCategory stockCategoryOf(Map<String, dynamic> p) {
  final c = '${_s(p['category'])} ${_s(p['name'])}'.toUpperCase();
  if (c.contains('GATEWAY')) return StockCategory.gateway;
  if (_s(p['category']).toUpperCase().contains('NODE')) {
    return StockCategory.node;
  }
  if (_sensorRe.hasMatch(c)) return StockCategory.sensor;
  return StockCategory.other;
}

int partQty(Map<String, dynamic> p) =>
    ((p['quantityInStock'] ?? p['quantity'] ?? 0) as num).toInt();

bool isFaultyPart(Map<String, dynamic> p) =>
    _s(p['status']).toLowerCase() == 'faulty';

/// Còn dùng được: còn hàng và không báo lỗi.
bool isUsablePart(Map<String, dynamic> p) => partQty(p) > 0 && !isFaultyPart(p);

class StockSummary {
  /// Số loại thiết bị còn dùng được, tổng số lượng còn dùng được, số dòng báo lỗi, số dòng đã cấp hết.
  final int kinds;
  final int units;
  final int faulty;
  final int empty;
  const StockSummary({
    required this.kinds,
    required this.units,
    required this.faulty,
    required this.empty,
  });
}

StockSummary summarizeStock(Iterable<Map<String, dynamic>> parts) {
  var kinds = 0, units = 0, faulty = 0, empty = 0;
  for (final p in parts) {
    if (isFaultyPart(p)) {
      faulty++;
    } else if (partQty(p) <= 0) {
      empty++;
    } else {
      kinds++;
      units += partQty(p);
    }
  }
  return StockSummary(kinds: kinds, units: units, faulty: faulty, empty: empty);
}

/// Số dòng theo từng loại (cho nhãn lọc).
Map<StockCategory, int> countByCategory(Iterable<Map<String, dynamic>> parts) {
  final m = {for (final c in StockCategory.values) c: 0};
  for (final p in parts) {
    m[StockCategory.all] = m[StockCategory.all]! + 1;
    final c = stockCategoryOf(p);
    m[c] = m[c]! + 1;
  }
  return m;
}

/// Lọc theo loại + từ khóa (mã, tên, serial, MAC); dùng được lên trước, rồi báo lỗi, rồi đã cấp hết; cùng nhóm theo tên.
List<Map<String, dynamic>> filterStock(
  Iterable<Map<String, dynamic>> parts, {
  String query = '',
  StockCategory category = StockCategory.all,
}) {
  final q = query.trim().toLowerCase();
  final out = [
    for (final p in parts)
      if ((category == StockCategory.all || stockCategoryOf(p) == category) &&
          (q.isEmpty ||
              [
                p['code'],
                p['name'],
                p['serialNumber'],
                p['macAddress'],
              ].any((v) => _s(v).toLowerCase().contains(q))))
        p,
  ];
  int rank(Map<String, dynamic> p) =>
      isUsablePart(p) ? 0 : (isFaultyPart(p) ? 1 : 2);
  out.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0
        ? r
        : _s(a['name']).toLowerCase().compareTo(_s(b['name']).toLowerCase());
  });
  return out;
}
