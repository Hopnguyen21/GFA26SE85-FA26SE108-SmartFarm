// ignore_for_file: invalid_use_of_visible_for_testing_member
// Kiểm tra API cảnh báo THẬT (chỉ đọc) qua AlertApi của mobile: localhost:5144, tài khoản demo của dự án.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/alerts/alert_rules_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  for (final acc in [
    ['OWNER', 'owner@smartfarm.demo'],
    ['FARMER', 'farmer@smartfarm.demo'],
  ]) {
    test('alert API thật ${acc[0]}', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      expect(await ApiService.login(acc[1], 'Demo@12345'), isNotNull);
      // Không cứng mã Zone (mã thay đổi theo từng cơ sở dữ liệu): lấy Zone đầu tiên mà tài khoản này truy cập được.
      final provider = FarmProvider()..switchRole(acc[0]);
      await provider.fetchFromApi();
      final zone = provider.allZones.firstOrNull?.zoneId;
      provider.dispose();
      if (zone == null) {
        markTestSkipped('Tài khoản ${acc[0]} chưa có Zone nào trong cơ sở dữ liệu này.');
        return;
      }
      final rules = await AlertApi.getRules(zone);
      final alerts = await AlertApi.getZoneAlerts(zone);
      // ignore: avoid_print
      print('${acc[0]}: ${rules.length} quy tắc, ${alerts.length} cảnh báo');
      for (final r in rules) {
        expect(
          canonicalParameter('${r['parameterCode']}'),
          isNotNull,
          reason: 'tham số lạ ${r['parameterCode']}',
        );
        expect((r['minThreshold'] as num) < (r['maxThreshold'] as num), isTrue);
        expect(alertSeverities.containsKey('${r['severity']}'), isTrue);
        expect(r['ruleId'], isNotNull);
      }
      for (final a in alerts) {
        expect(
          alertStatusLabels.containsKey('${a['status']}'),
          isTrue,
          reason: 'trạng thái lạ ${a['status']}',
        );
        expect(a['observedValue'], isA<num>());
        expect(DateTime.tryParse('${a['createdAtUtc']}'), isNotNull);
      }
      // Farmer không được tạo quy tắc (403) và lỗi backend được báo ra đúng
      if (acc[0] == 'FARMER') {
        await expectLater(
          AlertApi.createRule(
            zone,
            parameterCode: 'Temperature',
            minThreshold: 1,
            maxThreshold: 2,
            severity: 'Warning',
            cooldownMinutes: 30,
          ),
          throwsA(isA<Exception>()),
        );
      } else {
        await expectLater(
          AlertApi.createRule(
            zone,
            parameterCode: 'Temperature',
            minThreshold: 30,
            maxThreshold: 20,
            severity: 'Warning',
            cooldownMinutes: 30,
          ),
          throwsA(isA<Exception>()), // min ≥ max → 400, không ghi gì
        );
      }
    });
  }
}
