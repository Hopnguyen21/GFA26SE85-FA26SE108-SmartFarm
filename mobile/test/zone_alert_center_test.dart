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
import 'package:smartfarm_mobile/features/alerts/alert_rules_logic.dart';
import 'package:smartfarm_mobile/features/alerts/zone_alert_center_screen.dart';

http.Response _json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _rule({
  String id = 'r1',
  String param = 'SoilMoisture',
  double min = 70,
  double max = 80,
  String sev = 'Warning',
  bool active = true,
  bool system = false,
}) => {
  'ruleId': id,
  'zoneId': 'z1',
  'parameterCode': param,
  'minThreshold': min,
  'maxThreshold': max,
  'severity': sev,
  'cooldownMinutes': 15,
  'isActive': active,
  'isSystemGenerated': system,
};

Map<String, dynamic> _alert({
  String id = 'aaaaaaaa-1111-2222-3333-444444444444',
  String status = 'Open',
}) => {
  'alertId': id,
  'zoneId': 'z1',
  'parameterCode': 'Temperature',
  'observedValue': 26.8,
  'minThreshold': 20,
  'maxThreshold': 25,
  'unit': '°C',
  'severity': 'Critical',
  'status': status,
  'title': 'Cảnh báo Nhiệt độ không khí vượt ngưỡng',
  'createdAtUtc': '2026-10-31T15:39:41Z',
  'history': [],
};

ZoneModel _zone({
  bool fresh = true,
  double soil = 50,
  List<Map<String, dynamic>> reqs = const [
    {'parameterCode': 'SoilMoisture', 'minValue': 70, 'maxValue': 80},
    {'parameterCode': 'Temperature', 'minValue': 20, 'maxValue': 25},
  ],
}) =>
    ZoneModel.fromJson(
      {'zoneId': 'z1', 'name': 'Khu cà chua', 'areaM2': 100},
      farmId: 'f1',
      fieldId: 'fl1',
      farmName: 'A',
    ).copyWith(
      telemetryIsFresh: fresh,
      currentSoilMoisture: soil,
      appliedRequirements: reqs,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var rules = <Map<String, dynamic>>[];
  var alerts = <Map<String, dynamic>>[];
  var rulesStatus = 200;
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];

  Future<http.Response> handler(http.Request r) async {
    final p = r.url.path;
    calls.add('${r.method} $p');
    if (r.body.isNotEmpty) {
      bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
    }
    if (p == '/api/v1/zones/z1/alert-rules' && r.method == 'GET') {
      return rulesStatus == 200
          ? _json(rules)
          : _json({
              'detail': 'Zone has no active Planting Season.',
            }, rulesStatus);
    }
    if (p == '/api/v1/zones/z1/alert-rules' && r.method == 'POST') {
      return _json(_rule(id: 'new'), 201);
    }
    if (p.startsWith('/api/v1/zones/z1/alert-rules/') && r.method == 'PUT') {
      return _json(_rule(id: 'r1'));
    }
    if (p.startsWith('/api/v1/zones/z1/alert-rules/') && r.method == 'DELETE') {
      return http.Response('', 204);
    }
    if (p == '/api/v1/zones/z1/alerts') return _json(alerts);
    if (p.endsWith('/acknowledge') || p.endsWith('/resolve')) {
      return _json(_alert(status: 'Acknowledged'));
    }
    return _json([]);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient(handler),
    );
  });

  setUp(() {
    rules = [];
    alerts = [];
    rulesStatus = 200;
    calls.clear();
    bodies.clear();
  });

  Future<FarmProvider> pump(
    WidgetTester t, {
    String role = 'OWNER',
    ZoneModel? zone,
  }) async {
    t.view.physicalSize = const Size(420, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: role == 'OWNER' ? 'FarmOwner' : 'Farmer',
    );
    final p = FarmProvider()..switchRole(role);
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(home: ZoneAlertCenterScreen(zone: zone ?? _zone())),
      ),
    );
    await t.pumpAndSettle();
    return p;
  }

  Future<void> dispose(WidgetTester t, FarmProvider p) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    p.dispose();
  }

  group('logic', () {
    test('validateRuleInput khớp luật backend (min < max, chờ 1–1440)', () {
      expect(validateRuleInput(min: 1, max: 2, cooldownMinutes: 30), isNull);
      expect(validateRuleInput(min: 5, max: 5, cooldownMinutes: 30), isNotNull);
      expect(validateRuleInput(min: 9, max: 5, cooldownMinutes: 30), isNotNull);
      expect(validateRuleInput(min: 1, max: 2, cooldownMinutes: 0), isNotNull);
      expect(
        validateRuleInput(min: 1, max: 2, cooldownMinutes: 1441),
        isNotNull,
      );
      expect(
        validateRuleInput(min: null, max: 2, cooldownMinutes: 30),
        isNotNull,
      );
    });
    test('canonicalParameter chấp nhận mã khác hoa thường/đồng nghĩa', () {
      expect(canonicalParameter('SOILMOISTURE'), 'SoilMoisture');
      expect(canonicalParameter('light'), 'LightIntensity');
      expect(canonicalParameter('CO2'), isNull);
    });
    test('isViolating chỉ khi quy tắc bật và có số đo mới', () {
      expect(
        isViolating(ruleActive: true, current: 50, min: 70, max: 80),
        isTrue,
      );
      expect(
        isViolating(ruleActive: false, current: 50, min: 70, max: 80),
        isFalse,
      );
      expect(
        isViolating(ruleActive: true, current: null, min: 70, max: 80),
        isFalse,
      );
      expect(
        isViolating(ruleActive: true, current: 75, min: 70, max: 80),
        isFalse,
      );
    });
  });

  testWidgets(
    'hiện quy tắc thật, dải an toàn, số đo thực tế và nhãn ĐANG VI PHẠM',
    (t) async {
      rules = [_rule()];
      final p = await pump(t, zone: _zone(soil: 50));
      expect(
        find.text('Cấu hình Quy tắc Cảnh báo An toàn Zone (1 luật phù hợp)'),
        findsOneWidget,
      );
      expect(find.text('TRUNG TÂM CẢNH BÁO NÔNG NGHIỆP'), findsOneWidget);
      expect(find.text('Tham số: Độ ẩm đất'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.textContaining('[70 – 80] %'), findsOneWidget);
      expect(find.text('Thực tế: 50 %'), findsOneWidget);
      expect(find.text('⚡ ĐANG VI PHẠM'), findsOneWidget);
      await dispose(t, p);
    },
  );

  testWidgets('số đo cũ: không có "Thực tế" và không báo vi phạm', (t) async {
    rules = [_rule()];
    final p = await pump(t, zone: _zone(fresh: false));
    expect(find.textContaining('Thực tế'), findsNothing);
    expect(find.text('⚡ ĐANG VI PHẠM'), findsNothing);
    await dispose(t, p);
  });

  testWidgets(
    'Farmer: chỉ xem, không có nút thêm/sửa/xóa và không bật tắt được',
    (t) async {
      rules = [_rule()];
      final p = await pump(t, role: 'FARMER');
      expect(find.byKey(const Key('add_rule')), findsNothing);
      expect(find.byTooltip('Sửa quy tắc'), findsNothing);
      expect(find.byTooltip('Xóa luật'), findsNothing);
      expect(tester(t).widget<Switch>(find.byType(Switch)).onChanged, isNull);
      await dispose(t, p);
    },
  );

  testWidgets(
    'quy tắc hệ thống bị khóa; Zone chưa có vụ: nêu lý do của backend',
    (t) async {
      rules = [_rule(system: true)];
      var p = await pump(t);
      expect(find.text('Hệ thống'), findsOneWidget);
      expect(find.byTooltip('Sửa quy tắc'), findsNothing);
      await dispose(t, p);

      rulesStatus = 409;
      p = await pump(t);
      expect(find.byKey(const Key('rules_note')), findsOneWidget);
      expect(find.textContaining('no active Planting Season'), findsOneWidget);
      // vẫn xem được nhật ký
      expect(find.byKey(const Key('alert_log_title')), findsOneWidget);
      await dispose(t, p);
    },
  );

  testWidgets('bật/tắt quy tắc gửi PUT kèm đủ trường và isActive mới', (
    t,
  ) async {
    rules = [_rule()];
    final p = await pump(t);
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    final put = calls.where(
      (c) => c.startsWith('PUT /api/v1/zones/z1/alert-rules/r1'),
    );
    expect(put, hasLength(1));
    final b = bodies.last;
    expect(b['isActive'], false);
    expect(b['parameterCode'], 'SoilMoisture');
    expect(b['minThreshold'], 70);
    expect(b['severity'], 'Warning');
    await dispose(t, p);
  });

  testWidgets(
    'thêm quy tắc: chặn min ≥ max ở máy, hợp lệ thì POST đúng nội dung',
    (t) async {
      final p = await pump(t);
      await t.tap(find.byKey(const Key('add_rule')));
      await t.pumpAndSettle();
      // gợi ý min/max lấy từ ngưỡng giai đoạn (70–80)
      expect(find.widgetWithText(TextField, '70'), findsOneWidget);
      await t.enterText(find.byKey(const Key('rule_min')), '90');
      await t.tap(find.byKey(const Key('rule_save')));
      await t.pump();
      expect(find.byKey(const Key('rule_error')), findsOneWidget);
      expect(calls.where((c) => c.startsWith('POST')), isEmpty);

      await t.enterText(find.byKey(const Key('rule_min')), '65');
      await t.enterText(find.byKey(const Key('rule_cooldown')), '45');
      await t.tap(find.byKey(const Key('rule_severity')));
      await t.pumpAndSettle();
      await t.tap(find.text('Nguy hiểm khẩn cấp (CRITICAL)').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('rule_save')));
      await t.pumpAndSettle();
      expect(
        calls.where((c) => c.startsWith('POST /api/v1/zones/z1/alert-rules')),
        hasLength(1),
      );
      final b = bodies.firstWhere(
        (x) => x.containsKey('cooldownMinutes') && x['cooldownMinutes'] == 45,
      );
      expect(b['parameterCode'], 'SoilMoisture');
      expect(b['minThreshold'], 65);
      expect(b['maxThreshold'], 80);
      expect(b['severity'], 'Critical');
      await dispose(t, p);
    },
  );

  testWidgets('trùng tham số + mức độ: báo ngay, không gọi API', (t) async {
    rules = [_rule()];
    final p = await pump(t);
    await t.tap(find.byKey(const Key('add_rule')));
    await t.pumpAndSettle();
    await t.tap(
      find.byKey(const Key('rule_save')),
    ); // SoilMoisture + Warning mặc định đã tồn tại
    await t.pump();
    expect(find.textContaining('Đã có quy tắc'), findsOneWidget);
    expect(calls.where((c) => c.startsWith('POST')), isEmpty);
    await dispose(t, p);
  });

  testWidgets(
    'Zone chưa có ngưỡng giai đoạn: không tạo được quy tắc, nêu rõ lý do',
    (t) async {
      final p = await pump(t, zone: _zone(reqs: const []));
      await t.tap(find.byKey(const Key('add_rule')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('editor_no_params')), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byKey(const Key('rule_save'))).onPressed,
        isNull,
      );
      await dispose(t, p);
    },
  );

  testWidgets('xóa quy tắc: hỏi xác nhận rồi DELETE', (t) async {
    rules = [_rule()];
    final p = await pump(t);
    await t.tap(find.byTooltip('Xóa luật'));
    await t.pumpAndSettle();
    await t.tap(find.text('Giữ lại'));
    await t.pumpAndSettle();
    expect(calls.where((c) => c.startsWith('DELETE')), isEmpty);
    await t.tap(find.byTooltip('Xóa luật'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xóa'));
    await t.pumpAndSettle();
    expect(
      calls.where(
        (c) => c.startsWith('DELETE /api/v1/zones/z1/alert-rules/r1'),
      ),
      hasLength(1),
    );
    await dispose(t, p);
  });

  testWidgets(
    'nhật ký: xác nhận cảnh báo mở; đóng cảnh báo bắt buộc ghi hành động',
    (t) async {
      alerts = [_alert()];
      final p = await pump(t);
      expect(find.text('1 cảnh báo đang mở cần xử lý'), findsOneWidget);
      expect(
        find.textContaining('Giá trị vi phạm: 26.8 °C · ngưỡng 20–25 °C'),
        findsOneWidget,
      );
      await t.tap(
        find.byKey(const Key('ack_aaaaaaaa-1111-2222-3333-444444444444')),
      );
      await t.pumpAndSettle();
      expect(
        calls,
        contains(
          'PUT /api/v1/alerts/aaaaaaaa-1111-2222-3333-444444444444/acknowledge',
        ),
      );

      await t.tap(
        find.byKey(const Key('resolve_aaaaaaaa-1111-2222-3333-444444444444')),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Đóng cảnh báo').last);
      await t.pump();
      expect(find.text('Bắt buộc ghi hành động đã làm.'), findsOneWidget);
      expect(calls.where((c) => c.endsWith('/resolve')), isEmpty);
      await t.enterText(find.byKey(const Key('resolve_action')), 'Đã bật quạt');
      await t.tap(find.text('Đóng cảnh báo').last);
      await t.pumpAndSettle();
      expect(calls.where((c) => c.endsWith('/resolve')), hasLength(1));
      expect(bodies.last['actionTaken'], 'Đã bật quạt');
      await dispose(t, p);
    },
  );

  testWidgets('cảnh báo đã đóng không còn nút thao tác', (t) async {
    alerts = [_alert(status: 'Resolved')];
    final p = await pump(t);
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Xác nhận'), findsNothing);
    expect(find.text('Đóng cảnh báo'), findsNothing);
    await dispose(t, p);
  });
}

WidgetTester tester(WidgetTester t) => t;
