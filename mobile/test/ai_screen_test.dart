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
import 'package:smartfarm_mobile/core/utils/ai_text.dart';
import 'package:smartfarm_mobile/features/ai/ai_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _guid = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';

Map<String, dynamic> _rec({String status = 'Ready'}) => {
  'recommendationId': 'r1',
  'question': 'Có cần tưới không?',
  'summary': 'Nên tưới nhẹ',
  'details': 'Độ ẩm đất thấp, nên bật bơm (ActuatorId: $_guid) trong 5 phút.',
  'isActionable': true,
  'proposedAction': 'TurnOn',
  'proposedDurationSeconds': 300,
  'confidence': 0.9,
  'status': status,
  'validUntilUtc': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
  'createdAtUtc': '2026-11-14T01:00:00Z',
  'limitations': ['Chỉ có một trạm đo'],
  'sources': [
    {
      'title': 'TCVN 11892-1',
      'standardCode': 'TCVN 11892-1:2017',
      'similarity': 0.82,
      'contentSnippet': 'Tưới đủ ẩm theo giai đoạn sinh trưởng.',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final posts = <Map<String, dynamic>>[];
  var history = <Map<String, dynamic>>[];
  var applyCode = 200;
  var applyCommandStatus = 'Sent';
  var logStatus = 'Acknowledged';
  var askBody = <String, dynamic>{
    'recommendationId': 'r2',
    'summary': 'Trời nắng, giữ lịch tưới hiện tại.',
    'isActionable': false,
  };
  var askCode = 201;

  Future<http.Response> handler(http.Request r) async {
    final p = r.url.path;
    if (p == '/api/v1/zones/z1/ai/context') {
      return _json({
        'zoneName': 'Zone 1',
        'cropName': 'Cà chua',
        'growthStageName': 'Ra hoa',
        'seasonAgeDays': 12,
        'telemetry': [
          {
            'parameterCode': 'SoilMoisture',
            'value': 41.5,
            'unit': '%',
            'isFresh': true,
          },
        ],
        'requirements': [
          {'parameterCode': 'SoilMoisture', 'minValue': 60, 'maxValue': 80},
        ],
        'weather': {
          'available': true,
          'rainProbabilityNext6HoursMaxPercent': 20,
        },
      });
    }
    if (p == '/api/v1/zones/z1/ai/history' && r.method == 'GET') {
      return _json(history);
    }
    if (p == '/api/v1/zones/z1/ai/ask') {
      posts.add({'path': p, ...jsonDecode(r.body) as Map<String, dynamic>});
      if (askCode != 201)
        return _json({'detail': 'AI tạm thời quá tải.'}, askCode);
      return _json(askBody, askCode);
    }
    if (p == '/api/v1/zones/z1/ai/apply-recommendation') {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      posts.add({'path': p, ...b});
      if (applyCode == 409) {
        return _json({'detail': 'Độ ẩm đất đang cao, không nên tưới.'}, 409);
      }
      if (b['decision'] == 'Rejected') return _json({'status': 'Rejected'});
      return _json({
        'command': {'commandId': 'c1', 'status': applyCommandStatus},
      }, 202);
    }
    if (p == '/api/v1/zones/z1/actuators/history') {
      return _json({
        'commands': [
          {'commandId': 'c1', 'status': logStatus},
        ],
      });
    }
    return http.Response('', 404);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'o@b.c',
      role: 'FarmOwner',
    );
    // Khởi tạo trạng thái đăng nhập của ApiService trong vùng MockClient như các test khác.
    await http.runWithClient(
      () => AiApi.getAiContext('z1'),
      () => MockClient(handler),
    );
  });

  setUp(() {
    posts.clear();
    history = [_rec()];
    applyCode = 200;
    applyCommandStatus = 'Sent';
    logStatus = 'Acknowledged';
    askCode = 201;
  });

  FarmProvider provider() {
    final p = FarmProvider();
    p.switchRole('OWNER');
    p.setSelectedFarmIdForTesting('f1');
    p.setZonesForTesting([
      ZoneModel(
        zoneId: 'z1',
        farmId: 'f1',
        farmName: 'Trại A',
        name: 'Zone 1',
        currentCrop: 'Cà chua',
        currentStage: 'Ra hoa',
        areaM2: 100,
        currentSoilMoisture: 40,
        currentTemp: 25,
        currentHumidity: 60,
        currentLux: 0,
      ),
    ]);
    return p;
  }

  Future<void> run(
    WidgetTester t,
    Future<void> Function(FarmProvider p) body, {
    Size size = const Size(500, 2600),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final p = provider();
    await http.runWithClient(() async {
      await t.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: p,
          child: const MaterialApp(home: AiAssistantScreen()),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      await body(p);
      // Gỡ widget để hủy Timer định kỳ/poll trước khi kết thúc test.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 6));
    }, () => MockClient(handler));
    p.dispose();
  }

  test('cleanTechnicalIds bỏ GUID kỹ thuật khỏi câu trả lời', () {
    expect(
      cleanTechnicalIds('Bật bơm (ActuatorId: $_guid) trong 5 phút.'),
      'Bật bơm trong 5 phút.',
    );
    expect(cleanTechnicalIds(null), '');
  });

  testWidgets(
    'cửa sổ rộng 353 và rất thấp (633/565/480px như log web): không tràn',
    (t) async {
      for (final h in [633.0, 565.0, 480.0]) {
        await run(t, (p) async {
          expect(t.takeException(), isNull, reason: 'cao ${h}px');
        }, size: Size(353, h + 56));
      }
    },
  );

  testWidgets('cửa sổ thấp (621px): ẩn gợi ý nhanh, khung chat không bị tràn', (
    t,
  ) async {
    await run(t, (p) async {
      expect(t.takeException(), isNull);
      expect(find.text('🌤️ Thời tiết'), findsNothing);
    }, size: const Size(400, 621));
  });

  testWidgets('lịch sử: thẻ đề xuất, hàng đợi và nút duyệt như web', (t) async {
    await run(t, (p) async {
      expect(find.text('Trợ lý AI Nông học'), findsOneWidget);
      expect(find.textContaining('Cà chua • Ra hoa (Ngày 12)'), findsOneWidget);
      expect(find.text('Có cần tưới không?'), findsOneWidget);
      expect(find.text('ĐỀ XUẤT GIẢI PHÁP'), findsOneWidget);
      expect(find.text('90% Tin cậy'), findsOneWidget);
      expect(find.text('Bật máy bơm tưới nước'), findsOneWidget);
      expect(find.textContaining('5 phút (300s)'), findsOneWidget);
      expect(find.text('Bỏ qua'), findsOneWidget);
      expect(find.text('Duyệt bật bơm (5p)'), findsOneWidget);
      // Mã GUID kỹ thuật bị loại khỏi nội dung hiển thị.
      expect(find.textContaining(_guid), findsNothing);
      // Hàng đợi có 1 khuyến nghị.
      expect(find.text('Hàng đợi Duyệt Khuyến nghị'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      // Gợi ý nhanh luôn hiện.
      expect(find.text('Gợi ý nhanh:'), findsOneWidget);
      expect(find.textContaining('Nhu cầu tưới'), findsOneWidget);
    });
  });

  testWidgets('bỏ qua: gửi Rejected kèm lý do, thẻ chuyển sang đã từ chối', (
    t,
  ) async {
    await run(t, (p) async {
      await t.tap(find.text('Bỏ qua'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final body = posts.firstWhere((x) => x['decision'] == 'Rejected');
      expect(body['recommendationId'], 'r1');
      expect(body['reason'], 'Từ chối bởi chủ trang trại');
      expect(find.text('Đã từ chối khuyến nghị'), findsOneWidget);
      expect(find.text('Duyệt bật bơm (5p)'), findsNothing);
    });
  });

  testWidgets(
    'duyệt: hiện trạng thái lệnh thật, sau đó cập nhật từ nhật ký thiết bị',
    (t) async {
      await run(t, (p) async {
        await t.tap(find.text('Duyệt bật bơm (5p)'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(
          posts.any(
            (x) => x['decision'] == 'Accepted' && x['recommendationId'] == 'r1',
          ),
          isTrue,
        );
        expect(find.text('Đã gửi lệnh, chờ thiết bị xác nhận'), findsOneWidget);
        // Sau 2,5 giây hỏi lại nhật ký lệnh: thiết bị xác nhận.
        await t.pump(const Duration(milliseconds: 2600));
        await t.pump(const Duration(milliseconds: 50));
        expect(find.text('Thiết bị đã xác nhận lệnh'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'duyệt bị chặn an toàn (409): báo lý do thật, không báo đã chạy',
    (t) async {
      applyCode = 409;
      await run(t, (p) async {
        await t.tap(find.text('Duyệt bật bơm (5p)'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        expect(
          find.textContaining('Hệ thống từ chối: Độ ẩm đất đang cao'),
          findsOneWidget,
        );
        expect(find.text('Thiết bị đã xác nhận lệnh'), findsNothing);
      });
    },
  );

  testWidgets(
    'khuyến nghị đã duyệt trong lịch sử: không khẳng định thiết bị đã chạy',
    (t) async {
      history = [_rec(status: 'Accepted')];
      await run(t, (p) async {
        expect(find.text('Đã duyệt; chưa tải trạng thái lệnh'), findsOneWidget);
        expect(find.text('Duyệt bật bơm (5p)'), findsNothing);
        // Đã quyết định nên không còn trong hàng đợi.
        expect(find.text('1'), findsNothing);
      });
    },
  );

  testWidgets('gợi ý nhanh gửi câu hỏi đầy đủ; lỗi backend hiện đúng lý do', (
    t,
  ) async {
    await run(t, (p) async {
      await t.ensureVisible(find.text('🌤️ Thời tiết'));
      await t.tap(find.text('🌤️ Thời tiết'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      final q = posts.firstWhere((x) => x['path'] == '/api/v1/zones/z1/ai/ask');
      expect(
        q['question'],
        'Thời tiết dự báo tiếp theo có thích hợp cho sự phát triển của cây không?',
      );
      expect(find.textContaining('giữ lịch tưới hiện tại'), findsOneWidget);

      askCode = 503;
      await t.ensureVisible(find.text('⏰ Lịch tưới'));
      await t.tap(find.text('⏰ Lịch tưới'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('AI tạm thời quá tải.'), findsOneWidget);
    });
  });

  testWidgets('tài liệu VietGAP tham chiếu mở ra trích đoạn', (t) async {
    await run(t, (p) async {
      expect(find.text('Tài liệu VietGAP tham chiếu (1):'), findsOneWidget);
      await t.tap(find.text('Tài liệu VietGAP tham chiếu (1):'));
      await t.pump();
      expect(find.text('TCVN 11892-1:2017'), findsOneWidget);
      expect(find.text('82% khớp'), findsOneWidget);
      await t.tap(find.text('Xem trích đoạn tri thức'));
      await t.pump();
      expect(
        find.text('Tưới đủ ẩm theo giai đoạn sinh trưởng.'),
        findsOneWidget,
      );
    });
  });
  testWidgets(
    'màn hình hẹp 320px không tràn bố cục (kể cả khi mở hết các khối)',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = provider();
      await http.runWithClient(() async {
        await t.pumpWidget(
          ChangeNotifierProvider<FarmProvider>.value(
            value: p,
            child: const MaterialApp(home: AiAssistantScreen()),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        await t.tap(find.text('Hàng đợi Duyệt Khuyến nghị'));
        await t.pump();
        await t.tap(find.textContaining('thông số vi khí hậu'));
        await t.pump();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 6));
      }, () => MockClient(handler));
      p.dispose();
    },
  );
  testWidgets(
    'hàng đợi rỗng khi mở: thẻ thông báo gọn theo nội dung, không giãn hết 40% chiều cao',
    (t) async {
      history = [];
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = provider();
      await http.runWithClient(() async {
        await t.pumpWidget(
          ChangeNotifierProvider<FarmProvider>.value(
            value: p,
            child: const MaterialApp(home: AiAssistantScreen()),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));
        await t.tap(find.text('Hàng đợi Duyệt Khuyến nghị'));
        await t.pump();
        final card = find.ancestor(
          of: find.text('Chưa có khuyến nghị mới cần duyệt'),
          matching: find.byType(Container),
        );
        expect(t.getSize(card.first).height, lessThan(250));
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 6));
      }, () => MockClient(handler));
      p.dispose();
    },
  );
  testWidgets(
    'vùng chạm: mọi nút thao tác cao tối thiểu 44dp, chữ không nhỏ hơn 11',
    (t) async {
      await run(t, (p) async {
        Size sz(Finder f) => t.getSize(f.first);
        expect(
          sz(find.widgetWithText(OutlinedButton, 'Bỏ qua')).height,
          greaterThanOrEqualTo(44),
        );
        expect(
          sz(find.widgetWithText(FilledButton, 'Duyệt bật bơm (5p)')).height,
          greaterThanOrEqualTo(44),
        );
        expect(sz(find.byType(ActionChip)).height, greaterThanOrEqualTo(44));
        for (final label in [
          'Hàng đợi Duyệt Khuyến nghị',
          'Tài liệu VietGAP tham chiếu (1):',
        ]) {
          final tile = find.ancestor(
            of: find.text(label),
            matching: find.byType(InkWell),
          );
          expect(sz(tile).height, greaterThanOrEqualTo(40), reason: label);
        }
        // Không còn chữ nhỏ hơn 11 trong màn hình.
        for (final w in t.widgetList<Text>(find.byType(Text))) {
          final size = w.style?.fontSize;
          if (size != null)
            expect(size, greaterThanOrEqualTo(11), reason: w.data);
        }
      });
    },
  );
}
