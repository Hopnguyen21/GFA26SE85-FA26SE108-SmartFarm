part of '../profile_screen.dart';

extension _ProfileScreenMenu on ProfileScreen {
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
      if (isOwner)
        {
          'icon': Icons.route_outlined,
          'label': 'Tiến độ thiết lập CF1',
          'color': const Color(0xFF0F766E),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Cf1ProgressScreen())),
        },
      // OWNER only: báo cáo VietGAP (Backend ReportsController chỉ cho phép FarmOwner)
      if (isOwner)
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
          'onTap': () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
        },
        {
          'icon': Icons.badge_outlined,
          'label': 'Quản lý Nông dân & Phân quyền (Farmer)',
          'color': const Color(0xFF0D9488),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkforceScreen())),
        },
      ],
      if (isTech) ...[
        {
          'icon': Icons.build_circle_outlined,
          'label': 'Bảo trì & sửa chữa được giao',
          'color': const Color(0xFFD97706),
          'onTap': () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicianMaintenanceScreen())),
        },
        {
          'icon': Icons.settings_input_antenna,
          'label': 'Cấu hình Gateway / Node & Kho linh kiện',
          'color': const Color(0xFF0284C7),
          'onTap': () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TechnicianGatewayToolsScreen())),
        },
      ],
      // Tất cả: thông báo, MQTT, trợ giúp
      {
        'icon': Icons.notifications_outlined,
        'label': 'Cài đặt thông báo cảnh báo',
        'color': const Color(0xFFDC2626),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
      },
      // OWNER & TECHNICIAN: Trạng thái kết nối MQTT (Backend IoTDeploymentController: FarmOwner, PlatformTechnician)
      if (isOwner || isTech)
        {
          'icon': Icons.wifi_outlined,
          'label': 'Trạng thái kết nối MQTT',
          'color': const Color(0xFF059669),
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MqttStatusScreen())),
        },
      {
        'icon': Icons.lock_reset,
        'label': 'Đổi mật khẩu',
        'color': const Color(0xFF475569),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
      },
      {
        'icon': Icons.help_outline,
        'label': 'Trợ giúp & Hướng dẫn sử dụng',
        'color': const Color(0xFF64748B),
        'onTap': () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hỗ trợ kỹ thuật: 1900-SMARTFARM'))),
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
                  title: Text(
                    item['label'] as String,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
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
}
