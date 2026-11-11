import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/auth/password_screens.dart';
import 'package:smartfarm_mobile/features/reports/reports_screen.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/utils/export_utils.dart';

http.Response Function(http.Request) handler = (_) => http.Response('{}', 200);
final calls = <http.Request>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // _client là static lazy: khởi tạo lần đầu bên trong runWithClient để dùng MockClient.
    handler = (_) => http.Response('[]', 200);
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() {
    calls.clear();
    handler = (_) => http.Response('{}', 200);
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'PlatformTechnician');
  });

  group('Password API', () {
    test('changePassword success', () async {
      handler = (_) => http.Response('', 204);
      await AccountApi.changePassword(currentPassword: 'Old12345', newPassword: 'New12345');
      expect(calls.single.url.path, '/api/v1/users/me/password');
    });
    test('changePassword 404 -> UnsupportedApiException (no fake success)', () async {
      handler = (_) => http.Response('', 404);
      expect(
        AccountApi.changePassword(currentPassword: 'a', newPassword: 'b'),
        throwsA(isA<UnsupportedApiException>()),
      );
    });
    test('changePassword 400 -> Exception', () async {
      handler = (_) => http.Response(jsonEncode({'message': 'wrong password'}), 400);
      expect(AccountApi.changePassword(currentPassword: 'a', newPassword: 'b'), throwsA(isA<Exception>()));
    });
    test('forgotPassword unsupported', () async {
      handler = (_) => http.Response('', 404);
      expect(AccountApi.forgotPassword('a@b.c'), throwsA(isA<UnsupportedApiException>()));
    });
  });

  group('Maintenance / hot swap / MQTT / reports API', () {
    test('rejects unknown service action', () {
      expect(() => SupportApi.serviceRequestAction('1', 'delete-all'), throwsArgumentError);
    });
    test('accept posts to correct path', () async {
      handler = (_) => http.Response(jsonEncode({'id': '1', 'status': 'InProgress'}), 200);
      final r = await SupportApi.serviceRequestAction('1', 'accept');
      expect(r['status'], 'InProgress');
      expect(calls.single.url.path, '/api/v1/service-requests/1/accept');
    });
    test('hot swap sends old/new/request ids', () async {
      handler = (_) => http.Response(jsonEncode({'id': 'sr'}), 200);
      await SupportApi.hotSwapDevice(zoneId: 'z', oldDeviceId: 'o', serviceRequestId: 'sr', newDeviceId: 'n');
      expect(calls.single.url.path, '/api/v1/zones/z/devices/o/hot-swap');
      final body = jsonDecode(calls.single.body) as Map;
      expect(body['newDeviceId'], 'n');
      expect(body['serviceRequestId'], 'sr');
    });
    test('hot swap failure throws', () async {
      handler = (_) => http.Response(jsonEncode({'message': 'x'}), 409);
      expect(
        SupportApi.hotSwapDevice(zoneId: 'z', oldDeviceId: 'o', serviceRequestId: 's', newDeviceId: 'n'),
        throwsA(isA<Exception>()),
      );
    });
    test('mqtt status real value and error', () async {
      handler = (_) => http.Response(jsonEncode({'gatewayId': 'g', 'mqttConnected': false}), 200);
      expect((await SupportApi.getGatewayMqttStatus('g'))['mqttConnected'], false);
      handler = (_) => http.Response('', 500);
      expect(SupportApi.getGatewayMqttStatus('g'), throwsA(isA<Exception>()));
    });
    test('report kind whitelist and excel bytes', () async {
      expect(() => ReportApi.getFarmReport('f', '../x'), throwsArgumentError);
      handler = (_) => http.Response.bytes([1, 2, 3], 200);
      final bytes = await ReportApi.downloadFarmReportExcel(
        'f',
        from: DateTime.utc(2026, 1, 1),
        to: DateTime.utc(2026, 2, 1),
      );
      expect(bytes, [1, 2, 3]);
      expect(calls.single.url.path, '/api/v1/farms/f/report/excel');
      expect(calls.single.url.queryParameters.containsKey('fromUtc'), isTrue);
    });
  });

  group('Pure helpers', () {
    test('sumBucketsByZone handles null/empty', () {
      expect(sumBucketsByZone(null), isEmpty);
      expect(sumBucketsByZone({'buckets': []}), isEmpty);
      expect(
        sumBucketsByZone({
          'buckets': [
            {'zoneName': 'A', 'value': 2},
            {'zoneName': 'A', 'value': 3.5},
            {'zoneName': 'B', 'value': 1},
          ],
        }),
        {'A': 5.5, 'B': 1.0},
      );
    });
    test('telemetry CSV keeps zone/metric/range and blocks formula injection', () {
      final csv = buildTelemetryCsv(
        zoneName: '=cmd',
        metric: 'TEMP',
        range: '24 Giờ',
        points: [
          {'bucketStartUtc': '2026-01-01T00:00:00Z', 'average': 21.5},
        ],
      );
      expect(csv, contains("'=cmd"));
      expect(csv, contains('TEMP'));
      expect(csv, contains('24 Giờ'));
      expect(csv, contains('21.5'));
    });
    test('phone URI is validated and encoded', () {
      expect(buildPhoneUri('tel', '0901 234 567').toString(), 'tel:0901234567');
      expect(buildPhoneUri('sms', '+84 90 123 4567').toString(), 'sms:+84901234567');
      expect(buildPhoneUri('tel', 'abc'), isNull);
      expect(buildPhoneUri('tel', '123'), isNull);
      expect(buildPhoneUri('http', '0901234567'), isNull);
    });
    test('password rule', () {
      expect(validateNewPassword('short1'), isNotNull);
      expect(validateNewPassword('onlyletters'), isNotNull);
      expect(validateNewPassword('Abcdef12'), isNull);
    });
  });

  group('Password screens', () {
    testWidgets('change password: mismatch is rejected without calling API', (t) async {
      await t.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await t.enterText(find.byType(TextField).at(0), 'Old12345');
      await t.enterText(find.byType(TextField).at(1), 'New12345');
      await t.enterText(find.byType(TextField).at(2), 'Different1');
      await t.tap(find.byType(FilledButton));
      await t.pump();
      expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
      expect(calls, isEmpty);
    });
    testWidgets('password fields obscured by default', (t) async {
      await t.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      for (final f in t.widgetList<TextField>(find.byType(TextField))) {
        expect(f.obscureText, isTrue);
      }
    });
    testWidgets('change password shows unsupported-backend message on 404', (t) async {
      handler = (_) => http.Response('', 404);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
        await t.enterText(find.byType(TextField).at(0), 'Old12345');
        await t.enterText(find.byType(TextField).at(1), 'New12345');
        await t.enterText(find.byType(TextField).at(2), 'New12345');
        await t.tap(find.byType(FilledButton));
        await t.pumpAndSettle();
      }, () => MockClient((r) async => handler(r)));
      expect(find.textContaining('chưa hỗ trợ'), findsOneWidget);
    });
    testWidgets('forgot password rejects invalid email', (t) async {
      await t.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await t.enterText(find.byType(TextField).first, 'not-an-email');
      await t.tap(find.text('Gửi mã xác nhận'));
      await t.pump();
      expect(find.text('Email không hợp lệ.'), findsOneWidget);
    });
  });

  group('Persisted via API (no local-only fakes)', () {
    test('provider starts empty: no seeded farms/zones/tasks', () {
      final p = FarmProvider();
      expect(p.farms, isEmpty);
      expect(p.allZones, isEmpty);
      expect(p.fields, isEmpty);
      p.dispose();
    });
    test('addFarm posts to backend and returns server error instead of faking success', () async {
      handler = (r) =>
          r.method == 'POST' ? http.Response(jsonEncode({'message': 'invalid'}), 400) : http.Response('[]', 200);
      final p = FarmProvider();
      final err = await p.addFarm(name: 'Farm', address: 'x', totalAreaM2: 100);
      expect(err, isNotNull);
      expect(p.farms, isEmpty);
      expect(calls.any((c) => c.method == 'POST' && c.url.path == '/api/v1/farms'), isTrue);
      p.dispose();
    });
    test('addField / addNewZone require a drawn boundary', () async {
      final p = FarmProvider();
      expect(await p.addField(farmId: 'f', name: 'n', description: '', areaM2: 10), isNotNull);
      expect((await p.addNewZone(name: 'z', areaM2: 10, customFieldId: 'fld')).error, isNotNull);
      p.dispose();
    });
    test('createSchedule validates time and posts cron', () async {
      await expectLater(
        AutomationApi.createSchedule(zoneId: 'z', actuatorId: 'a', name: 'n', startTime: '25:99', durationMinutes: 5),
        throwsA(isA<Exception>()),
      );
      handler = (_) => http.Response(jsonEncode({'scheduleId': 's'}), 201);
      await AutomationApi.createSchedule(
        zoneId: 'z',
        actuatorId: 'a',
        name: 'n',
        startTime: '06:30',
        durationMinutes: 15,
      );
      final body = jsonDecode(calls.last.body) as Map;
      expect(body['cronExpression'], '30 6 * * *');
      expect(body['durationSeconds'], 900);
    });
    test('polygon GeoJSON is [lng,lat] and closed', () {
      final g = FarmApi.polygonGeoJson([
        [10, 100],
        [10, 101],
        [11, 101],
      ]);
      final ring = (g['coordinates'] as List).first as List;
      expect(ring.first, [100, 10]);
      expect(ring.first, ring.last);
    });
  });

  group('Crop library from API', () {
    final profileJson = {
      'profileId': 'p1',
      'cropId': 'c1',
      'cropName': 'Ca chua',
      'varietyId': 'v1',
      'varietyName': 'Beef',
      'name': 'Chuan',
      'description': 'd',
      'isSystemDefined': true,
      'stages': [
        {'stageId': 's2', 'name': 'Ra hoa', 'stageOrder': 2, 'durationDays': 20, 'requirements': []},
        {
          'stageId': 's1',
          'name': 'Nay mam',
          'stageOrder': 1,
          'durationDays': 10,
          'description': 'x',
          'requirements': [
            {'parameterCode': 'SoilMoisture', 'minValue': 60, 'maxValue': 80, 'targetValue': 70, 'unit': '%'},
            {'parameterCode': 'Temperature', 'minValue': 18, 'maxValue': 28, 'targetValue': 23, 'unit': 'C'},
          ],
        },
      ],
    };
    test('maps growth profile -> stages ordered, cumulative days, thresholds', () {
      final p = defaultCropProfileFromApi(profileJson, {
        'cropId': 'c1',
        'name': 'Ca chua',
        'scientificName': 'Solanum',
      });
      expect(p.cropId, 'p1');
      expect(p.realCropId, 'c1');
      expect(p.totalCycleDays, 30);
      expect(p.growthStages.first.name, 'Nay mam');
      expect(p.growthStages.first.requirements.soilMoistureMin, 60);
      expect(p.growthStages.last.startDayFromPlanting, 10);
    });
    test('library is empty until loaded, then filled from API; profiles without stages are dropped', () async {
      handler = (r) {
        if (r.url.path.endsWith('/growth-profiles')) {
          return http.Response(
            jsonEncode([
              profileJson,
              {...profileJson, 'profileId': 'p2', 'stages': []},
            ]),
            200,
          );
        }
        if (r.url.path.endsWith('/crops')) {
          return http.Response(
            jsonEncode([
              {'cropId': 'c1', 'name': 'Ca chua'},
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      };
      final p = FarmProvider();
      expect(p.defaultCropProfiles, isEmpty);
      await p.loadCropProfiles();
      expect(p.defaultCropProfiles.map((e) => e.cropId), ['p1']);
      p.dispose();
    });
    test('applyCropProfile attaches the profile to the Zone and creates NO season', () async {
      handler = (r) {
        if (r.url.path.endsWith('/growth-profiles')) return http.Response(jsonEncode([profileJson]), 200);
        if (r.url.path.endsWith('/crops')) return http.Response('[]', 200);
        if (r.method == 'PUT') return http.Response(jsonEncode({'zoneId': 'zone-x'}), 200);
        return http.Response('[]', 200);
      };
      final p = FarmProvider();
      await p.loadCropProfiles();
      final err = await p.applyCropProfile('p1', targetZoneId: 'zone-x');
      expect(err, isNull);
      expect(calls.where((c) => c.method == 'POST' && c.url.path.contains('planting-seasons')), isEmpty);
      final put = calls.firstWhere((c) => c.method == 'PUT' && c.url.path == '/api/v1/zones/zone-x');
      expect((jsonDecode(put.body) as Map)['growthProfileId'], 'p1');
      p.dispose();
    });
  });

  group('Sync error handling', () {
    test('network/server failure keeps state and reports syncError (not an empty account)', () async {
      handler = (_) => http.Response('', 500);
      final p = FarmProvider();
      await p.fetchFromApi();
      expect(p.syncError, isNotNull);
      expect(p.selectedFarmId, isEmpty);
      p.dispose();
    });
    test('getFarms throws on server error but returns [] for a genuinely empty list', () async {
      handler = (_) => http.Response('', 503);
      await expectLater(FarmApi.getFarms(), throwsA(isA<Exception>()));
      handler = (_) => http.Response('[]', 200);
      expect(await FarmApi.getFarms(), isEmpty);
    });
    test('appRole is exact', () {
      ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'PlatformAdmin');
      expect(ApiService.appRole, isNull);
      ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
      expect(ApiService.appRole, isNotNull);
    });
  });

  group('Maintenance screens', () {
    testWidgets('non-technician is blocked', (t) async {
      ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
      await t.pumpWidget(const MaterialApp(home: TechnicianMaintenanceScreen()));
      expect(find.text('Chức năng dành cho Kỹ thuật viên.'), findsOneWidget);
    });
    testWidgets('empty list state', (t) async {
      handler = (_) => http.Response('[]', 200);
      await t.pumpWidget(MaterialApp(home: _wrap(const TechnicianMaintenanceScreen())));
      await t.pumpAndSettle();
      expect(find.textContaining('Chưa có yêu cầu'), findsOneWidget);
    });
    testWidgets('error state with retry', (t) async {
      handler = (_) => http.Response('', 500);
      await t.pumpWidget(MaterialApp(home: _wrap(const TechnicianMaintenanceScreen())));
      await t.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });
    testWidgets('list shows items; detail offers accept once and guards double tap', (t) async {
      final req = {
        'id': 'r1',
        'failureCode': 'SENSOR_OFFLINE',
        'description': 'offline',
        'status': 'Assigned',
        'zoneId': 'z',
        'history': [],
      };
      handler = (r) {
        if (r.method == 'POST') return http.Response(jsonEncode({...req, 'status': 'InProgress'}), 200);
        return r.url.path.endsWith('/r1') ? http.Response(jsonEncode(req), 200) : http.Response(jsonEncode([req]), 200);
      };
      await t.pumpWidget(MaterialApp(home: _wrap(const TechnicianMaintenanceScreen())));
      await t.pumpAndSettle();
      expect(find.text('SENSOR_OFFLINE'), findsOneWidget);
      await t.tap(find.text('SENSOR_OFFLINE'));
      await t.pumpAndSettle();
      expect(find.text('Nhận việc'), findsOneWidget);
      await t.tap(find.text('Nhận việc'));
      await t.pumpAndSettle();
      expect(calls.where((c) => c.method == 'POST').length, 1);
      expect(find.text('Ghi chẩn đoán'), findsOneWidget);
    });
    testWidgets('hot-swap offered only when diagnosis is Replacement', (t) async {
      final req = {
        'id': 'r2',
        'failureCode': 'X',
        'description': 'd',
        'status': 'Diagnosed',
        'resolutionAction': 'Replacement',
        'zoneId': 'z',
        'originalDeviceId': 'o',
        'history': [],
      };
      handler = (_) => http.Response(jsonEncode(req), 200);
      await t.pumpWidget(MaterialApp(home: _wrap(const ServiceRequestDetailScreen(requestId: 'r2'))));
      await t.pumpAndSettle();
      expect(find.text('Thay nóng thiết bị'), findsOneWidget);
    });
  });
}

/// Bọc widget trong runWithClient không cần thiết vì _client đã tạo ở setUpAll (MockClient dùng chung).
Widget _wrap(Widget w) => w;
