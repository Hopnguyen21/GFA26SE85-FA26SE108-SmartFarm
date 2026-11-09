import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/task_actions.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import 'alerts_tasks_screen.dart';
import 'zone_detail_screen.dart';
import '../services/api_service.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final List<_DiaryEntry> _diaryEntries = [
    _DiaryEntry(
      id: 'd-01',
      date: DateTime.now().subtract(const Duration(days: 1)),
      zone: 'Nhà màng 01 - Cà chua Beefsteak',
      activity: 'Tưới nước buổi sáng',
      note: 'Đất ổn định, rễ phát triển tốt. Độ ẩm đất khoảng 68%.',
      weather: 'Nắng nhẹ',
      icon: '💧',
    ),
    _DiaryEntry(
      id: 'd-02',
      date: DateTime.now().subtract(const Duration(days: 2)),
      zone: 'Nhà màng 01 - Cà chua Beefsteak',
      activity: 'Bón phân NPK định kỳ',
      note:
          'Bón 2kg/100m2 NPK 20-20-15 pha loãng. Cây đang ở giai đoạn ra hoa.',
      weather: 'Mát mẻ',
      icon: '🌿',
    ),
    _DiaryEntry(
      id: 'd-03',
      date: DateTime.now().subtract(const Duration(days: 3)),
      zone: 'Nhà màng 02 - Dâu tây New Zealand',
      activity: 'Kiểm tra sâu bệnh',
      note: 'Phát hiện một số lá vàng nhẹ, đã phun thuốc sinh học phòng ngừa.',
      weather: 'Nhiều mây',
      icon: '🔍',
    ),
  ];

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
    final currentFarmer = _getCurrentFarmer(provider);

    // Lấy zones được phân công cho farmer này
    final assignedZones = _getAssignedZones(provider, currentFarmer);
    final canControlPump =
        currentFarmer?.permissions.contains('CAN_CONTROL_PUMP') ?? false;
    final canLogDiary =
        currentFarmer?.permissions.contains('CAN_LOG_DIARY') ?? false;
    final canViewReports =
        currentFarmer?.permissions.contains('CAN_VIEW_REPORTS') ?? false;
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
              child: const Center(
                child: Icon(Icons.person, color: Color(0xFF10B981), size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentFarmer?.name ?? 'Nông Dân',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    currentFarmer?.role ?? 'Farmer (Thực địa)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.sync,
                    color: provider.isApiConnected
                        ? const Color(0xFF10B981)
                        : Colors.white70,
                  ),
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
                    backgroundColor: provider.isApiConnected
                        ? const Color(0xFF062326)
                        : Colors.orange[800],
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            const Tab(
              icon: Icon(Icons.home_work_outlined, size: 18),
              text: 'Khu Vực',
            ),
            Tab(
              icon: const Icon(Icons.water_drop_outlined, size: 18),
              text: canControlPump ? 'Điều Khiển' : 'Lịch Tưới',
            ),
            Tab(
              icon: const Icon(Icons.book_outlined, size: 18),
              text: canLogDiary ? 'Nhật Ký' : 'Báo Cáo',
            ),
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
  FarmerModel? _getCurrentFarmer(FarmProvider provider) {
    final farmers = provider.farmersForCurrentFarm;
    if (farmers.isEmpty) return null;

    // Lấy farmer theo thông tin người dùng đang đăng nhập từ session / JWT (ApiService)
    final email = ApiService.userEmail?.toLowerCase();
    if (email != null && email.isNotEmpty) {
      final matched = farmers
          .where(
            (f) =>
                f.email.toLowerCase() == email ||
                f.username.toLowerCase() == email,
          )
          .toList();
      if (matched.isNotEmpty) return matched.first;
    }
    return farmers.first;
  }

  List<ZoneModel> _getAssignedZones(
    FarmProvider provider,
    FarmerModel? farmer,
  ) {
    if (farmer == null) return [];
    if (farmer.assignedZoneNames.isEmpty) return provider.zones;
    return provider.allZones
        .where(
          (z) => farmer.assignedZoneNames.any(
            (name) => z.name.contains(name.split(' - ').first),
          ),
        )
        .toList();
  }

  // ─── TAB 1: ZONES ──────────────────────────────────────────────────────────
  Widget _buildZonesTab(
    BuildContext context,
    FarmProvider provider,
    List<ZoneModel> zones,
    FarmerModel? farmer,
  ) {
    final assignedTasks = provider.tasks.where((t) {
      if (farmer == null) return true;
      if (t.assignedFarmerId == farmer.farmerId) return true;
      if (t.assignedFarmerName != null &&
          t.assignedFarmerName!.contains(farmer.name))
        return true;
      if (t.assignedFarmerId == null || t.assignedFarmerId!.isEmpty) {
        return zones.any((z) => t.zoneName.contains(z.name.split(' - ').first));
      }
      return false;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF065F46).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF6EE7B7),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _LiveClock(
                        weekdayLabel: _weekdayVi,
                        style: const TextStyle(
                          color: Color(0xFF6EE7B7),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Khu vực phụ trách',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${zones.length} nhà màng',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'LoRa Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Permission badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: (farmer?.permissions ?? []).map((p) {
                    final info = _permissionInfo(p);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${info.$1} ${info.$2}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Nhiệm vụ phân công cho Farmer
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'NHIỆM VỤ ĐƯỢC GIAO HÔM NAY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${assignedTasks.where((t) => !t.isCompleted).length} việc cần làm',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (assignedTasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tất cả công việc đã hoàn thành hoặc chưa có việc mới!',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            )
          else
            ...assignedTasks.map(
              (task) => _buildFarmerTaskCard(context, provider, task),
            ),

          const SizedBox(height: 24),
          const Text(
            'NHÀ MÀNG ĐƯỢC PHÂN CÔNG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          if (zones.isEmpty)
            _buildEmptyState(
              'Chưa có khu vực nào được phân công',
              Icons.home_work_outlined,
            )
          else
            ...zones.map((zone) => _buildZoneCard(context, zone, provider)),
        ],
      ),
    );
  }

  Widget _buildFarmerTaskCard(
    BuildContext context,
    FarmProvider provider,
    TaskModel task,
  ) {
    final isHigh = task.priority == 'HIGH';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isCompleted
              ? const Color(0xFFE2E8F0)
              : (isHigh ? const Color(0xFFFECACA) : const Color(0xFFD1FAE5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: task.isCompleted
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? const Color(0xFFF1F5F9)
                            : (isHigh
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.isCompleted
                            ? 'Xong'
                            : (isHigh ? 'Khẩn cấp' : 'Bình thường'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: task.isCompleted
                              ? const Color(0xFF64748B)
                              : (isHigh
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        task.zoneName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.schedule,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      task.dueDate,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                TaskActions(task: task, isOwner: false),
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(
    BuildContext context,
    ZoneModel zone,
    FarmProvider provider,
  ) {
    final moisture = zone.currentSoilMoisture;
    final temp = zone.currentTemp;
    final humidity = zone.currentHumidity;

    Color moistureColor = !zone.telemetryIsFresh || !zone.cropContextIsDbBacked
        ? const Color(0xFFF59E0B)
        : moisture >= 60 && moisture <= 80
        ? const Color(0xFF059669)
        : moisture < 50 || moisture > 90
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () {
        final idx = provider.allZones.indexOf(zone);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ZoneDetailScreen(zone: zone, zoneIndex: idx),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1FAE5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF065F46).withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _cropEmoji(zone.currentCrop),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF065F46),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${zone.currentCrop} • ${zone.currentStage}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ],
              ),
            ),
            // Sensor data
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _sensorTile(
                        '💧',
                        'Ẩm đất',
                        zone.telemetryIsFresh
                            ? '${moisture.toStringAsFixed(1)}%'
                            : '—',
                        moistureColor,
                      ),
                      const SizedBox(width: 8),
                      _sensorTile(
                        '🌡️',
                        'Nhiệt độ',
                        zone.telemetryIsFresh
                            ? '${temp.toStringAsFixed(1)}°C'
                            : '—',
                        zone.telemetryIsFresh &&
                                zone.cropContextIsDbBacked &&
                                temp > 30
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 8),
                      _sensorTile(
                        '💨',
                        'Độ ẩm KK',
                        zone.telemetryIsFresh
                            ? '${humidity.toStringAsFixed(0)}%'
                            : '—',
                        const Color(0xFF0284C7),
                      ),
                    ],
                  ),
                  // Area indicator
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${zone.areaM2.toInt()} m²',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Moisture status indicator
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: moistureColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            !zone.telemetryIsFresh
                                ? 'Chưa có telemetry mới'
                                : !zone.cropContextIsDbBacked
                                ? 'Chưa có ngưỡng DB'
                                : moisture < 55
                                ? '⚠️ Cần tưới'
                                : moisture > 85
                                ? '💦 Đủ ẩm'
                                : '✅ Ổn định',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: moistureColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorTile(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2A: PUMP CONTROL (CAN_CONTROL_PUMP) ───────────────────────────────
  Widget _buildControlTab(
    BuildContext context,
    FarmProvider provider,
    List<ZoneModel> zones,
  ) {
    final actuators = provider.actuators;
    // Lọc actuator theo zones được phân công
    final assignedActuators = actuators
        .where((a) => zones.any((z) => z.zoneId == a.zoneId))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chỉ điều khiển thiết bị trong khu vực được phân công. Mọi hành động đều được ghi lại.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

          const Text(
            'ĐIỀU KHIỂN MÁY BƠM & THIẾT BỊ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          if (assignedActuators.isEmpty)
            _buildEmptyState(
              'Không có thiết bị nào trong khu vực của bạn',
              Icons.device_unknown,
            )
          else
            ...assignedActuators.map((actuator) {
              final zone = zones.firstWhere(
                (z) => z.zoneId == actuator.zoneId,
                orElse: () => zones.first,
              );
              return _buildActuatorControlCard(
                context,
                actuator,
                zone,
                provider,
              );
            }),

          const SizedBox(height: 20),
          // Quick Actions
          const Text(
            'TƯỚI NHANH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _quickWaterButton(context, '10 phút', 10, provider, zones),
              const SizedBox(width: 8),
              _quickWaterButton(context, '20 phút', 20, provider, zones),
              const SizedBox(width: 8),
              _quickWaterButton(context, '30 phút', 30, provider, zones),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorControlCard(
    BuildContext context,
    ActuatorModel actuator,
    ZoneModel zone,
    FarmProvider provider,
  ) {
    final isRunning = actuator.isRunning;
    final color = isRunning ? const Color(0xFF059669) : const Color(0xFF64748B);
    final bgColor = isRunning
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFF8FAFC);

    String typeIcon = '💧';
    if (actuator.actuatorType == 'FAN') typeIcon = '🌬️';
    if (actuator.actuatorType == 'GROW_LIGHT') typeIcon = '💡';
    if (actuator.actuatorType == 'VALVE') typeIcon = '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRunning ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isRunning
                ? const Color(0xFF059669).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(typeIcon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actuator.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  zone.name.split(' - ').first,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (isRunning)
                  Text(
                    '⏱ Còn ${actuator.remainingMinutes} phút',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: isRunning,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (_) => provider.toggleActuator(actuator.actuatorId),
          ),
        ],
      ),
    );
  }

  Widget _quickWaterButton(
    BuildContext context,
    String label,
    int minutes,
    FarmProvider provider,
    List<ZoneModel> zones,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Bật tất cả bơm trong zones được phân công trong N phút
          for (final zone in zones) {
            final actuators = provider.actuators.where(
              (a) => a.zoneId == zone.zoneId && a.actuatorType == 'PUMP',
            );
            for (final a in actuators) {
              if (!a.isRunning)
                provider.toggleActuator(a.actuatorId, durationMinutes: minutes);
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Đã bật tưới $label cho ${zones.length} nhà màng',
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('💧', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 2B: SCHEDULE VIEW (khi không có CAN_CONTROL_PUMP) ─────────────────
  Widget _buildScheduleViewTab(BuildContext context, FarmProvider provider) {
    final schedules = provider.schedules;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Row(
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn không có quyền điều khiển thiết bị. Chỉ xem được lịch tưới.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'LỊCH TƯỚI HÔM NAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...schedules.map((s) => _scheduleReadOnlyCard(s)),
        ],
      ),
    );
  }

  Widget _scheduleReadOnlyCard(ScheduleModel schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🕐', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${schedule.zoneName} • ${schedule.startTime} • ${schedule.durationMinutes} phút',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  schedule.daysOfWeek.join(', '),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: schedule.isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              schedule.isActive ? 'Đang kích hoạt' : 'Tắt',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: schedule.isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 3A: DIARY (CAN_LOG_DIARY) ─────────────────────────────────────────
  Widget _buildDiaryTab(
    BuildContext context,
    FarmProvider provider,
    List<ZoneModel> zones,
    FarmerModel? farmer,
  ) {
    if (_selectedZoneForDiary.isEmpty && zones.isNotEmpty) {
      _selectedZoneForDiary = zones.first.name;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Diary Button
          if (!_showAddDiaryForm)
            GestureDetector(
              onTap: () => setState(() => _showAddDiaryForm = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF065F46).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ghi Nhật Ký Canh Tác Hôm Nay',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildAddDiaryForm(context, zones),

          const Text(
            'NHẬT KÝ CANH TÁC GẦN ĐÂY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          if (_diaryEntries.isEmpty)
            _buildEmptyState(
              'Chưa có nhật ký nào. Hãy ghi lại hoạt động hôm nay!',
              Icons.book_outlined,
            )
          else
            ..._diaryEntries.map((entry) => _buildDiaryCard(entry)),
        ],
      ),
    );
  }

  Widget _buildAddDiaryForm(BuildContext context, List<ZoneModel> zones) {
    final activities = [
      'Tưới nước',
      'Bón phân',
      'Phun thuốc',
      'Kiểm tra sâu bệnh',
      'Thu hoạch',
      'Làm đất',
      'Khác',
    ];

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Ghi Nhật Ký Mới',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Zone selector
              if (zones.isNotEmpty) ...[
                const Text(
                  'Khu vực:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedZoneForDiary.isEmpty
                      ? zones.first.name
                      : _selectedZoneForDiary,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF0FDF4),
                  ),
                  items: zones
                      .map(
                        (z) => DropdownMenuItem(
                          value: z.name,
                          child: Text(
                            z.name.split(' - ').first,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedZoneForDiary = v ?? ''),
                ),
                const SizedBox(height: 10),
              ],

              // Activity selector
              const Text(
                'Hoạt động:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activities.map((a) {
                  final selected = _selectedActivity == a;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedActivity = a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF065F46)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF065F46)
                              : const Color(0xFFD1FAE5),
                        ),
                      ),
                      child: Text(
                        a,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Note
              const Text(
                'Ghi chú:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _diaryNoteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Mô tả hoạt động, tình trạng cây trồng...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _showAddDiaryForm = false;
                        _diaryNoteController.clear();
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF065F46)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Color(0xFF065F46)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_diaryNoteController.text.isNotEmpty) {
                          setState(() {
                            _diaryEntries.insert(
                              0,
                              _DiaryEntry(
                                id: 'd-${_diaryEntries.length + 1}',
                                date: DateTime.now(),
                                zone: _selectedZoneForDiary,
                                activity: _selectedActivity,
                                note: _diaryNoteController.text,
                                weather: 'Không rõ',
                                icon: _activityIcon(_selectedActivity),
                              ),
                            );
                            _showAddDiaryForm = false;
                            _diaryNoteController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Đã lưu nhật ký canh tác!'),
                              backgroundColor: Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Lưu Nhật Ký',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiaryCard(_DiaryEntry entry) {
    final diff = DateTime.now().difference(entry.date);
    final timeAgo = diff.inDays == 0
        ? 'Hôm nay'
        : diff.inDays == 1
        ? 'Hôm qua'
        : '${diff.inDays} ngày trước';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(entry.icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.activity,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      entry.zone.split(' - ').first,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.date.day}/${entry.date.month}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.note,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TAB 3B: REPORTS VIEW (khi không có CAN_LOG_DIARY) ─────────────────────
  Widget _buildReportsViewTab(
    BuildContext context,
    FarmProvider provider,
    bool canViewReports,
  ) {
    if (!canViewReports) {
      return _buildAccessDenied(
        'Bạn không có quyền xem báo cáo. Liên hệ Owner để được cấp quyền.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BÁO CÁO TÓM TẮT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _summaryReportCard(),
        ],
      ),
    );
  }

  Widget _summaryReportCard() {
    // Chỉ số liệu có thật trong ứng dụng; lượng nước và giờ bơm chưa có nguồn nên không hiển thị.
    final tasks = context.read<FarmProvider>().tasks;
    final doneTasks = tasks.where((t) => t.isCompleted).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng quan công việc',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...[
            ('✅ Tác vụ đã hoàn thành', '$doneTasks/${tasks.length} tác vụ'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UTILITY ───────────────────────────────────────────────────────────────
  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFD1FAE5)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDenied(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 40,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có quyền truy cập',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayVi(int weekday) {
    const days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return days[(weekday - 1).clamp(0, 6)];
  }

  String _cropEmoji(String crop) {
    if (crop.contains('Cà chua')) return '🍅';
    if (crop.contains('Dâu')) return '🍓';
    if (crop.contains('Ớt')) return '🫑';
    if (crop.contains('Xà lách')) return '🥬';
    if (crop.contains('Kale') || crop.contains('Cải')) return '🥦';
    if (crop.contains('Dưa')) return '🥒';
    return '🌱';
  }

  String _activityIcon(String activity) {
    switch (activity) {
      case 'Tưới nước':
        return '💧';
      case 'Bón phân':
        return '🌿';
      case 'Phun thuốc':
        return '💊';
      case 'Kiểm tra sâu bệnh':
        return '🔍';
      case 'Thu hoạch':
        return '🧺';
      case 'Làm đất':
        return '⛏️';
      default:
        return '📝';
    }
  }

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
