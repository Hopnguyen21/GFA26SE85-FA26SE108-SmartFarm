import 'package:flutter/material.dart';
import '../support/support_requests_screen.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';

import 'zone_contract_forms.dart';

part 'parts/contracts_depreciation_screen_contracts_tab.dart';
part 'parts/contracts_depreciation_screen_depreciations_tab.dart';
part 'parts/contracts_depreciation_screen_alerts_tab.dart';
part 'parts/contracts_depreciation_screen_actions.dart';
part 'parts/contracts_depreciation_screen_common.dart';

class ContractsDepreciationScreen extends StatefulWidget {
  final String? initialZoneId;
  final String? initialFarmId;
  final int initialTabIndex;

  /// Mở từ Zone Detail: MỌI tab (hợp đồng, khấu hao, cảnh báo hết hạn) và mọi form tạo mới chỉ dùng Zone này và không đổi sang Zone
  /// khác. Không truyền = quản lý cấp Farm (nhiều Zone).
  final ZoneModel? lockedZone;

  const ContractsDepreciationScreen({
    super.key,
    this.initialZoneId,
    this.initialFarmId,
    this.initialTabIndex = 0,
    this.lockedZone,
  });

  @override
  State<ContractsDepreciationScreen> createState() => _ContractsDepreciationScreenState();
}

class _ContractsDepreciationScreenState extends State<ContractsDepreciationScreen> with SingleTickerProviderStateMixin {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _isLoading = false;
  List<ZoneContractModel> _contracts = [];
  List<DeviceDepreciationModel> _depreciations = [];
  List<ExpiringContractAlertModel> _expiringAlerts = [];

  String? _selectedFarmId;
  String? _selectedZoneId;
  String _contractStatusFilter = 'ALL';
  String _depreciationStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _selectedFarmId = widget.lockedZone?.farmId ?? widget.initialFarmId;
    _selectedZoneId = widget.lockedZone?.zoneId ?? widget.initialZoneId;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contracts = await ContractApi.getZoneContracts(farmId: _selectedFarmId, zoneId: _selectedZoneId);
      final depreciations = await ContractApi.getDeviceDepreciations(farmId: _selectedFarmId, zoneId: _selectedZoneId);
      final alerts = await ContractApi.getExpiringContracts(
        farmId: _selectedFarmId,
        zoneId: widget.lockedZone?.zoneId,
        daysThreshold: 30,
      );
      // Ngữ cảnh Zone: lọc lại phía app theo zoneId để chắc chắn không lộ dữ liệu Zone khác (kể cả khi API cũ chưa hỗ trợ lọc).
      final zid = widget.lockedZone?.zoneId.toLowerCase();
      bool inZone(String id) => zid == null || id.toLowerCase() == zid;

      if (mounted) {
        setState(() {
          _contracts = [
            for (final c in contracts)
              if (inZone(c.zoneId)) c,
          ];
          _depreciations = [
            for (final d in depreciations)
              if (inZone(d.zoneId)) d,
          ];
          _expiringAlerts = [
            for (final a in alerts)
              if (inZone(a.zoneId)) a,
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không tải được hợp đồng/khấu hao: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: const Color(0xFFDC2626),
            action: SnackBarAction(label: 'Thử lại', textColor: Colors.white, onPressed: _loadData),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────
  // UI Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final isOwner = provider.currentRole == 'OWNER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hợp Đồng Thuê & Khấu Hao',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text('Zone Contracts & Device Depreciation', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Hợp Đồng (${_contracts.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_down, size: 16),
                  const SizedBox(width: 6),
                  Text('Khấu Hao (${_depreciations.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: _expiringAlerts.isNotEmpty,
                    label: Text('${_expiringAlerts.length}'),
                    backgroundColor: const Color(0xFFEF4444),
                    child: const Icon(Icons.alarm, size: 16),
                  ),
                  const SizedBox(width: 6),
                  const Text('Sắp Hết Hạn'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildContractsTab(provider, isOwner),
                _buildDepreciationsTab(provider, isOwner),
                _buildExpiringAlertsTab(provider),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(provider, isOwner),
    );
  }

  Widget? _buildFloatingActionButton(FarmProvider provider, bool isOwner) {
    final currentTab = _tabController.index;
    final isTech = provider.currentRole == 'TECHNICIAN';
    if (currentTab == 0 && isOwner) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
        label: const Text('Gửi yêu cầu hỗ trợ kỹ thuật', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateContractDialog(provider),
      );
    } else if (currentTab == 1 && (isOwner || isTech)) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add, color: Color(0xFF10B981)),
        label: const Text('Thêm Hồ Sơ Khấu Hao', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateDepreciationDialog(provider),
      );
    }
    return null;
  }

  // ─────────────────────────────────────────
  // Modals & Dialogs
  // ─────────────────────────────────────────
}
