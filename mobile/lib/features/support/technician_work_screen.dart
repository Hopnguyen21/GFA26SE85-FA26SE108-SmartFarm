import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'technician_maintenance_screen.dart';

/// Tab "Công việc" của kỹ thuật viên: MỘT danh sách, mỗi yêu cầu chỉ một thẻ, thao tác đổi theo tiến độ:
/// - Trước cọc 30%: tiếp nhận → khảo sát → tạo/gửi hợp đồng → chờ Owner thanh toán.
/// - Đã cọc 30%: chuyển sang triển khai → chấm node → lưu vị trí → ghi kết nối → hoàn tất.
/// - Sau hoàn tất: chờ Owner thanh toán 70% và nghiệm thu → đóng công việc.
/// Chỉ hiển thị phiếu được giao; triển khai liên kết nằm trong cùng thẻ công việc.
class TechnicianWorkScreen extends StatelessWidget {
  const TechnicianWorkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(title: const Text('Công việc')),
      body: const TechnicianMaintenanceScreen(embedded: true),
    );
  }
}
