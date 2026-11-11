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
import 'package:smartfarm_mobile/features/zones/profile_irrigation_logic.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_irrigation_panel.dart';

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

ZoneModel _zone({String? profileId = 'p1'}) => ZoneModel.fromJson(
  {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100, 'growthProfileId': profileId},
  farmId: 'f1',
  fieldId: 'fl1',
);

Map<String, dynamic> _irrigation({
  bool editable = true,
  String source = 'Profile',
  List<Map<String, dynamic>>? sessions,
  bool twoStages = false,
}) {
  Map<String, dynamic> stage(String id, int order, String name) => {
    'stageId': id,
    'stageName': name,
    'stageOrder': order,
    'durationDays': 20,
    'source': source,
    'sessions':
        sessions ??
        [
          {
            'sessionId': 'x1',
            'title': 'Tưới sáng',
            'startTime': '06:00',
            'durationSeconds': 480,
            'enabled': true,
            'method': 'Nhỏ giọt',
            'waterPerPlantMl': 200,
          },
          {'sessionId': 'x2', 'title': 'Tưới chiều', 'startTime': '16:30', 'durationSeconds': 360, 'enabled': false},
        ],
  };
  return {
    'profileId': 'p1',
    'profileName': 'Bản của tôi',
    'isSystemDefined': !editable,
    'isEditable': editable,
    'repeatType': 'DAILY',
    'timeZone': 'Asia/Ho_Chi_Minh',
    'stages': [stage('st1', 1, 'Cây con'), if (twoStages) stage('st2', 2, 'Ra hoa')],
  };
}

Map<String, dynamic> _sched({String id = 'sc1', String cron = '30 6 * * *', int seconds = 480, bool active = true}) => {
  'scheduleId': id,
  'zoneId': 'z1',
  'actuatorId': 'a1',
  'name': '[AutoSync] Bản của tôi · Cây con · Tưới sáng 06:30',
  'cronExpression': cron,
  'durationSeconds': seconds,
  'enableRainDelay': true,
  'rainThresholdPercent': 70,
  'isActive': active,
};

void _route({
  Object? irrigation,
  http.Response? irrigationError,
  List<Map<String, dynamic>>? schedules,
  http.Response? scheduleError,
  Object? actuators,
  http.Response Function(http.Request)? sync,
  http.Response Function(http.Request)? putIrrigation,
  http.Response Function(http.Request)? putSchedule,
}) {
  handler = (r) async {
    final p = r.url.path;
    if (p == '/api/v1/growth-profiles/p1/irrigation-schedule') {
      if (r.method == 'PUT') return putIrrigation?.call(r) ?? utf8Json(irrigation ?? _irrigation());
      return irrigationError ?? utf8Json(irrigation ?? _irrigation());
    }
    if (p == '/api/v1/zones/z1/schedules' && r.method == 'GET') return scheduleError ?? utf8Json(schedules ?? []);
    if (p == '/api/v1/zones/z1/actuators') {
      return utf8Json(
        actuators ??
            [
              {'actuatorId': 'a1', 'zoneId': 'z1', 'name': 'Bơm tưới', 'actuatorType': 'PUMP'},
              {'actuatorId': 'a2', 'zoneId': 'z1', 'name': 'Quạt', 'actuatorType': 'FAN'},
            ],
      );
    }
    if (p == '/api/v1/zones/z1/schedules/sync-from-profile') {
      return sync?.call(r) ??
          utf8Json({
            'profileId': 'p1',
            'profileName': 'Bản của tôi',
            'stageId': 'st1',
            'stageName': 'Cây con',
            'source': 'Profile',
            'actuatorId': 'a1',
            'schedules': [_sched()],
          });
    }
    if (r.method == 'PUT' && p.startsWith('/api/v1/zones/z1/schedules/'))
      return putSchedule?.call(r) ?? utf8Json(_sched());
    return utf8Json([]);
  };
}

Future<void> _pump(WidgetTester tester, {ZoneModel? zone}) async {
  tester.view.physicalSize = const Size(500, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FarmProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ZoneIrrigationPanel(zone: zone ?? _zone())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
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
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('profile_irrigation_logic', () {
    test('ProfileSchedule đọc đúng schema backend (HH:mm, giây, ml, nguồn)', () {
      final ps = ProfileSchedule.fromJson(_irrigation(twoStages: true));
      expect(ps.isEditable, isTrue);
      expect(ps.timeZone, 'Asia/Ho_Chi_Minh');
      expect(ps.stages.map((s) => s.name), ['Cây con', 'Ra hoa']);
      final first = ps.stages.first.sessions.first;
      expect(first.startTime, '06:00');
      expect(first.durationSeconds, 480);
      expect(first.durationMinutes, 8);
      expect(first.waterPerPlantMl, 200);
      expect(first.method, 'Nhỏ giọt');
      expect(ps.stages.first.fromProfile, isTrue);
    });

    test('toJson đúng tên trường của PUT và bỏ trường rỗng', () {
      const s = ProfileSession(
        title: ' Sáng ',
        startTime: '06:15',
        durationSeconds: 300,
        method: '  ',
        waterPerPlantMl: null,
      );
      expect(s.toJson(), {'title': 'Sáng', 'startTime': '06:15', 'durationSeconds': 300, 'enabled': true});
      expect(stageIrrigationPayload('st1', [s])['stageId'], 'st1');
    });

    test('validateStageSessions theo quy tắc backend', () {
      ProfileSession ok({String t = '06:00', int sec = 60, String title = 'a', int? ml}) =>
          ProfileSession(title: title, startTime: t, durationSeconds: sec, waterPerPlantMl: ml);
      expect(validateStageSessions([ok()]), isNull);
      expect(validateStageSessions([ok(t: '25:00')]), contains('HH:mm'));
      expect(validateStageSessions([ok(sec: 1801)]), contains('30 phút'));
      expect(validateStageSessions([ok(sec: 0)]), isNotNull);
      expect(validateStageSessions([ok(title: ' ')]), contains('tên'));
      expect(validateStageSessions([ok(ml: -1)]), contains('ml/gốc'));
      expect(validateStageSessions([ok(), ok()]), contains('trùng giờ'));
      expect(validateStageSessions([for (var i = 0; i < 9; i++) ok(t: '0$i:00')]), contains('tối đa 8'));
      expect(validateStageSessions([ok(sec: 1800)]), isNull, reason: 'đúng 30 phút là giới hạn cho phép');
    });
  });

  group('ZoneIrrigationPanel (lịch của hồ sơ gắn trên Zone)', () {
    testWidgets('hiển thị lịch của hồ sơ theo giai đoạn (giờ, phút, ml/gốc, tắt) và lịch đang áp dụng cho thiết bị', (
      tester,
    ) async {
      _route(schedules: [_sched()]);
      await _pump(tester);

      expect(calls.any((c) => c.url.path == '/api/v1/growth-profiles/p1/irrigation-schedule'), isTrue);
      expect(find.textContaining('Hồ sơ "Bản của tôi" · riêng của trang trại'), findsOneWidget);
      expect(find.textContaining('múi giờ Asia/Ho_Chi_Minh'), findsOneWidget);
      expect(find.textContaining('Tưới sáng · 06:00 · 8 phút · 200 ml/gốc · Nhỏ giọt'), findsOneWidget);
      expect(find.textContaining('Tưới chiều · 16:30 · 6 phút (tắt)'), findsOneWidget);
      expect(find.text('Hồ sơ'), findsOneWidget, reason: 'nhãn nguồn của giai đoạn');
      expect(find.textContaining('hằng ngày lúc 06:30 · 8 phút'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('Zone chưa gắn hồ sơ: không gọi API lịch hồ sơ, không cho đồng bộ', (tester) async {
      _route();
      await _pump(tester, zone: _zone(profileId: null));
      expect(calls.where((c) => c.url.path.contains('irrigation-schedule')), isEmpty);
      expect(find.textContaining('chưa gắn hồ sơ canh tác'), findsOneWidget);
      expect(find.text('Đồng bộ lịch của hồ sơ'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('hồ sơ hệ thống: chỉ xem (không có nút sửa) và giải thích cách sao chép', (tester) async {
      _route(irrigation: _irrigation(editable: false, source: 'Crop'));
      await _pump(tester);
      expect(find.text('Lịch mẫu của cây'), findsOneWidget);
      expect(find.textContaining('Sửa ca tưới'), findsNothing);
      expect(find.textContaining('Lưu ca tưới riêng'), findsNothing);
      expect(find.textContaining('không sửa trực tiếp'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('hồ sơ chưa có ca và cây cũng chưa có lịch mẫu → nói rõ, không bịa lịch', (tester) async {
      _route(
        irrigation: _irrigation(source: 'None', sessions: const []),
      );
      await _pump(tester);
      expect(find.textContaining('chưa có ca tưới nào và cây cũng chưa có lịch mẫu'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('lỗi tải lịch hồ sơ hiện lỗi thật, phần lịch của Zone vẫn hiển thị', (tester) async {
      _route(irrigationError: utf8Json({'message': 'Máy chủ bận'}, 500), schedules: [_sched()]);
      await _pump(tester);
      expect(find.textContaining('Không tải được lịch của hồ sơ'), findsOneWidget);
      expect(find.textContaining('hằng ngày lúc 06:30'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('lỗi tải lịch của Zone không bị coi là rỗng', (tester) async {
      _route(scheduleError: utf8Json({'message': 'Máy chủ bận'}, 500));
      await _pump(tester);
      expect(find.textContaining('Không tải được lịch của Zone'), findsOneWidget);
      expect(find.textContaining('Zone chưa có lịch tưới nào đang áp dụng'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('lưu ca tưới: PUT đúng schema rồi tải lại từ backend và báo "chưa đổi lịch thiết bị"', (tester) async {
      var saved = false;
      handler = (r) async {
        final p = r.url.path;
        if (p == '/api/v1/growth-profiles/p1/irrigation-schedule') {
          if (r.method == 'PUT') {
            saved = true;
            return utf8Json(_irrigation());
          }
          return utf8Json(
            _irrigation(
              sessions: saved
                  ? [
                      {
                        'sessionId': 'n1',
                        'title': 'Tưới mới',
                        'startTime': '07:00',
                        'durationSeconds': 600,
                        'enabled': true,
                      },
                    ]
                  : null,
            ),
          );
        }
        if (p == '/api/v1/zones/z1/schedules') return utf8Json([]);
        if (p == '/api/v1/zones/z1/actuators') return utf8Json([]);
        return utf8Json([]);
      };
      await _pump(tester);
      await tester.tap(find.text('Sửa ca tưới'));
      await tester.pumpAndSettle();
      // Sửa tên ca đầu tiên và giờ, xoá ca thứ hai.
      await tester.enterText(find.widgetWithText(TextField, 'Tưới sáng'), 'Tưới mới');
      await tester.enterText(find.widgetWithText(TextField, '06:00'), '07:00');
      await tester.enterText(find.widgetWithText(TextField, '8'), '10');
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final put = calls.firstWhere((c) => c.method == 'PUT');
      expect(put.url.path, '/api/v1/growth-profiles/p1/irrigation-schedule');
      final stages = (jsonDecode(put.body) as Map<String, dynamic>)['stages'] as List;
      expect(stages, hasLength(1));
      expect(stages.single['stageId'], 'st1');
      final sessions = stages.single['sessions'] as List;
      expect(sessions, hasLength(1));
      expect(sessions.single['title'], 'Tưới mới');
      expect(sessions.single['startTime'], '07:00');
      expect(sessions.single['durationSeconds'], 600);
      // Dữ liệu hiển thị là dữ liệu tải lại từ backend.
      expect(find.textContaining('Tưới mới · 07:00 · 10 phút'), findsOneWidget);
      expect(find.textContaining('Lịch điều khiển của thiết bị chưa đổi'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('lưu ca tưới lỗi → báo lỗi backend, không báo đã lưu', (tester) async {
      _route(
        putIrrigation: (_) =>
            utf8Json({'message': 'Hai ca tưới trong cùng giai đoạn không được trùng giờ bắt đầu.'}, 400),
      );
      await _pump(tester);
      await tester.tap(find.text('Sửa ca tưới'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không lưu được lịch tưới của hồ sơ'), findsOneWidget);
      expect(find.textContaining('trùng giờ'), findsWidgets);
      expect(find.textContaining('Đã lưu ca tưới'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('đồng bộ: gọi sync-from-profile (KHÔNG có cropId), báo số lịch và nguồn thật', (tester) async {
      _route(schedules: [_sched()]);
      await _pump(tester);
      await tester.tap(find.text('Đồng bộ lịch của hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();

      final req = calls.firstWhere((c) => c.url.path.endsWith('/sync-from-profile'));
      expect(req.method, 'POST');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['actuatorId'], 'a1');
      expect(body.containsKey('cropId'), isFalse, reason: 'nguồn là hồ sơ của Zone, không nhận cây tùy ý');
      expect(find.textContaining('Đã đồng bộ 1 lịch từ giai đoạn "Cây con" của hồ sơ "Bản của tôi"'), findsOneWidget);
      expect(find.textContaining('ca lưu trong hồ sơ'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('đồng bộ lỗi thiếu actuator (409) → hiện thông điệp backend kèm gợi ý, không báo thành công', (
      tester,
    ) async {
      _route(
        sync: (_) => utf8Json({
          'message': "Khu vực 'A' chưa có thiết bị van hoặc máy bơm tưới (Actuator). Vui lòng cấu hình",
        }, 409),
      );
      await _pump(tester);
      await tester.tap(find.text('Đồng bộ lịch của hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chưa có thiết bị van hoặc máy bơm'), findsWidgets);
      expect(find.textContaining('do kỹ thuật viên lắp'), findsOneWidget);
      expect(find.textContaining('Đã đồng bộ'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('đồng bộ khi Zone chưa gắn hồ sơ ở backend / quyền bị từ chối → báo đúng lý do', (tester) async {
      _route(
        sync: (_) => utf8Json({
          'message': 'Zone chưa gắn hồ sơ canh tác. Hãy chọn hồ sơ cho Zone trước khi đồng bộ lịch tưới.',
        }, 409),
      );
      await _pump(tester);
      await tester.tap(find.text('Đồng bộ lịch của hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('gắn một hồ sơ canh tác cho Zone'), findsOneWidget);

      _route(sync: (_) => http.Response('', 403));
      await tester.tap(find.text('Đồng bộ lịch của hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('quyền'), findsWidgets);
      await _dispose(tester);
    });

    testWidgets('chọn giai đoạn để đồng bộ gửi growthStageId', (tester) async {
      _route(irrigation: _irrigation(twoStages: true));
      await _pump(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2. Ra hoa').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ lịch của hồ sơ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      final body =
          jsonDecode(calls.firstWhere((c) => c.url.path.endsWith('/sync-from-profile')).body) as Map<String, dynamic>;
      expect(body['growthStageId'], 'st2');
      await _dispose(tester);
    });

    testWidgets('Zone chưa có bơm/van → báo rõ và không cho đồng bộ', (tester) async {
      _route(
        actuators: [
          {'actuatorId': 'a2', 'zoneId': 'z1', 'name': 'Quạt', 'actuatorType': 'FAN'},
        ],
      );
      await _pump(tester);
      expect(find.textContaining('chưa có bơm/van tưới'), findsOneWidget);
      expect(find.text('Đồng bộ lịch của hồ sơ'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('bật/tắt lịch thiết bị gửi PUT đủ trường; lỗi thì báo lỗi backend', (tester) async {
      _route(schedules: [_sched()]);
      await _pump(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      final put = calls.firstWhere((c) => c.method == 'PUT' && c.url.path == '/api/v1/zones/z1/schedules/sc1');
      final body = jsonDecode(put.body) as Map<String, dynamic>;
      expect(body['isActive'], isFalse);
      expect(body['cronExpression'], '30 6 * * *');
      expect(body['durationSeconds'], 480);
      expect(find.textContaining('Đã tắt lịch'), findsOneWidget);
      await _dispose(tester);

      _route(schedules: [_sched()], putSchedule: (_) => utf8Json({'message': 'Thiết bị không thuộc Zone'}, 409));
      await _pump(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Không lưu được lịch'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('lịch cron không phải hằng ngày: không cho sửa giờ', (tester) async {
      _route(schedules: [_sched(cron: '0 6 * * 1')]);
      await _pump(tester);
      final edit = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.edit_outlined).last);
      expect(edit.onPressed, isNull);
      await _dispose(tester);
    });
  });
}
