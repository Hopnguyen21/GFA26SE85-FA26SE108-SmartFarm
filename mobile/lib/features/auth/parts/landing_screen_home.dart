part of '../landing_screen.dart';

// Các khối trang chủ theo web (`HomePage`): phần mở đầu (hero), dải chỉ số, thanh điều hướng tới các mục và "Hệ sinh thái".
extension _LandingScreenStateHome on _LandingScreenState {
  static const _green = Color(0xFF119653);

  /// Cuộn tới một mục như các liên kết neo (#solutions, #hardware…) trên thanh điều hướng của web.
  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: 0.02,
    );
  }

  /// Hero: huy hiệu, tiêu đề, mô tả, ba nút (Đăng ký ngay / Đăng nhập / Yêu cầu tư vấn thiết bị) và ba chỉ số tin cậy.
  Widget _buildHeroIntro(BuildContext context) {
    Widget trust(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _green,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF047857)),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'HỆ THỐNG QUẢN TRỊ NÔNG NGHIỆP THÔNG MINH SỐ 1',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: const Text(
                'Chuẩn VietGAP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 25,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Kiến tạo Nông trang số '),
              TextSpan(
                text: 'Tự động hóa Vi khí hậu',
                style: TextStyle(color: _green),
              ),
              TextSpan(text: ' & Quản trị IoT Thực địa'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Nền tảng Cloud SaaS đồng bộ trạm cảm biến LoRa tầm xa, bản đồ vệ tinh GIS, rơ-le tưới nhỏ giọt tự động và Trợ lý AI nông học chuyên biệt cho các Hợp tác xã & Nhà vườn hiện đại.',
          style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openRegister(context),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Đăng ký ngay'),
            iconAlignment: IconAlignment.start,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _navigateToLogin(context),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Đăng nhập'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: BorderSide(
                  color: _green.withValues(alpha: 0.35),
                  width: 1.6,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showConsultModal(context),
              icon: const Icon(Icons.phone_outlined, size: 16),
              label: const Text('Yêu cầu tư vấn thiết bị'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF065F46),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              trust('500+', 'Hecta chuẩn hóa'),
              trust('99.9%', 'Thời gian Uptime'),
              trust('-35%', 'Chi phí nước & phân'),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Thanh điều hướng tới các mục (tương đương nav Giải pháp / Thiết bị LoRa / Quy trình VietGAP / Triển khai GIS ).
  Widget _buildNavChips() {
    Widget chip(String label, GlobalKey key) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () => _scrollTo(key),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFA7F3D0)),
        labelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF065F46),
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          chip('Giải pháp', _solutionsKey),
          chip('Thiết bị LoRa', _hardwareKey),
          chip('Triển khai GIS', _workflowKey),
          chip('Khách hàng', _testimonialsKey),
        ],
      ),
    );
  }

  /// "Hệ sinh thái Nông nghiệp Toàn diện": sáu thẻ như web; bấm "Khám phá…" chuyển tới mục tương ứng.
  Widget _buildEcosystemSection() {
    Widget card({
      required IconData icon,
      required Color iconBg,
      required Color iconFg,
      required String title,
      required String desc,
      required String action,
      required VoidCallback onTap,
    }) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      // Gọn cho màn hẹp: biểu tượng bên trái, tiêu đề + mô tả bên phải, cả thẻ là vùng chạm (không còn dòng liên kết riêng).
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconFg, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    void openTab(int tab) => _scrollTo(_workflowKey);

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
            'HỆ SINH THÁI NÔNG NGHIỆP TOÀN DIỆN',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mọi công cụ cần thiết cho Nhà vườn số hóa',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF062326),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tích hợp chặt chẽ từ phần cứng cảm biến, bản đồ địa không gian GIS đến hồ sơ sinh trưởng cây trồng VietGAP và trợ lý AI thông minh.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        card(
          icon: Icons.place_outlined,
          iconBg: _green,
          iconFg: Colors.white,
          title: 'Bản đồ Vệ tinh GIS Đa tầng',
          desc:
              'Phân cấp không gian chính xác từ Nông trang ➔ Thửa đất (Field) ➔ Khu vực (Zone). Vẽ ranh giới Polygon thực địa và tự động tính toán diện tích m².',
          action: 'Khám phá tính năng GIS',
          onTap: () => openTab(1),
        ),
        card(
          icon: Icons.cell_tower,
          iconBg: const Color(0xFF065F46),
          iconFg: Colors.white,
          title: 'Trạm ESP32 LoRa & Cảm biến RS485',
          desc:
              'Thu thập chỉ số độ ẩm đất, nhiệt độ, pH, EC, cường độ ánh sáng và độ ẩm không khí theo chu kỳ 60 giây qua sóng LoRa khoảng cách đến 2km.',
          action: 'Chi tiết phần cứng',
          onTap: () => _scrollTo(_hardwareKey),
        ),
        card(
          icon: Icons.water_drop_outlined,
          iconBg: const Color(0xFF115E59),
          iconFg: Colors.white,
          title: 'Tự động hóa Vi khí hậu & Lịch Cron',
          desc:
              'Bộ luật IF-THEN tự động bảo vệ cây trồng: bật tưới khi ẩm đất < 60%, ngắt quạt khi lạnh, cùng nút Dừng khẩn cấp (Emergency Stop) 1 chạm.',
          action: 'Trạm điều khiển CF3',
          onTap: () => openTab(0),
        ),
        card(
          icon: Icons.eco_outlined,
          iconBg: const Color(0xFFB45309),
          iconFg: Colors.white,
          title: 'Hồ sơ Sinh trưởng 4 Tầng',
          desc:
              'Cơ chế Crop-aware độc quyền: Cây trồng ➔ Giống ➔ Hồ sơ sinh trưởng ➔ Giai đoạn. Tự điều chỉnh ngưỡng vi khí hậu theo từng ngày tuổi.',
          action: 'Thư viện cây trồng',
          onTap: () => openTab(0),
        ),
        card(
          icon: Icons.smart_toy_outlined,
          iconBg: const Color(0xFF312E81),
          iconFg: const Color(0xFF6EE7B7),
          title: 'Trợ lý AI Nông học Gemini',
          desc:
              'Tích hợp AI RAG chẩn đoán bệnh cây qua hình ảnh thực địa, đề xuất lịch bón phân và cảnh báo rủi ro thời tiết cực đoan trước 24 giờ.',
          action: 'Trải nghiệm AI Demo',
          onTap: () => openTab(2),
        ),
        card(
          icon: Icons.description_outlined,
          iconBg: const Color(0xFF1E293B),
          iconFg: const Color(0xFFFBBF24),
          title: 'Báo giá & Ký Hợp đồng Điện tử',
          desc:
              'Kỹ thuật viên khảo sát thực địa, xuất báo giá phần cứng chi tiết, ký hợp đồng điện tử online và nghiệm thu bàn giao 2 pha minh bạch.',
          action: 'Quy trình ký số',
          onTap: () => openTab(3),
        ),
      ],
    );
  }
}

// Cột liên kết chân trang như web: "Sản phẩm & Giải pháp" và "Cổng Dịch vụ".
extension _LandingScreenStateFooterLinks on _LandingScreenState {
  Widget _buildFooterLinks(BuildContext context) {
    void goTab(int tab) => _scrollTo(_solutionsKey);

    Widget link(String text, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF047857)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Widget group(String title, List<Widget> links) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        ...links,
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group('Sản phẩm & Giải pháp', [
            link('Bản đồ vệ tinh GIS Nông trang', () => goTab(1)),
            link(
              'Trạm LoRa Gateway & Sensor Nodes',
              () => _scrollTo(_hardwareKey),
            ),
            link('Bộ luật Tự động hóa CF3', () => goTab(0)),
            link('Trợ lý AI Nông học Gemini', () => goTab(2)),
          ]),
          const SizedBox(height: 10),
          group('Cổng Dịch vụ', [
            link(
              'Cổng Chủ Trang Trại (Owner Portal)',
              () => _navigateToLogin(context),
            ),
            link(
              'Cổng Kỹ Thuật Viên (Technician)',
              () => _navigateToLogin(context),
            ),
            link('Đăng ký Nông trang Mới', () => _openRegister(context)),
          ]),
        ],
      ),
    );
  }
}
