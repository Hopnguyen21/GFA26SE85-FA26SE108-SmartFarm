import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../core/widgets/dispose_later.dart';

part 'parts/landing_screen_consult.dart';
part 'parts/landing_screen_tabs.dart';
part 'parts/landing_screen_sections.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LandingScreen({super.key, required this.onLoginSuccess});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  int _activeTabIndex = 0; // 0: IoT, 1: GIS, 2: AI, 3: Nghiệm thu

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(onLoginSuccess: widget.onLoginSuccess),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Announcement Bar
            _buildTopAnnouncementBar(),

            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF062326),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF062326,
                          ).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.eco,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'SmartFarm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF062326),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'IoT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Nông nghiệp số VietGAP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _showConsultModal(context),
                        icon: const Icon(
                          Icons.phone_in_talk,
                          color: Color(0xFF059669),
                          size: 19,
                        ),
                        tooltip: 'Tư vấn',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => _navigateToLogin(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF062326),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),

                    // Badge Highlight
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF059669),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Nền tảng Quản trị Nông nghiệp Đa cấp 2026',
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Main Headline
                    const Text(
                      'Tối Ưu Nông Trại Bằng\nCảm Biến LoRa & AI',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062326),
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    const Text(
                      'Tự động hóa tưới tiêu thông minh, giám sát vi khí hậu thời gian thực và trợ lý nông học theo tiêu chuẩn VietGAP.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CTA Buttons: Bắt đầu ngay, Đăng ký, Tư vấn
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: () => _navigateToLogin(context),
                            icon: const Icon(Icons.arrow_forward, size: 15),
                            label: const Text('Bắt Đầu Ngay'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF062326),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF062326),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.3,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                            child: const Text('Đăng Ký'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Nút Yêu cầu tư vấn thiết bị (Secondary CTA)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => _showConsultModal(context),
                        icon: const Icon(
                          Icons.support_agent,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        label: const Text(
                          'Yêu cầu tư vấn thiết bị & Khảo sát thực địa',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF065F46),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // HERO TELEMETRY CARD WITH BANNER IMAGE (100% Matching Web)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF062326,
                            ).withValues(alpha: 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner Image with Overlay
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                            ),
                            child: Stack(
                              children: [
                                SizedBox(
                                  height: 155,
                                  width: double.infinity,
                                  child: Image.asset(
                                    'assets/images/banner.jpg',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              color: const Color(0xFF062326),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.agriculture,
                                                  color: Color(0xFF34D399),
                                                  size: 48,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                                // Gradient Overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          const Color(
                                            0xFF062326,
                                          ).withValues(alpha: 0.85),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Badge top left
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF062326,
                                      ).withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF34D399,
                                        ).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.water_drop,
                                          color: Color(0xFF34D399),
                                          size: 12,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Hệ thống tưới nhỏ giọt',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Badge top right: LoRa Live
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 2.5,
                                          backgroundColor: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Online 24/7',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Farm title bottom overlay
                                const Positioned(
                                  bottom: 10,
                                  left: 12,
                                  right: 12,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TRANG TRẠI THỰC ĐỊA #01',
                                        style: TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Vườn Cà Chua Công Nghệ Cao Đà Lạt',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Realtime Telemetry Data Grid
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile(
                                    'Độ ẩm đất',
                                    '68.4%',
                                    '✓ Đạt chuẩn',
                                    const Color(0xFF10B981),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 35,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                Expanded(
                                  child: _buildMetricTile(
                                    'Nhiệt độ KK',
                                    '24.5°C',
                                    'Tối ưu',
                                    const Color(0xFF0284C7),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 35,
                                  color: const Color(0xFFE2E8F0),
                                ),
                                Expanded(
                                  child: _buildMetricTile(
                                    'Bơm Tưới',
                                    'AUTO ON',
                                    'Van #1 (12p)',
                                    const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Stats Bar
                    Row(
                      children: [
                        Expanded(child: _buildStatBadge('1,200+', 'Node LoRa')),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildStatBadge('150+', 'Nhà màng HTX'),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildStatBadge('99.9%', 'Uptime 24/7'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // INTERACTIVE TABS: 4 TRỤ CỘT NỀN TẢNG (Matching Web Tabs)
                    const Text(
                      'Khám Phá 4 Trụ Cột Nền Tảng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF062326),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Chọn từng trụ cột để xem cách thức vận hành số hóa từ cảm biến đến nghiệm thu:',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab Selector Buttons (Horizontal Scrollable)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTabButton(
                            0,
                            '1. Vi khí hậu LoRa',
                            Icons.cell_tower,
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            1,
                            '2. Bản đồ GIS',
                            Icons.map_outlined,
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            2,
                            '3. AI Nông học',
                            Icons.smart_toy_outlined,
                          ),
                          const SizedBox(width: 6),
                          _buildTabButton(
                            3,
                            '4. Ký Nghiệm thu',
                            Icons.verified_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab Content Card
                    _buildActiveTabContent(),
                    const SizedBox(height: 22),

                    // Roles Overview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF062326),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF062326,
                            ).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.people_alt_outlined,
                                color: Color(0xFF10B981),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Dành Cho Ai Trong Nông Trại?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildRoleItem(
                            '👑 Chủ Trang Trại (Owner)',
                            'Toàn quyền quản trị farm, giám sát chỉ số, điều khiển bơm và hỏi đáp AI.',
                          ),
                          const Divider(height: 14, color: Colors.white12),
                          _buildRoleItem(
                            '🔧 Kỹ Thuật Viên (Technician)',
                            'Khảo sát hiện trường, cấp phát Gateway, chấm vị trí Node trên bản đồ GIS.',
                          ),
                          const Divider(height: 14, color: Colors.white12),
                          _buildRoleItem(
                            '👤 Nông Dân / Công Nhân (Farmer)',
                            'Xem nhanh nhà màng được giao, ghi nhật ký canh tác và nhận cảnh báo sớm.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Khối Phần Cứng LoRa Chuẩn Công Nghiệp
                    _buildHardwareShowcase(),
                    const SizedBox(height: 24),

                    // Quy trình 4 bước chuẩn hóa
                    _buildWorkflowSteps(),
                    const SizedBox(height: 24),

                    // Đánh giá khách hàng thực tế
                    _buildTestimonials(),
                    const SizedBox(height: 24),

                    // Footer & CTA Đăng Ký
                    _buildFooterSection(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
