import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';

void main() {
  group('EmergencyStopResult.fromJson', () {
    test('đọc đúng phản hồi backend (camelCase)', () {
      final r = EmergencyStopResult.fromJson({
        'success': true,
        'stoppedCount': 4,
        'message': 'Đã dừng khẩn cấp thành công 4 rơ-le thiết bị.',
      });
      expect(r.success, isTrue);
      expect(r.stoppedCount, 4);
      expect(r.message, contains('4 rơ-le'));
    });

    test('thiếu message thì tự tạo thông báo theo số rơ-le', () {
      final r = EmergencyStopResult.fromJson({
        'success': true,
        'stoppedCount': 0,
      });
      expect(r.stoppedCount, 0);
      expect(r.message, 'Đã phát lệnh dừng khẩn cấp 0 rơ-le.');
    });

    test('body rỗng không bị coi là thành công', () {
      final r = EmergencyStopResult.fromJson(const {});
      expect(r.success, isFalse);
      expect(r.stoppedCount, 0);
    });
  });
}
