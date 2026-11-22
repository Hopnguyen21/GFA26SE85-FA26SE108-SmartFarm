import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/crop_emoji.dart';
import '../../../core/utils/export_utils.dart';
import '../../../core/utils/user_error.dart';

/// Modal BottomSheet hiển thị báo cáo tóm tắt mùa vụ của một Phân khu (Zone).
/// Gọi GET /api/v1/zones/{zoneId}/report/season-summary
/// Cho phép xuất file Excel báo cáo vụ này qua GET /api/v1/zones/{zoneId}/report/season-summary/excel.
Future<void> showZoneSeasonSummarySheet(
  BuildContext context, {
  required String zoneId,
  required String zoneName,
  String? cropLabel,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ZoneSeasonSummarySheet(
      zoneId: zoneId,
      zoneName: zoneName,
      cropLabel: cropLabel,
    ),
  );
}

class _ZoneSeasonSummarySheet extends StatefulWidget {
  final String zoneId;
  final String zoneName;
  final String? cropLabel;

  const _ZoneSeasonSummarySheet({
    required this.zoneId,
    required this.zoneName,
    this.cropLabel,
  });

  @override
  State<_ZoneSeasonSummarySheet> createState() =>
      _ZoneSeasonSummarySheetState();
}

class _ZoneSeasonSummarySheetState extends State<_ZoneSeasonSummarySheet> {
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ReportApi.getZoneSeasonSummaryReport(widget.zoneId);
      if (!mounted) return;
      setState(() => _data = res);
    } catch (e) {
      if (!mounted) return;
      final msg = userFacingError(e);
      final is404 =
          msg.contains('404') ||
          msg.toLowerCase().contains('not found') ||
          msg.contains('không tìm thấy');
      setState(
        () => _error = is404
            ? 'Phân khu "${widget.zoneName}" hiện chưa có vụ mùa nào đang canh tác hoặc đã hoàn thành.'
            : msg,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await ReportApi.downloadZoneSeasonReportExcel(widget.zoneId);
      final seasonName = _data?['seasonName'] ?? 'mua-vu';
      final safeName =
          'bao-cao-vu-${widget.zoneName}-$seasonName-${DateTime.now().toIso8601String().substring(0, 10)}.xlsx'
              .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      await saveAndShareFile(
        safeName,
        bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xuất Excel vụ thất bại: ${userFacingError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fmtKg(num? v) {
    if (v == null) return '—';
    final s = v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(1);
    final parts = s.split('.');
    final i = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return parts.length > 1 ? '$i,${parts[1]} kg' : '$i kg';
  }

  String _fmtDate(Object? d) {
    if (d == null) return '—';
    final parsed = DateTime.tryParse('$d');
    if (parsed == null) return '$d';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF047857),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Báo Cáo Tóm Tắt Mùa Vụ',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          widget.zoneName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_data != null)
                    IconButton(
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF047857),
                              ),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              color: Color(0xFF047857),
                            ),
                      tooltip: 'Xuất Excel vụ này',
                      onPressed: _exporting ? null : _exportExcel,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF047857)),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFF64748B),
                              size: 44,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _fetch,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Tải lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildReportContent(scrollController),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(ScrollController scrollController) {
    final d = _data!;
    final seasonName = '${d['seasonName'] ?? '—'}';
    final cropName = '${d['cropName'] ?? widget.cropLabel ?? 'Cây trồng'}';
    final varietyName = d['varietyName'] as String?;
    final growthStageName = '${d['growthStageName'] ?? '—'}';
    final status = '${d['status'] ?? '—'}';
    final startDate = _fmtDate(d['startDate']);
    final endDate = _fmtDate(d['endDate']);
    final actualYieldKg = d['actualYieldKg'] as num?;
    final previousYieldKg = d['previousYieldKg'] as num?;
    final waterLiters = (d['waterLiters'] as num?)?.toDouble() ?? 0.0;
    final electricityKWh = (d['electricityKWh'] as num?)?.toDouble() ?? 0.0;
    final materialIssued = (d['materialIssuedQuantity'] as num?)?.toDouble() ?? 0.0;
    final alertCount = (d['alertCount'] as num?)?.toInt() ?? 0;
    final cmdCount =
        (d['acknowledgedIrrigationCommandCount'] as num?)?.toInt() ?? 0;

    final isDone = status == 'Completed';
    final statusVi = isDone
        ? 'Đã thu hoạch'
        : status == 'InProgress'
        ? 'Đang canh tác'
        : status == 'Planned'
        ? 'Kế hoạch'
        : status;
    final statusColor = isDone
        ? const Color(0xFF7C3AED)
        : status == 'InProgress'
        ? const Color(0xFF047857)
        : const Color(0xFF0284C7);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        // Card 1: Header Vụ trồng
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF047857).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
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
                          seasonName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          varietyName != null
                              ? '$cropName · Giống: $varietyName'
                              : cropName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFD1FAE5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      statusVi,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Giai đoạn hiện tại: $growthStageName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bắt đầu: $startDate',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  Text(
                    'Kết thúc: $endDate',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Card 2: Tài nguyên & Vận hành trong vụ
        const Text(
          'TÀI NGUYÊN & VẬN HÀNH TRONG VỤ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statTile(
                title: 'Nước tưới tiêu thụ',
                value: '${waterLiters.toStringAsFixed(1)} L',
                subtitle: '$cmdCount lệnh tưới hoàn thành',
                icon: Icons.water_drop_rounded,
                color: const Color(0xFF0284C7),
                bgTint: const Color(0xFFF0F9FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statTile(
                title: 'Điện năng tiêu thụ',
                value: '${electricityKWh.toStringAsFixed(2)} kWh',
                subtitle: 'Máy bơm & van điện',
                icon: Icons.bolt_rounded,
                color: const Color(0xFFD97706),
                bgTint: const Color(0xFFFFFBEB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statTile(
                title: 'Vật tư đã xuất kho',
                value: '${materialIssued.toStringAsFixed(1)} kg/L',
                subtitle: 'Phân bón & chế phẩm',
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF0F766E),
                bgTint: const Color(0xFFF0FDF4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statTile(
                title: 'Cảnh báo phát sinh',
                value: '$alertCount',
                subtitle: 'Ngưỡng vi khí hậu vụ',
                icon: Icons.warning_amber_rounded,
                color: alertCount > 0
                    ? const Color(0xFFE11D48)
                    : const Color(0xFF64748B),
                bgTint: alertCount > 0
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Card 3: Năng suất & Thu hoạch
        const Text(
          'NĂNG SUẤT & THU HOẠCH',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Sản lượng thực tế vụ này',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    actualYieldKg != null
                        ? _fmtKg(actualYieldKg)
                        : (isDone ? 'Chưa ghi nhận' : 'Đang nuôi trái'),
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: actualYieldKg != null
                          ? const Color(0xFF047857)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Sản lượng vụ trước',
                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    previousYieldKg != null
                        ? _fmtKg(previousYieldKg)
                        : 'Không có dữ liệu',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (actualYieldKg != null &&
                  previousYieldKg != null &&
                  previousYieldKg > 0) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
                Builder(
                  builder: (_) {
                    final deltaKg = actualYieldKg - previousYieldKg;
                    final deltaPercent = (deltaKg / previousYieldKg) * 100;
                    final isPositive = deltaKg >= 0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Tăng trưởng vụ trước',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 18,
                              color: isPositive
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${isPositive ? '+' : ''}${deltaPercent.toStringAsFixed(1)}% (${isPositive ? '+' : ''}${_fmtKg(deltaKg)})',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isPositive
                                    ? const Color(0xFF047857)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Nút xuất Excel vụ này
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _exporting ? null : _exportExcel,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.table_chart_rounded, size: 20),
            label: Text(
              _exporting
                  ? 'Đang chuẩn bị file Excel...'
                  : 'Xuất Báo Cáo Vụ Này (.xlsx)',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
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
                padding: const EdgeInsets.all(5),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: color,
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
}
