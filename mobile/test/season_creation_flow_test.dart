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

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

final _zone = ZoneModel.fromJson({'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100}, farmId: 'f1', fieldId: 'fl1');

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
        {'profileId': 'general', 'cropId': 'c1', 'varietyId': null, 'name': 'Hồ sơ chung'},
        {'profileId': 'forV1', 'cropId': 'c1', 'varietyId': 'v1', 'name': 'Hồ sơ giống A'},
        {'profileId': 'forV2', 'cropId': 'c1', 'varietyId': 'v2', 'name': 'Hồ sơ giống B'},
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
            child: ElevatedButton(onPressed: () => showCreateSeasonSheet(context, _zone), child: const Text('mở')),
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
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  testWidgets('Zone đang có vụ InProgress: cảnh báo nêu tên vụ + hướng xử lý TRƯỚC khi gửi, nút tạo bị khóa', (
    tester,
  ) async {
    _route(
      seasons: [
        {'seasonId': 's1', 'zoneId': 'z1', 'name': 'Vụ đông 2026', 'status': 'InProgress', 'startDate': '2026-11-01'},
      ],
    );
    await _openSheet(tester);
    expect(find.textContaining('Vụ đông 2026'), findsOneWidget);
    expect(find.textContaining('không tự đóng vụ đang chạy'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Tạo vụ trồng'));
    expect(button.onPressed, isNull);
    expect(calls.where((c) => c.method == 'POST'), isEmpty);
  });

  testWidgets('chọn giống: danh sách hồ sơ chỉ gồm hồ sơ khớp đúng giống; đổi giống thì bỏ hồ sơ cũ', (tester) async {
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
    expect(find.text('Hồ sơ chung'), findsNothing, reason: 'hồ sơ đã chọn bị xóa khi đổi giống');
    await tester.tap(find.text('Hồ sơ sinh trưởng *'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ giống A'), findsWidgets);
    expect(find.text('Hồ sơ giống B'), findsNothing);
  });
}
