import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/farms/farm_setup_logic.dart';
import 'package:smartfarm_mobile/features/zones/honeycomb_estimate.dart';

Map<String, dynamic> hw(
  String id,
  String code,
  String role,
  num price, {
  List<String> measured = const [],
  int units = 1,
}) => {
  'id': id,
  'code': code,
  'name': 'Thiet bi $code',
  'category': 'X',
  'model': 'M-$code',
  'quantityInStock': 0,
  'unitPrice': price,
  'status': 'InStock',
  'estimateRole': role,
  'estimateUnits': units,
  'measuredParameters': measured,
};

const gwId = '11111111-1111-1111-1111-111111111111';
const nodeId = '22222222-2222-2222-2222-222222222222';
const valveId = '33333333-3333-3333-3333-333333333333';
const kitId = '44444444-4444-4444-4444-444444444444';

final catalogRows = [
  hw(gwId, 'GW', 'Gateway', 3800000),
  hw(
    nodeId,
    'NODE',
    'SensorNode',
    950000,
    measured: ['Temperature', 'SoilMoisture', 'AirHumidity', 'LightIntensity'],
  ),
  hw(valveId, 'VALVE', 'ActuatorNode', 2150000),
  hw(kitId, 'KIT', 'InstallKit', 150000),
];

HoneycombEstimate est(
  List<Map<String, dynamic>> rows, {
  double area = 1458,
  List<String> req = const [],
  ZoneInstalledDevices? installed,
}) => computeHoneycombEstimate(
  areaM2: area,
  radiusM: 25,
  actuatorRatio: 0.6,
  catalog: HoneycombCatalog.fromHardwareItems(rows),
  requiredParameters: req,
  installed: installed ?? ZoneInstalledDevices.none,
);

void main() {
  test(
    'dự toán đủ giá → các dòng hàng gửi theo id kho + vai trò + số lượng; thi công gửi kèm đơn giá cố định',
    () {
      final e = est(catalogRows, req: ['Temperature', 'LightIntensity']);
      final d = buildWizardEstimateItems(e);
      expect(d.skippedReason, isNull);
      expect(d.items.map((i) => i['role']), [
        'Gateway',
        'SensorNode',
        'ActuatorNode',
        'InstallKit',
        'Installation',
      ]);
      expect(d.items[0]['hardwareItemId'], gwId);
      expect(d.items[1]['quantity'], e.line(EstimateRole.sensorNode).quantity);
      // ứng dụng KHÔNG gửi đơn giá của thiết bị kho (backend tự lấy từ kho)
      expect(d.items.take(4).every((i) => !i.containsKey('unitPrice')), isTrue);
      expect(d.items.last['unitPrice'], honeycombInstallationFlatVnd);
      expect(d.items.last.containsKey('hardwareItemId'), isFalse);
    },
  );

  test(
    'thiếu cảm biến đo thông số (có tạm tính): vẫn lưu các dòng đã có đủ giá',
    () {
      final e = est(catalogRows, req: ['Temperature', 'Ph']);
      expect(e.total, isNull);
      expect(e.partialTotal, isNotNull);
      expect(buildWizardEstimateItems(e).hasItems, isTrue);
    },
  );

  test('thiếu hạng mục/đơn giá: không lưu và nêu đúng lý do', () {
    final e = est(catalogRows.where((r) => r['code'] != 'KIT').toList());
    final d = buildWizardEstimateItems(e);
    expect(d.hasItems, isFalse);
    expect(d.skippedReason, contains('Vật tư phụ kiện'));
  });

  test('chưa có dự toán (null): không lưu', () {
    final d = buildWizardEstimateItems(null);
    expect(d.hasItems, isFalse);
    expect(d.skippedReason, isNotNull);
  });

  test('Zone đã đủ thiết bị: không có dòng nào để lưu và không phải lỗi', () {
    final installed = ZoneInstalledDevices.fromJson([
      for (var k = 0; k < 2; k++)
        {
          'deviceType': 'SensorNode',
          'gatewayId': 'g',
          'status': 'Online',
          'sensors': ['Temperature'],
        },
      for (var k = 0; k < 2; k++)
        {
          'deviceType': 'ActuatorNode',
          'gatewayId': 'g',
          'status': 'Online',
          'sensors': [],
        },
    ]);
    final d = buildWizardEstimateItems(
      est(catalogRows, req: ['Temperature'], installed: installed),
    );
    expect(d.hasItems, isFalse);
    expect(d.skippedReason, isNull);
  });

  test('id kho không phải GUID: không lưu (tránh gửi dữ liệu sai)', () {
    final bad = [
      ...catalogRows.where((r) => r['code'] != 'GW'),
      hw('khong-phai-guid', 'GW', 'Gateway', 1000),
    ];
    final d = buildWizardEstimateItems(est(bad));
    expect(d.hasItems, isFalse);
    expect(d.skippedReason, contains('GW'));
  });

  test(
    'đọc dự toán đã lưu từ phản hồi backend: tổng từng dòng và tổng chung khớp',
    () {
      final r = DeploymentRequest.fromJson({
        'requestId': 'r1',
        'farmId': 'f',
        'zoneId': 'z',
        'status': 'Submitted',
        'requiredParameters': ['Temperature'],
        'planItems': [],
        'surveys': [],
        'decisionHistory': [],
        'estimateItems': [
          {
            'estimateItemId': 'e1',
            'hardwareItemId': gwId,
            'code': 'GW',
            'name': 'Gateway',
            'model': 'LG308N',
            'role': 'Gateway',
            'quantity': 1,
            'unitPrice': 3800000,
            'lineTotal': 3800000,
            'notes': 'n',
          },
          {
            'estimateItemId': 'e2',
            'hardwareItemId': null,
            'code': 'INSTALLATION',
            'name': 'Thi công',
            'model': null,
            'role': 'Installation',
            'quantity': 1,
            'unitPrice': 500000.0,
            'lineTotal': 500000.0,
            'notes': null,
          },
        ],
      });
      expect(r.estimateItems.length, 2);
      expect(
        r.estimateItems.fold<double>(0, (a, e) => a + e.lineTotal),
        4300000,
      );
      expect(r.estimateItems[1].hardwareItemId, isNull);
    },
  );

  test('backend cũ không có estimateItems: đọc được, danh sách rỗng', () {
    final r = DeploymentRequest.fromJson({
      'requestId': 'r1',
      'farmId': 'f',
      'zoneId': 'z',
      'status': 'Submitted',
      'requiredParameters': [],
      'planItems': [],
      'surveys': [],
      'decisionHistory': [],
    });
    expect(r.estimateItems, isEmpty);
  });
}
