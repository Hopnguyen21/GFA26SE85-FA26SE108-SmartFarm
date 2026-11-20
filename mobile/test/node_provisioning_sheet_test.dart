import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart'
    show GeocodeResult, GeocodeFailureKind;
import 'package:smartfarm_mobile/core/services/gps_service.dart';
import 'package:smartfarm_mobile/features/support/node_provisioning_flow.dart';
import 'package:smartfarm_mobile/features/support/node_provisioning_sheet.dart';

void main() {
  addressTests();
  testWidgets(
    'backend báo trùng địa chỉ: ghi nhớ, gợi ý lại số kế tiếp; chọn lại thì cấp phát được',
    (t) async {
      final stock = [
        {
          'id': 'q1',
          'code': 'SN-SOIL-01',
          'name': 'Node đo đất',
          'category': 'SOIL_SENSOR',
          'estimateRole': 'SensorNode',
          'quantityInStock': 9,
        },
      ];
      final tried = <String>[];
      bool? popped;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async => popped = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NodeProvisionSheet(
                    slotLabel: 'Node cảm biến · 1/1',
                    actuator: false,
                    load: (taken) async =>
                        nodeChoices(stock, usedAddresses: taken),
                    provision: (n, address, install) async {
                      tried.add(address);
                      if (address == 'SN-SOIL-01-01') {
                        throw Exception(
                          'A hardware address is already provisioned on another Gateway: SN-SOIL-01-01.',
                        );
                      }
                    },
                  ),
                ),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      // lần 1: địa chỉ gợi ý SN-SOIL-01-01 bị backend báo trùng
      await t.tap(find.byKey(const ValueKey('node-q1')));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'SN-SOIL-01-01'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('node-address-ok')));
      await t.pumpAndSettle();
      expect(find.textContaining('đã được dùng ở nơi khác'), findsOneWidget);
      // lần 2: gợi ý lại -02, chấp nhận
      await t.tap(find.byKey(const ValueKey('node-q1')));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'SN-SOIL-01-02'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('node-address-ok')));
      await t.pumpAndSettle();
      expect(tried, ['SN-SOIL-01-01', 'SN-SOIL-01-02']);
      expect(popped, isTrue);
    },
  );

  testWidgets(
    'dòng Node điều khiển: hàng cảm biến (có vai trò rõ) không được gợi ý',
    (t) async {
      final stock = [
        {
          'id': 's1',
          'code': 'SN-SOIL-01',
          'name': 'Node đo đất',
          'category': 'SOIL_SENSOR',
          'estimateRole': 'SensorNode',
          'quantityInStock': 9,
        },
        {
          'id': 'a1',
          'code': 'ACT-VALVE-01',
          'name': 'Node điều khiển van',
          'category': 'VALVE',
          'estimateRole': 'ActuatorNode',
          'quantityInStock': 5,
        },
      ];
      final tried = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NodeProvisionSheet(
              slotLabel: 'Node điều khiển · 1/1',
              actuator: true,
              load: (taken) async => nodeChoices(stock, usedAddresses: taken),
              provision: (n, address, install) async => tried.add(n.code),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('node-s1')), findsNothing);
      expect(find.byKey(const ValueKey('node-a1')), findsOneWidget);
      expect(tried, isEmpty);
    },
  );

  testWidgets(
    'bắt buộc đúng loại hợp đồng: chỉ hiện hàng kho cùng mã với dòng đang chấm; mã khác (kể cả cùng loại) bị ẩn; không hỏi xác nhận',
    (t) async {
      final stock = [
        {
          'id': 'v1',
          'code': 'ACT-VALVE-01',
          'name': 'Van',
          'category': 'Node',
          'quantityInStock': 4,
        },
        {
          'id': 's1',
          'code': 'SN-SOIL-01',
          'name': 'Đo đất',
          'category': 'Node',
          'quantityInStock': 4,
        },
        {
          'id': 'x1',
          'code': 'MYSTERY-1',
          'name': 'Node lạ',
          'category': 'Node',
          'quantityInStock': 4,
        },
      ];
      final tried = <String>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NodeProvisionSheet(
              slotLabel: 'Node điều khiển · 1/1',
              actuator: true,
              slotCode: 'ACT-VALVE-01',
              contractKinds: const {'ACT-VALVE-01': true, 'SN-SOIL-01': false},
              load: (taken) async => nodeChoices(stock, usedAddresses: taken),
              provision: (n, address, install) async => tried.add(n.code),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('node-s1')),
        findsNothing,
      ); // SN-SOIL-01 là cảm biến theo hợp đồng
      // mã lạ và mã của dòng khác không được đưa ra
      expect(find.byKey(const ValueKey('node-x1')), findsNothing);
      expect(find.byKey(const ValueKey('node-v1')), findsOneWidget);
      // chọn là vào thẳng hộp địa chỉ, không có hộp xác nhận loại nào
      for (final id in ['node-v1']) {
        await t.tap(find.byKey(ValueKey(id)));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('node-address-ok')), findsOneWidget);
        await t.tap(find.text('Hủy'));
        await t.pumpAndSettle();
      }
    },
  );
}

class _FakeGps implements GpsProvider {
  final GpsFix? fix;
  final GpsException? error;
  _FakeGps({this.fix, this.error});
  @override
  Future<GpsFix> current() async {
    if (error != null) throw error!;
    return fix!;
  }
}

final _stock = [
  {
    'id': 'q1',
    'code': 'SN-SOIL-01',
    'name': 'Node đo đất',
    'category': 'SOIL_SENSOR',
    'estimateRole': 'SensorNode',
    'quantityInStock': 9,
  },
];

Future<void> _openDialog(
  WidgetTester t, {
  required List<(String, String?)> calls,
  GpsProvider? gps,
  Future<GeocodeResult> Function(double, double)? lookup,
}) async {
  await t.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: NodeProvisionSheet(
                    slotLabel: 'Node cảm biến · 1/1',
                    actuator: false,
                    load: (taken) async =>
                        nodeChoices(_stock, usedAddresses: taken),
                    gps:
                        gps ??
                        _FakeGps(
                          error: const GpsException(GpsFailure.unknown, 'x'),
                        ),
                    addressLookup: lookup,
                    provision: (n, address, install) async =>
                        calls.add((address, install)),
                  ),
                ),
              ),
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('mở'));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('node-q1')));
  await t.pumpAndSettle();
}

void addressTests() {
  testWidgets(
    'địa chỉ nơi lắp đặt nhập tay: truyền cho provision; để trống thì null',
    (t) async {
      final calls = <(String, String?)>[];
      await _openDialog(t, calls: calls);
      await t.enterText(
        find.byKey(const ValueKey('node-install-address')),
        'Nhà màng 02, Đà Lạt',
      );
      await t.tap(find.byKey(const ValueKey('node-address-ok')));
      await t.pumpAndSettle();
      expect(calls.single.$2, 'Nhà màng 02, Đà Lạt');

      final calls2 = <(String, String?)>[];
      await _openDialog(t, calls: calls2);
      await t.tap(find.byKey(const ValueKey('node-address-ok')));
      await t.pumpAndSettle();
      expect(calls2.single.$2, isNull);
    },
  );

  testWidgets('nút Lấy địa chỉ từ GPS: điền ô bằng địa chỉ tra được', (
    t,
  ) async {
    final calls = <(String, String?)>[];
    await _openDialog(
      t,
      calls: calls,
      gps: _FakeGps(
        fix: const GpsFix(latitude: 11.94, longitude: 108.44, accuracyM: 5),
      ),
      lookup: (lat, lng) async {
        expect(lat, 11.94);
        return GeocodeResult.success('Xã Xuân Thọ, Đà Lạt, Lâm Đồng');
      },
    );
    await t.tap(find.byKey(const ValueKey('node-address-gps')));
    await t.pumpAndSettle();
    expect(find.text('Xã Xuân Thọ, Đà Lạt, Lâm Đồng'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('node-address-ok')));
    await t.pumpAndSettle();
    expect(calls.single.$2, 'Xã Xuân Thọ, Đà Lạt, Lâm Đồng');
  });

  testWidgets(
    'GPS lỗi hoặc không tra được địa chỉ: giữ nội dung đã gõ, báo lý do, vẫn nhập tay được',
    (t) async {
      final calls = <(String, String?)>[];
      await _openDialog(
        t,
        calls: calls,
        gps: _FakeGps(
          error: const GpsException(
            GpsFailure.serviceDisabled,
            'Dịch vụ vị trí đang tắt.',
          ),
        ),
      );
      await t.enterText(
        find.byKey(const ValueKey('node-install-address')),
        'Lô A',
      );
      await t.tap(find.byKey(const ValueKey('node-address-gps')));
      await t.pumpAndSettle();
      expect(find.text('Dịch vụ vị trí đang tắt.'), findsOneWidget);
      expect(find.text('Lô A'), findsOneWidget);

      final calls2 = <(String, String?)>[];
      await _openDialog(
        t,
        calls: calls2,
        gps: _FakeGps(
          fix: const GpsFix(latitude: 1, longitude: 2, accuracyM: 5),
        ),
        lookup: (lat, lng) async =>
            GeocodeResult.failed(GeocodeFailureKind.notFound),
      );
      await t.tap(find.byKey(const ValueKey('node-address-gps')));
      await t.pumpAndSettle();
      expect(find.textContaining('Chưa tìm được tên địa điểm'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('node-address-ok')));
      await t.pumpAndSettle();
      expect(calls2.single.$2, isNull);
    },
  );
}
