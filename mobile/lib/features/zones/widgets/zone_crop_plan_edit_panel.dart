import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../zone_crop_plan_applier.dart';
import '../zone_crop_plan_controller.dart';
import '../zone_crop_plan_logic.dart';
import 'own_profile_editor.dart';
import 'stage_draft_tile.dart';
import 'zone_crop_plan_section.dart';
import 'zone_profile_detail_page.dart';

/// Hồ sơ canh tác của Zone khi SỬA Zone. Hồ sơ được lưu TRỰC TIẾP trên Zone (Zone.GrowthProfileId), không qua vụ mùa:
/// mở lại Zone là tải đúng hồ sơ từ máy chủ. Chọn/đổi/gỡ hồ sơ không tạo hay đổi vụ mùa; vụ mùa giữ hồ sơ riêng của nó.
/// Hồ sơ hệ thống chỉ xem hoặc sao chép; hồ sơ riêng của trang trại sửa được (tên, mô tả, giai đoạn, ngưỡng).
class ZoneCropPlanEditPanel extends StatefulWidget {
  final ZoneModel zone;
  const ZoneCropPlanEditPanel({super.key, required this.zone});

  @override
  State<ZoneCropPlanEditPanel> createState() => _ZoneCropPlanEditPanelState();
}

class _ZoneCropPlanEditPanelState extends State<ZoneCropPlanEditPanel> {
  final ZoneCropPlanController _plan = ZoneCropPlanController();
  bool _loading = true;
  String? _error;
  String? _profileId; // hồ sơ đang gắn trên Zone (từ Zone API)
  Map<String, dynamic>? _profile; // chi tiết hồ sơ (từ GET /growth-profiles)
  Map<String, dynamic>? _season; // vụ đang chạy/dự kiến (chỉ để thông tin)
  bool _changing = false;
  bool _busy = false;
  String? _message;
  String? _preparedCloneId;
  String? _preparedKey;

  @override
  void initState() {
    super.initState();
    _profileId = widget.zone.growthProfileId;
    _load();
  }

  @override
  void dispose() {
    _plan.dispose();
    super.dispose();
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seasons = await CropApi.getPlantingSeasons(
        zoneId: widget.zone.zoneId,
      );
      Map<String, dynamic>? pick(String status) =>
          seasons.where((s) => '${s['status']}' == status).firstOrNull;
      Map<String, dynamic>? profile;
      if (_profileId != null) {
        final all = await CropApi.getGrowthProfiles();
        profile = all
            .where((p) => '${p['profileId']}' == _profileId)
            .firstOrNull;
      }
      if (!mounted) return;
      setState(() {
        _season = pick('InProgress') ?? pick('Planned');
        _profile = profile;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmApply(String newName) {
    final sel = _plan.selection;
    final p = _plan.currentProfile;
    return confirmApplyProfile(
      context,
      zoneName: widget.zone.name,
      profileName: newName,
      cropName: '${_plan.currentCrop?['name'] ?? p?['cropName'] ?? ''}',
      varietyName: p == null ? null : _plan.varietyNameOf(p),
      isSystem: p?['isSystemDefined'] == true,
      willClone: sel.mode == ZoneProfileMode.custom,
      stageCount: sel.stages.length,
      currentProfileName: _profileId == null
          ? null
          : '${_profile?['name'] ?? widget.zone.growthProfileName ?? 'hồ sơ hiện tại'}',
    );
  }

  String _selectionKey(ZoneCropSelection sel) {
    final stages = [
      for (final s in sel.stages)
        '${s.durationDays}:${[for (final r in s.requirements) '${r.min},${r.max},${r.target}'].join(';')}',
    ].join('/');
    return '${sel.profileId}|${sel.customName}|${sel.customDescription}|$stages';
  }

  Future<void> _apply() async {
    final problem = _plan.validate();
    final sel = _plan.selection;
    if (problem != null || !sel.active) {
      setState(
        () => _message = problem ?? 'Chọn cây và hồ sơ trước khi áp dụng.',
      );
      return;
    }
    final newName = sel.mode == ZoneProfileMode.custom
        ? sel.customName.trim()
        : '${_plan.currentProfile?['name'] ?? 'hồ sơ đã chọn'}';
    if (!await _confirmApply(newName)) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final provider = context.read<FarmProvider>();
    final key = _selectionKey(sel);
    final prep = await prepareZoneProfile(
      selection: sel,
      reuseCloneId: _preparedKey == key ? _preparedCloneId : null,
    );
    if (prep.cloned && prep.profileId != null) {
      _preparedCloneId = prep.profileId;
      _preparedKey = key;
    }
    if (!prep.ok) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message =
              '${prep.error} Dữ liệu bạn nhập được giữ nguyên, bấm lại để tiếp tục.';
        });
      }
      return;
    }
    final err = await attachProfileToZone(
      zoneId: widget.zone.zoneId,
      zoneName: widget.zone.name,
      profileId: prep.profileId!,
      notes: widget.zone.notes,
    );
    if (err == null) await provider.fetchFromApi();
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _message =
            'Chưa gắn được hồ sơ cho Zone: $err'
            '${prep.cloned ? ' (hồ sơ riêng "$newName" đã được tạo và sẽ được dùng lại khi bạn thử lại)' : ''}';
      });
      return;
    }
    setState(() {
      _profileId = prep.profileId;
      _changing = false;
      _busy = false;
    });
    await _load();
    if (mounted)
      setState(
        () => _message =
            'Đã gắn hồ sơ "$newName" cho Zone. Không có vụ trồng nào được tạo.',
      );
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Gỡ hồ sơ khỏi Zone?',
          style: TextStyle(fontSize: 15),
        ),
        content: const Text(
          'Zone sẽ không còn hồ sơ canh tác (cây của Zone giữ nguyên). Vụ trồng và lịch điều khiển đã có không bị xóa.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ hồ sơ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<FarmProvider>();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await FarmApi.updateZone(
        widget.zone.zoneId,
        name: widget.zone.name,
        notes: widget.zone.notes,
        clearGrowthProfile: true,
      );
      await provider.fetchFromApi();
      if (!mounted) return;
      setState(() {
        _profileId = null;
        _profile = null;
        _message = 'Đã gỡ hồ sơ khỏi Zone.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Không gỡ được hồ sơ: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editOwnProfile(List<StageDraft> stages) async {
    final p = _profile;
    if (p == null) return;
    final saved = await showOwnProfileEditor(
      context,
      profileId: '${p['profileId']}',
      name: '${p['name']}',
      description: p['description'] as String?,
      stages: stages,
    );
    if (saved == true) {
      await _load();
      if (mounted) setState(() => _message = 'Đã lưu hồ sơ riêng.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Không tải được hồ sơ của Zone: $_error',
            style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
          ),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      );
    }
    final hasProfile = _profileId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasProfile) _currentProfile(),
        if (!hasProfile)
          const Text(
            'Zone chưa gắn hồ sơ canh tác. Chọn một hồ sơ để gắn trực tiếp cho Zone (không tạo vụ trồng).',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        if (!hasProfile || _changing) ...[
          const SizedBox(height: 8),
          ZoneCropPlanSection(controller: _plan),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _apply,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.spa_outlined, size: 18),
            label: Text(
              hasProfile ? 'Đổi hồ sơ của Zone' : 'Gắn hồ sơ cho Zone',
            ),
          ),
          if (hasProfile)
            TextButton(
              onPressed: _busy ? null : () => setState(() => _changing = false),
              child: const Text('Hủy đổi hồ sơ'),
            ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _message!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
            ),
          ),
      ],
    );
  }

  Widget _currentProfile() {
    final profile = _profile;
    final isSystem =
        (profile?['isSystemDefined'] ?? widget.zone.growthProfileIsSystem) ==
        true;
    final stages = [
      for (final s in (profile?['stages'] as List? ?? const []))
        if (s is Map) StageDraft.fromJson(Map<String, dynamic>.from(s)),
    ]..sort((a, b) => a.order.compareTo(b.order));
    final seasonProfile = _season?['growthProfileName'];
    final profileName =
        profile?['name'] ?? widget.zone.growthProfileName ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${profile?['cropName'] ?? ''}${profile?['varietyName'] == null ? '' : ' · giống ${profile!['varietyName']}'}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          'Hồ sơ: $profileName (${isSystem ? 'hệ thống, chỉ xem/sao chép' : 'riêng của trang trại'})',
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        if (_season != null)
          Text(
            'Vụ ${_season!['status'] == 'InProgress' ? 'đang chạy' : 'dự kiến'}: ${_season!['name']} · dùng hồ sơ "$seasonProfile"'
            '${seasonProfile != null && seasonProfile != profile?['name'] ? ' (khác hồ sơ của Zone; vụ giữ hồ sơ riêng của nó)' : ''}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        const SizedBox(height: 6),
        if (profile == null)
          const Text(
            'Không đọc được chi tiết hồ sơ (có thể hồ sơ không còn hiển thị với tài khoản này).',
            style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
          )
        else
          for (final st in stages) StageDraftTile(stage: st),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (!isSystem && profile != null && stages.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _editOwnProfile(stages),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Sửa hồ sơ riêng'),
              ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => _changing = !_changing),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Đổi hồ sơ'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Gỡ hồ sơ'),
            ),
          ],
        ),
        if (isSystem)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Hồ sơ hệ thống không sửa trực tiếp. Muốn chỉnh giai đoạn, ngưỡng hoặc lịch tưới: bấm "Đổi hồ sơ" rồi chọn '
              '"Tùy chỉnh bản sao".',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}
