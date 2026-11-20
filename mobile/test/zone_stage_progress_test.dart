import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/home/widgets/zone_stage_progress.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);

http.Response _json(Object o) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _zone = ZoneModel.fromJson(
  {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
  farmId: 'f1',
  fieldId: 'fl1',
  farmName: 'Trang trại A',
);

final _stages = [
  {'stageId': 'g3', 'stageOrder': 3, 'name': 'Ra hoa'},
  {'stageId': 'g1', 'stageOrder': 1, 'name': 'Gieo mầm'},
  {'stageId': 'g2', 'stageOrder': 2, 'name': 'Cây con'},
  {'stageId': 'g4', 'stageOrder': 4, 'name': 'Thu hoạch'},
];

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ApiService.setTokens(
    accessToken: 't',
    refreshToken: 'r',
    email: 'a@b.c',
    role: 'FarmOwner',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ZoneStageProgress(zone: _zone)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async => handler(req)),
    );
  });

  test('buildStageSteps: sắp theo thứ tự, trước hiện tại = xong', () {
    final steps = buildStageSteps(_stages, currentStageId: 'G2');
    expect(steps.map((s) => s.name), [
      'Gieo mầm',
      'Cây con',
      'Ra hoa',
      'Thu hoạch',
    ]);
    expect(steps.map((s) => s.done), [true, false, false, false]);
    expect(steps.map((s) => s.current), [false, true, false, false]);
  });

  test('buildStageSteps: không rõ giai đoạn hiện tại thì không đánh dấu', () {
    final steps = buildStageSteps(_stages, currentStageId: 'khong-co');
    expect(steps.any((s) => s.done || s.current), isFalse);
    expect(buildStageSteps(_stages).any((s) => s.done || s.current), isFalse);
  });

  testWidgets('hiện đúng số giai đoạn của hồ sơ, không cố định 6', (
    tester,
  ) async {
    handler = (r) async {
      if (r.url.path == '/api/v1/planting-seasons') {
        return _json([
          {
            'seasonId': 's1',
            'zoneId': 'z1',
            'status': 'InProgress',
            'growthProfileId': 'p1',
            'currentGrowthStageId': 'g2',
          },
        ]);
      }
      if (r.url.path == '/api/v1/growth-profiles/p1/stages') {
        return _json(_stages);
      }
      return http.Response('Not found', 404);
    };
    await _pump(tester);
    expect(find.text('TIẾN ĐỘ 4 GIAI ĐOẠN CANH TÁC'), findsOneWidget);
    expect(find.text('Gieo mầm'), findsOneWidget);
    expect(find.text('Thu hoạch'), findsOneWidget);
    // Chỉ 1 bước hoàn tất (Gieo mầm), không phải 3 như bản cố định.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('không có vụ đang canh tác: nêu rõ, không vẽ giai đoạn giả', (
    tester,
  ) async {
    handler = (r) async => _json([]);
    await _pump(tester);
    expect(find.byKey(const Key('stage_progress_empty')), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.text('Gieo mầm'), findsNothing);
  });
}
