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
import 'package:smartfarm_mobile/features/zones/widgets/record_yield_dialog.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_yield_card.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response _json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _zone = ZoneModel.fromJson(
  {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 1000},
  farmId: 'f1',
  fieldId: 'fl1',
  farmName: 'Trang trại A',
);

Map<String, dynamic> _season({
  String status = 'InProgress',
  Object? yieldKg,
  String? crop = 'Dưa lưới',
  String currentGrowthStageName = 'Thu hoạch',
  String startDate = '2026-11-01',
  String expectedEndDate = '2027-01-20',
}) => {
  'seasonId': 's1',
  'zoneId': 'z1',
  'name': 'Vụ đông 2026',
  'status': status,
  'cropName': crop,
  'currentGrowthStageName': currentGrowthStageName,
  'actualYieldKg': yieldKg,
  'startDate': startDate,
  'expectedEndDate': expectedEndDate,
  if (status == 'Completed') 'actualEndDate': '2027-01-18',
};

Future<void> _pump(WidgetTester tester, {String role = 'FarmOwner'}) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ApiService.setTokens(
    accessToken: 't',
    refreshToken: 'r',
    email: 'a@b.c',
    role: role,
  );
  final provider = FarmProvider()
    ..switchRole(role == 'FarmOwner' ? 'OWNER' : 'TECHNICIAN');
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ZoneYieldCard(zone: _zone)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
  _provider = provider;
}

FarmProvider? _provider;

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  _provider?.dispose();
  _provider = null;
}

Future<T> _withHttp<T>(Future<T> Function() body) => body();

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
    harvestNoteCache.clear();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'pickHarvestSeason: ưu tiên vụ đang chạy (đã đến thu hoạch), rồi vụ đã thu hoạch gần nhất',
    () {
      final a = {'status': 'Completed', 'startDate': '2025-01-01', 'name': 'a'};
      final b = {'status': 'Completed', 'startDate': '2026-01-01', 'name': 'b'};
      final c = {
        'status': 'InProgress',
        'startDate': '2024-01-01',
        'name': 'c',
        'currentGrowthStageName': 'Thu hoạch',
      };
      final p = {'status': 'Planned', 'startDate': '2027-01-01', 'name': 'p'};
      expect(pickHarvestSeason([a, b, p])!['name'], 'b');
      expect(pickHarvestSeason([a, b, c])!['name'], 'c');
      expect(pickHarvestSeason([p]), isNull);
    },
  );

  test('fmtKg / yieldPerM2', () {
    expect(fmtKg(1250), '1.250');
    expect(fmtKg(12.5), '12,5');
    expect(yieldPerM2(500, 1000), 0.5);
    expect(yieldPerM2(500, 0), 0);
  });

  testWidgets('chưa có vụ: ẩn hoàn toàn thẻ sản lượng', (tester) async {
    handler = (r) async => _json([]);
    await _withHttp(() => _pump(tester));
    expect(find.byKey(const Key('zone_yield_card')), findsNothing);
    expect(find.byKey(const Key('yield_open')), findsNothing);
    expect(find.textContaining('1.250'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('vụ đang chạy ở giai đoạn Cây con: ẩn hoàn toàn thẻ sản lượng', (
    tester,
  ) async {
    handler = (r) async => _json([
      _season(
        currentGrowthStageName: 'Cây con & Hồi xanh',
        startDate: DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String()
            .split('T')[0],
        expectedEndDate: DateTime.now()
            .add(const Duration(days: 85))
            .toIso8601String()
            .split('T')[0],
      ),
    ]);
    await _withHttp(() => _pump(tester));
    expect(find.byKey(const Key('zone_yield_card')), findsNothing);
    expect(find.text('Sản lượng canh tác & thu hoạch'), findsNothing);
    await _dispose(tester);
  });

  testWidgets('vụ đang chạy chưa ghi: hiện Chưa ghi nhận; Owner có nút nhập', (
    tester,
  ) async {
    handler = (r) async => _json([_season()]);
    await _withHttp(() => _pump(tester));
    expect(find.text('Vụ đang canh tác'), findsOneWidget);
    expect(find.text('Chưa ghi nhận'), findsWidgets);
    expect(find.byKey(const Key('yield_open')), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('vụ đã thu hoạch: kg, tấn, kg/m² và ngày thu hoạch từ backend', (
    tester,
  ) async {
    handler = (r) async => _json([_season(status: 'Completed', yieldKg: 1250)]);
    await _withHttp(() => _pump(tester));
    expect(find.text('Đã thu hoạch'), findsOneWidget);
    expect(find.textContaining('1.250'), findsOneWidget);
    expect(find.text('≈ 1.25 tấn'), findsOneWidget);
    expect(find.text('18/01/2027'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('Technician không thấy nút nhập', (tester) async {
    handler = (r) async => _json([_season()]);
    await _withHttp(() => _pump(tester, role: 'PlatformTechnician'));
    expect(find.byKey(const Key('yield_open')), findsNothing);
    await _dispose(tester);
  });

  testWidgets(
    'nhập sản lượng: xem trước tấn + kg/m², gửi PUT /yield kèm phân loại + chốt vụ',
    (tester) async {
      Map<String, dynamic>? body;
      handler = (r) async {
        calls.add(r);
        if (r.method == 'PUT' && r.url.path.endsWith('/yield')) {
          body = jsonDecode(r.body) as Map<String, dynamic>;
          return _json(_season(status: 'Completed', yieldKg: 500));
        }
        return _json([_season()]);
      };
      await _withHttp(() async {
        await _pump(tester);
        await tester.tap(find.byKey(const Key('yield_open')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('yield_kg')), '500');
        await tester.pump();
        expect(find.text('≈ 0.50 tấn'), findsOneWidget);
        expect(find.text('Năng suất: 0.50 kg/m²'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('yield_notes')), 'Ngọt');
        await tester.tap(find.byKey(const Key('yield_save')));
        await tester.pumpAndSettle();
      });
      expect(body, isNotNull);
      expect(body!['actualYieldKg'], 500);
      expect(body!['markCompleted'], true);
      expect(body!['notes'], 'Loại 1 (Xuất khẩu / Siêu thị cao cấp) - Ngọt');
      expect(body!['actualEndDate'], isNotNull);
      await _dispose(tester);
    },
  );

  testWidgets('sản lượng trống bị chặn, không gọi API', (tester) async {
    handler = (r) async {
      calls.add(r);
      return _json([_season()]);
    };
    await _withHttp(() async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('yield_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('yield_save')));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('lớn hơn hoặc bằng 0'), findsOneWidget);
    expect(calls.where((c) => c.method == 'PUT'), isEmpty);
    await _dispose(tester);
  });
}
