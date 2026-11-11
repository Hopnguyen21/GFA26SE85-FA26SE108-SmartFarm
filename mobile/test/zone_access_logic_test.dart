import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/workforce/zone_access_logic.dart';

void main() {
  test('giữ quyền Zone ngoài phạm vi đang chỉnh và cập nhật phần được chọn', () {
    final out = mergeZoneAccessPayload(
      existing: [(zoneId: 'other', canControl: true), (zoneId: 'z1', canControl: false)],
      editableZoneIds: {'z1', 'z2'},
      draft: {'z1': true, 'z2': null},
    );
    expect(out, [
      {'zoneId': 'other', 'canControl': true},
      {'zoneId': 'z1', 'canControl': true},
    ]);
  });

  test('bỏ chọn hết Zone đang hiển thị vẫn giữ Zone khác', () {
    final out = mergeZoneAccessPayload(
      existing: [(zoneId: 'other', canControl: false), (zoneId: 'z1', canControl: true)],
      editableZoneIds: {'z1'},
      draft: {'z1': null},
    );
    expect(out, [
      {'zoneId': 'other', 'canControl': false},
    ]);
  });
}
