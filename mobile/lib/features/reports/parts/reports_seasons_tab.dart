import 'package:flutter/material.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/utils/crop_emoji.dart';
import '../../zones/widgets/record_yield_dialog.dart';
import '../../zones/widgets/zone_seasons_section.dart'
    show compareSeasonsForDisplay, seasonTimeProgress;
import 'reports_season_summary_sheet.dart';

/// Tab 2: Mùa vụ & Tiến độ Sinh trưởng (Danh sách vụ trồng, tiến trình ngày, giai đoạn, VietGAP, báo cáo vụ).
class ReportsSeasonsTab extends StatefulWidget {
  final FarmProvider farmProvider;
  final List<Map<String, dynamic>> plantingSeasons;
  final VoidCallback onRefresh;

  const ReportsSeasonsTab({
    super.key,
    required this.farmProvider,
    required this.plantingSeasons,
    required this.onRefresh,
  });

  @override
  State<ReportsSeasonsTab> createState() => _ReportsSeasonsTabState();
}

class _ReportsSeasonsTabState extends State<ReportsSeasonsTab> {
  String _selectedStatus = 'All'; // 'All', 'InProgress', 'Planned', 'Completed'

  String _fmtDate(Object? d) {
    if (d == null) return '—';
    final parsed = DateTime.tryParse('$d');
    if (parsed == null) return '$d';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.plantingSeasons]..sort(compareSeasonsForDisplay);

    final inProgressCount =
        all.where((s) => '${s['status']}' == 'InProgress').length;
    final plannedCount =
        all.where((s) => '${s['status']}' == 'Planned').length;
    final completedCount =
        all.where((s) => '${s['status']}' == 'Completed').length;

    final filtered = _selectedStatus == 'All'
        ? all
        : all.where((s) => '${s['status']}' == _selectedStatus).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ─── Header Thống kê Vụ mùa ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF047857), Color(0xFF065F46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.agriculture_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${all.length} Vụ Trồng Của Trang Trại',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$inProgressCount đang canh tác · $plannedCount kế hoạch · $completedCount đã thu hoạch',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD1FAE5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Bộ lọc Trạng thái ───────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Tất cả (${all.length})', 'All'),
                const SizedBox(width: 8),
                _filterChip('Đang canh tác ($inProgressCount)', 'InProgress'),
                const SizedBox(width: 8),
                _filterChip('Kế hoạch ($plannedCount)', 'Planned'),
                const SizedBox(width: 8),
                _filterChip('Đã thu hoạch ($completedCount)', 'Completed'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.filter_list_off_rounded,
                      size: 40,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Không có vụ trồng nào khớp với bộ lọc.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final s in filtered) ...[
              _buildSeasonCard(context, s),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF047857),
      backgroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
        width: 1,
      ),
      showCheckmark: false,
      onSelected: (_) => setState(() => _selectedStatus = value),
    );
  }

  Widget _buildSeasonCard(BuildContext context, Map<String, dynamic> s) {
    final name = '${s['name'] ?? 'Vụ mùa'}';
    final cropName = '${s['cropName'] ?? 'Cây trồng'}';
    final profileName = '${s['growthProfileName'] ?? 'Quy trình canh tác'}';
    final stageName = '${s['currentGrowthStageName'] ?? 'Giai đoạn'}';
    final status = '${s['status'] ?? '—'}';
    final zoneId = '${s['zoneId'] ?? ''}';
    final startDate = _fmtDate(s['startDate']);
    final expectedEndDate = _fmtDate(s['expectedEndDate']);
    final actualEndDate = s['actualEndDate'] != null ? _fmtDate(s['actualEndDate']) : null;
    final actualYieldKg = s['actualYieldKg'] as num?;

    // Tìm Zone tương ứng
    final zone = widget.farmProvider.allZones
        .where((z) => z.zoneId.toLowerCase() == zoneId.toLowerCase())
        .firstOrNull;
    final zoneName = zone?.name ?? 'Zone';

    final isDone = status == 'Completed';
    final isRunning = status == 'InProgress';
    final isPlanned = status == 'Planned';

    final statusVi = isDone
        ? 'Đã thu hoạch'
        : isRunning
        ? 'Đang canh tác'
        : isPlanned
        ? 'Kế hoạch'
        : status;
    final statusColor = isDone
        ? const Color(0xFF7C3AED)
        : isRunning
        ? const Color(0xFF047857)
        : const Color(0xFF0284C7);

    // Tiến độ thời gian
    final progress = seasonTimeProgress(s);
    final reqs = (s['appliedRequirements'] as List?) ?? const [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Crop Emoji, Tên Vụ, Status Badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(cropEmoji(cropName), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$cropName · $zoneName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    statusVi,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Row 2: Hồ sơ sinh trưởng & Giai đoạn
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
                    children: [
                      const Icon(
                        Icons.timelapse_rounded,
                        size: 16,
                        color: Color(0xFF047857),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Giai đoạn hiện tại: $stageName',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quy trình: $profileName',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Row 3: Thanh tiến độ ngày (nếu đang canh tác)
            if (isRunning && progress != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tiến độ canh tác: Ngày ${progress.day} / ${progress.totalDays} ngày (${progress.percent}%)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.percent / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF047857),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Row 4: Ngày bắt đầu - Kết thúc
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bắt đầu: $startDate',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDone && actualEndDate != null
                        ? 'Thu hoạch: $actualEndDate'
                        : 'Dự kiến kết thúc: $expectedEndDate',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Thông số VietGAP tiêu biểu
            if (reqs.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final r in reqs.take(3)) ...[
                    if (r is Map)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${r['parameterCode']}: ${r['minValue']}–${r['maxValue']} ${r['unit'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Row 5: Nút Báo Cáo Vụ & Nút Ghi Nhận Sản Lượng
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showZoneSeasonSummarySheet(
                      context,
                      zoneId: zoneId,
                      zoneName: zoneName,
                      cropLabel: cropName,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFF047857), width: 1.2),
                      foregroundColor: const Color(0xFF047857),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: const Text(
                      'Tóm Tắt Vụ Mùa',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (zone != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await showHarvestYieldDialog(
                          context,
                          zoneId: zone.zoneId,
                          zoneName: zone.name,
                          areaM2: zone.areaM2,
                          cropLabel: cropName,
                          season: s,
                        );
                        if (ok == true) {
                          widget.onRefresh();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actualYieldKg != null
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.scale_rounded, size: 16),
                      label: Text(
                        actualYieldKg != null
                            ? '${actualYieldKg.toStringAsFixed(0)} kg'
                            : 'Ghi Sản Lượng',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
