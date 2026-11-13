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
import 'package:smartfarm_mobile/features/irrigation/irrigation_calendar_screen.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

DefaultCropProfile _profile() => defaultCropProfileFromApi({
  'profileId': 'p1',
  'cropId': 'c1',
  'cropName': 'Dưa lưới',
  'name': 'Bản của tôi',
  'stages': [
    {
      'stageId': 'st1',
      'name': 'Cây con',
      'stageOrder': 1,
      'durationDays': 20,
      'requirements': [],
    },
    {
      'stageId': 'st2',
      'name': 'Ra hoa',
      'stageOrder': 2,
      'durationDays': 40,
      'requirements': [],
    },
  ],
}, null);

Map<String, dynamic> _irrigation({
  bool editable = true,
  bool empty = false,
  bool enabled = true,
}) => {
  'profileId': 'p1',
  'profileName': 'Bản của tôi',
  'isSystemDefined': !editable,
  'isEditable': editable,
  'repeatType': 'DAILY',
  'timeZone': 'Asia/Ho_Chi_Minh',
  'stages': [
    for (final (id, order, name, days) in [
      ('st1', 1, 'Cây con', 20),
      ('st2', 2, 'Ra hoa', 40),
    ])
      {
        'stageId': id,
        'stageName': name,
        'stageOrder': order,
        'durationDays': days,
        'source': empty ? 'None' : 'Profile',
        'sessions': empty
            ? []
            : [
                {
                  'sessionId': 's-$id',
                  'title': 'Ca từ backend $id',
                  'startTime': '05:45',
                  'durationSeconds': 420,
                  'enabled': enabled,
                  'method': 'Nhỏ giọt',
                  'waterPerPlantMl': 120,
                },
              ],
      },
  ],
};

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FarmProvider(),
      child: MaterialApp(home: IrrigationCalendarScreen(profile: _profile())),
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
    SharedPreferences.setMockInitialValues({});
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  testWidgets(
    'lịch tưới được tải từ backend theo giai đoạn; không còn ca mặc định tự sinh',
    (tester) async {
      handler = (r) async =>
          r.url.path == '/api/v1/growth-profiles/p1/irrigation-schedule'
          ? utf8Json(_irrigation())
          : utf8Json([]);
      await _pump(tester);

      expect(
        calls.any(
          (c) => c.url.path == '/api/v1/growth-profiles/p1/irrigation-schedule',
        ),
        isTrue,
      );
      expect(find.textContaining('Ca từ backend st1'), findsWidgets);
      expect(find.textContaining('Ca 1: Tưới gốc buổi sáng'), findsNothing);
      expect(find.textContaining('Phun sương hạ nhiệt'), findsNothing);
      await _dispose(tester);
    },
  );

  testWidgets('hồ sơ chưa có ca nào: không bịa ca mặc định', (tester) async {
    handler = (r) async =>
        r.url.path == '/api/v1/growth-profiles/p1/irrigation-schedule'
        ? utf8Json(_irrigation(empty: true))
        : utf8Json([]);
    await _pump(tester);
    expect(find.textContaining('Ca 1:'), findsNothing);
    expect(find.textContaining('Tưới gốc'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('không lưu lịch trong SharedPreferences', (tester) async {
    handler = (r) async =>
        r.url.path == '/api/v1/growth-profiles/p1/irrigation-schedule'
        ? utf8Json(_irrigation())
        : utf8Json([]);
    await _pump(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.contains('calendar_overrides')),
      isEmpty,
    );
    await _dispose(tester);
  });

  testWidgets('lỗi API: hiện lỗi tải và nút thử lại, không hiện lịch giả', (
    tester,
  ) async {
    handler = (_) async => utf8Json({'message': 'Máy chủ bận'}, 500);
    await _pump(tester);
    expect(
      find.textContaining('Không tải được lịch tưới của hồ sơ'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets(
    'hồ sơ hệ thống chỉ xem: bật/tắt ca bị từ chối với giải thích, không gọi PUT',
    (tester) async {
      handler = (r) async =>
          r.url.path == '/api/v1/growth-profiles/p1/irrigation-schedule'
          ? utf8Json(_irrigation(editable: false))
          : utf8Json([]);
      await _pump(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Hồ sơ hệ thống chỉ để xem'), findsOneWidget);
      expect(calls.where((c) => c.method == 'PUT'), isEmpty);
      await _dispose(tester);
    },
  );

  testWidgets(
    'hồ sơ riêng: bật/tắt ca lưu lên backend (PUT theo giai đoạn) rồi tải lại',
    (tester) async {
      var saved = false;
      handler = (r) async {
        if (r.url.path != '/api/v1/growth-profiles/p1/irrigation-schedule')
          return utf8Json([]);
        if (r.method == 'PUT') {
          saved = true;
          return utf8Json(_irrigation(enabled: false));
        }
        return utf8Json(_irrigation(enabled: !saved));
      };
      await _pump(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      final put = calls.firstWhere((c) => c.method == 'PUT');
      final stages =
          (jsonDecode(put.body) as Map<String, dynamic>)['stages'] as List;
      expect(stages, hasLength(1), reason: 'chỉ giai đoạn chứa ngày đang chọn');
      expect(stages.single['stageId'], 'st1');
      final session =
          (stages.single['sessions'] as List).single as Map<String, dynamic>;
      expect(session['enabled'], isFalse);
      expect(session['startTime'], '05:45');
      expect(session['durationSeconds'], 420);
      expect(session['waterPerPlantMl'], 120);
      expect(
        find.textContaining('Đã lưu lịch tưới của giai đoạn "Cây con"'),
        findsOneWidget,
      );
      await _dispose(tester);
    },
  );

  testWidgets('lưu lỗi: báo lỗi backend, không báo đã lưu', (tester) async {
    handler = (r) async {
      if (r.url.path != '/api/v1/growth-profiles/p1/irrigation-schedule')
        return utf8Json([]);
      if (r.method == 'PUT')
        return utf8Json({'message': 'Hai ca tưới không được trùng giờ'}, 400);
      return utf8Json(_irrigation());
    };
    await _pump(tester);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Không lưu được lịch tưới'), findsOneWidget);
    expect(find.textContaining('Đã lưu lịch tưới'), findsNothing);
    await _dispose(tester);
  });
}
