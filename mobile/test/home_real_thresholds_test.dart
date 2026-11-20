import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/home/widgets/zone_temperature_gauge.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_logic.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);

http.Response _json(Object o) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _stage(String id, String name, double min, double max) => {
  'stageId': id,
  'stageOrder': 1,
  'name': name,
  'durationDays': 20,
  'requirements': [
    {
      'parameterCode': 'Temperature',
      'minValue': min,
      'maxValue': max,
      'targetValue': (min + max) / 2,
      'unit': '°C',
    },
  ],
};

ZoneModel _zone({
  double temp = 21,
  String stage = 'Cây con',
  String season = 'InProgress',
  bool fresh = true,
}) => ZoneModel.fromJson(
  {
    'zoneId': 'z1',
    'name': 'Nhà màng 1',
    'areaM2': 100,
    'currentStage': stage,
    'seasonStatus': season,
    'growthProfileId': 'p1',
  },
  farmId: 'f1',
  fieldId: 'fl1',
  farmName: 'A',
).copyWith(currentTemp: temp, telemetryIsFresh: fresh);

Future<void> _pump(WidgetTester tester, ZoneModel zone) async {
  ApiService.setTokens(
    accessToken: 't',
    refreshToken: 'r',
    email: 'a@b.c',
    role: 'FarmOwner',
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ZoneTemperatureGauge(zone: zone, onEditThresholds: () {}),
        ),
      ),
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

  test(
    'safeTempRangeOf: chỉ khi vụ đang chạy và khớp giai đoạn; mã nhiệt độ chuẩn hóa',
    () {
      final stages = [
        StageDraft.fromJson(_stage('g1', 'Cây con', 20, 26)),
        StageDraft.fromJson(_stage('g2', 'Ra hoa', 18, 24)),
      ];
      final r = safeTempRangeOf(
        stages: stages,
        seasonStatus: 'InProgress',
        currentStage: 'ra hoa',
      );
      expect((r!.min, r.max), (18.0, 24.0));
      expect(
        safeTempRangeOf(
          stages: stages,
          seasonStatus: 'PlannedOnly',
          currentStage: 'Ra hoa',
        ),
        isNull,
      );
      expect(
        safeTempRangeOf(
          stages: stages,
          seasonStatus: 'InProgress',
          currentStage: 'Giai đoạn lạ',
        ),
        isNull,
      );
    },
  );

  test('gaugeScale bao trọn vùng an toàn và số đo, làm tròn 5°C', () {
    final s = gaugeScale((min: 20.0, max: 26.0), 21);
    expect(s.min, lessThanOrEqualTo(12));
    expect(s.max, greaterThanOrEqualTo(38));
    expect(s.min % 5, 0);
    final hot = gaugeScale((min: 20.0, max: 26.0), 45);
    expect(hot.max, greaterThanOrEqualTo(47));
  });

  testWidgets(
    'hiện ngưỡng thật của hồ sơ (không phải 18–28) và ngưỡng quạt đã lưu',
    (tester) async {
      handler = (r) async {
        if (r.url.path == '/api/v1/growth-profiles/p1/stages') {
          return _json([_stage('g1', 'Cây con', 20, 26)]);
        }
        if (r.url.path == '/api/v1/control/environmental-configs') {
          return _json([
            {'zoneId': 'z1', 'maxTemperature': 25, 'minSoilMoisture': 70},
          ]);
        }
        return http.Response('Not found', 404);
      };
      await _pump(tester, _zone(temp: 21));
      expect(find.text('Chuẩn: 20°C - 26°C'), findsOneWidget);
      expect(find.text('✓ Chuẩn'), findsOneWidget);
      expect(find.textContaining('Quạt bật khi > 25°C'), findsOneWidget);
      expect(find.textContaining('18°C - 28°C'), findsNothing);
    },
  );

  testWidgets('quá nóng theo ngưỡng thật: cảnh báo kèm số ngưỡng của hồ sơ', (
    tester,
  ) async {
    handler = (r) async {
      if (r.url.path == '/api/v1/growth-profiles/p1/stages') {
        return _json([_stage('g1', 'Cây con', 20, 26)]);
      }
      return _json([]);
    };
    await _pump(tester, _zone(temp: 29));
    expect(find.text('⚠️ > 26°C'), findsOneWidget);
    expect(
      find.textContaining('Chưa cấu hình ngưỡng bật quạt'),
      findsOneWidget,
    );
  });

  testWidgets('không có vụ đang chạy: không đánh giá bằng ngưỡng giả', (
    tester,
  ) async {
    handler = (r) async => _json([]);
    await _pump(
      tester,
      _zone(season: 'None', stage: 'Chưa có vụ đang canh tác'),
    );
    expect(find.byKey(const Key('temp_gauge_no_threshold')), findsOneWidget);
    expect(find.byKey(const Key('temp_gauge_verdict')), findsNothing);
  });

  testWidgets('telemetry cũ: không đánh giá', (tester) async {
    handler = (r) async => _json([]);
    await _pump(tester, _zone(fresh: false));
    expect(find.textContaining('Chưa có telemetry'), findsOneWidget);
  });
}
