part of '../irrigation_calendar_screen.dart';

/// Lịch tưới của màn này lấy TỪ BACKEND (GET /growth-profiles/{id}/irrigation-schedule), theo GIAI ĐOẠN: mọi ngày trong một giai đoạn
/// dùng chung các ca của giai đoạn đó. Không còn lịch mặc định tự sinh hay lưu cục bộ trong SharedPreferences.
/// Chỉ hồ sơ riêng của trang trại mới sửa được (lưu qua PUT); hồ sơ hệ thống chỉ xem.
extension _IrrigationCalendarScreenStateLogic
    on _IrrigationCalendarScreenState {
  Future<void> _loadSchedule() async {
    _rebuild(() {
      _isLoaded = false;
      _loadError = null;
    });
    try {
      final json = await CropApi.getProfileIrrigation(widget.profile.profileId);
      if (!mounted) return;
      _rebuild(() => _schedule = ProfileSchedule.fromJson(json));
    } catch (e) {
      if (mounted)
        _rebuild(
          () => _loadError = e.toString().replaceFirst('Exception: ', ''),
        );
    }
    if (mounted) _rebuild(() => _isLoaded = true);
  }

  bool get _canEditSchedule => _schedule?.isEditable == true;

  /// Giai đoạn của backend ứng với ngày [day] của vụ (ghép theo thứ tự giai đoạn và số ngày của chính backend).
  StageSchedule? _backendStageForDay(int day) {
    final stages = _schedule?.stages ?? const <StageSchedule>[];
    if (stages.isEmpty) return null;
    var accumulated = 0;
    for (final s in stages) {
      accumulated += s.durationDays;
      if (day <= accumulated) return s;
    }
    return stages.last;
  }

  /// Ca tưới của ngày [day] = ca của giai đoạn chứa ngày đó (dữ liệu thật; rỗng nếu chưa có).
  List<DayIrrigationSession> _getSessionsForDay(int day) {
    final stage = _backendStageForDay(day);
    if (stage == null) return [];
    return [
      for (var i = 0; i < stage.sessions.length; i++)
        DayIrrigationSession(
          session: 'S$i',
          title: stage.sessions[i].title,
          startTime: stage.sessions[i].startTime,
          durationMinutes: (stage.sessions[i].durationSeconds / 60)
              .round()
              .clamp(1, 30),
          enabled: stage.sessions[i].enabled,
          method: stage.sessions[i].method ?? '',
          volumeMl: stage.sessions[i].waterPerPlantMl ?? 0,
        ),
    ];
  }

  /// Ngày này thuộc giai đoạn đã có ca LƯU TRONG HỒ SƠ (không phải lịch mẫu của cây).
  bool _isStageSavedInProfile(int day) =>
      _backendStageForDay(day)?.fromProfile == true;

  int _getStageIndexForDay(DefaultCropProfile profile, int day) {
    if (profile.growthStages.isEmpty) return 0;
    var accumulated = 0;
    for (int i = 0; i < profile.growthStages.length; i++) {
      final s = profile.growthStages[i];
      final start = accumulated + 1;
      final end = accumulated + s.durationDays;
      accumulated = end;
      if (day >= start && day <= end) {
        return i;
      }
    }
    return profile.growthStages.length - 1;
  }

  GrowthStageProfile? _getStageForDay(DefaultCropProfile profile, int day) {
    if (profile.growthStages.isEmpty) return null;
    return profile.growthStages[_getStageIndexForDay(profile, day)];
  }

  Color _getStageColor(int stageIndex) {
    switch (stageIndex % 4) {
      case 0:
        return const Color(0xFF10B981); // Emerald (Cây con)
      case 1:
        return const Color(0xFF0284C7); // Sky (Thân lá)
      case 2:
        return const Color(0xFFF59E0B); // Amber (Hoa/Trái)
      case 3:
      default:
        return const Color(0xFF8B5CF6); // Purple (Thu hoạch)
    }
  }

  Color _getStageBgColor(int stageIndex) {
    switch (stageIndex % 4) {
      case 0:
        return const Color(0xFFECFDF5);
      case 1:
        return const Color(0xFFF0F9FF);
      case 2:
        return const Color(0xFFFFFBEB);
      case 3:
      default:
        return const Color(0xFFF5F3FF);
    }
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Lưu ca của giai đoạn chứa [day] (hoặc của MỌI giai đoạn khi [allStages]) lên backend rồi tải lại. Báo kết quả thật.
  Future<void> _saveSessions(
    int day,
    List<DayIrrigationSession> sessions, {
    bool allStages = false,
  }) async {
    if (!_canEditSchedule) {
      _toast(
        'Hồ sơ hệ thống chỉ để xem. Tạo bản sao riêng của trang trại để chỉnh lịch tưới.',
        error: true,
      );
      return;
    }
    final stage = _backendStageForDay(day);
    if (stage == null) {
      _toast('Hồ sơ chưa có giai đoạn nào để lưu lịch.', error: true);
      return;
    }
    final mapped = [
      for (final s in sessions)
        ProfileSession(
          title: s.title,
          startTime: s.startTime,
          durationSeconds: s.durationMinutes * 60,
          enabled: s.enabled,
          method: s.method.trim().isEmpty ? null : s.method.trim(),
          waterPerPlantMl: s.volumeMl > 0 ? s.volumeMl : null,
        ),
    ];
    final invalid = validateStageSessions(mapped);
    if (invalid != null) {
      _toast(invalid, error: true);
      return;
    }
    _rebuild(() => _saving = true);
    try {
      final targets = allStages ? _schedule!.stages : [stage];
      await CropApi.updateProfileIrrigation(widget.profile.profileId, [
        for (final t in targets) stageIrrigationPayload(t.stageId, mapped),
      ]);
      final fresh = await CropApi.getProfileIrrigation(
        widget.profile.profileId,
      );
      if (!mounted) return;
      _rebuild(() => _schedule = ProfileSchedule.fromJson(fresh));
      _toast(
        allStages
            ? 'Đã lưu lịch tưới cho mọi giai đoạn của hồ sơ.'
            : 'Đã lưu lịch tưới của giai đoạn "${stage.name}".',
      );
    } catch (e) {
      if (mounted)
        _toast(
          'Không lưu được lịch tưới: ${e.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
    } finally {
      if (mounted) _rebuild(() => _saving = false);
    }
  }

  void _updateDaySessions(int day, List<DayIrrigationSession> sessions) =>
      _saveSessions(day, sessions);

  void _applyToCurrentStage(int day) =>
      _saveSessions(day, _getSessionsForDay(day));

  void _applyToAllDaysWith(int day, List<DayIrrigationSession> sessions) =>
      _saveSessions(day, sessions, allStages: true);
}
