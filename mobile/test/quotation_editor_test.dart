import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/support/quotation_editor.dart';

void main() {
  testWidgets(
    'read-only contract retains API metadata, notes and payment amounts',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final q = Quotation.fromJson({
        'id': 'contract-real-id',
        'serviceRequestId': 'request-id',
        'technicianUserId': 'technician-id',
        'createdAtUtc': '2026-11-13T01:00:00Z',
        'vatPercent': 8,
        'subtotal': 1000000,
        'vatAmount': 80000,
        'totalAmount': 1080000,
        'deposit30Percent': 324001,
        'remaining70Percent': 755999,
        'status': 'SignedByOwner',
        'notes': 'Ghi chú riêng từ API',
        'contractTerms': 'Điều khoản riêng',
        'items': [
          {
            'code': 'NODE',
            'name': 'Node',
            'category': 'SENSOR_NODE',
            'unit': 'Cái',
            'quantity': 1,
            'unitPrice': 1000000,
            'vatPercent': 8,
            'totalAmount': 1080000,
          },
        ],
      });
      expect(q.serviceRequestId, 'request-id');
      expect(q.technicianUserId, 'technician-id');
      expect(q.vatPercent, 8);
      await tester.pumpWidget(
        MaterialApp(home: QuotationEditor(initial: q, readOnly: true)),
      );
      expect(find.text('Mã hợp đồng: contract-real-id'), findsOneWidget);
      expect(
        find.text('Ngày lập: ${formatContractDate(q.createdAtUtc!)}'),
        findsOneWidget,
      );
      expect(
        find.text('Ghi chú bổ sung: Ghi chú riêng từ API'),
        findsOneWidget,
      );
      expect(find.text('324.001 đ'), findsOneWidget);
      expect(find.text('755.999 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  bangDuToanTests();
  khoVaChiXemTests();
  testWidgets(
    'Existing quotation keeps equipment, terms and notes when adding items',
    (tester) async {
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
      // Một ô điều khoản duy nhất (như web): ưu tiên điều khoản đã lưu, không còn ô ghi chú riêng.
      expect(find.text('Thêm theo khảo sát'), findsNothing);
      expect(find.text('Bảo hành'), findsOneWidget);
      await tester.tap(find.text('Nhập ngoài'));
      await tester.pump();
      expect(find.text('Hạng mục 2'), findsOneWidget);
      expect(find.text('Gateway'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa hạng mục').last);
      await tester.pump();
      expect(find.text('Hạng mục 2'), findsNothing);
      expect(find.text('Gateway'), findsOneWidget);
    },
  );

  testWidgets('Empty quotation cannot be submitted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: QuotationEditor()));
    await tester.tap(find.text('Xác nhận & gửi hợp đồng cho khách'));
    await tester.pump();
    expect(find.text('Vui lòng nhập thông tin'), findsWidgets);
    expect(find.text('Nhập đơn giá lớn hơn 0'), findsOneWidget);
    expect(find.byType(QuotationEditor), findsOneWidget);
  });
}

class _Opened {
  QuotationDraft? draft;
}

QuotationItem _item(String code, int qty, double price, {double vat = 8}) =>
    QuotationItem(
      code: code,
      name: 'Thiết bị $code',
      category: 'HARDWARE',
      unit: 'Cái',
      quantity: qty,
      unitPrice: price,
      vatPercent: vat,
      totalAmount: qty * price * (1 + vat / 100),
    );

Future<_Opened> _open(
  WidgetTester tester, {
  List<QuotationItem>? estimate,
  bool readOnly = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 9000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final out = _Opened();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                out.draft = await Navigator.push<QuotationDraft>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuotationEditor(
                      estimateItems: estimate,
                      contractTitle: 'Hợp đồng lắp đặt IoT #339E17EB',
                      farmName: 'Nông trại CNC Lâm Đồng',
                      zoneName: 'Nhà màng 03',
                      readOnly: readOnly,
                    ),
                  ),
                );
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
  return out;
}

void bangDuToanTests() {
  testWidgets(
    'số liệu thật của đợt 64b8e491 (5 dòng dự toán trong DB): tổng, VAT, cọc 30%, nghiệm thu 70% khớp cách backend tính',
    (tester) async {
      await _open(
        tester,
        estimate: [
          _item('GW-ESP32-DL01', 1, 3800000),
          _item('SN-AIR-02', 1, 950000),
          _item('ACT-VALVE-01', 1, 2150000),
          _item('HW-KIT-01', 2, 150000),
          _item('INSTALLATION', 1, 500000),
        ],
      );
      expect(find.textContaining('(5/5)'), findsOneWidget);
      expect(
        find.text('7.700.000 đ'),
        findsOneWidget,
      ); // 3.800.000+950.000+2.150.000+300.000+500.000
      expect(find.text('616.000 đ'), findsOneWidget); // VAT 8%
      expect(find.text('8.316.000 đ'), findsOneWidget); // tổng
      expect(find.text('2.494.800 đ'), findsOneWidget); // cọc 30%
      expect(find.text('5.821.200 đ'), findsOneWidget); // nghiệm thu 70%
    },
  );

  testWidgets(
    'bảng dự toán: tiêu đề hợp đồng, nơi lắp, tổng tiền, tạm ứng 30% và nghiệm thu 70% tính đúng',
    (tester) async {
      await _open(
        tester,
        estimate: [_item('GW', 1, 3800000), _item('SN', 2, 1250000)],
      );
      expect(find.text('Hợp đồng lắp đặt IoT #339E17EB'), findsOneWidget);
      expect(find.text('Trang trại: Nông trại CNC Lâm Đồng'), findsOneWidget);
      expect(find.text('Phân khu: Nhà màng 03'), findsOneWidget);
      expect(find.text('Khách hàng: Chủ trang trại'), findsOneWidget);
      expect(
        find.textContaining('BẢNG BÁO GIÁ THIẾT BỊ & VẬT TƯ IOT (2/2)'),
        findsOneWidget,
      );
      // 3.800.000 + 2×1.250.000 = 6.300.000; VAT 8% = 504.000; tổng 6.804.000
      expect(find.text('6.300.000 đ'), findsOneWidget);
      expect(find.text('504.000 đ'), findsOneWidget);
      expect(find.text('6.804.000 đ'), findsOneWidget);
      expect(find.text('2.041.200 đ'), findsOneWidget); // cọc 30%
      expect(find.text('4.762.800 đ'), findsOneWidget); // nghiệm thu 70%
    },
  );

  testWidgets(
    'bỏ chọn một dòng: không tính vào tổng và không đưa vào hợp đồng gửi đi',
    (tester) async {
      final out = await _open(
        tester,
        estimate: [_item('GW', 1, 1000000), _item('SN', 1, 500000)],
      );
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      expect(find.textContaining('(1/2)'), findsOneWidget);
      expect(find.text('1.080.000 đ'), findsWidgets); // tổng chỉ còn dòng đầu
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Ghi chú điều khoản & phạm vi lắp đặt *',
        ),
        'Bảo hành 2 năm',
      );
      await tester.tap(find.text('Xác nhận & gửi hợp đồng cho khách'));
      await tester.pumpAndSettle();
      final draft = out.draft!;
      expect(draft.items, hasLength(1));
      expect(draft.items.single['code'], 'GW');
      expect(draft.terms, 'Bảo hành 2 năm');
    },
  );

  testWidgets('điều khoản bắt buộc; bỏ chọn hết thì không gửi được', (
    tester,
  ) async {
    final out = await _open(tester, estimate: [_item('GW', 1, 1000000)]);
    await tester.tap(find.text('Xác nhận & gửi hợp đồng cho khách'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập thông tin'), findsOneWidget);
    expect(out.draft, isNull);
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Ghi chú điều khoản & phạm vi lắp đặt *',
      ),
      'Điều khoản',
    );
    await tester.tap(find.text('Bỏ chọn tất cả'));
    await tester.pump();
    await tester.tap(find.text('Xác nhận & gửi hợp đồng cho khách'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chọn ít nhất một hạng mục đưa vào hợp đồng.'),
      findsOneWidget,
    );
    expect(out.draft, isNull);
  });

  testWidgets('tăng giảm số lượng cập nhật tổng; không giảm dưới 1', (
    tester,
  ) async {
    await _open(tester, estimate: [_item('GW', 1, 1000000, vat: 0)]);
    expect(find.text('1.000.000 đ'), findsWidgets);
    await tester.tap(find.byTooltip('Tăng số lượng'));
    await tester.pump();
    expect(find.text('2.000.000 đ'), findsWidgets);
    await tester.tap(find.byTooltip('Giảm số lượng'));
    await tester.tap(find.byTooltip('Giảm số lượng'));
    await tester.pump();
    expect(find.text('1.000.000 đ'), findsWidgets);
  });

  testWidgets('hủy bỏ: đóng mà không trả bản nháp', (tester) async {
    final out = await _open(tester, estimate: [_item('GW', 1, 1000000)]);
    await tester.tap(find.text('Hủy bỏ'));
    await tester.pumpAndSettle();
    expect(out.draft, isNull);
    expect(find.byType(QuotationEditor), findsNothing);
  });
}

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _stock = <Map<String, dynamic>>[
  {
    'id': 'a',
    'code': 'GW-ESP32-DL01',
    'name': 'Trạm Central Gateway',
    'category': 'GATEWAY',
    'model': 'LG308N',
    'manufacturer': 'Dragino',
    'quantityInStock': 3,
    'unitPrice': 3800000,
  },
  {
    'id': 'b',
    'code': 'SN-SOIL-01',
    'name': 'Node Cảm biến Đất',
    'category': 'SENSOR_NODE',
    'quantityInStock': 0,
    'unitPrice': 1250000,
  },
  {
    'id': 'c',
    'code': 'ACT-PUMP-02',
    'name': 'Node Bơm',
    'category': 'PUMP',
    'quantityInStock': 5,
    'unitPrice': 0,
  },
];

void khoVaChiXemTests() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 't@b.c',
      role: 'PlatformTechnician',
    );
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient(
        (r) async => r.url.path.endsWith('/platform/hardware-items')
            ? _json(_stock)
            : _json([]),
      ),
    );
  });

  testWidgets(
    'hợp đồng đã ký: chỉ xem, khóa mọi thao tác sửa và có thông báo khóa',
    (tester) async {
      final out = await _open(
        tester,
        estimate: [_item('GW', 1, 1000000)],
        readOnly: true,
      );
      expect(find.text('Hợp đồng triển khai IoT (đã khóa)'), findsOneWidget);
      expect(
        find.textContaining('đã được chủ trang trại ký và thanh toán cọc'),
        findsOneWidget,
      );
      expect(find.text('Thêm thiết bị từ kho'), findsNothing);
      expect(find.text('Nhập ngoài'), findsNothing);
      expect(find.text('Chọn tất cả'), findsNothing);
      expect(find.byTooltip('Xóa hạng mục'), findsNothing);
      expect(find.byTooltip('Tăng số lượng'), findsNothing);
      expect(find.text('Xác nhận & gửi hợp đồng cho khách'), findsNothing);
      final cb = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(cb.onChanged, isNull);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(out.draft, isNull);
    },
  );

  testWidgets(
    'thêm từ kho: tìm kiếm, lọc chủng loại, tồn kho; chọn lại món đã có thì +1 số lượng',
    (tester) async {
      await _open(
        tester,
        estimate: [_item('GW-ESP32-DL01', 1, 3800000, vat: 0)],
      );
      await tester.tap(find.text('Thêm thiết bị từ kho'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chọn thiết bị & vật tư từ kho nền tảng'),
        findsOneWidget,
      );
      expect(find.text('Tồn kho: 3'), findsOneWidget);
      expect(find.text('Tồn kho: 0'), findsOneWidget);
      // Món chưa có giá: nói rõ, không bịa giá.
      expect(find.textContaining('chưa có giá'), findsOneWidget);
      Finder inPicker(String code) =>
          find.descendant(of: find.byType(ListTile), matching: find.text(code));
      // Lọc chủng loại và tìm kiếm.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Gateway'));
      await tester.pumpAndSettle();
      expect(inPicker('GW-ESP32-DL01'), findsOneWidget);
      expect(inPicker('ACT-PUMP-02'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tất cả chủng loại'));
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'khongco',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Không tìm thấy thiết bị nào phù hợp trong kho.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'lg308',
      );
      await tester.pumpAndSettle();
      expect(inPicker('GW-ESP32-DL01'), findsOneWidget);
      expect(inPicker('SN-SOIL-01'), findsNothing);
      // Món đã có trong bảng: nút "Thêm (+1)" tăng số lượng thay vì thêm dòng mới.
      await tester.tap(find.text('Thêm (+1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn tất chọn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(1/1)'), findsOneWidget);
      expect(find.text('7.600.000 đ'), findsWidgets); // 2 × 3.800.000, VAT 0%
    },
  );

  testWidgets(
    'thêm món mới từ kho: lấy mã, tên, đơn giá, đơn vị Trạm và mô tả model từ kho',
    (tester) async {
      final out = await _open(tester, estimate: [_item('X', 1, 1000)]);
      await tester.tap(find.text('Thêm thiết bị từ kho'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Chọn').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn tất chọn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(2/2)'), findsOneWidget);
      expect(find.text('Model: LG308N (Dragino)'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Ghi chú điều khoản & phạm vi lắp đặt *',
        ),
        'Điều khoản',
      );
      await tester.tap(find.text('Xác nhận & gửi hợp đồng cho khách'));
      await tester.pumpAndSettle();
      final gw = out.draft!.items.firstWhere(
        (i) => i['code'] == 'GW-ESP32-DL01',
      );
      expect(gw['unit'], 'Trạm');
      expect(gw['unitPrice'], 3800000.0);
      expect(gw['category'], 'GATEWAY');
      expect(out.draft!.notes, 'Điều khoản');
      expect(out.draft!.terms, 'Điều khoản');
    },
  );
}
