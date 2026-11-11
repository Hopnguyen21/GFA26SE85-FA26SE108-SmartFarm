part of '../farmer_dashboard_screen.dart';

extension _FarmerDashboardScreenStateCommon on _FarmerDashboardScreenState {
  // ─── UTILITY ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFD1FAE5)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDenied(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline, size: 40, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có quyền truy cập',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayVi(int weekday) {
    const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  String _cropEmoji(String crop) {
    if (crop.contains('Cà chua')) return '🍅';
    if (crop.contains('Dâu')) return '🍓';
    if (crop.contains('Ớt')) return '🫑';
    if (crop.contains('Xà lách')) return '🥬';
    if (crop.contains('Kale') || crop.contains('Cải')) return '🥦';
    if (crop.contains('Dưa')) return '🥒';
    return '🌱';
  }

  String _activityIcon(String activity) {
    switch (activity) {
      case 'Tưới nước':
        return '💧';
      case 'Bón phân':
        return '🌿';
      case 'Phun thuốc':
        return '💊';
      case 'Kiểm tra sâu bệnh':
        return '🔍';
      case 'Thu hoạch':
        return '🧺';
      case 'Làm đất':
        return '⛏️';
      default:
        return '📝';
    }
  }
}
