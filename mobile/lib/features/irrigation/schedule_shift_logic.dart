import '../../core/models/models.dart';

/// Logic thuần (không phụ thuộc giao diện) cho màn Lịch & Luật tự động: xác định ca tưới theo giờ, gộp theo Zone,
/// sắp xếp và phát hiện lịch trùng giờ trên cùng thiết bị.

/// Ca tưới theo giờ bắt đầu "HH:mm": sáng 05:00–10:59, trưa 11:00–14:59, chiều 15:00–19:59, còn lại là đêm.
/// Giờ sai định dạng trả về null (không đoán ca).
String? shiftOfTime(String startTime) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(startTime.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  if (h >= 5 && h < 11) return 'Ca sáng';
  if (h >= 11 && h < 15) return 'Ca trưa';
  if (h >= 15 && h < 20) return 'Ca chiều';
  return 'Ca đêm';
}

/// Số phút từ 00:00 của giờ "HH:mm"; null khi sai định dạng.
int? minutesOfDay(String startTime) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(startTime.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// Sắp xếp theo tên Zone rồi theo giờ bắt đầu (lịch sai giờ xếp cuối); không đổi danh sách gốc.
List<ScheduleModel> sortedSchedules(Iterable<ScheduleModel> list) {
  final out = list.toList();
  out.sort((a, b) {
    final z = a.zoneName.compareTo(b.zoneName);
    if (z != 0) return z;
    final ta = minutesOfDay(a.startTime) ?? 1 << 20;
    final tb = minutesOfDay(b.startTime) ?? 1 << 20;
    return ta.compareTo(tb);
  });
  return out;
}

/// Luật: đang bật lên trước, rồi theo Zone, rồi theo tên.
List<AutomationRuleModel> sortedRules(Iterable<AutomationRuleModel> list) {
  final out = list.toList();
  out.sort((a, b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    final z = a.zoneName.compareTo(b.zoneName);
    if (z != 0) return z;
    return a.name.compareTo(b.name);
  });
  return out;
}

/// Gộp theo Zone giữ thứ tự xuất hiện (danh sách đã sắp xếp thì các nhóm theo thứ tự tên Zone).
Map<String, List<T>> groupByZone<T>(
  Iterable<T> items,
  String Function(T) zoneOf,
) {
  final out = <String, List<T>>{};
  for (final it in items) {
    out.putIfAbsent(zoneOf(it), () => []).add(it);
  }
  return out;
}

/// Mã các lịch đang BẬT bị trùng giờ với lịch khác trong CÙNG Zone và có chung ít nhất một ngày (backend cũng chặn trùng theo Zone,
/// nên đây là cảnh báo cho dữ liệu cũ/seed): hai khoảng [bắt đầu, bắt đầu + thời lượng) giao nhau. Lịch tắt hoặc sai giờ không được xét.
Set<String> conflictingScheduleIds(Iterable<ScheduleModel> list) {
  final active = [
    for (final s in list)
      if (s.isActive && minutesOfDay(s.startTime) != null) s,
  ];
  final conflicts = <String>{};
  for (var i = 0; i < active.length; i++) {
    for (var j = i + 1; j < active.length; j++) {
      final a = active[i], b = active[j];
      if (a.zoneId != b.zoneId) continue;
      if (!a.daysOfWeek.any(b.daysOfWeek.contains)) continue;
      final a0 = minutesOfDay(a.startTime)!;
      final b0 = minutesOfDay(b.startTime)!;
      final a1 = a0 + a.durationMinutes;
      final b1 = b0 + b.durationMinutes;
      if (a0 < b1 && b0 < a1) {
        conflicts
          ..add(a.scheduleId)
          ..add(b.scheduleId);
      }
    }
  }
  return conflicts;
}
