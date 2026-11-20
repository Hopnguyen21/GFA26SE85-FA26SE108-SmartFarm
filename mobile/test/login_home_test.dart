import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/auth/landing_screen.dart';
import 'package:smartfarm_mobile/features/auth/login_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var loginCode = 200;
  Object loginBody = {};
  final loginPosts = <Map<String, dynamic>>[];

  Future<http.Response> handler(http.Request r) async {
    if (r.url.path == '/api/v1/auth/login') {
      loginPosts.add(jsonDecode(r.body) as Map<String, dynamic>);
      return _json(loginBody, loginCode);
    }
    if (r.url.path == '/api/v1/platform/business-parameters') {
      return _json({
        'depositPercent': 30,
        'rainGuardThresholdPercent': 70,
        'repeatPurchaseDiscountPercent': 15,
        'renewalDiscountPercent': 10,
      });
    }
    return http.Response('', 404);
  }

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    // Gắn MockClient cho ApiService (client được tạo trong vùng chạy này).
    await http.runWithClient(
      () => ApiService.login('x@x.x', 'x'),
      () => MockClient(handler),
    );
  });

  setUp(() {
    loginCode = 200;
    loginBody = {};
    loginPosts.clear();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLogin(
    WidgetTester tester, {
    String? initialEmail,
    String? initialMessage,
    VoidCallback? onSuccess,
  }) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onLoginSuccess: onSuccess ?? () {},
            initialEmail: initialEmail,
            initialMessage: initialMessage,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  testWidgets('đăng nhập: bố cục và chữ như web', (tester) async {
    await pumpLogin(tester);
    expect(find.text('SmartFarm SaaS'), findsOneWidget);
    expect(
      find.text('Nền tảng Quản lý Nông nghiệp Thông minh Tích hợp AI'),
      findsOneWidget,
    );
    expect(find.text('Đăng nhập Hệ thống'), findsOneWidget);
    expect(
      find.text('Nhập tài khoản của bạn để truy cập Workspace'),
      findsOneWidget,
    );
    expect(find.text('Email / Tên đăng nhập'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Ghi nhớ'), findsOneWidget);
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.text('Đăng ký?'), findsOneWidget);
    expect(find.text('Đăng ký ngay'), findsOneWidget);
    expect(find.text('Đăng nhập ngay'), findsOneWidget);
  });

  testWidgets(
    'sau đăng ký: điền sẵn email, mật khẩu trống và hiện thông báo thành công',
    (tester) async {
      await pumpLogin(
        tester,
        initialEmail: 'moi@trangtrai.vn',
        initialMessage:
            'Đăng ký tài khoản thành công! Hãy nhập mật khẩu của bạn để đăng nhập.',
      );
      expect(find.text('moi@trangtrai.vn'), findsOneWidget);
      expect(
        find.textContaining('Đăng ký tài khoản thành công!'),
        findsOneWidget,
      );
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[1].controller!.text, isEmpty);
    },
  );

  testWidgets('thiếu email hoặc mật khẩu: báo lỗi, không gọi API', (
    tester,
  ) async {
    await pumpLogin(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), '');
    await tester.tap(find.text('Đăng nhập ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập email và mật khẩu.'), findsOneWidget);
    expect(loginPosts, isEmpty);
  });

  testWidgets(
    'đăng nhập sai: hiện đúng lý do backend trả (như web), không phải câu chung',
    (tester) async {
      loginCode = 401;
      loginBody = {
        'title': 'Unauthorized',
        'detail': 'Tài khoản tạm khóa 15 phút do đăng nhập sai nhiều lần.',
      };
      await pumpLogin(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'a@b.vn');
      await tester.enterText(fields.at(1), 'sai-mat-khau');
      await http.runWithClient(() async {
        await tester.tap(find.text('Đăng nhập ngay'));
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      expect(
        find.text('Tài khoản tạm khóa 15 phút do đăng nhập sai nhiều lần.'),
        findsOneWidget,
      );
      expect(loginPosts.single['email'], 'a@b.vn');
    },
  );

  testWidgets('đăng nhập sai không kèm lý do: câu mặc định như web', (
    tester,
  ) async {
    loginCode = 401;
    loginBody = {'title': 'Unauthorized'};
    await pumpLogin(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'a@b.vn');
    await tester.enterText(fields.at(1), 'x');
    await http.runWithClient(() async {
      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
    expect(
      find.text('Đăng nhập thất bại. Vui lòng kiểm tra email và mật khẩu.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'đăng nhập thành công: gọi onLoginSuccess; "Ghi nhớ" chỉ nhớ email, không lưu mật khẩu',
    (tester) async {
      loginBody = {
        'accessToken': 'a',
        'refreshToken': 'r',
        'user': {'role': 'FarmOwner'},
      };
      var ok = 0;
      await pumpLogin(tester, onSuccess: () => ok++);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'chu@trai.vn');
      await tester.enterText(fields.at(1), 'MatKhau#1');
      await http.runWithClient(() async {
        await tester.tap(find.text('Đăng nhập ngay'));
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      expect(ok, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('login_remembered_email'), 'chu@trai.vn');
      expect(
        prefs.getKeys().any(
          (k) => (prefs.get(k) ?? '').toString().contains('MatKhau#1'),
        ),
        isFalse,
      );
    },
  );

  testWidgets('bỏ tích "Ghi nhớ": không lưu email', (tester) async {
    loginBody = {
      'accessToken': 'a',
      'refreshToken': 'r',
      'user': {'role': 'FarmOwner'},
    };
    await pumpLogin(tester);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'chu@trai.vn');
    await tester.enterText(fields.at(1), 'MatKhau#1');
    await http.runWithClient(() async {
      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('login_remembered_email'), isNull);
  });

  testWidgets('email đã ghi nhớ được điền sẵn lần sau', (tester) async {
    SharedPreferences.setMockInitialValues({
      'login_remembered_email': 'cu@trai.vn',
    });
    await pumpLogin(tester);
    expect(find.text('cu@trai.vn'), findsOneWidget);
  });

  group('trang chủ theo web', () {
    Future<void> pumpHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(home: LandingScreen(onLoginSuccess: () {})),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }, () => MockClient(handler));
    }

    testWidgets('hero, dải chỉ số và hệ sinh thái đủ nội dung như web', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(
        find.text('HỆ THỐNG QUẢN TRỊ NÔNG NGHIỆP THÔNG MINH SỐ 1'),
        findsOneWidget,
      );
      expect(find.textContaining('Kiến tạo Nông trang số'), findsOneWidget);
      expect(find.text('Yêu cầu tư vấn thiết bị'), findsOneWidget);
      expect(find.text('500+'), findsOneWidget);
      expect(find.text('-35%'), findsOneWidget);
      expect(
        find.text('Mọi công cụ cần thiết cho Nhà vườn số hóa'),
        findsOneWidget,
      );
    });

    testWidgets(
      'thanh điều hướng cuộn tới mục tương ứng (như liên kết neo web)',
      (tester) async {
        await pumpHome(tester);
        final target = find.text('Đồng hành cùng nền Nông nghiệp Bền vững');
        // Chưa cuộn tới thì chưa nhìn thấy mục khách hàng.
        expect(target.hitTestable(), findsNothing);
        final chip = find.widgetWithText(ActionChip, 'Khách hàng');
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
      },
    );

    testWidgets('nút "Đăng ký" trên đầu trang mở màn đăng ký', (tester) async {
      await pumpHome(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Họ và tên (*)'), findsOneWidget);
    });

    testWidgets('tư vấn: gửi xong hiện xác nhận rồi tự đóng sau 2,5 giây', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text('Yêu cầu tư vấn thiết bị'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng ký Tư vấn & Khảo sát Thực địa'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Nguyễn Văn Nam');
      await tester.enterText(fields.at(1), '0988123456');
      await tester.tap(find.text('Xác nhận gửi thông tin khảo sát'));
      await tester.pump();
      expect(find.text('Gửi thông tin thành công!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();
      // dispose_later giải phóng ô nhập sau một nhịp nghỉ: xả hết bộ hẹn giờ trước khi kết thúc test.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Gửi thông tin thành công!'), findsNothing);
    });

    testWidgets('tư vấn: thiếu họ tên hoặc số điện thoại thì không gửi', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text('Yêu cầu tư vấn thiết bị'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận gửi thông tin khảo sát'));
      await tester.pump();
      expect(
        find.text('Vui lòng điền họ tên và số điện thoại'),
        findsOneWidget,
      );
      expect(find.text('Gửi thông tin thành công!'), findsNothing);
    });
  });
}
