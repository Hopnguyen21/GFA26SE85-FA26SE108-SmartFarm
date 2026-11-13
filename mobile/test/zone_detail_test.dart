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
import 'package:smartfarm_mobile/features/zones/widgets/zone_climate_panel.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_cultivation_info_card.dart';
import 'package:smartfarm_mobile/features/zones/zone_climate_logic.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_logic.dart';
import 'package:smartfarm_mobile/features/zones/zone_detail_screen.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

ZoneModel _zone({
  String id = 'z1',
  String name = 'Nhà màng 1',
  String? profileId,
  String season = 'None',
  String? stage,
}) => ZoneModel.fromJson(
  {
    'zoneId': id,
    'name': name,
    'areaM2': 100,
    'seasonStatus': season,
    'currentStage': ?stage,
    'growthProfileId': profileId,
    'growthProfileName': profileId == null ? null : 'VietGAP',
  },
  farmId: 'f1',
  fieldId: 'fl1',
);

Map<String, dynamic> _metric(
  String code,
  num value, {
  bool fresh = true,
  String unit = '',
}) => {
  'parameterCode': code,
  'value': value,
  'unit': unit,
  'capturedAtUtc': '2026-11-11T08:00:00Z',
  'receivedAtUtc': '2026-11-11T08:00:01Z',
  'isFresh': fresh,
  'thresholdStatus': 'Unknown',
};

Map<String, dynamic> _telemetry({
  List<Map<String, dynamic>>? metrics,
  bool fresh = true,
}) => {
  'zoneId': 'z1',
  'latestReceivedAtUtc': '2026-11-11T08:00:01Z',
  'hasFreshTelemetry': fresh,
  'metrics':
      metrics ??
      [
        _metric('SoilMoisture', 65, unit: '%'),
        _metric('Temperature', 41, unit: '°C'),
        _metric('AirHumidity', 70, unit: '%'),
      ],
};

Map<String, dynamic> _profile() => {
  'profileId': 'p1',
  'name': 'VietGAP',
  'cropName': 'Dưa lưới',
  'varietyName': null,
  'isSystemDefined': true,
  'stages': [
    {
      'stageId': 'st1',
      'name': 'Cây con',
      'stageOrder': 1,
      'durationDays': 20,
      'requirements': [
        {
          'parameterCode': 'SoilMoisture',
          'minValue': 60,
          'maxValue': 80,
          'targetValue': 70,
          'unit': '%',
        },
        {
          'parameterCode': 'Temperature',
          'minValue': 20,
          'maxValue': 30,
          'targetValue': 25,
          'unit': '°C',
        },
      ],
    },
    {
      'stageId': 'st2',
      'name': 'Ra hoa',
      'stageOrder': 2,
      'durationDays': 35,
      'requirements': [],
    },
  ],
};

void _route({
  Map<String, dynamic>? telemetry,
  http.Response? telemetryError,
  List<Map<String, dynamic>> seasons = const [],
}) {
  handler = (r) async {
    final p = r.url.path;
    if (p.endsWith('/telemetry/latest'))
      return telemetryError ?? utf8Json(telemetry ?? _telemetry());
    if (p == '/api/v1/growth-profiles') return utf8Json([_profile()]);
    if (p == '/api/v1/planting-seasons') return utf8Json(seasons);
    return utf8Json([]);
  };
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
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
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('logic', () {
    test(
      'giai đoạn hiện tại chỉ xác định khi có vụ InProgress và tên khớp hồ sơ của Zone',
      () {
        final stages = [
          for (final s in (_profile()['stages'] as List))
            StageDraft.fromJson(Map<String, dynamic>.from(s as Map)),
        ];
        expect(
          currentStageOfZone(
            profileStages: stages,
            seasonStatus: 'InProgress',
            currentStageName: 'cây con',
          )?.stageId,
          'st1',
        );
        expect(
          currentStageOfZone(
            profileStages: stages,
            seasonStatus: 'None',
            currentStageName: 'Cây con',
          ),
          isNull,
        );
        expect(
          currentStageOfZone(
            profileStages: stages,
            seasonStatus: 'InProgress',
            currentStageName: 'Khác',
          ),
          isNull,
        );
      },
    );

    test(
      'đánh giá ngưỡng: số đo cũ/thiếu ngưỡng không bị đánh giá đạt hay không đạt',
      () {
        const req = RequirementDraft(
          code: 'SoilMoisture',
          min: 60,
          max: 80,
          target: 70,
          unit: '%',
        );
        TelemetryMetric m(double v, {bool fresh = true}) => TelemetryMetric(
          code: 'soilmoisture',
          value: v,
          unit: '%',
          capturedAtUtc: null,
          isFresh: fresh,
          thresholdStatus: '',
        );
        expect(evaluateMetric(m(65), req), MetricVerdict.ok);
        expect(evaluateMetric(m(50), req), MetricVerdict.below);
        expect(evaluateMetric(m(90), req), MetricVerdict.above);
        expect(evaluateMetric(m(65, fresh: false), req), MetricVerdict.stale);
        expect(evaluateMetric(m(65), null), MetricVerdict.noThreshold);
        expect(evaluateMetric(null, req), MetricVerdict.noData);
      },
    );

    test(
      'đọc telemetry: mã tham số chuẩn hóa, bỏ số đo không phải số, PascalCase vẫn đọc được',
      () {
        final s = ZoneTelemetrySnapshot.fromJson({
          'HasFreshTelemetry': true,
          'Metrics': [
            {
              'ParameterCode': 'LightIntensity',
              'Value': 800,
              'Unit': 'lx',
              'IsFresh': true,
            },
            {'parameterCode': 'Ph', 'value': 'abc', 'isFresh': true},
          ],
        });
        expect(s.metrics.keys, ['lightintensity']);
        expect(s.hasFreshTelemetry, isTrue);
        expect(
          ageText(
            DateTime.utc(2026, 11, 11, 8),
            DateTime.utc(2026, 11, 11, 8, 30),
          ),
          '30 phút trước',
        );
      },
    );
  });

  group('tab Vi khí hậu', () {
    testWidgets(
      'Zone CHƯA có vụ/hồ sơ: vẫn hiện telemetry, nhưng không đánh giá đạt/không đạt',
      (tester) async {
        _route();
        await _pump(
          tester,
          ZoneClimatePanel(
            zone: _zone(),
            refreshEvery: null,
            clock: () => DateTime.utc(2026, 11, 11, 8, 10),
          ),
        );
        expect(
          find.textContaining('65'),
          findsWidgets,
          reason: 'số đo độ ẩm đất vẫn hiển thị',
        );
        expect(find.textContaining('Chưa gắn hồ sơ canh tác'), findsWidgets);
        expect(
          find.textContaining('Zone chưa có vụ đang canh tác'),
          findsOneWidget,
        );
        expect(find.text('Trong ngưỡng'), findsNothing);
        expect(find.textContaining('Chưa đánh giá được'), findsOneWidget);
        expect(find.textContaining('Telemetry mới'), findsOneWidget);
        await _dispose(tester);
      },
    );

    testWidgets(
      'có hồ sơ của Zone + vụ InProgress: dùng ngưỡng giai đoạn hiện tại, báo đúng cao/thấp/đạt',
      (tester) async {
        _route();
        await _pump(
          tester,
          ZoneClimatePanel(
            zone: _zone(
              profileId: 'p1',
              season: 'InProgress',
              stage: 'Cây con',
            ),
            refreshEvery: null,
            clock: () => DateTime.utc(2026, 11, 11, 8, 10),
          ),
        );
        expect(
          calls.any((c) => c.url.path == '/api/v1/growth-profiles'),
          isTrue,
          reason: 'tải hồ sơ theo growthProfileId của Zone',
        );
        expect(
          find.text('Trong ngưỡng'),
          findsOneWidget,
          reason: 'độ ẩm đất 65 trong 60–80',
        );
        expect(
          find.text('Cao hơn ngưỡng'),
          findsOneWidget,
          reason: 'nhiệt độ 41 > 30',
        );
        expect(
          find.text('Chưa có ngưỡng'),
          findsWidgets,
          reason: 'độ ẩm không khí không có ngưỡng trong hồ sơ',
        );
        expect(
          find.textContaining('Đánh giá theo ngưỡng giai đoạn "Cây con"'),
          findsOneWidget,
        );
        await _dispose(tester);
      },
    );

    testWidgets(
      'số đo cũ: hiện nhãn "cũ" và không đánh giá; telemetry không phải "mới nhất"',
      (tester) async {
        _route(
          telemetry: _telemetry(
            fresh: false,
            metrics: [_metric('SoilMoisture', 65, fresh: false, unit: '%')],
          ),
        );
        await _pump(
          tester,
          ZoneClimatePanel(
            zone: _zone(
              profileId: 'p1',
              season: 'InProgress',
              stage: 'Cây con',
            ),
            refreshEvery: null,
            clock: () => DateTime.utc(2026, 11, 12, 8),
          ),
        );
        expect(find.textContaining('Telemetry đã cũ'), findsWidgets);
        expect(find.text('Số đo cũ'), findsOneWidget);
        expect(find.text('Trong ngưỡng'), findsNothing);
        expect(find.textContaining('Telemetry mới'), findsNothing);
        await _dispose(tester);
      },
    );

    testWidgets(
      'chưa có số đo nào / lỗi 403: báo rõ, có thử lại, không bịa số',
      (tester) async {
        _route(telemetry: _telemetry(metrics: [], fresh: false));
        await _pump(
          tester,
          ZoneClimatePanel(zone: _zone(), refreshEvery: null),
        );
        expect(find.textContaining('Chưa có số đo telemetry'), findsWidgets);
        await _dispose(tester);

        _route(
          telemetryError: utf8Json({
            'message': 'Bạn không có quyền xem Zone này',
          }, 403),
        );
        await _pump(
          tester,
          ZoneClimatePanel(zone: _zone(), refreshEvery: null),
        );
        expect(find.textContaining('Không tải được telemetry'), findsOneWidget);
        expect(find.text('Thử lại'), findsOneWidget);
        await _dispose(tester);
      },
    );

    testWidgets('telemetry lấy theo zoneId của chính Zone đang mở', (
      tester,
    ) async {
      _route();
      await _pump(
        tester,
        ZoneClimatePanel(zone: _zone(id: 'zone-xyz'), refreshEvery: null),
      );
      expect(
        calls.any(
          (c) => c.url.path == '/api/v1/zones/zone-xyz/telemetry/latest',
        ),
        isTrue,
      );
      await _dispose(tester);
    });
  });

  group('tab Canh tác', () {
    testWidgets(
      'không còn dữ liệu cứng; hiện thông tin thật từ vụ + hồ sơ và tách nguồn',
      (tester) async {
        _route(
          seasons: [
            {
              'seasonId': 's1',
              'name': 'Vụ đông 2026',
              'status': 'InProgress',
              'cropName': 'Dưa lưới',
              'growthProfileId': 'p1',
              'growthProfileName': 'VietGAP',
              'currentGrowthStageName': 'Cây con',
              'startDate': '2026-11-01',
              'expectedEndDate': '2027-01-20',
            },
          ],
        );
        await _pump(
          tester,
          SingleChildScrollView(
            child: ZoneCultivationInfoCard(zone: _zone(profileId: 'p1')),
          ),
        );
        for (final fake in [
          '95 ngày',
          'VietGAP TCVN',
          '3.5 cây/m²',
          '01/09/2026',
          '05/12/2026',
        ]) {
          expect(
            find.textContaining(fake),
            findsNothing,
            reason: '"$fake" là dữ liệu cứng đã bị loại bỏ',
          );
        }
        expect(find.text('THUỘC ZONE'), findsOneWidget);
        expect(find.textContaining('HỒ SƠ CANH TÁC'), findsOneWidget);
        expect(find.text('VỤ TRỒNG'), findsOneWidget);
        expect(find.text('Vụ đông 2026'), findsOneWidget);
        expect(find.text('Đang canh tác'), findsOneWidget);
        expect(find.text('Cây con'), findsOneWidget);
        expect(
          find.text('Dưa lưới'),
          findsWidgets,
          reason: 'Zone chưa có currentCrop thì lấy cây từ vụ đang canh tác',
        );
        expect(find.text('Chưa gán cây'), findsNothing);
        expect(
          find.textContaining('55 ngày (theo hồ sơ)'),
          findsOneWidget,
          reason: '20 + 35 ngày từ các giai đoạn của hồ sơ',
        );
        expect(find.text('Hồ sơ hệ thống (chỉ xem)'), findsOneWidget);
      },
    );

    testWidgets('Zone chưa có hồ sơ/vụ: nói rõ và hiện "—", không suy đoán', (
      tester,
    ) async {
      _route();
      await _pump(
        tester,
        SingleChildScrollView(child: ZoneCultivationInfoCard(zone: _zone())),
      );
      expect(
        find.textContaining('Zone chưa gắn hồ sơ canh tác'),
        findsOneWidget,
      );
      expect(find.textContaining('Zone chưa có vụ trồng'), findsOneWidget);
      expect(find.text('Chưa gán cây'), findsOneWidget);
    });

    testWidgets('không tràn ở 320px, chữ 1,3×', (tester) async {
      _route(
        seasons: [
          {
            'seasonId': 's1',
            'name': 'Vụ đông 2026 - Nhà màng số 01 khu Lâm Đồng',
            'status': 'InProgress',
            'cropName': 'Dưa leo màu',
            'varietyName': 'Dưa leo màu (Demo Green F1)',
            'growthProfileName': 'Quy trình VietGAP Dưa Leo Nhà Màng (75 ngày)',
            'currentGrowthStageName': 'Phát triển thân lá & Leo giàn',
            'startDate': '2026-11-11',
            'expectedEndDate': '2027-02-09',
          },
        ],
      );
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZoneCultivationInfoCard(zone: _zone(profileId: 'p1')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('VỤ TRỒNG'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'ZoneDetailScreen tra Zone theo zoneId; Zone không còn trong dữ liệu thì báo rõ, không hiện Zone khác',
    (tester) async {
      _route();
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = FarmProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: ZoneDetailScreen(
              zone: _zone(id: 'gone', name: 'Zone đã mất'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      provider.setZonesForTesting([
        ZoneModel.fromJson(
          {'zoneId': 'other', 'name': 'Zone khác', 'areaM2': 1},
          farmId: 'f1',
          fieldId: 'fl1',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không tìm thấy Zone "Zone đã mất"'),
        findsOneWidget,
      );
      expect(find.text('Zone khác'), findsNothing);
      expect(find.text('Tải lại'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      provider.dispose();
    },
  );
}
