import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/zones/honeycomb_estimate.dart';

/// Bản sao 4 bản ghi THẬT đọc từ bảng PlatformHardwareItems của DB dev (SmartFarmDB01) ngày 2026-11-11.
List<Map<String, dynamic>> realDb() => [
  {
    'id': '70000000-0000-0000-0000-000000000003',
    'code': 'HW-ACT-01',
    'name': 'Hop Relay Dieu Khien Van Tuoi 4 Kenh LoRa',
    'category': 'Actuator',
    'model': 'LSP-RELAY4',
    'quantityInStock': 25,
    'unitPrice': 1200000,
    'status': 'InStock',
    'assignedTechnicianId': null,
  },
  {
    'id': '70000000-0000-0000-0000-000000000004',
    'code': 'HW-CAM-01',
    'name': 'Camera AI Giam Sat Sau Benh Nang Luong Mat Troi',
    'category': 'Camera',
    'model': 'SF-CAM-SOLAR',
    'quantityInStock': 10,
    'unitPrice': 3200000,
    'status': 'InStock',
  },
  {
    'id': '70000000-0000-0000-0000-000000000001',
    'code': 'HW-GW-01',
    'name': 'LoRaWAN Gateway Cong Nghiep 8-Channel',
    'category': 'Gateway',
    'model': 'LG308N',
    'quantityInStock': 15,
    'unitPrice': 4500000,
    'status': 'InStock',
  },
  {
    'id': '70000000-0000-0000-0000-000000000002',
    'code': 'HW-SN-01',
    'name': 'Cam bien Dat 5 trong 1 (Do am/Nhiet do/EC/pH/NPK)',
    'category': 'Sensor',
    'model': 'RS485-SOIL-5IN1',
    'quantityInStock': 40,
    'unitPrice': 1850000,
    'status': 'InStock',
  },
];

Map<String, dynamic> item(
  String code, {
  String category = 'Sensor',
  Object? price = 1000,
  String status = 'InStock',
  String? role,
  int units = 1,
  List<String>? measured,
  String? tech,
  int qty = 5,
}) => {
  'id': 'id-$code',
  'code': code,
  'name': 'Thiet bi $code',
  'category': category,
  'model': 'M-$code',
  'quantityInStock': qty,
  'unitPrice': price,
  'status': status,
  'estimateRole': role,
  'estimateUnits': units,
  'measuredParameters': measured,
  'assignedTechnicianId': tech,
};

HoneycombEstimate est(
  List<Map<String, dynamic>> db, {
  double area = 4500,
  List<String> req = const [],
  ZoneInstalledDevices installed = ZoneInstalledDevices.none,
}) => computeHoneycombEstimate(
  areaM2: area,
  radiusM: honeycombFixedRadiusM,
  actuatorRatio: honeycombActuatorRatio('Cà Chua Beefsteak (Tomato)'),
  catalog: HoneycombCatalog.fromHardwareItems(db),
  requiredParameters: req,
  installed: installed,
);

void main() {
  group('Dữ liệu DB thật (4 bản ghi, chưa có cấu hình vai trò)', () {
    final catalog = HoneycombCatalog.fromHardwareItems(realDb());

    test(
      'chỉ Gateway được chọn: 4.500.000 đ (category Gateway, bản ghi duy nhất)',
      () {
        expect(catalog.gateway?.code, 'HW-GW-01');
        expect(catalog.gateway?.unitPrice, 4500000);
      },
    );

    test(
      'đầu dò đất 5-in-1 KHÔNG bị dùng làm giá node cảm biến; relay chưa cấu hình thì không đoán',
      () {
        expect(catalog.sensor, isNull);
        expect(
          catalog.of(EstimateRole.sensorNode).issue,
          ResolutionIssue.notConfigured,
        );
        expect(catalog.actuator, isNull);
        expect(catalog.accessories, isNull);
      },
    );

    test(
      'không có tổng giả; nêu đúng hạng mục thiếu; Gateway vẫn tính được',
      () {
        final e = est(realDb());
        expect(e.total, isNull);
        expect(e.gatewayCost, 4500000);
        expect(
          e.totalBlockedReason,
          allOf(
            contains('Node cảm biến'),
            contains('Node điều khiển'),
            contains('Vật tư'),
          ),
        );
        expect(e.totalBlockedReason, isNot(contains('Gateway')));
      },
    );

    test('bảng chẩn đoán: bản ghi nào chọn/bỏ qua và lý do', () {
      final rows = {for (final r in catalog.diagnose()) r.code: r};
      expect(rows['HW-GW-01']!.selected, isTrue);
      expect(rows['HW-SN-01']!.selected, isFalse);
      expect(rows['HW-SN-01']!.reason, contains('linh kiện rời'));
      expect(rows['HW-ACT-01']!.selected, isFalse);
      expect(rows['HW-CAM-01']!.selected, isFalse);
    });
  });

  group('Sau khi quản trị cấu hình vai trò rõ ràng', () {
    final db = [
      ...realDb().where((m) => m['code'] == 'HW-GW-01'),
      item(
        'NODE-1',
        role: 'SensorNode',
        price: 3000000,
        measured: ['Temperature', 'SoilMoisture', 'AirHumidity', 'Ph', 'Ec'],
      ),
      item(
        'RELAY-4',
        category: 'Actuator',
        role: 'ActuatorNode',
        units: 4,
        price: 1200000,
      ),
      item('KIT-1', category: 'Peripheral', role: 'InstallKit', price: 150000),
      item('PROBE-1', price: 1850000), // đầu dò rời, không gán vai trò
    ];

    test(
      'Zone 4.500 m², R=25: 1 GW, 5 node, 3 điểm van → 1 relay 4 kênh; tổng khớp từng dòng',
      () {
        final e = est(db);
        expect(
          [e.gateways, e.sensors, e.actuators, e.accessoryPoints],
          [1, 5, 3, 8],
        );
        expect(e.line(EstimateRole.actuatorNode).quantity, 1); // ceil(3/4)
        expect(e.gatewayCost, 4500000);
        expect(e.sensorCost, 5 * 3000000);
        expect(e.actuatorCost, 1200000);
        expect(e.accessoriesCost, 8 * 150000);
        final sum =
            e.lines.fold<double>(0, (a, l) => a + l.lineTotal!) +
            e.installationCost;
        expect(e.total, sum);
        expect(e.total, 4500000 + 15000000 + 1200000 + 1200000 + 500000);
        expect(formatVnd(e.total!), '22.400.000 đ');
      },
    );

    test('đầu dò rời không được chọn dù cùng nhóm Sensor', () {
      final c = HoneycombCatalog.fromHardwareItems(db);
      expect(c.sensor?.code, 'NODE-1');
    });

    test(
      'node đã khai báo thông số mà thiếu pH/EC so với nhu cầu → không có tổng, nêu thông số thiếu',
      () {
        final weak = [
          ...db.where((m) => m['code'] != 'NODE-1'),
          item(
            'NODE-2',
            role: 'SensorNode',
            price: 900000,
            measured: ['Temperature', 'SoilMoisture'],
          ),
        ];
        final e = est(weak, req: ['Temperature', 'Ph', 'EC']);
        expect(e.capability.missing, ['Ph', 'EC']);
        expect(e.total, isNull);
        expect(e.totalBlockedReason, contains('Ph'));
      },
    );

    test(
      'thiếu năng lực đo nhưng đủ giá mọi hạng mục: không có tổng đầy đủ, chỉ có tạm tính kèm cảnh báo',
      () {
        final e = est(db, req: ['Temperature', 'LightIntensity'], area: 1458);
        expect(e.total, isNull);
        expect(e.totalBlockedReason, contains('LightIntensity'));
        expect(
          e.partialTotal,
          4500000 + 2 * 3000000 + 1200000 + 4 * 150000 + 500000,
        );
      },
    );

    test('thiếu hạng mục thì không có cả tạm tính', () {
      final e = est(realDb(), req: ['LightIntensity']);
      expect(e.total, isNull);
      expect(e.partialTotal, isNull);
    });

    test(
      'node chưa khai báo năng lực đo: vẫn tính giá nhưng capability.declared=false (không khẳng định đáp ứng)',
      () {
        final e = est(
          [
            ...db.where((m) => m['code'] != 'NODE-1'),
            item('NODE-3', role: 'SensorNode', price: 800000),
          ],
          req: ['Ph'],
        );
        expect(e.capability.declared, isFalse);
        expect(e.total, isNotNull);
      },
    );
  });

  group('Quy tắc chọn bản ghi', () {
    test('giá dạng chuỗi/số đều đọc được; null và 0 coi là chưa có giá', () {
      expect(
        HoneycombCatalog.fromHardwareItems([
          item('G', category: 'Gateway', price: '4500000'),
        ]).gateway?.unitPrice,
        4500000,
      );
      expect(
        HoneycombCatalog.fromHardwareItems([
          item('G', category: 'Gateway', price: 4500000.0),
        ]).gateway?.unitPrice,
        4500000,
      );
      for (final p in [null, 0, '0', 'abc', '']) {
        final c = HoneycombCatalog.fromHardwareItems([
          item('G', category: 'Gateway', price: p),
        ]);
        expect(c.gateway, isNull, reason: 'price=$p');
        expect(
          c.of(EstimateRole.gateway).issue,
          ResolutionIssue.noPrice,
          reason: 'price=$p',
        );
      }
    });

    test('PascalCase của backend (UnitPrice/Category) cũng được đọc', () {
      final c = HoneycombCatalog.fromHardwareItems([
        {
          'Code': 'G',
          'Name': 'GW',
          'Category': 'GATEWAY',
          'UnitPrice': 100,
          'Status': 'InStock',
        },
      ]);
      expect(c.gateway?.unitPrice, 100);
    });

    test('nhiều Gateway → mơ hồ, không chọn bản ghi đầu tiên', () {
      final c = HoneycombCatalog.fromHardwareItems([
        item('G1', category: 'Gateway', role: 'Gateway', price: 1000),
        item('G2', category: 'Gateway', role: 'Gateway', price: 2000),
      ]);
      expect(c.gateway, isNull);
      expect(c.of(EstimateRole.gateway).issue, ResolutionIssue.ambiguous);
      expect(
        c.of(EstimateRole.gateway).detail,
        allOf(contains('G1'), contains('G2')),
      );
    });

    test(
      'nhiều loại node cảm biến: mỗi loại là một dòng riêng, tính theo từng thiết bị',
      () {
        final c = HoneycombCatalog.fromHardwareItems([
          item('N1', role: 'SensorNode', price: 1000),
          item('N2', role: 'SensorNode', price: 2000),
        ]);
        expect(c.of(EstimateRole.sensorNode).items.map((i) => i.code), [
          'N1',
          'N2',
        ]);
      },
    );

    test(
      'một loại thiết bị cùng vai trò thiếu giá thì cả vai trò báo thiếu, không bỏ lặng lẽ',
      () {
        final c = HoneycombCatalog.fromHardwareItems([
          item('N1', role: 'SensorNode', price: 1000),
          item('N2', role: 'SensorNode', price: 0),
        ]);
        expect(c.of(EstimateRole.sensorNode).items, isEmpty);
        expect(c.of(EstimateRole.sensorNode).issue, ResolutionIssue.noPrice);
        expect(c.of(EstimateRole.sensorNode).detail, contains('N2'));
      },
    );

    test(
      'bản sao của kỹ thuật viên cùng mã (cùng giá) là một sản phẩm; khác giá là xung đột',
      () {
        final same = HoneycombCatalog.fromHardwareItems([
          item('GW', category: 'Gateway', price: 100),
          item('GW', category: 'Gateway', price: 100, tech: 'tech-1'),
        ]);
        expect(same.gateway?.unitPrice, 100);
        final diff = HoneycombCatalog.fromHardwareItems([
          item('GW', category: 'Gateway', price: 100),
          item('GW', category: 'Gateway', price: 120, tech: 'tech-1'),
        ]);
        expect(diff.gateway, isNull);
        expect(
          diff.of(EstimateRole.gateway).issue,
          ResolutionIssue.priceConflict,
        );
      },
    );

    test(
      'Gateway đã cấp hết cho kỹ thuật viên (bản ghi trung tâm chuyển sang kỹ thuật viên) vẫn có giá',
      () {
        final c = HoneycombCatalog.fromHardwareItems([
          item(
            'GW',
            category: 'Gateway',
            price: 4500000,
            status: 'Issued',
            tech: 'tech-1',
            qty: 0,
          ),
        ]);
        expect(c.gateway?.unitPrice, 4500000);
      },
    );

    test(
      'hết hàng (qty 0) KHÔNG bị coi là không có giá; ngừng sử dụng thì bỏ qua',
      () {
        expect(
          HoneycombCatalog.fromHardwareItems([
            item('N', role: 'SensorNode', qty: 0, price: 500),
          ]).sensor?.unitPrice,
          500,
        );
        final c = HoneycombCatalog.fromHardwareItems([
          item('N', role: 'SensorNode', status: 'Retired', price: 500),
        ]);
        expect(c.sensor, isNull);
        expect(
          c.of(EstimateRole.sensorNode).issue,
          ResolutionIssue.retiredOnly,
        );
      },
    );

    test(
      'category cũ (GATEWAY/AIR_SENSOR/VALVE/SPARE_PART) không còn đủ để chọn node/van/phụ kiện',
      () {
        final c = HoneycombCatalog.fromHardwareItems([
          item('S', category: 'AIR_SENSOR', price: 850000),
          item('V', category: 'VALVE', price: 650000),
          item('P', category: 'SPARE_PART', price: 150000),
        ]);
        expect(c.sensor, isNull);
        expect(c.actuator, isNull);
        expect(c.accessories, isNull);
      },
    );

    test('danh mục rỗng: không có gì được chọn, không có tổng', () {
      final e = est([]);
      expect(e.total, isNull);
      expect(e.lines.every((l) => l.item == null), isTrue);
    });
  });

  group('Bộ node cảm biến là phương án thay thế nhau (bộ ánh sáng / bộ pH)', () {
    // Mỗi bộ = vi điều khiển + nhiều cảm biến trong MỘT bản ghi kho.
    final kits = [
      item('GW', category: 'GATEWAY', role: 'Gateway', price: 3800000),
      item(
        'KIT-LIGHT',
        role: 'SensorNode',
        price: 1000000,
        measured: [
          'Temperature',
          'SoilMoisture',
          'AirHumidity',
          'LightIntensity',
        ],
      ),
      item(
        'KIT-PH',
        role: 'SensorNode',
        price: 1100000,
        measured: ['Temperature', 'SoilMoisture', 'AirHumidity', 'Ph'],
      ),
      item('PUMP-NODE', role: 'ActuatorNode', price: 2150000),
      item('ACC', role: 'InstallKit', price: 150000),
    ];
    String sensorsOf(HoneycombEstimate e) => e
        .linesOf(EstimateRole.sensorNode)
        .map((l) => '${l.item!.code}x${l.quantity}')
        .join(',');

    test(
      'cần ánh sáng + pH: bộ chính 4 + 1 bộ biến thể pH (tổng vẫn 5 điểm đo), không cộng dồn mọi bộ',
      () {
        final e = est(
          kits,
          area: 4500,
          req: [
            'Temperature',
            'SoilMoisture',
            'AirHumidity',
            'Ph',
            'LightIntensity',
          ],
        );
        expect(e.sensors, 5);
        expect(sensorsOf(e), 'KIT-LIGHTx4,KIT-PHx1');
        expect(e.sensorCost, 4 * 1000000 + 1100000);
        expect(e.capability.missing, isEmpty);
        expect(e.total, 3800000 + 5100000 + 3 * 2150000 + 8 * 150000 + 500000);
      },
    );

    test('chỉ cần ánh sáng: chỉ dùng bộ ánh sáng cho cả 5 điểm', () {
      final e = est(
        kits,
        area: 4500,
        req: ['Temperature', 'SoilMoisture', 'AirHumidity', 'LightIntensity'],
      );
      expect(sensorsOf(e), 'KIT-LIGHTx5');
    });

    test('chỉ cần pH: chỉ dùng bộ pH cho cả 5 điểm', () {
      final e = est(
        kits,
        area: 4500,
        req: ['Temperature', 'SoilMoisture', 'AirHumidity', 'Ph'],
      );
      expect(sensorsOf(e), 'KIT-PHx5');
    });

    test(
      'không có nhu cầu đo: dùng bộ rẻ nhất cho mọi điểm, không khẳng định đáp ứng',
      () {
        final e = est(kits, area: 4500);
        expect(sensorsOf(e), 'KIT-LIGHTx5');
      },
    );

    test(
      'thông số không bộ nào đo được: vẫn tính điểm đo bằng bộ rẻ nhất, báo thiếu thông số, chỉ có tạm tính',
      () {
        final e = est(kits, area: 4500, req: ['Temperature', 'Co2']);
        expect(e.capability.missing, ['Co2']);
        expect(e.total, isNull);
        expect(e.partialTotal, isNotNull);
      },
    );

    test(
      'bộ điều khiển: chỉ một loại (nhiều loại → mơ hồ); một bộ có thể phục vụ nhiều điểm (EstimateUnits)',
      () {
        final two = HoneycombCatalog.fromHardwareItems([
          item('P1', role: 'ActuatorNode', price: 1),
          item('P2', role: 'ActuatorNode', price: 2),
        ]);
        expect(
          two.of(EstimateRole.actuatorNode).issue,
          ResolutionIssue.ambiguous,
        );
        final multi = est([
          ...kits.where((m) => m['code'] != 'PUMP-NODE'),
          item('PUMP4', role: 'ActuatorNode', units: 4, price: 2000000),
        ], area: 4500);
        expect(multi.actuators, 3);
        expect(
          multi.line(EstimateRole.actuatorNode).quantity,
          1,
        ); // 3 điểm / 4 cổng
      },
    );
  });

  group('Phần BỔ SUNG theo thiết bị đã gắn vào Zone', () {
    final catalogDb = [
      item('GW', category: 'GATEWAY', role: 'Gateway', price: 3800000),
      item(
        'N-AIR',
        role: 'SensorNode',
        price: 950000,
        measured: [
          'Temperature',
          'AirHumidity',
          'SoilMoisture',
          'LightIntensity',
        ],
      ),
      item(
        'N-SOIL',
        role: 'SensorNode',
        price: 1250000,
        measured: [
          'Temperature',
          'AirHumidity',
          'SoilMoisture',
          'LightIntensity',
        ],
      ),
      item('VALVE', role: 'ActuatorNode', price: 2150000),
      item('KIT', role: 'InstallKit', price: 150000),
    ];
    Map<String, dynamic> dev(
      String type,
      String gw,
      List<String> sensors, {
      String status = 'Online',
    }) => {
      'deviceType': type,
      'gatewayId': gw,
      'status': status,
      'sensors': sensors,
      'actuators': <String>[],
    };
    const all6 = [
      'Temperature',
      'SoilMoisture',
      'AirHumidity',
      'Ph',
      'LightIntensity',
      'Ec',
    ];
    final reqAll = [
      'Temperature',
      'SoilMoisture',
      'AirHumidity',
      'Ph',
      'LightIntensity',
    ];

    test(
      'đọc thiết bị đã gắn: đếm theo loại, gateway khác nhau, hợp thông số; bỏ thiết bị ngừng',
      () {
        final i = ZoneInstalledDevices.fromJson([
          dev('SensorNode', 'g1', ['Temperature', 'Ph']),
          dev('SensorNode', 'g1', ['SoilMoisture']),
          dev('ActuatorNode', 'g2', []),
          dev('SensorNode', 'g3', ['Ec'], status: 'Decommissioned'),
        ]);
        expect([i.sensorNodes, i.actuatorNodes, i.gateways], [2, 1, 2]);
        expect(i.measured, {'temperature', 'ph', 'soilmoisture'});
      },
    );

    test(
      'Khu cà chua 12 (2.204 m², đã gắn 4 node, 2 van, 1 gateway, đủ thông số): không cần bổ sung, chi phí 0',
      () {
        final installed = ZoneInstalledDevices.fromJson([
          for (var k = 0; k < 4; k++) dev('SensorNode', 'g1', all6),
          for (var k = 0; k < 2; k++) dev('ActuatorNode', 'g1', []),
        ]);
        final e = est(catalogDb, area: 2204, req: reqAll, installed: installed);
        expect(e.nothingToAdd, isTrue);
        expect(e.total, 0);
        expect(e.installationCost, 0);
        expect(e.lines.every((l) => l.covered), isTrue);
      },
    );

    test(
      'Líp 00 (2.500 m², đã gắn 3 node, 1 van, 1 gateway): chỉ bổ sung 1 van + 1 phụ kiện + thi công',
      () {
        final installed = ZoneInstalledDevices.fromJson([
          for (var k = 0; k < 3; k++) dev('SensorNode', 'g1', all6),
          dev('ActuatorNode', 'g1', []),
        ]);
        final e = est(catalogDb, area: 2500, req: reqAll, installed: installed);
        expect([e.sensors, e.actuators, e.gateways], [3, 2, 1]);
        expect(e.linesOf(EstimateRole.actuatorNode).single.quantity, 1);
        expect(e.linesOf(EstimateRole.actuatorNode).single.installed, 1);
        expect(e.gatewayCost, 0);
        expect(e.sensorCost, 0);
        expect(e.total, 2150000 + 150000 + 500000);
      },
    );

    test(
      'Luống 02 (3.500 m², đã gắn 1 node/1 van, chưa ai đo pH, kho không có node đo pH): có tạm tính, báo thiếu pH',
      () {
        final installed = ZoneInstalledDevices.fromJson([
          dev('SensorNode', 'g1', [
            'Temperature',
            'SoilMoisture',
            'AirHumidity',
            'LightIntensity',
          ]),
          dev('ActuatorNode', 'g1', []),
        ]);
        final e = est(catalogDb, area: 3500, req: reqAll, installed: installed);
        expect(e.capability.missing, ['Ph']);
        expect(e.total, isNull);
        expect(e.partialTotal, isNotNull);
        expect(e.totalBlockedReason, contains('Ph'));
      },
    );

    test(
      'đủ số node nhưng thiếu pH: chỉ thêm node đo được pH (1 cái); nếu kho không có node nào đo pH thì báo thiếu',
      () {
        final installed = ZoneInstalledDevices.fromJson([
          for (var k = 0; k < 3; k++)
            dev('SensorNode', 'g1', [
              'Temperature',
              'SoilMoisture',
              'AirHumidity',
              'LightIntensity',
            ]),
          for (var k = 0; k < 2; k++) dev('ActuatorNode', 'g1', []),
        ]);
        final noPh = est(
          catalogDb,
          area: 2500,
          req: reqAll,
          installed: installed,
        );
        expect(noPh.linesOf(EstimateRole.sensorNode).single.covered, isTrue);
        expect(noPh.capability.missing, ['Ph']);
        expect(noPh.total, isNull);

        final withPh = est(
          [
            ...catalogDb.where((m) => m['code'] != 'N-SOIL'),
            item('N-PH', role: 'SensorNode', price: 1000000, measured: ['Ph']),
          ],
          area: 2500,
          req: reqAll,
          installed: installed,
        );
        // chỉ node đo được pH được thêm (1 cái); phụ kiện cho 1 vị trí
        expect(
          withPh
              .linesOf(EstimateRole.sensorNode)
              .map((l) => '${l.item!.code}x${l.quantity}'),
          ['N-PHx1'],
        );
        expect(withPh.capability.missing, isEmpty);
        expect(withPh.total, 1000000 + 150000 + 500000);
      },
    );

    test('Zone chưa gắn gì: lắp mới toàn bộ như trước', () {
      final a = est(catalogDb, area: 1458, req: ['Temperature']);
      final b = est(
        catalogDb,
        area: 1458,
        req: ['Temperature'],
        installed: ZoneInstalledDevices.none,
      );
      expect(a.total, b.total);
      expect(a.lines.every((l) => !l.covered), isTrue);
    });
  });

  test(
    'mỗi 15.000 m² thêm một gateway; tối thiểu 1 node cảm biến; bán kính cố định 25 m',
    () {
      expect(honeycombFixedRadiusM, 25);
      expect(est([], area: 15001).gateways, 2);
      expect(
        computeHoneycombEstimate(
          areaM2: 60,
          radiusM: 30,
          actuatorRatio: 0.6,
          catalog: HoneycombCatalog.fromHardwareItems([]),
        ).sensors,
        1,
      );
    },
  );

  group('Số node: công thức theo diện tích + chu vi, khớp mô phỏng phủ kín', () {
    int nodes(double area, {double? perimeter}) => computeHoneycombEstimate(
      areaM2: area,
      radiusM: 25,
      actuatorRatio: 0.6,
      catalog: HoneycombCatalog.fromHardwareItems([]),
      perimeterM: perimeter,
    ).sensors;

    test(
      'các Zone thật: kết quả khớp số node tối thiểu của mô phỏng (hình chữ nhật 1:2)',
      () {
        // Mô phỏng k-tâm (bán kính 25 m) cho hình chữ nhật 1:2: 172→1, 1.458→2, 2.500→3, 4.500→5, 10.000→8.
        expect(nodes(172), 1);
        expect(nodes(1458), 2);
        expect(nodes(2500), 3);
        expect(nodes(4500), 5);
        expect(
          nodes(10000),
          9,
        ); // sát nhưng không thiếu (mô phỏng: 8–10 tuỳ tỉ lệ cạnh)
      },
    );

    test(
      'Zone dài hẹp (chu vi lớn) cần nhiều node hơn Zone vuông cùng diện tích',
      () {
        final square = nodes(2500, perimeter: 200);
        final narrow = nodes(2500, perimeter: 2 * (250 + 10));
        expect(narrow, greaterThanOrEqualTo(square));
      },
    );

    test(
      'chu vi sai/lệch bị chặn trong khoảng hợp lý, không làm số node vô lý',
      () {
        final huge = nodes(2500, perimeter: 1e9);
        final tiny = nodes(2500, perimeter: 1);
        expect(huge, lessThan(10));
        expect(tiny, greaterThanOrEqualTo(1));
      },
    );

    test('chu vi bao lồi từ toạ độ: hình vuông ~100 m x 100 m → ~400 m', () {
      const d = 100 / 110540.0; // độ vĩ ~ 100 m
      final dl = 100 / (111320.0 * 0.9998);
      final per = convexHullPerimeterM([
        (lat: 10.0, lng: 106.0),
        (lat: 10.0 + d, lng: 106.0),
        (lat: 10.0 + d, lng: 106.0 + dl),
        (lat: 10.0, lng: 106.0 + dl),
        (lat: 10.0 + d / 2, lng: 106.0 + dl / 2), // điểm trong bao lồi
      ]);
      expect(per, closeTo(400, 8));
      expect(
        convexHullPerimeterM([(lat: 1.0, lng: 1.0), (lat: 2.0, lng: 2.0)]),
        isNull,
      );
    });
  });

  test('formatVnd phân tách hàng nghìn', () {
    expect(formatVnd(10400000), '10.400.000 đ');
    expect(formatVnd(0), '0 đ');
  });
}
