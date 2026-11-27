import 'dart:convert';
import '../../core/models/models.dart';

/// Ca tưới trong ngày, phân loại giống web (CF3ControlSection): theo tên "sáng/trưa/chiều" hoặc theo giờ bắt đầu.
enum IrrigationSessionKind { morning, noon, afternoon, other }

IrrigationSessionKind scheduleSessionKind(ScheduleModel s) {
  final name = s.name.toLowerCase();
  final t = s.startTime;
  if (name.contains('sáng') || (t.isNotEmpty && t.compareTo('11:00') < 0)) {
    return IrrigationSessionKind.morning;
  }
  if (name.contains('trưa') ||
      (t.compareTo('11:00') >= 0 && t.compareTo('14:00') <= 0)) {
    return IrrigationSessionKind.noon;
  }
  if (name.contains('chiều') || t.compareTo('14:00') > 0) {
    return IrrigationSessionKind.afternoon;
  }
  return IrrigationSessionKind.other;
}

/// Một ca trong kế hoạch tưới của cây (calendarIrrigationPlan.sessions).
class CropPlanSession {
  final String session; // MORNING / NOON / AFTERNOON
  final String startTime;
  final int durationMinutes;
  const CropPlanSession(this.session, this.startTime, this.durationMinutes);

  /// "07:30 (20m)" — đúng định dạng ô xem trước của web.
  String get label => '$startTime (${durationMinutes}m)';
}

/// Đọc kế hoạch tưới 3 ca của cây. Backend lưu dạng chuỗi JSON (web nhận đối tượng); nhận cả hai, hỏng/thiếu thì rỗng
/// để ô xem trước hiện "Chưa có" như web thay vì bịa số liệu.
List<CropPlanSession> parseCropPlanSessions(dynamic plan) {
  dynamic p = plan;
  if (p is String) {
    if (p.trim().isEmpty) return const [];
    try {
      p = jsonDecode(p);
    } catch (_) {
      return const [];
    }
  }
  if (p is! Map) return const [];
  final raw = p['sessions'] ?? p['Sessions'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map && (e['session'] ?? e['Session']) != null)
        CropPlanSession(
          '${e['session'] ?? e['Session']}'.toUpperCase(),
          '${e['startTime'] ?? e['StartTime'] ?? ''}',
          (e['durationMinutes'] as num?)?.toInt() ??
              (((e['durationSeconds'] ?? e['DurationSeconds']) as num?)
                          ?.toInt() ??
                      0) ~/
                  60,
        ),
  ];
}

CropPlanSession? planSessionOf(List<CropPlanSession> s, String key) =>
    s.where((x) => x.session == key).firstOrNull;
