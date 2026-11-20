import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/inventory/stock_out_screen.dart';

http.Response _json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _so(
  String id,
  String code,
  String status, {
  String? zone,
  String? notes,
  String? requestId,
}) => {
  'id': id,
  'stockOutCode': code,
  'status': status,
  'zoneId': zone == null ? null : 'z1',
  'zoneName': zone,
  'notes': notes,
  'serviceRequestId': requestId,
  'createdByName': 'KTV Demo',
  'createdAtUtc': '2026-11-15T14:49:00Z',
  'details': [
    {
      'itemName': '[GW-1] Gateway LoRa',
      'unit': 'Cái',
      'quantity': 1,
      'currentStock': 9,
    },
    {
      'itemName': '[SN-1] Node cảm biến',
      'unit': 'Cái',
      'quantity': 3,
      'currentStock': 4,
    },
  ],
};

FarmProvider? _provider;
final _calls = <http.Request>[];
late List<Map<String, dynamic>> _docs;

http.Response _route(http.Request r) {
  _calls.add(r);
  final p = r.url.path;
  if (p == '/api/v1/farms') {
    return _json([
      {
        'farmId': 'f1',
        'name': 'Trang trại Đà Lạt',
        'locationText': 'Lâm Đồng',
        'totalAreaM2': 1000,
        'latitude': 11.9,
        'longitude': 108.4,
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/fields') {
    return _json([
      {'fieldId': 'fl1', 'farmId': 'f1', 'name': 'Lô A', 'areaM2': 500},
    ]);
  }
  if (p == '/api/v1/fields/fl1/zones') {
    return _json([
      {
        'zoneId': 'z1',
        'farmId': 'f1',
        'fieldId': 'fl1',
        'name': 'Nhà màng 01',
        'areaM2': 300,
      },
    ]);
  }
  if (p == '/api/v1/service-requests') {
    return _json([
      {
        'id': 'sr-0001-aaaa',
        'farmId': 'f1',
        'zoneId': 'z1',
        'failureCode': 'INSTALLATION',
        'description': 'Lắp đặt IoT cho Zone Demo. Chi tiết.',
        'status': 'Assigned',
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/stock-outs') {
    if (r.method == 'POST') return _json(_so('new', 'PXK-NEW', 'Draft'), 201);
    return _json(_docs);
  }
  if (p.startsWith('/api/v1/farms/f1/stock-outs/') && r.method == 'PUT') {
    return _json(_so('x', 'PXK-X', 'Pending'));
  }
  if (p.startsWith('/api/v1/farms/f1/stock-outs/') && r.method == 'DELETE') {
    return http.Response('', 204);
  }
  if (p == '/api/v1/platform/hardware-items') {
    return _json([
      {
        'id': 'hw1',
        'code': 'SHT-1',
        'name': 'Cảm biến SHT30',
        'model': 'SHT30',
        'quantityInStock': 2,
        'category': 'Sensor',
        'status': 'InWarehouse',
      },
      // Không được hiện trong ô chọn: đã giao cho KTV, bị lỗi, hết hàng
      {
        'id': 'hw-tech',
        'code': 'TECH-1',
        'name': 'Hàng của KTV',
        'quantityInStock': 3,
        'category': 'Sensor',
        'status': 'InTechnicianStock',
        'assignedTechnicianId': 'tech-1',
      },
      {
        'id': 'hw-faulty',
        'code': 'BAD-1',
        'name': 'Hàng lỗi',
        'quantityInStock': 3,
        'category': 'Sensor',
        'status': 'Faulty',
      },
      {
        'id': 'hw-empty',
        'code': 'EMP-1',
        'name': 'Hàng hết',
        'quantityInStock': 0,
        'category': 'Sensor',
        'status': 'InWarehouse',
      },
      // Hàng theo serial: tồn 1 xuất được (số lượng cố định 1); tồn khác 1 bị khoá
      {
        'id': 'hw-node',
        'code': 'NODE-1',
        'name': 'Node cảm biến',
        'serialNumber': 'SN-N1',
        'quantityInStock': 1,
        'category': 'Node cảm biến',
        'status': 'InWarehouse',
      },
      {
        'id': 'hw-bignode',
        'code': 'NODE-2',
        'name': 'Node lô lớn',
        'serialNumber': 'SN-BIG',
        'quantityInStock': 5,
        'category': 'Node cảm biến',
        'status': 'InWarehouse',
      },
    ]);
  }
  return http.Response('', 404);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      () => MockClient((r) async => _route(r)),
    );
  });

  setUp(() {
    _calls.clear();
    _docs = [
      _so(
        'd1',
        'PXK-202611-001',
        'Draft',
        zone: 'Nhà màng 01',
        notes: 'Lắp node',
      ),
      _so('p1', 'PXK-202611-002', 'Pending', requestId: 'sr-0001-aaaa'),
      _so('a1', 'PXK-202611-003', 'Approved'),
    ];
  });

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(480, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final p = FarmProvider()..switchRole('TECHNICIAN');
    _provider = p;
    await t.runAsync(() => p.fetchFromApi());
    await t.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: p,
        child: const MaterialApp(home: StockOutScreen()),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> end(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    _provider?.dispose(); // huỷ các Timer đồng bộ của FarmProvider
    _provider = null;
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'danh sách như web: mã, Zone nhận, số loại/số cái, người lập, trạng thái',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        expect(find.text('PXK-202611-001'), findsOneWidget);
        expect(find.text('Nhà màng 01'), findsWidgets);
        expect(find.text('Toàn trang trại / Kỹ thuật viên'), findsWidgets);
        expect(find.text('2 loại thiết bị (4 cái)'), findsWidgets);
        expect(find.textContaining('Người lập: KTV Demo'), findsWidgets);
        expect(find.text('Bản nháp'), findsWidgets);
        expect(find.text('Chờ duyệt'), findsWidgets);
        await end(t);
      }, () => MockClient((r) async => _route(r)));
    },
  );

  testWidgets('lọc theo trạng thái và tìm theo mã', (t) async {
    await http.runWithClient(() async {
      await open(t);
      await t.tap(find.widgetWithText(ChoiceChip, 'Chờ duyệt'));
      await t.pump();
      expect(find.text('PXK-202611-002'), findsOneWidget);
      expect(find.text('PXK-202611-001'), findsNothing);
      await t.tap(find.widgetWithText(ChoiceChip, 'Tất cả'));
      await t.pump();
      await t.enterText(find.byType(TextField).first, '003');
      await t.pump();
      expect(find.text('PXK-202611-003'), findsOneWidget);
      expect(find.text('PXK-202611-001'), findsNothing);
      await end(t);
    }, () => MockClient((r) async => _route(r)));
  });

  testWidgets('chi tiết phiếu nháp: Gửi duyệt (PUT Pending) và có Xóa phiếu', (
    t,
  ) async {
    await http.runWithClient(() async {
      await open(t);
      await t.tap(find.text('PXK-202611-001'));
      await t.pumpAndSettle();
      expect(find.text('Gửi duyệt'), findsOneWidget);
      expect(find.text('Xóa phiếu'), findsOneWidget);
      expect(find.textContaining('Tồn kho hiện tại: 9'), findsOneWidget);
      await t.tap(find.text('Gửi duyệt'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đồng ý'));
      await t.pumpAndSettle();
      final put = _calls.where(
        (c) => c.method == 'PUT' && c.url.path.endsWith('/status'),
      );
      expect(put, hasLength(1));
      expect(jsonDecode(put.first.body)['status'], 'Pending');
      await end(t);
    }, () => MockClient((r) async => _route(r)));
  });

  testWidgets(
    'chờ duyệt: chỉ được Hủy, không gửi/xóa; đã duyệt: không thao tác (Admin xử lý trên web)',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        await t.tap(find.text('PXK-202611-002'));
        await t.pumpAndSettle();
        expect(find.text('Từ chối / Hủy'), findsOneWidget);
        expect(find.text('Gửi duyệt'), findsNothing);
        expect(find.text('Xóa phiếu'), findsNothing);
        expect(find.textContaining('chờ Admin duyệt'), findsOneWidget);
        await t.pageBack();
        await t.pumpAndSettle();

        await t.tap(find.text('PXK-202611-003'));
        await t.pumpAndSettle();
        expect(find.text('Từ chối / Hủy'), findsNothing);
        expect(find.text('Gửi duyệt'), findsNothing);
        expect(find.text('Xóa phiếu'), findsNothing);
        expect(find.text('Duyệt'), findsNothing);
        expect(find.text('Hoàn thành'), findsNothing);
        await end(t);
      }, () => MockClient((r) async => _route(r)));
    },
  );

  testWidgets(
    'tạo phiếu: vượt tồn kho bị chặn, đủ tồn thì POST đúng nội dung',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        await t.tap(find.text('Tạo phiếu xuất kho'));
        await t.pumpAndSettle();
        // chưa chọn thiết bị
        await t.tap(find.widgetWithText(FilledButton, 'Tạo phiếu xuất kho'));
        await t.pumpAndSettle();
        expect(find.textContaining('ít nhất một vật tư'), findsOneWidget);

        await t.tap(find.text('Chọn thiết bị xuất kho'));
        await t.pumpAndSettle();
        await t.tap(find.textContaining('[SHT-1] Cảm biến SHT30').last);
        await t.pumpAndSettle();
        // tồn 2: tăng lên 3 → vượt tồn
        await t.tap(find.byIcon(Icons.add_circle_outline));
        await t.tap(find.byIcon(Icons.add_circle_outline));
        await t.pump();
        expect(find.textContaining('Vượt tồn kho 1'), findsOneWidget);
        await t.tap(find.widgetWithText(FilledButton, 'Tạo phiếu xuất kho'));
        await t.pumpAndSettle();
        expect(find.textContaining('Không đủ tồn kho'), findsOneWidget);
        expect(_calls.where((c) => c.method == 'POST'), isEmpty);

        // giảm về 2 → hợp lệ
        await t.tap(find.byIcon(Icons.remove_circle_outline));
        await t.pump();
        expect(find.textContaining('Tồn kho sau xuất: 0'), findsOneWidget);
        await t.tap(find.widgetWithText(FilledButton, 'Tạo phiếu xuất kho'));
        await t.pumpAndSettle();
        final post = _calls.where(
          (c) => c.method == 'POST' && c.url.path.endsWith('/stock-outs'),
        );
        expect(post, hasLength(1));
        final body = jsonDecode(post.first.body) as Map;
        expect((body['details'] as List).single['inventoryItemId'], 'hw1');
        expect((body['details'] as List).single['quantity'], 2);
        await end(t);
      }, () => MockClient((r) async => _route(r)));
    },
  );

  testWidgets(
    'ô chọn thiết bị: chỉ hàng ở kho chính; hàng theo serial cố định số lượng 1, tồn khác 1 bị khoá',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        await t.tap(find.text('Tạo phiếu xuất kho'));
        await t.pumpAndSettle();
        await t.tap(find.text('Chọn thiết bị xuất kho'));
        await t.pumpAndSettle();
        expect(find.textContaining('[SHT-1]'), findsWidgets);
        expect(find.textContaining('[NODE-1]'), findsWidgets);
        // hàng của KTV / lỗi / hết không có trong danh sách
        expect(find.textContaining('TECH-1'), findsNothing);
        expect(find.textContaining('BAD-1'), findsNothing);
        expect(find.textContaining('EMP-1'), findsNothing);
        // hàng serial tồn 5: hiện nhưng khoá, kèm lý do
        expect(find.textContaining('cần tách từng serial'), findsWidgets);
        await t.tap(find.textContaining('[NODE-1]').last);
        await t.pumpAndSettle();
        expect(
          find.textContaining('Số lượng: 1 (hàng theo serial)'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.add_circle_outline), findsNothing);
        await end(t);
      }, () => MockClient((r) async => _route(r)));
    },
  );

  testWidgets(
    'phiếu gắn yêu cầu: hiện "Thuộc yêu cầu" ở danh sách và nhắc Gắn Node ở chi tiết',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        expect(
          find.text('Thuộc yêu cầu: Lắp đặt IoT cho Zone Demo'),
          findsOneWidget,
        );
        await t.tap(find.text('PXK-202611-002'));
        await t.pumpAndSettle();
        expect(find.text('Thuộc yêu cầu'), findsOneWidget);
        expect(
          find.textContaining('nút "Gắn Node" của yêu cầu này mới mở'),
          findsOneWidget,
        );
        await end(t);
      }, () => MockClient((r) async => _route(r)));
    },
  );

  testWidgets(
    'tạo phiếu: không có ô chọn yêu cầu/Zone; phiếu gửi lên không kèm Zone hay yêu cầu',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        await t.tap(find.text('Tạo phiếu xuất kho'));
        await t.pumpAndSettle();
        expect(find.textContaining('Gắn với yêu cầu lắp đặt'), findsNothing);
        expect(find.textContaining('Zone nhận thiết bị'), findsNothing);
        await end(t);
      }, () => MockClient((r) async => _route(r)));
    },
  );
}
