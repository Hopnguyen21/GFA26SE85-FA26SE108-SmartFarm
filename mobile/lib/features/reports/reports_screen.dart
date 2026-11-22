import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/user_error.dart';
import 'parts/reports_farm_overview_tab.dart';
import 'parts/reports_zones_tab.dart';
import 'parts/reports_seasons_tab.dart';
import 'parts/reports_harvest_tab.dart';
import 'parts/reports_export_sheet.dart';

/// Màn hình Báo Cáo & Thống Kê Trang Trại dành cho Chủ Trang Trại (Owner).
/// Cung cấp cái nhìn toàn diện & chính xác về:
/// 1. Tổng quan Trang trại (KPIs, tài chính, tài nguyên, công việc)
/// 2. Phân khu & Vi khí hậu (Telemetry, tiêu thụ nước/điện theo Zone)
/// 3. Mùa vụ & Tiến độ sinh trưởng (Giai đoạn, VietGAP, báo cáo vụ)
/// 4. Thu hoạch & Năng suất (Sản lượng thực tế, kg/m², so sánh vụ trước)
/// Xuất Excel đa dạng do máy chủ backend tạo.
class ReportsScreen extends StatefulWidget {
  final int initialTabIndex;

  const ReportsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _days = 30;
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _water;
  Map<String, dynamic>? _power;
  Map<String, dynamic>? _tasks;
  Map<String, dynamic>? _inventory;
  List<Map<String, dynamic>> _plantingSeasons = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime get _to => DateTime.now().toUtc();
  DateTime get _from => _to.subtract(Duration(days: _days));

  Future<void> _load() async {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    if (provider.currentRole != 'OWNER') {
      setState(() {
        _loading = false;
        _error =
            'Bạn không có quyền truy cập Báo cáo (Yêu cầu tài khoản Chủ trang trại - FarmOwner).';
      });
      return;
    }
    final farmId = provider.selectedFarmId;
    if (farmId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Chưa chọn trang trại.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ReportApi.getFarmReport(farmId, 'overview'),
        ReportApi.getFarmReport(farmId, 'water-usage', from: _from, to: _to),
        ReportApi.getFarmReport(farmId, 'electricity', from: _from, to: _to),
        ReportApi.getFarmReport(farmId, 'tasks', from: _from, to: _to),
        ReportApi.getFarmReport(farmId, 'inventory'),
        CropApi.getPlantingSeasons(farmId: farmId),
      ]);

      if (!mounted) return;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _water = results[1] as Map<String, dynamic>;
        _power = results[2] as Map<String, dynamic>;
        _tasks = results[3] as Map<String, dynamic>;
        _inventory = results[4] as Map<String, dynamic>;
        _plantingSeasons = results[5] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) {
        final msg = userFacingError(e);
        final is403 =
            msg.contains('403') ||
            msg.toLowerCase().contains('forbidden') ||
            msg.contains('không có quyền');
        setState(
          () => _error = is403
              ? 'Bạn không có quyền truy cập Báo cáo (403 Forbidden - Yêu cầu tài khoản Chủ trang trại).'
              : msg,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onFarmSelected(String farmId) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    provider.selectFarm(farmId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);
    final farmName = farmProvider.currentFarm.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        titleSpacing: 8,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Báo Cáo & Thống Kê',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              farmName,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF86EFAC),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Colors.white),
            tooltip: 'Xuất Báo Cáo Excel (.xlsx)',
            onPressed: _loading || _error != null
                ? null
                : () => showReportExportSheet(
                      context,
                      farmId: farmProvider.selectedFarmId,
                      farmName: farmName,
                      from: _from,
                      to: _to,
                    ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _loading ? null : _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF082F35),
              border: Border(
                top: BorderSide(color: Color(0xFF0D474E), width: 1),
                bottom: BorderSide(color: Color(0xFF0D474E), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF34D399),
                  width: 1.5,
                ),
              ),
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              labelColor: const Color(0xFF6EE7B7),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.insights_rounded, size: 18),
                  text: 'Tổng quan',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.grid_view_rounded, size: 18),
                  text: 'Phân khu',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.eco_rounded, size: 18),
                  text: 'Mùa vụ',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.scale_rounded, size: 18),
                  text: 'Thu hoạch',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          color: Color(0xFF047857),
                          strokeWidth: 3.5,
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Đang tổng hợp dữ liệu báo cáo...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Đồng bộ số liệu vi khí hậu, điện nước và mùa vụ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFECACA)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          size: 36,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Thử lại',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                ReportsFarmOverviewTab(
                  farmProvider: farmProvider,
                  overview: _overview,
                  water: _water,
                  power: _power,
                  tasks: _tasks,
                  inventory: _inventory,
                  days: _days,
                  onDaysChanged: (d) {
                    setState(() => _days = d);
                    _load();
                  },
                  onFarmSelected: _onFarmSelected,
                  onRefresh: _load,
                ),
                ReportsZonesTab(
                  farmProvider: farmProvider,
                  water: _water,
                  power: _power,
                  onRefresh: _load,
                ),
                ReportsSeasonsTab(
                  farmProvider: farmProvider,
                  plantingSeasons: _plantingSeasons,
                  onRefresh: _load,
                ),
                ReportsHarvestTab(
                  farmProvider: farmProvider,
                  plantingSeasons: _plantingSeasons,
                  onRefresh: _load,
                ),
              ],
            ),
    );
  }
}

/// Helper gộp tổng giá trị theo zoneName từ mảng buckets trong report.
Map<String, double> sumBucketsByZone(Map<String, dynamic>? report) {
  final out = <String, double>{};
  final buckets = (report?['buckets'] as List?) ?? const [];
  for (final b in buckets) {
    if (b is! Map) continue;
    final name = '${b['zoneName'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    out[name] = (out[name] ?? 0) + ((b['value'] as num?)?.toDouble() ?? 0);
  }
  return out;
}
