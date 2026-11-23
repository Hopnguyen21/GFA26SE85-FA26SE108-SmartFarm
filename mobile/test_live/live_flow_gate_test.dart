// ignore_for_file: invalid_use_of_visible_for_testing_member
// Mô phỏng cổng "Gắn Node" của mobile với dữ liệu THẬT cho mọi phiếu lắp đặt (chỉ đọc), vai trò kỹ thuật viên demo.
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/node_placement_logic.dart';
import 'package:smartfarm_mobile/features/support/service_board_logic.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart'
    show serviceStatusOf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test('cổng Gắn Node theo dữ liệu thật', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    expect(
      await ApiService.login('technician@smartfarm.demo', 'Demo@12345'),
      isNotNull,
    );
    final list = await SupportApi.getServiceRequests();
    for (final r in list) {
      if (serviceKindOf(r) != ServiceKind.installation) continue;
      final id = '${r['id']}';
      final q = await SupportApi.getQuotation(id);
      final dep = '${r['deploymentRequestId'] ?? ''}';
      String? depStatus;
      if (dep.isNotEmpty && !dep.startsWith('0000')) {
        try {
          depStatus = (await DeploymentApi.getDeploymentRequest(
            dep,
            technician: true,
          )).status;
        } catch (_) {}
      }
      final gate = checkNodePlacement(
        serviceStatus: serviceStatusOf(r),
        quotationLoaded: true,
        quotationStatus: effectiveQuotationStatus(q?.status, r),
        deploymentStatus: depStatus,
        linkValid: depStatus != null,
      );
      // ignore: avoid_print
      print(
        '${id.substring(0, 8)} sr=${serviceStatusOf(r)} quote=${q?.status} dep=$depStatus → ${gate.allowed ? 'MỞ' : 'KHOÁ(${gate.block?.name})'}',
      );
    }
  });
}
