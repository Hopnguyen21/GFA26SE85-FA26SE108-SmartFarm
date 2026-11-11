part of '../zone_contract_forms.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Hồ sơ khấu hao: chọn thiết bị thật trong Zone
// ═══════════════════════════════════════════════════════════════════════════
/// Trả về true nếu đã tạo.
Future<bool?> showCreateDepreciationSheet(
  BuildContext context, {
  required List<ZoneModel> zones,
  required Set<String> deviceIdsWithDepreciation,
  String? initialZoneId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DepreciationSheet(
      zones: zones,
      existing: deviceIdsWithDepreciation.map((e) => e.toLowerCase()).toSet(),
      initialZoneId: initialZoneId,
    ),
  );
}

class _DepreciationSheet extends StatefulWidget {
  final List<ZoneModel> zones;
  final Set<String> existing;
  final String? initialZoneId;
  const _DepreciationSheet({required this.zones, required this.existing, this.initialZoneId});
  @override
  State<_DepreciationSheet> createState() => _DepreciationSheetState();
}

class _DepreciationSheetState extends State<_DepreciationSheet> {
  late String _zoneId = widget.zones.any((z) => z.zoneId == widget.initialZoneId)
      ? widget.initialZoneId!
      : widget.zones.first.zoneId;
  Future<List<Map<String, dynamic>>>? _devices;
  String? _deviceId;
  final _cost = TextEditingController();
  final _months = TextEditingController(text: '36');
  final _notes = TextEditingController();
  DateTime _start = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() {
    _deviceId = null;
    _devices = SupportApi.listZoneDevices(_zoneId);
  }

  @override
  void dispose() {
    _cost.dispose();
    _months.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cost = _money(_cost);
    final months = int.tryParse(_months.text.trim());
    if (_deviceId == null) return _snack(context, 'Chọn thiết bị cần trích khấu hao.', error: true);
    if (cost == null || cost <= 0) return _snack(context, 'Nguyên giá phải > 0.', error: true);
    if (months == null || months < 1 || months > 120) {
      return _snack(context, 'Thời gian khấu hao từ 1 đến 120 tháng.', error: true);
    }
    setState(() => _busy = true);
    try {
      await ContractApi.createDeviceDepreciation(_zoneId, {
        'deviceId': _deviceId,
        'originalCostVnd': cost,
        'depreciationLifetimeMonths': months,
        'startDate': _ymd.format(_start),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(context, _err(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = _money(_cost) ?? 0;
    final months = int.tryParse(_months.text.trim()) ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thêm hồ sơ khấu hao thiết bị', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _zoneId,
              isExpanded: true,
              decoration: _dec('Zone'),
              items: [for (final z in widget.zones) DropdownMenuItem(value: z.zoneId, child: Text(z.name))],
              onChanged: (v) => setState(() {
                _zoneId = v ?? _zoneId;
                _loadDevices();
              }),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _devices,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const LinearProgressIndicator(minHeight: 2);
                if (snap.hasError) {
                  return Text(
                    'Không tải được thiết bị: ${_err(snap.error!)}',
                    style: const TextStyle(color: Color(0xFFDC2626)),
                  );
                }
                final devices = snap.data!
                    .where((d) => '${d['status']}' != 'Decommissioned')
                    .where((d) => !widget.existing.contains('${d['deviceId']}'.toLowerCase()))
                    .toList();
                if (devices.isEmpty) {
                  return const Text(
                    'Zone này không còn thiết bị nào chưa có hồ sơ khấu hao.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  );
                }
                return DropdownButtonFormField<String>(
                  key: ValueKey(_zoneId),
                  initialValue: _deviceId,
                  isExpanded: true,
                  decoration: _dec('Thiết bị *'),
                  items: [
                    for (final d in devices)
                      DropdownMenuItem(
                        value: '${d['deviceId']}',
                        child: Text(
                          '${d['hardwareAddress']} · ${d['deviceType']} · ${d['status']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _deviceId = v),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('Nguyên giá (₫) *'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _months,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: _dec('Số tháng (1–120)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.event, size: 16),
              label: Text('Bắt đầu khấu hao: ${_dmy.format(_start)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime(2015),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _start = d);
              },
            ),
            if (cost > 0 && months > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Khấu hao đường thẳng ≈ ${_vnd.format((cost / months).roundToDouble())}/tháng.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            const SizedBox(height: 10),
            TextField(controller: _notes, maxLines: 2, decoration: _dec('Ghi chú (bảo hành, nhà cung cấp…)')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu hồ sơ khấu hao'),
            ),
          ],
        ),
      ),
    );
  }
}
