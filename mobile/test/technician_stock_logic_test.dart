import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/devices/technician_stock_logic.dart';

Map<String, dynamic> _p(
  String id,
  String name,
  String category,
  int qty, {
  String status = 'InTechnicianStock',
  String? serial,
}) => {
  'id': id,
  'code': 'C-$id',
  'name': name,
  'category': category,
  'quantityInStock': qty,
  'status': status,
  'serialNumber': ?serial,
};

void main() {
  final parts = [
    _p('1', 'Gateway ESP32', 'Gateway', 1, serial: 'SN-GW'),
    _p('2', 'Node cảm biến đất', 'Node cảm biến', 1, serial: 'SN-N1'),
    _p('3', 'SHT30', 'Sensor', 5),
    _p('4', 'Cáp', 'Peripheral', 0),
    _p('5', 'DHT22', 'Sensor', 2, status: 'Faulty'),
  ];

  test('phân loại: Gateway, Node, cảm biến, khác', () {
    expect(stockCategoryOf(parts[0]), StockCategory.gateway);
    expect(stockCategoryOf(parts[1]), StockCategory.node);
    expect(stockCategoryOf(parts[2]), StockCategory.sensor);
    expect(stockCategoryOf(parts[3]), StockCategory.other);
  });

  test(
    'thống kê: chỉ tính hàng còn dùng được; báo lỗi và đã cấp hết tách riêng',
    () {
      final s = summarizeStock(parts);
      expect(s.kinds, 3); // gateway, node, SHT30
      expect(s.units, 7); // 1 + 1 + 5
      expect(s.faulty, 1);
      expect(s.empty, 1);
    },
  );

  test('đếm theo loại', () {
    final c = countByCategory(parts);
    expect(c[StockCategory.all], 5);
    expect(c[StockCategory.sensor], 2);
    expect(c[StockCategory.gateway], 1);
  });

  test('lọc + sắp xếp: dùng được → báo lỗi → đã cấp hết; tìm theo serial', () {
    final all = filterStock(parts);
    expect(all.map((p) => p['id']), ['1', '2', '3', '5', '4']);
    expect(
      filterStock(parts, category: StockCategory.sensor).map((p) => p['id']),
      ['3', '5'],
    );
    expect(filterStock(parts, query: 'sn-n1').map((p) => p['id']), ['2']);
    expect(filterStock(parts, query: 'không có'), isEmpty);
  });
}
