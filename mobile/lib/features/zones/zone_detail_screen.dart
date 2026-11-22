import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';
import '../../core/widgets/mini_gis_map_picker.dart';
import '../../core/services/api_service.dart';
import '../ai/ai_screen.dart';
import '../support/support_requests_screen.dart';
import '../workforce/workforce_screen.dart';
// ZonePendingActionsBanner (thông báo việc đang chờ Owner) nằm trong cùng tệp trên.
import '../crops/crop_profiles_screen.dart';
import '../contracts/contracts_depreciation_screen.dart';
import '../home/widgets/zone_ai_advice_card.dart';
import 'widgets/emergency_stop_button.dart';
import 'zone_operations_screens.dart';
import 'widgets/zone_node_summary_card.dart';
import 'widgets/zone_cultivation_info_card.dart';
import 'widgets/zone_climate_panel.dart';
import 'widgets/zone_seasons_section.dart';
import 'widgets/zone_yield_card.dart';
import 'actuator_labels.dart';
import '../alerts/zone_alert_center_screen.dart';
import 'widgets/zone_workers_section.dart';
import 'widgets/zone_contracts_section.dart';
import 'widgets/zone_support_section.dart';
import 'widgets/zone_profile_page.dart';
import 'widgets/zone_irrigation_page.dart';
import 'widgets/actuator_feedback.dart';
import 'honeycomb_estimate.dart';
import 'widgets/zone_iot_plan_tab.dart';
import '../reports/parts/reports_season_summary_sheet.dart';
import '../../core/utils/user_error.dart';

part 'parts/zone_detail_screen_climate.dart';
part 'parts/zone_detail_screen_devices.dart';
part 'parts/zone_detail_screen_cultivation.dart';

class ZoneDetailScreen extends StatefulWidget {
  /// Zone được mở. Màn hình LUÔN tra lại Zone theo `zoneId` trong provider (không dùng chỉ số danh sách vì provider có
  /// danh sách đầy đủ và danh sách đã lọc theo Farm/Field). [zone] chỉ dùng để biết ID và hiển thị tạm khi dữ liệu đang tải.
  final ZoneModel zone;

  const ZoneDetailScreen({super.key, required this.zone});

  @override
  State<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends State<ZoneDetailScreen>
    with SingleTickerProviderStateMixin {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  late TabController _tabController;
  late final bool _showAdminTab;
  late final bool _isFarmer;
  // Custom simulation items edited by owner
  List<LatLng>? _editedPolygon;
  bool _isEditingGis = false;
  bool _isSavingGis = false;
  // Node đã chấm toạ độ GIS của Zone (GET /zones/{id}/devices/map-locations), vẽ trên bản đồ vị trí.
  List<MapNodeMarker> _nodeMarkers = const [];
  int _cultivationVersion =
      0; // tăng để tải lại thẻ canh tác sau khi gắn hồ sơ/tạo vụ

  @override
  void initState() {
    super.initState();
    // Hợp đồng/Hỗ trợ kỹ thuật: backend chỉ cho Owner và Technician; Farmer không có tab này.
    // Farmer chỉ xem 3 tab: Vi khí hậu, Thiết bị, Canh tác (ẩn Triển khai IoT và Hợp đồng/Hỗ trợ).
    final role = context.read<FarmProvider>().currentRole;
    _isFarmer = role == 'FARMER';
    _showAdminTab = role == 'OWNER' || role == 'TECHNICIAN';
    final tabCount = _isFarmer ? 3 : (_showAdminTab ? 5 : 4);
    _tabController = TabController(length: tabCount, vsync: this);
    // Thiết bị của CHÍNH Zone đang mở (không phụ thuộc Zone đang chọn ở nơi khác).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        context.read<FarmProvider>().refreshCurrentZoneActuators(
          zoneId: widget.zone.zoneId,
        );
    });
    _loadNodeMarkers();
    // Quay lại tab Vi khí hậu thì tải lại (toạ độ có thể vừa được cập nhật ở màn Node).
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 0) {
        _loadNodeMarkers();
      }
    });
  }

  Future<void> _loadNodeMarkers() async {
    try {
      final rows = await FarmApi.getDeviceMapLocations(widget.zone.zoneId);
      final markers = [for (final r in rows) ?MapNodeMarker.fromJson(r)];
      if (mounted) setState(() => _nodeMarkers = markers);
    } catch (_) {
      // Không có quyền/không tải được: bản đồ vẫn hiện ranh giới, chỉ không có chấm node.
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Tên người phụ trách theo quyền truy cập Zone (cùng nguồn với khu vực Nhân công); rỗng thì "Chưa phân công".
  String _workerNames(FarmProvider provider, ZoneModel zone) {
    final names = [
      for (final w in provider.getWorkersForZone(zone.zoneId))
        if (w.isActive) w.name,
    ];
    if (names.isNotEmpty) return names.join(', ');
    return zone.assignedWorkerName ?? 'Chưa phân công';
  }

  /// Trạng thái "không tìm thấy Zone" kèm thử tải lại (không lấy Zone khác thay thế).
  Widget _missingZoneScaffold(FarmProvider provider) {
    final err = provider.syncError;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: Text(
          widget.zone.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                'Không tìm thấy Zone "${widget.zone.name}" trong dữ liệu hiện tại. Zone có thể đã được lưu trữ, '
                'bạn không còn quyền truy cập, hoặc dữ liệu chưa tải được${err == null ? '' : ' ($err)'}.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: provider.fetchFromApi,
                child: const Text('Tải lại'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Quay lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    // ID là định danh ổn định; không dùng index để tránh mở nhầm Zone sau khi lọc/tải lại.
    final live = provider.allZones
        .where(
          (z) => z.zoneId.toLowerCase() == widget.zone.zoneId.toLowerCase(),
        )
        .firstOrNull;
    if (live == null) {
      // Zone không còn trong dữ liệu vừa tải (bị lưu trữ/xóa, mất quyền, hoặc tải lỗi): không hiển thị Zone khác, không crash.
      if (provider.isLoadingApi) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: const Color(0xFF062326),
            foregroundColor: Colors.white,
            title: Text(
              widget.zone.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return _missingZoneScaffold(provider);
    }
    final zone = live;
    final zoneActuators = provider.actuators
        .where((a) => a.zoneId.toLowerCase() == zone.zoneId.toLowerCase())
        .toList();
    final isOwner = provider.currentRole == 'OWNER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ─── Hero AppBar ───
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF062326),
            foregroundColor: Colors.white,
            title: Text(
              zone.name.split(' - ')[0],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(
                                0xFF34D399,
                              ).withValues(alpha: 0.4),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.eco_rounded,
                              color: Color(0xFF34D399),
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                zone.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15.5,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF34D399,
                                        ).withValues(alpha: 0.45),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 4.5,
                                          height: 4.5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF34D399),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          zone.currentStage,
                                          style: const TextStyle(
                                            color: Color(0xFF6EE7B7),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${zone.farmName} ➔ ${zone.fieldName} ➔ Zone Chi tiết',
                                      style: const TextStyle(
                                        color: Color(0xFFA7F3D0),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${zone.areaM2.toInt()} m² • Phụ trách: ${_workerNames(provider, zone)}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
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
                ),
              ),
            ),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Sửa / lưu trữ Zone',
                  onPressed: () async {
                    final result = await showEditZoneSheet(context, zone);
                    if (result == null || !context.mounted) return;
                    await provider.fetchFromApi();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result == 'archived'
                              ? 'Đã lưu trữ Zone.'
                              : 'Đã cập nhật Zone.',
                        ),
                        backgroundColor: const Color(0xFF047857),
                      ),
                    );
                    if (result == 'archived') Navigator.of(context).pop();
                  },
                ),
                // Các thao tác phụ gom vào menu để thanh tiêu đề không chật trên màn hẹp.
                PopupMenuButton<String>(
                  tooltip: 'Thêm',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    final Widget page = switch (v) {
                      'contracts' => ContractsDepreciationScreen(
                        lockedZone: zone,
                      ),
                      'support' => SupportRequestsScreen(zone: zone),
                      _ => AiAssistantScreen(initialZoneId: zone.zoneId),
                    };
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => page),
                    );
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'support',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.support_agent),
                        title: Text('Gửi yêu cầu hỗ trợ kỹ thuật'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'contracts',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.assignment_outlined),
                        title: Text('Hợp đồng & Khấu hao Zone'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ai',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.psychology_outlined),
                        title: Text('Hỏi AI về Zone này'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: !_isFarmer && _showAdminTab,
              tabAlignment: (!_isFarmer && _showAdminTab) ? TabAlignment.start : null,
              indicatorColor: const Color(0xFF34D399),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF34D399),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                const Tab(text: 'Vi khí hậu'),
                const Tab(text: 'Thiết bị'),
                const Tab(text: 'Canh tác'),
                if (!_isFarmer) const Tab(text: 'Triển khai IoT'),
                if (_showAdminTab) const Tab(text: 'Hợp đồng & Hỗ trợ'),
              ],
            ),
          ),

          // ─── Tab Content ───
          SliverFillRemaining(
            child: Column(
              children: [
                if (isOwner) ZonePendingActionsBanner(zone: zone),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildClimateTab(zone, provider),
                      _buildDevicesTab(context, provider, zoneActuators),
                      _buildCultivationTab(context, provider, zone),
                      if (!_isFarmer)
                        ZoneIotPlanTab(
                          zoneId: zone.zoneId,
                          farmId: zone.farmId,
                          zoneName: zone.name,
                          areaM2: zone.areaM2,
                          cropName: zone.currentCrop,
                          perimeterM: zone.polygon == null
                              ? null
                              : convexHullPerimeterM([
                                  for (final p in zone.polygon!)
                                    (lat: p.latitude, lng: p.longitude),
                                ]),
                        ),
                      if (_showAdminTab)
                        _buildContractsSupportTab(zone, provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId),
                ),
              ),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              icon: const Icon(
                Icons.psychology,
                size: 20,
                color: Color(0xFF34D399),
              ),
              label: const Text(
                'Hỏi AI Zone',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
