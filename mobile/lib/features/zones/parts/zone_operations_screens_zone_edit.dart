part of '../zone_operations_screens.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 4. Sửa / lưu trữ Zone (Owner)
// ═══════════════════════════════════════════════════════════════════════════
/// Trả về 'updated', 'archived' hoặc null.
Future<String?> showEditZoneSheet(BuildContext context, ZoneModel zone) {
  final nameC = TextEditingController(text: zone.name);
  final areaC = TextEditingController(text: zone.areaM2 > 0 ? zone.areaM2.toStringAsFixed(0) : '');
  final notesC = TextEditingController(text: zone.notes ?? '');
  var busy = false;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Sửa thông tin Zone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: nameC,
                decoration: const InputDecoration(labelText: 'Tên Zone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaC,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Diện tích (m²)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesC,
                maxLength: 1000,
                decoration: const InputDecoration(labelText: 'Ghi chú', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final name = nameC.text.trim();
                        final area = areaC.text.trim().isEmpty
                            ? null
                            : double.tryParse(areaC.text.trim().replaceAll(',', '.'));
                        if (name.length < 2) {
                          _toast(ctx, 'Tên Zone cần ít nhất 2 ký tự.', error: true);
                          return;
                        }
                        if (areaC.text.trim().isNotEmpty && (area == null || area <= 0)) {
                          _toast(ctx, 'Diện tích phải là số dương.', error: true);
                          return;
                        }
                        setLocal(() => busy = true);
                        try {
                          await FarmApi.updateZone(
                            zone.zoneId,
                            name: name,
                            areaM2: area,
                            notes: notesC.text.trim().isEmpty ? null : notesC.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx, 'updated');
                        } catch (e) {
                          setLocal(() => busy = false);
                          if (ctx.mounted) _toast(ctx, _err(e), error: true);
                        }
                      },
                child: const Text('Lưu thay đổi'),
              ),
              const SizedBox(height: 14),
              const Divider(),
              const Text('Cây trồng & hồ sơ canh tác', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ZoneCropPlanEditPanel(zone: zone),
              const Divider(),
              const Text('Lịch tưới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ZoneIrrigationPanel(zone: zone),
              const Divider(),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: _red),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Lưu trữ Zone'),
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: const Text('Lưu trữ Zone?'),
                            content: Text(
                              'Zone "${zone.name}" sẽ bị ẩn khỏi trang trại. '
                              'Hệ thống sẽ từ chối nếu Zone còn vụ đang canh tác hoặc thiết bị đang hoạt động.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: _red),
                                onPressed: () => Navigator.pop(d, true),
                                child: const Text('Lưu trữ'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        setLocal(() => busy = true);
                        try {
                          await FarmApi.archiveZone(zone.zoneId);
                          if (ctx.mounted) Navigator.pop(ctx, 'archived');
                        } catch (e) {
                          setLocal(() => busy = false);
                          if (ctx.mounted) _toast(ctx, _err(e), error: true);
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    nameC.dispose();
    areaC.dispose();
    notesC.dispose();
  });
}
