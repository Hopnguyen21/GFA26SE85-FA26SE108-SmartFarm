import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/crop_sync_logic.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_irrigation_panel.dart';

/// "Đồng bộ từ Thư viện Cây" + thẻ lịch tưới giống web (CF3ControlSection).
Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

ScheduleModel sched(String name, String cron) => ScheduleModel.fromJson({
  'scheduleId': name,
  'zoneId': 'z1',
  'actuatorId': 'a1',
  'name': name,
  'cronExpression': cron,
  'durationSeconds': 600,
  'enableRainDelay': true,
  'rainThresholdPercent': 70,
  'isActive': true,
});

final _plan = jsonEncode({
  'repeatType': 'DAILY',
  'sessions': [
    {'session': 'MORNING', 'startTime': '07:30', 'durationMinutes': 20},
    {'session': 'NOON', 'startTime': '12:00', 'durationMinutes': 10},
    {'session': 'AFTERNOON', 'startTime': '16:30', 'durationMinutes': 15},
  ],
});

void route({List<Map<String, dynamic>> schedules = const []}) {
  handler = (r) async {
    final p = r.url.path;
    if (p == '/api/v1/crops') {
      return utf8Json([
        {
          'cropId': 'c1',
          'name': 'Dưa leo',
          'scientificName': 'Cucumis sativus',
          'category': 'Rau ăn quả',
          'growthCycleDays': 45,
          'calendarIrrigationPlan': _plan,
        },
        {'cropId': 'c2', 'name': 'Cà chua', 'calendarIrrigationPlan': null},
      ]);
    }
    if (p == '/api/v1/zones/z1/schedules/sync-from-crop') {
      return utf8Json([
        {'scheduleId': 's1'},
        {'scheduleId': 's2'},
        {'scheduleId': 's3'},
      ]);
    }
    if (p == '/api/v1/zones/z1/schedules' && r.method == 'GET') {
      return utf8Json(schedules);
    }
    if (p == '/api/v1/zones/z1/actuators') {
      return utf8Json([
        {
          'actuatorId': 'a1',
          'zoneId': 'z1',
          'name': 'Bơm tưới',
          'actuatorType': 'PUMP',
        },
      ]);
    }
    return utf8Json([]);
  };
}

Future<void> pumpPanel(WidgetTester t) async {
  t.view.physicalSize = const Size(500, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FarmProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZoneIrrigationPanel(
              zone: ZoneModel.fromJson(
                {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
                farmId: 'f1',
                fieldId: 'fl1',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> disposePanel(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
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
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('logic', () {
    test('phân ca theo tên hoặc giờ như web', () {
      expect(
        scheduleSessionKind(sched('Tưới Sáng Khởi Động', '30 7 * * *')),
        IrrigationSessionKind.morning,
      );
      expect(
        scheduleSessionKind(sched('Ca X', '0 12 * * *')),
        IrrigationSessionKind.noon,
      );
      expect(
        scheduleSessionKind(sched('Tưới Chiều Bổ Sung', '30 16 * * *')),
        IrrigationSessionKind.afternoon,
      );
    });

    test('đọc kế hoạch tưới dạng chuỗi JSON hoặc đối tượng; hỏng thì rỗng', () {
      final fromString = parseCropPlanSessions(_plan);
      expect(planSessionOf(fromString, 'MORNING')!.label, '07:30 (20m)');
      expect(planSessionOf(fromString, 'AFTERNOON')!.label, '16:30 (15m)');
      expect(parseCropPlanSessions(jsonDecode(_plan)).length, 3);
      expect(parseCropPlanSessions(null), isEmpty);
      expect(parseCropPlanSessions('{hỏng'), isEmpty);
      expect(parseCropPlanSessions('   '), isEmpty);
    });

    test('đọc ca tính bằng giây (DurationSeconds)', () {
      final s = parseCropPlanSessions({
        'sessions': [
          {'session': 'noon', 'startTime': '12:00', 'durationSeconds': 600},
        ],
      });
      expect(planSessionOf(s, 'NOON')!.durationMinutes, 10);
    });
  });

  group('ZoneIrrigationPanel đồng bộ từ Thư viện Cây', () {
    testWidgets('Zone chưa có lịch: có nút đồng bộ ngay ở trạng thái rỗng', (
      t,
    ) async {
      route();
      await pumpPanel(t);
      expect(find.byKey(const ValueKey('sync-crop-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-crop-button')), findsOneWidget);
      await disposePanel(t);
    });

    testWidgets('mở hộp: xem trước 3 ca, đổi cây không có kế hoạch → Chưa có', (
      t,
    ) async {
      route();
      await pumpPanel(t);
      await t.ensureVisible(find.byKey(const ValueKey('sync-crop-button')));
      await t.tap(find.byKey(const ValueKey('sync-crop-button')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('crop-sync-dialog')), findsOneWidget);
      expect(find.text('07:30 (20m)'), findsOneWidget);
      expect(find.text('12:00 (10m)'), findsOneWidget);
      expect(find.text('16:30 (15m)'), findsOneWidget);
      expect(find.text('45 ngày vụ'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('crop-sync-select')));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Cà chua').last);
      await t.pumpAndSettle();
      expect(find.text('Chưa có'), findsNWidgets(3));
      expect(find.text('Chưa có chu kỳ'), findsOneWidget);
      await disposePanel(t);
    });

    testWidgets('áp dụng: gửi cropId + actuatorId và báo số ca đã tạo', (
      t,
    ) async {
      route();
      await pumpPanel(t);
      await t.ensureVisible(find.byKey(const ValueKey('sync-crop-button')));
      await t.tap(find.byKey(const ValueKey('sync-crop-button')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('crop-sync-apply')));
      await t.pumpAndSettle();
      final req = calls.firstWhere(
        (c) => c.url.path.endsWith('/sync-from-crop'),
      );
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['cropId'], 'c1');
      expect(body['actuatorId'], 'a1');
      expect(find.textContaining('Đã đồng bộ 3 ca tưới'), findsOneWidget);
      await disposePanel(t);
    });

    testWidgets('Hủy: không gọi API đồng bộ', (t) async {
      route();
      await pumpPanel(t);
      await t.ensureVisible(find.byKey(const ValueKey('sync-crop-button')));
      await t.tap(find.byKey(const ValueKey('sync-crop-button')));
      await t.pumpAndSettle();
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(calls.any((c) => c.url.path.endsWith('/sync-from-crop')), isFalse);
      await disposePanel(t);
    });

    testWidgets('thẻ lịch: biểu tượng ca và dòng Zone • thiết bị', (t) async {
      route(
        schedules: [
          {
            'scheduleId': 's1',
            'zoneId': 'z1',
            'actuatorId': 'a1',
            'name': 'Tưới Sáng Khởi Động',
            'cronExpression': '30 7 * * *',
            'durationSeconds': 1200,
            'enableRainDelay': true,
            'rainThresholdPercent': 70,
            'isActive': true,
            'zoneName': 'Nhà màng 1',
            'actuatorName': 'Bơm tưới',
          },
        ],
      );
      await pumpPanel(t);
      expect(find.byIcon(Icons.wb_twilight), findsOneWidget);
      expect(find.textContaining('Bơm tưới'), findsWidgets);
      await disposePanel(t);
    });
  });
}
