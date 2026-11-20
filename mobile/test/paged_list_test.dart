import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/widgets/paged_list.dart';

void main() {
  testWidgets(
    'PagedList: 10 dòng mỗi trang, chuyển trang, kẹp lại khi danh sách co',
    (t) async {
      t.view.physicalSize = const Size(800, 4000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var items = List.generate(23, (i) => 'Mục $i');
      late StateSetter set;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (c, s) {
                set = s;
                return PagedList<String>(
                  items: items,
                  itemBuilder: (_, e) => SizedBox(height: 20, child: Text(e)),
                );
              },
            ),
          ),
        ),
      );
      expect(find.textContaining('Mục '), findsNWidgets(10));
      expect(find.text('Mục 0'), findsOneWidget);
      expect(find.text('Trang 1/3 · 23 mục'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('page-next')));
      await t.pump();
      expect(find.text('Mục 10'), findsOneWidget);
      expect(find.text('Mục 0'), findsNothing);
      await t.tap(find.byKey(const ValueKey('page-next')));
      await t.pump();
      expect(
        find.textContaining('Mục '),
        findsNWidgets(3),
      ); // trang cuối 20..22

      // danh sách co lại còn 12 mục: trang 3 không còn → lùi về trang 2
      set(() => items = items.take(12).toList());
      await t.pump();
      expect(find.text('Trang 2/2 · 12 mục'), findsOneWidget);
      expect(find.textContaining('Mục '), findsNWidgets(2));

      // ≤ 10 mục: không hiện thanh trang
      set(() => items = items.take(7).toList());
      await t.pump();
      expect(find.byKey(const ValueKey('page-next')), findsNothing);
      expect(find.textContaining('Mục '), findsNWidgets(7));
    },
  );
}
