part of '../home_screen.dart';

extension _HomeScreenOwnerActions on HomeScreen {
  List<Widget> _ownerQuickActionsSection(BuildContext context, FarmProvider farmProvider, ZoneModel zone) {
    return [
      // Owner Quick Action Utilities (Kho Vật Tư, Báo giá & cọc, AI, Hợp đồng & Khấu hao, Mùa vụ)
      if (farmProvider.currentRole == 'OWNER') ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                // Row 1: Vận hành thiết bị & kho
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0F766E), size: 18),
                                  ),
                                  if (farmProvider.lowStockCount > 0)
                                    Positioned(
                                      top: -3,
                                      right: -3,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDC2626),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Kho Vật Tư',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportRequestsScreen())),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFD97706), size: 18),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Báo Giá & Cọc',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId)),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF059669), size: 18),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Hỏi AI Trại',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                // Row 2: Hợp đồng Zone & Khấu hao thiết bị
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen()),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 16, color: Color(0xFF059669)),
                              SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Hợp Đồng Thuê & Khấu Hao',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                // Row 3: Hướng dẫn & Tiến độ thiết lập CF1 (Platform, Farm & IoT Setup)
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Cf1ProgressScreen())),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route_outlined, size: 16, color: Color(0xFF0F766E)),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tiến Độ Thiết Lập CF1 (Farm & Hạ Tầng IoT)',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF0F766E)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}
