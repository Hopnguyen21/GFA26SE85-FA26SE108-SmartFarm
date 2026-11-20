import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import 'zone_crop_plan_edit_panel.dart';

/// Màn chọn/sửa HỒ SƠ CANH TÁC của một Zone (gắn trực tiếp Zone.GrowthProfileId). Chọn hoặc đổi hồ sơ ở đây KHÔNG tạo vụ trồng.
/// Luồng: xem chi tiết hồ sơ → áp dụng → xác nhận → lưu → tải lại Zone từ máy chủ. Chỉ chủ trang trại mở được từ Zone Detail.
class ZoneProfilePage extends StatelessWidget {
  final ZoneModel zone;
  const ZoneProfilePage({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    // Luôn dùng bản Zone mới nhất theo zoneId (sau khi gắn hồ sơ provider tải lại).
    final live =
        context
            .watch<FarmProvider>()
            .allZones
            .where((z) => z.zoneId.toLowerCase() == zone.zoneId.toLowerCase())
            .firstOrNull ??
        zone;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hồ sơ canh tác · ${live.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Quy trình sinh trưởng & ngưỡng môi trường Zone',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: ZoneCropPlanEditPanel(
            key: ValueKey('profile_${live.zoneId}'),
            zone: live,
          ),
        ),
      ),
    );
  }
}
