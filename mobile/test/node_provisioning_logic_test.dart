import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/support/node_provisioning_flow.dart';

NodeChoice _n(String name, String category) =>
    NodeChoice(hardwareItemId: 'x', code: 'C', name: name, category: category);

void main() {
  test('vai trò rõ quyết định loại thiết bị gửi lên backend', () {
    NodeChoice n(String role) => NodeChoice(
      hardwareItemId: 'x',
      code: 'C',
      name: 'N',
      category: 'SOIL_SENSOR',
      estimateRole: role,
    );
    expect(n('SensorNode').roleKnown, isTrue);
    expect(n('SensorNode').roleDeviceType, 'SensorNode');
    expect(n('ActuatorNode').roleDeviceType, 'ActuatorNode');
    expect(n('InstallKit').roleKnown, isFalse);
    expect(n('InstallKit').roleDeviceType, isNull);
  });

  test('địa chỉ gợi ý: mã dài bị cắt, mã rỗng dùng NODE, luôn 3–64 ký tự', () {
    final longCode = 'C' * 80;
    final list = nodeChoices([
      {
        'id': '1',
        'code': longCode,
        'name': 'Node dài',
        'category': 'Node',
        'quantityInStock': 3,
      },
      {
        'id': '2',
        'code': '',
        'name': 'Node trống',
        'category': 'Node',
        'quantityInStock': 3,
      },
    ]);
    for (final n in list) {
      expect(n.suggestedAddress.length, inInclusiveRange(3, 64));
      expect(validateNodeAddress(n.suggestedAddress), isNull);
    }
    expect(list[1].suggestedAddress, 'NODE-01');
  });

  test('địa chỉ đã dùng ở trang trại/nơi khác được bỏ qua khi gợi ý', () {
    final stock = [
      {
        'id': '1',
        'code': 'SN-SOIL-01',
        'name': 'Node đo đất',
        'category': 'SOIL_SENSOR',
        'estimateRole': 'SensorNode',
        'quantityInStock': 9,
      },
    ];
    expect(nodeChoices(stock).single.suggestedAddress, 'SN-SOIL-01-01');
    expect(
      nodeChoices(
        stock,
        usedAddresses: {'sn-soil-01-01', 'SN-SOIL-01-02'},
      ).single.suggestedAddress,
      'SN-SOIL-01-03',
    );
  });

  test('nhận ra lỗi trùng địa chỉ từ backend', () {
    expect(
      isAddressConflict(
        Exception(
          'A hardware address is already provisioned on another Gateway: X.',
        ),
      ),
      isTrue,
    );
    expect(
      isAddressConflict(Exception('Deployment Request must be Installing.')),
      isFalse,
    );
  });

  test(
    'hàng theo số lượng không bị ẩn sau lần gắn đầu; địa chỉ gợi ý chạy tiếp mã-01, mã-02…',
    () {
      final stock = [
        {
          'id': '1',
          'code': 'SN-SOIL-01',
          'name': 'Node đo đất',
          'category': 'SOIL_SENSOR',
          'estimateRole': 'SensorNode',
          'quantityInStock': 9,
        },
        {
          'id': '2',
          'code': 'NODE-A',
          'name': 'Node A',
          'category': 'Node',
          'serialNumber': 'SN-A',
          'quantityInStock': 1,
        },
        {
          'id': '3',
          'code': 'NODE-B',
          'name': 'Node B',
          'category': 'Node',
          'serialNumber': 'SN-B',
          'quantityInStock': 1,
        },
      ];
      var list = nodeChoices(stock);
      expect(list.map((n) => n.suggestedAddress), [
        'SN-SOIL-01-01',
        'SN-A',
        'SN-B',
      ]);
      // đã cấp phát một Node SN-SOIL-01-01 và serial SN-A
      list = nodeChoices(stock, usedAddresses: {'SN-SOIL-01-01', 'SN-A'});
      expect(list.map((n) => n.code), [
        'SN-SOIL-01',
        'NODE-B',
      ]); // hàng số lượng còn tồn vẫn hiện; serial đã dùng thì ẩn
      expect(list.first.suggestedAddress, 'SN-SOIL-01-02');
      // bản cũ ẩn luôn hàng nếu địa chỉ trùng mã
      expect(
        nodeChoices(stock, usedAddresses: {'SN-SOIL-01'}).map((n) => n.code),
        contains('SN-SOIL-01'),
      );
    },
  );

  test(
    'Node nhận theo vai trò dự toán, không chỉ theo tên loại (SOIL_SENSOR vẫn là Node cảm biến)',
    () {
      final list = nodeChoices([
        {
          'id': '1',
          'code': 'SN-SOIL-01',
          'name': 'Node đo đất',
          'category': 'SOIL_SENSOR',
          'estimateRole': 'SensorNode',
          'quantityInStock': 10,
        },
        {
          'id': '2',
          'code': 'ACT-VALVE-01',
          'name': 'Node điều khiển van',
          'category': 'VALVE',
          'estimateRole': 'ActuatorNode',
          'quantityInStock': 5,
        },
        {
          'id': '3',
          'code': 'GW-1',
          'name': 'Gateway',
          'category': 'GATEWAY',
          'estimateRole': 'Gateway',
          'quantityInStock': 3,
        },
        {
          'id': '4',
          'code': 'HW-KIT-01',
          'name': 'Phụ kiện',
          'category': 'Peripheral',
          'estimateRole': 'InstallKit',
          'quantityInStock': 9,
        },
        {
          'id': '5',
          'code': 'ACT-PUMP-RELAY',
          'name': 'Tủ bơm',
          'category': 'VALVE',
          'quantityInStock': 10,
        },
        {
          'id': '6',
          'code': 'SN-OLD',
          'name': 'Node cũ',
          'category': 'Node cảm biến',
          'quantityInStock': 0,
        },
      ]);
      expect(list.map((n) => n.code), ['SN-SOIL-01', 'ACT-VALVE-01']);
      expect(list[0].isActuator, isFalse);
      expect(list[1].isActuator, isTrue);
    },
  );

  test('Node điều khiển nhận theo TỪ nguyên, không theo chuỗi con', () {
    expect(_n('Node điều khiển van 1', 'Node').isActuator, isTrue);
    expect(_n('Node relay 4 kênh', 'Node').isActuator, isTrue);
    expect(_n('Node chấp hành', 'Node').isActuator, isTrue);
    expect(_n('Node Advanced soil', 'Node cảm biến').isActuator, isFalse);
    expect(_n('Caravan node', 'Node').isActuator, isFalse);
    expect(_n('Node cảm biến đất', 'Node cảm biến').isActuator, isFalse);
  });

  test('chưa gán vai trò: suy loại Node từ chủng loại kho như backend', () {
    expect(inferNodeType(null, 'VALVE'), 'ActuatorNode');
    expect(inferNodeType(null, 'ACTUATOR_NODE'), 'ActuatorNode');
    expect(inferNodeType(null, 'SOIL_SENSOR'), 'SensorNode');
    expect(inferNodeType(null, 'Peripheral'), isNull);
    expect(
      inferNodeType('SensorNode', 'VALVE'),
      'SensorNode',
    ); // Admin gán thì ưu tiên
    final valve = _n('Van điện từ', 'VALVE');
    expect(valve.roleKnown, isTrue);
    expect(valve.roleDeviceType, 'ActuatorNode');
  });

  test(
    'Gateway, camera, bộ lắp đặt không phải Node; hàng chưa gán vai trò chỉ liệt kê khi chủng loại có chữ NODE',
    () {
      Map<String, dynamic> p(String cat, {String? role}) => {
        'id': cat,
        'code': cat,
        'name': cat,
        'category': cat,
        'estimateRole': role,
        'quantityInStock': 3,
      };
      final out = nodeChoices([
        p('GATEWAY'),
        p('Camera'),
        p('Peripheral', role: 'InstallKit'),
        p('VALVE'),
        p('SENSOR_NODE'),
      ]);
      expect(out.map((e) => e.category), ['SENSOR_NODE']);
    },
  );
}
