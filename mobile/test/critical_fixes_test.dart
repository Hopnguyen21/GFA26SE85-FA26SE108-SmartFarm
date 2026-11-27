import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/features/irrigation/season_irrigation_calendar_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/season_irrigation_logic.dart';
import 'package:smartfarm_mobile/features/zones/profile_irrigation_logic.dart';

SeasonDay _day(List<ProfileSession> sessions) => SeasonDay(
  dayNumber: 1,
  date: '2026-11-26',
  stageId: 's1',
  stageName: 'Cây con',
  source: DaySource.profile,
  outOfRange: false,
  sessions: sessions,
);

ProfileSession _s(String title, String time) =>
    ProfileSession(title: title, startTime: time, durationSeconds: 600);

void main() {
  group('ActuatorCommandResult.acknowledged', () {
    test('chỉ ACK khi status là Acknowledged', () {
      expect(
        ActuatorCommandResult.fromJson({'status': 'Acknowledged'}).acknowledged,
        isTrue,
      );
    });

    test('observedState RUNNING không được coi là ACK (vd. lệnh TẮT)', () {
      final r = ActuatorCommandResult.fromJson({
        'status': 'Sent',
        'observedState': 'RUNNING',
      });
      expect(r.acknowledged, isFalse);
    });
  });

  group('Lịch tưới theo vụ', () {
    test('ngày không có ca: ô trống đều TẮT và không gửi lên máy chủ', () {
      final slots = extractDaySessions(_day(const []));
      expect(slots.every((s) => !s.enabled), isTrue);
      expect(sessionsToSave(slots, extraDaySessions(_day(const []))), isEmpty);
    });

    test('ca thứ 4 trở đi được giữ lại khi lưu', () {
      final day = _day([
        _s('Sáng 1', '06:00'),
        _s('Sáng 2', '08:00'),
        _s('Trưa', '12:00'),
        _s('Chiều', '16:00'),
      ]);
      final saved = sessionsToSave(
        extractDaySessions(day),
        extraDaySessions(day),
      );
      expect(saved.map((s) => s.title).toSet(), {
        'Sáng 1',
        'Sáng 2',
        'Trưa',
        'Chiều',
      });
    });

    test('ô trống đã được người dùng bật thì được lưu', () {
      final slots = extractDaySessions(_day(const []));
      slots[0] = slots[0].copyWith(enabled: true);
      final saved = sessionsToSave(slots, const []);
      expect(saved, hasLength(1));
      expect(saved.single.enabled, isTrue);
    });
  });
}
