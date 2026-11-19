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
import '../../../core/utils/user_error.dart';

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

  String _err(Object e) => userFacingError(e);

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
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.spa_outlined,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Zone chưa gắn hồ sơ canh tác. Chọn một hồ sơ để gắn trực tiếp cho Zone (không tạo vụ trồng).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!hasProfile || _changing) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasProfile) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          size: 18,
                          color: Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ĐỔI HỒ SƠ CANH TÁC',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                ZoneCropPlanSection(controller: _plan),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (hasProfile) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _changing = false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                    child: const Text('Hủy đổi hồ sơ'),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_message != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF334155),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _message!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHeroStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF15803D)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF14532D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final totalDays = stages.fold<int>(0, (sum, st) => sum + st.durationDays);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Hero Profile Card ───
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF047857),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile?['cropName'] ?? ''}${profile?['varietyName'] == null ? '' : ' · giống ${profile!['varietyName']}'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isSystem
                                ? const Color(0xFFF1F5F9)
                                : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSystem
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSystem
                                    ? Icons.verified_user_outlined
                                    : Icons.home_work_outlined,
                                size: 12,
                                color: isSystem
                                    ? const Color(0xFF475569)
                                    : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSystem
                                    ? 'Hồ sơ hệ thống'
                                    : 'Hồ sơ trang trại',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSystem
                                      ? const Color(0xFF475569)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: Color(0xFF047857),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Hồ sơ: $profileName (${isSystem ? 'hệ thống, chỉ xem/sao chép' : 'riêng của trang trại'})',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_season != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Vụ ${_season!['status'] == 'InProgress' ? 'đang chạy' : 'dự kiến'}: ${_season!['name']} · dùng hồ sơ "$seasonProfile"'
                              '${seasonProfile != null && seasonProfile != profile?['name'] ? ' (khác hồ sơ của Zone; vụ giữ hồ sơ riêng của nó)' : ''}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (stages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeroStat(
                        icon: Icons.timer_outlined,
                        label: 'Chu kỳ',
                        value: '$totalDays ngày',
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFBBF7D0),
                      ),
                      _buildHeroStat(
                        icon: Icons.timeline_rounded,
                        label: 'Giai đoạn',
                        value: '${stages.length} bước',
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: const Color(0xFFBBF7D0),
                      ),
                      _buildHeroStat(
                        icon: Icons.grid_view_rounded,
                        label: 'Khu vực',
                        value: widget.zone.name,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ─── Header: Danh sách giai đoạn sinh trưởng ───
        if (profile != null && stages.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.timeline_rounded,
                  size: 16,
                  color: Color(0xFF047857),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'CÁC GIAI ĐOẠN SINH TRƯỞNG (${stages.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                if (totalDays > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tổng $totalDays ngày',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        if (profile == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Không đọc được chi tiết hồ sơ (có thể hồ sơ không còn hiển thị với tài khoản này).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB45309),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (final st in stages) StageDraftTile(stage: st),

        const SizedBox(height: 8),

        // ─── Action Buttons Card ───
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!isSystem && profile != null && stages.isNotEmpty)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _editOwnProfile(stages),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'Sửa hồ sơ riêng',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _changing = !_changing),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF047857),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text(
                      'Đổi hồ sơ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _clear,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      side: BorderSide(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text(
                      'Gỡ hồ sơ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (isSystem) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hồ sơ hệ thống không sửa trực tiếp. Muốn chỉnh giai đoạn, ngưỡng hoặc lịch tưới: bấm "Đổi hồ sơ" rồi chọn "Tùy chỉnh bản sao".',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
