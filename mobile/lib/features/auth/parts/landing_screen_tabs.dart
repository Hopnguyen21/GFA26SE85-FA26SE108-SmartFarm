part of '../landing_screen.dart';

extension _LandingScreenStateTabs on _LandingScreenState {
  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return InkWell(
      onTap: () => _rebuild(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF062326) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF062326).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF34D399) : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return _buildTabDetailCard(
          title: 'Giám Sát Vi Khí Hậu & Sóng LoRa 433MHz',
          badgeText: 'IoT Telemetry Realtime',
          badgeColor: const Color(0xFF0284C7),
          description:
              'Thu thập độ ẩm đất, nhiệt độ, EC và pH mỗi 60s qua sóng LoRa khoảng cách > 1.5km xuyên tán lá. Tự động kích hoạt bơm bù ẩm chống sốc nhiệt.',
          feature1: 'Khóa an toàn khẩn cấp E-Stop 1 chạm',
          feature2: 'Lập lịch tưới đa chu kỳ tự ngắt khi mưa',
          actionText: 'Trải nghiệm Bảng điều khiển IoT',
        );
      case 1:
        return _buildTabDetailCard(
          title: 'Bản Đồ Số GIS Phân Vùng Đa Cấp',
          badgeText: 'Satellite GIS WGS84',
          badgeColor: const Color(0xFF10B981),
          description:
              'Phân cấp không gian chính xác từ Farm ➔ Thửa đất (Field) ➔ Nhà màng (Zone). Vẽ ranh giới Polygon thực địa và gán tọa độ GPS cho Gateway & Node.',
          feature1: 'Đo đạc diện tích tự động (m², Hecta)',
          feature2: 'Chấm điểm thiết bị & đo cường độ sóng RSSI',
          actionText: 'Khám phá Bản đồ GIS Farm',
        );
      case 2:
        return _buildTabDetailCard(
          title: 'Trợ Lý AI Nông Học SmartFarm',
          badgeText: 'VietGAP Agronomist AI',
          badgeColor: const Color(0xFF8B5CF6),
          description:
              'Chẩn đoán bệnh lá qua ảnh chụp thực địa, phân tích biểu đồ vi khí hậu 7 ngày để cảnh báo nấm bệnh và đề xuất dinh dưỡng N-P-K theo ngày tuổi.',
          feature1: 'Chẩn đoán bệnh cây bằng camera điện thoại',
          feature2: 'Tư vấn phác đồ sinh học chuẩn VietGAP',
          actionText: 'Hỏi đáp với Trợ lý AI',
        );
      case 3:
      default:
        return _buildTabDetailCard(
          title: 'Minh Bạch Báo Giá & Ký Nghiệm Thu Số',
          badgeText: 'E-Contract 2 Pha',
          badgeColor: const Color(0xFFD97706),
          description:
              'Quy trình triển khai 2 pha minh bạch: Tạm ứng 30% khi ký hợp đồng khảo sát, thanh toán 70% sau khi ký biên bản nghiệm thu vận hành trơn tru.',
          feature1: 'Ký số trực tiếp trên điện thoại',
          feature2: 'Bảo hành phần cứng Gateway LoRa 24 tháng',
          actionText: 'Yêu cầu Báo giá & Khảo sát',
        );
    }
  }

  Widget _buildTabDetailCard({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required String description,
    required String feature1,
    required String feature2,
    required String actionText,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF062326)),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feature1,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF062326)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  feature2,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF062326)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToLogin(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062326),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              child: Text('$actionText ➔'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, String subtext, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 1),
        Text(
          subtext,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatBadge(String number, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleItem(String roleTitle, String roleDesc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          roleTitle,
          style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(roleDesc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.35)),
      ],
    );
  }
}
