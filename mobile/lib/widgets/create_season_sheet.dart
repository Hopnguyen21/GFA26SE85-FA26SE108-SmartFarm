import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Tạo vụ mùa cho một Zone (Owner). Cây của Zone chỉ được gán khi tạo vụ:
/// Zone chưa có cây thì vụ mới gán cây; Zone đang có cây khác thì phải tích xác nhận đổi cây.
/// Trả về true khi tạo thành công.
Future<bool?> showCreateSeasonSheet(BuildContext context, ZoneModel zone) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _CreateSeasonForm(zone: zone),
    ),
  );
}

class _CreateSeasonForm extends StatefulWidget {
  final ZoneModel zone;
  const _CreateSeasonForm({required this.zone});

  @override
  State<_CreateSeasonForm> createState() => _CreateSeasonFormState();
}

class _CreateSeasonFormState extends State<_CreateSeasonForm> {
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _profiles = [];
  String? _cropId;
  String? _profileId;
  final _nameCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool _confirmChange = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _zoneHasCrop => !widget.zone.currentCrop.startsWith('Chưa gán cây');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final crops = await ApiService.getCropsForProfiles();
      final profiles = await ApiService.getGrowthProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        // Chỉ cây đã có hồ sơ sinh trưởng mới tạo được vụ.
        _crops = crops.where((c) => profiles.any((p) => p['cropId']?.toString() == c['cropId']?.toString())).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được danh sách cây: $e';
        _loading = false;
      });
    }
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? _start : (_end ?? _start.add(const Duration(days: 90)));
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _submit() async {
    final profile = _profiles.firstWhere((p) => (p['profileId'] ?? p['growthProfileId'] ?? p['id'])?.toString() == _profileId, orElse: () => {});
    final end = _end;
    if (_cropId == null || _profileId == null || _nameCtrl.text.trim().isEmpty || end == null) {
      setState(() => _error = 'Hãy chọn cây, hồ sơ sinh trưởng, đặt tên và chọn ngày kết thúc dự kiến.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.createPlantingSeason(widget.zone.zoneId, {
        'name': _nameCtrl.text.trim(),
        'cropId': _cropId,
        if (profile['varietyId'] != null) 'varietyId': profile['varietyId'],
        'growthProfileId': _profileId,
        'startDate': _fmt(_start),
        'expectedEndDate': _fmt(end),
        'setZoneCrop': _confirmChange,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _profiles.where((p) => p['cropId']?.toString() == _cropId).toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tạo vụ mùa — ${widget.zone.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _zoneHasCrop ? 'Cây hiện tại của Zone: ${widget.zone.currentCrop}' : 'Zone chưa gán cây; cây của vụ này sẽ được gán cho Zone.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _cropId,
                    decoration: const InputDecoration(labelText: 'Cây trồng *', border: OutlineInputBorder()),
                    items: _crops.map((c) => DropdownMenuItem(value: c['cropId']?.toString(), child: Text(c['name']?.toString() ?? ''))).toList(),
                    onChanged: (v) => setState(() {
                      _cropId = v;
                      _profileId = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _profileId,
                    decoration: const InputDecoration(labelText: 'Hồ sơ sinh trưởng *', border: OutlineInputBorder()),
                    items: profiles
                        .map((p) => DropdownMenuItem(
                              value: (p['profileId'] ?? p['growthProfileId'] ?? p['id'])?.toString(),
                              child: Text(p['name']?.toString() ?? '', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: _cropId == null ? null : (v) => setState(() => _profileId = v),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên vụ *', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('Bắt đầu: ${_fmt(_start)}'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text(_end == null ? 'Kết thúc dự kiến *' : 'Kết thúc: ${_fmt(_end!)}'))),
                    ],
                  ),
                  if (_zoneHasCrop)
                    CheckboxListTile(
                      value: _confirmChange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() => _confirmChange = v ?? false),
                      title: const Text('Xác nhận đổi cây của Zone nếu cây của vụ khác cây hiện tại', style: TextStyle(fontSize: 12)),
                    ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12))),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'Đang tạo…' : 'Tạo vụ mùa'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
