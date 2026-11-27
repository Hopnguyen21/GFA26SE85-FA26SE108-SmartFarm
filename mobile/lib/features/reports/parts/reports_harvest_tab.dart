import 'package:flutter/material.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/utils/crop_emoji.dart';
import '../../zones/widgets/record_yield_dialog.dart';

/// Tab 3: Thu hoạch & Năng suất (Tổng sản lượng, năng suất kg/m², so sánh vụ trước, ghi nhận thu hoạch).
class ReportsHarvestTab extends StatelessWidget {
  final FarmProvider farmProvider;
  final List<Map<String, dynamic>> plantingSeasons;
  final VoidCallback onRefresh;

  const ReportsHarvestTab({
    super.key,
    required this.farmProvider,
    required this.plantingSeasons,
    required this.onRefresh,
  });

  String _fmtKg(num? v) {
    if (v == null) return '0 kg';
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

  String _fmtTon(num? kg) {
    if (kg == null || kg == 0) return '0 tấn';
    final ton = kg / 1000.0;
    return '${ton.toStringAsFixed(2)} tấn';
  }

  String _fmtDate(Object? d) {
    if (d == null) return '—';
    final parsed = DateTime.tryParse('$d');
    if (parsed == null) return '$d';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Tìm các vụ đã thu hoạch hoặc đã có sản lượng thực tế
    final withYield = plantingSeasons.where((s) {
      final y = s['actualYieldKg'] as num?;
      return y != null && y > 0;
    }).toList();

    final completedSeasons = plantingSeasons.where((s) {
      return '${s['status']}' == 'Completed';
    }).toList();

    // Các vụ hiển thị ở mục thu hoạch: tất cả các vụ completed + bất kỳ vụ nào có actualYieldKg
    final harvestSeasons = <Map<String, dynamic>>{};
    for (final s in completedSeasons) {
      harvestSeasons.add(s);
    }
    for (final s in withYield) {
      harvestSeasons.add(s);
    }

    final sortedHarvest = harvestSeasons.toList()
      ..sort((a, b) {
        final aDate =
            '${a['actualEndDate'] ?? a['endDate'] ?? a['startDate'] ?? ''}';
        final bDate =
            '${b['actualEndDate'] ?? b['endDate'] ?? b['startDate'] ?? ''}';
        return bDate.compareTo(aDate);
      });

    // Tổng sản lượng thực tế
    final totalYieldKg = withYield.fold<double>(
      0.0,
      (acc, s) => acc + ((s['actualYieldKg'] as num?)?.toDouble() ?? 0.0),
    );

    // Tính tổng diện tích của các vụ có sản lượng để tính năng suất trung bình kg/m²
    double totalAreaForYield = 0.0;
    for (final s in withYield) {
      final zId = '${s['zoneId'] ?? ''}'.toLowerCase();
      final zone = farmProvider.allZones
          .where((z) => z.zoneId.toLowerCase() == zId)
          .firstOrNull;
      if (zone != null && zone.areaM2 > 0) {
        totalAreaForYield += zone.areaM2;
      }
    }
    final avgYieldPerM2 = totalAreaForYield > 0
        ? (totalYieldKg / totalAreaForYield)
        : 0.0;

    // Các vụ đang canh tác (InProgress) có thể ghi nhận thu hoạch nhanh
    final inProgressSeasons = plantingSeasons
        .where((s) => '${s['status']}' == 'InProgress')
        .toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ─── Header Thống Kê Năng Suất ───────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.scale_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tổng Sản Lượng Thu Hoạch',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE9D5FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalYieldKg > 1000
                                ? '${_fmtKg(totalYieldKg)} (${_fmtTon(totalYieldKg)})'
                                : _fmtKg(totalYieldKg),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _headerSubStat(
                        'Năng suất TB',
                        '${avgYieldPerM2.toStringAsFixed(2)} kg/m²',
                      ),
                      Container(width: 1, height: 26, color: Colors.white24),
                      _headerSubStat(
                        'Vụ đã thu hoạch',
                        '${completedSeasons.length} vụ',
                      ),
                      Container(width: 1, height: 26, color: Colors.white24),
                      _headerSubStat(
                        'Vụ đang canh tác',
                        '${inProgressSeasons.length} vụ',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─── Nút Ghi Nhận Thu Hoạch Nhanh ────────────────────────────
          if (inProgressSeasons.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _pickAndRecordSeason(context, inProgressSeasons),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: const Text(
                  'Ghi Nhận Thu Hoạch Cho Vụ Đang Canh Tác',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Danh Sách Các Vụ Thu Hoạch ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LỊCH SỬ THU HOẠCH & NĂNG SUẤT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${sortedHarvest.length} vụ',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (sortedHarvest.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.agriculture_rounded,
                      size: 44,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có dữ liệu thu hoạch nào được ghi nhận.',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Khi một vụ hoàn thành hoặc thu hoạch từng đợt, bấm "Ghi Nhận Thu Hoạch" ở trên.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final s in sortedHarvest) ...[
              _buildHarvestCard(context, s),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _headerSubStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFFE9D5FF)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestCard(BuildContext context, Map<String, dynamic> s) {
    final name = '${s['name'] ?? 'Vụ thu hoạch'}';
    final cropName = '${s['cropName'] ?? 'Cây trồng'}';
    final zoneId = '${s['zoneId'] ?? ''}'.toLowerCase();
    final zone = farmProvider.allZones
        .where((z) => z.zoneId.toLowerCase() == zoneId)
        .firstOrNull;
    final zoneName = zone?.name ?? 'Zone';
    final areaM2 = zone?.areaM2 ?? 0.0;

    final actualYieldKg = (s['actualYieldKg'] as num?)?.toDouble();
    final actualEndDate = s['actualEndDate'] != null
        ? _fmtDate(s['actualEndDate'])
        : _fmtDate(s['expectedEndDate']);
    final isDone = '${s['status']}' == 'Completed';

    final yieldPerArea = (actualYieldKg != null && areaM2 > 0)
        ? (actualYieldKg / areaM2)
        : 0.0;

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Crop Emoji, Name, Status Badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                      : const Color(0xFF047857).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cropEmoji(cropName),
                  style: const TextStyle(fontSize: 24),
                ),
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
                      '$cropName · $zoneName (${areaM2.toStringAsFixed(0)} m²)',
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                      : const Color(0xFF047857).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                        : const Color(0xFF047857).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  isDone ? 'Đã thu hoạch' : 'Đang canh tác',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDone
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Row 2: Sản lượng & Năng suất
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF047857).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sản lượng thực tế',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        actualYieldKg != null ? _fmtKg(actualYieldKg) : '—',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF047857),
                        ),
                      ),
                      if (actualYieldKg != null && actualYieldKg >= 1000)
                        Text(
                          _fmtTon(actualYieldKg),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w500,
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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Năng suất m²',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        yieldPerArea > 0
                            ? '${yieldPerArea.toStringAsFixed(2)} kg/m²'
                            : '—',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      if (yieldPerArea > 0)
                        Text(
                          '${(yieldPerArea * 10).toStringAsFixed(1)} tấn/ha',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Ngày kết thúc: $actualEndDate',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (zone != null)
                TextButton.icon(
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
                      onRefresh();
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Cập nhật'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickAndRecordSeason(
    BuildContext context,
    List<Map<String, dynamic>> inProgressSeasons,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 16),
            const Text(
              'Chọn Vụ Đang Canh Tác Để Ghi Nhận Thu Hoạch:',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),
            for (final s in inProgressSeasons) ...[
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final zId = '${s['zoneId'] ?? ''}'.toLowerCase();
                    final zone = farmProvider.allZones
                        .where((z) => z.zoneId.toLowerCase() == zId)
                        .firstOrNull;
                    if (zone != null) {
                      final ok = await showHarvestYieldDialog(
                        context,
                        zoneId: zone.zoneId,
                        zoneName: zone.name,
                        areaM2: zone.areaM2,
                        cropLabel: '${s['cropName']}',
                        season: s,
                      );
                      if (ok == true) {
                        onRefresh();
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF047857,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            cropEmoji('${s['cropName']}'),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s['name']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s['cropName']} · Bắt đầu: ${_fmtDate(s['startDate'])}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ],
          ],
        ),
      ),
    );
  }
}
