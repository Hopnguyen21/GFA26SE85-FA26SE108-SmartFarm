import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import '../../core/widgets/mini_gis_map_picker.dart';
import '../farms/farm_create_logic.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../tasks/alerts_tasks_screen.dart';
import '../zones/zone_detail_screen.dart';
import '../zones/widgets/actuator_feedback.dart';
import '../crops/crop_profiles_screen.dart';
import '../irrigation/schedules_automation_screen.dart';
import '../support/support_requests_screen.dart';
import '../inventory/inventory_screen.dart';
import '../ai/ai_screen.dart';
import '../contracts/contracts_depreciation_screen.dart';
import '../cf1/cf1_progress_screen.dart';
import '../../core/widgets/dispose_later.dart';
import '../zones/widgets/emergency_stop_button.dart';
import 'widgets/zone_ai_advice_card.dart';

part 'parts/home_screen_top_banners.dart';
part 'parts/home_screen_owner_actions.dart';
part 'parts/home_screen_ai_crop.dart';
part 'parts/home_screen_climate_control.dart';
part 'parts/home_screen_ecosystem.dart';
part 'parts/home_screen_weather_cards.dart';
part 'parts/home_screen_sensor_cards.dart';
part 'parts/home_screen_selectors.dart';
part 'parts/home_screen_quick_add.dart';
part 'parts/home_screen_thresholds.dart';

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
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Nút đổi vai trò – chỉ hiện trong chế độ DEMO (khi chưa đăng nhập bằng JWT)
          if (!kReleaseMode && !ApiService.isAuthenticated)
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
                : Icon(Icons.sync, color: farmProvider.isApiConnected ? const Color(0xFF10B981) : Colors.white70),
            tooltip: farmProvider.isApiConnected
                ? 'API Đã kết nối (Chạm để đồng bộ)'
                : 'API Ngoại tuyến (Chạm để kết nối lại)',
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
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsTasksScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: farmProvider.fetchFromApi,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._farmSelectorSection(context, farmProvider, zone),
              ..._heroBannerSection(context, farmProvider, zone),
              ..._ownerQuickActionsSection(context, farmProvider, zone),
              ..._aiRecommendationSection(context, farmProvider, zone),
              ..._activeCropSection(context, farmProvider, zone),
              ..._climateSection(context, farmProvider, zone),
              ..._quickControlSection(context, farmProvider, zone),
              ..._ecosystemSection(context, farmProvider, zone),
            ],
          ),
        ),
      ),
    );
  }
}
