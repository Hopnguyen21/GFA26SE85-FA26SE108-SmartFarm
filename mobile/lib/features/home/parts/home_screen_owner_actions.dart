part of '../home_screen.dart';

extension _HomeScreenOwnerActions on HomeScreen {
  /// Lối tắt của Owner: thẻ "Việc cần bạn xử lý" (hợp đồng/thanh toán đang chờ) rồi lưới 2×2 (Kho vật tư, Yêu cầu & Hợp đồng,
  /// Hỏi AI, Hợp đồng Zone & Khấu hao) và thẻ tiến độ thiết lập.
  List<Widget> _ownerQuickActionsSection(
    BuildContext context,
    FarmProvider farmProvider,
    ZoneModel zone,
  ) {
    if (farmProvider.currentRole != 'OWNER') return const [];
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    Widget tile({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool dot = false,
    }) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  if (dot)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      // 2 dòng: "Yêu cầu & Hợp đồng", "Quản lý Nhân công", "Lập lịch tự động" bị cắt "…" khi chỉ 1 dòng.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return [
      OwnerPendingActionsCard(
        key: ValueKey('pending-${farmProvider.allZones.length}-${zone.zoneId}'),
        zones: farmProvider.allZones,
        zoneId: zone.zoneId,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: tile(
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF0F766E),
                      title: 'Kho vật tư',
                      subtitle: farmProvider.lowStockCount > 0
                          ? '${farmProvider.lowStockCount} mục sắp hết'
                          : 'Tồn kho, nhập xuất',
                      dot: farmProvider.lowStockCount > 0,
                      onTap: () => open(const InventoryScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: tile(
                      icon: Icons.assignment_turned_in_outlined,
                      color: AppColors.warning,
                      title: 'Yêu cầu & Hợp đồng',
                      subtitle: 'Báo giá, ký, thanh toán',
                      onTap: () => open(const SupportRequestsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: tile(
                      icon: Icons.smart_toy_outlined,
                      color: AppColors.primaryDark,
                      title: 'Hỏi AI Trại',
                      subtitle: 'Tư vấn theo dữ liệu Zone',
                      onTap: () =>
                          open(AiAssistantScreen(initialZoneId: zone.zoneId)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: tile(
                      icon: Icons.description_outlined,
                      color: AppColors.info,
                      title: 'Hợp đồng Zone',
                      subtitle: 'Hợp đồng & khấu hao',
                      onTap: () => open(const ContractsDepreciationScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: tile(
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF2563EB),
                      title: 'Quản lý Nhân công',
                      subtitle: 'Mời & phân quyền Zone',
                      onTap: () => open(
                        WorkforceScreen(
                          initialFarmId: farmProvider.selectedFarmId,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: tile(
                      icon: Icons.tune_outlined,
                      color: const Color(0xFF0D9488),
                      title: 'Lập lịch tự động',
                      subtitle: 'Quy tắc & vi khí hậu',
                      onTap: () => open(const SchedulesAutomationScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: tile(
                      icon: Icons.insights_rounded,
                      color: const Color(0xFF047857),
                      title: 'Báo cáo Tổng hợp',
                      subtitle: 'Trang trại, zone, vụ, năng suất',
                      onTap: () => open(const ReportsScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: tile(
                      icon: Icons.corporate_fare_rounded,
                      color: const Color(0xFF0284C7),
                      title: 'Quản lý Farm & Zone',
                      subtitle: 'Cấu trúc & ranh giới GIS',
                      onTap: () => open(const FarmsManagementScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ];
  }
}
