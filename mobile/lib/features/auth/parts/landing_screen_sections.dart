part of '../landing_screen.dart';

extension _LandingScreenStateSections on _LandingScreenState {
  /// Top Announcement Bar giống FE
  Widget _buildTopAnnouncementBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF047857), Color(0xFF065F46)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'MỚI 2026',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFF062326),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Chuẩn VietGAP & Trợ lý AI Gemini Nông học',
              style: TextStyle(
                color: Color(0xFFD1FAE5),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '📞 1900 6899',
            style: TextStyle(
              color: Color(0xFFA7F3D0),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Khối 1: Phần cứng LoRa chuẩn công nghiệp (Hardware Showcase)
  Widget _buildHardwareShowcase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Text(
            'PHẦN CỨNG LORA CHUẨN CÔNG NGHIỆP',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Trạm Gateway & Cảm Biến Bền Bỉ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF062326),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Thiết kế chuẩn kháng nước IP67, pin mặt trời và sóng LoRa xuyên tán lá 2.5km.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        // 3 Thẻ thiết bị phần cứng
        _buildHardwareCard(
          icon: Icons.cell_tower,
          title: 'Gateway ESP32-S3 LoRa Dual Antenna',
          desc:
              'Kết nối đến 128 sensor node trong bán kính 2.5km không cần kéo dây mạng.',
          color: const Color(0xFF059669),
        ),
        const SizedBox(height: 8),
        _buildHardwareCard(
          icon: Icons.grass,
          title: 'Đầu dò Đất RS485 Modbus 3-in-1',
          desc:
              'Đo độ ẩm đất, nhiệt độ đất và độ dẫn điện EC, chống ăn mòn phân bón.',
          color: const Color(0xFF0284C7),
        ),
        const SizedBox(height: 8),
        _buildHardwareCard(
          icon: Icons.wb_sunny_outlined,
          title: 'Trạm Vi khí hậu SHT30 & Cảm biến Lux',
          desc:
              'Giám sát vi khí hậu nhà màng liên tục, tự động phát hiện sốc nhiệt.',
          color: const Color(0xFFD97706),
        ),
        const SizedBox(height: 12),

        // Bảng trạng thái thực địa LoRa
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF065F46)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34D399),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'BẢNG TỔNG QUAN THỰC ĐỊA LORA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'v2.6',
                    style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 9.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildLoRaMetric('Sóng LoRa', '-68 dBm', 'Cực mạnh'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLoRaMetric(
                      'Pin Năng Lượng',
                      '94%',
                      'Solar ON',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildLoRaMetric('Chu kỳ gửi', '60s', 'TimescaleDB'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildLoRaMetric(
                      'Rơ-le tưới',
                      '4 Cổng',
                      'Optocoupler',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHardwareCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoRaMetric(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 9.5),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 9),
          ),
        ],
      ),
    );
  }

  /// Khối 2: Quy trình triển khai 4 bước (Workflow Steps)
  Widget _buildWorkflowSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Text(
            'QUY TRÌNH VẬN HÀNH CHUẨN MỰC',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Từ Khảo Sát Đến Nghiệm Thu',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF062326),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Số hóa minh bạch, ký hợp đồng điện tử và nghiệm thu bàn giao 2 pha an tâm.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),

        _buildStepItem(
          step: '01',
          title: 'Khảo Sát & Chấm GIS Thực Địa',
          desc:
              'Kỹ thuật viên đo đạc ranh giới polygon và chấm tọa độ Gateway & Node trên bản đồ số.',
          isHighlight: false,
        ),
        const SizedBox(height: 8),
        _buildStepItem(
          step: '02',
          title: 'Ký Số & Tạm Ứng ${BusinessParameters.active.depositLabel}',
          desc:
              'Xuất báo giá chi tiết, Chủ trang trại ký hợp đồng điện tử và tạm ứng ${BusinessParameters.active.depositLabel} triển khai.',
          isHighlight: false,
        ),
        const SizedBox(height: 8),
        _buildStepItem(
          step: '03',
          title: 'Lắp Đặt & Provisioning Thiết Bị',
          desc:
              'Cấu hình trạm ESP32, kiểm thử kết nối telemetry và hiệu chuẩn cảm biến với đất.',
          isHighlight: false,
        ),
        const SizedBox(height: 8),
        _buildStepItem(
          step: '04',
          title:
              'Nghiệm Thu & Vận Hành ${BusinessParameters.active.remainingLabel}',
          desc:
              'Kiểm tra hệ thống tưới tự động ổn định, ký nghiệm thu số và thanh toán ${BusinessParameters.active.remainingLabel} còn lại.',
          isHighlight: true,
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required String desc,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlight
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: isHighlight ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isHighlight
                  ? const Color(0xFF059669)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isHighlight ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isHighlight
                        ? const Color(0xFF065F46)
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Khối 3: Đánh giá thực tế từ khách hàng (Testimonials)
  Widget _buildTestimonials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Text(
            'NIỀM TIN TỪ KHÁCH HÀNG & HTX',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB45309),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Đồng Hành Cùng Nông Nghiệp Xanh',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF062326),
          ),
        ),
        const SizedBox(height: 12),

        _buildTestimonialCard(
          quote:
              'Hệ thống tưới nhỏ giọt kết hợp cảm biến đất LoRa giúp 8ha cà chua của chúng tôi tại Đơn Dương tiết kiệm 40% chi phí nhân công và tăng 22% năng suất.',
          author: 'Ông Nguyễn Văn An',
          role: 'GĐ HTX Nông nghiệp Công nghệ cao Đà Lạt',
        ),
        const SizedBox(height: 8),
        _buildTestimonialCard(
          quote:
              'Bản đồ GIS và quy trình hồ sơ sinh trưởng VietGAP rất chuẩn mực. Kỹ thuật viên hỗ trợ tận tình từ khảo sát đến nghiệm thu hợp đồng điện tử.',
          author: 'Bà Trần Thị Hoa',
          role: 'Chủ trang trại Dưa lưới Organic Mộc Châu',
        ),
        const SizedBox(height: 8),
        _buildTestimonialCard(
          quote:
              'Trợ lý AI Nông học Gemini chẩn đoán bệnh lá và lịch tưới cực kỳ chính xác. Hoàn toàn yên tâm quản trị từ xa qua điện thoại.',
          author: 'Kỹ sư Lê Minh Tuấn',
          role: 'Quản lý Kỹ thuật Farm Đức Trọng FarmTech',
        ),
      ],
    );
  }

  Widget _buildTestimonialCard({
    required String quote,
    required String author,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '"$quote"',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF334155),
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFF059669),
                child: Text(
                  author.split(' ').last.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      role,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Khối 4: Call To Action & Footer đầy đủ (Giống Web)
  Widget _buildFooterSection(BuildContext context) {
    return Column(
      children: [
        // Bottom CTA Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF064E3B).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Sẵn sàng bắt đầu mùa vụ mới?',
                style: TextStyle(
                  color: Color(0xFFFDE68A),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Nâng Tầm Nông Trang Số',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Đăng ký tài khoản miễn phí để trải nghiệm trạm điều khiển IoT và nhận tư vấn khảo sát thực địa.',
                style: TextStyle(
                  color: Color(0xFFD1FAE5),
                  fontSize: 11,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(
                              onRegisterSuccess: () {
                                Navigator.pop(context);
                                _navigateToLogin(context);
                              },
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF062326),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      child: const Text('Đăng Ký Ngay'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _navigateToLogin(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white60),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      child: const Text('Đăng Nhập'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Footer info & Contact
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.eco, color: Color(0xFF059669), size: 16),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'SmartFarm IoT Platform',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 12, color: Color(0xFF059669)),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Hotline: 1900 6899 (8:00 - 20:00)',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 12,
                    color: Color(0xFF059669),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Email: hotro@smartfarm.vn',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF475569),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: Color(0xFF059669),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Đà Lạt, Lâm Đồng & TP. Hồ Chí Minh',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 14, color: Color(0xFFCBD5E1)),
              Text(
                '© 2026 SmartFarm IoT Platform • Bản quyền thuộc về Đội ngũ Kỹ sư Công nghệ Nông nghiệp.',
                style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
