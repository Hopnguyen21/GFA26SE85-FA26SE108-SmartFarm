// Logic thuần của tab Tổng quan báo cáo (tách ra để kiểm thử).

/// Cộng các `buckets` (theo tháng) của báo cáo nước/điện thành tổng theo Zone, khóa là TÊN HIỂN THỊ.
/// Gộp theo `zoneId` (không phải theo tên): hai Zone khác nhau trùng tên không bị cộng chung; khi trùng tên thì thêm
/// hậu tố "(2)", "(3)"... để phân biệt. Bucket thiếu zoneId thì gộp theo tên (dữ liệu cũ).
Map<String, double> sumBucketsByZone(Map<String, dynamic>? report) {
  final order = <String>[]; // thứ tự xuất hiện của khóa gộp
  final totals = <String, double>{};
  final names = <String, String>{};
  final raw = report?['buckets'];
  final buckets = raw is List ? raw : const [];
  for (final b in buckets) {
    if (b is! Map) continue;
    final name = '${b['zoneName'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    final id = '${b['zoneId'] ?? ''}'.trim();
    final key = id.isNotEmpty ? 'id:$id' : 'name:$name';
    if (!totals.containsKey(key)) order.add(key);
    final v = b['value'];
    totals[key] =
        (totals[key] ?? 0) + (v is num && v.isFinite ? v.toDouble() : 0);
    names[key] = name;
  }
  final out = <String, double>{};
  final used = <String, int>{};
  for (final key in order) {
    final base = names[key]!;
    final n = (used[base] ?? 0) + 1;
    used[base] = n;
    out[n == 1 ? base : '$base ($n)'] = totals[key]!;
  }
  return out;
}

/// Số lệnh KHÔNG được tính vào tổng nước/điện vì thiết bị chưa khai báo lưu lượng (L/phút) hoặc công suất (W).
/// Backend không điền số giả định mà đếm riêng; nếu không báo cho người dùng thì tổng nhìn như đủ nhưng thực ra thiếu.
int unmeasuredCommands(
  Map<String, dynamic>? water,
  Map<String, dynamic>? power,
) {
  int n(Map<String, dynamic>? r) {
    final v = r?['unmeasuredCommandCount'];
    return v is num && v.isFinite ? v.toInt() : 0;
  }

  return n(water) + n(power);
}
