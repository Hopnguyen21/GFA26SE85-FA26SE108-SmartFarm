/// Phân trang và sắp xếp theo thời gian dùng chung cho các danh sách dài (mỗi trang 10 dòng).
const int kPageSize = 10;

/// Số trang (tối thiểu 1 để hiển thị "Trang 1/1" khi rỗng).
int pageCount(int total, [int size = kPageSize]) =>
    total <= 0 ? 1 : (total + size - 1) ~/ size;

/// Giữ số trang trong [0, pageCount-1] (danh sách co lại sau khi lọc/xóa thì lùi về trang cuối).
int clampPage(int page, int total, [int size = kPageSize]) =>
    page.clamp(0, pageCount(total, size) - 1);

/// Các phần tử của trang [page] (đếm từ 0).
List<T> pageSlice<T>(List<T> items, int page, [int size = kPageSize]) {
  final p = clampPage(page, items.length, size);
  final start = p * size;
  final end = (start + size) > items.length ? items.length : start + size;
  return items.sublist(start, end);
}

/// Đọc mốc thời gian ISO-8601 (có hoặc không có "Z"); coi không có múi giờ là UTC như API. Không đọc được → null.
DateTime? parseTime(Object? v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty || s == 'null') return null;
  final hasZone = s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  return DateTime.tryParse(hasZone || !s.contains('T') ? s : '${s}Z');
}

/// Mới nhất lên đầu; phần tử không có thời gian xuống cuối và giữ thứ tự gốc (sắp xếp ổn định).
List<T> sortNewestFirst<T>(Iterable<T> items, DateTime? Function(T) timeOf) {
  final indexed = [for (final (i, e) in items.indexed) (e, i, timeOf(e))];
  indexed.sort((a, b) {
    final ta = a.$3, tb = b.$3;
    if (ta == null && tb == null) return a.$2.compareTo(b.$2);
    if (ta == null) return 1;
    if (tb == null) return -1;
    final c = tb.compareTo(ta);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  return [for (final e in indexed) e.$1];
}
