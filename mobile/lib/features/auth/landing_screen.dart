import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../widgets/dispose_later.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LandingScreen({super.key, required this.onLoginSuccess});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  int _activeTabIndex = 0; // 0: IoT, 1: GIS, 2: AI, 3: Nghiệm thu

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(onLoginSuccess: widget.onLoginSuccess),
      ),
    );
  }

  void _showConsultModal(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final areaController = TextEditingController();
    String selectedProvince = 'Lâm Đồng (Đà Lạt)';
    bool isSubmitted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: isSubmitted
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 54),
                        const SizedBox(height: 12),
                        const Text(
                          'Gửi Yêu Cầu Thành Công!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF062326),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kỹ thuật viên SmartFarm sẽ liên hệ lại với bạn trong vòng 15 phút để tư vấn khảo sát thực địa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF062326),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 45),
                          ),
                          child: const Text('Đóng'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.eco, color: Color(0xFF10B981), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tư Vấn Khảo Sát Nông Trang',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF062326),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const Text(
                            'Để lại thông tin để kỹ sư phần cứng LoRa liên hệ tư vấn cấu hình thiết bị tối ưu.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Họ và tên chủ trang trại',
                              labelStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.person_outline, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại (Zalo)',
                              labelStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: areaController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Diện tích (ha/m²)',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    prefixIcon: const Icon(Icons.landscape_outlined, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedProvince,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF062326)),
                                  items: const [
                                    DropdownMenuItem(value: 'Lâm Đồng (Đà Lạt)', child: Text('Lâm Đồng')),
                                    DropdownMenuItem(value: 'Đắk Lắk', child: Text('Đắk Lắk')),
                                    DropdownMenuItem(value: 'Gia Lai', child: Text('Gia Lai')),
                                    DropdownMenuItem(value: 'Sơn La', child: Text('Sơn La')),
                                    DropdownMenuItem(value: 'Tỉnh khác', child: Text('Khác')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => selectedProvince = val);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Khu vực',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Vui lòng điền họ tên và số điện thoại')),
                                );
                                return;
                              }
                              setModalState(() => isSubmitted = true);
                            },
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text('Gửi Yêu Cầu Khảo Sát'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF062326),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    ).then((_) => disposeControllersLater([nameController, phoneController, areaController]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
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
                          color: const Color(0xFF062326).withValues(alpha: 0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.eco, color: Color(0xFF10B981), size: 18),
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
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Nông nghiệp số VietGAP',
                          style: TextStyle(
                            fontSize: 9,
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
                        icon: const Icon(Icons.phone_in_talk, color: Color(0xFF059669), size: 19),
                        tooltip: 'Tư vấn',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => _navigateToLogin(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF062326),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Nền tảng Quản trị Nông nghiệp Đa cấp 2026',
                              style: const TextStyle(
                                color: Color(0xFF065F46),
                                fontSize: 10,
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.3),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
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
                        icon: const Icon(Icons.support_agent, size: 16, color: Color(0xFF059669)),
                        label: const Text('Yêu cầu tư vấn thiết bị & Khảo sát thực địa'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF065F46),
                          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                            color: const Color(0xFF062326).withValues(alpha: 0.08),
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
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: const Color(0xFF062326),
                                      child: const Center(
                                        child: Icon(Icons.agriculture, color: Color(0xFF34D399), size: 48),
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
                                          const Color(0xFF062326).withValues(alpha: 0.85),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF062326).withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.water_drop, color: Color(0xFF34D399), size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'Hệ thống tưới nhỏ giọt',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(radius: 2.5, backgroundColor: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Online 24/7', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TRANG TRẠI THỰC ĐỊA #01',
                                        style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        'Vườn Cà Chua Công Nghệ Cao Đà Lạt',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildMetricTile('Độ ẩm đất', '68.4%', '✓ Đạt chuẩn', const Color(0xFF10B981)),
                                ),
                                Container(width: 1, height: 35, color: const Color(0xFFE2E8F0)),
                                Expanded(
                                  child: _buildMetricTile('Nhiệt độ KK', '24.5°C', 'Tối ưu', const Color(0xFF0284C7)),
                                ),
                                Container(width: 1, height: 35, color: const Color(0xFFE2E8F0)),
                                Expanded(
                                  child: _buildMetricTile('Bơm Tưới', 'AUTO ON', 'Van #1 (12p)', const Color(0xFF059669)),
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
                        Expanded(child: _buildStatBadge('150+', 'Nhà màng HTX')),
                        const SizedBox(width: 6),
                        Expanded(child: _buildStatBadge('99.9%', 'Uptime 24/7')),
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
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Tab Selector Buttons (Horizontal Scrollable)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildTabButton(0, '1. Vi khí hậu LoRa', Icons.cell_tower),
                          const SizedBox(width: 6),
                          _buildTabButton(1, '2. Bản đồ GIS', Icons.map_outlined),
                          const SizedBox(width: 6),
                          _buildTabButton(2, '3. AI Nông học', Icons.smart_toy_outlined),
                          const SizedBox(width: 6),
                          _buildTabButton(3, '4. Ký Nghiệm thu', Icons.verified_outlined),
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
                            color: const Color(0xFF062326).withValues(alpha: 0.15),
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
                              const Icon(Icons.people_alt_outlined, color: Color(0xFF10B981), size: 16),
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
                          _buildRoleItem('👑 Chủ Trang Trại (Owner)', 'Toàn quyền quản trị farm, giám sát chỉ số, điều khiển bơm và hỏi đáp AI.'),
                          const Divider(height: 14, color: Colors.white12),
                          _buildRoleItem('🔧 Kỹ Thuật Viên (Technician)', 'Khảo sát hiện trường, cấp phát Gateway, chấm vị trí Node trên bản đồ GIS.'),
                          const Divider(height: 14, color: Colors.white12),
                          _buildRoleItem('👤 Nông Dân / Công Nhân (Farmer)', 'Xem nhanh nhà màng được giao, ghi nhật ký canh tác và nhận cảnh báo sớm.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
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
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF34D399) : const Color(0xFF64748B),
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
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
              style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062326),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.4),
          ),
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
          style: const TextStyle(
            fontSize: 9.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtext,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF065F46),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
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
          style: const TextStyle(
            color: Color(0xFF34D399),
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          roleDesc,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
