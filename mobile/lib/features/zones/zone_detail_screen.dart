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
import '../crops/crop_profiles_screen.dart';
import '../contracts/contracts_depreciation_screen.dart';
import 'widgets/emergency_stop_button.dart';
import 'zone_operations_screens.dart';
import 'widgets/zone_node_summary_card.dart';
import 'widgets/zone_cultivation_info_card.dart';
import 'widgets/zone_climate_panel.dart';
import 'widgets/zone_seasons_section.dart';
import 'widgets/zone_workers_section.dart';
import 'widgets/zone_contracts_section.dart';
import 'widgets/zone_support_section.dart';
import 'widgets/zone_profile_page.dart';
import 'widgets/zone_irrigation_page.dart';
import 'widgets/actuator_feedback.dart';
import 'widgets/zone_iot_plan_tab.dart';

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

class _ZoneDetailScreenState extends State<ZoneDetailScreen> with SingleTickerProviderStateMixin {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  late TabController _tabController;
  late final bool _showAdminTab;
  // Custom simulation items edited by owner
  List<LatLng>? _editedPolygon;
  bool _isEditingGis = false;
  bool _isSavingGis = false;
  int _cultivationVersion = 0; // tăng để tải lại thẻ canh tác sau khi gắn hồ sơ/tạo vụ

  @override
  void initState() {
    super.initState();
    // Hợp đồng/Hỗ trợ kỹ thuật: backend chỉ cho Owner và Technician; Farmer không có tab này.
    final role = context.read<FarmProvider>().currentRole;
    _showAdminTab = role == 'OWNER' || role == 'TECHNICIAN';
    _tabController = TabController(length: _showAdminTab ? 5 : 4, vsync: this);
    // Thiết bị của CHÍNH Zone đang mở (không phụ thuộc Zone đang chọn ở nơi khác).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FarmProvider>().refreshCurrentZoneActuators(zoneId: widget.zone.zoneId);
    });
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
      appBar: AppBar(title: Text(widget.zone.name)),
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
              FilledButton(onPressed: provider.fetchFromApi, child: const Text('Tải lại')),
              TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Quay lại')),
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
    final live = provider.allZones.where((z) => z.zoneId.toLowerCase() == widget.zone.zoneId.toLowerCase()).firstOrNull;
    if (live == null) {
      // Zone không còn trong dữ liệu vừa tải (bị lưu trữ/xóa, mất quyền, hoặc tải lỗi): không hiển thị Zone khác, không crash.
      if (provider.isLoadingApi) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.zone.name)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return _missingZoneScaffold(provider);
    }
    final zone = live;
    final zoneActuators = provider.actuators.where((a) => a.zoneId.toLowerCase() == zone.zoneId.toLowerCase()).toList();
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 52),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: const Center(child: Text('🌱', style: TextStyle(fontSize: 26))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                zone.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      zone.currentStage,
                                      style: const TextStyle(
                                        color: Color(0xFF6EE7B7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${zone.farmName} ➔ ${zone.fieldName} ➔ Zone Chi tiết',
                                      style: const TextStyle(
                                        color: Color(0xFFFCD34D),
                                        fontSize: 11,
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
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                        content: Text(result == 'archived' ? 'Đã lưu trữ Zone.' : 'Đã cập nhật Zone.'),
                        backgroundColor: const Color(0xFF059669),
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
                      'contracts' => ContractsDepreciationScreen(lockedZone: zone),
                      'support' => SupportRequestsScreen(zone: zone),
                      _ => AiAssistantScreen(initialZoneId: zone.zoneId),
                    };
                    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
              isScrollable: _showAdminTab,
              tabAlignment: _showAdminTab ? TabAlignment.start : null,
              indicatorColor: const Color(0xFF10B981),
              indicatorWeight: 3,
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Vi khí hậu'),
                Tab(text: 'Thiết bị'),
                Tab(text: 'Canh tác'),
                Tab(text: 'Triển khai IoT'),
                if (_showAdminTab) Tab(text: 'Hợp đồng & Hỗ trợ'),
              ],
            ),
          ),

          // ─── Tab Content ───
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildClimateTab(zone, provider),
                _buildDevicesTab(context, provider, zoneActuators),
                _buildCultivationTab(context, provider, zone),
                ZoneIotPlanTab(
                  zoneId: zone.zoneId,
                  zoneName: zone.name,
                  areaM2: zone.areaM2,
                  cropName: zone.currentCrop,
                ),
                if (_showAdminTab) _buildContractsSupportTab(zone, provider),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId)),
              ),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.psychology, size: 20),
              label: const Text('Hỏi AI Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}
