import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var response = http.Response('[]', 200);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((_) async => response),
    );
  });
  setUp(() {
    ApiService.setTokens(accessToken: 't', role: 'FarmOwner');
  });
  test(
    'Actuator API errors are not empty successes; a genuine empty response is allowed',
    () async {
      response = http.Response('{"detail":"unavailable"}', 500);
      await expectLater(FarmApi.getZoneActuators('z'), throwsException);
      response = http.Response('[]', 200);
      expect(await FarmApi.getZoneActuators('z'), isEmpty);
    },
  );
  test(
    'Telemetry errors and malformed profiles are not silently empty',
    () async {
      response = http.Response('{}', 500);
      await expectLater(
        FarmApi.getTelemetryHistory(zoneId: 'z', parameterCode: 'Temperature'),
        throwsException,
      );
      response = http.Response('{}', 200);
      await expectLater(CropApi.getGrowthProfiles(), throwsFormatException);
      response = http.Response(jsonEncode({'data': []}), 200);
      expect(
        await FarmApi.getTelemetryHistory(
          zoneId: 'z',
          parameterCode: 'Temperature',
        ),
        isEmpty,
      );
    },
  );
  test(
    'Invalidated session cannot restore stale tokens from secure storage',
    () async {
      SharedPreferences.setMockInitialValues({
        'session_invalidated': true,
        'user_role': 'FarmOwner',
      });
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'stale',
        'refresh_token': 'stale',
      });
      expect(await ApiService.loadSavedTokens(), isFalse);
      expect(ApiService.isAuthenticated, isFalse);
    },
  );
}
