// Backend thay THẾ toàn bộ danh sách quyền Zone của Farmer ở PUT /users/{id}/zone-access.
// Vì vậy phải giữ nguyên các quyền Zone hiện có nằm ngoài phạm vi đang chỉnh (vd. Zone của Farm khác)
// và chỉ cập nhật các Zone được hiển thị trong màn hình.
List<Map<String, dynamic>> mergeZoneAccessPayload({
  required Iterable<({String zoneId, bool canControl})> existing,
  required Set<String> editableZoneIds,
  required Map<String, bool?> draft,
}) {
  return [
    for (final a in existing)
      if (!editableZoneIds.contains(a.zoneId)) {'zoneId': a.zoneId, 'canControl': a.canControl},
    for (final e in draft.entries)
      if (editableZoneIds.contains(e.key) && e.value != null) {'zoneId': e.key, 'canControl': e.value},
  ];
}
