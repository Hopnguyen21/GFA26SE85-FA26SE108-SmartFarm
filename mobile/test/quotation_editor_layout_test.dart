import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/support/quotation_editor.dart';

QuotationItem _item(
  String code,
  String name,
  String unit,
  int qty,
  double price,
) => QuotationItem(
  code: code,
  name: name,
  category: 'HARDWARE',
  unit: unit,
  quantity: qty,
  unitPrice: price,
  vatPercent: 8,
  totalAmount: qty * price * 1.08,
  notes: 'LoRa 915MHz, Chống nước IP67, Bảo hành 24 tháng',
);

Quotation _quote() => Quotation(
  id: 'q',
  status: 'SentToOwner',
  subtotal: 5100000,
  vatAmount: 408000,
  totalAmount: 5508000,
  deposit30: 1652400,
  remaining70: 3855600,
  items: [
    _item(
      'GW-ESP32-DL01',
      'Trạm Central Gateway ESP32-LoRa Dual Antenna',
      'Trạm',
      1,
      3800000,
    ),
    _item(
      'SN-AIR-02',
      'Node Cảm biến Vi khí hậu Không khí SHT30',
      'Node',
      2,
      950000,
    ),
  ],
);

void main() {
  for (final readOnly in [true, false]) {
    testWidgets(
      'bảng báo giá ${readOnly ? 'chỉ xem' : 'sửa'}: màn hẹp 320px, chữ 1.3×, không tràn; đơn giá/ĐVT/VAT hiển thị đủ',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: QuotationEditor(initial: _quote(), readOnly: readOnly),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Trạm Central Gateway ESP32-LoRa Dual Antenna'),
          findsOneWidget,
        );
        if (readOnly) {
          // Dòng tóm tắt thay cho ô nhập bị khoá: không còn nhãn bị cắt ("Trạ", "No", "VA…").
          expect(find.text('Trạm'), findsOneWidget);
          expect(find.text('Đơn giá 3.800.000 đ'), findsOneWidget);
          expect(find.text('VAT 8%'), findsWidgets);
          expect(find.text('SL 2', skipOffstage: false), findsOneWidget);
        } else {
          expect(find.text('Đơn giá (đ)'), findsWidgets);
          expect(find.text('ĐVT'), findsWidgets);
          expect(find.text('VAT %'), findsWidgets);
        }
      },
    );
  }
}
