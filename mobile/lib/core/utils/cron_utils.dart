/// Backend chỉ chạy lịch tưới lặp HẰNG NGÀY vào một giờ cố định, cron 5 trường dạng "phút giờ * * *".
/// Chuỗi cron khác dạng này (ví dụ theo thứ) không đọc được thành giờ và được báo là không hỗ trợ, không đoán.
({int hour, int minute})? parseDailyCron(String cron) {
  final m = RegExp(
    r'^\s*(\d{1,2})\s+(\d{1,2})\s+\*\s+\*\s+\*\s*$',
  ).firstMatch(cron);
  if (m == null) return null;
  final minute = int.parse(m.group(1)!);
  final hour = int.parse(m.group(2)!);
  if (minute > 59 || hour > 23) return null;
  return (hour: hour, minute: minute);
}

/// "06:30" → "30 6 * * *". Trả null nếu giờ không hợp lệ.
String? buildDailyCron(String hhmm) {
  final t = parseHhmm(hhmm);
  return t == null ? null : '${t.minute} ${t.hour} * * *';
}

({int hour, int minute})? parseHhmm(String value) {
  final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(value);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return (hour: h, minute: min);
}

/// Giờ hiển thị từ cron hằng ngày; null nếu cron không phải dạng hằng ngày.
String? cronToHhmm(String cron) {
  final t = parseDailyCron(cron);
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
