import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/support/quotation_editor.dart';

void main() {
  testWidgets('Existing quotation keeps equipment, terms and notes when adding items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final q = Quotation(
      id: 'q',
      subtotal: 100,
      vatAmount: 8,
      totalAmount: 108,
      deposit30: 32.4,
      remaining70: 75.6,
      status: 'SentToOwner',
      notes: 'Thêm theo khảo sát',
      contractTerms: 'Bảo hành',
      items: [
        QuotationItem(
          code: 'GW',
          name: 'Gateway',
          category: 'HARDWARE',
          unit: 'Bộ',
          quantity: 2,
          unitPrice: 50,
          vatPercent: 8,
          totalAmount: 108,
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: QuotationEditor(initial: q)));
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.text('Thêm theo khảo sát'), findsOneWidget);
    expect(find.text('Bảo hành'), findsOneWidget);
    await tester.tap(find.text('Thêm hạng mục'));
    await tester.pump();
    expect(find.text('Hạng mục 2'), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa hạng mục').last);
    await tester.pump();
    expect(find.text('Hạng mục 2'), findsNothing);
    expect(find.text('Gateway'), findsOneWidget);
  });

  testWidgets('Empty quotation cannot be submitted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: QuotationEditor()));
    await tester.tap(find.text('Gửi báo giá để Owner xem và xác nhận'));
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin'), findsWidgets);
    expect(find.text('Nhập đơn giá lớn hơn 0'), findsOneWidget);
    expect(find.byType(QuotationEditor), findsOneWidget);
  });
}
