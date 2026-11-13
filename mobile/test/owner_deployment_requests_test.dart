import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/devices/deployment_screens.dart';

Map<String, dynamic> request(
  String id,
  String status, {
  bool context = true,
  bool estimate = true,
}) => {
  'requestId': id,
  'farmId': 'f',
  'zoneId': 'z',
  'status': status,
  'requiredParameters': ['Temperature', 'SoilMoisture'],
  'planItems': [],
  'surveys': [],
  'decisionHistory': [],
  if (context)
    'context': {
      'farmName': 'Nông trại CNC Lâm Đồng',
      'fieldName': 'Lô A1',
      'zoneName': 'Nhà màng 01',
      'zoneType': 'Greenhouse',
      'zoneAreaM2': 1458.0,
      'seasonName': 'Vụ 1',
      'seasonStatus': 'Planned',
      'seasonStartDate': '2026-11-01',
      'seasonExpectedEndDate': '2027-02-01',
    },
  if (estimate)
    'estimateItems': [
      {
        'estimateItemId': 'e1',
        'code': 'GW',
        'name': 'Gateway',
        'role': 'Gateway',
        'quantity': 1,
        'unitPrice': 3800000,
        'lineTotal': 3800000,
      },
      {
        'estimateItemId': 'e2',
        'code': 'INSTALLATION',
        'name': 'Thi công',
        'role': 'Installation',
        'quantity': 1,
        'unitPrice': 500000,
        'lineTotal': 500000,
      },
    ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<http.Response> Function(http.Request) handler = (r) async =>
      http.Response('[]', 200);
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient((r) => handler(r)),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OwnerDeploymentRequestsScreen()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets(
    'hiện từng yêu cầu theo Zone · farm, tổng dự toán và trạng thái; KHÔNG có ô chọn Zone hay nút tạo nháp',
    (tester) async {
      handler = (r) async => http.Response(
        jsonEncode([
          request('4fd9ce0e-0000-0000-0000-000000000001', 'Submitted'),
          request(
            'aaaa1111-0000-0000-0000-000000000002',
            'Accepted',
            estimate: false,
          ),
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      await pump(tester);
      expect(
        find.text('Nhà màng 01 · Nông trại CNC Lâm Đồng'),
        findsNWidgets(2),
      );
      expect(find.textContaining('dự toán ~4.300.000 đ'), findsOneWidget);
      expect(find.textContaining('Cần đo 2 thông số'), findsNWidgets(2));
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.textContaining('Chọn Zone'), findsNothing);
      expect(find.textContaining('Tạo bản nháp'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chưa có yêu cầu: hướng dẫn gửi từ chính Zone (không bắt chọn Zone lại)',
    (tester) async {
      handler = (r) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
      await pump(tester);
      expect(find.text('Chưa có yêu cầu triển khai nào.'), findsOneWidget);
      expect(find.textContaining('mở Zone cần lắp thiết bị'), findsOneWidget);
    },
  );

  testWidgets(
    'lỗi tải: báo rõ và cho thử lại, không hiện thành "chưa có yêu cầu"',
    (tester) async {
      handler = (r) async => http.Response(
        jsonEncode({'title': 'Forbidden'}),
        403,
        headers: {'content-type': 'application/json'},
      );
      await pump(tester);
      expect(
        find.textContaining('Không tải được danh sách yêu cầu'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Chưa có yêu cầu triển khai nào.'), findsNothing);
    },
  );
}
