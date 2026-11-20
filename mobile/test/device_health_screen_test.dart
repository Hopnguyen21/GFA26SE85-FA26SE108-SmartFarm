import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/devices/device_health_screen.dart';

http.Response _json(Object o) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<http.Response> Function(http.Request) _activeHandler = _defaultHandler;
Future<http.Response> _handler(http.Request r) => _activeHandler(r);

Future<http.Response> _defaultHandler(http.Request r) async {
  final p = r.url.path;
  if (p == '/api/v1/platform/deployment-requests') {
    return _json([
      {
        'requestId': 'dep1',
        'farmId': 'f1',
        'zoneId': 'z1',
        'status': 'Installing',
        'requiredParameters': [],
        'planItems': [],
        'surveys': [],
        'decisionHistory': [],
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/gateways') {
    return _json([
      {
        'gatewayId': 'g1',
        'gatewaySerial': 'GW-TEST-1',
        'lastSeenAtUtc': DateTime.now().toUtc().toIso8601String(),
        'telemetryIntervalSec': 60,
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/devices') {
    return _json([
      {
        'deviceId': 'd1',
        'hardwareAddress': 'SENS-1',
        'deviceType': 'SensorNode',
        'zoneId': 'z1',
        'lastSeenAtUtc': DateTime.now().toUtc().toIso8601String(),
      },
      {
        'deviceId': 'd2',
        'hardwareAddress': 'ACT-1',
        'deviceType': 'ActuatorNode',
        'zoneId': 'z1',
      },
    ]);
  }
  if (p == '/api/v1/zones/z1/devices/map-locations') return _json([]);
  return http.Response('', 404);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      () => MockClient(_handler),
    );
  });

  // Hồi quy: _reload từng gọi setState(() => _future = f) — hàm trả về Future nên bản debug ném lỗi
  // "setState() callback argument returned a Future" và màn hình quay mãi, không hiện thiết bị.
  testWidgets(
    'màn Thiết Bị của kỹ thuật viên hiện danh sách, không lỗi setState và không quay mãi',
    (t) async {
      t.view.physicalSize = const Size(420, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = FarmProvider()..switchRole('TECHNICIAN');
      await http.runWithClient(() async {
        await t.pumpWidget(
          ChangeNotifierProvider<FarmProvider>.value(
            value: p,
            child: const MaterialApp(home: DeviceHealthScreen()),
          ),
        );
        await t.pump();
        for (
          var i = 0;
          i < 30 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(t.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('Gateway GW-TEST-1'), findsOneWidget);
        expect(find.textContaining('SENS-1'), findsWidgets);
        expect(find.textContaining('ACT-1'), findsWidgets);
        await t.pumpWidget(const SizedBox());
        p.dispose();
        await t.pump(const Duration(seconds: 12));
      }, () => MockClient(_handler));
    },
  );

  testWidgets(
    'phân trang danh sách thiết bị 10 cái / page, chuyển trang mượt mà',
    (t) async {
      t.view.physicalSize = const Size(420, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = FarmProvider()..switchRole('TECHNICIAN');

      // Tạo mock 25 thiết bị
      Future<http.Response> handler25(http.Request r) async {
        final path = r.url.path;
        if (path == '/api/v1/platform/deployment-requests') {
          return _json([
            {
              'requestId': 'dep1',
              'farmId': 'f1',
              'zoneId': 'z1',
              'status': 'Installing',
              'requiredParameters': [],
              'planItems': [],
              'surveys': [],
              'decisionHistory': [],
            },
          ]);
        }
        if (path == '/api/v1/farms/f1/gateways') return _json([]);
        if (path == '/api/v1/farms/f1/devices') {
          return _json([
            for (var i = 1; i <= 25; i++)
              {
                'deviceId': 'd$i',
                'hardwareAddress': 'NODE-${i.toString().padLeft(3, '0')}',
                'deviceType': 'SensorNode',
                'zoneId': 'z1',
              },
          ]);
        }
        if (path == '/api/v1/zones/z1/devices/map-locations') return _json([]);
        return http.Response('', 404);
      }

      _activeHandler = handler25;
      addTearDown(() => _activeHandler = _defaultHandler);

      await http.runWithClient(() async {
        await t.pumpWidget(
          ChangeNotifierProvider<FarmProvider>.value(
            value: p,
            child: const MaterialApp(home: DeviceHealthScreen()),
          ),
        );
        await t.pump();
        for (
          var i = 0;
          i < 30 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('DANH SÁCH THIẾT BỊ (25)'), findsOneWidget);
        expect(find.text('Trang 1 / 3'), findsOneWidget);
        expect(find.text('NODE-001'), findsOneWidget);
        expect(find.text('NODE-011'), findsNothing);

        // Cuộn xuống các nút phân trang và chuyển sang Trang 2
        await t.scrollUntilVisible(find.widgetWithText(FilledButton, '2'), 500);
        await t.tap(find.widgetWithText(FilledButton, '2'));
        await t.pumpAndSettle();

        expect(find.text('Trang 2 / 3'), findsOneWidget);
        expect(find.text('NODE-001'), findsNothing);
        expect(find.text('NODE-011'), findsOneWidget);
        expect(find.text('NODE-021'), findsNothing);

        await t.pumpWidget(const SizedBox());
        p.dispose();
      }, () => MockClient(handler25));
    },
  );
}
