import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../main.dart';
import '../farms/farms_management_screen.dart';
import '../devices/device_health_screen.dart';
import '../monitoring/monitoring_history_screen.dart';
import '../irrigation/schedules_automation_screen.dart';
import '../reports/reports_screen.dart';
import '../devices/provisioning_screen.dart';
import '../tasks/alerts_tasks_screen.dart';
import '../workforce/workforce_screen.dart';
import 'connection_notification_screens.dart';
import '../auth/password_screens.dart';
import '../workforce/farm_invitations_screen.dart';
import '../cf1/cf1_progress_screen.dart';
import '../support/support_requests_screen.dart';
import '../inventory/inventory_screen.dart';
import '../contracts/contracts_depreciation_screen.dart';
import '../../core/widgets/dispose_later.dart';
import '../devices/technician_gateway_tools_screen.dart';

part 'parts/profile_screen_widgets.dart';
part 'parts/profile_screen_menu.dart';
part 'parts/profile_screen_dialogs.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static String _formatJoined(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    return d == null
        ? '—'
        : '${d.toLocal().day.toString().padLeft(2, '0')}/${d.toLocal().month.toString().padLeft(2, '0')}/${d.toLocal().year}';
  }

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
    final userName =
        me?['fullName']?.toString() ?? ApiService.userEmail ?? 'Tài khoản';

    final userEmail = me?['email']?.toString() ?? ApiService.userEmail ?? '—';

    final userInitials = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(3)
        .map((w) => w[0].toUpperCase())
        .join();
    final userPhoneRaw = me?['phone']?.toString() ?? '';
    final userPhone = userPhoneRaw.isEmpty ? 'Chưa cập nhật' : userPhoneRaw;
    final userIdRaw = me?['userId']?.toString() ?? '';
    final empCode = userIdRaw.length >= 8
        ? userIdRaw.substring(0, 8).toUpperCase()
        : '—';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ─── Profile Hero AppBar ───
          SliverAppBar(
            expandedHeight:
                200 +
                40 * MediaQuery.textScalerOf(context).scale(1.0) +
                MediaQuery.paddingOf(context).top,
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
                                  colors: [
                                    roleColor,
                                    roleColor.withValues(alpha: 0.7),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  userInitials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
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
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: roleColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            roleLabel,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
                      _buildStatCard(
                        'Trang Trại',
                        '${provider.farms.length}',
                        Icons.corporate_fare,
                        const Color(0xFF062326),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        'Zone Canh Tác',
                        '${provider.zones.length}',
                        Icons.grid_view_rounded,
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        'Cảnh Báo',
                        '${provider.alerts.where((a) => !a.isAcknowledged).length}',
                        Icons.notifications_active,
                        const Color(0xFFDC2626),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Account Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildSectionHeader(
                          'THÔNG TIN TÀI KHOẢN (ĐỒNG BỘ BACKEND & DEMO)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _showEditProfileDialog(
                          context,
                          provider,
                          userName,
                          userPhoneRaw,
                        ),
                        icon: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                        label: const Text(
                          'Chỉnh sửa',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                    if (provider.tenantName != null)
                      _infoItem(
                        Icons.business_outlined,
                        'Tổ chức',
                        provider.tenantName!,
                      ),
                    _infoItem(
                      Icons.confirmation_number_outlined,
                      'Mã Tenant',
                      me?['tenantId']?.toString() ?? '—',
                    ),
                    _infoItem(
                      Icons.agriculture_outlined,
                      'Trang trại hiện tại',
                      provider.currentFarm.name,
                    ),
                    _infoItem(
                      Icons.calendar_today_outlined,
                      'Tham gia từ',
                      _formatJoined(me?['createdAtUtc']?.toString()),
                    ),
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
                          _roleOption(
                            context,
                            provider,
                            'OWNER',
                            '👑 Chủ Trang Trại',
                            'Toàn quyền: xem, điều khiển, quản lý tổ chức',
                            const Color(0xFF059669),
                          ),
                          const Divider(height: 16),
                          _roleOption(
                            context,
                            provider,
                            'FARMER',
                            '👤 Nông Dân Thực Địa',
                            'Giám sát, nhận thông báo và xem lịch tưới',
                            const Color(0xFFD97706),
                          ),
                          const Divider(height: 16),
                          _roleOption(
                            context,
                            provider,
                            'TECHNICIAN',
                            '🔧 Kỹ Thuật Viên IoT',
                            'Cấp phát thiết bị, quét QR, gán node vào zone',
                            const Color(0xFF0284C7),
                          ),
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
                            child: Icon(
                              Icons.verified_user,
                              color: roleColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  roleLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: roleColor,
                                  ),
                                ),
                                const Text(
                                  'Vai trò được xác thực bởi hệ thống (JWT)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: roleColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'Đang dùng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
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
                              child: const Icon(
                                Icons.eco,
                                color: Color(0xFF10B981),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SmartFarm Mobile',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'FA26SE108 • Capstone 2026',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'v1.0.0',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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
        border: Border.all(
          color: const Color(0xFF062326).withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF062326),
        ),
      ),
    );
  }
}
