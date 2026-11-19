import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../zones/profile_irrigation_logic.dart';
import '../../zones/zone_auto_season.dart' show autoSeasonDays, minSeasonDays;
import '../../zones/zone_operations_screens.dart'
    show ZonePlantingSeasonsScreen;
import 'season_profile_preview.dart';
import '../../../core/utils/user_error.dart';

/// Tạo vụ trồng cho một Zone (Owner). Cây của Zone chỉ được gán khi tạo vụ:
/// Zone chưa có cây thì vụ mới gán cây; Zone đang có cây khác thì phải tích xác nhận đổi cây.
/// Trả về true khi tạo thành công.
Future<bool?> showCreateSeasonSheet(
  BuildContext context,
  ZoneModel zone,
) async {
  // Mọi lối vào tạo vụ đều qua đây: Zone đã có vụ ĐANG canh tác thì không mở biểu mẫu (backend chỉ cho một vụ đang
  // canh tác mỗi Zone). Không đọc được danh sách vụ thì vẫn mở, biểu mẫu tự kiểm tra lại và backend là nơi quyết định.
  try {
    final seasons = await CropApi.getPlantingSeasons(zoneId: zone.zoneId);
    final running = seasons
        .where((x) => '${x['status']}' == 'InProgress')
        .firstOrNull;
    if (running != null) {
      if (!context.mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Zone đã có vụ đang canh tác',
            style: TextStyle(fontSize: 16),
          ),
          content: Text(
            'Zone "${zone.name}" đang có vụ “${running['name']}” (từ ${running['startDate']}). '
            'Mỗi Zone chỉ có một vụ đang canh tác và hệ thống không tự đóng vụ đang chạy: hãy ghi sản lượng và kết thúc vụ đó '
            '(Zone → Vụ trồng) rồi mới tạo vụ mới.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return false;
    }
  } catch (_) {}
  if (!context.mounted) return false;
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
  // Người dùng đã tự chọn ngày kết thúc: không ghi đè bằng ngày tự tính theo hồ sơ.
  bool _endPicked = false;
  // Mùa vụ chung (không bắt buộc): gom nhiều vụ trồng của nhiều Zone cùng một mùa.
  List<Map<String, dynamic>> _farmingSeasons = [];
  String? _farmingSeasonId;
  bool _confirmChange = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  ProfileSchedule? _profileSchedule;
  bool _loadingSchedule = false;

  Future<void> _fetchProfileSchedule(String profileId) async {
    setState(() => _loadingSchedule = true);
    try {
      final json = await CropApi.getProfileIrrigation(profileId);
      if (!mounted) return;
      setState(() {
        _profileSchedule = ProfileSchedule.fromJson(json);
        _loadingSchedule = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileSchedule = null;
        _loadingSchedule = false;
      });
    }
  }

  static const _newFarmingValue = '__new_farming_season__';

  /// Thêm mùa vụ chung mới (vd. khi sang năm 2027 chưa có mùa vụ nào) rồi chọn luôn cho vụ trồng này.
  Future<void> _addFarmingSeason() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _NewFarmingSeasonDialog(),
    );
    if (created == null || !mounted) return;
    final id = _farmingId(created);
    setState(() {
      if (id != null) {
        _farmingSeasons = [..._farmingSeasons, created];
        _farmingSeasonId = id;
      }
    });
  }

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
      // Mùa vụ chung chỉ là tùy chọn: không tải được thì vẫn tạo được vụ độc lập.
      List<Map<String, dynamic>> farming = [];
      try {
        farming = await CropApi.getFarmingSeasons();
      } catch (_) {}
      // Zone đã gắn hồ sơ canh tác: tự nhận diện cây, giống, hồ sơ của vụ theo hồ sơ đó.
      final zoneProfileId = widget.zone.growthProfileId?.toLowerCase();
      final preset = zoneProfileId == null
          ? null
          : profiles
                .where(
                  (p) => '${p['profileId']}'.toLowerCase() == zoneProfileId,
                )
                .firstOrNull;
      List<Map<String, dynamic>> presetVarieties = [];
      if (preset != null) {
        try {
          presetVarieties = await CropApi.getVarieties(
            cropId: '${preset['cropId']}',
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _farmingSeasons = farming;
        if (preset != null) {
          _cropId = '${preset['cropId']}';
          _varietyId = preset['varietyId']?.toString();
          _profileId = '${preset['profileId']}';
          _varieties = presetVarieties;
          _applyDefaultEnd();
          _fetchProfileSchedule('${preset['profileId']}');
        }
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
        _error = 'Không tải được danh sách cây: ${userFacingError(e)}';
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
        setState(() => _error = 'Không tải được giống: ${userFacingError(e)}');
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _farmingId(Map<String, dynamic> s) {
    final id = '${s['id'] ?? s['seasonId'] ?? ''}'.trim();
    return id.isEmpty ? null : id;
  }

  String _farmingLabel(Map<String, dynamic> s) {
    final name = '${s['name'] ?? ''}'.trim();
    final code = '${s['code'] ?? ''}'.trim();
    return code.isEmpty ? name : '$name ($code)';
  }

  /// Số ngày dự kiến của vụ theo hồ sơ (tổng thời gian các giai đoạn). Hồ sơ không nêu thì dùng mặc định; không ít hơn mức backend yêu cầu.
  int _profileDays(Map<String, dynamic>? profile) {
    var total = 0;
    final stages = profile?['stages'];
    if (stages is List) {
      for (final s in stages) {
        if (s is Map)
          total += num.tryParse('${s['durationDays']}')?.toInt() ?? 0;
      }
    }
    if (total <= 0) {
      total =
          num.tryParse(
            '${profile?['totalDays'] ?? profile?['totalDurationDays'] ?? ''}',
          )?.toInt() ??
          0;
    }
    if (total <= 0) return autoSeasonDays;
    return total < minSeasonDays ? minSeasonDays : total;
  }

  /// Tự điền ngày kết thúc dự kiến theo hồ sơ đã chọn, trừ khi người dùng đã tự chọn ngày.
  /// Gọi bên trong setState.
  void _applyDefaultEnd() {
    if (_endPicked || _profileId == null) return;
    final profile = _profiles
        .followedBy(const <Map<String, dynamic>>[])
        .where((p) => '${p['profileId']}' == _profileId)
        .firstOrNull;
    _end = DateTime(
      _start.year,
      _start.month,
      _start.day + _profileDays(profile),
    );
  }

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
    if (!mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
        _applyDefaultEnd();
      } else {
        _end = picked;
        _endPicked = true;
      }
    });
  }

  Future<void> _submit() async {
    final end = _end;
    if (_running != null) {
      setState(() => _error = _runningMessage());
      return;
    }
    // So theo NGÀY (bỏ giờ): ngày bắt đầu mặc định là "bây giờ" còn ngày chọn từ lịch chỉ có ngày.
    if (end != null &&
        DateUtils.dateOnly(end).isBefore(
          DateTime(_start.year, _start.month, _start.day + minSeasonDays),
        )) {
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
    final farmingName = _farmingSeasons
        .where((s) => _farmingId(s) == _farmingSeasonId)
        .firstOrNull?['name'];
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
          '${farmingName == null ? '' : 'Mùa vụ chung: $farmingName\n'}'
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
        if (_farmingSeasonId != null) 'farmingSeasonId': _farmingSeasonId,
        'setZoneCrop': _confirmChange,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(e);
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
                  ...[
                    DropdownButtonFormField<String?>(
                      key: ValueKey('farming-${_farmingSeasons.length}'),
                      initialValue: _farmingSeasonId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Mùa vụ chung (không bắt buộc)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Không gắn mùa vụ chung (vụ độc lập)'),
                        ),
                        for (final s in _farmingSeasons)
                          DropdownMenuItem<String?>(
                            value: _farmingId(s),
                            child: Text(
                              _farmingLabel(s),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const DropdownMenuItem<String?>(
                          value: _newFarmingValue,
                          child: Text('➕ Thêm mùa vụ chung mới…'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == _newFarmingValue) {
                          _addFarmingSeason();
                        } else {
                          setState(() => _farmingSeasonId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: _cropId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cây trồng *',
                      hintText: 'Chạm để chọn cây',
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
                    decoration: InputDecoration(
                      labelText: 'Hồ sơ sinh trưởng *',
                      hintText: _cropId == null
                          ? 'Chọn cây trước'
                          : 'Chạm để chọn hồ sơ',
                      border: const OutlineInputBorder(),
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
                        : (v) {
                            setState(() {
                              _profileId = v;
                              _applyDefaultEnd();
                            });
                            if (v != null) {
                              _fetchProfileSchedule(v);
                            } else {
                              setState(() => _profileSchedule = null);
                            }
                          },
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
                  _buildProfileIrrigationCard(),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Tên vụ *',
                      hintText: 'Ví dụ: Vụ cà chua đông xuân 2026',
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _saving || _running != null ? null : _submit,
                      child: Text(
                        _saving ? 'Đang tạo…' : 'Tạo vụ trồng',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileIrrigationCard() {
    if (_profileId == null) return const SizedBox.shrink();

    if (_loadingSchedule) {
      return Container(
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF047857),
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Đang tải lịch tưới mẫu của hồ sơ…',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final ps = _profileSchedule;
    if (ps == null || !ps.hasAnySessions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.water_drop,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LỊCH TƯỚI MẪU CỦA HỒ SƠ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SeasonProfilePreview(profileId: _profileId!),
                    ),
                  );
                },
                child: const Text(
                  'Xem chi tiết ➔',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Hệ thống tự động áp dụng lịch tưới 3 ca theo từng giai đoạn phát triển của cây:',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          for (final st in ps.stages.take(4)) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${st.order}. ${st.name}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${st.durationDays} ngày',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                  if (st.sessions.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final s in st.sessions.where((x) => x.enabled))
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                s.title.toLowerCase().contains('sáng')
                                    ? Icons.wb_twilight
                                    : s.title.toLowerCase().contains('trưa')
                                    ? Icons.wb_sunny
                                    : Icons.nights_stay,
                                size: 12,
                                color: s.title.toLowerCase().contains('sáng')
                                    ? const Color(0xFFD97706)
                                    : s.title.toLowerCase().contains('trưa')
                                    ? const Color(0xFFE11D48)
                                    : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${s.title.replaceAll("Tưới ", "")}: ${s.startTime} (${(s.durationSeconds / 60).round()}p)',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (ps.stages.length > 4)
            Text(
              '+ Thêm ${ps.stages.length - 4} giai đoạn tiếp theo...',
              style: const TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF065F46),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hộp thoại thêm mùa vụ chung (Đông-Xuân, Hè-Thu...) cho năm bất kỳ khi chưa có sẵn trong danh sách.
/// Trả về mùa vụ vừa tạo (Map từ backend) hoặc null nếu hủy.
class _NewFarmingSeasonDialog extends StatefulWidget {
  const _NewFarmingSeasonDialog();

  @override
  State<_NewFarmingSeasonDialog> createState() =>
      _NewFarmingSeasonDialogState();
}

class _NewFarmingSeasonDialogState extends State<_NewFarmingSeasonDialog> {
  final _name = TextEditingController();
  final _year = TextEditingController();
  late DateTime _start = DateTime.now();
  late DateTime _end = DateTime.now().add(const Duration(days: 120));
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _year.text = '${_start.year}';
  }

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pick(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
        _year.text = '${picked.year}';
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(days: 120));
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final year = int.tryParse(_year.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Hãy nhập tên mùa vụ.');
      return;
    }
    if (year == null || year < 2001 || year > 2100) {
      setState(() => _error = 'Năm không hợp lệ.');
      return;
    }
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await CropApi.createFarmingSeason(
        name: name,
        year: year,
        startDate: _start,
        endDate: _end,
      );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userFacingError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Thêm mùa vụ chung mới',
        style: TextStyle(fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tên mùa vụ *',
                hintText: 'Ví dụ: Đông Xuân 2027',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Năm *',
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
                    child: Text('Kết thúc: ${_fmt(_end)}'),
                  ),
                ),
              ],
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang tạo…' : 'Tạo mùa vụ'),
        ),
      ],
    );
  }
}
