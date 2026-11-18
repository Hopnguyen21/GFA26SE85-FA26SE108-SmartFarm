import 'package:flutter/material.dart';
import '../../core/models/iot_deployment.dart';

/// Biên bản nghiệm thu lắp đặt: KTV lập khi bấm "Hoàn tất lắp đặt" (kèm ghi chú), Owner xem lại trước khi ký + thanh toán.
/// Dựng hoàn toàn từ dữ liệu có thật (Zone, Node đã cấp phát, vị trí đã lưu, kết quả kiểm tra kết nối); thiếu thì hiện "—".

class ReportNode {
  final String address;
  final String kind; // Node cảm biến / Node điều khiển
  final String location; // "lat, lng" hoặc "Chưa chấm vị trí"
  final String connection; // kết quả kiểm tra kết nối gần nhất
  const ReportNode({
    required this.address,
    required this.kind,
    required this.location,
    required this.connection,
  });
}

class AcceptanceReport {
  final String farm;
  final String field;
  final String zone;
  final String area;
  final List<ReportNode> nodes;

  /// Ghi chú nghiệm thu của KTV (rỗng = chưa có).
  final String note;
  const AcceptanceReport({
    required this.farm,
    required this.field,
    required this.zone,
    required this.area,
    required this.nodes,
    this.note = '',
  });

  int get located => nodes.where((n) => !n.location.startsWith('Chưa')).length;
  int get connected => nodes.where((n) => n.connection == 'Kết nối đạt').length;
}

String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v.trim();

String formatArea(double? m2) => (m2 == null || m2 <= 0)
    ? '—'
    : '${m2.toStringAsFixed(m2 % 1 == 0 ? 0 : 1)} m²';

/// Dựng biên bản từ thiết bị đã cấp phát; [saved] = vị trí đã lưu theo deviceId (chữ thường, có latitude/longitude).
AcceptanceReport buildAcceptanceReport({
  String? farm,
  String? field,
  String? zone,
  double? areaM2,
  required Iterable<IotDevice> devices,
  Map<String, Map<String, dynamic>> saved = const {},
  String note = '',
}) {
  return AcceptanceReport(
    farm: _dash(farm),
    field: _dash(field),
    zone: _dash(zone),
    area: formatArea(areaM2),
    note: note.trim(),
    nodes: [
      for (final d in devices)
        () {
          final loc = saved[d.deviceId.toLowerCase()];
          final lat = (loc?['latitude'] as num?)?.toDouble();
          final lng = (loc?['longitude'] as num?)?.toDouble();
          final t = d.latestTest;
          return ReportNode(
            address: d.hardwareAddress,
            kind: d.deviceType == 'ActuatorNode'
                ? 'Node điều khiển'
                : 'Node cảm biến',
            location: lat == null || lng == null
                ? 'Chưa chấm vị trí'
                : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
            connection: t == null
                ? 'Chưa kiểm tra kết nối'
                : (t.succeeded ? 'Kết nối đạt' : 'Kết nối lỗi'),
          );
        }(),
    ],
  );
}

/// Khối hiển thị biên bản (dùng chung cho KTV lúc hoàn tất và Owner lúc nghiệm thu).
class AcceptanceReportView extends StatelessWidget {
  final AcceptanceReport report;
  final String? noteLabel;
  const AcceptanceReportView({super.key, required this.report, this.noteLabel});

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(color: Colors.black54),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 12.5),
      ),
    );
    return Container(
      key: const ValueKey('acceptance-report'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BIÊN BẢN NGHIỆM THU LẮP ĐẶT',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          const SizedBox(height: 6),
          row('Nông trại', report.farm),
          row('Thửa đất (Field)', report.field),
          row('Zone', report.zone),
          row('Diện tích Zone', report.area),
          row(
            'Node',
            '${report.nodes.length} thiết bị · ${report.located} đã chấm vị trí · ${report.connected} kết nối đạt',
          ),
          if (report.nodes.isNotEmpty) const SizedBox(height: 4),
          for (final n in report.nodes)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '• ${n.address} (${n.kind}) — ${n.location} — ${n.connection}',
                style: const TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
          const SizedBox(height: 6),
          row(noteLabel ?? 'Ghi chú nghiệm thu của KTV', _dash(report.note)),
        ],
      ),
    );
  }
}

/// KTV xem biên bản + nhập ghi chú rồi xác nhận hoàn tất. Trả ghi chú (có thể rỗng) khi xác nhận, null khi hủy.
Future<String?> showAcceptanceReportSheet(
  BuildContext context, {
  required AcceptanceReport report,
  required String remainingLabel,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _AcceptanceSheet(report: report, remainingLabel: remainingLabel),
);

class _AcceptanceSheet extends StatefulWidget {
  final AcceptanceReport report;
  final String remainingLabel;
  const _AcceptanceSheet({required this.report, required this.remainingLabel});

  @override
  State<_AcceptanceSheet> createState() => _AcceptanceSheetState();
}

class _AcceptanceSheetState extends State<_AcceptanceSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lập biên bản nghiệm thu & hoàn tất lắp đặt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Sau khi hoàn tất, Owner xem biên bản này rồi ký nghiệm thu và thanh toán ${widget.remainingLabel}. Backend kiểm tra lại số lượng thiết bị và kết quả kết nối.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            AcceptanceReportView(report: widget.report),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('acceptance-note'),
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Ghi chú nghiệm thu (tuỳ chọn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chưa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const ValueKey('acceptance-confirm'),
                    onPressed: () => Navigator.pop(context, _note.text.trim()),
                    child: const Text('Xác nhận & hoàn tất'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
