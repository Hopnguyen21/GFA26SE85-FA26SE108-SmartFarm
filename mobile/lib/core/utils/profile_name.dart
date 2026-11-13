// Tên hồ sơ để hiển thị.
//
// Khi gắn hồ sơ hệ thống cho Zone hoặc bắt đầu vụ, backend tạo bản sao riêng của trang trại và đặt tên
// "tên hồ sơ · tên Zone · mã GUID" (mã GUID chỉ để tên không bị trùng). Phần đuôi đó là chi tiết kỹ thuật,
// không nên hiện cho người dùng.

final _idSuffix = RegExp(
  r'\s*·\s*(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})\s*$',
);

/// Bỏ mã GUID ở cuối tên hồ sơ; nếu nêu [zoneName] thì bỏ luôn đoạn " · tên Zone" ở cuối (tên Zone đã hiện ở chỗ khác).
/// Backend cắt tên Zone tối đa 40 ký tự khi đặt tên nên cả bản đầy đủ lẫn bản cắt đều được nhận ra.
/// Tên không có đuôi như vậy được giữ nguyên.
String displayProfileName(String? name, {String? zoneName}) {
  var s = (name ?? '').trim();
  if (s.isEmpty) return s;
  s = s.replaceFirst(_idSuffix, '').trimRight();
  final zone = (zoneName ?? '').trim();
  if (zone.isNotEmpty) {
    final candidates = {zone, if (zone.length > 40) zone.substring(0, 40)};
    for (final z in candidates) {
      final suffix = ' · $z';
      if (s.length > suffix.length && s.endsWith(suffix)) {
        s = s.substring(0, s.length - suffix.length).trimRight();
        break;
      }
    }
  }
  return s;
}

/// Như [displayProfileName] nhưng giữ null.
String? displayProfileNameOrNull(String? name, {String? zoneName}) =>
    name == null ? null : displayProfileName(name, zoneName: zoneName);

/// Bản sao danh sách hồ sơ/vụ với tên đã bỏ mã GUID, để mọi màn hình dùng chung dữ liệu sạch.
/// Làm cho cả `name` (hồ sơ) lẫn `growthProfileName` (vụ trồng) nếu có.
List<Map<String, dynamic>> withDisplayProfileNames(
  List<Map<String, dynamic>> items,
) => [
  for (final m in items)
    {
      ...m,
      if (m['name'] is String) 'name': displayProfileName(m['name'] as String),
      if (m['growthProfileName'] is String)
        'growthProfileName': displayProfileName(
          m['growthProfileName'] as String,
        ),
    },
];
