/// Mức độ gấp của hạn chót công việc (khớp `dueLabel` trên web).
enum DueTone { late, today, soon, later, none }

class DueLabel {
  final String text;
  final DueTone tone;
  const DueLabel(this.text, this.tone);
}

/// Hạn chót dễ đọc: "Quá hạn 2 ngày", "Hôm nay (15:02)", "Ngày mai", "Còn 3 ngày (04/11/2026)".
DueLabel dueLabel(DateTime? dueUtc, {DateTime? now}) {
  if (dueUtc == null) return const DueLabel('Chưa đặt hạn', DueTone.none);
  String two(int v) => v.toString().padLeft(2, '0');
  final due = dueUtc.toLocal();
  final today = now ?? DateTime.now();
  final days = DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  final date = '${two(due.day)}/${two(due.month)}/${due.year}';
  if (days < 0) return DueLabel('Quá hạn ${-days} ngày ($date)', DueTone.late);
  if (days == 0) {
    return DueLabel(
      'Hôm nay (${two(due.hour)}:${two(due.minute)})',
      DueTone.today,
    );
  }
  if (days == 1) return DueLabel('Ngày mai ($date)', DueTone.soon);
  return DueLabel('Còn $days ngày ($date)', DueTone.later);
}
