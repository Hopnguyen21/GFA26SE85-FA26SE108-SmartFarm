import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/contracts/zone_contract_forms.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _contract({
  int days = 200,
  String status = 'Active',
  bool withExtras = true,
}) => {
  'id': 'c1',
  'tenantId': 't1',
  'farmId': 'f1',
  'farmName': 'Trại A',
  'zoneId': 'z1',
  'zoneName': 'Zone 1',
  'contractNumber': 'HD-SR-ABCD1234',
  'cropType': 'Cà chua',
  'monthlyRentVnd': 1000000,
  'depositVnd': 3000000,
  'totalContractValueVnd': 12000000,
  'startDate': '2026-11-01',
  'endDate': '2027-11-01',
  'status': status,
  'statusText': days < 0 ? 'Đã hết hạn' : 'Đang hiệu lực',
  'daysRemaining': days,
  'lesseeName': 'Lê Văn An',
  'signedAtUtc': '2026-11-01T03:00:00Z',
  if (withExtras) ...{
    'contractPackageName': 'Gói Premium',
    'isCustomPackage': true,
    'parentContractNumber': 'HD-OLD-1',
    'specialTerms': 'Bảo hành 24 tháng.',
    'equipment': [
      {
        'code': 'GW-1',
        'name': 'Gateway ESP32',
        'category': 'GATEWAY',
        'unit': 'cái',
        'quantity': 1,
        'unitPrice': 2000000,
      },
      {
        'code': 'SN-1',
        'name': 'Cảm biến đất',
        'category': 'SENSOR_NODE',
        'unit': 'cái',
        'quantity': 3,
        'unitPrice': 500000,
      },
    ],
    'renewals': [
      {
        'id': 'r1',
        'newEndDate': '2028-11-01',
        'renewalValueVnd': 5000000,
        'notes': 'Gia hạn 1 năm',
        'createdAtUtc': '2027-10-01T00:00:00Z',
      },
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var body = _contract();

  Future<http.Response> handler(http.Request r) async {
    if (r.url.path == '/api/v1/zone-contracts/c1') return _json(body);
    return http.Response('', 404);
  }

  setUpAll(() async {
    await initializeDateFormatting('vi_VN');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'o@b.c',
      role: 'FarmOwner',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZoneContractDetailScreen(
            contract: ZoneContractModel.fromJson(body),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  testWidgets(
    'hiển thị đủ các khối như web: banner, vị trí, khách hàng, tiền, thiết bị, điều khoản, gia hạn',
    (tester) async {
      body = _contract();
      await pump(tester);
      expect(find.text('Chi tiết hợp đồng #HD-SR-ABCD1234'), findsOneWidget);
      expect(find.textContaining('còn 200 ngày'), findsOneWidget);
      expect(find.text('Thông tin Vị trí & Cây trồng'), findsOneWidget);
      expect(
        find.textContaining('Gói Premium · Riêng khách hàng'),
        findsOneWidget,
      );
      expect(find.text('HD-OLD-1'), findsOneWidget);
      expect(find.text('Lê Văn An'), findsOneWidget);
      expect(find.textContaining('4. Tạm ứng 30% khi ký'), findsOneWidget);
      expect(
        find.textContaining('5. Còn lại khi nghiệm thu (70%)'),
        findsOneWidget,
      );
      expect(find.textContaining('2 loại · tổng 4 thiết bị'), findsOneWidget);
      expect(find.text('Gateway'), findsOneWidget);
      expect(find.text('Cảm biến'), findsOneWidget);
      expect(find.text('3 cái'), findsOneWidget);
      expect(find.text('Bảo hành 24 tháng.'), findsOneWidget);
      expect(
        find.textContaining('Lịch sử các lần gia hạn (1)'),
        findsOneWidget,
      );
      expect(find.text('Gia hạn 1 năm'), findsOneWidget);
    },
  );

  testWidgets('sắp hết hạn / đã hết hạn: banner cảnh báo theo số ngày', (
    tester,
  ) async {
    body = _contract(days: 10);
    await pump(tester);
    expect(find.textContaining('sắp hết hạn trong 10 ngày'), findsOneWidget);
    body = _contract(days: -3, status: 'Expired');
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(find.textContaining('đã hết hạn hiệu lực'), findsOneWidget);
  });

  testWidgets(
    'hợp đồng không có thiết bị/gia hạn: báo trống, không bịa dữ liệu',
    (tester) async {
      body = _contract(withExtras: false);
      await pump(tester);
      expect(
        find.text('Hợp đồng này chưa ghi nhận danh mục thiết bị.'),
        findsOneWidget,
      );
      expect(
        find.text('Chưa có lần gia hạn nào cho hợp đồng này.'),
        findsOneWidget,
      );
      expect(find.textContaining('Gói hợp đồng'), findsNothing);
    },
  );
}
