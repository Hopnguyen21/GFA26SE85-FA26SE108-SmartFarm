import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../zones/zone_detail_screen.dart';
import 'reports_season_summary_sheet.dart';

/// Tab 1: Phân khu & Vi khí hậu (Danh sách Zone, cảm biến, tỷ lệ tiêu thụ tài nguyên, báo cáo vụ của Zone).
class ReportsZonesTab extends StatelessWidget {
  final FarmProvider farmProvider;
  final Map<String, dynamic>? water;
  final Map<String, dynamic>? power;
  final VoidCallback onRefresh;

  const ReportsZonesTab({
    super.key,
    required this.farmProvider,
    required this.water,
    required this.power,
    required this.onRefresh,
  });

  Map<String, double> _sumBucketsByZoneId(Map<String, dynamic>? report) {
    final out = <String, double>{};
    final buckets = (report?['buckets'] as List?) ?? const [];
    for (final b in buckets) {
      if (b is! Map) continue;
      final id = '${b['zoneId'] ?? ''}'.trim().toLowerCase();
      if (id.isEmpty) continue;
      out[id] = (out[id] ?? 0) + ((b['value'] as num?)?.toDouble() ?? 0);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Lấy danh sách Zone của trang trại đang chọn
    final zones = farmProvider.zones.isNotEmpty
        ? farmProvider.zones
        : farmProvider.allZones;

    final waterByZoneId = _sumBucketsByZoneId(water);
    final powerByZoneId = _sumBucketsByZoneId(power);
    final totalWater = (water?['total'] as num?)?.toDouble() ?? 0.0;
    final totalPower = (power?['total'] as num?)?.toDouble() ?? 0.0;

    final totalAreaM2 = zones.fold<double>(0.0, (acc, z) => acc + z.areaM2);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // ─── Header tổng quan Phân khu ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF047857)],
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
                    Icons.grid_view_rounded,
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
                        '${zones.length} Phân Khu Canh Tác',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        totalAreaM2 > 10000
                            ? 'Tổng diện tích: ${(totalAreaM2 / 10000).toStringAsFixed(2)} ha (${totalAreaM2.toStringAsFixed(0)} m²)'
                            : 'Tổng diện tích: ${totalAreaM2.toStringAsFixed(0)} m²',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFCCFBF1),
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

          if (zones.isEmpty)
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
                      Icons.grid_off_rounded,
                      size: 40,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Trang trại này chưa có phân khu nào.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final z in zones) ...[
              _buildZoneCard(
                context,
                z,
                waterByZoneId,
                powerByZoneId,
                totalWater,
                totalPower,
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildZoneCard(
    BuildContext context,
    ZoneModel z,
    Map<String, double> waterByZoneId,
    Map<String, double> powerByZoneId,
    double totalWater,
    double totalPower,
  ) {
    final zoneIdNorm = z.zoneId.toLowerCase();
    final zoneWater = waterByZoneId[zoneIdNorm] ?? 0.0;
    final zonePower = powerByZoneId[zoneIdNorm] ?? 0.0;
    final waterPercent = totalWater > 0 ? (zoneWater / totalWater * 100) : 0.0;
    final powerPercent = totalPower > 0 ? (zonePower / totalPower * 100) : 0.0;

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
            // Row 1: Tên Zone & Loại hình
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        z.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${z.fieldName.isNotEmpty ? '${z.fieldName} · ' : ''}${z.areaM2.toStringAsFixed(0)} m²',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF047857).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    z.currentCrop.isNotEmpty ? z.currentCrop : 'Chưa gieo trồng',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: z.currentCrop.isNotEmpty
                          ? const Color(0xFF047857)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),

            if (z.currentStage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timelapse_rounded,
                      size: 14,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Giai đoạn: ${z.currentStage}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Row 2: Vi khí hậu trực tiếp (nếu có dữ liệu cảm biến)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _sensorChip(
                  icon: Icons.thermostat_rounded,
                  label: '${z.currentTemp.toStringAsFixed(1)}°C',
                  color: const Color(0xFFEA580C),
                ),
                _sensorChip(
                  icon: Icons.water_drop_outlined,
                  label: '${z.currentHumidity.toStringAsFixed(0)}% KK',
                  color: const Color(0xFF0284C7),
                ),
                _sensorChip(
                  icon: Icons.grass_rounded,
                  label: '${z.currentSoilMoisture.toStringAsFixed(0)}% Đất',
                  color: const Color(0xFF16A34A),
                ),
                _sensorChip(
                  icon: Icons.light_mode_outlined,
                  label: '${z.currentLux.toStringAsFixed(0)} lux',
                  color: const Color(0xFFD97706),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Row 3: Tiêu thụ tài nguyên của Zone kèm thanh tỷ lệ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.water_drop_rounded, size: 14, color: Color(0xFF0284C7)),
                                SizedBox(width: 4),
                                Text(
                                  'Nước tưới Zone',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${zoneWater.toStringAsFixed(1)} L (${waterPercent.toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalWater > 0 ? (zoneWater / totalWater).clamp(0.0, 1.0) : 0.0,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFD97706)),
                                SizedBox(width: 4),
                                Text(
                                  'Điện năng Zone',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${zonePower.toStringAsFixed(1)} kWh (${powerPercent.toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: totalPower > 0 ? (zonePower / totalPower).clamp(0.0, 1.0) : 0.0,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Row 4: Hành động nhanh
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showZoneSeasonSummarySheet(
                      context,
                      zoneId: z.zoneId,
                      zoneName: z.name,
                      cropLabel: z.currentCrop,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFF047857), width: 1.2),
                      foregroundColor: const Color(0xFF047857),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.assessment_outlined, size: 16),
                    label: const Text(
                      'Báo Cáo Vụ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZoneDetailScreen(zone: z),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062326),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text(
                      'Chi Tiết Zone',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
