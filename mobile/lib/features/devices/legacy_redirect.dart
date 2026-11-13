import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';
import 'deployment_screens.dart';
import '../support/support_requests_screen.dart';

/// Màn hình thay thế cho luồng cũ (khảo sát / đơn thiết bị lưu cục bộ trên máy, không có trong CSDL).
/// Quy trình thật chạy qua Yêu cầu triển khai thiết bị và Yêu cầu hỗ trợ kỹ thuật (đều lưu ở máy chủ).
class LegacyFlowRedirectScreen extends StatelessWidget {
  final String title;
  const LegacyFlowRedirectScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final role = ApiService.appRole;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Luồng này trước đây chỉ lưu tạm trên thiết bị nên không có trong cơ sở dữ liệu. '
            'Hãy dùng quy trình chính thức được lưu trên máy chủ:',
          ),
          const SizedBox(height: 16),
          if (role == AppRole.farmOwner)
            ListTile(
              leading: const Icon(Icons.router),
              title: const Text('Yêu cầu triển khai thiết bị'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OwnerDeploymentRequestsScreen(),
                ),
              ),
            ),
          if (role == AppRole.platformTechnician)
            ListTile(
              leading: const Icon(Icons.router),
              title: const Text('Yêu cầu triển khai (Kỹ thuật viên)'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TechnicianDeploymentsScreen(),
                ),
              ),
            ),
          if (role == AppRole.farmOwner || role == AppRole.platformTechnician)
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Yêu cầu hỗ trợ & báo giá'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupportRequestsScreen(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
