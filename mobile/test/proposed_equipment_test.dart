import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/support/proposed_equipment.dart';
import 'package:smartfarm_mobile/features/zones/honeycomb_estimate.dart';

Map<String, dynamic> hw(
  String id,
  String code,
  String role,
  num price, {
  List<String> measured = const [],
}) => {
  'id': id,
  'code': code,
  'name': 'Thiết bị $code',
  'category': 'X',
  'model': 'M-$code',
  'quantityInStock': 10,
  'unitPrice': price,
  'status': 'InStock',
  'estimateRole': role,
  'estimateUnits': 1,
  'measuredParameters': measured,
};

const guid = '11111111-1111-1111-1111-11111111111';

HoneycombEstimate estimate(
  List<Map<String, dynamic>> items, {
  double area = 2500,
}) => computeHoneycombEstimate(
  areaM2: area,
  radiusM: honeycombFixedRadiusM,
  actuatorRatio: honeycombActuatorRatio('Dưa leo'),
  catalog: HoneycombCatalog.fromHardwareItems(items),
  requiredParameters: const ['SoilMoisture', 'Temperature'],
);

void main() {
  final full = [
    hw('${guid}1', 'GW', 'Gateway', 3800000),
    hw(
      '${guid}2',
      'SN',
      'SensorNode',
      950000,
      measured: ['SoilMoisture', 'Temperature'],
    ),
    hw('${guid}3', 'VALVE', 'ActuatorNode', 2150000),
    hw('${guid}4', 'KIT', 'InstallKit', 150000),
  ];

  test(
    'đề xuất theo diện tích Zone: đủ gateway, node, vật tư, thi công; số tiền khớp dự toán',
    () {
      final est = estimate(full);
      final items = quotationItemsFromEstimate(est);
      final codes = [for (final i in items) i.code];
      expect(codes, containsAll(['GW', 'SN', 'VALVE', 'INSTALLATION']));
      expect(items.every((i) => i.quantity > 0 && i.unitPrice > 0), isTrue);
      // Tiền hàng chưa thuế của các dòng báo giá bằng tổng dự toán của Owner (cùng thuật toán).
      final net = items.fold<double>(0, (s, i) => s + i.quantity * i.unitPrice);
      expect(net, closeTo((est.total ?? est.partialTotal)!, 0.5));
      // Gắn nhãn rõ là ước tính, đúng loại/ĐVT như bản nháp từ dự toán đã lưu.
      final gw = items.firstWhere((i) => i.code == 'GW');
      expect([gw.category, gw.unit, gw.vatPercent], ['GATEWAY', 'Trạm', 8.0]);
      expect(gw.notes, contains('ước tính theo diện tích Zone'));
      expect(items.last.code, 'INSTALLATION');
      expect([items.last.category, items.last.unit], ['SERVICE', 'Gói']);
    },
  );

  test('thành tiền mỗi dòng gồm VAT', () {
    final items = quotationItemsFromEstimate(estimate(full));
    for (final i in items) {
      expect(i.totalAmount, closeTo(i.quantity * i.unitPrice * 1.08, 0.5));
    }
  });

  test('kho chưa có thiết bị/đơn giá: không bịa dòng', () {
    expect(quotationItemsFromEstimate(estimate(const [])), isEmpty);
    final noPrice = [hw('${guid}1', 'GW', 'Gateway', 0)];
    expect(
      quotationItemsFromEstimate(
        estimate(noPrice),
      ).where((i) => i.code == 'GW'),
      isEmpty,
    );
  });

  test('Zone lớn cần nhiều thiết bị hơn Zone nhỏ', () {
    int total(double area) => quotationItemsFromEstimate(
      estimate(full, area: area),
    ).where((i) => i.category != 'SERVICE').fold(0, (s, i) => s + i.quantity);
    expect(total(10000), greaterThan(total(500)));
  });
}
