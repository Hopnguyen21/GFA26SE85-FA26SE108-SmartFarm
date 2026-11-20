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
import 'package:smartfarm_mobile/features/bills/bills_screen.dart';

http.Response _json(Object b, [int c = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(b)),
  c,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _bill(
  String id,
  String code,
  String status, {
  double amount = 10000000,
  double paid = 0,
}) => {
  'id': id,
  'billCode': code,
  'contractId': 'c1',
  'contractNumber': 'HD-001',
  'lesseeName': 'Nguyễn Văn An',
  'amount': amount,
  'paidAmount': paid,
  'remainingAmount': amount - paid,
  'status': status,
  'issueDate': '2026-11-01',
  'dueDate': '2026-12-01',
  'createdByName': 'KTV',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];
  var bills = <Map<String, dynamic>>[];

  Future<http.Response> handler(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (p == '/api/v1/bills' && r.method == 'GET') return _json(bills);
    if (p == '/api/v1/zone-contracts') {
      return _json([
        {
          'id': 'c1',
          'contractNumber': 'HD-001',
          'lesseeName': 'Nguyễn Văn An',
          'totalContractValueVnd': 10000000,
        },
      ]);
    }
    if (p.endsWith('/payments')) {
      return _json(_bill('b1', 'HDN-001', 'PartiallyPaid', paid: 4000000));
    }
    if (p.endsWith('/status')) {
      return _json(_bill('b1', 'HDN-001', 'Cancelled'));
    }
    return http.Response('[]', 200);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'PlatformTechnician',
    );
    await http.runWithClient(
      () => BillApi.getBills(),
      () => MockClient(handler),
    );
  });

  setUp(() {
    calls.clear();
    bills = [
      _bill('b1', 'HDN-001', 'Issued'),
      _bill('b2', 'HDN-002', 'Paid', paid: 10000000),
      _bill('b3', 'HDN-003', 'Draft'),
    ];
  });

  Future<FarmProvider> open(WidgetTester t, String role) async {
    t.view.physicalSize = const Size(500, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final p = FarmProvider()..switchRole(role);
    await t.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: p,
        child: const MaterialApp(home: BillsScreen()),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    return p;
  }

  testWidgets(
    'Owner chỉ xem: có danh sách, tổng hợp, không có nút tạo/thu tiền',
    (t) async {
      await http.runWithClient(() async {
        final p = await open(t, 'OWNER');
        expect(find.text('Giao dịch & Hóa đơn'), findsOneWidget);
        expect(find.text('HDN-001'), findsOneWidget);
        expect(find.text('Chờ thanh toán'), findsWidgets);
        expect(find.text('Đã thanh toán'), findsWidgets);
        expect(find.text('Thu tiền'), findsNothing);
        expect(find.text('Tạo hóa đơn từ hợp đồng'), findsNothing);
        // Bộ lọc trạng thái.
        final chip = find.widgetWithText(ChoiceChip, 'Đã thanh toán');
        await t.ensureVisible(chip);
        await t.tap(chip);
        await t.pump();
        expect(find.text('HDN-002'), findsOneWidget);
        expect(find.text('HDN-001'), findsNothing);
        // Chi tiết không có thao tác quản lý.
        await t.tap(find.text('HDN-002'));
        await t.pumpAndSettle();
        expect(find.text('Hóa đơn HDN-002'), findsOneWidget);
        expect(find.text('Hủy hóa đơn'), findsNothing);
        expect(find.text('Xóa'), findsNothing);
        await t.pumpWidget(const SizedBox());
        p.dispose();
      }, () => MockClient(handler));
    },
  );

  testWidgets(
    'Kỹ thuật viên: thu tiền gửi đúng số tiền; không thu quá số còn lại',
    (t) async {
      await http.runWithClient(() async {
        final p = await open(t, 'TECHNICIAN');
        expect(find.text('Hóa đơn & Thu phí'), findsOneWidget);
        expect(find.text('Tạo hóa đơn từ hợp đồng'), findsOneWidget);
        await t.tap(find.text('Thu tiền').first);
        await t.pumpAndSettle();
        // Thu quá số còn lại (10.000.000) bị chặn, chưa gửi gì.
        await t.enterText(
          find.widgetWithText(TextField, 'Số tiền thu (đ) *'),
          '20.000.000',
        );
        await t.tap(find.text('Ghi nhận thanh toán'));
        await t.pumpAndSettle();
        expect(find.textContaining('Không thu quá số còn lại'), findsOneWidget);
        expect(calls.where((c) => c.method == 'POST'), isEmpty);
        // Thu 4.000.000.
        await t.enterText(
          find.widgetWithText(TextField, 'Số tiền thu (đ) *'),
          '4.000.000',
        );
        await t.tap(find.text('Ghi nhận thanh toán'));
        await t.pumpAndSettle();
        final post = calls.firstWhere((c) => c.method == 'POST');
        expect(post.url.path, '/api/v1/bills/b1/payments');
        expect((jsonDecode(post.body) as Map)['paymentAmount'], 4000000);
        await t.pumpWidget(const SizedBox());
        p.dispose();
      }, () => MockClient(handler));
    },
  );

  testWidgets(
    'Kỹ thuật viên: hủy hóa đơn gửi PUT status Cancelled; nháp mới có nút Xóa',
    (t) async {
      await http.runWithClient(() async {
        final p = await open(t, 'TECHNICIAN');
        await t.tap(find.text('HDN-001'));
        await t.pumpAndSettle();
        expect(find.text('Xóa'), findsNothing); // Đã phát hành: không xóa được
        await t.tap(find.text('Hủy hóa đơn'));
        await t.pumpAndSettle();
        await t.tap(find.widgetWithText(FilledButton, 'Hủy hóa đơn'));
        await t.pumpAndSettle();
        final put = calls.firstWhere((c) => c.method == 'PUT');
        expect(put.url.path, '/api/v1/bills/b1/status');
        expect((jsonDecode(put.body) as Map)['status'], 'Cancelled');

        await t.tap(find.text('HDN-003'));
        await t.pumpAndSettle();
        expect(find.text('Xóa'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        p.dispose();
      }, () => MockClient(handler));
    },
  );
}
