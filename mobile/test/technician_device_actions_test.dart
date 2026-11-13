import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/devices/technician_gateway_tools_screen.dart';
import 'package:smartfarm_mobile/features/devices/widgets/device_actions_sheet.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

DeviceHealthModel _device({
  String? zoneId = 'z1',
  String type = 'SENSOR_NODE',
}) => DeviceHealthModel(
  nodeId: 'AA:BB',
  name: 'Node AA:BB',
  type: type,
  lastSeenAt: DateTime.now(),
  expectedIntervalSeconds: 60,
  deviceId: 'd1',
  zoneId: zoneId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];
  var pingStatus = 200;
  var heldParts = <Map<String, dynamic>>[];
  var detailOk = true;

  final stock = [
    {
      'id': 'gw1',
      'code': 'GW-1',
      'name': 'Gateway LoRa',
      'category': 'GATEWAY',
      'quantityInStock': 3,
      'assignedTechnicianId': null,
    },
    {
      'id': 'cb1',
      'code': 'CB-1',
      'name': 'Cáp nối',
      'category': 'ACCESSORY',
      'quantityInStock': 10,
      'assignedTechnicianId': null,
    },
    {
      'id': 'x1',
      'code': 'X-1',
      'name': 'Đã có người giữ',
      'category': 'ACCESSORY',
      'quantityInStock': 5,
      'assignedTechnicianId': 'someone',
    },
  ];

  Future<http.Response> handler(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (p.endsWith('/ping')) {
      return pingStatus == 200
          ? _json({
              'testId': 't1',
              'succeeded': true,
              'rssi': -92,
              'snr': 7.5,
              'roundTripLatencyMs': 420,
              'observedAtUtc': '2026-11-12T08:00:00Z',
            })
          : _json({'detail': 'No connection test'}, 404);
    }
    if (r.method == 'GET' && p.endsWith('/api/v1/devices/d1')) {
      return detailOk
          ? _json({
              'deviceId': 'd1',
              'sensors': ['SoilMoisture', 'Temperature'],
              'actuators': ['Pump'],
            })
          : _json({'detail': 'Device was not found.'}, 404);
    }
    if (r.method == 'PUT' &&
        (p.endsWith('/sensors') || p.endsWith('/actuators'))) {
      return _json({'deviceId': 'd1'});
    }
    if (p.endsWith('/diagnose')) {
      return _json({'diagnosticJobId': 'j1', 'status': 'Pending'}, 202);
    }
    if (p.endsWith('/unassign')) return _json({'deviceId': 'd1'});
    if (r.method == 'DELETE' && p.endsWith('/devices/d1')) {
      return http.Response('', 204);
    }
    if (p.endsWith('/platform/hardware-items')) return _json(stock);
    if (p.endsWith('/spare-parts')) return _json(heldParts);
    if (p.contains('/hardware-items/') &&
        (p.endsWith('/assign') || p.endsWith('/return'))) {
      return _json({'id': 'x'});
    }
    return _json([]);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 't@b.c',
      role: 'PlatformTechnician',
    );
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient(handler),
    );
  });

  setUp(() {
    calls.clear();
    pingStatus = 200;
    heldParts = [];
    detailOk = true;
  });

  Future<void> openSheet(WidgetTester tester, DeviceHealthModel d) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showDeviceActionsSheet(context, d, onChanged: () {}),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  group('Thao tác kỹ thuật trên node', () {
    testWidgets(
      'node đã gán Zone: có "Gỡ khỏi Zone", không có "Ngừng sử dụng"',
      (tester) async {
        await openSheet(tester, _device());
        expect(find.text('Kiểm tra kết nối gần nhất'), findsOneWidget);
        expect(find.text('Chẩn đoán từ xa'), findsOneWidget);
        expect(find.text('Gỡ khỏi Zone'), findsOneWidget);
        expect(find.text('Ngừng sử dụng thiết bị'), findsNothing);
      },
    );

    testWidgets('node chưa gán Zone: chỉ có "Ngừng sử dụng"', (tester) async {
      await openSheet(tester, _device(zoneId: null));
      expect(find.text('Gỡ khỏi Zone'), findsNothing);
      expect(find.text('Ngừng sử dụng thiết bị'), findsOneWidget);
    });

    testWidgets(
      'kiểm tra kết nối: hiện kết quả đã ghi nhận và nói rõ không phải phép đo mới',
      (tester) async {
        await openSheet(tester, _device());
        await tester.tap(find.text('Kiểm tra kết nối gần nhất'));
        await tester.pumpAndSettle();
        expect(calls.single.method, 'GET');
        expect(calls.single.url.path, endsWith('/api/v1/devices/d1/ping'));
        expect(find.text('Kết nối đạt'), findsOneWidget);
        expect(find.textContaining('RSSI: -92 dBm'), findsOneWidget);
        expect(find.textContaining('Độ trễ: 420 ms'), findsOneWidget);
        expect(find.textContaining('không phải phép đo mới'), findsOneWidget);
      },
    );

    testWidgets('chưa từng kiểm tra (404): báo lỗi, không hiện kết quả giả', (
      tester,
    ) async {
      pingStatus = 404;
      await openSheet(tester, _device());
      await tester.tap(find.text('Kiểm tra kết nối gần nhất'));
      await tester.pumpAndSettle();
      expect(find.text('Kết nối đạt'), findsNothing);
      expect(find.textContaining('No connection test'), findsOneWidget);
    });

    testWidgets(
      'chẩn đoán "khởi động lại": gửi đúng hành động và không báo thành công giả',
      (tester) async {
        await openSheet(tester, _device());
        await tester.tap(find.text('Chẩn đoán từ xa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Khởi động lại node'));
        await tester.pumpAndSettle();
        final post = calls.singleWhere((c) => c.method == 'POST');
        expect(post.url.path, endsWith('/api/v1/devices/d1/diagnose'));
        expect(jsonDecode(post.body), {'action': 'REBOOT_NODE'});
        expect(find.textContaining('vào hàng đợi'), findsOneWidget);
        expect(find.textContaining('Chờ thiết bị phản hồi'), findsOneWidget);
      },
    );

    testWidgets('đổi kênh: bắt buộc nhập số kênh hợp lệ rồi mới gửi', (
      tester,
    ) async {
      await openSheet(tester, _device());
      await tester.tap(find.text('Chẩn đoán từ xa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đổi kênh tần số'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gửi lệnh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vui lòng nhập'), findsOneWidget);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
      await tester.enterText(find.byType(TextField), '921,5');
      await tester.tap(find.text('Gửi lệnh'));
      await tester.pumpAndSettle();
      final body =
          jsonDecode(calls.singleWhere((c) => c.method == 'POST').body)
              as Map<String, dynamic>;
      expect(body['action'], 'CHANGE_CHANNEL');
      expect(body['newFrequencyChannel'], 921.5);
    });

    testWidgets('gỡ khỏi Zone: lý do bắt buộc, gửi đúng Zone và thiết bị', (
      tester,
    ) async {
      await openSheet(tester, _device());
      await tester.tap(find.text('Gỡ khỏi Zone'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Gỡ khỏi Zone'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Vui lòng nhập lý do'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'Thay vị trí lắp');
      await tester.tap(find.widgetWithText(FilledButton, 'Gỡ khỏi Zone'));
      await tester.pumpAndSettle();
      final post = calls.single;
      expect(post.url.path, endsWith('/zones/z1/devices/d1/unassign'));
      expect(jsonDecode(post.body), {'reason': 'Thay vị trí lắp'});
    });

    testWidgets(
      'sửa cấu hình cảm biến: chọn sẵn loại đang có, đổi rồi lưu đúng PUT',
      (tester) async {
        await openSheet(tester, _device());
        await tester.tap(find.text('Cấu hình cảm biến'));
        await tester.pumpAndSettle();
        CheckboxListTile tile(String label) => tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, label),
        );
        expect(tile('Độ ẩm đất (%)').value, isTrue);
        expect(tile('Nhiệt độ (°C)').value, isTrue);
        expect(tile('pH (pH)').value, isFalse);
        await tester.tap(find.text('pH (pH)'));
        await tester.tap(find.text('Nhiệt độ (°C)'));
        await tester.enterText(find.byType(TextField), '30');
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pumpAndSettle();
        final put = calls.singleWhere((c) => c.method == 'PUT');
        expect(put.url.path, endsWith('/api/v1/devices/d1/sensors'));
        final sensors = (jsonDecode(put.body)['sensors'] as List).cast<Map>();
        expect(
          [for (final s in sensors) s['sensorType']],
          ['SoilMoisture', 'Ph'],
        );
        expect(sensors.every((s) => s['samplingIntervalSec'] == 30), isTrue);
        expect(find.textContaining('Đã lưu cấu hình'), findsOneWidget);
      },
    );

    testWidgets('cảm biến: không chọn gì hoặc chu kỳ sai thì không gửi', (
      tester,
    ) async {
      await openSheet(tester, _device());
      await tester.tap(find.text('Cấu hình cảm biến'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('từ 10 đến 3600 giây'), findsOneWidget);
      expect(calls.where((c) => c.method == 'PUT'), isEmpty);
    });

    testWidgets(
      'node điều khiển: kênh relay phải nhập lại, trùng kênh bị chặn, lưu đúng PUT',
      (tester) async {
        await openSheet(tester, _device(type: 'ACTUATOR_NODE'));
        expect(find.text('Cấu hình cảm biến'), findsNothing);
        await tester.tap(find.text('Cấu hình cơ cấu chấp hành'));
        await tester.pumpAndSettle();
        expect(
          find.text('Cơ cấu 1'),
          findsOneWidget,
        ); // dựng sẵn từ loại hiện có (Pump)
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('kênh relay phải từ 1 đến 8'),
          findsOneWidget,
        );
        expect(calls.where((c) => c.method == 'PUT'), isEmpty);
        await tester.enterText(
          find.widgetWithText(TextField, 'Kênh relay (1–8)'),
          '3',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Chạy tối đa (phút, 1–30)'),
          '45',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pumpAndSettle();
        expect(find.textContaining('từ 1 đến 30 phút'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Chạy tối đa (phút, 1–30)'),
          '15',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
        await tester.pumpAndSettle();
        final put = calls.singleWhere((c) => c.method == 'PUT');
        expect(put.url.path, endsWith('/api/v1/devices/d1/actuators'));
        expect(jsonDecode(put.body), {
          'actuators': [
            {
              'actuatorType': 'Pump',
              'relayChannel': 3,
              'maxDurationMinutes': 15,
            },
          ],
        });
      },
    );

    testWidgets(
      'đọc cấu hình hiện có lỗi: báo lỗi, không mở hộp thoại để ghi đè mù',
      (tester) async {
        detailOk = false;
        await openSheet(tester, _device());
        await tester.tap(find.text('Cấu hình cảm biến'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Device was not found'), findsOneWidget);
        expect(find.text('Lưu'), findsNothing);
      },
    );

    testWidgets('ngừng sử dụng: xác nhận rồi gọi DELETE (204)', (tester) async {
      await openSheet(tester, _device(zoneId: null));
      await tester.tap(find.text('Ngừng sử dụng thiết bị'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Ngừng sử dụng'));
      await tester.pumpAndSettle();
      final del = calls.single;
      expect(del.method, 'DELETE');
      expect(del.url.path, endsWith('/api/v1/devices/d1'));
      expect(find.textContaining('Đã ngừng sử dụng'), findsOneWidget);
    });
  });

  group('Kho linh kiện của kỹ thuật viên', () {
    Future<void> openParts(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: TechnicianGatewayToolsScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kho linh kiện'));
      await tester.pumpAndSettle();
    }

    testWidgets('nhận Gateway: chỉ liệt kê món còn trong kho, gửi số lượng 1', (
      tester,
    ) async {
      await openParts(tester);
      expect(find.text('Bạn chưa giữ linh kiện nào.'), findsOneWidget);
      await tester.tap(find.text('Nhận linh kiện từ kho'));
      await tester.pumpAndSettle();
      expect(find.text('Gateway LoRa'), findsOneWidget);
      expect(find.text('Cáp nối'), findsOneWidget);
      expect(find.text('Đã có người giữ'), findsNothing);
      await tester.tap(find.text('Gateway LoRa'));
      await tester.pumpAndSettle();
      final post = calls.singleWhere((c) => c.method == 'POST');
      expect(post.url.path, endsWith('/platform/hardware-items/gw1/assign'));
      expect(jsonDecode(post.body), {'quantity': 1});
    });

    testWidgets('nhận vật tư: hỏi số lượng, từ chối số vượt tồn kho', (
      tester,
    ) async {
      await openParts(tester);
      await tester.tap(find.text('Nhận linh kiện từ kho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cáp nối'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '99');
      await tester.tap(find.widgetWithText(FilledButton, 'Nhận'));
      await tester.pumpAndSettle();
      expect(find.textContaining('từ 1 đến 10'), findsOneWidget);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('trả kho: xác nhận rồi gọi đúng món', (tester) async {
      heldParts = [
        {
          'id': 'gw9',
          'code': 'GW-9',
          'name': 'Gateway đang giữ',
          'category': 'GATEWAY',
          'quantityInStock': 1,
        },
      ];
      await openParts(tester);
      await tester.tap(find.text('Trả kho'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Trả kho'));
      await tester.pumpAndSettle();
      final post = calls.singleWhere((c) => c.method == 'POST');
      expect(post.url.path, endsWith('/platform/hardware-items/gw9/return'));
    });

    testWidgets('chọn "Giữ lại" khi trả kho: không gọi API', (tester) async {
      heldParts = [
        {
          'id': 'gw9',
          'code': 'GW-9',
          'name': 'Gateway đang giữ',
          'category': 'GATEWAY',
          'quantityInStock': 1,
        },
      ];
      await openParts(tester);
      await tester.tap(find.text('Trả kho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giữ lại'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
    });
  });
}
