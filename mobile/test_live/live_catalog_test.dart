// ignore_for_file: invalid_use_of_visible_for_testing_member
// Danh mục thiết bị THẬT → dự toán có chọn được đúng một loại cho mỗi vai trò không (chỉ đọc).
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/honeycomb_estimate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test(
    'dự toán với danh mục thật: mỗi vai trò chọn được thiết bị, tính được tổng',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      expect(
        await ApiService.login('owner@smartfarm.demo', 'Demo@12345'),
        isNotNull,
      );
      final catalog = HoneycombCatalog.fromHardwareItems(
        await DeploymentApi.getHardwareItems(),
      );
      final est = computeHoneycombEstimate(
        areaM2: 2204,
        radiusM: honeycombFixedRadiusM,
        actuatorRatio: honeycombActuatorRatio('Cà Chua Beefsteak (Tomato)'),
        catalog: catalog,
      );
      for (final role in EstimateRole.values) {
        // ignore: avoid_print
        print(
          '${role.name}: issue=${catalog.of(role).issue} items=${catalog.of(role).items.map((i) => i.code).join(",")}',
        );
      }
      // ignore: avoid_print
      print('tổng=${est.total} blocked=${est.totalBlockedReason}');
      expect(est.totalBlockedReason, isNull);
      expect(est.total, greaterThan(0));
    },
  );
}
