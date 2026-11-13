import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_seasons_section.dart';

void main() {
  test('vụ đang canh tác lên đầu, cùng trạng thái thì vụ mới hơn trước', () {
    final seasons = <Map<String, dynamic>>[
      {'name': 'old-done', 'status': 'Completed', 'startDate': '2026-01-01'},
      {'name': 'planned', 'status': 'Planned', 'startDate': '2026-12-01'},
      {'name': 'cancelled', 'status': 'Cancelled', 'startDate': '2026-11-01'},
      {'name': 'new-done', 'status': 'Completed', 'startDate': '2026-06-01'},
      {'name': 'running', 'status': 'InProgress', 'startDate': '2026-10-03'},
      {'name': 'unknown', 'status': 'Weird', 'startDate': '2026-12-31'},
    ]..sort(compareSeasonsForDisplay);

    expect(
      [for (final s in seasons) s['name']],
      ['running', 'planned', 'new-done', 'old-done', 'cancelled', 'unknown'],
    );
  });
}
