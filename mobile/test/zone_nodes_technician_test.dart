import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/zone_operations_screens.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var telemetryAllowed = false;
  var locationsOk = true;

  Future<http.Response> handler(http.Request r) async {
    final p = r.url.path;
    if (p.endsWith('/telemetry/latest-by-device')) {
      return telemetryAllowed
          ? _json({'devices': <Object>[]})
          : _json({
              'title': 'Forbidden',
              'detail':
                  'The authenticated role is not allowed to access this resource.',
            }, 403);
    }
    if (p.endsWith('/devices/map-locations')) {
      return locationsOk
          ? _json([
              {
                'deviceId': 'd1',
                'deviceName': 'Node đất 01',
                'hardwareAddress': 'AA:BB:01',
                'latitude': 11.94,
                'longitude': 108.44,
              },
            ])
          : _json({'detail': 'Zone was not found.'}, 404);
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
    telemetryAllowed = false;
    locationsOk = true;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ZoneNodesScreen(
          zoneId: 'z1',
          zoneName: 'Khu ca chua 12',
          canEditLocations: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'kỹ thuật viên bị chặn số đo: vẫn thấy node, toạ độ và nút sửa, có ghi chú rõ',
    (tester) async {
      await pump(tester);
      expect(find.textContaining('not allowed'), findsNothing);
      expect(find.text('Node đất 01'), findsOneWidget);
      expect(find.text('Cập nhật toạ độ các node'), findsOneWidget);
      expect(find.textContaining('không được xem số đo'), findsOneWidget);
    },
  );

  testWidgets('được xem số đo: không có ghi chú', (tester) async {
    telemetryAllowed = true;
    await pump(tester);
    expect(find.text('Node đất 01'), findsOneWidget);
    expect(find.textContaining('không được xem số đo'), findsNothing);
  });

  testWidgets('vị trí node lỗi thì vẫn báo lỗi và cho thử lại', (tester) async {
    locationsOk = false;
    await pump(tester);
    expect(find.textContaining('Zone was not found'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
