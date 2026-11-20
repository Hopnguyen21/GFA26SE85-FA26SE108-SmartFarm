import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/features/zones/actuator_labels.dart';

ActuatorModel _a(String dev, int ch, String status) => ActuatorModel.fromJson({
  'actuatorId': '$dev-$ch',
  'zoneId': 'z1',
  'deviceId': dev,
  'name': 'Thiết bị IrrigationValve #$ch',
  'actuatorType': 'PUMP',
  'relayChannel': ch,
  'status': status,
});

void main() {
  countTests();
  test('ActuatorModel đọc node, cổng relay và trạng thái thô', () {
    final a = _a('dev-1', 3, 'MAINTENANCE');
    expect((a.deviceId, a.relayChannel, a.status), ('dev-1', 3, 'MAINTENANCE'));
    expect(a.isRunning, isFalse);
  });

  test('2 node × 4 cổng: tên trùng nhưng nhãn vị trí khác nhau', () {
    final all = [
      for (final d in ['dev-a', 'dev-b'])
        for (var c = 1; c <= 4; c++) _a(d, c, 'OFF'),
    ];
    final labels = all.map((x) => actuatorPlaceLabel(x, all)).toSet();
    expect(labels.length, 8);
    expect(actuatorPlaceLabel(all.first, all), 'Node 1/2 · Cổng relay 1');
    expect(actuatorPlaceLabel(all.last, all), 'Node 2/2 · Cổng relay 4');
  });

  test('một node duy nhất: chỉ hiện cổng relay; thiếu dữ liệu: null', () {
    final one = [_a('dev-a', 2, 'OFF')];
    expect(actuatorPlaceLabel(one.first, one), 'Cổng relay 2');
    final bare = ActuatorModel(
      actuatorId: 'x',
      zoneId: 'z',
      name: 'n',
      actuatorType: 'PUMP',
    );
    expect(actuatorPlaceLabel(bare, [bare]), isNull);
  });

  test(
    'MAINTENANCE/OFFLINE: có lý do chưa điều khiển được; OFF/ON thì không',
    () {
      expect(actuatorNotReadyReason(_a('d', 1, 'MAINTENANCE')), isNotNull);
      expect(actuatorNotReadyReason(_a('d', 1, 'offline')), isNotNull);
      expect(actuatorNotReadyReason(_a('d', 1, 'OFF')), isNull);
      expect(actuatorNotReadyReason(_a('d', 1, 'ON')), isNull);
    },
  );
}

void countTests() {
  test('relaySummary: kênh và node tách bạch', () {
    final all = [
      for (final d in ['a', 'b'])
        for (var c = 1; c <= 4; c++) _a(d, c, 'OFF'),
    ];
    expect(relaySummary(all), '8 kênh · 2 node');
    expect(relaySummary(const []), '0 kênh');
  });
  test(
    'countZoneNodes: đếm đúng loại, giả lập và online (dữ liệu Khu cà chua 12)',
    () {
      final c = countZoneNodes([
        {
          'deviceType': 'ActuatorNode',
          'hardwareAddress': '24:DC:C3:44:01:02',
          'status': 'Online',
        },
        {
          'deviceType': 'ActuatorNode',
          'hardwareAddress': '24:DC:C3:44:01:01',
          'status': 'Online',
        },
        {
          'deviceType': 'SensorNode',
          'hardwareAddress': 'SIM-NODE-84742C3A',
          'status': 'Online',
        },
        {
          'deviceType': 'SensorNode',
          'hardwareAddress': '24:DC:C3:77:02:02',
          'status': 'Offline',
        },
        {
          'deviceType': 'SensorNode',
          'hardwareAddress': '24:DC:C3:88:00:01',
          'status': 'Online',
        },
        {
          'deviceType': 'SensorNode',
          'hardwareAddress': '24:DC:C3:77:02:01',
          'status': 'Online',
        },
      ]);
      expect(
        (c.total, c.sensors, c.actuators, c.simulated, c.online),
        (6, 4, 2, 1, 5),
      );
    },
  );
}
