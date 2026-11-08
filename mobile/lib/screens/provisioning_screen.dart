import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'deployment_screens.dart';

/// Điểm vào luồng lắp đặt thiết bị IoT, tách theo role: chủ trang trại lập kế hoạch/gửi yêu cầu,
/// kỹ thuật viên nền tảng tiếp nhận, khảo sát và cấp phát. Không còn quét QR/MAC giả lập.
class ProvisioningScreen extends StatelessWidget {
  const ProvisioningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = ApiService.userRole?.toLowerCase();
    if (role == 'platformtechnician') return const TechnicianDeploymentsScreen();
    if (role == 'farmowner') return const DeploymentPlanningScreen();
    return Scaffold(
      appBar: AppBar(title: const Text('Lắp đặt thiết bị IoT')),
      body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Tài khoản của bạn không có thao tác trong luồng lắp đặt thiết bị.'))),
    );
  }
}
