import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import 'gateway_activation_logic.dart';
import 'gateway_activation_sheet.dart';

/// Gateway trong kho của KTV kèm đăng ký của từng thiết bị (backend đã tắt cấp phát Gateway tay `POST /gateways`:
/// Gateway thật tự đăng ký rồi KTV kích hoạt cho yêu cầu).
Future<List<GatewayChoice>> loadGatewayChoices() async {
  final parts = await DeploymentApi.getTechnicianSpareParts();
  final enrollments = <String, Map<String, dynamic>?>{};
  await Future.wait([
    for (final p in parts)
      if ('${p['category'] ?? ''}'.toUpperCase().contains('GATEWAY'))
        () async {
          try {
            enrollments['${p['id']}'] =
                await DeploymentApi.getGatewayEnrollmentByHardware(
                  '${p['id']}',
                );
          } catch (_) {
            enrollments['${p['id']}'] = null;
          }
        }(),
  ]);
  return gatewayChoices(parts, enrollments);
}

/// Kích hoạt Gateway đã đăng ký cho yêu cầu triển khai (tạo Gateway của đợt lắp đặt).
Future<void> activateGatewayChoice(
  GatewayChoice g, {
  required String farmId,
  required String deploymentRequestId,
}) async {
  await DeploymentApi.activateGatewayEnrollment(
    g.enrollmentId!,
    farmId: farmId,
    deploymentRequestId: deploymentRequestId,
  );
}

/// MÔ PHỎNG khi chưa có phần cứng: app đóng vai Gateway gọi API tự đăng ký (đúng API công khai mà firmware gọi) bằng MAC của
/// Gateway có thật trong kho KTV, rồi kích hoạt cho yêu cầu. Không tạo thiết bị ngoài luồng đăng ký/kích hoạt của backend.
Future<String> simulateGatewayForDeployment({
  required String farmId,
  required String deploymentRequestId,
}) async {
  final choices = await loadGatewayChoices();
  final g = pickGatewayToSimulate(choices);
  if (g == null) {
    // Kho KTV chưa có Gateway nào dùng được: nhờ backend dựng Gateway mô phỏng (chỉ khi môi trường bật mô phỏng).
    try {
      final r = await DeploymentApi.simulateGatewayOnBackend(
        farmId: farmId,
        deploymentRequestId: deploymentRequestId,
      );
      return 'Đã mô phỏng Gateway ${r['gatewaySerial'] ?? ''}: tự đăng ký và kích hoạt cho yêu cầu này.';
    } catch (e) {
      // Môi trường không bật mô phỏng: báo cần Admin giao Gateway thật; lỗi khác (chưa cọc, đã có Gateway…) báo nguyên văn.
      if ('$e'.contains('simulation is disabled')) {
        throw Exception(noGatewayToSimulateMessage(choices));
      }
      rethrow;
    }
  }
  var enrollmentId = g.enrollmentId;
  if (enrollmentId == null) {
    final mac = g.mac!;
    final e = await DeploymentApi.simulateGatewayAutoEnroll(
      macAddress: mac,
      chipId:
          'SIM-${mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase()}',
      gatewaySerial: g.serial,
    );
    enrollmentId = '${e['id']}';
  }
  await DeploymentApi.activateGatewayEnrollment(
    enrollmentId,
    farmId: farmId,
    deploymentRequestId: deploymentRequestId,
  );
  return 'Đã mô phỏng Gateway ${g.code}: tự đăng ký và kích hoạt cho yêu cầu này.';
}

/// Mở bảng kích hoạt/mô phỏng Gateway; trả true khi đã kích hoạt được một Gateway cho yêu cầu.
Future<bool> showGatewayActivationSheet(
  BuildContext context, {
  required String farmId,
  required String deploymentRequestId,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GatewayActivationSheet(
        load: loadGatewayChoices,
        activate: (g) => activateGatewayChoice(
          g,
          farmId: farmId,
          deploymentRequestId: deploymentRequestId,
        ),
        simulate: () => simulateGatewayForDeployment(
          farmId: farmId,
          deploymentRequestId: deploymentRequestId,
        ),
      ),
    ) ??
    false;
