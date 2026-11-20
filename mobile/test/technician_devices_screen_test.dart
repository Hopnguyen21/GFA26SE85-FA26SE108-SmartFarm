import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/devices/technician_devices_screen.dart';
import 'package:smartfarm_mobile/features/inventory/stock_out_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// Client giả được giữ toàn cục cho cả file sau lần dựng đầu nên các test dùng chung một handler thay được.
Future<http.Response> Function(http.Request)? _custom;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'jwt_token': 'fake-token'});
  });

  testWidgets(
    'TechnicianDevicesScreen chỉ còn 2 tab: Gateway ESP32 và Kho & Xuất kho',
    (tester) async {
      _custom = null;
      final client = MockClient((r) async {
        if (_custom != null) return _custom!(r);
        return _json([]);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => FarmProvider(),
            child: const MaterialApp(home: TechnicianDevicesScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Gateway ESP32'), findsOneWidget);
        expect(find.text('Kho & Xuất kho'), findsOneWidget);
        expect(find.text('Chuẩn bị phần cứng'), findsNothing);
        expect(find.text('Chẩn đoán Node'), findsNothing);
        expect(find.text('Quản Lý Thiết Bị & Phần Cứng'), findsOneWidget);

        await tester.tap(find.text('Kho & Xuất kho'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }, () => client);
    },
  );

  testWidgets(
    'Kho KTV: hiện hàng đang giữ; nhận thêm = lập phiếu xuất kho (không gọi API gán trực tiếp); trả kho gọi return',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <http.Request>[];
      _custom = (r) async {
        calls.add(r);
        final p = r.url.path;
        if (r.method == 'GET' && p.endsWith('/spare-parts')) {
          return _json([
            {
              'id': 'p1',
              'code': 'SHT30',
              'name': 'Cảm biến SHT30',
              'category': 'Sensor',
              'quantityInStock': 3,
              'status': 'InTechnicianStock',
            },
            {
              'id': 'p2',
              'code': 'NODE-1',
              'name': 'Node cảm biến',
              'category': 'Node cảm biến',
              'serialNumber': 'SN-1',
              'quantityInStock': 1,
              'status': 'InTechnicianStock',
            },
          ]);
        }
        if (r.method == 'POST' && p.endsWith('/hardware-items/p1/return')) {
          return _json({'id': 'p1'});
        }
        return _json([]);
      };
      final client = MockClient((r) async => _custom!(r));
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => FarmProvider(),
            child: const MaterialApp(home: TechnicianDevicesScreen()),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Kho & Xuất kho'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Cảm biến SHT30'), findsOneWidget);
        expect(find.text('x3'), findsOneWidget);
        // thẻ thống kê + bộ lọc theo loại + tìm kiếm
        expect(find.byKey(const ValueKey('stock-kpis')), findsOneWidget);
        expect(find.text('4'), findsWidgets); // tổng số thiết bị = 3 + 1
        await tester.tap(find.byKey(const ValueKey('stock-cat-node')));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Node cảm biến'), findsOneWidget);
        expect(find.text('Cảm biến SHT30'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-cat-all')));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(
          find.byKey(const ValueKey('stock-search')),
          'sn-1',
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Node cảm biến'), findsOneWidget);
        expect(find.text('Cảm biến SHT30'), findsNothing);
        await tester.enterText(find.byKey(const ValueKey('stock-search')), '');
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Nhận từ kho chính'), findsOneWidget);

        // trả kho: xác nhận → POST /return
        await tester.tap(find.text('Trả kho').first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Xác nhận'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          calls.where(
            (c) =>
                c.method == 'POST' &&
                c.url.path.endsWith('/hardware-items/p1/return'),
          ),
          hasLength(1),
        );

        // nhận thêm: mở màn lập phiếu xuất kho, KHÔNG gọi /assign (chỉ Admin được gán trực tiếp)
        await tester.tap(find.text('Nhận từ kho chính'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(StockOutScreen), findsOneWidget);
        expect(calls.any((c) => c.url.path.endsWith('/assign')), isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }, () => client);
    },
  );
}
