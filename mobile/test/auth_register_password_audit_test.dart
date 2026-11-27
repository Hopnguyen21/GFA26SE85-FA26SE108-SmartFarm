import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/utils/export_utils.dart';
import 'package:smartfarm_mobile/features/auth/password_screens.dart';
import 'package:smartfarm_mobile/features/auth/register_screen.dart';

http.Response Function(http.Request) handler = (_) => http.Response('{}', 200);
final calls = <http.Request>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    // _client là static lazy: khởi tạo lần đầu bên trong runWithClient để dùng MockClient.
    handler = (_) => http.Response('{}', 200);
    await http.runWithClient(
      () => ApiService.login('setup@farm.vn', 'pass'),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() async {
    calls.clear();
    handler = (_) => http.Response('{}', 200);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 'mock_jwt_token',
      refreshToken: 'mock_refresh_token',
      email: 'owner@farm.vn',
      role: 'FarmOwner',
    );
  });

  void setScreenSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1.0;
  }

  group('A. Pure Password Validators Audit', () {
    test('validateNewPassword basic rule (>=8 chars, letters and digits)', () {
      expect(validateNewPassword('short'), isNotNull);
      expect(validateNewPassword('12345678'), isNotNull); // missing letter
      expect(validateNewPassword('abcdefgh'), isNotNull); // missing digit
      expect(validateNewPassword('Abcdef12'), isNull);
    });

    test('validateStrongPassword matches Backend .NET policy', () {
      expect(validateStrongPassword('short'), contains('ít nhất 8 ký tự'));
      expect(validateStrongPassword('abcdef123!'), contains('chữ in hoa'));
      expect(validateStrongPassword('ABCDEF123!'), contains('chữ in thường'));
      expect(validateStrongPassword('Abcdefgh!'), contains('chữ số'));
      expect(validateStrongPassword('Abcdef1234'), contains('ký tự đặc biệt'));
      expect(validateStrongPassword('ValidPassword123!'), isNull);
      expect(validateStrongPassword('MatKhau#123'), isNull);
    });
  });

  group('B. RegisterScreen Audit', () {
    testWidgets('Validation: blocks empty fields', (tester) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Đăng Ký Tài Khoản'),
      );
      await tester.pump();
      expect(find.textContaining('Vui lòng điền đầy đủ'), findsOneWidget);
    });

    testWidgets('Validation: blocks invalid email', (tester) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Nguyễn Văn A'); // Name field
      await tester.enterText(fields.at(1), 'not-an-email'); // Email field
      await tester.enterText(fields.at(3), 'ValidPass123!'); // Pass field
      await tester.enterText(fields.at(4), 'ValidPass123!'); // Confirm field
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Đăng Ký Tài Khoản'),
      );
      await tester.pump();
      expect(find.textContaining('Email không hợp lệ'), findsOneWidget);
    });

    testWidgets('Validation: blocks weak password', (tester) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Nguyễn Văn A');
      await tester.enterText(fields.at(1), 'test@smartfarm.vn');
      await tester.enterText(fields.at(3), 'weakpass');
      await tester.enterText(fields.at(4), 'weakpass');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Đăng Ký Tài Khoản'),
      );
      await tester.pump();
      expect(find.textContaining('chữ in hoa'), findsOneWidget);
    });

    testWidgets('Validation: blocks password mismatch', (tester) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Nguyễn Văn A');
      await tester.enterText(fields.at(1), 'test@smartfarm.vn');
      await tester.enterText(fields.at(3), 'ValidPass123!');
      await tester.enterText(fields.at(4), 'DifferentPass123!');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Đăng Ký Tài Khoản'),
      );
      await tester.pump();
      expect(
        find.textContaining('Mật khẩu xác nhận không khớp'),
        findsOneWidget,
      );
    });

    testWidgets('Validation: blocks invalid phone', (tester) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Nguyễn Văn A');
      await tester.enterText(fields.at(1), 'test@smartfarm.vn');
      await tester.enterText(fields.at(2), '1234'); // too short phone
      await tester.enterText(fields.at(3), 'ValidPass123!');
      await tester.enterText(fields.at(4), 'ValidPass123!');
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Đăng Ký Tài Khoản'),
      );
      await tester.pump();
      expect(find.textContaining('Số điện thoại không hợp lệ'), findsOneWidget);
    });

    testWidgets('Successful registration sends full DTO and returns email', (
      tester,
    ) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      handler = (request) {
        if (request.url.path == '/api/v1/auth/register') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'userId': '11111111-1111-1111-1111-111111111111',
              'email': body['email'],
              'fullName': body['fullName'],
              'role': body['role'],
              'status': 'Active',
            }),
            201,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('', 404);
      };

      String? returnedEmail;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                returnedEmail = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Trần Thị Chủ');
      await tester.enterText(fields.at(1), 'chu@farm.vn');
      await tester.enterText(fields.at(2), '0901234567');
      await tester.enterText(fields.at(3), 'MatKhau#123');
      await tester.enterText(fields.at(4), 'MatKhau#123');

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Đăng Ký Tài Khoản'),
      );
      await tester.pumpAndSettle();

      final regCall = calls.firstWhere(
        (c) => c.url.path == '/api/v1/auth/register',
      );
      final sentBody = jsonDecode(regCall.body) as Map<String, dynamic>;

      expect(sentBody['email'], 'chu@farm.vn');
      expect(sentBody['fullName'], 'Trần Thị Chủ');
      expect(sentBody['phone'], '0901234567');
      expect(sentBody['password'], 'MatKhau#123');
      expect(sentBody['role'], 'Farmer');
      expect(returnedEmail, 'chu@farm.vn');
    });
  });

  group('C. Forgot & Reset Password Audit', () {
    testWidgets('Forgot password: sends OTP request to backend', (
      tester,
    ) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      handler = (request) {
        if (request.url.path == '/api/v1/auth/forgot-password') {
          return http.Response(
            jsonEncode({
              'message': 'Mã OTP đã được gửi.',
              'otp': '654321',
              'expiresAtUtc': DateTime.now()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('', 404);
      };

      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.enterText(find.byType(TextField).first, 'user@farm.vn');
      await tester.tap(find.widgetWithText(FilledButton, 'Gửi mã xác nhận'));
      await tester.pumpAndSettle();

      final forgotCall = calls.firstWhere(
        (c) => c.url.path == '/api/v1/auth/forgot-password',
      );
      final body = jsonDecode(forgotCall.body) as Map<String, dynamic>;

      expect(body['email'], 'user@farm.vn');
      expect(find.textContaining('mã xác nhận đã được gửi'), findsOneWidget);
    });

    testWidgets(
      'Reset password: sends otp and token to POST /api/v1/auth/reset-password',
      (tester) async {
        setScreenSize(tester);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        handler = (request) {
          if (request.url.path == '/api/v1/auth/forgot-password') {
            return http.Response(jsonEncode({'message': 'OTP sent'}), 200);
          }
          if (request.url.path == '/api/v1/auth/reset-password') {
            return http.Response(
              jsonEncode({'message': 'Đặt lại mật khẩu thành công!'}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('', 404);
        };

        await tester.pumpWidget(
          const MaterialApp(home: ForgotPasswordScreen()),
        );
        // Step 1: Send OTP
        await tester.enterText(find.byType(TextField).first, 'user@farm.vn');
        await tester.tap(find.widgetWithText(FilledButton, 'Gửi mã xác nhận'));
        await tester.pumpAndSettle();

        // Step 2: Reset Password
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(1), '123456'); // OTP token
        await tester.enterText(fields.at(2), 'NewPass#123'); // New password
        await tester.enterText(fields.at(3), 'NewPass#123'); // Confirm
        await tester.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
        await tester.pumpAndSettle();

        final resetCall = calls.firstWhere(
          (c) => c.url.path == '/api/v1/auth/reset-password',
        );
        final resetBody = jsonDecode(resetCall.body) as Map<String, dynamic>;

        expect(resetBody['email'], 'user@farm.vn');
        expect(resetBody['otp'], '123456'); // Matches backend Otp
        expect(resetBody['token'], '123456'); // Backward compatible
        expect(resetBody['newPassword'], 'NewPass#123');
        expect(
          find.textContaining('Đặt lại mật khẩu thành công'),
          findsOneWidget,
        );
      },
    );
  });

  group('D. ChangePasswordScreen Audit', () {
    testWidgets('Change password: calls PUT /api/v1/users/me/password', (
      tester,
    ) async {
      setScreenSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      handler = (request) {
        if (request.url.path == '/api/v1/users/me/password' &&
            request.method == 'PUT') {
          return http.Response(
            jsonEncode({'message': 'Đổi mật khẩu thành công!'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('', 404);
      };

      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'OldPass#123');
      await tester.enterText(fields.at(1), 'NewPass#456');
      await tester.enterText(fields.at(2), 'NewPass#456');
      await tester.tap(find.widgetWithText(FilledButton, 'Đổi mật khẩu'));
      await tester.pumpAndSettle();

      final changeCall = calls.firstWhere(
        (c) => c.url.path == '/api/v1/users/me/password',
      );
      final changeBody = jsonDecode(changeCall.body) as Map<String, dynamic>;

      expect(changeBody['currentPassword'], 'OldPass#123');
      expect(changeBody['newPassword'], 'NewPass#456');
      expect(find.textContaining('Đã đổi mật khẩu thành công'), findsOneWidget);
    });
  });
}
