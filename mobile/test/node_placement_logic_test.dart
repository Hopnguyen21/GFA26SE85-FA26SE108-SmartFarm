import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/support/node_placement_logic.dart';

QuotationItem _item(String category, int qty) => QuotationItem(
  code: 'X',
  name: 'X',
  category: category,
  unit: 'cái',
  quantity: qty,
  unitPrice: 1,
  vatPercent: 8,
  totalAmount: 1,
);

IotDevice _dev(String id, {String type = 'SensorNode', bool? test}) =>
    IotDevice(
      deviceId: id,
      gatewayId: 'g',
      deploymentRequestId: 'd',
      hardwareAddress: 'HW-$id',
      deviceType: type,
      status: 'Assigned',
      latestTest: test == null
          ? null
          : ConnectionTest(
              succeeded: test,
              observedAtUtc: '2026-11-12T00:00:00Z',
            ),
    );

const _square = [
  (lat: 10.0, lng: 100.0),
  (lat: 10.0, lng: 100.001),
  (lat: 10.001, lng: 100.001),
  (lat: 10.001, lng: 100.0),
];

void main() {
  group('phân loại dòng hợp đồng', () {
    test('chỉ Gateway / Sensor / Actuator là thiết bị chấm điểm', () {
      expect(nodeKindOfCategory('GATEWAY'), NodeKind.gateway);
      expect(nodeKindOfCategory('SENSOR_SOIL'), NodeKind.sensor);
      expect(nodeKindOfCategory('ACTUATOR_PUMP'), NodeKind.actuator);
      expect(nodeKindOfCategory('CABLE'), isNull);
      expect(nodeKindOfCategory('SERVICE'), isNull);
      expect(nodeKindOfCategory('INSTALLATION'), isNull);
    });

    test('cộng số lượng theo loại, bỏ vật tư và dòng số lượng 0', () {
      final m = contractUnitsByKind([
        _item('GATEWAY', 1),
        _item('SENSOR', 3),
        _item('SENSOR_AIR', 2),
        _item('CABLE', 50),
        _item('ACTUATOR', 0),
      ]);
      expect(m, {NodeKind.gateway: 1, NodeKind.sensor: 5});
    });

    test('đếm thiết bị đã cấp phát theo loại, Gateway tính riêng', () {
      final m = provisionedUnitsByKind(
        devices: [
          _dev('1'),
          _dev('2', type: 'ActuatorNode'),
        ],
        gateways: 1,
      );
      expect(m, {
        NodeKind.gateway: 1,
        NodeKind.sensor: 1,
        NodeKind.actuator: 1,
      });
    });
  });

  group('điểm trong Zone và độ chính xác GPS', () {
    test('pointInPolygon', () {
      expect(pointInPolygon(10.0005, 100.0005, _square), isTrue);
      expect(pointInPolygon(10.002, 100.0005, _square), isFalse);
      expect(
        pointInPolygon(10.0005, 100.0005, _square.take(2).toList()),
        isFalse,
      );
    });

    test('evaluateFix: ngoài Zone, sai số, không có ranh giới', () {
      FixVerdict v(
        double lat,
        double acc, [
        List<({double lat, double lng})>? p = _square,
      ]) => evaluateFix(lat: lat, lng: 100.0005, accuracyM: acc, polygon: p);
      expect(v(10.0005, 5), FixVerdict.ok);
      expect(v(10.0005, 30), FixVerdict.poorAccuracy);
      expect(v(10.0005, 80), FixVerdict.tooInaccurate);
      expect(v(10.5, 5), FixVerdict.outsideZone);
      expect(v(10.0005, 5, null), FixVerdict.noBoundary);
    });
  });

  group('điều kiện hoàn tất lắp đặt', () {
    List<String> blockers({
      String status = 'Installing',
      List<IotDevice>? devices,
      Set<String> placed = const {},
      Map<NodeKind, int> contract = const {},
      Map<NodeKind, int> prov = const {},
    }) => completionBlockers(
      deploymentStatus: status,
      devices: devices ?? [],
      placed: placed,
      contractUnits: contract,
      provisioned: prov,
    );

    test('chưa Installing thì chặn ngay', () {
      expect(blockers(status: 'PlanConfirmed').single, contains('chưa ở bước'));
    });

    test('không có thiết bị: chặn; đủ vị trí + kiểm tra đạt: không chặn', () {
      expect(blockers(), contains('Chưa có thiết bị nào được cấp phát.'));
      final d = _dev('a', test: true);
      expect(
        blockers(
          devices: [d],
          placed: {'a'},
          contract: {NodeKind.sensor: 1},
          prov: {NodeKind.sensor: 1},
        ),
        isEmpty,
      );
    });

    test(
      'lưu vị trí chưa đủ: thiếu vị trí, thiếu / hỏng kiểm tra kết nối, thiếu số lượng',
      () {
        final out = blockers(
          devices: [_dev('a'), _dev('b', test: false)],
          placed: {'b'},
          contract: {NodeKind.sensor: 3},
          prov: {NodeKind.sensor: 2},
        );
        expect(out.any((s) => s.contains('2/3')), isTrue);
        expect(
          out.any((s) => s.contains('HW-a') && s.contains('vị trí')),
          isTrue,
        );
        expect(
          out.any((s) => s.contains('HW-a') && s.contains('chưa ghi kiểm tra')),
          isTrue,
        );
        expect(
          out.any((s) => s.contains('HW-b') && s.contains('không đạt')),
          isTrue,
        );
      },
    );
  });

  group('checkNodePlacement (cổng Gắn Node)', () {
    NodePlacementGate g({
      String? service = 'InProgress',
      bool loaded = true,
      String? quote = 'SignedByOwner',
      String? dep = 'Accepted',
      bool link = true,
    }) => checkNodePlacement(
      serviceStatus: service,
      quotationLoaded: loaded,
      quotationStatus: quote,
      deploymentStatus: dep,
      linkValid: link,
    );

    test('đã ký + cọc: mở với mọi trạng thái triển khai chưa kết thúc', () {
      for (final d in [
        'Submitted',
        'Accepted',
        'Surveyed',
        'PlanConfirmed',
        'Installing',
      ]) {
        expect(g(dep: d).allowed, isTrue, reason: d);
      }
      expect(g(quote: 'DepositPaid').allowed, isTrue);
      expect(
        g(service: 'Assigned').allowed,
        isTrue,
      ); // không bắt nhận lại phiếu
    });

    test('chưa cọc / thiếu báo giá: khoá (unpaid)', () {
      for (final q in [null, '', 'Draft', 'SentToOwner']) {
        final r = g(quote: q);
        expect(r.allowed, isFalse, reason: '$q');
        expect(r.block, NodePlacementBlock.unpaid);
      }
    });

    test('dữ liệu chưa đọc được hoặc lỗi: khoá (unknown), không đoán', () {
      expect(g(loaded: false).block, NodePlacementBlock.unknown);
      expect(g(service: null).block, NodePlacementBlock.unknown);
      expect(g(loaded: false, quote: 'SignedByOwner').allowed, isFalse);
    });

    test('đã cọc nhưng kết thúc: vẫn khoá', () {
      expect(g(service: 'Closed').block, NodePlacementBlock.serviceFinished);
      expect(g(service: 'Resolved').allowed, isFalse);
      expect(g(quote: 'Completed').block, NodePlacementBlock.serviceFinished);
      for (final d in ['Completed', 'Cancelled', 'MaintenanceRequired']) {
        expect(
          g(dep: d).block,
          NodePlacementBlock.deploymentFinished,
          reason: d,
        );
      }
    });

    test('liên kết sai hoặc triển khai không đọc được: khoá (wrongLink)', () {
      expect(g(link: false).block, NodePlacementBlock.wrongLink);
      expect(g(dep: null).block, NodePlacementBlock.wrongLink);
    });
  });

  group('deploymentLinkValid', () {
    bool v({
      String farm = 'f1',
      String zone = 'z1',
      String sDep = 'd1',
      String? dep = 'd1',
      String? dFarm = 'f1',
      String? dZone = 'z1',
    }) => deploymentLinkValid(
      serviceFarmId: farm,
      serviceZoneId: zone,
      serviceDeploymentId: sDep,
      deploymentId: dep,
      deploymentFarmId: dFarm,
      deploymentZoneId: dZone,
    );
    test('khớp mã, Farm và Zone (không phân biệt hoa thường)', () {
      expect(v(), isTrue);
      expect(v(dep: 'D1', dFarm: 'F1', dZone: 'Z1'), isTrue);
    });
    test('sai mã/Farm/Zone, mã rỗng hoặc 0, chưa đọc được: từ chối', () {
      expect(v(dZone: 'z2'), isFalse);
      expect(v(dFarm: 'f2'), isFalse);
      expect(v(dep: 'd2'), isFalse);
      expect(v(sDep: ''), isFalse);
      expect(
        v(
          sDep: '00000000-0000-0000-0000-000000000000',
          dep: '00000000-0000-0000-0000-000000000000',
        ),
        isFalse,
      );
      expect(v(dep: null, dFarm: null, dZone: null), isFalse);
    });
  });

  group('danh sách theo hợp đồng (contractSlots / matchNodeSlots)', () {
    test(
      'mỗi đơn vị Gateway/Node là một chỗ; vật tư, thi công, số lượng 0 bị bỏ',
      () {
        final s = contractSlots([
          _item('GATEWAY', 1),
          _item('SENSOR_NODE', 2),
          _item('ACTUATOR_NODE', 1),
          _item('ACCESSORY', 4),
          _item('SERVICE', 1),
          _item('SENSOR', 0),
        ]);
        expect(s.map((e) => e.kind), [
          NodeKind.gateway,
          NodeKind.sensor,
          NodeKind.sensor,
          NodeKind.actuator,
        ]);
        expect(s[1].label, endsWith('(1/2)'));
        expect(s[2].label, endsWith('(2/2)'));
        expect(s[0].label, isNot(contains('/'))); // 1 đơn vị: không ghi 1/1
      },
    );

    test(
      'ghép thiết bị đã cấp phát theo loại; chỗ thiếu để trống, thiết bị dư vào extras',
      () {
        final slots = contractSlots([
          _item('SENSOR_NODE', 2),
          _item('ACTUATOR_NODE', 1),
        ]);
        final devices = [
          _dev('b'),
          _dev('a'),
          _dev('c'),
        ]; // 3 cảm biến, 0 điều khiển
        final m = matchNodeSlots(slots, devices);
        expect(m.slots.map((x) => x.device?.deviceId), ['a', 'b', null]);
        expect(
          m.slots[2].slot.kind,
          NodeKind.actuator,
        ); // chưa cấp phát Node điều khiển
        expect(m.extras.map((d) => d.deviceId), ['c']);
      },
    );

    test('không có thiết bị nào: mọi chỗ trống, không tạo thiết bị giả', () {
      final m = matchNodeSlots(contractSlots([_item('SENSOR_NODE', 2)]), []);
      expect(m.slots.every((x) => x.device == null), isTrue);
      expect(m.extras, isEmpty);
    });

    test('Gateway ghép theo thứ tự, dư thì để trống', () {
      final slots = contractSlots([_item('GATEWAY', 2)]);
      final r = matchGatewaySlots(slots, [
        {'gatewaySerial': 'GW-1'},
      ]);
      expect(r.length, 2);
      expect(r[0].gateway?['gatewaySerial'], 'GW-1');
      expect(r[1].gateway, isNull);
    });
  });

  test(
    'dòng hợp đồng không chấm được (vật tư, thi công) được liệt kê để chỉ xem',
    () {
      final r = contractNonPlaceableLines([
        _item('GATEWAY', 1),
        _item('SENSOR_NODE', 2),
        _item('ACCESSORY', 2),
        _item('SERVICE', 1),
        _item('LABOR', 0),
      ]);
      expect(r.map((i) => i.category), ['ACCESSORY', 'SERVICE']);
    },
  );

  group('nhận diện loại thiết bị của dòng hợp đồng (nodeKindOfItem)', () {
    QuotationItem line(String category, String code, String name) =>
        QuotationItem(
          code: code,
          name: name,
          category: category,
          unit: 'Cái',
          quantity: 1,
          unitPrice: 1,
          vatPercent: 8,
          totalAmount: 1,
        );

    test(
      'danh mục tên cũ: VALVE/PUMP/RELAY là Node điều khiển, AIR_SENSOR/SOIL_SENSOR là cảm biến',
      () {
        expect(nodeKindOfItem(line('VALVE', 'X', 'x')), NodeKind.actuator);
        expect(nodeKindOfItem(line('PUMP', 'X', 'x')), NodeKind.actuator);
        expect(nodeKindOfItem(line('RELAY', 'X', 'x')), NodeKind.actuator);
        expect(nodeKindOfItem(line('AIR_SENSOR', 'X', 'x')), NodeKind.sensor);
        expect(nodeKindOfItem(line('SOIL_SENSOR', 'X', 'x')), NodeKind.sensor);
      },
    );
    test('danh mục chung (HARDWARE/nhập tay): suy theo mã rồi theo tên', () {
      expect(
        nodeKindOfItem(line('HARDWARE', 'ACT-VALVE-01', 'Van')),
        NodeKind.actuator,
      );
      expect(
        nodeKindOfItem(line('HARDWARE', 'SN-AIR-02', 'x')),
        NodeKind.sensor,
      );
      expect(nodeKindOfItem(line('HARDWARE', 'GW-1', 'x')), NodeKind.gateway);
      expect(
        nodeKindOfItem(line('HARDWARE', 'ZZ', 'Node Điều khiển Van Solenoid')),
        NodeKind.actuator,
      );
      expect(
        nodeKindOfItem(line('HARDWARE', 'ZZ', 'Node Cảm biến Độ ẩm')),
        NodeKind.sensor,
      );
      expect(
        nodeKindOfItem(line('', 'ZZ', 'Trạm Central Gateway')),
        NodeKind.gateway,
      );
    });
    test(
      'vật tư, phụ kiện, thi công không bao giờ thành thiết bị dù tên/mã giống',
      () {
        expect(
          nodeKindOfItem(line('ACCESSORY', 'SN-KIT', 'Phụ kiện cảm biến')),
          isNull,
        );
        expect(
          nodeKindOfItem(
            line('SERVICE', 'INSTALLATION', 'Thi công, định vị GPS'),
          ),
          isNull,
        );
        expect(
          nodeKindOfItem(line('LABOR', 'ACT-LABOR', 'Công lắp van')),
          isNull,
        );
        expect(
          nodeKindOfItem(
            line('HARDWARE', 'HW-KIT-01', 'Vật tư phụ kiện lắp đặt'),
          ),
          isNull,
        );
      },
    );
    test(
      'hợp đồng thật (VALVE + AIR_SENSOR + SOIL_SENSOR + GATEWAY) cho đủ 7 chỗ',
      () {
        final items = [
          line('GATEWAY', 'GW-ESP32-DL01', 'Trạm Central Gateway'),
          QuotationItem(
            code: 'SN-AIR-02',
            name: 'Node Cảm biến Không khí',
            category: 'AIR_SENSOR',
            unit: 'Node',
            quantity: 2,
            unitPrice: 1,
            vatPercent: 8,
            totalAmount: 1,
          ),
          QuotationItem(
            code: 'SN-SOIL-01',
            name: 'Node Cảm biến Đất',
            category: 'SOIL_SENSOR',
            unit: 'Node',
            quantity: 2,
            unitPrice: 1,
            vatPercent: 8,
            totalAmount: 1,
          ),
          QuotationItem(
            code: 'ACT-VALVE-01',
            name: 'Node Điều khiển Van',
            category: 'VALVE',
            unit: 'Node',
            quantity: 2,
            unitPrice: 1,
            vatPercent: 8,
            totalAmount: 1,
          ),
        ];
        final s = contractSlots(items);
        expect(s.length, 7);
        expect(s.where((e) => e.kind == NodeKind.actuator).length, 2);
        expect(contractUnitsByKind(items), {
          NodeKind.gateway: 1,
          NodeKind.sensor: 4,
          NodeKind.actuator: 2,
        });
      },
    );
  });
}
