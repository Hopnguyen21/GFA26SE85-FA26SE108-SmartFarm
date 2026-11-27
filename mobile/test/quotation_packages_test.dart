import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/quotation_editor.dart';

const _pkgA = '11111111-aaaa-bbbb-cccc-000000000001';
const _pkgB = '22222222-aaaa-bbbb-cccc-000000000002';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

List<Map<String, dynamic>> _packages = [];

QuotationItem _hw(String code, int qty, double price) => QuotationItem(
  code: code,
  name: 'Thiết bị $code',
  category: 'HARDWARE',
  unit: 'Cái',
  quantity: qty,
  unitPrice: price,
  vatPercent: 8,
  totalAmount: qty * price * 1.08,
);

class _Out {
  QuotationDraft? draft;
}

Future<_Out> _open(WidgetTester t, {Quotation? initial}) async {
  await t.binding.setSurfaceSize(const Size(1400, 9000));
  addTearDown(() => t.binding.setSurfaceSize(null));
  final out = _Out();
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              out.draft = await Navigator.push<QuotationDraft>(
                context,
                MaterialPageRoute(
                  builder: (_) => QuotationEditor(
                    initial: initial,
                    estimateItems: initial == null
                        ? [_hw('GW', 1, 1000000)]
                        : null,
                    contractTitle: 'HĐ',
                    autoFillFromEstimate: true,
                  ),
                ),
              );
            },
            child: const Text('mở'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('mở'));
  await t.pumpAndSettle();
  return out;
}

void main() {
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
      () => SupportApi.getContractPackages().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient((r) async {
        if (r.url.path.endsWith('/contract-packages')) return _json(_packages);
        return http.Response('{}', 404);
      }),
    );
  });

  setUp(() {
    _packages = [
      {
        'id': _pkgA,
        'packageName': 'Gói bảo trì 12 tháng',
        'description': 'Kiểm tra định kỳ',
        'durationMonths': 12,
        'maxZones': 3,
        'price': 5000000,
        'status': 'Active',
      },
      {
        'id': _pkgB,
        'packageName': 'Gói giám sát 6 tháng',
        'durationMonths': 6,
        'maxZones': 1,
        'price': 2000000,
        'status': 'Active',
      },
    ];
  });

  testWidgets('tích gói: cộng tiền gói + VAT vào tổng, bỏ tích thì trừ ra', (
    t,
  ) async {
    await _open(t);
    await t.tap(find.text('Gói dịch vụ đi kèm'));
    await t.pumpAndSettle();
    expect(find.text('Gói bảo trì 12 tháng'), findsOneWidget);
    // thiết bị 1.000.000 + VAT 8% = 1.080.000
    expect(find.text('1.080.000 đ'), findsWidgets);

    await t.tap(find.byKey(const ValueKey('pkg-$_pkgA')));
    await t.pumpAndSettle();
    // + 5.000.000 (VAT 8%) → 6.000.000 chưa thuế, 6.480.000 tổng
    expect(find.text('6.480.000 đ'), findsWidgets);
    expect(find.textContaining('trong đó gói dịch vụ (1 gói)'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('pkg-$_pkgB')));
    await t.pumpAndSettle();
    expect(find.text('8.640.000 đ'), findsWidgets); // (1+5+2)tr * 1.08
    expect(find.textContaining('trong đó gói dịch vụ (2 gói)'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('pkg-$_pkgA'))); // bỏ tích
    await t.pumpAndSettle();
    expect(find.text('3.240.000 đ'), findsWidgets); // (1+2)tr * 1.08
    expect(find.textContaining('trong đó gói dịch vụ (1 gói)'), findsOneWidget);
  });

  testWidgets('gói đã tích đi vào bản nháp gửi hợp đồng như một dòng "Gói"', (
    t,
  ) async {
    final out = await _open(t);
    await t.tap(find.text('Gói dịch vụ đi kèm'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pkg-$_pkgA')));
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(
        TextFormField,
        'Ghi chú điều khoản & phạm vi lắp đặt *',
      ),
      'Điều khoản',
    );
    await t.tap(find.text('Xác nhận & gửi hợp đồng cho khách'));
    await t.pumpAndSettle();
    final items = out.draft!.items;
    expect(items.length, 2);
    final pkg = items.singleWhere((i) => i['category'] == 'SERVICE_PACKAGE');
    expect(pkg['code'], 'PKG-11111111AAAABBBBCCCC000000000001');
    expect(pkg['name'], 'Gói bảo trì 12 tháng');
    expect(pkg['unit'], 'Gói');
    expect(pkg['quantity'], 1);
    expect(pkg['unitPrice'], 5000000);
    expect(pkg['vatPercent'], 8);
  });

  testWidgets(
    'mở lại hợp đồng đã lưu: gói đã chọn hiện đã tích; gói chưa chọn chưa tích',
    (t) async {
      final q = Quotation.fromJson({
        'id': 'q',
        'serviceRequestId': 's',
        'vatPercent': 8,
        'subtotal': 6000000,
        'vatAmount': 480000,
        'totalAmount': 6480000,
        'deposit30Percent': 1944000,
        'remaining70Percent': 4536000,
        'status': 'Draft',
        'items': [
          {
            'code': 'GW',
            'name': 'Gateway',
            'category': 'GATEWAY',
            'unit': 'Trạm',
            'quantity': 1,
            'unitPrice': 1000000,
            'vatPercent': 8,
            'totalAmount': 1080000,
          },
          {
            'code': 'PKG-11111111AAAABBBBCCCC000000000001',
            'name': 'Gói bảo trì 12 tháng',
            'category': 'SERVICE_PACKAGE',
            'unit': 'Gói',
            'quantity': 1,
            'unitPrice': 5000000,
            'vatPercent': 8,
            'totalAmount': 5400000,
          },
        ],
      });
      await _open(t, initial: q);
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const ValueKey('pkg-$_pkgA')))
            .value,
        isTrue,
      );
      expect(
        t
            .widget<CheckboxListTile>(find.byKey(const ValueKey('pkg-$_pkgB')))
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'các gói có mã chung tiền tố (như dữ liệu thật a0000001-...): tích một gói không tích các gói khác',
    (t) async {
      _packages = [
        for (var i = 1; i <= 3; i++)
          {
            'id': 'a0000001-0000-0000-0000-00000000000$i',
            'packageName': 'Gói số $i',
            'durationMonths': 6,
            'maxZones': 1,
            'price': 1000000 * i,
            'status': 'Active',
          },
      ];
      await _open(t);
      await t.tap(find.text('Gói dịch vụ đi kèm'));
      await t.pumpAndSettle();
      bool ticked(int i) => t
          .widget<CheckboxListTile>(
            find.byKey(ValueKey('pkg-a0000001-0000-0000-0000-00000000000$i')),
          )
          .value!;
      await t.tap(
        find.byKey(const ValueKey('pkg-a0000001-0000-0000-0000-000000000002')),
      );
      await t.pumpAndSettle();
      expect([ticked(1), ticked(2), ticked(3)], [false, true, false]);
      expect(
        find.textContaining('trong đó gói dịch vụ (1 gói)'),
        findsOneWidget,
      );
    },
  );
}
