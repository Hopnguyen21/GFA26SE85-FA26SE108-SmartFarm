import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../irrigation/schedules_automation_screen.dart';
import '../../irrigation/season_irrigation_calendar_screen.dart';
import '../../irrigation/season_irrigation_logic.dart';
import '../../../core/utils/user_error.dart';

/// Dữ liệu biểu diễn một ca tưới trong ngày hôm nay của Zone.
class ZoneTodaySession {
  final String id;
  final String title;
  final String startTime;
  final int durationMinutes;
  final String targetDevice;
  final bool isEnabled;
  final bool enableRainDelay;
  final int? waterPerPlantMl;
  final bool isAutomation;
  final String? nextRun;
  final String? actuatorId;

  const ZoneTodaySession({
    required this.id,
    required this.title,
    required this.startTime,
    required this.durationMinutes,
    required this.targetDevice,
    this.isEnabled = true,
    this.enableRainDelay = false,
    this.waterPerPlantMl,
    this.isAutomation = true,
    this.nextRun,
    this.actuatorId,
  });
}

/// Thẻ hiển thị lịch tưới hôm nay của Zone đang chọn trên Dashboard của Chủ trại (Owner).
/// Hiển thị ca tưới thật từ rơ-le IoT hoặc ca tưới đề xuất theo vụ trồng/giai đoạn sinh trưởng.
class ZoneTodayIrrigationCard extends StatefulWidget {
  final ZoneModel zone;

  const ZoneTodayIrrigationCard({super.key, required this.zone});

  @override
  State<ZoneTodayIrrigationCard> createState() =>
      _ZoneTodayIrrigationCardState();
}

class _ZoneTodayIrrigationCardState extends State<ZoneTodayIrrigationCard> {
  bool _loading = true;
  String? _error;
  List<ZoneTodaySession> _sessions = const [];
  String? _seasonStage;
  final Set<String> _runningSessionIds = {};
  String? _triggeringSessionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneTodayIrrigationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zone.zoneId != widget.zone.zoneId ||
        oldWidget.zone.currentCrop != widget.zone.currentCrop ||
        oldWidget.zone.currentStage != widget.zone.currentStage) {
      _load();
    }
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const dayNames = [
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'Chủ Nhật',
    ];
    final dayName = dayNames[(now.weekday - 1) % 7];
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    return '$dayName, $dd/$mm';
  }

  bool _isScheduleForToday(ScheduleModel s, DateTime now) {
    const dayCodes = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final todayCode = dayCodes[(now.weekday - 1) % 7];

    // 1. Nếu danh sách ngày có chứa '*' hoặc thứ của ngày hôm nay
    if (s.daysOfWeek.contains('*') || s.daysOfWeek.contains(todayCode)) {
      return true;
    }

    // 2. Kiểm tra biểu thức cron
    final cron = s.cronExpression.trim();
    if (cron.isEmpty) {
      return s.daysOfWeek.isEmpty;
    }

    // Biểu thức cron dạng hằng ngày: dấu * ở 3 trường cuối
    if (RegExp(r'\*\s+\*\s+\*').hasMatch(cron)) {
      return true;
    }

    // Kiểm tra trường thứ 5 (day of week) trong cron 5 trường
    final parts = cron.split(RegExp(r'\s+'));
    if (parts.length >= 5) {
      final dow = parts[4].toUpperCase();
      if (dow == '*' || dow == '?') return true;

      final dartWeekday = now.weekday; // 1 = T2, 7 = CN
      // Dải thứ: ví dụ 1-5 (Thứ 2 đến Thứ 6)
      final rangeMatch = RegExp(r'^(\d)-(\d)$').firstMatch(dow);
      if (rangeMatch != null) {
        final start = int.parse(rangeMatch.group(1)!);
        final end = int.parse(rangeMatch.group(2)!);
        if (dartWeekday >= start && dartWeekday <= end) return true;
      }

      // Danh sách thứ: ví dụ 1,3,5
      final items = dow.split(',');
      for (final it in items) {
        final d = int.tryParse(it.trim());
        if (d != null && (d == dartWeekday || (d == 0 && dartWeekday == 7))) {
          return true;
        }
      }
    }

    return s.daysOfWeek.isEmpty;
  }

  bool _isCurrentlyActive(ZoneTodaySession session) {
    if (_runningSessionIds.contains(session.id)) return true;
    if (!session.isEnabled) return false;
    final parts = session.startTime.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null) return false;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, h, m);
    final end = start.add(Duration(minutes: session.durationMinutes));
    return now.isAfter(start) && now.isBefore(end);
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId;
    if (!mounted) return;
    final now = DateTime.now();

    // 0. Nạp nhanh từ bộ nhớ đệm FarmProvider nếu có sẵn để hiển thị tức thì
    try {
      final provider = Provider.of<FarmProvider>(context, listen: false);
      final cachedSchedules = provider.schedules
          .where((s) => s.zoneId.toLowerCase() == zoneId.toLowerCase())
          .toList();
      if (cachedSchedules.isNotEmpty && _sessions.isEmpty) {
        final todayCached = cachedSchedules
            .where((s) => _isScheduleForToday(s, now))
            .toList();
        if (todayCached.isNotEmpty) {
          _sessions = [
            for (final s in todayCached)
              ZoneTodaySession(
                id: s.scheduleId,
                title: s.name.isNotEmpty ? s.name : 'Tưới định kỳ',
                startTime: s.startTime,
                durationMinutes: s.durationMinutes,
                targetDevice: s.actuatorName.isNotEmpty
                    ? s.actuatorName
                    : 'Bơm tưới',
                isEnabled: s.isEnabled,
                enableRainDelay: s.enableRainDelay,
                isAutomation: true,
                nextRun: s.nextRunFormatted,
                actuatorId: s.actuatorId,
              ),
          ]..sort((a, b) => a.startTime.compareTo(b.startTime));
          _loading = false;
        }
      }
    } catch (_) {}

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Tải song song: Lịch IoT rơ-le của Zone và Mùa vụ của Zone
      final results = await Future.wait([
        AutomationApi.getSchedules(
          zoneId: zoneId,
        ).catchError((_) => <ScheduleModel>[]),
        CropApi.getPlantingSeasons(
          zoneId: zoneId,
        ).catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final apiSchedules = results[0] as List<ScheduleModel>;
      final seasons = results[1] as List<Map<String, dynamic>>;

      // 2. Kiểm tra Mùa vụ đang diễn ra để lấy hồ sơ tưới theo giai đoạn
      SeasonIrrigationCalendar? cal;
      if (seasons.isNotEmpty) {
        final currentSeason = seasons.firstWhere(
          (s) => '${s['status']}' == 'InProgress' || '${s['zoneId']}' == zoneId,
          orElse: () => seasons.first,
        );
        final seasonId =
            '${currentSeason['plantingSeasonId'] ?? currentSeason['seasonId'] ?? ''}';
        if (seasonId.isNotEmpty) {
          try {
            final json = await CropApi.getSeasonIrrigation(zoneId, seasonId);
            cal = SeasonIrrigationCalendar.fromJson(json);
          } catch (_) {}
        }
      }

      final parsedSessions = <ZoneTodaySession>[];

      // A. Nếu có lịch IoT chạy hôm nay:
      final todaySchedules = apiSchedules
          .where((s) => _isScheduleForToday(s, now))
          .toList();
      for (final s in todaySchedules) {
        parsedSessions.add(
          ZoneTodaySession(
            id: s.scheduleId,
            title: s.name.isNotEmpty ? s.name : 'Tưới định kỳ',
            startTime: s.startTime,
            durationMinutes: s.durationMinutes,
            targetDevice: s.actuatorName.isNotEmpty
                ? s.actuatorName
                : 'Bơm tưới',
            isEnabled: s.isEnabled,
            enableRainDelay: s.enableRainDelay,
            isAutomation: true,
            nextRun: s.nextRunFormatted,
            actuatorId: s.actuatorId,
          ),
        );
      }

      // B. Nếu chưa có lịch IoT hoặc có thêm ca tưới từ lịch vụ mùa hôm nay:
      if (cal != null) {
        final todayDay =
            cal.today ??
            (cal.todayDayNumber != null ? cal.day(cal.todayDayNumber!) : null);
        final dayNum = cal.todayDayNumber ?? 1;
        final totalDays = cal.totalDays > 0 ? cal.totalDays : 90;
        final stageDesc = todayDay?.stageName ?? cal.profileName;
        _seasonStage = 'Ngày $dayNum/$totalDays · $stageDesc';

        if (parsedSessions.isEmpty &&
            todayDay != null &&
            todayDay.sessions.isNotEmpty) {
          for (var i = 0; i < todayDay.sessions.length; i++) {
            final ps = todayDay.sessions[i];
            parsedSessions.add(
              ZoneTodaySession(
                id: 'season_${todayDay.dayNumber}_$i',
                title: ps.title.isNotEmpty ? ps.title : 'Ca tưới ${i + 1}',
                startTime: ps.startTime,
                durationMinutes: (ps.durationSeconds / 60).round(),
                targetDevice: ps.method ?? 'Hệ thống tưới nhỏ giọt',
                isEnabled: ps.enabled,
                enableRainDelay: false,
                waterPerPlantMl: ps.waterPerPlantMl,
                isAutomation: false,
              ),
            );
          }
        }
      } else {
        _seasonStage = widget.zone.currentStage;
      }

      // Sắp xếp ca tưới theo thứ tự giờ tăng dần
      parsedSessions.sort((a, b) => a.startTime.compareTo(b.startTime));

      if (mounted) {
        setState(() {
          if (parsedSessions.isNotEmpty || _sessions.isEmpty) {
            _sessions = parsedSessions;
          }
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _toggleSchedule(ZoneTodaySession session, bool enable) async {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.toggleScheduleEnabled(session.id, enable);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final idx = _sessions.indexWhere((s) => s.id == session.id);
        if (idx != -1) {
          final old = _sessions[idx];
          _sessions = List.of(_sessions)
            ..[idx] = ZoneTodaySession(
              id: old.id,
              title: old.title,
              startTime: old.startTime,
              durationMinutes: old.durationMinutes,
              targetDevice: old.targetDevice,
              isEnabled: enable,
              enableRainDelay: old.enableRainDelay,
              waterPerPlantMl: old.waterPerPlantMl,
              isAutomation: old.isAutomation,
              nextRun: old.nextRun,
              actuatorId: old.actuatorId,
            );
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? '✅ Đã kích hoạt lịch tự động "${session.title}".'
                : '⏸️ Đã tạm dừng lịch tự động "${session.title}".',
          ),
          backgroundColor: const Color(0xFF062326),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể đổi trạng thái lịch. Vui lòng kiểm tra quyền hoặc kết nối.',
          ),
          backgroundColor: Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _stopRunningSession(ZoneTodaySession session) async {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    String? actId = session.actuatorId;
    if (actId == null || actId.isEmpty) {
      final usable = provider.actuators
          .where(
            (a) => a.zoneId.toLowerCase() == widget.zone.zoneId.toLowerCase(),
          )
          .toList();
      actId = usable.firstOrNull?.actuatorId;
    }
    if (actId == null || actId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Zone chưa có thiết bị rơ-le để gửi lệnh tắt.'),
        ),
      );
      return;
    }
    setState(() => _triggeringSessionId = session.id);
    try {
      await AutomationApi.sendActuatorCommand(
        zoneId: widget.zone.zoneId,
        actuatorId: actId,
        action: 'TurnOff',
        durationSeconds: 1,
      );
      if (!mounted) return;
      setState(() {
        _runningSessionIds.remove(session.id);
        _triggeringSessionId = null;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('🛑 Đã ngắt thiết bị tưới của ca "${session.title}".'),
          backgroundColor: const Color(0xFF062326),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _triggeringSessionId = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi ngắt thiết bị: ${userFacingError(e)}'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  Future<void> _showTriggerDialog(ZoneTodaySession session) async {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    String? actId = session.actuatorId;
    String actName = session.targetDevice;
    if (actId == null || actId.isEmpty) {
      final usable = provider.actuators
          .where(
            (a) => a.zoneId.toLowerCase() == widget.zone.zoneId.toLowerCase(),
          )
          .toList();
      final pump =
          usable
              .where(
                (a) =>
                    a.actuatorType == 'PUMP' ||
                    a.actuatorType == 'VALVE' ||
                    a.name.toLowerCase().contains('bơm') ||
                    a.name.toLowerCase().contains('tưới'),
              )
              .firstOrNull ??
          usable.firstOrNull;
      if (pump != null && pump.actuatorId.isNotEmpty) {
        actId = pump.actuatorId;
        actName = pump.name;
      }
    }

    if (actId == null || actId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Zone chưa có thiết bị rơ-le bơm/van để gửi lệnh.'),
        ),
      );
      return;
    }

    int selectedMinutes = session.durationMinutes.clamp(1, 15);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF047857),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kích Hoạt Ca Tưới Ngay?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ca tưới: ${session.title} (${session.startTime})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Thiết bị chấp hành: $actName',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Thời gian tưới an toàn (phút):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [1, 3, 5, 10, 15].map((m) {
                  final active = selectedMinutes == m;
                  return ChoiceChip(
                    label: Text('$m phút'),
                    selected: active,
                    selectedColor: const Color(0xFF10B981),
                    labelStyle: TextStyle(
                      color: active ? Colors.white : const Color(0xFF334155),
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                    onSelected: (sel) {
                      if (sel) setDlgState(() => selectedMinutes = m);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: Color(0xFF047857),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cơ chế tự ngắt bảo vệ rơ-le: Tối đa 15 phút. Lệnh phát qua LoRa Gateway tới ESP32.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.bolt_rounded, size: 16),
              label: Text('Bật tưới ngay ($selectedMinutes phút)'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _triggeringSessionId = session.id);
    try {
      await AutomationApi.sendActuatorCommand(
        zoneId: widget.zone.zoneId,
        actuatorId: actId,
        action: 'TurnOn',
        durationSeconds: selectedMinutes * 60,
      );
      if (!mounted) return;
      setState(() {
        _runningSessionIds.add(session.id);
        _triggeringSessionId = null;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '⚡ Đã gửi lệnh bật thiết bị tưới qua LoRa Gateway! Tự ngắt an toàn sau $selectedMinutes phút (BR-SAFE-01).',
          ),
          backgroundColor: const Color(0xFF062326),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _triggeringSessionId = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Lỗi gửi lệnh điều khiển: ${userFacingError(e)}'),
          backgroundColor: const Color(0xFFE11D48),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final zone = widget.zone;
    final todayText = _formatTodayDate();
    final cropName = zone.currentCrop.trim().isNotEmpty
        ? zone.currentCrop.trim()
        : 'Cây trồng';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _sessions.isNotEmpty
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Card ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF047857),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LỊCH TƯỚI HÔM NAY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _seasonStage != null && _seasonStage!.isNotEmpty
                            ? '$todayText · ${zone.name} · $_seasonStage'
                            : '$todayText · ${zone.name} · $cropName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Badge tổng số ca & Nút làm mới
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF059669),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: _sessions.isNotEmpty
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _sessions.isNotEmpty
                                ? const Color(0xFFA7F3D0)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_sessions.isNotEmpty) ...[
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              _sessions.isNotEmpty
                                  ? '${_sessions.length} ca'
                                  : '0 ca',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: _sessions.isNotEmpty
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 3),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _load,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Session List / Empty State ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _buildBody(),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Action Footer (Keyed for tests & user shortcuts) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Material(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: const Key('home_irrigation_calendar'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SeasonIrrigationCalendarScreen(zone: zone),
                          ),
                        );
                        if (mounted) _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month_outlined,
                              size: 16,
                              color: Color(0xFF047857),
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Lịch vụ mùa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: const Key('home_automation_schedules'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SchedulesAutomationScreen(),
                          ),
                        );
                        if (mounted) _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: Color(0xFF475569),
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Cấu hình IoT',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _sessions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Column(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF059669),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Đang kiểm tra ca tưới hôm nay...',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null && _sessions.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF059669)),
            onPressed: _load,
            tooltip: 'Thử lại',
          ),
        ],
      );
    }

    if (_sessions.isEmpty) {
      final hasCrop = widget.zone.currentCrop.trim().isNotEmpty;
      final cropTitle = hasCrop ? widget.zone.currentCrop.trim() : 'Cây trồng';
      final isNeedsSeason = widget.zone.needsSeason;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.water_drop_outlined,
                size: 24,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chưa có ca tưới nào được lên lịch hôm nay',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isNeedsSeason
                        ? 'Khu vực ${widget.zone.name} chưa có vụ mùa đang chạy. Mở "Lịch vụ mùa" để gán cây hoặc tạo ca tưới.'
                        : 'Cây $cropTitle đang ở trạng thái tưới thủ công hoặc chờ đồng bộ từ lịch vụ mùa.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildSessionTile(_sessions[i]),
        ],
      ],
    );
  }

  Widget _buildStatusBadge(bool isRunningNow, bool isEnabled) {
    if (isRunningNow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3310B981),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.water_drop_rounded, size: 10, color: Colors.white),
            SizedBox(width: 2),
            Text(
              'Đang tưới',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isEnabled ? 'Tự động' : 'Tạm dừng',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isEnabled ? const Color(0xFF15803D) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildSessionTile(ZoneTodaySession session) {
    final isRunningNow = _isCurrentlyActive(session);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isRunningNow
            ? const Color(0xFFECFDF5)
            : (session.isEnabled
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunningNow
              ? const Color(0xFF10B981)
              : (session.isEnabled
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFE2E8F0)),
          width: isRunningNow ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Khung giờ tưới
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isRunningNow
                    ? const Color(0xFF10B981)
                    : (session.isEnabled
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_filled,
                      size: 12,
                      color: isRunningNow
                          ? const Color(0xFF10B981)
                          : (session.isEnabled
                                ? const Color(0xFF047857)
                                : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      session.startTime,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: session.isEnabled
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${session.durationMinutes} phút',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: session.isEnabled
                        ? const Color(0xFF047857)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Tên ca & Thiết bị & Trạng thái
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: session.isEnabled
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildStatusBadge(isRunningNow, session.isEnabled),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.settings_input_component,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        session.targetDevice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                // Lần chạy tiếp theo (nếu có từ backend)
                if (session.nextRun != null && session.nextRun!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Lần chạy tới: ${session.nextRun}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
                // Huy hiệu bổ trợ (Mưa / Lượng nước)
                if (session.enableRainDelay ||
                    session.waterPerPlantMl != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (session.enableRainDelay)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Text(
                            '🌧️ Hoãn khi mưa >70%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      if (session.waterPerPlantMl != null &&
                          session.waterPerPlantMl! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            '💧 ${session.waterPerPlantMl}ml/cây',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (session.isAutomation) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Trạng thái Tự động/Tạm dừng đã hiện ở huy hiệu phía trên: không lặp lại chữ ở đây.
                          SizedBox(
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Switch(
                                value: session.isEnabled,
                                activeThumbColor: const Color(0xFF047857),
                                activeTrackColor: const Color(0xFFA7F3D0),
                                onChanged: (val) =>
                                    _toggleSchedule(session, val),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Flexible + căn phải: nút co lại trên màn hẹp/chữ lớn thay vì làm tràn hàng.
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _sessionActionButton(session, isRunningNow),
                      ),
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

  Widget _sessionActionButton(ZoneTodaySession session, bool isRunningNow) {
    return isRunningNow
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _triggeringSessionId == session.id
                ? null
                : () => _stopRunningSession(session),
            icon: const Icon(Icons.stop_circle_rounded, size: 14),
            label: Text(
              _triggeringSessionId == session.id ? 'Đang ngắt...' : 'Dừng tưới',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFECFDF5),
              foregroundColor: const Color(0xFF047857),
              side: const BorderSide(color: Color(0xFFA7F3D0)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _triggeringSessionId == session.id
                ? null
                : () => _showTriggerDialog(session),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 14),
            label: Text(
              _triggeringSessionId == session.id ? 'Đang gửi...' : 'Tưới ngay',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
  }
}
