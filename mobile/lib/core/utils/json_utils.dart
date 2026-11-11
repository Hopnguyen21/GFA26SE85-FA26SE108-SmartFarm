// Đọc JSON backend một cách dung sai (camelCase/PascalCase, số dạng chuỗi, danh sách bị bọc) mà KHÔNG bịa giá trị mặc định.

/// Lấy trường theo tên không phân biệt hoa thường (camelCase/PascalCase) và bỏ qua giá trị null.
dynamic jsonField(Map<dynamic, dynamic> j, String key) {
  final direct = j[key];
  if (direct != null) return direct;
  final lower = key.toLowerCase();
  for (final e in j.entries) {
    if ('${e.key}'.toLowerCase() == lower && e.value != null) return e.value;
  }
  return null;
}

/// Số từ JSON: nhận num hoặc chuỗi ("60", "60.5", "60,5"); khác thì null (không ép thành 0).
double? jsonNumber(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

/// Danh sách từ JSON, kể cả khi bị bọc: `[..]`, `{value:[..]}`, `{items:[..]}`, `{data:[..]}`, `{$values:[..]}`.
List<dynamic> jsonList(dynamic v) {
  if (v is List) return v;
  if (v is Map) {
    for (final k in const ['value', 'items', 'data', r'$values', 'results']) {
      final inner = jsonField(v, k);
      if (inner is List) return inner;
    }
  }
  return const [];
}
