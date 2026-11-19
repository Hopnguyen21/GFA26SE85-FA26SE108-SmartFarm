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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: Color(0xFF047857)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Luồng này trước đây chỉ lưu tạm trên thiết bị nên không có trong cơ sở dữ liệu. '
                    'Hãy dùng quy trình chính thức được lưu trên máy chủ:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF065F46),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (role == AppRole.farmOwner)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.router, color: Color(0xFF0284C7)),
                ),
                title: const Text(
                  'Yêu cầu triển khai thiết bị',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OwnerDeploymentRequestsScreen(),
                  ),
                ),
              ),
            ),
          if (role == AppRole.platformTechnician)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.router, color: Color(0xFF0284C7)),
                ),
                title: const Text(
                  'Yêu cầu triển khai (Kỹ thuật viên)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TechnicianDeploymentsScreen(),
                  ),
                ),
              ),
            ),
          if (role == AppRole.farmOwner || role == AppRole.platformTechnician)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.support_agent, color: Color(0xFFD97706)),
                  ),
                  title: const Text(
                    'Yêu cầu hỗ trợ & báo giá',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportRequestsScreen(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
