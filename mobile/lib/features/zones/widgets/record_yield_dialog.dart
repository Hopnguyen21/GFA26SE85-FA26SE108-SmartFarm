import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

/// Phân loại chất lượng khi thu hoạch (giống danh sách trên web).
const harvestQualityGrades = <String>[
  'Loại 1 (Xuất khẩu / Siêu thị cao cấp)',
  'Loại 2 (Thương phẩm nội địa / Chợ đầu mối)',
  'Loại 3 (Nhà máy chế biến / Đóng hộp)',
  'Đạt chuẩn VietGAP / GlobalGAP',
  'Hữu cơ Organic',
];

/// Backend không trả lại phân loại/ghi chú của vụ, nên app nhớ lần ghi gần nhất trong phiên để hiện trên thẻ.
final Map<String, ({String quality, String notes})> harvestNoteCache = {};

String? harvestSeasonId(Map<String, dynamic> s) {
  final v = '${s['seasonId'] ?? s['plantingSeasonId'] ?? ''}'.trim();
  return v.isEmpty || v.toLowerCase() == 'null' ? null : v;
}

/// Năng suất kg/m²; 0 khi chưa có diện tích.
double yieldPerM2(double kg, double areaM2) => areaM2 > 0 ? kg / areaM2 : 0;

/// Số kiểu Việt Nam: 1250 → "1.250", 12.5 → "12,5".
String fmtKg(num v) {
  final s = v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1);
  final parts = s.split('.');
  final i = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return parts.length > 1 ? '$i,${parts[1]}' : i;
}

String _vnDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Ngày yyyy-MM-dd → dd/MM/yyyy; "—" khi thiếu/sai.
String harvestDayLabel(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null ? '—' : _vnDay(d);
}

/// Hộp thoại "Ghi nhận sản lượng & thu hoạch" (khớp modal của web): kg thực tế (+ tấn, kg/m²), ngày ghi nhận,
/// phân loại chất lượng, ghi chú, đánh dấu hoàn tất vụ. Trả về true nếu đã lưu.
Future<bool?> showHarvestYieldDialog(
  BuildContext context, {
  required String zoneId,
  required String zoneName,
  required double areaM2,
  required String cropLabel,
  required Map<String, dynamic> season,
}) {
  final seasonId = harvestSeasonId(season);
  final cached = seasonId == null ? null : harvestNoteCache[seasonId];
  final running = '${season['status']}' == 'InProgress';
  final existing = season['actualYieldKg'];
  final kgC = TextEditingController(text: existing == null ? '' : '$existing');
  final notesC = TextEditingController(text: cached?.notes ?? '');
  var quality = cached?.quality ?? harvestQualityGrades.first;
  var date =
      DateTime.tryParse('${season['actualEndDate'] ?? ''}') ?? DateTime.now();
  var markCompleted = running;
  var saving = false;
  String? error;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final kg = double.tryParse(kgC.text.trim().replaceAll(',', '.')) ?? 0;
        return AlertDialog(
          scrollable: true,
          title: Text(
            'Ghi nhận sản lượng · $zoneName',
            style: const TextStyle(fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'Vụ: ${season['name'] ?? '—'}\nCây trồng: $cropLabel\n'
                  'Diện tích: ${fmtKg(areaM2)} m²',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('yield_kg'),
                controller: kgC,
                onChanged: (_) => setLocal(() => error = null),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Sản lượng thu hoạch thực tế (kg) *',
                  hintText: 'VD: 1250',
                  border: OutlineInputBorder(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      '≈ ${(kg / 1000).toStringAsFixed(2)} tấn',
                      key: const Key('yield_tons'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Năng suất: ${yieldPerM2(kg, areaM2).toStringAsFixed(2)} kg/m²',
                      key: const Key('yield_per_m2'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('yield_date'),
                icon: const Icon(Icons.event, size: 18),
                label: Text('Ngày ghi nhận / thu hoạch: ${_vnDay(date)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const Key('yield_quality'),
                isExpanded: true,
                initialValue: quality,
                decoration: const InputDecoration(
                  labelText: 'Phân loại & tiêu chuẩn chất lượng',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final g in harvestQualityGrades)
                    DropdownMenuItem(
                      value: g,
                      child: Text(
                        g,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
                onChanged: (v) => setLocal(() => quality = v ?? quality),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('yield_notes'),
                controller: notesC,
                maxLines: 3,
                maxLength: 900,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thu hoạch & đánh giá chất lượng',
                  hintText: 'Độ ngọt Brix, ngoại hình, đối tác thu mua...',
                  border: OutlineInputBorder(),
                ),
              ),
              if (running)
                CheckboxListTile(
                  key: const Key('yield_complete'),
                  contentPadding: EdgeInsets.zero,
                  value: markCompleted,
                  onChanged: (v) => setLocal(() => markCompleted = v ?? false),
                  title: const Text(
                    'Đánh dấu hoàn tất vụ mùa',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Kết thúc chu kỳ sinh trưởng và lưu trữ hồ sơ vụ này',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              key: const Key('yield_save'),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text(saving ? 'Đang lưu...' : 'Lưu sản lượng'),
              onPressed: saving || seasonId == null
                  ? null
                  : () async {
                      final v = double.tryParse(
                        kgC.text.trim().replaceAll(',', '.'),
                      );
                      if (v == null || v < 0) {
                        setLocal(
                          () => error =
                              'Nhập sản lượng là số lớn hơn hoặc bằng 0.',
                        );
                        return;
                      }
                      final note = notesC.text.trim();
                      final notes = note.isEmpty ? quality : '$quality - $note';
                      setLocal(() => saving = true);
                      try {
                        await CropApi.recordSeasonYield(
                          zoneId,
                          seasonId,
                          actualYieldKg: v,
                          // Chỉ ghi ngày kết thúc khi chốt vụ (hoặc vụ đã đóng); vụ đang chạy không bị gán ngày kết thúc.
                          actualEndDate: (running && !markCompleted)
                              ? null
                              : date,
                          notes: notes,
                          markCompleted: running && markCompleted,
                        );
                        harvestNoteCache[seasonId] = (
                          quality: quality,
                          notes: note,
                        );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setLocal(() {
                          saving = false;
                          error = e.toString().replaceFirst('Exception: ', '');
                        });
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
  // Không dispose controller ở đây: hộp thoại còn chạy hiệu ứng đóng và vẫn dựng TextField; controller tự được thu gom.
}
