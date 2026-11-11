import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../zone_operations_screens.dart';

/// Tóm tắt node cảm biến của Zone từ dữ liệu thật (GET /zones/{id}/telemetry/latest-by-device):
/// số node online/tổng, pin thấp nhất, sóng yếu nhất. Chạm để xem chi tiết từng node.
class ZoneNodeSummaryCard extends StatefulWidget {
  final String zoneId;
  final String zoneName;
  final bool canEditLocations;

  const ZoneNodeSummaryCard({super.key, required this.zoneId, required this.zoneName, this.canEditLocations = false});

  @override
  State<ZoneNodeSummaryCard> createState() => _ZoneNodeSummaryCardState();
}

class _ZoneNodeSummaryCardState extends State<ZoneNodeSummaryCard> {
  late Future<List<Map<String, dynamic>>> _future = FarmApi.getLatestTelemetryByDevice(widget.zoneId);

  void _reload() => setState(() => _future = FarmApi.getLatestTelemetryByDevice(widget.zoneId));

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ZoneNodesScreen(
              zoneId: widget.zoneId,
              zoneName: widget.zoneName,
              canEditLocations: widget.canEditLocations,
            ),
          ),
        );
        if (mounted) _reload();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.router, color: Color(0xFF0284C7), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  final title = Text(
                    'Node cảm biến · ${widget.zoneName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  );
                  if (snap.connectionState != ConnectionState.done) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, const SizedBox(height: 8), const LinearProgressIndicator(minHeight: 2)],
                    );
                  }
                  if (snap.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        Text(
                          'Không tải được trạng thái node. Chạm để thử lại.',
                          style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        ),
                      ],
                    );
                  }
                  final nodes = snap.data!;
                  if (nodes.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        title,
                        const SizedBox(height: 4),
                        const Text(
                          'Zone chưa có node nào được gán.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    );
                  }
                  final online = nodes.where((n) => '${n['status']}' == 'Online').length;
                  final batteries = [for (final n in nodes) (n['batteryLevel'] as num?)?.toInt()].whereType<int>();
                  final rssis = [for (final n in nodes) (n['rssi'] as num?)?.toDouble()].whereType<double>();
                  final minBattery = batteries.isEmpty ? null : batteries.reduce((a, b) => a < b ? a : b);
                  final worstRssi = rssis.isEmpty ? null : rssis.reduce((a, b) => a < b ? a : b);
                  final allOnline = online == nodes.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      const SizedBox(height: 3),
                      const Text(
                        'Chạm để xem số đo & vị trí từng node',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip(
                            '● $online/${nodes.length} online',
                            allOnline ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                            allOnline ? const Color(0xFF059669) : const Color(0xFFD97706),
                          ),
                          if (minBattery != null)
                            _chip(
                              '🔋 thấp nhất $minBattery%',
                              minBattery < 20 ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                              minBattery < 20 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            ),
                          if (worstRssi != null)
                            _chip(
                              '📶 yếu nhất ${worstRssi.toStringAsFixed(0)} dBm',
                              const Color(0xFFF0F9FF),
                              const Color(0xFF0284C7),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
