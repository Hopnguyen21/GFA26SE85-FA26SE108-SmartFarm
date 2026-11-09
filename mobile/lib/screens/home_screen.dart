import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/mini_gis_map_picker.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import 'alerts_tasks_screen.dart';
import 'zone_detail_screen.dart';
import 'crop_profiles_screen.dart';
import 'schedules_automation_screen.dart';
import 'inspection_requests_screen.dart';
import 'equipment_orders_screen.dart';
import 'inventory_screen.dart';
import 'ai_screen.dart';
import 'contracts_depreciation_screen.dart';
import 'farming_seasons_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);
    final zone = farmProvider.currentZone;
    final unreadAlerts = farmProvider.alerts.where((a) => !a.isAcknowledged).length;
    final unreadTotal = unreadAlerts + farmProvider.unreadNotificationCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: Color(0xFF10B981), size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SmartFarm Mobile',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    farmProvider.currentRole == 'OWNER'
                        ? 'Chủ Trang Trại (Owner)'
                        : farmProvider.currentRole == 'TECHNICIAN'
                            ? 'Kỹ Thuật Viên (Technician)'
                            : 'Nông Dân Thực Địa (Worker)',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Nút đổi vai trò – chỉ hiện trong chế độ DEMO (khi chưa đăng nhập bằng JWT)
          if (!ApiService.isAuthenticated)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              tooltip: 'Đổi Vai trò',
              onSelected: (role) => farmProvider.switchRole(role),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'OWNER', child: Text('👑 Chủ trại (Owner)')),
                const PopupMenuItem(value: 'FARMER', child: Text('👤 Nông dân (Worker)')),
                const PopupMenuItem(value: 'TECHNICIAN', child: Text('🔧 Kỹ thuật viên (Technician)')),
              ],
            ),
          IconButton(
            icon: farmProvider.isLoadingApi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    Icons.sync,
                    color: farmProvider.isApiConnected ? const Color(0xFF10B981) : Colors.white70,
                  ),
            tooltip: farmProvider.isApiConnected ? 'API Đã kết nối (Chạm để đồng bộ)' : 'API Ngoại tuyến (Chạm để kết nối lại)',
            onPressed: () async {
              await farmProvider.fetchFromApi();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      farmProvider.isApiConnected
                          ? '✅ Đã đồng bộ dữ liệu mới nhất từ SmartFarm API'
                          : '⚠️ Không kết nối được API backend, đang dùng dữ liệu offline',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: farmProvider.isApiConnected ? const Color(0xFF065F46) : Colors.orange[800],
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: unreadTotal > 0,
              label: Text('$unreadTotal'),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.notifications_none, color: Colors.white),
            ),
            tooltip: 'Thông báo & Cảnh báo',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsTasksScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Farm Selector Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              decoration: const BoxDecoration(
                color: Color(0xFF062326),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Farm & Field Interactive Selector Header (Level 1: Farm, Level 2: Field)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        // Farm Switcher Row
                        InkWell(
                          onTap: () => _showFarmSelectorModal(context, farmProvider),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.corporate_fare, color: Color(0xFF10B981), size: 16),
                                const SizedBox(width: 6),
                                const Text('TRANG TRẠI: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    farmProvider.currentFarm.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Đổi Farm', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                                      Icon(Icons.keyboard_arrow_down, size: 12, color: Color(0xFF10B981)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 10, color: Colors.white12),
                        // Field Switcher Row
                        InkWell(
                          onTap: () => _showFieldSelectorModal(context, farmProvider),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.layers_outlined, color: Color(0xFF38BDF8), size: 16),
                                const SizedBox(width: 6),
                                const Text('THỬA ĐẤT: ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    farmProvider.currentField?.name ?? 'Tất cả các thửa (${farmProvider.fieldsForCurrentFarm.length} lô đất)',
                                    style: const TextStyle(color: Color(0xFFBAE6FD), fontSize: 11, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Lọc Lô', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold)),
                                      Icon(Icons.keyboard_arrow_down, size: 12, color: Color(0xFF38BDF8)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Zone Header with Quick Switcher & LoRa Live
                  InkWell(
                    onTap: () => _showZoneSelectorModal(context, farmProvider),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  'NHÀ MÀNG (ZONE): ',
                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                Flexible(
                                  child: Text(
                                    farmProvider.currentZone.name.split(' - ').first,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_down, color: Color(0xFF10B981), size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF064E3B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                            ),
                            child: const Text('LoRa Live', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Horizontal Zone Carousel with smooth touch scrolling
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: farmProvider.zones.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == farmProvider.zones.length) {
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CropProfilesScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF10B981), width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 14, color: Color(0xFF10B981)),
                                  SizedBox(width: 4),
                                  Text(
                                    '+ Zone Mới',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final z = farmProvider.zones[index];
                        final isSelected = index == farmProvider.selectedZoneIndex;
                        return InkWell(
                          onTap: () => farmProvider.selectZone(index),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check, size: 12, color: Color(0xFF062326)),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    z.name.split(' - ')[0],
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF062326) : Colors.white,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ─── FE-ALIGNED HERO SHOWCASE BANNER (banner.jpg) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF062326).withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Banner with Badges & Overlays
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                      child: Stack(
                        children: [
                          Image.asset(
                            'assets/images/banner.jpg',
                            height: 230,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              height: 230,
                              color: const Color(0xFF062326),
                              child: const Center(
                                child: Icon(Icons.eco, color: Color(0xFF10B981), size: 48),
                              ),
                            ),
                          ),
                          // Dark gradient overlay
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.15),
                                    const Color(0xFF062326).withValues(alpha: 0.85),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Top Badges
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF062326).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.water_drop, color: Color(0xFF34D399), size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Hệ thống tưới nhỏ giọt tự động',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.white, size: 6),
                                  SizedBox(width: 4),
                                  Text(
                                    'Online 24/7',
                                    style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Bottom Info inside image
                          Positioned(
                            bottom: 10,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TRANG TRẠI THỰC ĐỊA #01',
                                  style: TextStyle(
                                    color: Color(0xFF6EE7B7),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  farmProvider.currentFarm.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
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
                    // Live Telemetry Mini Bar (Matching FE Hero Banner)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Độ ẩm đất', style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
                                const SizedBox(height: 1),
                                Text(
                                  zone.telemetryIsFresh ? '${zone.currentSoilMoisture}%' : '—',
                                  style: const TextStyle(color: Color(0xFF047857), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const Text('✓ Đạt chuẩn', style: TextStyle(color: Color(0xFF10B981), fontSize: 8.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Nhiệt độ KK', style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
                                const SizedBox(height: 1),
                                Text(
                                  zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—',
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const Text('Tối ưu', style: TextStyle(color: Color(0xFF64748B), fontSize: 8.5)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Trạng thái Bơm', style: TextStyle(color: Color(0xFF64748B), fontSize: 9.5)),
                                const SizedBox(height: 1),
                                Text(
                                  farmProvider.currentZoneActuators.any((a) => a.isRunning && a.actuatorType == 'PUMP')
                                      ? 'AUTO ON'
                                      : 'SẴN SÀNG',
                                  style: TextStyle(
                                    color: farmProvider.currentZoneActuators.any((a) => a.isRunning && a.actuatorType == 'PUMP')
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF059669),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text('Van #1 (12p)', style: TextStyle(color: Color(0xFF0284C7), fontSize: 8.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Technician Assigned Field Inspection Banner
            if (farmProvider.currentRole == 'TECHNICIAN' || farmProvider.inspectionRequests.any((r) => r.status == 'DISPATCHED' || r.status == 'APPROVED')) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final assignedList = farmProvider.inspectionRequests.where((r) => r.status == 'DISPATCHED' || r.status == 'APPROVED').toList();
                    final count = assignedList.length;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.engineering_rounded, color: Color(0xFF38BDF8), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'YÊU CẦU KHẢO SÁT ĐƯỢC PHÂN CÔNG',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7DD3FC),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      count > 0 ? '$count phiếu khảo sát cần kỹ thuật viên tiếp nhận' : 'Không có phiếu khảo sát tồn đọng',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const InspectionRequestsScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text('Xem phiếu', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          if (assignedList.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: Colors.white12),
                            const SizedBox(height: 8),
                            Text(
                              '📍 Điểm hẹn: ${assignedList.first.zoneName} (${assignedList.first.areaM2.toInt()} m²)\n👤 Khách hàng: ${assignedList.first.contactName} - ${assignedList.first.contactPhone}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Owner Equipment Order & 30% Deposit Banner
            if (farmProvider.currentRole == 'OWNER' && farmProvider.equipmentOrders.any((o) => o.status == 'AWAITING_PAYMENT')) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    final awaitingOrders = farmProvider.equipmentOrders.where((o) => o.status == 'AWAITING_PAYMENT').toList();
                    final firstOrder = awaitingOrders.first;
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF78350F), Color(0xFF92400E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shopping_cart_checkout, color: Color(0xFFFDE68A), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'ĐƠN HÀNG THIẾT BỊ CẦN XÁC NHẬN CỌC',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFDE68A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '${awaitingOrders.length} đơn hàng đang chờ Owner cọc 30%',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const EquipmentOrdersScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: const Color(0xFF78350F),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: const Text('Cọc 30%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Colors.white24),
                          const SizedBox(height: 8),
                          Text(
                            '📍 Đơn: ${firstOrder.orderId} • ${firstOrder.zoneName}\n💰 Tiền cọc (30%): ${(firstOrder.depositAmountVND / 1000000).toStringAsFixed(2)} Tr VNĐ / Tổng ${(firstOrder.totalAmountVND / 1000000).toStringAsFixed(2)} Tr VNĐ',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFFEF3C7), height: 1.4),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Owner Quick Action Utilities (Kho Vật Tư, Đơn hàng cọc, Khảo sát, Hợp đồng & Khấu hao, Mùa vụ)
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
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Row 1: Vận hành thiết bị & kho
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
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
                                              decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('Kho Vật Tư', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EquipmentOrdersScreen())),
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
                                    const Text('Đơn Hàng & Cọc', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId))),
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
                                    const Text('Hỏi AI Trại', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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
                      // Row 2: Hợp đồng Zone, Khấu hao thiết bị & Khung mùa vụ
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
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
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmingSeasonsScreen())),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.calendar_month_outlined, size: 16, color: Color(0xFF0284C7)),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Khung Mùa Vụ Canh Tác',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // AI Agronomic Recommendation Card (VietGAP AI Assistant)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF062326),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.psychology_outlined, color: Color(0xFF10B981), size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Trợ lý AI Nông học VietGAP',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062326),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                          ),
                          child: const Text(
                            'Độ tin cậy: 92%',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Khuyến nghị: Duy trì độ ẩm đất 65 - 70% và thông gió nhẹ buổi chiều nhằm tăng khả năng hấp thu khoáng chất.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E293B), height: 1.45, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD1FAE5)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🌱 Lý do nông học: Giai đoạn phát triển thân lá đòi hỏi cân bằng bốc thoát hơi nước, giảm nguy cơ nấm cổ rễ.',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.35),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '📈 Tác động: Tăng 8% tốc độ quang hợp và phát triển chồi non.',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã bỏ qua khuyến nghị hiện tại'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Bỏ qua', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId)),
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline, size: 14),
                          label: const Text('Áp dụng & Hỏi AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF062326),
                            foregroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Active Crop & Cultivation Info Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZoneDetailScreen(
                        zone: zone,
                        zoneIndex: farmProvider.selectedZoneIndex,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Crop & Area
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                zone.currentCrop.contains('Cà chua')
                                    ? '🍅'
                                    : zone.currentCrop.contains('Dâu')
                                        ? '🍓'
                                        : '🫑',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  zone.currentCrop,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        zone.currentStage,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '• ${zone.areaM2.toInt()} m²',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      const SizedBox(height: 10),

                      // Assigned Worker Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                const Text(
                                  'Phụ trách: ',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                Text(
                                  zone.assignedWorkerName ?? 'Chưa phân công',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (zone.workerRole != null) ...[
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '(${zone.workerRole!.split(' - ')[0]})',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Growth Stages Pipeline
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'TIẾN ĐỘ 6 GIAI ĐOẠN CANH TÁC',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Chi tiết >',
                                style: TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Stage Progress Indicators
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final stages = [
                                {'name': 'Gieo mầm', 'done': true, 'current': false},
                                {'name': 'Cây con', 'done': true, 'current': false},
                                {'name': 'Sinh trưởng', 'done': true, 'current': false},
                                {
                                  'name': 'Ra hoa',
                                  'done': false,
                                  'current': zone.currentStage.contains('Ra hoa') || zone.currentStage.contains('Flowering'),
                                },
                                {
                                  'name': 'Nuôi trái',
                                  'done': false,
                                  'current': zone.currentStage.contains('Nuôi trái') || zone.currentStage.contains('Fruiting'),
                                },
                                {'name': 'Thu hoạch', 'done': false, 'current': false},
                              ];

                              return Row(
                                children: List.generate(stages.length * 2 - 1, (index) {
                                  if (index.isOdd) {
                                    final prevIdx = index ~/ 2;
                                    final isDone = stages[prevIdx]['done'] as bool;
                                    return Expanded(
                                      child: Container(
                                        height: 2,
                                        color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                      ),
                                    );
                                  }

                                  final stageIdx = index ~/ 2;
                                  final s = stages[stageIdx];
                                  final isDone = s['done'] as bool;
                                  final isCurrent = s['current'] as bool;

                                  return Expanded(
                                    flex: 3,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 16,
                                          height: 16,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCurrent
                                              ? const Color(0xFF059669)
                                              : isDone
                                                  ? const Color(0xFFECFDF5)
                                                  : const Color(0xFFF1F5F9),
                                          border: Border.all(
                                            color: isCurrent
                                                ? const Color(0xFF059669)
                                                : isDone
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFCBD5E1),
                                            width: isCurrent ? 2 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: isDone
                                              ? const Icon(Icons.check, size: 10, color: Color(0xFF059669))
                                              : isCurrent
                                                  ? Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: const BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : Text(
                                                      '${stageIdx + 1}',
                                                      style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                                                    ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        s['name'] as String,
                                        style: TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                          color: isCurrent
                                              ? const Color(0xFF059669)
                                              : isDone
                                                  ? const Color(0xFF334155)
                                                  : const Color(0xFF94A3B8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Outdoor Local Weather Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildOutdoorWeatherCard(farmProvider),
            ),

            const SizedBox(height: 16),

            // Telemetry Grid Section (CF2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'VI KHÍ HẬU THỜI GIAN THỰC (CF2)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text(
                        '10s/lần',
                        style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Temperature Safe Range Visual Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTemperatureRangeCard(context, zone),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.20,
                children: [
                  _buildSensorCard(
                    context: context,
                    title: 'Độ ẩm đất (Soil)',
                    value: zone.telemetryIsFresh ? '${zone.currentSoilMoisture}%' : '—',
                    target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
                    icon: Icons.water_drop,
                    iconColor: const Color(0xFF0284C7),
                    bgColor: const Color(0xFFF0F9FF),
                    isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : zone.currentSoilMoisture < 60,
                    history: const [58, 60, 62, 59, 56, 54, 52, 55],
                    unit: '%',
                  ),
                  _buildSensorCard(
                    context: context,
                    title: 'Nhiệt độ không khí',
                    value: zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—',
                    target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
                    icon: Icons.thermostat,
                    iconColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFF7ED),
                    isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : zone.currentTemp > 28 || zone.currentTemp < 18,
                    history: const [24, 25, 27, 29, 31, 30.5, 29, 28],
                    unit: '°C',
                  ),
                  _buildSensorCard(
                    context: context,
                    title: 'Độ ẩm không khí',
                    value: zone.telemetryIsFresh ? '${zone.currentHumidity}%' : '—',
                    target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
                    icon: Icons.cloud,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFF0FDF4),
                    isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : false,
                    history: const [78, 76, 74, 70, 68, 72, 75, 74],
                    unit: '%',
                  ),
                  _buildSensorCard(
                    context: context,
                    title: 'Ánh sáng (Lux)',
                    value: zone.telemetryIsFresh ? '${zone.currentLux.toInt()} lx' : '—',
                    target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
                    icon: Icons.wb_sunny,
                    iconColor: const Color(0xFFCA8A04),
                    bgColor: const Color(0xFFFEFCE8),
                    isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : false,
                    history: const [300, 420, 560, 890, 720, 610, 480, 520],
                    unit: 'lx',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Control Section (CF3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'ĐIỀU KHIỂN RƠ-LE BƠM/QUẠT (CF3)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    farmProvider.currentRole == 'FARMER' ? 'Hạn mức: 15p' : 'Toàn quyền',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: farmProvider.currentRole == 'OWNER' ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: farmProvider.currentZoneActuators.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final act = farmProvider.currentZoneActuators[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: act.isRunning ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                        width: act.isRunning ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: act.isRunning ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            act.actuatorType == 'PUMP'
                                ? Icons.water
                                : act.actuatorType == 'FAN'
                                    ? Icons.wind_power
                                    : act.actuatorType == 'VALVE'
                                        ? Icons.tune
                                        : Icons.lightbulb,
                            color: act.isRunning ? const Color(0xFF059669) : const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(act.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text(
                                act.isRunning ? 'Đang bật (${act.remainingMinutes} phút còn lại)' : 'Đang tắt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: act.isRunning ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                  fontWeight: act.isRunning ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: act.isRunning,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (_) {
                            if (farmProvider.currentRole != 'OWNER') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Phân quyền Slide 6: Chỉ Chủ trang trại (Owner) mới có quyền bật/tắt thiết bị chấp hành!'),
                                  backgroundColor: Color(0xFFE11D48),
                                ),
                              );
                              return;
                            }
                            farmProvider.toggleActuator(act.actuatorId);
                          },
                        ),

                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ─── FE-ALIGNED ECOSYSTEM SOLUTIONS CARDS (Solutions Ribbon) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'HỆ SINH THÁI NÔNG NGHIỆP SỐ (FE ECOSYSTEM)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('VietGAP 4.0', style: TextStyle(color: Color(0xFF065F46), fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
                children: [
                  // Sol 1: GIS Map
                  _buildEcosystemFeatureCard(
                    icon: Icons.map_outlined,
                    iconBg: const Color(0xFF062326),
                    iconColor: const Color(0xFF10B981),
                    title: 'Bản Đồ GIS',
                    subtitle: 'Phân tầng Farm ➔ Lô ➔ Zone',
                  ),
                  // Sol 2: Hardware LoRa
                  _buildEcosystemFeatureCard(
                    icon: Icons.cell_tower,
                    iconBg: const Color(0xFF065F46),
                    iconColor: Colors.white,
                    title: 'Trạm LoRa 2.5km',
                    subtitle: 'Pin mặt trời 3 năm liên tục',
                  ),
                  // Sol 3: Auto Microclimate
                  _buildEcosystemFeatureCard(
                    icon: Icons.water_drop_outlined,
                    iconBg: const Color(0xFF0284C7),
                    iconColor: Colors.white,
                    title: 'Tự Động Vi Khí Hậu',
                    subtitle: 'Lập lịch Cron & IF-THEN',
                  ),
                  // Sol 4: Electronic Contract
                  _buildEcosystemFeatureCard(
                    icon: Icons.verified_user_outlined,
                    iconBg: const Color(0xFFD97706),
                    iconColor: Colors.white,
                    title: 'Hợp Đồng Điện Tử',
                    subtitle: 'Cọc 30% - Nghiệm thu 70%',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── FE-ALIGNED TRUST NUMBERS BANNER ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF062326), Color(0xFF0B3A36)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF062326).withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        children: [
                          Text('1,200+', style: TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 1),
                          Text('Node Cảm biến', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                        ],
                      ),
                    ),
                    Container(height: 24, width: 1, color: Colors.white24),
                    const Expanded(
                      child: Column(
                        children: [
                          Text('500+ ha', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 1),
                          Text('Chuẩn VietGAP', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                        ],
                      ),
                    ),
                    Container(height: 24, width: 1, color: Colors.white24),
                    const Expanded(
                      child: Column(
                        children: [
                          Text('-35%', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 1),
                          Text('Chi phí Phân & Nước', style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // Helper for FE Ecosystem Feature Card
  Widget _buildEcosystemFeatureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Outdoor Local Weather Card
  Widget _buildOutdoorWeatherCard(FarmProvider farmProvider) {
    final farm = farmProvider.currentFarm;
    final weather = farmProvider.farmWeather;
    final isLoading = farmProvider.isLoadingWeather;

    final locationName = farm.province.isNotEmpty
        ? (farm.district.isNotEmpty ? '${farm.district}, ${farm.province}' : farm.province)
        : (farm.name.isNotEmpty ? farm.name : 'Vị trí trang trại');

    final hasWeatherData = weather != null && weather['temperature'] != null;
    final outdoorTemp = hasWeatherData
        ? '${(weather['temperature'] as num).toStringAsFixed(1)}°C'
        : (isLoading ? '--°C' : 'Chưa có DL');

    final weatherCondition = hasWeatherData
        ? (weather['weatherDescription']?.toString() ?? 'Khí hậu địa phương')
        : (isLoading ? 'Đang cập nhật thời tiết...' : 'Thời tiết không khả dụng');

    final rainProb = hasWeatherData && weather['precipitationProbability'] != null
        ? '${(weather['precipitationProbability'] as num).toInt()}%'
        : '--';

    final outdoorHumidity = hasWeatherData && weather['humidity'] != null
        ? '${(weather['humidity'] as num).toInt()}%'
        : '--';

    final windSpeed = hasWeatherData && weather['windSpeed'] != null
        ? '${(weather['windSpeed'] as num).toStringAsFixed(1)} km/h'
        : '--';

    final uvIndex = hasWeatherData
        ? 'Dữ liệu trạm Open-Meteo theo vị trí hiệu lực'
        : 'Chưa có dữ liệu thời tiết thực tế cho tọa độ này';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Location & Weather Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_cloudy_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'THỜI TIẾT NGOÀI TRỜI (TRẠM ĐỊA PHƯƠNG)',
                            style: TextStyle(
                              color: Color(0xFF99F6E4),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Live', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      locationName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Big Temp
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    outdoorTemp,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weatherCondition,
                    style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 9.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.water_drop_outlined, 'Mưa', rainProb))),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.opacity, 'Độ ẩm', outdoorHumidity))),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.air, 'Gió', windSpeed))),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.wb_sunny_outlined, 'Trạm', hasWeatherData ? 'OpenMeteo' : '--'))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 11, color: Color(0xFF99F6E4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  uvIndex,
                  style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 9.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMiniItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF99F6E4), size: 12),
        const SizedBox(width: 3),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 8),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Visual Temperature Safe-Zone Range Card
  Widget _buildTemperatureRangeCard(BuildContext context, dynamic zone) {
    if (!zone.telemetryIsFresh || !zone.cropContextIsDbBacked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Text(!zone.telemetryIsFresh ? 'Chưa có telemetry nhiệt độ mới từ DB để đánh giá vùng an toàn.' : 'Chưa có ngưỡng nhiệt độ theo mùa vụ từ DB để đánh giá vùng an toàn.', style: const TextStyle(fontSize: 12, color: Color(0xFFB45309))),
      );
    }
    final double currentT = (zone.currentTemp as num).toDouble();
    const double minSafe = 18.0;
    const double maxSafe = 28.0;
    const double scaleMin = 10.0;
    const double scaleMax = 40.0;

    final isOptimal = currentT >= minSafe && currentT <= maxSafe;
    final isTooHot = currentT > maxSafe;

    // Calculate clamped fraction for marker on scale [10, 40]
    final double markerPercent = ((currentT - scaleMin) / (scaleMax - scaleMin)).clamp(0.05, 0.95);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOptimal ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
          width: isOptimal ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isOptimal
                            ? const Color(0xFFECFDF5)
                            : (isTooHot ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune,
                        size: 14,
                        color: isOptimal
                            ? const Color(0xFF059669)
                            : (isTooHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'DẢI NHIỆT ĐỘ AN TOÀN VIETGAP',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showThresholdSettingsModal(context, zone),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOptimal
                        ? const Color(0xFFECFDF5)
                        : (isTooHot ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOptimal
                          ? const Color(0xFF10B981)
                          : (isTooHot ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOptimal
                            ? '✓ Chuẩn'
                            : (isTooHot ? '⚠️ > 28°C' : '⚠️ < 18°C'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: isOptimal
                              ? const Color(0xFF059669)
                              : (isTooHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_note, size: 13, color: isOptimal ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Visual Gauge Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Safe zone is from (18 - 10) / (40 - 10) = 8/30 ≈ 26.7% to (28 - 10) / (40 - 10) = 18/30 = 60%
              const leftPercent = (minSafe - scaleMin) / (scaleMax - scaleMin);
              const rightPercent = (maxSafe - scaleMin) / (scaleMax - scaleMin);

              return Column(
                children: [
                  // Range Track
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Full track
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Danger low zone
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: width * leftPercent,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFBFDBFE),
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                          ),
                        ),
                      ),
                      // Optimal Safe Zone (VietGAP)
                      Positioned(
                        left: width * leftPercent,
                        top: 0,
                        bottom: 0,
                        width: width * (rightPercent - leftPercent),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF86EFAC),
                          ),
                          child: const Center(
                            child: Text(
                              'DẢI TỐI ƯU',
                              style: TextStyle(
                                fontSize: 7.5,
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Danger high zone
                      Positioned(
                        left: width * rightPercent,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFECACA),
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                          ),
                        ),
                      ),
                      // Current Value Indicator Pin
                      Positioned(
                        left: (width * markerPercent) - 6,
                        top: -3,
                        child: Container(
                          width: 12,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text('10°C (Lạnh)', style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)), maxLines: 1),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                        ),
                        child: const Text(
                          'Chuẩn: 18°C - 28°C',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                      const Flexible(
                        child: Text('40°C (Nóng)', style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)), maxLines: 1, textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
          // Explanation line & Quick action
          InkWell(
            onTap: () => _showThresholdSettingsModal(context, zone),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 13, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hiện tại: $currentT°C • Quạt bật khi > 28°C • Bấm để chỉnh ngưỡng',
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 14, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard({
    required BuildContext context,
    required String title,
    required String value,
    required String target,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool? isWarning,
    required List<double> history,
    required String unit,
  }) {
    return InkWell(
      onTap: history.isNotEmpty
          ? () => _showSensorHistoryModal(
                context,
                title,
                value,
                unit,
                icon,
                iconColor,
                history,
              )
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWarning == true ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
            width: isWarning == true ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 15),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isWarning == true ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: value == '—' || isWarning == null ? const Color(0xFFFFFBEB) : isWarning == true ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value == '—' ? 'Thiếu dữ liệu' : isWarning == null ? 'Thiếu ngưỡng DB' : isWarning == true ? 'Cảnh báo' : 'Ổn định',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: value == '—' || isWarning == null ? const Color(0xFFB45309) : isWarning == true ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              target,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showSensorHistoryModal(
    BuildContext context,
    String title,
    String currentValue,
    String unit,
    IconData icon,
    Color iconColor,
    List<double> history,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final spots = history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
        final minY = (history.reduce((a, b) => a < b ? a : b) * 0.9).floorToDouble();
        final maxY = (history.reduce((a, b) => a > b ? a : b) * 1.1).ceilToDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                        Text('Giá trị tức thời: $currentValue', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('24 giờ qua', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('BIỂU ĐỒ DIỄN BIẾN THEO THỜI GIAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 1,
                      getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, meta) {
                            final hours = ['00h', '03h', '06h', '09h', '12h', '15h', '18h', '21h'];
                            final idx = v.toInt();
                            if (idx >= 0 && idx < hours.length) {
                              return Text(hours[idx], style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (history.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: iconColor,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: iconColor.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dữ liệu vi khí hậu được tự động thu thập từ Sensor Node ESP32 mỗi 10 giây qua MQTT Broker.',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Modal Chọn Nông Trại Khác ───
  void _showFarmSelectorModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.corporate_fare, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chọn Nông Trại Canh Tác',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showQuickAddFarmDialog(context, provider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Thêm Farm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Chuyển đổi giữa các cơ sở sản xuất thuộc doanh nghiệp.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                const SizedBox(height: 12),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: provider.farms.map((farm) {
                      final isSelected = farm.farmId == provider.selectedFarmId;
                      final farmZones = provider.allZones.where((z) => z.farmId == farm.farmId).length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.agriculture, color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B)),
                            ),
                            title: Text(farm.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A))),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(farm.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text('$farmZones nhà màng • ${(farm.totalAreaM2 / 10000).toStringAsFixed(1)} ha', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22)
                                : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
                            onTap: () {
                              provider.selectFarm(farm.farmId);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã chuyển sang: ${farm.name}'),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Modal Chọn / Lọc Thửa Đất (Field) ───
  void _showFieldSelectorModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final fields = provider.fieldsForCurrentFarm;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.layers_outlined, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn Thửa Đất (Field)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Thuộc: ${provider.currentFarm.name}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showQuickAddFieldDialog(context, provider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text(
                        'Thêm Lô',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Option: Tất cả các thửa
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: provider.selectedFieldId == null ? const Color(0xFFF0F9FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: provider.selectedFieldId == null ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            width: provider.selectedFieldId == null ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: const Icon(Icons.select_all, color: Color(0xFF0284C7)),
                            title: const Text('Tất cả các thửa đất', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text('Hiển thị toàn bộ ${provider.allZones.where((z) => z.farmId == provider.selectedFarmId).length} nhà màng trong trang trại', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            trailing: provider.selectedFieldId == null
                                ? const Icon(Icons.check_circle, color: Color(0xFF0284C7), size: 20)
                                : null,
                            onTap: () {
                              provider.selectField(null);
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ),

                      ...fields.map((field) {
                        final isSelected = field.fieldId == provider.selectedFieldId;
                        final fieldZones = provider.allZones.where((z) => z.fieldId == field.fieldId).length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: const Icon(Icons.landscape_outlined, color: Color(0xFF0369A1)),
                              title: Text(field.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A))),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(field.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text('$fieldZones nhà màng • ${(field.areaM2 / 10000).toStringAsFixed(1)} ha', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                                ],
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Color(0xFF0284C7), size: 20)
                                  : null,
                              onTap: () {
                                provider.selectField(field.fieldId);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã lọc theo thửa: ${field.name}'),
                                    backgroundColor: const Color(0xFF0284C7),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Modal Chọn / Chuyển Nhà Màng (Zone) ───
  void _showZoneSelectorModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final zones = provider.zones;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn Nhà Màng Canh Tác (Zone)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Trang trại: ${provider.currentFarm.name}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        CropProfilesScreen.showCreateZone(context, provider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text(
                        'Thêm Zone',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: zones.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final z = zones[index];
                      final isSelected = index == provider.selectedZoneIndex;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.eco, color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B), size: 20),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    z.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('ĐANG XEM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text('Cây trồng: ${z.currentCrop} • ${z.currentStage}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text('${(z.areaM2).toStringAsFixed(0)} m²', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                                    const SizedBox(width: 8),
                                    Text('• Thửa: ${z.fieldName}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22)
                                : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
                            onTap: () {
                              provider.selectZone(index);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đang hiển thị dữ liệu: ${z.name}'),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Modal Thêm Nhanh Nông Trại Mới ───
  void _showQuickAddFarmDialog(BuildContext context, FarmProvider provider) {
    final nextNum = provider.farms.length + 1;
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    double currentLat = 11.8341;
    double currentLng = 108.5724;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.add_business, color: Color(0xFF10B981), size: 24),
                      SizedBox(width: 10),
                      Text('Thêm Nông Trại Mới (Farm)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Khởi tạo cơ sở sản xuất mới và định vị bản đồ số GIS.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  const Text('Tên Nông Trại *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Địa Chỉ Thực Địa *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: addressCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 14),

                  // Bản đồ số GIS Vệ tinh thực tế (Real Satellite Map Picker)
                  Row(
                    children: [
                      const Icon(Icons.satellite_alt, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Vị Trí & Ranh Giới GIS',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Chạm bản đồ để dời tâm', style: TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MiniGISMapPicker(
                    initialCenter: LatLng(currentLat, currentLng),
                    level: 'FARM',
                    height: 250,
                    onCenterChanged: (newCoord) {
                      currentLat = newCoord.latitude;
                      currentLng = newCoord.longitude;
                    },
                    onAddressResolved: (newAddress) {
                      // Cập nhật trực tiếp — KHÔNG dùng setModalState để tránh rebuild lại map
                      if (addressCtrl.text != newAddress) {
                        addressCtrl.text = newAddress;
                      }
                    },
                    onRegionNameResolved: (regionShortName) {
                      final newName = 'Nông trại CNC $regionShortName (Cơ sở 0$nextNum)';
                      if (nameCtrl.text != newName) {
                        nameCtrl.text = newName;
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Huỷ', style: TextStyle(color: Color(0xFF475569))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final name = nameCtrl.text.trim().isEmpty ? 'Nông trại 0$nextNum' : nameCtrl.text.trim();
                            final address = addressCtrl.text.trim().isEmpty ? 'Lâm Đồng' : addressCtrl.text.trim();

                            provider.addFarm(
                              name: name,
                              address: address,
                              latitude: currentLat,
                              longitude: currentLng,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Đã tạo thành công nông trại: "$name"!'),
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Tạo Nông Trại', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  // ─── Modal Thêm Nhanh Thửa Đất (Field) Mới ───
  void _showQuickAddFieldDialog(BuildContext context, FarmProvider provider) {
    final nextNum = provider.fieldsForCurrentFarm.length + 1;
    final nameCtrl = TextEditingController(text: 'Lô đất C$nextNum (Khu Canh Tác Mới)');
    final descCtrl = TextEditingController(text: 'Quy hoạch cụm nhà màng thông minh chuẩn VietGAP');
    final areaCtrl = TextEditingController(text: '12000');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        List<LatLng>? fieldPolygon;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.add_chart, color: Color(0xFF0284C7), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Thêm Thửa Đất / Phân Khu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('Trực thuộc: ${provider.currentFarm.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Tên Thửa Đất / Lô Đất *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('Mô Tả Quy Hoạch / Đất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('Diện Tích Thửa (m²) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: areaCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bản đồ số GIS Vệ tinh phân khu (Field GIS Map)
                    Row(
                      children: [
                        const Icon(Icons.satellite_alt, size: 16, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Tọa Độ & Ranh Giới Thửa Đất (GIS)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Thửa đất (Field)', style: TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MiniGISMapPicker(
                      initialCenter: LatLng(provider.currentFarm.latitude, provider.currentFarm.longitude),
                      level: 'FIELD',
                      existingPolygons: provider.fieldsForCurrentFarm
                          .where((f) => f.polygon != null && f.polygon!.isNotEmpty)
                          .map((f) => {
                                'name': f.name,
                                'polygon': f.polygon,
                              })
                          .toList(),
                      height: 250,
                      onPolygonChanged: (pts) {
                        fieldPolygon = pts;
                      },
                      onAreaCalculated: (areaM2) {
                        areaCtrl.text = areaM2.toStringAsFixed(0);
                      },
                      onRegionNameResolved: (regionShortName) {
                        final newName = 'Lô đất C$nextNum - Khu $regionShortName';
                        if (nameCtrl.text != newName) {
                          nameCtrl.text = newName;
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Huỷ', style: TextStyle(color: Color(0xFF475569))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              // Kiểm tra chống chọn đè lên Thửa đất (Field) khác của Farm
                              if (fieldPolygon != null && fieldPolygon!.length >= 3) {
                                bool isInsidePoly(LatLng pt, List<LatLng> poly) {
                                  final double px = pt.longitude;
                                  final double py = pt.latitude;
                                  bool inside = false;
                                  for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
                                    final double xi = poly[i].longitude;
                                    final double yi = poly[i].latitude;
                                    final double xj = poly[j].longitude;
                                    final double yj = poly[j].latitude;
                                    if (((yi > py) != (yj > py)) &&
                                        (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                                      inside = !inside;
                                    }
                                  }
                                  return inside;
                                }

                                final otherFields = provider.fieldsForCurrentFarm
                                    .where((f) => f.polygon != null && f.polygon!.length >= 3);
                                for (final of in otherFields) {
                                  final pts = of.polygon!;
                                  final isOverlapping = fieldPolygon!.any((pt) => isInsidePoly(pt, pts)) ||
                                      pts.any((pt) => isInsidePoly(pt, fieldPolygon!));
                                  if (isOverlapping) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('⚠️ Ranh giới đang chồng đè lên "${of.name}"! Không thể tạo.'),
                                        backgroundColor: const Color(0xFFEF4444),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                    return;
                                  }
                                }
                              }

                              final name = nameCtrl.text.trim().isEmpty ? 'Lô đất 0$nextNum' : nameCtrl.text.trim();
                              final desc = descCtrl.text.trim().isEmpty ? 'Khu quy hoạch chuẩn VietGAP' : descCtrl.text.trim();
                              final area = double.tryParse(areaCtrl.text) ?? 10000.0;

                              provider.addField(
                                farmId: provider.selectedFarmId,
                                name: name,
                                description: desc,
                                areaM2: area,
                                polygon: fieldPolygon,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🎉 Đã tạo thành công thửa đất: "$name"!'),
                                  backgroundColor: const Color(0xFF0284C7),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Tạo Thửa Đất', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
  },
);
  }

  // ─── Modal Cài Đặt Ngưỡng An Toàn & Kích Hoạt Thiết Bị (Threshold Setting) ───
  void _showThresholdSettingsModal(BuildContext context, dynamic zone) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    double minTemp = 18.0;
    double maxTemp = 28.0;
    double minSoil = 60.0;
    double maxSoil = 80.0;
    bool autoFan = true;
    bool autoPump = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cài Đặt Ngưỡng Tự Động (AutoRule)',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${zone.name} • Tiêu chuẩn VietGAP',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nhiệt độ không khí
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.thermostat, color: Color(0xFFEA580C), size: 16),
                                SizedBox(width: 6),
                                Text('Dải nhiệt độ tối ưu:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Text(
                              '${minTemp.toInt()}°C - ${maxTemp.toInt()}°C',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEA580C)),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(minTemp, maxTemp),
                          min: 10,
                          max: 38,
                          divisions: 28,
                          activeColor: const Color(0xFFEA580C),
                          inactiveColor: const Color(0xFFFED7AA),
                          labels: RangeLabels('${minTemp.toInt()}°C', '${maxTemp.toInt()}°C'),
                          onChanged: (values) {
                            setModalState(() {
                              minTemp = values.start;
                              maxTemp = values.end;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tự bật Quạt đối lưu khi > Max:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Switch(
                              value: autoFan,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) => setModalState(() => autoFan = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Độ ẩm đất
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.water_drop, color: Color(0xFF0284C7), size: 16),
                                SizedBox(width: 6),
                                Text('Dải độ ẩm đất (Soil):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Text(
                              '${minSoil.toInt()}% - ${maxSoil.toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(minSoil, maxSoil),
                          min: 30,
                          max: 95,
                          divisions: 65,
                          activeColor: const Color(0xFF0284C7),
                          inactiveColor: const Color(0xFFBAE6FD),
                          labels: RangeLabels('${minSoil.toInt()}%', '${maxSoil.toInt()}%'),
                          onChanged: (values) {
                            setModalState(() {
                              minSoil = values.start;
                              maxSoil = values.end;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tự bật Bơm tưới khi < Min:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            Switch(
                              value: autoPump,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) => setModalState(() => autoPump = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Nút Lưu và Nút Mở trang AutoRule đầy đủ
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SchedulesAutomationScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            foregroundColor: const Color(0xFF0284C7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.flash_on, size: 16),
                          label: const Text('Tất cả AutoRule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final error = await provider.updateZoneThresholds(
                              zoneId: zone.zoneId,
                              maxTemp: maxTemp,
                              minSoil: minSoil,
                              maxSoil: maxSoil,
                            );
                            if (error != null) {
                              messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)));
                              return;
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('✅ Đã lưu cấu hình ngưỡng cho ${zone.name}: Nhiệt độ ${minTemp.toInt()}–${maxTemp.toInt()}°C, Độ ẩm ${minSoil.toInt()}–${maxSoil.toInt()}%!'),
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Lưu Ngưỡng', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

