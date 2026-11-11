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
import 'package:smartfarm_mobile/features/zones/widgets/zone_crop_plan_edit_panel.dart';

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

ZoneModel _zone({String? profileId, String? profileName, bool? system}) => ZoneModel.fromJson(
  {
    'zoneId': 'z1',
    'name': 'Nhà màng 1',
    'areaM2': 100,
    'growthProfileId': profileId,
    'growthProfileName': profileName,
    'growthProfileIsSystemDefined': system,
  },
  farmId: 'f1',
  fieldId: 'fl1',
);

Map<String, dynamic> _season({String profileName = 'Hồ sơ vụ', String status = 'InProgress'}) => {
  'seasonId': 's1',
  'zoneId': 'z1',
  'cropId': 'c1',
  'cropName': 'Dưa lưới',
  'growthProfileId': 'pSeason',
  'growthProfileName': profileName,
  'name': 'Vụ 1',
  'status': status,
};

Map<String, dynamic> _profile({required String id, String name = 'VietGAP Dưa lưới', bool system = true}) => {
  'profileId': id,
  'name': name,
  'cropName': 'Dưa lưới',
  'varietyName': 'Giống A',
  'isSystemDefined': system,
  'isDefault': true,
  'stages': [
    {
      'stageId': 'st1',
      'name': 'Cây con',
      'stageOrder': 1,
      'durationDays': 20,
      'requirements': [
        {'parameterCode': 'SoilMoisture', 'minValue': 60, 'maxValue': 80, 'targetValue': 70, 'unit': '%'},
      ],
    },
  ],
};

void _route({
  List<Map<String, dynamic>> seasons = const [],
  List<Map<String, dynamic>> profiles = const [],
  http.Response? seasonsError,
  http.Response Function(http.Request)? putZone,
}) {
  handler = (r) async {
    final p = r.url.path;
    if (p == '/api/v1/planting-seasons') return seasonsError ?? utf8Json(seasons);
    if (p == '/api/v1/growth-profiles' && r.method == 'GET') return utf8Json(profiles);
    if (r.method == 'PUT' && p == '/api/v1/zones/z1') return putZone?.call(r) ?? utf8Json({'zoneId': 'z1'});
    return utf8Json([]);
  };
}

Future<void> _pump(WidgetTester tester, ZoneModel zone) async {
  tester.view.physicalSize = const Size(500, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FarmProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ZoneCropPlanEditPanel(zone: zone)),
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

  testWidgets('mở lại Zone: hiển thị hồ sơ ĐANG GẮN TRÊN ZONE (từ Zone API), kèm giai đoạn và ngưỡng', (tester) async {
    _route(profiles: [_profile(id: 'p1')]);
    await _pump(tester, _zone(profileId: 'p1', profileName: 'VietGAP Dưa lưới', system: true));

    expect(find.textContaining('Dưa lưới · giống Giống A'), findsOneWidget);
    expect(find.textContaining('Hồ sơ: VietGAP Dưa lưới (hệ thống'), findsOneWidget);
    expect(find.textContaining('1. Cây con'), findsOneWidget);
    expect(find.textContaining('Độ ẩm đất: 60–80 %'), findsOneWidget);
    expect(find.text('Đổi hồ sơ'), findsOneWidget);
    expect(find.text('Gỡ hồ sơ'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('hồ sơ hệ thống: không có nút sửa, chỉ hướng dẫn sao chép', (tester) async {
    _route(profiles: [_profile(id: 'p1')]);
    await _pump(tester, _zone(profileId: 'p1', system: true));
    expect(find.text('Sửa hồ sơ riêng'), findsNothing);
    expect(find.textContaining('không sửa trực tiếp'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('hồ sơ riêng của trang trại: có nút sửa', (tester) async {
    _route(
      profiles: [_profile(id: 'p1', name: 'Bản của tôi', system: false)],
    );
    await _pump(tester, _zone(profileId: 'p1', system: false));
    expect(find.text('Sửa hồ sơ riêng'), findsOneWidget);
    expect(find.textContaining('riêng của trang trại'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Zone chưa gắn hồ sơ: mở được, không tự gán hồ sơ, dù vụ mùa có hồ sơ', (tester) async {
    _route(seasons: [_season()]);
    await _pump(tester, _zone());
    expect(find.textContaining('Zone chưa gắn hồ sơ canh tác'), findsOneWidget);
    expect(find.text('Gắn hồ sơ cho Zone'), findsOneWidget);
    expect(find.textContaining('Hồ sơ:'), findsNothing, reason: 'không suy hồ sơ của Zone từ vụ mùa');
    expect(calls.where((c) => c.method == 'PUT'), isEmpty);
    await _dispose(tester);
  });

  testWidgets('vụ đang chạy dùng hồ sơ khác hồ sơ của Zone: nói rõ vụ giữ hồ sơ riêng', (tester) async {
    _route(
      seasons: [_season(profileName: 'Hồ sơ cũ của vụ')],
      profiles: [_profile(id: 'p1')],
    );
    await _pump(tester, _zone(profileId: 'p1', system: true));
    expect(find.textContaining('Vụ đang chạy: Vụ 1 · dùng hồ sơ "Hồ sơ cũ của vụ"'), findsOneWidget);
    expect(find.textContaining('vụ giữ hồ sơ riêng của nó'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('API lỗi: báo lỗi tải và có nút thử lại, không hiện như thể chưa gắn hồ sơ', (tester) async {
    _route(seasonsError: http.Response('{"title":"boom"}', 500));
    await _pump(tester, _zone(profileId: 'p1'));
    expect(find.textContaining('Không tải được hồ sơ của Zone'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Zone chưa gắn hồ sơ'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('gỡ hồ sơ: hỏi xác nhận rồi PUT clearGrowthProfile, không đụng vụ mùa', (tester) async {
    _route(profiles: [_profile(id: 'p1')]);
    await _pump(tester, _zone(profileId: 'p1', system: true));
    await tester.tap(find.text('Gỡ hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Gỡ hồ sơ khỏi Zone?'), findsOneWidget);
    expect(calls.where((c) => c.method == 'PUT'), isEmpty, reason: 'chưa xác nhận thì chưa gọi API');
    await tester.tap(find.widgetWithText(FilledButton, 'Gỡ hồ sơ'));
    await tester.pumpAndSettle();

    final put = calls.firstWhere((c) => c.method == 'PUT');
    expect(put.url.path, '/api/v1/zones/z1');
    expect((jsonDecode(put.body) as Map<String, dynamic>)['clearGrowthProfile'], isTrue);
    expect(calls.where((c) => c.url.path.contains('planting-seasons') && c.method == 'POST'), isEmpty);
    expect(find.text('Đã gỡ hồ sơ khỏi Zone.'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('gỡ hồ sơ bị backend từ chối → báo lỗi thật, hồ sơ vẫn hiển thị', (tester) async {
    _route(
      profiles: [_profile(id: 'p1')],
      putZone: (_) => utf8Json({'message': 'Bạn không có quyền'}, 403),
    );
    await _pump(tester, _zone(profileId: 'p1', system: true));
    await tester.tap(find.text('Gỡ hồ sơ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Gỡ hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Không gỡ được hồ sơ'), findsOneWidget);
    expect(find.textContaining('Hồ sơ: VietGAP Dưa lưới'), findsOneWidget);
    await _dispose(tester);
  });

  group('chọn hồ sơ: xem chi tiết → áp dụng → xác nhận → gắn', () {
    void routeCatalog({List<Map<String, dynamic>>? putLog, http.Response Function(http.Request)? putZone}) {
      handler = (r) async {
        final p = r.url.path;
        if (p == '/api/v1/planting-seasons') return utf8Json([]);
        if (p == '/api/v1/crops') {
          return utf8Json([
            {'cropId': 'c1', 'name': 'Dưa lưới'},
          ]);
        }
        if (p == '/api/v1/varieties') {
          return utf8Json([
            {'varietyId': 'v1', 'name': 'Giống A'},
          ]);
        }
        if (p == '/api/v1/crops/c1/growth-profiles') {
          return utf8Json([
            {..._profile(id: 'general', name: 'Hồ sơ chung'), 'varietyId': null, 'varietyName': null},
            {..._profile(id: 'forV1', name: 'Hồ sơ giống A'), 'varietyId': 'v1'},
          ]);
        }
        if (p.endsWith('/irrigation-schedule')) {
          return utf8Json({
            'profileId': 'general',
            'profileName': 'Hồ sơ chung',
            'isSystemDefined': true,
            'isEditable': false,
            'repeatType': 'DAILY',
            'timeZone': 'Asia/Ho_Chi_Minh',
            'stages': [
              {
                'stageId': 'st1',
                'stageName': 'Cây con',
                'stageOrder': 1,
                'durationDays': 20,
                'source': 'Profile',
                'sessions': [
                  {
                    'sessionId': 'x',
                    'title': 'Tưới sáng',
                    'startTime': '06:00',
                    'durationSeconds': 300,
                    'enabled': true,
                    'method': 'Nhỏ giọt',
                    'waterPerPlantMl': 150,
                  },
                ],
              },
            ],
          });
        }
        if (r.method == 'PUT' && p == '/api/v1/zones/z1') return putZone?.call(r) ?? utf8Json({'zoneId': 'z1'});
        return utf8Json([]);
      };
    }

    Future<void> openList(WidgetTester tester) async {
      await tester.tap(find.text('Dùng hồ sơ có sẵn'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dưa lưới').last);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'không tự áp dụng; chung + riêng giống đều hiện; xem chi tiết hiện đủ lịch tưới; chỉ gắn sau khi xác nhận',
      (tester) async {
        routeCatalog();
        await _pump(tester, _zone());
        await openList(tester);

        expect(find.text('Hồ sơ chung'), findsOneWidget);
        expect(find.text('Xem chi tiết'), findsOneWidget, reason: 'chưa chọn giống: chỉ hồ sơ chung');
        expect(find.textContaining('Chưa chọn hồ sơ nào'), findsOneWidget);

        await tester.tap(find.text('Xem chi tiết'));
        await tester.pumpAndSettle();
        expect(find.text('Chi tiết hồ sơ canh tác'), findsOneWidget);
        expect(find.textContaining('Hồ sơ hệ thống (chỉ xem)'), findsWidgets);
        expect(find.textContaining('Độ ẩm đất: 60–80 % (mục tiêu 70)'), findsOneWidget);
        expect(find.textContaining('Tưới sáng'), findsOneWidget);
        expect(find.textContaining('Nhỏ giọt'), findsOneWidget);
        expect(find.text('Tạo bản sao riêng để chỉnh'), findsOneWidget);
        expect(calls.where((c) => c.method == 'PUT'), isEmpty);

        await tester.tap(find.text('Quay lại danh sách'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa chọn hồ sơ nào'), findsOneWidget, reason: 'quay lại không chọn gì');

        // Chưa chọn hồ sơ thì không gắn được.
        await tester.tap(find.text('Gắn hồ sơ cho Zone'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa chọn hồ sơ'), findsWidgets);
        expect(calls.where((c) => c.method == 'PUT'), isEmpty);

        await tester.tap(find.text('Xem chi tiết'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Áp dụng profile này cho Zone'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Đã chọn'), findsOneWidget);
        expect(calls.where((c) => c.method == 'PUT'), isEmpty, reason: 'chọn xong vẫn chưa lưu');

        await tester.tap(find.text('Gắn hồ sơ cho Zone'));
        await tester.pumpAndSettle();
        expect(find.text('Gắn hồ sơ cho Zone?'), findsOneWidget);
        expect(find.textContaining('Hồ sơ: Hồ sơ chung'), findsOneWidget);
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(calls.where((c) => c.method == 'PUT'), isEmpty, reason: 'hủy xác nhận thì không gắn');

        await tester.tap(find.text('Gắn hồ sơ cho Zone'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận gắn'));
        await tester.pumpAndSettle();
        final put = calls.firstWhere((c) => c.method == 'PUT');
        expect((jsonDecode(put.body) as Map<String, dynamic>)['growthProfileId'], 'general');
        expect(calls.where((c) => c.url.path.contains('planting-seasons') && c.method == 'POST'), isEmpty);
        await _dispose(tester);
      },
    );

    testWidgets('chọn giống: hồ sơ chung (không gắn giống) vẫn hiện cùng hồ sơ riêng của giống', (tester) async {
      routeCatalog();
      await _pump(tester, _zone());
      await openList(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giống A').last);
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ chung'), findsOneWidget);
      expect(find.text('Hồ sơ giống A'), findsOneWidget);
      expect(find.text('Xem chi tiết'), findsNWidgets(2));
      await _dispose(tester);
    });
  });
}
