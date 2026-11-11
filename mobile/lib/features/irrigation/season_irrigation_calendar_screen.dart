import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../zones/profile_irrigation_logic.dart';
import '../zones/widgets/profile_irrigation_view.dart';
import 'season_irrigation_logic.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF475569);
const _green = Color(0xFF059669);
const _amber = Color(0xFFB45309);

/// Lịch tưới THEO NGÀY của một vụ trồng (Zone + mùa vụ), đọc/ghi qua backend (không lưu cục bộ). Phân biệt rõ 3 loại lịch:
///  1. Lịch mẫu/đề xuất theo Growth Profile (giai đoạn) — không bị sửa ở đây;
///  2. Lịch tùy chỉnh theo ngày của vụ — thứ màn này sửa;
///  3. Lịch điều khiển thật trên thiết bị (ControlSchedule) — chỉ đổi khi đồng bộ.
class SeasonIrrigationCalendarScreen extends StatefulWidget {
  final ZoneModel zone;

  /// Vụ cần mở; bỏ trống = vụ đang chạy của Zone (rồi vụ dự kiến).
  final String? seasonId;
  const SeasonIrrigationCalendarScreen({super.key, required this.zone, this.seasonId});

  @override
  State<SeasonIrrigationCalendarScreen> createState() => _SeasonIrrigationCalendarScreenState();
}

class _SeasonIrrigationCalendarScreenState extends State<SeasonIrrigationCalendarScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _seasons = [];
  String? _seasonId;
  SeasonIrrigationCalendar? _cal;
  int _selected = 1;
  String _stageFilter = 'ALL';
  bool _busy = false;

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void initState() {
    super.initState();
    _load(seasonId: widget.seasonId);
  }

  /// Tải danh sách vụ của Zone rồi lịch của vụ được chọn (mặc định: vụ đang chạy, rồi vụ dự kiến).
  Future<void> _load({String? seasonId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await CropApi.getPlantingSeasons(zoneId: widget.zone.zoneId);
      final usable = [
        for (final s in all)
          if ('${s['status']}' == 'InProgress' || '${s['status']}' == 'Planned') s,
      ];
      _seasons = usable;
      Map<String, dynamic>? pick = usable.where((s) => '${s['seasonId']}' == (seasonId ?? _seasonId)).firstOrNull;
      pick ??= usable.where((s) => '${s['status']}' == 'InProgress').firstOrNull ?? usable.firstOrNull;
      if (pick == null) {
        if (!mounted) return;
        setState(() {
          _seasonId = null;
          _cal = null;
          _loading = false;
        });
        return;
      }
      final id = '${pick['seasonId']}';
      final json = await CropApi.getSeasonIrrigation(widget.zone.zoneId, id);
      if (!mounted) return;
      final cal = SeasonIrrigationCalendar.fromJson(json);
      setState(() {
        _seasonId = id;
        _cal = cal;
        _selected = cal.todayDayNumber ?? 1;
        _stageFilter = 'ALL';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _err(e);
          _loading = false;
        });
      }
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFDC2626) : _green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Chạy một thao tác ghi: chỉ báo thành công khi backend xác nhận, và dùng đúng dữ liệu backend trả về.
  Future<void> _write(Future<Map<String, dynamic>> Function() call, String success) async {
    setState(() => _busy = true);
    try {
      final json = await call();
      if (!mounted) return;
      setState(() => _cal = SeasonIrrigationCalendar.fromJson(json));
      _toast(success);
    } catch (e) {
      if (mounted) _toast('Không lưu được: ${_err(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDays(List<int> days, List<ProfileSession> sessions, String success) {
    final c = _cal!;
    return _write(
      () => CropApi.updateSeasonIrrigation(c.zoneId, c.seasonId, [
        for (final d in days) dayIrrigationPayload(d, sessions),
      ]),
      success,
    );
  }

  Future<void> _editDay(SeasonDay day) async {
    final c = _cal!;
    final edit = await showStageSessionsEditor(
      context,
      StageSchedule(
        stageId: day.stageId ?? '',
        name: 'Ngày ${day.dayNumber}',
        order: day.dayNumber,
        durationDays: 1,
        source: day.source.code,
        sessions: day.sessions,
      ),
      canApplyAll: day.stageId != null,
      title: 'Ca tưới · Ngày ${day.dayNumber} (${day.shortDate})',
      hint:
          'Chỉ lưu cho vụ này (lịch tùy chỉnh theo ngày), không đổi lịch mẫu của hồ sơ. Giờ HH:mm theo múi giờ trang trại. '
          'Mỗi ca tối đa 30 phút. Không có ca nào = ngày này không tưới.',
      applyAllLabel: 'Áp dụng cho mọi ngày cùng giai đoạn "${day.stageName ?? ''}"',
    );
    if (edit == null || !mounted) return;
    final problem = validateStageSessions(edit.sessions);
    if (problem != null) {
      _toast(problem, error: true);
      return;
    }
    final days = edit.applyToAllStages ? targetDays(c, day, wholeSeason: false) : [day.dayNumber];
    await _saveDays(
      days,
      edit.sessions,
      days.length == 1
          ? 'Đã lưu lịch tưới riêng cho ngày ${day.dayNumber}.'
          : 'Đã lưu lịch tưới riêng cho ${days.length} ngày của giai đoạn "${day.stageName}".',
    );
  }

  Future<void> _applyElsewhere(SeasonDay day, {required bool wholeSeason}) async {
    final c = _cal!;
    final days = targetDays(c, day, wholeSeason: wholeSeason);
    if (days.isEmpty) return;
    final ok = await _confirm(
      wholeSeason ? 'Áp dụng cho cả vụ?' : 'Áp dụng cho cả giai đoạn?',
      'Ca tưới của ngày ${day.dayNumber} sẽ ghi đè lịch của ${days.length} ngày'
          '${wholeSeason ? ' trong vụ' : ' thuộc giai đoạn "${day.stageName}"'}. Lịch mẫu của hồ sơ không bị đổi; bạn có thể khôi phục từng ngày hoặc cả vụ.',
      'Áp dụng',
    );
    if (!ok || !mounted) return;
    await _saveDays(days, day.sessions, 'Đã áp dụng ca tưới của ngày ${day.dayNumber} cho ${days.length} ngày.');
  }

  Future<void> _resetDay(SeasonDay day) async {
    final c = _cal!;
    final ok = await _confirm(
      'Khôi phục ngày ${day.dayNumber}?',
      'Ngày này sẽ quay về lịch mẫu của hồ sơ. Các ngày khác không đổi.',
      'Khôi phục',
    );
    if (!ok || !mounted) return;
    await _write(
      () => CropApi.resetSeasonIrrigation(c.zoneId, c.seasonId, dayNumber: day.dayNumber),
      'Đã khôi phục ngày ${day.dayNumber} về lịch mẫu.',
    );
  }

  Future<void> _resetAll() async {
    final c = _cal!;
    final ok = await _confirm(
      'Khôi phục cả mùa vụ?',
      'Mọi ngày tùy chỉnh (${c.overrideDayCount} ngày) của vụ "${c.seasonName}" sẽ bị xóa và quay về lịch mẫu của hồ sơ. '
          'Không thể hoàn tác.',
      'Khôi phục tất cả',
    );
    if (!ok || !mounted) return;
    await _write(
      () => CropApi.resetSeasonIrrigation(c.zoneId, c.seasonId),
      'Đã khôi phục toàn bộ mùa vụ về lịch mẫu của hồ sơ.',
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Lịch tưới theo ngày · ${widget.zone.name}', style: const TextStyle(fontSize: 15)),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _centered([
        Text('Không tải được lịch tưới của vụ: $_error', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Thử lại')),
      ]);
    }
    final c = _cal;
    if (c == null) {
      return _centered([
        const Text(
          'Zone chưa có vụ trồng đang chạy hoặc dự kiến, nên chưa có lịch tưới theo ngày. Hãy tạo vụ trồng cho Zone trước.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _load, child: const Text('Tải lại')),
      ]);
    }
    final days = c.inRangeDays;
    final visible = _stageFilter == 'ALL'
        ? days
        : [
            for (final d in days)
              if (d.stageId == _stageFilter) d,
          ];
    final selected = c.day(_selected) ?? days.firstOrNull;
    return RefreshIndicator(
      onRefresh: () => _load(seasonId: _seasonId),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(c),
          const SizedBox(height: 12),
          _legend(c),
          if (c.isStale || c.outOfRangeDays.isNotEmpty) ...[const SizedBox(height: 12), _staleBanner(c)],
          const SizedBox(height: 12),
          _filters(c),
          const SizedBox(height: 8),
          _grid(visible),
          const SizedBox(height: 12),
          if (selected != null) _dayCard(c, selected),
          const SizedBox(height: 12),
          if (c.isEditable && c.hasOverrides)
            OutlinedButton.icon(
              onPressed: _busy ? null : _resetAll,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Khôi phục toàn bộ mùa vụ về lịch mẫu'),
            ),
          const SizedBox(height: 12),
          _syncNote(c),
        ],
      ),
    );
  }

  Widget _centered(List<Widget> children) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    ),
  );

  Widget _header(SeasonIrrigationCalendar c) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_seasons.length > 1)
          DropdownButtonFormField<String>(
            initialValue: _seasonId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vụ trồng', isDense: true, border: OutlineInputBorder()),
            items: [
              for (final s in _seasons)
                DropdownMenuItem(
                  value: '${s['seasonId']}',
                  child: Text('${s['name']} (${s['status'] == 'InProgress' ? 'đang chạy' : 'dự kiến'})'),
                ),
            ],
            onChanged: _busy ? null : (v) => _load(seasonId: v),
          )
        else
          Text(
            c.seasonName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink),
          ),
        const SizedBox(height: 6),
        Text(
          'Hồ sơ: ${c.profileName}\nBắt đầu ${c.startDate} · ${c.totalDays} ngày'
          '${c.todayDayNumber == null ? ' · hôm nay nằm ngoài vụ' : ' · hôm nay là ngày ${c.todayDayNumber}'}\n'
          'Múi giờ ${c.timeZone} · ${c.overrideDayCount} ngày tùy chỉnh'
          '${c.updatedAtUtc == null ? '' : ' · cập nhật ${c.updatedAtUtc!.replaceFirst('T', ' ').split('.').first} UTC'}',
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.45),
        ),
        if (!c.isEditable)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Chỉ chủ trang trại sửa được lịch của vụ đang chạy hoặc dự kiến; bạn chỉ xem.',
              style: TextStyle(fontSize: 11.5, color: _amber),
            ),
          ),
        if (c.todayDayNumber != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _selected = c.todayDayNumber!;
                _stageFilter = 'ALL';
              }),
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Hôm nay'),
            ),
          ),
      ],
    ),
  );

  Widget _legend(SeasonIrrigationCalendar c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
    child: const Text(
      'Ba loại lịch khác nhau:\n'
      '• Lịch mẫu theo hồ sơ: đề xuất theo giai đoạn, dùng khi ngày không có chỉnh sửa (không đổi ở đây).\n'
      '• Lịch tùy chỉnh theo ngày: lịch riêng của vụ này (chấm cam), lưu trên máy chủ.\n'
      '• Lịch điều khiển trên thiết bị: chỉ đổi khi bạn đồng bộ (mục "Lịch tưới" của Zone).',
      style: TextStyle(fontSize: 11.5, color: _muted, height: 1.45),
    ),
  );

  Widget _staleBanner(SeasonIrrigationCalendar c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vụ đã thay đổi sau lần lưu lịch cuối',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _amber),
        ),
        for (final r in c.staleReasons)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('• ${staleReasonText(r)}', style: const TextStyle(fontSize: 11.5, color: _ink, height: 1.35)),
          ),
        for (final d in c.outOfRangeDays)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ngày ${d.dayNumber} (ngoài vụ): ${d.sessions.length} ca',
                    style: const TextStyle(fontSize: 11.5, color: _ink),
                  ),
                ),
                if (c.isEditable)
                  TextButton(onPressed: _busy ? null : () => _resetDay(d), child: const Text('Khôi phục')),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _filters(SeasonIrrigationCalendar c) {
    final stages = c.stages;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('Tất cả (${c.totalDays} ngày)', style: const TextStyle(fontSize: 12)),
              selected: _stageFilter == 'ALL',
              onSelected: (_) => setState(() => _stageFilter = 'ALL'),
            ),
          ),
          for (final s in stages)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(s.name, style: const TextStyle(fontSize: 12)),
                selected: _stageFilter == s.id,
                onSelected: (_) => setState(() {
                  _stageFilter = s.id;
                  final first = c.inRangeDays.where((d) => d.stageId == s.id).firstOrNull;
                  if (first != null && c.day(_selected)?.stageId != s.id) _selected = first.dayNumber;
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _grid(List<SeasonDay> days) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in days)
          InkWell(
            key: ValueKey('day_${d.dayNumber}'),
            onTap: () => setState(() => _selected = d.dayNumber),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: d.dayNumber == _selected ? const Color(0xFF064E3B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: d.dayNumber == _selected
                      ? const Color(0xFF10B981)
                      : (d.isOverride ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
                  width: d.isOverride || d.dayNumber == _selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'N${d.dayNumber}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: d.dayNumber == _selected ? Colors.white : _ink,
                    ),
                  ),
                  Text(
                    d.shortDate,
                    style: TextStyle(fontSize: 10, color: d.dayNumber == _selected ? Colors.white70 : _muted),
                  ),
                  Text(
                    d.source == DaySource.none ? '—' : '${d.enabledCount} ca',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: d.dayNumber == _selected ? Colors.white : (d.isOverride ? _amber : _green),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _dayCard(SeasonIrrigationCalendar c, SeasonDay d) {
    final canEdit = c.isEditable;
    final isToday = c.todayDayNumber == d.dayNumber;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: d.isOverride ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ngày ${d.dayNumber} · ${d.date}${isToday ? ' · hôm nay' : ''}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _ink),
          ),
          Text(
            '${d.stageName ?? 'Ngoài các giai đoạn của hồ sơ'} · Nguồn: ${d.source.label}',
            style: TextStyle(fontSize: 12, color: d.isOverride ? _amber : _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (d.sessions.isEmpty)
            Text(
              d.isOverride
                  ? 'Ngày này được đặt là KHÔNG tưới (không có ca nào).'
                  : 'Chưa có lịch cho ngày này: hồ sơ chưa có ca tưới và cây cũng chưa có lịch mẫu.',
              style: const TextStyle(fontSize: 12, color: _amber),
            )
          else
            for (final s in d.sessions)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${s.enabled ? '•' : '◦'} ${describeProfileSession(s)}',
                  style: TextStyle(fontSize: 12.5, color: s.enabled ? _ink : _muted),
                ),
              ),
          if (d.source == DaySource.crop)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Đây chỉ là lịch mẫu chung của cây để tham khảo, chưa lưu trong hồ sơ.',
                style: TextStyle(fontSize: 11, color: _muted),
              ),
            ),
          const SizedBox(height: 8),
          if (canEdit)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _editDay(d),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa ngày này'),
                ),
                if (d.isOverride)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resetDay(d),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Khôi phục ngày'),
                  ),
                if (d.sessions.isNotEmpty || d.isOverride) ...[
                  if (d.stageId != null)
                    OutlinedButton(
                      onPressed: _busy ? null : () => _applyElsewhere(d, wholeSeason: false),
                      child: const Text('Áp dụng cả giai đoạn'),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _applyElsewhere(d, wholeSeason: true),
                    child: const Text('Áp dụng cả vụ'),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _syncNote(SeasonIrrigationCalendar c) {
    final today = c.today;
    final text = today == null
        ? 'Hôm nay nằm ngoài vụ nên đồng bộ thiết bị sẽ dùng lịch theo giai đoạn của hồ sơ.'
        : today.isOverride
        ? 'Khi đồng bộ xuống thiết bị hôm nay (ngày ${today.dayNumber}), hệ thống dùng lịch TÙY CHỈNH của ngày này. '
              'Thiết bị lặp hằng ngày cho tới lần đồng bộ kế tiếp.'
        : 'Hôm nay (ngày ${today.dayNumber}) chưa có lịch tùy chỉnh: khi đồng bộ, hệ thống dùng lịch theo giai đoạn của hồ sơ.';
    return Text(text, style: const TextStyle(fontSize: 11.5, color: _muted, height: 1.4));
  }
}
