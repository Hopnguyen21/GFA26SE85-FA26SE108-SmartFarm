import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/support_requests_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

ZoneModel _zone() => ZoneModel(
  zoneId: 'z1',
  farmId: 'f1',
  farmName: 'Trại A',
  name: 'Zone 1',
  currentCrop: '',
  currentStage: '',
  areaM2: 100,
  currentSoilMoisture: 0,
  currentTemp: 0,
  currentHumidity: 0,
  currentLux: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var quote = 'SentToOwner';
  var depStatus = 'Surveyed';
  var quoteHttp = 200;
  var signHttp = 200;

  final signPosts = <http.Request>[];

  Future<http.Response> handler(http.Request r) async {
    final p = r.url.path;
    if (r.method == 'POST' && p.endsWith('/sign-contract-deposit')) {
      if (signHttp != 200)
        return _json({
          'detail': 'Quotation is not awaiting Owner signature.',
        }, signHttp);
      signPosts.add(r);
      quote = 'SignedByOwner';
      return _json({
        'id': 'pay1',
        'paymentStage': 'DEPOSIT_30',
        'amount': 3596400,
        'paymentMethod': 'CASH',
        'signerFullName': 'Lê Văn An',
        'status': 'Confirmed',
        'paidAtUtc': '2026-11-13T07:00:00Z',
      });
    }
    if (r.method == 'POST' && p.endsWith('/sign-acceptance-final')) {
      signPosts.add(r);
      quote = 'Completed';
      return _json({
        'id': 'pay2',
        'paymentStage': 'FINAL_70',
        'amount': 8391600,
        'paymentMethod': 'BANK_TRANSFER',
        'signerFullName': 'Chủ Trang Trại',
        'status': 'Confirmed',
        'paidAtUtc': '2026-11-14T07:00:00Z',
      });
    }
    if (p == '/api/v1/service-requests/s1') {
      return _json({
        'id': 's1',
        'status': 'Assigned',
        'farmId': 'f1',
        'zoneId': 'z1',
        'deploymentRequestId': 'dep1',
        'history': <Object>[],
      });
    }
    if (p == '/api/v1/service-requests') {
      return _json([
        {
          'id': 's1',
          'failureCode': 'NEW_INSTALL',
          'status': 'Assigned',
          'description': 'Khảo sát và lắp đặt IoT.',
          'farmId': 'f1',
          'zoneId': 'z1',
          'deploymentRequestId': 'dep1',
          'history': <Object>[],
        },
        {
          'id': 's2',
          'failureCode': 'NEW_INSTALL',
          'status': 'Assigned',
          'description': 'Của Zone khác.',
          'farmId': 'f1',
          'zoneId': 'z-other',
          'deploymentRequestId': 'dep2',
          'history': <Object>[],
        },
      ]);
    }
    if (p == '/api/v1/service-requests/s1/quotation') {
      if (quoteHttp != 200) return _json({'detail': 'boom'}, 500);
      return _json({
        'id': 'q1',
        'status': quote,
        'totalAmount': 11988000,
        'deposit30Percent': 3596400,
        'remaining70Percent': 8391600,
        'items': <Object>[],
      });
    }
    if (p.endsWith('/deployment-requests/dep1')) {
      return _json({
        'requestId': 'dep1',
        'farmId': 'f1',
        'zoneId': 'z1',
        'status': depStatus,
        'requiredParameters': <Object>[],
        'planItems': <Object>[],
        'surveys': <Object>[],
        'decisionHistory': <Object>[],
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
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient(handler),
    );
  });

  setUp(() {
    quote = 'SentToOwner';
    depStatus = 'Surveyed';
    quoteHttp = 200;
    signHttp = 200;
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(const SizedBox()); // bỏ State cũ để tải lại dữ liệu
    tester.view.physicalSize = const Size(
      900,
      1600,
    ); // rộng hơn vì phông Ahem của test rộng hơn phông thật
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  testWidgets(
    'dải thông báo trên Zone: hợp đồng đã gửi thì báo Owner ký và cọc 30%',
    (tester) async {
      await pump(tester, ZonePendingActionsBanner(zone: _zone()));
      expect(
        find.text('Cần bạn: ký hợp đồng và thanh toán cọc 30%'),
        findsOneWidget,
      );
      expect(find.text('Xem hợp đồng'), findsOneWidget);
    },
  );

  testWidgets(
    'dải thông báo: chỉ tính phiếu của Zone này; chưa có hợp đồng thì không báo',
    (tester) async {
      quote = 'Draft';
      await pump(tester, ZonePendingActionsBanner(zone: _zone()));
      expect(find.byIcon(Icons.notifications_active), findsNothing);
    },
  );

  testWidgets(
    'đã cọc, triển khai chưa xong: không báo việc cho Owner; KTV hoàn tất thì báo nghiệm thu 70%',
    (tester) async {
      quote = 'SignedByOwner';
      depStatus = 'Installing';
      await pump(tester, ZonePendingActionsBanner(zone: _zone()));
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      depStatus = 'Completed';
      await pump(tester, ZonePendingActionsBanner(zone: _zone()));
      expect(
        find.text('Cần bạn: ký nghiệm thu và thanh toán 70%'),
        findsOneWidget,
      );
    },
  );

  testWidgets('lỗi đọc hợp đồng: không báo gì (không đoán)', (tester) async {
    quoteHttp = 500;
    await pump(tester, ZonePendingActionsBanner(zone: _zone()));
    expect(find.byIcon(Icons.notifications_active), findsNothing);
  });

  testWidgets(
    'thẻ yêu cầu của Owner: trạng thái tiếng Việt, hợp đồng và việc chờ Owner; bấm mở chi tiết hợp đồng',
    (tester) async {
      await pump(
        tester,
        OwnerRequestCard(
          request: const {
            'id': 's1',
            'failureCode': 'NEW_INSTALL',
            'status': 'Assigned',
            'description': 'Khảo sát và lắp đặt IoT.',
            'farmId': 'f1',
            'zoneId': 'z1',
            'deploymentRequestId': 'dep1',
            'history': <Object>[],
          },
          zoneName: 'Zone 1 · Trại A',
          zone: _zone(),
        ),
      );
      expect(
        find.text('Assigned'),
        findsNothing,
      ); // không còn trạng thái tiếng Anh thô
      expect(find.text('Lắp đặt thiết bị mới'), findsOneWidget);
      expect(find.textContaining('Tổng HĐ: '), findsOneWidget);
      expect(find.textContaining('bấm để xem hợp đồng'), findsOneWidget);
      await http.runWithClient(() async {
        await tester.tap(find.textContaining('bấm để xem hợp đồng'));
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      // Luồng như web: Mục 1 (cọc 30%) có form ký ngay trong màn; Mục 2 khóa cho đến khi cọc.
      expect(
        find.textContaining(
          '1. Hợp đồng Báo giá Thiết bị & Thanh toán Tạm ứng 30%',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '2. Biên bản Nghiệm thu Công trình & Thanh toán 70%',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Đang khóa: cần ký hợp đồng'), findsOneWidget);
      final signBtn = find.textContaining('KÝ HỢP ĐỒNG & THANH TOÁN 30% CỌC');
      await tester.ensureVisible(signBtn);
      await tester.pumpAndSettle();
      // Chưa tích đồng ý điều khoản thì nút bị khóa.
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(of: signBtn, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('COC30 #'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiền mặt'));
      await tester.pumpAndSettle();
      expect(find.textContaining('COC30 #'), findsNothing);
      signPosts.clear();
      await http.runWithClient(() async {
        await tester.enterText(find.byType(TextField).first, 'Lê Văn An');
        await tester.tap(signBtn);
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      expect(signPosts, hasLength(1));
      final body = jsonDecode(signPosts.single.body) as Map<String, dynamic>;
      expect(body['paymentMethod'], 'CASH');
      expect(body['transactionReference'], matches(RegExp(r'^PAY30-\d{14}$')));
      expect(body['signerFullName'], 'Lê Văn An');
      // Biên lai hiện sau khi ghi nhận.
      expect(
        find.text('Biên lai Xác nhận Giao dịch Thanh toán'),
        findsOneWidget,
      );
      expect(find.textContaining('Tiền mặt'), findsWidgets);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      // Trạng thái lấy lại từ backend: Mục 1 đã khóa, Mục 2 chờ KTV hoàn tất lắp đặt.
      expect(
        find.textContaining('Đã ký hợp đồng và thanh toán tạm ứng 30%'),
        findsWidgets,
      );
      expect(
        find.textContaining('Đang chờ kỹ thuật viên hoàn tất lắp đặt'),
        findsOneWidget,
      );
      expect(find.text('Xem biên lai'), findsOneWidget);
    },
  );

  testWidgets(
    'nghiệm thu: Mục 2 chỉ mở khi triển khai Completed backend; ký → POST 70% + biên lai + hoàn tất',
    (tester) async {
      quote = 'SignedByOwner';
      depStatus = 'Installing';
      const req = {
        'id': 's1',
        'failureCode': 'NEW_INSTALL',
        'status': 'Assigned',
        'description': 'x',
        'farmId': 'f1',
        'zoneId': 'z1',
        'deploymentRequestId': 'dep1',
        'history': <Object>[],
      };
      Future<void> open() async {
        await pump(
          tester,
          const QuotationPanel(
            serviceRequestId: 's1',
            deploymentRequestId: 'dep1',
          ),
        );
      }

      await open();
      final btn = find.textContaining(
        'KÝ BÀN GIAO NGHIỆM THU & THANH TOÁN 70%',
      );
      expect(
        find.textContaining('Đang chờ kỹ thuật viên hoàn tất'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(of: btn, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNull,
      );
      expect(req['id'], 's1');

      depStatus = 'Completed';
      await open();
      signPosts.clear();
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await http.runWithClient(() async {
        await tester.tap(btn);
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      expect(signPosts, hasLength(1));
      final body = jsonDecode(signPosts.single.body) as Map<String, dynamic>;
      expect(body['paymentMethod'], 'BANK_TRANSFER');
      expect(body['transactionReference'], matches(RegExp(r'^PAY70-\d{14}$')));
      expect(
        find.text('Biên lai Xác nhận Giao dịch Thanh toán'),
        findsOneWidget,
      );
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hợp đồng hoàn tất 100%'), findsWidgets);
    },
  );

  testWidgets(
    'ký cọc bị backend từ chối (409): hiện lỗi, không biên lai, vẫn chưa ký',
    (tester) async {
      signHttp = 409;
      await pump(
        tester,
        const QuotationPanel(
          serviceRequestId: 's1',
          deploymentRequestId: 'dep1',
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final btn = find.textContaining('KÝ HỢP ĐỒNG & THANH TOÁN 30% CỌC');
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await http.runWithClient(() async {
        await tester.tap(btn);
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      expect(find.textContaining('Không ghi nhận được'), findsOneWidget);
      expect(find.text('Biên lai Xác nhận Giao dịch Thanh toán'), findsNothing);
      expect(find.text('Xem biên lai'), findsNothing);
      expect(find.textContaining('Đang khóa: cần ký hợp đồng'), findsOneWidget);
    },
  );
}
