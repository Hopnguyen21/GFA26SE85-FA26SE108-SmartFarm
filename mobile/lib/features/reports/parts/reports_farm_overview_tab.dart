import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/providers/farm_provider.dart';

/// Tab 0: Tổng quan Trang trại (KPIs vận hành, Tài chính, Tiêu thụ tài nguyên & Biểu đồ, Tiến độ công việc).
class ReportsFarmOverviewTab extends StatefulWidget {
  final FarmProvider farmProvider;
  final Map<String, dynamic>? overview;
  final Map<String, dynamic>? water;
  final Map<String, dynamic>? power;
  final Map<String, dynamic>? tasks;
  final Map<String, dynamic>? inventory;
  final int days;
  final ValueChanged<int> onDaysChanged;
  final ValueChanged<String> onFarmSelected;
  final VoidCallback onRefresh;

  const ReportsFarmOverviewTab({
    super.key,
    required this.farmProvider,
    required this.overview,
    required this.water,
    required this.power,
    required this.tasks,
    this.inventory,
    required this.days,
    required this.onDaysChanged,
    required this.onFarmSelected,
    required this.onRefresh,
  });

  @override
  State<ReportsFarmOverviewTab> createState() => _ReportsFarmOverviewTabState();
}

class _ReportsFarmOverviewTabState extends State<ReportsFarmOverviewTab> {
  bool _showWaterChart = true;

  String _fmt(num? v, String unit) =>
      v == null ? '—' : '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} $unit';

  String _fmtVnd(num? v) {
    if (v == null) return '0 đ';
    final isNegative = v < 0;
    final absVal = v.abs().round();
    final s = absVal.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '${isNegative ? '-' : ''}$s đ';
  }

  Map<String, double> _sumBucketsByZone(Map<String, dynamic>? report) {
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

  @override
  Widget build(BuildContext context) {
    final o = widget.overview;
    final waterByZone = _sumBucketsByZone(widget.water);
    final powerByZone = _sumBucketsByZone(widget.power);
    final totalWater = (widget.water?['total'] as num?)?.toDouble();
    final totalPower = (widget.power?['total'] as num?)?.toDouble();

    final taskTotal = (widget.tasks?['total'] as num?)?.toInt() ?? 0;
    final taskApproved = (widget.tasks?['approved'] as num?)?.toInt() ?? 0;
    final taskOverdue = (widget.tasks?['overdue'] as num?)?.toInt() ?? 0;
    final taskCompletion =
        (widget.tasks?['completionRatePercent'] as num?)?.toDouble() ?? 0.0;
    final assignees = (widget.tasks?['byAssignee'] as List?) ?? const [];

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ─── Farm Selector (nếu Owner có nhiều hơn 1 trang trại) ──────
          if (widget.farmProvider.farms.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x04000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.corporate_fare_rounded,
                      color: Color(0xFF047857),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Trang trại:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.farmProvider.selectedFarmId,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                        items: widget.farmProvider.farms.map((f) {
                          return DropdownMenuItem<String>(
                            value: f.farmId,
                            child: Text(
                              f.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null && id != widget.farmProvider.selectedFarmId) {
                            widget.onFarmSelected(id);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ─── Time Range Selector ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: SegmentedButton<int>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF047857);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFF475569);
                }),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                side: WidgetStateProperty.all(
                  const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              segments: const [
                ButtonSegment(value: 7, label: Text('7 ngày qua')),
                ButtonSegment(value: 30, label: Text('30 ngày qua')),
                ButtonSegment(value: 90, label: Text('90 ngày qua')),
              ],
              selected: {widget.days},
              onSelectionChanged: (s) => widget.onDaysChanged(s.first),
            ),
          ),
          const SizedBox(height: 16),

          // ─── KPI Vận hành cốt lõi ──────────────────────────────────────
          if (o != null) ...[
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    title: 'Phân khu canh tác',
                    value: '${o['zoneCount']} Zone',
                    subtitle: 'Trong ${o['fieldCount']} Khu đất',
                    icon: Icons.grid_view_rounded,
                    color: const Color(0xFF047857),
                    bgTint: const Color(0xFFECFDF5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    title: 'Vụ đang hoạt động',
                    value: '${o['activeSeasonCount']} Vụ',
                    subtitle: 'Đang theo dõi vi khí hậu',
                    icon: Icons.eco_rounded,
                    color: const Color(0xFF15803D),
                    bgTint: const Color(0xFFF0FDF4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    title: 'Thiết bị trực tuyến',
                    value: '${o['onlineDeviceCount']} Node/GW',
                    subtitle: 'Hoạt động bình thường',
                    icon: Icons.router_rounded,
                    color: const Color(0xFF0284C7),
                    bgTint: const Color(0xFFF0F9FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    title: 'Cảnh báo 7 ngày',
                    value: '${o['alertsLast7Days']}',
                    subtitle: '${o['openAlertCount']} cảnh báo đang mở',
                    icon: Icons.warning_amber_rounded,
                    color: ((o['openAlertCount'] as num?) ?? 0) > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF64748B),
                    bgTint: ((o['openAlertCount'] as num?) ?? 0) > 0
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    title: 'Công việc mở',
                    value: '${o['openTaskCount']} việc',
                    subtitle: 'Cần nhân công thực hiện',
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFFD97706),
                    bgTint: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kpiCard(
                    title: 'Vật tư sắp hết',
                    value: '${o['lowStockItemCount']} mục',
                    subtitle: 'Dưới ngưỡng tồn an toàn',
                    icon: Icons.inventory_2_outlined,
                    color: ((o['lowStockItemCount'] as num?) ?? 0) > 0
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF64748B),
                    bgTint: ((o['lowStockItemCount'] as num?) ?? 0) > 0
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── Tài chính & Dòng tiền tháng này ──────────────────────────
            _sectionCard(
              title: 'Tài chính & Dòng tiền tháng này',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF047857),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF047857).withValues(alpha: 0.08),
                          const Color(0xFF047857).withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF047857).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF047857),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.savings_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Dòng tiền thuần',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Doanh thu trừ chi phí tháng',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fmtVnd(o['netCashFlowCurrentMonth'] as num?),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: ((o['netCashFlowCurrentMonth'] as num?) ?? 0) >= 0
                                ? const Color(0xFF047857)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _statRow(
                    'Doanh thu tháng',
                    _fmtVnd(o['revenueCurrentMonth'] as num?),
                    color: const Color(0xFF047857),
                    isBold: true,
                    icon: Icons.trending_up_rounded,
                  ),
                  const Divider(height: 16, color: Color(0xFFF1F5F9)),
                  _statRow(
                    'Chi phí phát sinh',
                    _fmtVnd(o['expenseCurrentMonth'] as num?),
                    color: const Color(0xFFD97706),
                    icon: Icons.trending_down_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Tiêu thụ tài nguyên & Biểu đồ ───────────────────────────
          _sectionCard(
            title: 'Tiêu thụ Nước tưới & Điện năng (${widget.days} ngày qua)',
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFF0284C7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.water_drop_rounded,
                                  color: Color(0xFF0284C7),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tổng nước tưới',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF0284C7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmt(totalWater, '${widget.water?['unit'] ?? 'L'}'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFD97706).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: Color(0xFFD97706),
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tổng điện năng',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFD97706),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _fmt(totalPower, '${widget.power?['unit'] ?? 'kWh'}'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Chart header with metric switcher
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _showWaterChart
                            ? 'Biểu đồ phân bổ Nước tưới theo Zone (Lít):'
                            : 'Biểu đồ phân bổ Điện năng theo Zone (kWh):',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Toggle pills
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showWaterChart = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _showWaterChart ? const Color(0xFF0284C7) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Nước',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _showWaterChart ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showWaterChart = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !_showWaterChart ? const Color(0xFFD97706) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Điện',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: !_showWaterChart ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chart Container
                (_showWaterChart ? waterByZone : powerByZone).isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            _showWaterChart
                                ? 'Chưa có dữ liệu tưới nước trong khoảng thời gian này.'
                                : 'Chưa có dữ liệu điện năng trong khoảng thời gian này.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.fromLTRB(8, 14, 12, 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: SizedBox(
                          height: 190,
                          child: _zoneBarChart(
                            _showWaterChart ? waterByZone : powerByZone,
                            isWater: _showWaterChart,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Tiến độ Công việc & Nhân công thực địa ────────────────────
          _sectionCard(
            title: 'Tiến độ Công việc & Nhân công (${widget.days} ngày qua)',
            icon: Icons.assignment_turned_in_rounded,
            iconColor: const Color(0xFF2563EB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tỷ lệ hoàn thành: ${taskCompletion.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$taskApproved / $taskTotal công việc',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: taskTotal > 0 ? (taskApproved / taskTotal) : 0,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _taskBadge('Đã duyệt: $taskApproved', const Color(0xFF047857)),
                    _taskBadge('Quá hạn: $taskOverdue', const Color(0xFFDC2626)),
                    _taskBadge(
                      'Thất bại: ${(widget.tasks?['failed'] as num?) ?? 0}',
                      const Color(0xFF64748B),
                    ),
                  ],
                ),
                if (assignees.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  const Text(
                    'Phân công theo nông dân:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final a in assignees) ...[
                    if (a is Map)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFF047857).withValues(alpha: 0.12),
                              child: Text(
                                _farmerInitials('${a['farmerName'] ?? 'ND'}'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${a['farmerName'] ?? 'Nông dân'}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Xong: ${a['approved'] ?? 0} · Làm: ${a['inProgress'] ?? 0} · Trễ: ${a['overdue'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _farmerInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'ND';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0].substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  Widget _zoneBarChart(Map<String, double> data, {required bool isWater}) {
    final entries = data.entries.toList();
    final maxY = entries.map((e) => e.value).fold<double>(0.0, (a, b) => a > b ? a : b);
    final unit = isWater ? 'L' : 'kWh';

    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY * 1.25,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final n = entries[groupIndex].key;
              final val = rod.toY;
              return BarTooltipItem(
                '$n\n${val.toStringAsFixed(1)} $unit',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                final n = entries[i].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    n.length > 7 ? '${n.substring(0, 7)}…' : n,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE2E8F0),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  gradient: LinearGradient(
                    colors: isWater
                        ? const [Color(0xFF34D399), Color(0xFF047857)]
                        : const [Color(0xFFFBBF24), Color(0xFFD97706)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgTint,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 8,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16.5,
              color: color,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
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
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _statRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    IconData? icon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color ?? const Color(0xFF64748B)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _taskBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
