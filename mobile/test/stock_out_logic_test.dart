import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/inventory/stock_out_logic.dart';

Map<String, dynamic> _so(
  String id,
  Object status, {
  String code = 'PXK-1',
  String? zone,
  String? notes,
  List<Map<String, dynamic>> details = const [],
}) => {
  'id': id,
  'stockOutCode': code,
  'status': status,
  'zoneName': zone,
  'notes': notes,
  'createdByName': 'KTV A',
  'createdAtUtc': '2026-11-15T14:49:00Z',
  'details': details,
};

void main() {
  _warehouseChoicesTests();
  test('trạng thái: tên enum và số 0–4 đều đúng, lạ → Bản nháp', () {
    expect(StockOutStatus.parse('Pending'), StockOutStatus.pending);
    expect(StockOutStatus.parse(2), StockOutStatus.approved);
    expect(StockOutStatus.parse('Completed'), StockOutStatus.completed);
    expect(StockOutStatus.parse('4'), StockOutStatus.cancelled);
    expect(StockOutStatus.parse(null), StockOutStatus.draft);
    expect(StockOutStatus.pending.label, 'Chờ duyệt');
  });

  test(
    'phiếu: "N loại thiết bị (M cái)", Zone mặc định như web, người lập',
    () {
      final d = StockOutDoc.fromJson(
        _so(
          'a',
          'Draft',
          details: [
            {
              'itemName': '[GW] Gateway',
              'quantity': 1,
              'unit': 'Cái',
              'currentStock': 9,
            },
            {'itemName': '[SN] Node', 'quantity': 3, 'currentStock': 4},
          ],
        ),
      );
      expect(d.summary, '2 loại thiết bị (4 cái)');
      expect(d.zoneText, 'Toàn trang trại / Kỹ thuật viên');
      expect(d.createdByName, 'KTV A');
      expect(d.lines.last.unit, 'Cái');
      expect(
        StockOutDoc.fromJson(_so('b', 'Draft', zone: 'Zone A')).zoneText,
        'Zone A',
      );
    },
  );

  test(
    'thao tác theo trạng thái: nháp gửi/xóa, chờ duyệt chỉ hủy, đã duyệt không thao tác',
    () {
      StockOutDoc d(Object s) => StockOutDoc.fromJson(_so('x', s));
      List<bool> acts(StockOutDoc x) => [x.canSend, x.canDelete, x.canCancel];
      expect(acts(d('Draft')), [true, true, false]);
      expect(acts(d('Pending')), [false, false, true]);
      expect(acts(d('Approved')), [false, false, false]);
      expect(acts(d('Completed')), [false, false, false]);
      expect(acts(d('Cancelled')), [false, true, false]);
    },
  );

  test(
    'lọc: theo trạng thái và tìm theo mã / Zone / ghi chú (không phân biệt hoa thường)',
    () {
      final all = [
        StockOutDoc.fromJson(
          _so('1', 'Draft', code: 'PXK-202611-001', zone: 'Nhà màng A'),
        ),
        StockOutDoc.fromJson(
          _so(
            '2',
            'Pending',
            code: 'PXK-202611-002',
            notes: 'Lắp node cho HĐ SR-ABC',
          ),
        ),
        StockOutDoc.fromJson(
          _so('3', 'Approved', code: 'PXK-202611-003', zone: 'Nhà màng B'),
        ),
      ];
      expect(filterStockOuts(all).length, 3);
      expect(
        filterStockOuts(all, status: StockOutStatus.pending).single.id,
        '2',
      );
      expect(filterStockOuts(all, query: 'pxk-202611-003').single.id, '3');
      expect(filterStockOuts(all, query: 'nhà màng').length, 2);
      expect(filterStockOuts(all, query: 'sr-abc').single.id, '2');
      expect(
        filterStockOuts(all, query: 'sr-abc', status: StockOutStatus.draft),
        isEmpty,
      );
    },
  );

  test('tồn kho sau xuất; số lượng/ngày hiển thị', () {
    expect(stockAfterIssue(5, 2), 3);
    expect(stockAfterIssue(1, 4), -3);
    expect(fmtQty(3), '3');
    expect(fmtQty(2.5), '2.5');
    expect(fmtDateTime(DateTime(2026, 11, 5, 9, 7)), '05/11/2026 09:07');
    expect(fmtDateTime(null), '');
  });
}

void _warehouseChoicesTests() {
  Map<String, dynamic> h(
    String id,
    String name, {
    String category = 'Sensor',
    num qty = 1,
    String status = 'InWarehouse',
    String? tech,
  }) => {
    'id': id,
    'name': name,
    'category': category,
    'quantityInStock': qty,
    'status': status,
    'assignedTechnicianId': tech,
  };
  test('ô chọn thiết bị xuất kho: chỉ hàng kho chính, xếp theo tên', () {
    final list = warehouseChoices([
      h('b', 'Bơm', qty: 3),
      h('a', 'Cảm biến', qty: 2),
      h('t', 'Của KTV', status: 'InTechnicianStock', tech: 'x'),
      h('f', 'Lỗi', status: 'Faulty'),
      h('d', 'Đã triển khai', status: 'Deployed'),
      h('e', 'Hết', qty: 0),
    ]);
    expect(list.map((e) => e['id']), ['b', 'a']);
  });

  test('dòng kho chính mang người giữ thừa (dữ liệu cũ) vẫn xuất được', () {
    final legacy = h('l', 'Hàng cũ', qty: 49, status: 'InStock', tech: 'old');
    expect(isWarehouseIssuable(legacy), isTrue);
    expect(warehouseChoices([legacy]), hasLength(1));
  });

  test('hàng theo serial chỉ xuất được khi tồn đúng 1', () {
    Map<String, dynamic> withSerial(Map<String, dynamic> m) => {
      ...m,
      'serialNumber': 'SN-1',
    };
    expect(
      isSerialTracked(withSerial(h('n', 'Node', category: 'Node cảm biến'))),
      isTrue,
    );
    expect(isSerialTracked(h('s', 'SHT')), isFalse);
    // Gateway/Node KHÔNG có serial = hàng tồn kho theo số lượng
    expect(
      isSerialTracked(h('g', 'Gateway', category: 'GATEWAY', qty: 49)),
      isFalse,
    );
    expect(
      isIssuableAsIs(h('g', 'Gateway', category: 'GATEWAY', qty: 49)),
      isTrue,
    );
    expect(
      isIssuableAsIs(withSerial(h('n1', 'Node', category: 'Node', qty: 1))),
      isTrue,
    );
    expect(
      isIssuableAsIs(withSerial(h('n5', 'Node', category: 'Node', qty: 5))),
      isFalse,
    );
    expect(isIssuableAsIs(h('s5', 'SHT', qty: 5)), isTrue);
  });
}
