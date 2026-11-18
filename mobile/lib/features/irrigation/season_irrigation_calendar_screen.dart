import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../zones/profile_irrigation_logic.dart';
import 'season_irrigation_logic.dart';
import '../../core/utils/user_error.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF047857);
const _amber = Color(0xFFD97706);

class StageInfo {
  final String id;
  final String name;
  final String shortName;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String rangeText;

  const StageInfo({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.rangeText,
  });
}

StageInfo getStageInfo(int dayNum, int maxDays) {
  final p = dayNum / (maxDays > 0 ? maxDays : 1);
  final d1 = (maxDays * 0.22).round().clamp(1, maxDays);
  final d2 = (maxDays * 0.50).round().clamp(d1 + 1, maxDays);
  final d3 = (maxDays * 0.78).round().clamp(d2 + 1, maxDays);

  if (p <= 0.22) {
    return StageInfo(
      id: 'STAGE_1',
      name: 'Giai đoạn 1: Cây con & Hồi xanh',
      shortName: 'Cây con',
      color: const Color(0xFF047857),
      bgColor: const Color(0xFFECFDF5),
      borderColor: const Color(0xFFA7F3D0),
      rangeText: 'Ngày 1 - Ngày $d1',
    );
  }
  if (p <= 0.50) {
    return StageInfo(
      id: 'STAGE_2',
      name: 'Giai đoạn 2: Phát triển thân lá',
      shortName: 'Thân lá',
      color: const Color(0xFF0284C7),
      bgColor: const Color(0xFFF0F9FF),
      borderColor: const Color(0xFFBAE6FD),
      rangeText: 'Ngày ${d1 + 1} - Ngày $d2',
    );
  }
  if (p <= 0.78) {
    return StageInfo(
      id: 'STAGE_3',
      name: 'Giai đoạn 3: Ra hoa & Đậu quả',
      shortName: 'Ra hoa',
      color: const Color(0xFFD97706),
      bgColor: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFDE68A),
      rangeText: 'Ngày ${d2 + 1} - Ngày $d3',
    );
  }
  return StageInfo(
    id: 'STAGE_4',
    name: 'Giai đoạn 4: Nuôi trái & Thu hoạch',
    shortName: 'Thu hoạch',
    color: const Color(0xFFE11D48),
    bgColor: const Color(0xFFFFF1F2),
    borderColor: const Color(0xFFFECDD3),
    rangeText: 'Ngày ${d3 + 1} - Ngày $maxDays',
  );
}

DateTime? getDayDate(String startDateStr, int dayNumber) {
  try {
    final start = DateTime.parse(startDateStr);
    return start.add(Duration(days: dayNumber - 1));
  } catch (_) {
    return null;
  }
}

String getDayOfWeekName(DateTime date) {
  const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  return days[(date.weekday - 1) % 7];
}

String formatDisplayDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

String formatFullDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

List<ProfileSession> extractDaySessions(SeasonDay? day) {
  ProfileSession? morning;
  ProfileSession? noon;
  ProfileSession? afternoon;

  if (day != null && day.sessions.isNotEmpty) {
    for (final s in day.sessions) {
      final l = s.title.toLowerCase();
      final h = int.tryParse(s.startTime.split(':').firstOrNull ?? '') ?? 0;
      if (morning == null && (l.contains('sáng') || h < 11)) {
        morning = s;
      } else if (noon == null && (l.contains('trưa') || (h >= 11 && h < 14))) {
        noon = s;
      } else if (afternoon == null && (l.contains('chiều') || h >= 14)) {
        afternoon = s;
      }
    }
  }

  morning ??= const ProfileSession(
    title: 'Tưới Sáng Khởi Động',
    startTime: '07:30',
    durationSeconds: 20 * 60,
    enabled: true,
    method: 'Tưới nhỏ giọt bù áp',
    waterPerPlantMl: 500,
  );
  noon ??= const ProfileSession(
    title: 'Tưới Trưa Giảm Nhiệt',
    startTime: '12:00',
    durationSeconds: 10 * 60,
    enabled: false,
    method: 'Tưới nhỏ giọt bù áp',
    waterPerPlantMl: 300,
  );
  afternoon ??= const ProfileSession(
    title: 'Tưới Chiều Bổ Sung',
    startTime: '16:30',
    durationSeconds: 15 * 60,
    enabled: true,
    method: 'Tưới nhỏ giọt bù áp',
    waterPerPlantMl: 400,
  );

  return [morning, noon, afternoon];
}

/// Màn hình Cuốn Lịch Tưới 3 Ca Vụ Mùa Chuẩn VietGAP trên Mobile
/// Thiết kế đồng bộ 100% với phiên bản Web:
/// 1. Banner tiến trình vụ mùa, tên giống, khoảng ngày canh tác
/// 2. Thanh 4 Giai đoạn sinh trưởng (Cây con, Thân lá, Ra hoa, Thu hoạch)
/// 3. Lưới lịch tưới ngày với 3 chấm biểu thị ca tưới (Sáng, Trưa, Chiều)
/// 4. Bảng điều khiển chi tiết 3 Ca tưới tích hợp thao tác sao chép hàng loạt
class SeasonIrrigationCalendarScreen extends StatefulWidget {
  final ZoneModel zone;
  final String? seasonId;

  const SeasonIrrigationCalendarScreen({
    super.key,
    required this.zone,
    this.seasonId,
  });

  @override
  State<SeasonIrrigationCalendarScreen> createState() =>
      _SeasonIrrigationCalendarScreenState();
}

class _SeasonIrrigationCalendarScreenState
    extends State<SeasonIrrigationCalendarScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _seasons = [];
  String? _seasonId;
  SeasonIrrigationCalendar? _cal;
  int _selected = 1;
  String _stageFilter = 'ALL';
  bool _busy = false;

  List<ProfileSession> _activeDaySessions = [];
  bool _hasUnsavedChanges = false;

  String _err(Object e) => userFacingError(e);

  @override
  void initState() {
    super.initState();
    _load(seasonId: widget.seasonId);
  }

  Future<void> _load({String? seasonId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await CropApi.getPlantingSeasons(zoneId: widget.zone.zoneId);
      final usable = [
        for (final s in all)
          if ('${s['status']}' == 'InProgress' || '${s['status']}' == 'Planned')
            s,
      ];
      _seasons = usable;
      Map<String, dynamic>? pick = usable
          .where((s) => '${s['seasonId']}' == (seasonId ?? _seasonId))
          .firstOrNull;
      pick ??=
          usable.where((s) => '${s['status']}' == 'InProgress').firstOrNull ??
          usable.firstOrNull;
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
      final initialDay = cal.todayDayNumber ?? 1;
      setState(() {
        _seasonId = id;
        _cal = cal;
        _selected = initialDay;
        _stageFilter = 'ALL';
        _activeDaySessions = extractDaySessions(cal.day(initialDay));
        _hasUnsavedChanges = false;
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFDC2626) : _green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onSelectDay(int dayNumber) {
    if (_selected == dayNumber) return;
    setState(() {
      _selected = dayNumber;
      final d = _cal?.day(dayNumber);
      _activeDaySessions = extractDaySessions(d);
      _hasUnsavedChanges = false;
    });
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() call,
    String success,
  ) async {
    setState(() => _busy = true);
    try {
      final json = await call();
      if (!mounted) return;
      final updated = SeasonIrrigationCalendar.fromJson(json);
      setState(() {
        _cal = updated;
        final d = updated.day(_selected);
        _activeDaySessions = extractDaySessions(d);
        _hasUnsavedChanges = false;
      });
      _toast(success);
    } catch (e) {
      if (mounted) _toast('Không lưu được: ${_err(e)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDays(
    List<int> days,
    List<ProfileSession> sessions,
    String success,
  ) {
    final c = _cal!;
    return _write(
      () => CropApi.updateSeasonIrrigation(c.zoneId, c.seasonId, [
        for (final d in days) dayIrrigationPayload(d, sessions),
      ]),
      success,
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _saveCurrentDay() async {
    await _saveDays(
      [_selected],
      _activeDaySessions,
      'Đã lưu thành công cấu hình lịch tưới Ngày $_selected!',
    );
  }

  Future<void> _applyToStage() async {
    final c = _cal!;
    final currentStage = getStageInfo(_selected, c.totalDays);
    final days = [
      for (final d in c.inRangeDays)
        if (getStageInfo(d.dayNumber, c.totalDays).id == currentStage.id)
          d.dayNumber,
    ];
    final ok = await _confirm(
      'Áp dụng cho toàn bộ ${currentStage.name}?',
      'Cấu hình 3 ca tưới của Ngày $_selected sẽ được sao chép cho toàn bộ ${days.length} ngày trong giai đoạn này.',
      'Áp dụng ngay',
    );
    if (!ok || !mounted) return;
    await _saveDays(
      days,
      _activeDaySessions,
      'Đã sao chép cấu hình Ngày $_selected cho toàn bộ ${currentStage.name}!',
    );
  }

  Future<void> _applyToAllDays() async {
    final c = _cal!;
    final days = [for (final d in c.inRangeDays) d.dayNumber];
    final ok = await _confirm(
      'Áp dụng cho cả vụ (${c.totalDays} ngày)?',
      'Cấu hình 3 ca tưới của Ngày $_selected sẽ được áp dụng cho tất cả ${days.length} ngày trong toàn bộ mùa vụ canh tác.',
      'Áp dụng cả vụ',
    );
    if (!ok || !mounted) return;
    await _saveDays(
      days,
      _activeDaySessions,
      'Đã áp dụng lịch tưới Ngày $_selected cho tất cả ${days.length} ngày của mùa vụ!',
    );
  }

  Future<void> _resetSelectedDay() async {
    final c = _cal!;
    final ok = await _confirm(
      'Khôi phục Ngày $_selected về chuẩn gốc?',
      'Ngày $_selected sẽ quay về cấu hình lịch mẫu VietGAP mặc định của Thư viện Cây trồng.',
      'Khôi phục ngày này',
    );
    if (!ok || !mounted) return;
    await _write(
      () => CropApi.resetSeasonIrrigation(
        c.zoneId,
        c.seasonId,
        dayNumber: _selected,
      ),
      'Đã khôi phục Ngày $_selected về lịch mẫu chuẩn!',
    );
  }

  Future<void> _resetAllToTemplate() async {
    final c = _cal!;
    final ok = await _confirm(
      'Khôi phục toàn bộ mùa vụ về chuẩn gốc?',
      'Mọi tùy chỉnh riêng của bạn cho ${c.overrideDayCount} ngày sẽ bị xóa và quay về lịch chuẩn VietGAP mặc định.',
      'Khôi phục tất cả',
    );
    if (!ok || !mounted) return;
    await _write(
      () => CropApi.resetSeasonIrrigation(c.zoneId, c.seasonId),
      'Đã khôi phục toàn bộ mùa vụ về chuẩn VietGAP gốc!',
    );
  }

  void _toggleSession(int index, bool val) {
    if (!(_cal?.isEditable ?? false)) return;
    setState(() {
      _activeDaySessions[index] = _activeDaySessions[index].copyWith(
        enabled: val,
      );
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _pickTime(int index) async {
    if (!(_cal?.isEditable ?? false)) return;
    final current = _activeDaySessions[index].startTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.firstOrNull ?? '7') ?? 7,
      minute: int.tryParse(parts.elementAtOrNull(1) ?? '30') ?? 30,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: _green)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _activeDaySessions[index] = _activeDaySessions[index].copyWith(
          startTime: '$hh:$mm',
        );
        _hasUnsavedChanges = true;
      });
    }
  }

  void _adjustDuration(int index, int deltaMinutes) {
    if (!(_cal?.isEditable ?? false)) return;
    final currentMin = (_activeDaySessions[index].durationSeconds / 60).round();
    final newMin = (currentMin + deltaMinutes).clamp(1, 30);
    setState(() {
      _activeDaySessions[index] = _activeDaySessions[index].copyWith(
        durationSeconds: newMin * 60,
      );
      _hasUnsavedChanges = true;
    });
  }

  void _adjustWater(int index, int deltaMl) {
    if (!(_cal?.isEditable ?? false)) return;
    final currentMl = _activeDaySessions[index].waterPerPlantMl ?? 500;
    final newMl = (currentMl + deltaMl).clamp(50, 3000);
    setState(() {
      _activeDaySessions[index] = _activeDaySessions[index].copyWith(
        waterPerPlantMl: newMl,
      );
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuốn Lịch Tưới 3 Ca Vụ Mùa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Zone: ${widget.zone.name}',
              style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Tải lại',
            onPressed: _busy ? null : () => _load(seasonId: _seasonId),
          ),
          if (_cal != null && _cal!.isEditable && _cal!.hasOverrides)
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.white),
              tooltip: 'Khôi phục chuẩn gốc',
              onPressed: _busy ? null : _resetAllToTemplate,
            ),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFF064E3B),
                  color: Color(0xFF34D399),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              Text(
                'Không tải được lịch tưới của vụ: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _ink),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: _load,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    final c = _cal;
    if (c == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 48, color: _muted),
              const SizedBox(height: 12),
              const Text(
                'Zone chưa có vụ trồng đang chạy hoặc dự kiến. Vui lòng tạo vụ trồng cho Zone trước.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _load, child: const Text('Tải lại')),
            ],
          ),
        ),
      );
    }

    final days = c.inRangeDays;
    final visibleDays = _stageFilter == 'ALL'
        ? days
        : [
            for (final d in days)
              if (getStageInfo(d.dayNumber, c.totalDays).id == _stageFilter) d,
          ];

    final selectedDay = c.day(_selected) ?? days.firstOrNull;

    return RefreshIndicator(
      color: _green,
      onRefresh: () => _load(seasonId: _seasonId),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // 1. Main Header Banner (Tiến trình vụ mùa & thông số)
          _buildHeaderBanner(c),
          const SizedBox(height: 14),

          // 2. 4 Growth Stages Bar (Tổng quan 4 Giai đoạn sinh trưởng)
          _buildGrowthStagesOverview(c),
          const SizedBox(height: 14),

          // 3. Filter & Legend Bar (Thanh lọc & chú thích ca tưới)
          _buildFilterAndLegend(c),
          const SizedBox(height: 10),

          // 4. Calendar Day Grid (Lưới lịch tưới cả vụ)
          _buildCalendarGrid(c, visibleDays),
          const SizedBox(height: 14),

          // 5. Selected Day Detail & Editing Control Panel (Chi tiết 3 Ca tưới)
          if (selectedDay != null) _buildSelectedDayPanel(c, selectedDay),
          const SizedBox(height: 14),

          // Stale notification if needed
          if (c.isStale || c.outOfRangeDays.isNotEmpty) ...[
            _buildStaleBanner(c),
            const SizedBox(height: 14),
          ],

          // Sync device note
          _buildSyncNote(c),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(SeasonIrrigationCalendar c) {
    final startDt = getDayDate(c.startDate, 1);
    final endDt = getDayDate(c.startDate, c.totalDays);
    final startStr = startDt != null ? formatDisplayDate(startDt) : c.startDate;
    final endStr = endDt != null
        ? formatDisplayDate(endDt)
        : 'Ngày ${c.totalDays}';

    final todayNum = c.todayDayNumber;
    final todayStage = todayNum != null
        ? getStageInfo(todayNum, c.totalDays)
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Cuốn Lịch Tưới 3 Ca Vụ Mùa (${c.totalDays} Ngày)',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            c.profileName,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                        if (_seasons.length > 1)
                          PopupMenuButton<String>(
                            tooltip: 'Chọn vụ trồng',
                            initialValue: _seasonId,
                            onSelected: _busy
                                ? null
                                : (v) => _load(seasonId: v),
                            itemBuilder: (context) => [
                              for (final s in _seasons)
                                PopupMenuItem(
                                  value: '${s['seasonId']}',
                                  child: Text(
                                    '${s['name']} (${s['status'] == 'InProgress' ? 'đang chạy' : 'dự kiến'})',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    c.seasonName,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: _ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 14,
                                    color: _ink,
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              c.seasonName,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tiến trình canh tác Ngày 1 ➔ Ngày ${c.totalDays} ($startStr ➔ $endStr). Múi giờ: ${c.timeZone}.',
            style: const TextStyle(fontSize: 12, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFD1FAE5)),
          const SizedBox(height: 10),

          // Sub parameters row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (todayNum != null && todayStage != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 13, color: _green),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Hôm nay: Ngày $todayNum/${c.totalDays} (${todayStage.shortName})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user, size: 13, color: _green),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Tùy chỉnh riêng cho Zone ${widget.zone.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthStagesOverview(SeasonIrrigationCalendar c) {
    final stages = [
      getStageInfo(1, c.totalDays),
      getStageInfo((c.totalDays * 0.35).round(), c.totalDays),
      getStageInfo((c.totalDays * 0.65).round(), c.totalDays),
      getStageInfo(c.totalDays, c.totalDays),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GIAI ĐOẠN SINH TRƯỞNG VIETGAP',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.0,
          ),
          itemCount: stages.length,
          itemBuilder: (context, idx) {
            final st = stages[idx];
            final isFilter = _stageFilter == st.id;
            return InkWell(
              onTap: () {
                setState(() {
                  _stageFilter = isFilter ? 'ALL' : st.id;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: st.bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFilter ? st.color : st.borderColor,
                    width: isFilter ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            st.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: st.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            st.rangeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: st.color.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      st.name.replaceFirst(RegExp(r'Giai đoạn \d+: '), ''),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterAndLegend(SeasonIrrigationCalendar c) {
    final todayNum = c.todayDayNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text(
                'Tất cả (${c.totalDays} ngày)',
                style: const TextStyle(fontSize: 11.5),
              ),
              selected: _stageFilter == 'ALL',
              selectedColor: const Color(0xFF0F172A),
              labelStyle: TextStyle(
                color: _stageFilter == 'ALL' ? Colors.white : _ink,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) => setState(() => _stageFilter = 'ALL'),
            ),
            if (todayNum != null)
              ActionChip(
                avatar: const Icon(Icons.my_location, size: 14, color: _green),
                label: Text(
                  'Hôm nay (Ngày $todayNum)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: const Color(0xFFD1FAE5),
                side: const BorderSide(color: Color(0xFFA7F3D0)),
                onPressed: () {
                  _onSelectDay(todayNum);
                  setState(() => _stageFilter = 'ALL');
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Chú thích: tự xuống dòng để thấy đủ 4 mục trên màn hẹp.
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _legendDot(const Color(0xFFF59E0B), 'Ca Sáng (Khởi động)'),
            _legendDot(const Color(0xFFF43F5E), 'Ca Trưa (Hạ nhiệt)'),
            _legendDot(const Color(0xFF6366F1), 'Ca Chiều (Bổ sung)'),
            _legendDot(_green, 'Đã tùy biến'),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: _muted)),
      ],
    );
  }

  Widget _buildCalendarGrid(SeasonIrrigationCalendar c, List<SeasonDay> days) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF047857),
                  Color(0xFF047857),
                  Color(0xFF0D9488),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(17),
                topRight: Radius.circular(17),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Color(0xFFFDE68A),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'LƯỚI LỊCH TƯỚI ${c.totalDays} NGÀY VỤ MÙA',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${days.length} / ${c.totalDays} ngày',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Day cells grid
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final d in days) _buildDayCell(c, d)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(SeasonIrrigationCalendar c, SeasonDay d) {
    final isSelected = d.dayNumber == _selected;
    final isToday = c.todayDayNumber == d.dayNumber;
    final stage = getStageInfo(d.dayNumber, c.totalDays);
    final dayDt = getDayDate(c.startDate, d.dayNumber);
    final displayDate = dayDt != null ? formatDisplayDate(dayDt) : d.shortDate;
    final dayOfWeek = dayDt != null ? getDayOfWeekName(dayDt) : '';

    final daySessions = isSelected ? _activeDaySessions : extractDaySessions(d);
    final morning = daySessions[0];
    final noon = daySessions[1];
    final afternoon = daySessions[2];

    return InkWell(
      key: ValueKey('calendar_day_${d.dayNumber}'),
      onTap: () => _onSelectDay(d.dayNumber),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFECFDF5)
              : isToday
              ? const Color(0xFFFFFBEB)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? _green
                : isToday
                ? _amber
                : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top: Day number + customized indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'N${d.dayNumber}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF065F46) : _ink,
                  ),
                ),
                if (d.isOverride)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  )
                else if (isToday)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: _amber,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),

            // Mid: Date + day of week
            const SizedBox(height: 2),
            Text(
              '$displayDate $dayOfWeek',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF047857) : _muted,
              ),
            ),

            // Bottom: 3 Session indicator dots + Stage short pill
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (morning.enabled)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (noon.enabled)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF43F5E),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (afternoon.enabled)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: stage.bgColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stage.shortName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: stage.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayPanel(
    SeasonIrrigationCalendar c,
    SeasonDay selectedDay,
  ) {
    final stage = getStageInfo(selectedDay.dayNumber, c.totalDays);
    final dayDt = getDayDate(c.startDate, selectedDay.dayNumber);
    final fullDate = dayDt != null ? formatFullDate(dayDt) : selectedDay.date;
    final dayOfWeek = dayDt != null ? getDayOfWeekName(dayDt) : '';
    final isToday = c.todayDayNumber == selectedDay.dayNumber;
    final canEdit = c.isEditable;

    final morning = _activeDaySessions[0];
    final noon = _activeDaySessions[1];
    final afternoon = _activeDaySessions[2];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of panel
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.access_time_filled,
                  color: _green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Chi tiết Lịch Tưới Ngày ${selectedDay.dayNumber}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: const Text(
                              'HÔM NAY',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _amber,
                              ),
                            ),
                          ),
                        ],
                        if (selectedDay.isOverride) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: const Text(
                              'ĐÃ TÙY BIẾN',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$fullDate ($dayOfWeek) • ${stage.name} (${stage.rangeText})',
                      style: const TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!canEdit)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Bạn chỉ xem được lịch tưới này (chỉ Chủ trang trại được chỉnh sửa).',
                style: TextStyle(fontSize: 12, color: _muted, height: 1.35),
              ),
            ),
          // Batch Action Buttons
          if (canEdit)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F9FF),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    foregroundColor: const Color(0xFF0369A1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : _applyToStage,
                  icon: const Icon(Icons.bolt, size: 15),
                  label: const Text(
                    'Áp dụng cả Giai đoạn này',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFECFDF5),
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    foregroundColor: const Color(0xFF047857),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _busy ? null : _applyToAllDays,
                  icon: const Icon(Icons.public, size: 15),
                  label: Text(
                    'Áp dụng cả Vụ (${c.totalDays} ngày)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (selectedDay.isOverride)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: _busy ? null : _resetSelectedDay,
                    icon: const Icon(Icons.undo, size: 14),
                    label: const Text(
                      'Bỏ tùy biến',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),

          // 3 Session Cards
          _buildSessionCard(
            index: 0,
            session: morning,
            sessionTypeTitle: 'Ca Sáng (Khởi động)',
            icon: Icons.wb_twilight,
            themeColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            canEdit: canEdit,
          ),
          const SizedBox(height: 10),

          _buildSessionCard(
            index: 1,
            session: noon,
            sessionTypeTitle: 'Ca Trưa (Hạ nhiệt)',
            icon: Icons.wb_sunny,
            themeColor: const Color(0xFFE11D48),
            bgColor: const Color(0xFFFFF1F2),
            borderColor: const Color(0xFFFECDD3),
            canEdit: canEdit,
          ),
          const SizedBox(height: 10),

          _buildSessionCard(
            index: 2,
            session: afternoon,
            sessionTypeTitle: 'Ca Chiều (Bổ sung)',
            icon: Icons.nights_stay,
            themeColor: const Color(0xFF4F46E5),
            bgColor: const Color(0xFFEEF2FF),
            borderColor: const Color(0xFFC7D2FE),
            canEdit: canEdit,
          ),
          const SizedBox(height: 14),

          // Save button for this day
          if (canEdit)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _hasUnsavedChanges
                      ? const Color(0xFF047857)
                      : const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _hasUnsavedChanges ? 3 : 0,
                ),
                onPressed: _busy ? null : _saveCurrentDay,
                icon: const Icon(Icons.save, size: 18),
                label: Text(
                  _hasUnsavedChanges
                      ? 'LƯU THAY ĐỔI NGÀY ${selectedDay.dayNumber}'
                      : 'LƯU CẤU HÌNH NGÀY ${selectedDay.dayNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSessionCard({
    required int index,
    required ProfileSession session,
    required String sessionTypeTitle,
    required IconData icon,
    required Color themeColor,
    required Color bgColor,
    required Color borderColor,
    required bool canEdit,
  }) {
    final durationMinutes = (session.durationSeconds / 60).round();
    final waterMl = session.waterPerPlantMl ?? 500;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: session.enabled ? bgColor : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: session.enabled ? borderColor : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Title + Checkbox + Time Picker Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Checkbox(
                      value: session.enabled,
                      activeColor: themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: canEdit
                          ? (val) => _toggleSession(index, val ?? false)
                          : null,
                    ),
                    Icon(
                      icon,
                      size: 17,
                      color: session.enabled ? themeColor : _muted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        sessionTypeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: session.enabled ? _ink : _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: canEdit && session.enabled
                    ? () => _pickTime(index)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: session.enabled
                          ? themeColor.withValues(alpha: 0.5)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: session.enabled ? themeColor : _muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        session.startTime,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: session.enabled ? themeColor : _muted,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Adjusters
          Opacity(
            opacity: session.enabled ? 1.0 : 0.45,
            child: Column(
              children: [
                // Duration Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Thời lượng tưới:',
                        style: const TextStyle(fontSize: 12, color: _ink),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepperButton(
                          icon: Icons.remove,
                          enabled: canEdit && session.enabled,
                          onPressed: () => _adjustDuration(index, -5),
                        ),
                        Container(
                          width: 64,
                          alignment: Alignment.center,
                          child: Text(
                            '$durationMinutes phút',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                        ),
                        _stepperButton(
                          icon: Icons.add,
                          enabled: canEdit && session.enabled,
                          onPressed: () => _adjustDuration(index, 5),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Water Volume Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Liều lượng nước:',
                        style: const TextStyle(fontSize: 12, color: _ink),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepperButton(
                          icon: Icons.remove,
                          enabled: canEdit && session.enabled,
                          onPressed: () => _adjustWater(index, -50),
                        ),
                        Container(
                          width: 80,
                          alignment: Alignment.center,
                          child: Text(
                            '$waterMl ml/gốc',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                        ),
                        _stepperButton(
                          icon: Icons.add,
                          enabled: canEdit && session.enabled,
                          onPressed: () => _adjustWater(index, 50),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Icon(icon, size: 14, color: enabled ? _ink : _muted),
      ),
    );
  }

  Widget _buildStaleBanner(SeasonIrrigationCalendar c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: _amber),
              SizedBox(width: 6),
              Text(
                'Lưu ý thay đổi mùa vụ',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _amber,
                ),
              ),
            ],
          ),
          for (final r in c.staleReasons)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• ${staleReasonText(r)}',
                style: const TextStyle(fontSize: 11.5, color: _ink),
              ),
            ),
          // Ngày đã tùy chỉnh nhưng nằm ngoài vụ hiện tại không có trong lưới: nêu rõ để không bị ẩn.
          for (final d in c.outOfRangeDays)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '• Ngày ${d.dayNumber} (ngoài vụ): ${d.enabledCount} ca đã tùy chỉnh, không nằm trong lưới ${c.totalDays} ngày.',
                style: const TextStyle(fontSize: 11.5, color: _ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncNote(SeasonIrrigationCalendar c) {
    final today = c.today;
    final text = today == null
        ? 'Hôm nay nằm ngoài vụ nên đồng bộ thiết bị sẽ dùng lịch theo giai đoạn chuẩn VietGAP của hồ sơ.'
        : today.isOverride
        ? 'Khi đồng bộ xuống thiết bị hôm nay (ngày ${today.dayNumber}), hệ thống sẽ nạp lịch TÙY CHỈNH 3 CA của ngày này.'
        : 'Hôm nay (ngày ${today.dayNumber}) dùng lịch chuẩn VietGAP. Bạn có thể tùy chỉnh và bấm Lưu để nạp xuống phần cứng.';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                color: _muted,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
