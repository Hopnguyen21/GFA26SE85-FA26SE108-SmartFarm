import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/crops/widgets/create_season_sheet.dart';

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
);

void _route({List<Map<String, dynamic>> seasons = const []}) {
  handler = (r) async {
    final p = r.url.path;
    if (p == '/api/v1/crops') {
      return utf8Json([
        {'cropId': 'c1', 'name': 'Dưa lưới'},
      ]);
    }
    if (p == '/api/v1/growth-profiles') {
      return utf8Json([
        {
          'profileId': 'general',
          'cropId': 'c1',
          'varietyId': null,
          'name': 'Hồ sơ chung',
        },
        {
          'profileId': 'forV1',
          'cropId': 'c1',
          'varietyId': 'v1',
          'name': 'Hồ sơ giống A',
        },
        {
          'profileId': 'forV2',
          'cropId': 'c1',
          'varietyId': 'v2',
          'name': 'Hồ sơ giống B',
        },
      ]);
    }
    if (p == '/api/v1/varieties') {
      return utf8Json([
        {'varietyId': 'v1', 'name': 'Giống A'},
        {'varietyId': 'v2', 'name': 'Giống B'},
      ]);
    }
    if (p == '/api/v1/planting-seasons') return utf8Json(seasons);
    if (p == '/api/v1/seasons') {
      return utf8Json([
        {
          'id': 'fs1',
          'code': 'DX26',
          'name': 'Đông Xuân 2026',
          'year': 2026,
          'startDate': '2026-10-01',
          'endDate': '2027-03-01',
        },
      ]);
    }
    return utf8Json([]);
  };
}

Future<void> _openSheet(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCreateSeasonSheet(context, _zone),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
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
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  testWidgets(
    'Zone đang có vụ InProgress: cảnh báo nêu tên vụ + hướng xử lý TRƯỚC khi gửi, nút tạo bị khóa',
    (tester) async {
      _route(
        seasons: [
          {
            'seasonId': 's1',
            'zoneId': 'z1',
            'name': 'Vụ đông 2026',
            'status': 'InProgress',
            'startDate': '2026-11-01',
          },
        ],
      );
      await _openSheet(tester);
      expect(find.textContaining('Vụ đông 2026'), findsOneWidget);
      expect(find.textContaining('không tự đóng vụ đang chạy'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Tạo vụ trồng'),
      );
      expect(button.onPressed, isNull);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
    },
  );

  for (final days in [19, 20, 21]) {
    testWidgets('ngày kết thúc cách ngày bắt đầu mặc định $days ngày', (
      tester,
    ) async {
      _route();
      await _openSheet(tester);
      // Keep the default start (including its time), as in normal usage.
      await tester.tap(find.text('Kết thúc dự kiến *'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      picker.onDateChanged(DateUtils.addDaysToDate(DateTime.now(), days));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo vụ trồng'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Ngày kết thúc dự kiến phải sau ngày bắt đầu ít nhất 20 ngày.',
        ),
        days < 20 ? findsOneWidget : findsNothing,
      );
      if (days >= 20) {
        // Date validation passed; only the other required fields are missing.
        expect(
          find.text(
            'Hãy chọn cây, hồ sơ sinh trưởng, đặt tên và chọn ngày kết thúc dự kiến.',
          ),
          findsOneWidget,
        );
      }
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
    });
  }

  testWidgets(
    'chọn giống: danh sách hồ sơ chỉ gồm hồ sơ khớp đúng giống; đổi giống thì bỏ hồ sơ cũ',
    (tester) async {
      _route();
      await _openSheet(tester);

      await tester.tap(find.text('Cây trồng *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dưa lưới').last);
      await tester.pumpAndSettle();

      // Chưa chọn giống: chỉ hồ sơ chung.
      await tester.tap(find.text('Hồ sơ sinh trưởng *'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ chung'), findsWidgets);
      expect(find.text('Hồ sơ giống A'), findsNothing);
      await tester.tap(find.text('Hồ sơ chung').last);
      await tester.pumpAndSettle();

      // Chọn giống A: hồ sơ chung bị bỏ (không còn khớp), chỉ còn hồ sơ giống A.
      await tester.tap(find.text('Không chọn giống (hồ sơ chung)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giống A').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Hồ sơ chung'),
        findsNothing,
        reason: 'hồ sơ đã chọn bị xóa khi đổi giống',
      );
      await tester.tap(find.text('Hồ sơ sinh trưởng *'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ giống A'), findsWidgets);
      expect(find.text('Hồ sơ giống B'), findsNothing);
    },
  );

  testWidgets(
    'Zone đã gắn hồ sơ canh tác: tự động nhận diện cây, hồ sơ và tính ngày kết thúc',
    (tester) async {
      _route();
      final zoneWithProf = ZoneModel.fromJson(
        {
          'zoneId': 'z2',
          'name': 'Nhà màng 2',
          'areaM2': 150,
          'growthProfileId': 'forV1',
        },
        farmId: 'f1',
        fieldId: 'fl1',
      );
      tester.view.physicalSize = const Size(600, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCreateSeasonSheet(context, zoneWithProf),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      // Cây, giống và hồ sơ đã được tự động điền sẵn
      expect(find.text('Dưa lưới'), findsWidgets);
      expect(find.text('Giống A'), findsWidgets);
      expect(find.text('Hồ sơ giống A'), findsWidgets);
      // Nút kết thúc có ngày được tính tự động (không còn là "Kết thúc dự kiến *")
      expect(find.text('Kết thúc dự kiến *'), findsNothing);
      expect(find.textContaining('Kết thúc: '), findsOneWidget);
    },
  );

  testWidgets(
    'Chọn mùa vụ chung: hiển thị danh sách mùa vụ và gửi farmingSeasonId trong payload',
    (tester) async {
      _route();
      await _openSheet(tester);

      // Mùa vụ chung hiển thị trong form
      expect(find.text('Không gắn mùa vụ chung (vụ độc lập)'), findsOneWidget);
      await tester.tap(find.text('Không gắn mùa vụ chung (vụ độc lập)'));
      await tester.pumpAndSettle();
      expect(find.text('Đông Xuân 2026 (DX26)'), findsWidgets);
      await tester.tap(find.text('Đông Xuân 2026 (DX26)').last);
      await tester.pumpAndSettle();

      // Chọn cây và hồ sơ
      await tester.tap(find.text('Cây trồng *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dưa lưới').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hồ sơ sinh trưởng *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ sơ chung').last);
      await tester.pumpAndSettle();

      // Nhập tên vụ
      await tester.enterText(find.byType(TextField).first, 'Vụ dưa test 2026');
      await tester.pumpAndSettle();

      // Bấm Tạo vụ trồng -> mở dialog xác nhận có hiện mùa vụ chung
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo vụ trồng'));
      await tester.pumpAndSettle();

      expect(find.text('Tạo vụ trồng cho Zone?'), findsOneWidget);
      expect(
        find.textContaining('Mùa vụ chung: Đông Xuân 2026'),
        findsOneWidget,
      );

      await tester.tap(find.text('Xác nhận tạo vụ'));
      await tester.pumpAndSettle();

      final postCall = calls.where((c) => c.method == 'POST').firstOrNull;
      expect(postCall, isNotNull);
      final body = jsonDecode(postCall!.body) as Map<String, dynamic>;
      expect(body['farmingSeasonId'], 'fs1');
      expect(body['name'], 'Vụ dưa test 2026');
    },
  );
}
