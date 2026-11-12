import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../zones/zone_operations_screens.dart'
    show ZonePlantingSeasonsScreen;

/// Tạo vụ trồng cho một Zone (Owner). Cây của Zone chỉ được gán khi tạo vụ:
/// Zone chưa có cây thì vụ mới gán cây; Zone đang có cây khác thì phải tích xác nhận đổi cây.
/// Trả về true khi tạo thành công.
Future<bool?> showCreateSeasonSheet(BuildContext context, ZoneModel zone) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
  List<Map<String, dynamic>> _varieties = [];
  Map<String, dynamic>? _running; // vụ đang canh tác của Zone (nếu có)
  String? _cropId;
  String? _varietyId;
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
      final crops = await CropApi.getCropsForProfiles();
      final profiles = await CropApi.getGrowthProfiles();
      // Kiểm tra TRƯỚC khi gửi: Zone đã có vụ đang canh tác thì không thể tạo vụ mới (hệ thống không tự đóng vụ đang chạy).
      final seasons = await CropApi.getPlantingSeasons(
        zoneId: widget.zone.zoneId,
      );
      if (!mounted) return;
      setState(() {
        _running = seasons
            .where((x) => '${x['status']}' == 'InProgress')
            .firstOrNull;
        _profiles = profiles;
        // Chỉ cây đã có hồ sơ sinh trưởng mới tạo được vụ.
        _crops = crops
            .where(
              (c) => profiles.any(
                (p) => p['cropId']?.toString() == c['cropId']?.toString(),
              ),
            )
            .toList();
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

  /// Đóng form và mở danh sách vụ của Zone để người dùng xử lý vụ đang chạy.
  void _openRunningSeason() {
    final nav = Navigator.of(context);
    nav.pop(false);
    nav.push(
      MaterialPageRoute(
        builder: (_) => ZonePlantingSeasonsScreen(zone: widget.zone),
      ),
    );
  }

  /// Sau lỗi từ máy chủ (vd. 409 do vụ vừa được tạo ở nơi khác): kiểm tra lại vụ đang chạy để hiện hướng xử lý.
  Future<void> _refreshRunning() async {
    try {
      final seasons = await CropApi.getPlantingSeasons(
        zoneId: widget.zone.zoneId,
      );
      if (mounted)
        setState(
          () => _running = seasons
              .where((x) => '${x['status']}' == 'InProgress')
              .firstOrNull,
        );
    } catch (_) {}
  }

  String _runningMessage() {
    final r = _running!;
    return 'Zone đang có vụ “${r['name']}” đang canh tác (từ ${r['startDate']}). Hệ thống không tự đóng vụ đang chạy: '
        'hãy kết thúc vụ đó (Zone → Vụ trồng → Ghi sản lượng → Kết thúc vụ) rồi tạo vụ mới.';
  }

  /// Hồ sơ hợp lệ cho cây + giống đã chọn: backend yêu cầu hồ sơ trùng đúng giống (hồ sơ chung chỉ dùng khi không chọn giống).
  List<Map<String, dynamic>> get _matchingProfiles => [
    for (final p in _profiles)
      if (p['cropId']?.toString() == _cropId &&
          (p['varietyId']?.toString() == _varietyId))
        p,
  ];

  Future<void> _selectCrop(String? id) async {
    setState(() {
      _cropId = id;
      _varietyId = null;
      _profileId = null;
      _varieties = [];
    });
    if (id == null) return;
    try {
      final v = await CropApi.getVarieties(cropId: id);
      if (mounted && _cropId == id) setState(() => _varieties = v);
    } catch (e) {
      if (mounted)
        setState(
          () => _error =
              'Không tải được giống: ${e.toString().replaceFirst('Exception: ', '')}',
        );
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool isStart) async {
    final initial = isStart
        ? _start
        : (_end ?? _start.add(const Duration(days: 90)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: isStart
          ? DateTime.now()
          : DateTime(
              2100,
            ), // backend chỉ tạo vụ đang canh tác: không nhận ngày bắt đầu tương lai
    );
    if (picked == null) return;
    if (mounted) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _submit() async {
    final end = _end;
    if (_running != null) {
      setState(() => _error = _runningMessage());
      return;
    }
    if (end != null && end.isBefore(_start.add(const Duration(days: 20)))) {
      setState(
        () => _error =
            'Ngày kết thúc dự kiến phải sau ngày bắt đầu ít nhất 20 ngày.',
      );
      return;
    }
    if (_cropId == null ||
        _profileId == null ||
        _nameCtrl.text.trim().isEmpty ||
        end == null) {
      setState(
        () => _error =
            'Hãy chọn cây, hồ sơ sinh trưởng, đặt tên và chọn ngày kết thúc dự kiến.',
      );
      return;
    }
    // Xác nhận trước khi tạo vụ cho Zone (một vụ riêng của Zone này; không tự đóng vụ khác).
    final cropName =
        _crops
            .where((c) => c['cropId']?.toString() == _cropId)
            .firstOrNull?['name'] ??
        '—';
    final varietyName = _varieties
        .where((v) => '${v['varietyId']}' == _varietyId)
        .firstOrNull?['name'];
    final profileName =
        _matchingProfiles
            .where((p) => '${p['profileId']}' == _profileId)
            .firstOrNull?['name'] ??
        '—';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Tạo vụ trồng cho Zone?',
          style: TextStyle(fontSize: 15),
        ),
        content: Text(
          'Zone: ${widget.zone.name}\n'
          'Cây: $cropName${varietyName == null ? '' : ' · giống $varietyName'}\n'
          'Hồ sơ: $profileName\n'
          'Vụ: ${_nameCtrl.text.trim()}\n'
          'Từ ${_fmt(_start)} đến ${_fmt(end)} (dự kiến)\n'
          '${_confirmChange ? '\nBạn đã xác nhận đổi/gán cây của Zone theo cây của vụ này.\n' : ''}'
          '\nVụ được tạo ở trạng thái đang canh tác ngay.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận tạo vụ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CropApi.createPlantingSeason(widget.zone.zoneId, {
        'name': _nameCtrl.text.trim(),
        'cropId': _cropId,
        if (_varietyId != null) 'varietyId': _varietyId,
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
        await _refreshRunning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = _matchingProfiles;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tạo vụ trồng — ${widget.zone.name}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _zoneHasCrop
                        ? 'Cây hiện tại của Zone: ${widget.zone.currentCrop}'
                        : 'Zone chưa gán cây; cây của vụ này sẽ được gán cho Zone.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _cropId,
                    decoration: const InputDecoration(
                      labelText: 'Cây trồng *',
                      border: OutlineInputBorder(),
                    ),
                    items: _crops
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['cropId']?.toString(),
                            child: Text(c['name']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: _selectCrop,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('variety-$_cropId-${_varieties.length}'),
                    initialValue: _varietyId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Giống (không bắt buộc)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Không chọn giống (hồ sơ chung)'),
                      ),
                      for (final v in _varieties)
                        DropdownMenuItem<String?>(
                          value: '${v['varietyId']}',
                          child: Text('${v['name']}'),
                        ),
                    ],
                    onChanged: _cropId == null
                        ? null
                        : (v) => setState(() {
                            _varietyId = v;
                            _profileId =
                                null; // hồ sơ cũ có thể không còn khớp giống mới
                          }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('profile-$_cropId-$_varietyId'),
                    initialValue: _profileId,
                    decoration: const InputDecoration(
                      labelText: 'Hồ sơ sinh trưởng *',
                      border: OutlineInputBorder(),
                    ),
                    items: profiles
                        .map(
                          (p) => DropdownMenuItem(
                            value:
                                (p['profileId'] ??
                                        p['growthProfileId'] ??
                                        p['id'])
                                    ?.toString(),
                            child: Text(
                              p['name']?.toString() ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _cropId == null
                        ? null
                        : (v) => setState(() => _profileId = v),
                    isExpanded: true,
                  ),
                  if (_cropId != null && profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Chưa có hồ sơ canh tác khớp đúng cây và giống này. Hãy chọn giống khác hoặc "Không chọn giống".',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên vụ *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pick(true),
                          child: Text('Bắt đầu: ${_fmt(_start)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pick(false),
                          child: Text(
                            _end == null
                                ? 'Kết thúc dự kiến *'
                                : 'Kết thúc: ${_fmt(_end!)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_zoneHasCrop)
                    CheckboxListTile(
                      value: _confirmChange,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) =>
                          setState(() => _confirmChange = v ?? false),
                      title: const Text(
                        'Xác nhận đổi cây của Zone nếu cây của vụ khác cây hiện tại',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  if (_running != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _runningMessage(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _openRunningSeason,
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Xem vụ hiện tại'),
                          ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving || _running != null ? null : _submit,
                      child: Text(_saving ? 'Đang tạo…' : 'Tạo vụ trồng'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
