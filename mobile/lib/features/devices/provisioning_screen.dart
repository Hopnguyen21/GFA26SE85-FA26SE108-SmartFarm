import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';
import 'deployment_screens.dart';

/// Điểm vào luồng lắp đặt thiết bị IoT, tách theo role: chủ trang trại lập kế hoạch/gửi yêu cầu,
/// kỹ thuật viên nền tảng tiếp nhận, khảo sát và cấp phát. Không còn quét QR/MAC giả lập.
class ProvisioningScreen extends StatelessWidget {
  const ProvisioningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pRole = context.watch<FarmProvider>().currentRole;
    final role =
        ApiService.appRole ??
        switch (pRole) {
          'TECHNICIAN' => AppRole.platformTechnician,
          'OWNER' => AppRole.farmOwner,
          'FARMER' => AppRole.farmer,
          _ => null,
        };
    if (role == AppRole.platformTechnician)
      return const TechnicianDeploymentsScreen();
    if (role == AppRole.farmOwner) return const OwnerDeploymentRequestsScreen();
    return Scaffold(
      appBar: AppBar(title: const Text('Lắp đặt thiết bị IoT')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tài khoản của bạn không có thao tác trong luồng lắp đặt thiết bị.',
          ),
        ),
      ),
    );
  }
}
