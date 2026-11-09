import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'farms_management_screen.dart';
import 'device_health_screen.dart';
import 'monitoring_history_screen.dart';
import 'schedules_automation_screen.dart';
import 'reports_screen.dart';
import 'provisioning_screen.dart';
import 'alerts_tasks_screen.dart';
import 'workforce_screen.dart';
import 'farm_invitations_screen.dart';
import 'support_requests_screen.dart';
import 'inventory_screen.dart';
import 'contracts_depreciation_screen.dart';
import 'farming_seasons_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);

    final roleLabel = provider.currentRole == 'OWNER'
        ? 'Chủ Trang Trại (Farm Owner)'
        : provider.currentRole == 'TECHNICIAN'
            ? 'Kỹ Thuật Viên IoT (Technician)'
            : 'Nông Dân Thực Địa (Field Worker)';

    final roleColor = provider.currentRole == 'OWNER'
        ? const Color(0xFF059669)
        : provider.currentRole == 'TECHNICIAN'
            ? const Color(0xFF0284C7)
            : const Color(0xFFD97706);

    final me = provider.me;
    final userName = me?['fullName']?.toString() ?? ApiService.userEmail ?? 'Tài khoản';

    final userEmail = me?['email']?.toString() ?? ApiService.userEmail ?? '—';

    final userInitials = userName.trim().split(RegExp(r's+')).where((w) => w.isNotEmpty).take(3).map((w) => w[0].toUpperCase()).join();
    final userPhoneRaw = me?['phone']?.toString() ?? '';
    final userPhone = userPhoneRaw.isEmpty ? 'Chưa cập nhật' : userPhoneRaw;
    final userIdRaw = me?['userId']?.toString() ?? '';
    final empCode = userIdRaw.length >= 8 ? userIdRaw.substring(0, 8).toUpperCase() : '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ─── Profile Hero AppBar ───
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF062326),
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF062326), Color(0xFF064E3B)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [roleColor, roleColor.withValues(alpha: 0.7)],
                                ),
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: Center(
                                child: Text(userInitials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check, size: 12, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Content ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  Row(
                    children: [
                      _buildStatCard('Trang Trại', '${provider.farms.length}', Icons.corporate_fare, const Color(0xFF062326)),
                      const SizedBox(width: 10),
                      _buildStatCard('Zone Canh Tác', '${provider.zones.length}', Icons.grid_view_rounded, const Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      _buildStatCard('Cảnh Báo', '${provider.alerts.where((a) => !a.isAcknowledged).length}', Icons.notifications_active, const Color(0xFFDC2626)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Account Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('THÔNG TIN TÀI KHOẢN (ĐỒNG BỘ BACKEND & DEMO)'),
                      TextButton.icon(
                        onPressed: () => _showEditProfileDialog(context, provider, userName, userPhoneRaw),
                        icon: const Icon(Icons.edit, size: 14, color: Color(0xFF10B981)),
                        label: const Text('Chỉnh sửa', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoCard([
                    _infoItem(Icons.person_outline, 'Họ và tên', userName),
                    _infoItem(Icons.email_outlined, 'Email', userEmail),
                    _infoItem(Icons.phone_outlined, 'Điện thoại', userPhone),
                    _infoItem(Icons.badge_outlined, 'Mã tài khoản', empCode),
                  ]),

                  const SizedBox(height: 16),

                  // Organization
                  _buildSectionHeader('TỔ CHỨC / TENANT'),
                  const SizedBox(height: 10),
                  _buildInfoCard([
                    _infoItem(Icons.corporate_fare, 'Tên tổ chức', 'Green Valley Agriculture Corp'),
                    _infoItem(Icons.confirmation_number_outlined, 'Mã Tenant', 'TENANT-01 (GREEN_VALLEY)'),
                    _infoItem(Icons.location_on_outlined, 'Khu vực hoạt động', 'TP. Đà Lạt, Lâm Đồng'),
                    _infoItem(Icons.calendar_today_outlined, 'Tham gia từ', 'Tháng 01/2026'),
                  ]),

                  const SizedBox(height: 16),

                  // Role & Permissions – chỉ hiện switcher trong chế độ DEMO (khi chưa đăng nhập bằng tài khoản thật)
                  // Khi đăng nhập bằng JWT token thật thì role được xác thực bởi server và không cho đổi
                  if (!ApiService.isAuthenticated) ...[
                    _buildSectionHeader('VAI TRÒ & PHÂN QUYỀN'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _roleOption(context, provider, 'OWNER', '👑 Chủ Trang Trại', 'Toàn quyền: xem, điều khiển, quản lý tổ chức', const Color(0xFF059669)),
                          const Divider(height: 16),
                          _roleOption(context, provider, 'FARMER', '👤 Nông Dân Thực Địa', 'Giám sát, nhận thông báo và xem lịch tưới', const Color(0xFFD97706)),
                          const Divider(height: 16),
                          _roleOption(context, provider, 'TECHNICIAN', '🔧 Kỹ Thuật Viên IoT', 'Cấp phát thiết bị, quét QR, gán node vào zone', const Color(0xFF0284C7)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    _buildSectionHeader('VAI TRÒ & PHÂN QUYỀN'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified_user, color: roleColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(roleLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: roleColor)),
                                const Text('Vai trò được xác thực bởi hệ thống (JWT)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                            ),
                            child: Text('Đang dùng', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],


                  // Quick Actions
                  _buildSectionHeader('CÀI ĐẶT & TIỆN ÍCH'),
                  const SizedBox(height: 10),
                  _buildMenuItems(context, provider),

                  const SizedBox(height: 16),

                  // App version
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.eco, color: Color(0xFF10B981), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SmartFarm Mobile',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'FA26SE108 • Capstone 2026',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('v1.0.0', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _TechChip('Flutter 3.x'),
                            _TechChip('Provider'),
                            _TechChip('LoRa SX1278'),
                            _TechChip('MQTT Broker'),
                            _TechChip('TimescaleDB'),
                            _TechChip('Gemini AI'),
                            _TechChip('VietGAP'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }

  Widget _roleOption(BuildContext context, FarmProvider provider, String role, String title, String desc, Color color) {
    final isSelected = provider.currentRole == role;
    return InkWell(
      onTap: () => provider.switchRole(role),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(title.substring(0, 2), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.substring(3), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? color : const Color(0xFF374151))),
                  Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Đang dùng', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              )
            else
              Icon(Icons.radio_button_unchecked, size: 18, color: const Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, FarmProvider provider) {
    final isOwner = provider.currentRole == 'OWNER';
    final isTech = provider.currentRole == 'TECHNICIAN';
    final isFarmer = provider.currentRole == 'FARMER';

    final items = [
      // Farmer: xem cảnh báo & tác vụ
      {
        'icon': Icons.warning_amber_rounded,
        'label': 'Cảnh báo & Tác vụ thực địa',
        'color': const Color(0xFFE11D48),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsTasksScreen())),
      },
      if (isFarmer)
        {
          'icon': Icons.mail_outline,
          'label': 'Lời mời tham gia Farm',
          'color': const Color(0xFF0284C7),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmInvitationsScreen())),
        },
      // Farmer + Tech + Owner: lịch sử cảm biến
      {
        'icon': Icons.history,
        'label': 'Lịch sử Cảm biến & Biểu đồ',
        'color': const Color(0xFF7C3AED),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonitoringHistoryScreen())),
      },
      // Farmer + Owner: lịch tưới (xem)
      if (!isTech) ...[ 
        {
          'icon': Icons.schedule,
          'label': 'Lịch tưới & Tự động hóa',
          'color': const Color(0xFFD97706),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulesAutomationScreen())),
        },
      ],
      // Farmer + Owner: báo cáo VietGAP
      {
        'icon': Icons.assessment_outlined,
        'label': 'Báo cáo & Xuất dữ liệu VietGAP',
        'color': const Color(0xFF10B981),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
      },
      // TECHNICIAN + OWNER: thiết bị
      if (!isFarmer) ...[
        {
          'icon': Icons.qr_code_scanner,
          'label': isTech ? 'Yêu cầu triển khai thiết bị (KTV)' : 'Lắp đặt thiết bị IoT cho Zone',
          'color': const Color(0xFF10B981),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProvisioningScreen())),
        },
        {
          'icon': Icons.router,
          'label': 'Sức khỏe & Quản lý Thiết bị (Gateway / Node)',
          'color': const Color(0xFF0284C7),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeviceHealthScreen())),
        },
      ],
      // OWNER + TECHNICIAN: đơn hàng, khảo sát
      if (isOwner || isTech) ...[
        if (isOwner)
          {
            'icon': Icons.support_agent,
            'label': 'Hỗ trợ kỹ thuật & Yêu cầu bảo trì',
            'color': const Color(0xFF7C3AED),
            'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportRequestsScreen())),
          },
        {
          'icon': Icons.corporate_fare,
          'label': 'Quản lý Trang trại & Zone',
          'color': const Color(0xFF059669),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmsManagementScreen())),
        },
      ],
      // OWNER only: kho vật tư, quản lý nông dân
      if (isOwner) ...[
        {
          'icon': Icons.inventory_2_outlined,
          'label': 'Kho Vật tư, Phân bón & Hạt giống',
          'color': const Color(0xFF0F766E),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
        },
        {
          'icon': Icons.assignment_outlined,
          'label': 'Hợp đồng Thuê Zone & Khấu hao Thiết bị',
          'color': const Color(0xFF059669),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
        },
        {
          'icon': Icons.calendar_month_outlined,
          'label': 'Khung Mùa vụ Canh tác (Farming Seasons)',
          'color': const Color(0xFF0284C7),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmingSeasonsScreen())),
        },
        {
          'icon': Icons.badge_outlined,
          'label': 'Quản lý Nông dân & Phân quyền (Farmer)',
          'color': const Color(0xFF0D9488),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkforceScreen())),
        },
      ],
      // Tất cả: thông báo, MQTT, trợ giúp
      {
        'icon': Icons.notifications_outlined,
        'label': 'Cài đặt thông báo cảnh báo',
        'color': const Color(0xFFDC2626),
        'onTap': () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cài đặt thông báo: Đã bật Push & SMS'))),
      },
      {
        'icon': Icons.wifi_outlined,
        'label': 'Kết nối MQTT Broker (Online)',
        'color': const Color(0xFF059669),
        'onTap': () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MQTT Broker: broker.emqx.io:1883 • Kết nối ổn định'))),
      },
      {
        'icon': Icons.help_outline,
        'label': 'Trợ giúp & Hướng dẫn sử dụng',
        'color': const Color(0xFF64748B),
        'onTap': () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hỗ trợ kỹ thuật: 1900-SMARTFARM'))),
      },
    ];


    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item['icon'] as IconData, size: 18, color: item['color'] as Color),
                  ),
                  title: Text(item['label'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
                  onTap: item['onTap'] as VoidCallback,
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                ),
                if (i < items.length - 1) const Divider(height: 1, indent: 56),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi SmartFarm?', style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.logout();
              if (context.mounted) {
                Provider.of<FarmProvider>(context, listen: false).resetState();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AppEntryPoint()),
                  (route) => false,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Đã đăng xuất khỏi tài khoản thành công'),
                    backgroundColor: Color(0xFF062326),
                  ),
                );
              }
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, FarmProvider provider, String currentName, String currentPhone) {
    final nameCtrl = TextEditingController(text: currentName);
    final phoneCtrl = TextEditingController(text: currentPhone);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.manage_accounts, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Cập Nhật Hồ Sơ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Họ và tên:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Nhập họ và tên đầy đủ...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.person, size: 18),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text('Số điện thoại:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 4),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 0912345678',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.phone, size: 18),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.length < 2 || name.length > 100) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Họ và tên phải từ 2 đến 100 ký tự')),
                        );
                        return;
                      }
                      setState(() => isSaving = true);
                      final phone = phoneCtrl.text.trim();
                      final ok = await provider.updateProfile(
                        fullName: name,
                        phone: phone.isEmpty ? null : phone,
                      );
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Cập nhật hồ sơ thành công!' : 'Không thể cập nhật hồ sơ, vui lòng thử lại'),
                            backgroundColor: ok ? const Color(0xFF059669) : Colors.red,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  const _TechChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF062326).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF062326).withValues(alpha: 0.12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF062326))),
    );
  }
}
