import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/support/acceptance_report.dart';

IotDevice _dev(String id, String type, {bool? test}) => IotDevice.fromJson({
  'deviceId': id,
  'gatewayId': 'g1',
  'deploymentRequestId': 'dep1',
  'zoneId': 'z1',
  'hardwareAddress': 'HW-$id',
  'deviceType': type,
  'status': 'Online',
  'latestConnectionTest': ?(test == null
      ? null
      : {'succeeded': test, 'observedAtUtc': '2026-11-12T08:00:00Z'}),
});

void main() {
  test('biên bản: đếm node đã chấm/kết nối, thiếu dữ liệu hiện "—"', () {
    final r = buildAcceptanceReport(
      farm: 'Trang trại A',
      zone: 'Nhà màng 1',
      areaM2: 930,
      devices: [
        _dev('a', 'SensorNode', test: true),
        _dev('b', 'ActuatorNode', test: false),
        _dev('c', 'SensorNode'),
      ],
      saved: {
        'a': {'latitude': 10.0004, 'longitude': 100.0004},
        'b': {'latitude': 10.0006, 'longitude': 100.0006},
      },
      note: '  Đạt  ',
    );
    expect(r.farm, 'Trang trại A');
    expect(r.field, '—'); // không có tên thửa đất thì không bịa
    expect(r.area, '930 m²');
    expect(r.nodes, hasLength(3));
    expect(r.located, 2);
    expect(r.connected, 1);
    expect(r.nodes[1].kind, 'Node điều khiển');
    expect(r.nodes[2].location, 'Chưa chấm vị trí');
    expect(r.nodes[2].connection, 'Chưa kiểm tra kết nối');
    expect(r.note, 'Đạt');
    expect(buildAcceptanceReport(devices: const []).area, '—');
  });

  testWidgets('bảng biên bản: Chưa → null, Xác nhận trả ghi chú', (t) async {
    String? result = 'chưa mở';
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => result = await showAcceptanceReportSheet(
                context,
                report: buildAcceptanceReport(
                  farm: 'F',
                  zone: 'Z',
                  devices: [_dev('a', 'SensorNode', test: true)],
                ),
                remainingLabel: '70%',
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    expect(find.text('BIÊN BẢN NGHIỆM THU LẮP ĐẶT'), findsOneWidget);
    expect(find.textContaining('HW-a'), findsOneWidget);
    await t.tap(find.text('Chưa'));
    await t.pumpAndSettle();
    expect(result, isNull);

    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('acceptance-note')), ' Ổn ');
    await t.tap(find.byKey(const ValueKey('acceptance-confirm')));
    await t.pumpAndSettle();
    expect(result, 'Ổn');
  });
}
