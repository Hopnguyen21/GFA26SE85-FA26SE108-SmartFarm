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
import 'package:smartfarm_mobile/features/zones/widgets/zone_seasons_section.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _zone = ZoneModel.fromJson(
  {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
  farmId: 'f1',
  fieldId: 'fl1',
  farmName: 'Trang trại A',
);

FarmProvider? _provider;

Future<void> _pump(WidgetTester tester, {String role = 'OWNER'}) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = _provider = FarmProvider()..switchRole(role);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ZoneSeasonsSection(zone: _zone)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  _provider?.dispose();
  _provider = null;
}

Map<String, dynamic> _season(String status, {String stage = 'st1'}) => {
  'seasonId': 's1',
  'zoneId': 'z1',
  'name': 'Vụ thử',
  'status': status,
  'cropName': 'Dưa lưới',
  'growthProfileId': 'p1',
  'growthProfileName': 'VietGAP',
  'currentGrowthStageId': stage,
  'currentGrowthStageName': stage == 'st1' ? 'Cây con' : 'Ra hoa',
  'farmingSeasonName': 'Vụ Đông - Xuân 2026',
  'startDate': '2026-11-01',
  'expectedEndDate': '2027-01-30',
};

final _stages = [
  {'stageId': 'st2', 'name': 'Ra hoa', 'stageOrder': 2, 'durationDays': 30},
  {'stageId': 'st1', 'name': 'Cây con', 'stageOrder': 1, 'durationDays': 20},
  {'stageId': 'st3', 'name': 'Thu hoạch', 'stageOrder': 3, 'durationDays': 40},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => CropApi.getPlantingSeasons(zoneId: 'z1'),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('seasonTimeProgress', () {
    final s = _season('InProgress');
    test('ngày đầu = 0%, giữa vụ tính theo ngày, quá hạn chặn ở 100%', () {
      expect(seasonTimeProgress(s, now: DateTime(2026, 11, 1)), (
        percent: 0,
        day: 1,
        totalDays: 90,
      ));
      expect(seasonTimeProgress(s, now: DateTime(2026, 12, 16, 23)), (
        percent: 50,
        day: 46,
        totalDays: 90,
      ));
      expect(seasonTimeProgress(s, now: DateTime(2027, 6, 1)), (
        percent: 100,
        day: 90,
        totalDays: 90,
      ));
      expect(seasonTimeProgress(s, now: DateTime(2026, 10, 1))?.percent, 0);
    });

    test('không tính cho vụ không đang chạy hoặc thiếu/sai ngày', () {
      expect(seasonTimeProgress(_season('Planned')), isNull);
      expect(seasonTimeProgress(_season('Completed')), isNull);
      expect(seasonTimeProgress({...s, 'expectedEndDate': null}), isNull);
      expect(
        seasonTimeProgress({...s, 'expectedEndDate': '2026-11-01'}),
        isNull,
      );
    });
  });

  testWidgets(
    'Owner chuyển giai đoạn: gợi ý giai đoạn kế tiếp, PUT đúng API rồi tải lại',
    (tester) async {
      var current = 'st1';
      handler = (r) async {
        if (r.url.path == '/api/v1/planting-seasons') {
          return utf8Json([_season('InProgress', stage: current)]);
        }
        if (r.url.path == '/api/v1/growth-profiles/p1/stages') {
          return utf8Json(_stages);
        }
        if (r.method == 'PUT' &&
            r.url.path == '/api/v1/zones/z1/planting-seasons/s1/stage') {
          current = '${jsonDecode(r.body)['growthStageId']}';
          return utf8Json(_season('InProgress', stage: current));
        }
        return utf8Json([]);
      };
      await _pump(tester);

      expect(find.text('Vụ Đông - Xuân 2026'), findsOneWidget);
      expect(find.text('Tiến độ thời gian'), findsOneWidget);
      expect(find.text('Cây con'), findsOneWidget);

      await tester.tap(find.text('Chuyển giai đoạn'));
      await tester.pumpAndSettle();
      expect(find.text('1. Cây con (hiện tại)'), findsOneWidget);
      expect(find.text('2. Ra hoa'), findsOneWidget);
      expect(find.text('3. Thu hoạch'), findsOneWidget);

      // Giai đoạn kế tiếp đã được chọn sẵn nên bấm lưu được ngay.
      await tester.tap(find.widgetWithText(FilledButton, 'Chuyển giai đoạn'));
      await tester.pumpAndSettle();

      final put = calls.singleWhere((c) => c.method == 'PUT');
      expect(put.url.path, '/api/v1/zones/z1/planting-seasons/s1/stage');
      expect(jsonDecode(put.body), {'growthStageId': 'st2'});
      expect(find.text('Ra hoa'), findsOneWidget, reason: 'đã tải lại vụ');
      expect(find.text('Cây con'), findsNothing);
      await _dispose(tester);
    },
  );

  testWidgets('backend từ chối: giữ hộp thoại và hiện lý do', (tester) async {
    handler = (r) async {
      if (r.url.path == '/api/v1/planting-seasons') {
        return utf8Json([_season('InProgress')]);
      }
      if (r.url.path == '/api/v1/growth-profiles/p1/stages') {
        return utf8Json(_stages);
      }
      if (r.method == 'PUT') {
        return utf8Json({'detail': 'Season is already in this stage.'}, 409);
      }
      return utf8Json([]);
    };
    await _pump(tester);
    await tester.tap(find.text('Chuyển giai đoạn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3. Thu hoạch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Chuyển giai đoạn'));
    await tester.pumpAndSettle();

    expect(jsonDecode(calls.singleWhere((c) => c.method == 'PUT').body), {
      'growthStageId': 'st3',
    });
    expect(find.text('3. Thu hoạch'), findsOneWidget, reason: 'vẫn mở');
    expect(find.textContaining('already in this stage'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('vụ không đang chạy hoặc Farmer: không có nút chuyển giai đoạn', (
    tester,
  ) async {
    handler = (r) async => r.url.path == '/api/v1/planting-seasons'
        ? utf8Json([_season('Planned')])
        : utf8Json([]);
    await _pump(tester);
    expect(find.text('Chuyển giai đoạn'), findsNothing);
    expect(find.text('Tiến độ thời gian'), findsNothing);
    await _dispose(tester);

    handler = (r) async => r.url.path == '/api/v1/planting-seasons'
        ? utf8Json([_season('InProgress')])
        : utf8Json([]);
    await _pump(tester, role: 'FARMER');
    expect(find.text('Vụ thử'), findsOneWidget);
    expect(find.text('Chuyển giai đoạn'), findsNothing);
    await _dispose(tester);
  });

  group('bắt đầu vụ dự kiến', () {
    const startPath = '/api/v1/zones/z1/planting-seasons/s1/start';

    testWidgets(
      'Owner: xác nhận rồi gọi API bắt đầu vụ, tải lại và vụ thành đang canh tác',
      (tester) async {
        var status = 'Planned';
        handler = (r) async {
          if (r.url.path == '/api/v1/planting-seasons') {
            return utf8Json([_season(status)]);
          }
          if (r.method == 'POST' && r.url.path == startPath) {
            status = 'InProgress';
            return utf8Json(_season('InProgress'));
          }
          return utf8Json([]);
        };
        await _pump(tester);

        expect(find.text('Dự kiến'), findsOneWidget);
        expect(find.text('Chuyển giai đoạn'), findsNothing);
        await tester.tap(find.text('Bắt đầu vụ'));
        await tester.pumpAndSettle();
        expect(find.text('Bắt đầu vụ?'), findsOneWidget);
        expect(calls.where((c) => c.method == 'POST'), isEmpty);

        await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu vụ').last);
        await tester.pumpAndSettle();

        expect(
          calls.singleWhere((c) => c.method == 'POST').url.path,
          startPath,
        );
        expect(find.text('Đang canh tác'), findsOneWidget);
        expect(find.text('Bắt đầu vụ'), findsNothing);
        expect(find.text('Chuyển giai đoạn'), findsOneWidget);
        await _dispose(tester);
      },
    );

    testWidgets('Hủy ở hộp xác nhận: không gọi API', (tester) async {
      handler = (r) async => r.url.path == '/api/v1/planting-seasons'
          ? utf8Json([_season('Planned')])
          : utf8Json([]);
      await _pump(tester);
      await tester.tap(find.text('Bắt đầu vụ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
      expect(find.text('Dự kiến'), findsOneWidget);
      await _dispose(tester);
    });

    testWidgets('backend từ chối: hiện đúng lý do, vụ vẫn dự kiến', (
      tester,
    ) async {
      handler = (r) async {
        if (r.url.path == '/api/v1/planting-seasons') {
          return utf8Json([_season('Planned')]);
        }
        if (r.method == 'POST' && r.url.path == startPath) {
          return utf8Json({
            'detail':
                'Zone đã có vụ đang canh tác. Hãy kết thúc vụ hiện tại trước.',
          }, 409);
        }
        return utf8Json([]);
      };
      await _pump(tester);
      await tester.tap(find.text('Bắt đầu vụ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu vụ').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Chưa bắt đầu được vụ:'), findsOneWidget);
      expect(
        find.textContaining('Zone đã có vụ đang canh tác'),
        findsOneWidget,
      );
      expect(find.text('Dự kiến'), findsOneWidget);
      expect(find.text('Chuyển giai đoạn'), findsNothing);
      await _dispose(tester);
    });

    testWidgets('Farmer và vụ không phải dự kiến: không có nút "Bắt đầu vụ"', (
      tester,
    ) async {
      handler = (r) async => r.url.path == '/api/v1/planting-seasons'
          ? utf8Json([_season('Planned')])
          : utf8Json([]);
      await _pump(tester, role: 'FARMER');
      expect(find.text('Vụ thử'), findsOneWidget);
      expect(find.text('Bắt đầu vụ'), findsNothing);
      await _dispose(tester);

      handler = (r) async => r.url.path == '/api/v1/planting-seasons'
          ? utf8Json([_season('InProgress')])
          : utf8Json([]);
      await _pump(tester);
      expect(find.text('Bắt đầu vụ'), findsNothing);
      await _dispose(tester);
    });
  });
}
