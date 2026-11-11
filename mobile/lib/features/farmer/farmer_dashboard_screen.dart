import 'dart:async';
import 'package:flutter/material.dart';
import '../tasks/widgets/task_actions.dart';
import '../zones/widgets/emergency_stop_button.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';
import '../tasks/alerts_tasks_screen.dart';
import '../zones/zone_detail_screen.dart';
import '../zones/widgets/actuator_feedback.dart';

part 'parts/farmer_dashboard_screen_zones.dart';
part 'parts/farmer_dashboard_screen_control.dart';
part 'parts/farmer_dashboard_screen_diary.dart';
part 'parts/farmer_dashboard_screen_common.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> with TickerProviderStateMixin {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  late TabController _tabController;
  // Nhật ký chỉ lưu tạm trên máy trong phiên này: backend chưa có API nhật ký canh tác.
  final List<_DiaryEntry> _diaryEntries = [];

  bool _showAddDiaryForm = false;
  final _diaryNoteController = TextEditingController();
  String _selectedActivity = 'Tưới nước';
  String _selectedZoneForDiary = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diaryNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final currentFarmer = provider.currentUserFarmer;

    // Lấy zones được phân công cho farmer này từ GET /users/me (zoneAccess)
    final assignedZones = provider.assignedZonesForCurrentFarmer;
    // Quyền điều khiển là quyền THEO TỪNG ZONE (zoneAccess.canControl), không phải cờ chung của Farmer.
    final canControlPump = assignedZones.any((z) => provider.canControlZone(z.zoneId));
    final canLogDiary = currentFarmer?.permissions.contains('CAN_LOG_DIARY') ?? false;
    final canViewReports = currentFarmer?.permissions.contains('CAN_VIEW_REPORTS') ?? false;
    final unreadAlerts = provider.alerts.where((a) => !a.isAcknowledged).length;
    final unreadTotal = unreadAlerts + provider.unreadNotificationCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(child: Icon(Icons.person, color: Color(0xFF10B981), size: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentFarmer?.name ?? provider.me?['fullName']?.toString() ?? 'Nông Dân',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentFarmer?.role ?? 'Nông dân Thực địa (CF2)',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: provider.isLoadingApi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.sync, color: provider.isApiConnected ? const Color(0xFF10B981) : Colors.white70),
            tooltip: provider.isApiConnected
                ? 'API Đã kết nối (Chạm để đồng bộ)'
                : 'API Ngoại tuyến (Chạm để kết nối lại)',
            onPressed: () async {
              await provider.fetchFromApi();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.isApiConnected
                          ? '✅ Đã đồng bộ dữ liệu mới nhất từ SmartFarm API'
                          : '⚠️ Không kết nối được API backend, đang dùng dữ liệu lưu tạm',
                    ),
                    duration: const Duration(seconds: 2),
                    backgroundColor: provider.isApiConnected ? const Color(0xFF062326) : Colors.orange[800],
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            const Tab(icon: Icon(Icons.home_work_outlined, size: 18), text: 'Khu Vực'),
            Tab(
              icon: const Icon(Icons.water_drop_outlined, size: 18),
              text: canControlPump ? 'Điều Khiển' : 'Lịch Tưới',
            ),
            Tab(icon: const Icon(Icons.book_outlined, size: 18), text: canLogDiary ? 'Nhật Ký' : 'Báo Cáo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Zones được phân công
          _buildZonesTab(context, provider, assignedZones, currentFarmer),
          // Tab 2: Điều khiển bơm / Lịch tưới
          canControlPump
              ? _buildControlTab(context, provider, assignedZones)
              : _buildScheduleViewTab(context, provider),
          // Tab 3: Nhật ký / Báo cáo
          canLogDiary
              ? _buildDiaryTab(context, provider, assignedZones, currentFarmer)
              : _buildReportsViewTab(context, provider, canViewReports),
        ],
      ),
    );
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────
  (String, String) _permissionInfo(String perm) {
    switch (perm) {
      case 'CAN_CONTROL_PUMP':
        return ('💧', 'Điều khiển bơm');
      case 'CAN_LOG_DIARY':
        return ('📝', 'Ghi nhật ký');
      case 'CAN_VIEW_REPORTS':
        return ('📊', 'Xem báo cáo');
      case 'CAN_CONFIG_SCHEDULE':
        return ('⏰', 'Cấu hình lịch');
      case 'CAN_MANAGE_HARDWARE':
        return ('🔧', 'Quản lý thiết bị');
      default:
        return ('✅', perm);
    }
  }
}

// ─── Local Diary Model ──────────────────────────────────────────────────────
class _DiaryEntry {
  final String id;
  final DateTime date;
  final String zone;
  final String activity;
  final String note;
  final String weather;
  final String icon;

  _DiaryEntry({
    required this.id,
    required this.date,
    required this.zone,
    required this.activity,
    required this.note,
    required this.weather,
    required this.icon,
  });
}

/// Đồng hồ trực tiếp: tự giữ bộ đếm 1 giây nên chỉ dòng chữ này được dựng lại, không phải cả màn hình.
class _LiveClock extends StatefulWidget {
  final String Function(int weekday) weekdayLabel;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;
  const _LiveClock({required this.weekdayLabel, required this.style, this.maxLines, this.overflow});

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    String two(int v) => v.toString().padLeft(2, '0');
    return Text(
      '${two(now.hour)}:${two(now.minute)}:${two(now.second)} '
      '— ${widget.weekdayLabel(now.weekday)}, ${now.day}/${now.month}/${now.year}',
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
