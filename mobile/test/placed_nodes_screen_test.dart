import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/placed_nodes_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var locHttp = 200;
  var devHttp = 200;
  var locations = <Map<String, dynamic>>[];

  Future<http.Response> handler(http.Request r) async {
    final p = r.url.path;
    if (p.endsWith('/devices/map-locations')) {
      return locHttp == 200
          ? _json(locations)
          : _json({'detail': 'boom'}, locHttp);
    }
    if (p == '/api/v1/farms/f1/devices') {
      return devHttp == 200
          ? _json([
              {
                'deviceId': 'a',
                'hardwareAddress': 'SENSOR-A',
                'deviceType': 'SensorNode',
                'status': 'Online',
                'lastSeenAtUtc': '2026-11-13T07:00:00Z',
                'latestConnectionTest': {
                  'succeeded': true,
                  'observedAtUtc': 'x',
                },
              },
              {
                'deviceId': 'b',
                'hardwareAddress': 'ACT-B',
                'deviceType': 'ActuatorNode',
                'status': 'Offline',
              },
            ])
          : _json({'detail': 'boom'}, devHttp);
    }
    if (p == '/api/v1/zones/z1') {
      return _json({
        'zoneId': 'z1',
        'farmId': 'f1',
        'fieldId': 'fl1',
        'name': 'Zone 1',
        'areaM2': 500,
        'boundaryGeoJson': {
          'type': 'Polygon',
          'coordinates': [
            [
              [100.0, 10.0],
              [100.001, 10.0],
              [100.001, 10.001],
              [100.0, 10.001],
              [100.0, 10.0],
            ],
          ],
        },
      });
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
    locHttp = 200;
    devHttp = 200;
    locations = [
      {
        'deviceId': 'a',
        'hardwareAddress': 'SENSOR-A',
        'deviceType': 'SensorNode',
        'latitude': 10.0004,
        'longitude': 100.0004,
        'batteryLevel': 87,
        'rssi': -71,
      },
      {
        'deviceId': 'b',
        'hardwareAddress': 'ACT-B',
        'deviceType': 'ActuatorNode',
        'latitude': 10.0006,
        'longitude': 100.0006,
      },
    ];
  });

  Future<void> pump(WidgetTester tester, {double width = 1200}) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlacedNodesScreen(zoneId: 'z1', farmId: 'f1'),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  testWidgets(
    'liệt kê Node đã chấm kèm tình trạng, pin, tín hiệu, kiểm tra kết nối; bản đồ có ranh giới Zone',
    (tester) async {
      await pump(tester);
      expect(find.text('Node đã chấm · Zone 1'), findsOneWidget);
      expect(
        find.textContaining(
          '2 Node đã chấm · 1 trực tuyến · 1 mất kết nối/lỗi',
        ),
        findsOneWidget,
      );
      expect(find.text('Trực tuyến'), findsOneWidget);
      expect(find.text('Mất kết nối'), findsOneWidget);
      expect(find.text('Pin: 87%'), findsOneWidget);
      expect(find.textContaining('RSSI): -71 dBm'), findsOneWidget);
      expect(find.text('Pin: chưa có dữ liệu'), findsOneWidget);
      expect(
        find.textContaining('Thấy gần nhất: 2026-11-13T07:00:00Z'),
        findsOneWidget,
      );
      expect(find.textContaining('(KTV nhập thủ công): đạt'), findsOneWidget);
      expect(find.text('Node điều khiển'), findsOneWidget);
      expect(find.byType(PolygonLayer), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    },
  );

  testWidgets('chưa chấm Node nào: báo rõ, không hiện số giả', (tester) async {
    locations = [];
    await pump(tester);
    expect(
      find.text('Chưa có Node nào được chấm vị trí trong Zone này.'),
      findsOneWidget,
    );
    expect(find.textContaining('0 Node đã chấm'), findsOneWidget);
  });

  testWidgets('lỗi tải vị trí: báo lỗi + thử lại, không coi là chưa có Node', (
    tester,
  ) async {
    locHttp = 500;
    await pump(tester);
    expect(
      find.text('Chưa có Node nào được chấm vị trí trong Zone này.'),
      findsNothing,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets(
    'lỗi tải thông tin thiết bị: vẫn xem được vị trí, thiếu phần trạng thái chi tiết',
    (tester) async {
      devHttp = 500;
      await pump(tester);
      expect(find.text('SENSOR-A'), findsWidgets);
      expect(find.text('Heartbeat thực tế: chưa nhận'), findsWidgets);
    },
  );

  test('nodeStatusInfo: nhãn tiếng Việt theo trạng thái thiết bị', () {
    expect(nodeStatusInfo('Online').ok, isTrue);
    expect(nodeStatusInfo('Offline').ok, isFalse);
    expect(nodeStatusInfo('MaintenanceRequired').label, 'Cần bảo trì');
    expect(nodeStatusInfo('Assigned').ok, isNull);
    expect(nodeStatusInfo('Unassigned').label, 'Chưa gán Zone');
    expect(nodeStatusInfo('').label, 'Chưa rõ');
  });

  testWidgets('bản đồ có nút + / − và phóng được quá mức 19', (tester) async {
    await pump(tester);
    final ctrl = MapController.maybeOf(
      tester.element(find.byType(PolygonLayer)),
    );
    expect(ctrl, isNotNull);
    final z0 = ctrl!.camera.zoom;
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Phóng to'));
      await tester.pump();
    }
    expect(ctrl.camera.zoom, greaterThan(z0));
    expect(ctrl.camera.zoom, greaterThan(19));
    await tester.tap(find.byTooltip('Thu nhỏ'));
    await tester.pump();
    expect(ctrl.camera.zoom, lessThanOrEqualTo(22));
  });
}
