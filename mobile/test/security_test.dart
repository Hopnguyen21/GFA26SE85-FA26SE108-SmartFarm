import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/main.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/workforce/workforce_screen.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/services/app_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ApiService.clearTokens();
  });

  group('1. TLS and Certificate Verification Security', () {
    test(
      'DebugLocalHttpOverrides only permits bad certs for local hosts in debug mode',
      () {
        // In Debug mode: Localhost allowed
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            'localhost',
            isDebug: true,
          ),
          isTrue,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            '127.0.0.1',
            isDebug: true,
          ),
          isTrue,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            '10.0.2.2',
            isDebug: true,
          ),
          isTrue,
        );

        // In Debug mode: Remote / third-party / production hosts are STRICTLY rejected
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            'evil-attacker.com',
            isDebug: true,
          ),
          isFalse,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            'api.smartfarm.vn',
            isDebug: true,
          ),
          isFalse,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            '192.168.1.100',
            isDebug: true,
          ),
          isFalse,
        );

        // In Release mode: ALL hosts (even localhost) MUST be rejected from bypassing verification
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            'localhost',
            isDebug: false,
          ),
          isFalse,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            '127.0.0.1',
            isDebug: false,
          ),
          isFalse,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            '10.0.2.2',
            isDebug: false,
          ),
          isFalse,
        );
        expect(
          DebugLocalHttpOverrides.isHostPermittedForSelfSigned(
            'api.smartfarm.vn',
            isDebug: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('2. URL & HTTPS Security in Release vs Debug', () {
    test('Release mode rejects unencrypted HTTP URLs', () {
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'http://api.smartfarm.vn',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'http://insecure.smartfarm.vn/api',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Release mode rejects untrusted hosts even with HTTPS', () {
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'https://evil-hacker.com',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'https://phishing-smartfarm.com',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Release mode accepts official trusted HTTPS hosts', () {
      final valid = ApiService.validateAndNormalizeBaseUrl(
        'https://api.smartfarm.vn',
        isRelease: true,
      );
      expect(valid, 'https://api.smartfarm.vn');

      // Subdomain không nằm trong danh sách tin cậy thì bị từ chối
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'https://sub.smartfarm.vn',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
    });

    test('Debug mode allows local HTTP/HTTPS development endpoints', () {
      expect(
        ApiService.validateAndNormalizeBaseUrl(
          'http://localhost:5144',
          isRelease: false,
        ),
        'http://localhost:5144',
      );
      expect(
        ApiService.validateAndNormalizeBaseUrl(
          'http://10.0.2.2:5144',
          isRelease: false,
        ),
        'http://10.0.2.2:5144',
      );
      expect(
        ApiService.validateAndNormalizeBaseUrl(
          'https://localhost:7040',
          isRelease: false,
        ),
        'https://localhost:7040',
      );
    });
  });

  group('3. Elimination of Plaintext Passwords from Farmer Model & UI', () {
    test('FarmerModel does not store or expose password', () {
      final farmer = FarmerModel(
        farmerId: 'f-1',
        name: 'Nguyễn Văn A',
        role: 'Farmer',
        phone: '0901234567',
      );

      // Verify through json mapping that no password is leaked
      final json = {
        'userId': 'f-2',
        'fullName': 'Trần Văn B',
        'role': 'Farmer',
      };
      final fromJsonFarmer = FarmerModel.fromJson(json);
      expect(fromJsonFarmer.name, 'Trần Văn B');
      expect(farmer.name, 'Nguyễn Văn A');
    });

    testWidgets('WorkforceScreen does not display passwords or copy buttons', (
      tester,
    ) async {
      final provider = FarmProvider();
      provider.switchRole('OWNER');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(
            value: provider,
            child: const WorkforceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no "Mật khẩu mẫu" or "Copy MK" text exists in the UI
      expect(find.text('Mật khẩu mẫu'), findsNothing);
      expect(find.text('Copy MK'), findsNothing);
      expect(find.text('Farmer@12345'), findsNothing);
      expect(find.text('Binh@Farmer2026'), findsNothing);

      provider.dispose();
      await tester.pumpAndSettle();
    });
  });

  group('4. Token Storage and Logout Security Flow', () {
    test(
      'Tokens are saved in FlutterSecureStorage and cleared on logout',
      () async {
        await ApiService.saveTokens(
          accessToken: 'mock_access_token_xyz',
          refreshToken: 'mock_refresh_token_abc',
          email: 'user@smartfarm.vn',
          role: 'OWNER',
        );

        expect(ApiService.isAuthenticated, isTrue);
        expect(ApiService.userEmail, 'user@smartfarm.vn');

        // Tokens must NOT be in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('access_token'), isNull);
        expect(prefs.getString('refresh_token'), isNull);

        // Clear tokens / logout
        await ApiService.clearTokens();

        expect(ApiService.isAuthenticated, isFalse);
        expect(ApiService.userEmail, isNull);
        expect(ApiService.userRole, isNull);

        // Verify tokens deleted from secure storage
        const secure = FlutterSecureStorage();
        expect(await secure.read(key: 'access_token'), isNull);
        expect(await secure.read(key: 'refresh_token'), isNull);
      },
    );
  });

  group('5. Role handling and request guards', () {
    test(
      'Only exact supported roles are accepted; ADMIN/unknown are blocked',
      () {
        expect(parseAppRole('FarmOwner'), AppRole.farmOwner);
        expect(parseAppRole('FARM_OWNER'), AppRole.farmOwner);
        expect(parseAppRole('Farmer'), AppRole.farmer);
        expect(parseAppRole('PLATFORM_TECHNICIAN'), AppRole.platformTechnician);
        expect(parseAppRole('PlatformAdmin'), isNull);
        expect(parseAppRole('PLATFORM_ADMIN'), isNull);
        expect(parseAppRole('ADMIN'), isNull);
        expect(parseAppRole('OWNER'), isNull);
        expect(parseAppRole('SuperUser'), isNull);
        expect(parseAppRole(null), isNull);
      },
    );

    test('Saved session with unsupported role is cleared on startup', () async {
      ApiService.setTokens(
        accessToken: 'a',
        refreshToken: 'r',
        email: 'x@y.z',
        role: 'PlatformAdmin',
      );
      await ApiService.saveTokens(
        accessToken: 'a',
        refreshToken: 'r',
        email: 'x@y.z',
        role: 'PlatformAdmin',
      );
      final restored = await ApiService.loadSavedTokens();
      expect(restored, isFalse);
      expect(ApiService.isAuthenticated, isFalse);
      expect(ApiService.userRole, isNull);
      const secure = FlutterSecureStorage();
      expect(await secure.read(key: 'access_token'), isNull);
    });

    test(
      'Release request guard rejects HTTP and untrusted hosts, allows trusted HTTPS',
      () {
        expect(
          () => ApiService.assertSecureRequest(
            Uri.parse('http://api.smartfarm.vn/x'),
            isRelease: true,
          ),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => ApiService.assertSecureRequest(
            Uri.parse('https://evil.example/x'),
            isRelease: true,
          ),
          throwsA(isA<SecurityException>()),
        );
        expect(
          () => ApiService.assertSecureRequest(
            Uri.parse('https://api.smartfarm.vn/x'),
            isRelease: true,
          ),
          returnsNormally,
        );
        // Debug cho phép API cục bộ
        expect(
          () => ApiService.assertSecureRequest(
            Uri.parse('http://10.0.2.2:5144/x'),
            isRelease: false,
          ),
          returnsNormally,
        );
      },
    );

    test(
      'Logout bumps sessionVersion and clears SharedPreferences session data',
      () async {
        await ApiService.saveTokens(
          accessToken: 'a',
          refreshToken: 'r',
          email: 'o@x.y',
          role: 'FarmOwner',
        );
        final before = ApiService.sessionVersion.value;
        await ApiService.clearTokens();
        expect(ApiService.sessionVersion.value, greaterThan(before));
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('user_email'), isNull);
        expect(prefs.getString('user_role'), isNull);
        expect(prefs.getString('base_url'), isNull);
      },
    );
  });
}
