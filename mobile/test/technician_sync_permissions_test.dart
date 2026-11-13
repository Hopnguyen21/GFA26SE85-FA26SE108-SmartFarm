import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final paths = <String>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 'test',
      refreshToken: 'test',
      email: 'tech@example.com',
      role: 'PlatformTechnician',
    );
    // Bind the API's shared client to the mock before its first request.
    await http.runWithClient(
      () async {
        await AccountApi.getMe();
      },
      () => MockClient((r) async {
        paths.add(r.url.path);
        final Object body = switch (r.url.path) {
          '/api/v1/users/me' => {'role': ApiService.userRole},
          '/api/v1/farms' => [
            {'farmId': 'farm-1', 'name': 'Assigned farm'},
          ],
          '/api/v1/tenants/me' => {'companyName': 'Owner tenant'},
          _ => [],
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  });

  setUp(() => paths.clear());

  test(
    'technician sync loads assigned farms without tenant or farm tasks',
    () async {
      final provider = FarmProvider()..switchRole('TECHNICIAN');
      addTearDown(provider.dispose);
      await provider.fetchFromApi();
      expect(paths, contains('/api/v1/farms'));
      expect(paths, contains('/api/v1/farms/farm-1/fields'));
      expect(paths, isNot(contains('/api/v1/tenants/me')));
      expect(paths, isNot(contains('/api/v1/farms/farm-1/tasks')));
      expect(provider.tasks, isEmpty);
    },
  );

  test('owner can still load their tenant and farm tasks', () async {
    ApiService.setTokens(
      accessToken: 'test',
      refreshToken: 'test',
      email: 'owner@example.com',
      role: 'FarmOwner',
    );
    final provider = FarmProvider()..switchRole('OWNER');
    addTearDown(provider.dispose);
    await provider.fetchFromApi();
    expect(paths, contains('/api/v1/tenants/me'));
    expect(paths, contains('/api/v1/farms/farm-1/tasks'));
  });
}
