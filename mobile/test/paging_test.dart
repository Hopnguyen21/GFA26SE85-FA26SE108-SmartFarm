import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/utils/paging.dart';

void main() {
  test('phân trang 10 dòng: số trang, cắt trang, kẹp trang', () {
    final items = List.generate(23, (i) => i);
    expect(pageCount(23), 3);
    expect(pageCount(0), 1);
    expect(pageCount(10), 1);
    expect(pageCount(11), 2);
    expect(pageSlice(items, 0), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(pageSlice(items, 2), [20, 21, 22]);
    expect(pageSlice(items, 9), [20, 21, 22]); // quá trang cuối → trang cuối
    expect(pageSlice(items, -3).length, 10);
    expect(pageSlice(<int>[], 0), isEmpty);
    expect(clampPage(5, 12), 1);
  });

  test('mới nhất lên đầu, không có thời gian xuống cuối, ổn định', () {
    final rows = [
      ('a', '2026-11-10T08:00:00'),
      ('b', null),
      ('c', '2026-11-16T08:00:00Z'),
      ('d', '2026-11-16T08:00:00Z'),
      ('e', 'rác'),
    ];
    final out = sortNewestFirst(rows, (r) => parseTime(r.$2));
    expect(out.map((e) => e.$1), ['c', 'd', 'a', 'b', 'e']);
  });

  test('parseTime coi chuỗi không múi giờ là UTC', () {
    expect(parseTime('2026-11-16T08:00:00')!.isUtc, isTrue);
    expect(parseTime('2026-11-16T08:00:00Z')!.isUtc, isTrue);
    expect(parseTime(''), isNull);
    expect(parseTime(null), isNull);
  });
}
