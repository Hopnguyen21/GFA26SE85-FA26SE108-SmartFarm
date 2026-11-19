import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../../core/widgets/dispose_later.dart';
import '../../core/services/api_service.dart' show BusinessParametersStore;

part 'parts/landing_screen_consult.dart';
part 'parts/landing_screen_tabs.dart';
part 'parts/landing_screen_sections.dart';
part 'parts/landing_screen_home.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LandingScreen({super.key, required this.onLoginSuccess});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  // Cuộn tới từng mục như các liên kết neo trên thanh điều hướng của web.
  final _scroll = ScrollController();
  final _solutionsKey = GlobalKey();
  final _hardwareKey = GlobalKey();
  final _workflowKey = GlobalKey();
  final _testimonialsKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Tỷ lệ cọc do Admin cấu hình (endpoint công khai): cập nhật chữ quảng cáo; lỗi mạng thì giữ mặc định.
    BusinessParametersStore.refresh().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(onLoginSuccess: widget.onLoginSuccess),
      ),
    );
  }

  /// Đăng ký như web: xong thì sang màn đăng nhập với email đã đăng ký và thông báo thành công (không tự đăng nhập).
  Future<void> _openRegister(BuildContext context) async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (email == null || !context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onLoginSuccess: widget.onLoginSuccess,
          initialEmail: email,
          initialMessage:
              'Đăng ký tài khoản thành công! Hãy nhập mật khẩu của bạn để đăng nhập.',
        ),
      ),
    );
  }

  /// ── Nav Bar ─────────────────────────────────────────────────────────────
  /// Thanh điều hướng sticky bên dưới announcement bar.
  /// ui-ux-pro-max: Agriculture/Farm Tech palette, 48dp touch targets Android.
  Widget _buildNavBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFBBF7D0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062326).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo container: dark forest bg + eco icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF062326),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF062326).withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.eco, color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 10),
          // Brand name + tagline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'SmartFarm',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF062326),
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text(
                        'IoT',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Nông nghiệp số công nghệ cao',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // CTAs — 36dp height, 48dp touch area via padding
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 36,
                child: TextButton(
                  onPressed: () => _navigateToLogin(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF15803D),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Đăng nhập'),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: () => _openRegister(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF15803D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  child: const Text('Đăng ký'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // Farm Tech bg: Mint-50
      body: SafeArea(
        child: Column(
          children: [
            // ── Announcement bar ─────────────────────────────────────
            _buildTopAnnouncementBar(),

            // ── Sticky nav bar (ui-ux-pro-max: 48dp touch targets Android) ──────
            _buildNavBar(context),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),

                    // Hero như web: huy hiệu, tiêu đề, mô tả, nút Đăng ký / Đăng nhập / Tư vấn, chỉ số tin cậy
                    _buildHeroIntro(context),
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
                                    const Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Thanh điều hướng mục và "Hệ sinh thái" như web
                    _buildNavChips(),
                    const SizedBox(height: 20),
                    SizedBox(key: _solutionsKey, height: 0),
                    _buildEcosystemSection(),
                    const SizedBox(height: 24),

                    SizedBox(key: _hardwareKey, height: 0),
                    // Khối Phần Cứng LoRa Chuẩn Công Nghiệp
                    _buildHardwareShowcase(),
                    const SizedBox(height: 24),

                    SizedBox(key: _workflowKey, height: 0),
                    // Quy trình 4 bước chuẩn hóa
                    _buildWorkflowSteps(),
                    const SizedBox(height: 24),

                    SizedBox(key: _testimonialsKey, height: 0),
                    // Đánh giá khách hàng như web
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
