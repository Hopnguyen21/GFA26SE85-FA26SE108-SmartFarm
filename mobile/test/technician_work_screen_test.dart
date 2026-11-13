import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/technician_work_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];

  Future<http.Response> handler(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (p == '/api/v1/service-requests') {
      return _json([
        {
          'id': 's1',
          'failureCode': 'SENSOR_OFFLINE',
          'status': 'Assigned',
          'description': 'Cảm biến mất tín hiệu.',
          'zoneId': 'z1',
          'history': <Object>[],
        },
        {
          'id': 's2',
          'failureCode': 'NEW_INSTALL',
          'status': 'InProgress',
          'description': 'Lắp đặt IoT cho Zone 2.',
          'farmId': 'f1',
          'zoneId': 'z1',
          'deploymentRequestId': 'dep-cccc-3333',
          'history': <Object>[],
        },
      ]);
    }
    if (p == '/api/v1/service-requests/s2/quotation') {
      return _json({
        'id': 'q',
        'status': 'SentToOwner',
        'totalAmount': 10,
        'deposit30Percent': 3,
        'remaining70Percent': 7,
        'items': <Object>[],
      });
    }
    if (p == '/api/v1/platform/deployment-requests/dep-cccc-3333') {
      return _json({
        'requestId': 'dep-cccc-3333',
        'farmId': 'f1',
        'zoneId': 'z1',
        'status': 'Surveyed',
        'requiredParameters': <Object>[],
        'planItems': <Object>[],
        'surveys': <Object>[],
        'decisionHistory': <Object>[],
      });
    }
    if (p == '/api/v1/platform/deployment-requests') {
      return _json([
        {
          'requestId': 'dep-aaaa-1111',
          'farmId': 'f1',
          'zoneId': 'z1',
          'status': 'Accepted',
          'requiredParameters': ['Temperature'],
          'planItems': [],
          'surveys': [],
          'decisionHistory': [],
        },
        {
          'requestId':
              'dep-cccc-3333', // đã có phiếu s2: không lặp thành thẻ thứ hai
          'farmId': 'f1',
          'zoneId': 'z1',
          'status': 'Surveyed',
          'requiredParameters': ['Temperature'],
          'planItems': [],
          'surveys': [],
          'decisionHistory': [],
        },
        {
          'requestId': 'dep-bbbb-2222',
          'farmId': 'f1',
          'zoneId': 'z1',
          'status': 'Cancelled',
          'requiredParameters': ['Temperature'],
          'planItems': [],
          'surveys': [],
          'decisionHistory': [],
        },
      ]);
    }
    return _json([]);
  }

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
      () => MockClient(handler),
    );
  });

  setUp(calls.clear);

  testWidgets(
    'tab Công việc: một danh sách, mỗi yêu cầu một thẻ; đợt đã có phiếu không lặp; việc tiếp theo theo tiến độ',
    (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: TechnicianWorkScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Công việc'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Phiếu dịch vụ'), findsNothing);
      // Thẻ phiếu bảo trì và phiếu lắp đặt.
      expect(find.text('SENSOR_OFFLINE'), findsOneWidget);
      expect(find.text('Lắp đặt IoT cho Zone 2'), findsOneWidget);
      // Phiếu lắp đặt đã gửi hợp đồng: việc tiếp theo là chờ Owner cọc.
      expect(
        find.text('Việc tiếp theo: Chờ Owner thanh toán cọc 30%'),
        findsOneWidget,
      );
      // Chỉ việc admin đã giao (phiếu dịch vụ của chính KTV): hàng đợi triển khai chưa ai được giao KHÔNG hiện,
      // và app không gọi danh sách triển khai chung.
      expect(
        find.text('Yêu cầu triển khai chưa có phiếu dịch vụ'),
        findsNothing,
      );
      expect(find.text('Khảo sát địa điểm'), findsNothing);
      expect(find.textContaining('Yêu cầu dep-'), findsNothing);
      expect(
        calls.any((c) => c.url.path == '/api/v1/platform/deployment-requests'),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
