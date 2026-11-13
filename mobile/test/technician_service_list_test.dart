import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart';

Map<String, dynamic> _sr(
  String id,
  String code,
  String status, {
  String desc = '',
  String zone = 'z1',
  Map<String, dynamic> extra = const {},
}) => {
  ...extra,
  'id': id,
  'failureCode': code,
  'status': status,
  'description': desc,
  'zoneId': zone,
  'history': [
    if (!extra.containsKey('history'))
      {'createdAtUtc': '2026-11-12T14:35:37Z', 'eventType': 'Created'},
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
      role: 'PlatformTechnician',
    );
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient((r) => handler(r)),
    );
  });

  http.Response json(Object o, [int code = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(o)),
    code,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  final sample = [
    _sr(
      'i1',
      'INSTALLATION',
      'InProgress',
      desc: 'Yêu cầu khảo sát và lắp đặt IoT cho Zone.',
      extra: {'deploymentRequestId': 'dep1', 'farmId': 'f1'},
    ),
    _sr(
      'm1',
      'SENSOR_OFFLINE',
      'Assigned',
      desc: 'Cảm biến độ ẩm mất tín hiệu.',
      zone: 'z2',
    ),
    _sr(
      'i2',
      'NEW_INSTALL',
      'Assigned',
      desc: 'Cần lắp trạm LoRa.',
      zone: 'z3',
    ),
    _sr('r1', 'GATEWAY_DOWN', 'Verified', desc: 'Đã thay gateway.', zone: 'z2'),
    _sr('c1', 'INSTALLATION', 'Closed', desc: 'Đã nghiệm thu.', zone: 'z4'),
  ];

  void route({Map<String, Object?>? quotation, int nodes = 3}) {
    handler = (r) async {
      final p = r.url.path;
      if (p == '/api/v1/service-requests') return json(sample);
      if (p.endsWith('/platform/deployment-requests/dep1')) {
        return json({
          'requestId': 'dep1',
          'farmId': 'f1',
          'zoneId': 'z1',
          'status': 'Installing',
          'requiredParameters': <Object>[],
          'planItems': <Object>[],
          'surveys': <Object>[],
          'decisionHistory': <Object>[],
        });
      }
      if (p.endsWith('/quotation')) {
        return quotation == null
            ? http.Response('', 404)
            : json({
                'id': 'q1',
                'status': quotation['status'],
                'totalAmount': 13500000,
                'items': <Object>[],
              });
      }
      if (p.endsWith('/devices/map-locations')) {
        return nodes < 0
            ? json({'message': 'lỗi'}, 500)
            : json([
                for (var i = 0; i < nodes; i++) {'deviceId': 'd$i'},
              ]);
      }
      return json(<Object>[]);
    };
  }

  Future<void> pumpList(
    WidgetTester tester, {
    double width = 390,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox()); // bỏ State cũ để tải lại dữ liệu
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TechnicianMaintenanceScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'danh sách gồm cả lắp đặt và bảo trì: đếm theo loại, đủ nhãn, mã lỗi chỉ hiện ở bảo trì',
    (tester) async {
      route(quotation: {'status': 'SignedByOwner'});
      await pumpList(tester);

      // Ô tóm tắt: 2 lắp đặt chưa đóng, 1 bảo trì, 1 sẵn sàng đóng, 1 đã đóng.
      for (final label in [
        'Lắp đặt mới',
        'Bảo trì / sửa chữa',
        'Sẵn sàng đóng',
        'Đã đóng',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('SENSOR_OFFLINE'), findsOneWidget);
      expect(find.text('GATEWAY_DOWN'), findsOneWidget);
      expect(
        find.text('INSTALLATION'),
        findsNothing,
        reason: 'yêu cầu lắp đặt không hiện mã thô',
      );
      expect(find.text('NEW_INSTALL'), findsNothing);
      expect(
        find.text('Yêu cầu khảo sát và lắp đặt IoT cho Zone'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('yêu cầu mới giao lên trước, yêu cầu đã đóng xuống cuối', (
    tester,
  ) async {
    route();
    await pumpList(tester);
    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(
      y('Cảm biến độ ẩm mất tín hiệu') <
          y('Yêu cầu khảo sát và lắp đặt IoT cho Zone'),
      isTrue,
      reason: 'Assigned trước InProgress',
    );
    expect(
      y('Yêu cầu khảo sát và lắp đặt IoT cho Zone') < y('Đã thay gateway'),
      isTrue,
    );
    expect(y('Đã thay gateway') < y('Đã nghiệm thu'), isTrue);
  });

  testWidgets(
    'yêu cầu lắp đặt: hiện giai đoạn hợp đồng và số node đã chấm; thiếu dữ liệu thì không điền số giả',
    (tester) async {
      route(quotation: {'status': 'SignedByOwner'}, nodes: 3);
      await pumpList(tester);
      expect(find.text('Đã thanh toán 30% cọc'), findsWidgets);
      expect(find.text('3 node đã chấm trên bản đồ'), findsWidgets);

      // Không tải được bản đồ: không hiện số node (web điền sẵn 4, mobile không).
      route(quotation: null, nodes: -1);
      await pumpList(tester);
      expect(find.textContaining('node đã chấm'), findsNothing);
      expect(find.text('Chưa tạo hợp đồng'), findsWidgets);
    },
  );

  testWidgets(
    'chạm ô "Sẵn sàng đóng" để lọc, "Bỏ lọc" để trở lại; tìm kiếm theo mô tả',
    (tester) async {
      route();
      await pumpList(tester);

      await tester.tap(find.text('Sẵn sàng đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Đã thay gateway'), findsOneWidget);
      expect(find.text('Cảm biến độ ẩm mất tín hiệu'), findsNothing);
      expect(find.textContaining('Hiển thị 1/5 yêu cầu'), findsOneWidget);

      await tester.tap(find.text('Bỏ lọc'));
      await tester.pumpAndSettle();
      expect(find.text('Cảm biến độ ẩm mất tín hiệu'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'lora');
      await tester.pumpAndSettle();
      expect(find.text('Cần lắp trạm LoRa'), findsOneWidget);
      expect(find.text('Cảm biến độ ẩm mất tín hiệu'), findsNothing);

      await tester.enterText(find.byType(TextField), 'không tồn tại');
      await tester.pumpAndSettle();
      expect(find.text('Không có yêu cầu phù hợp với bộ lọc.'), findsOneWidget);
    },
  );

  testWidgets(
    'thẻ lắp đặt giống web: chip triển khai, tổng HĐ, ngày tạo; thẻ bảo trì không có tổng HĐ',
    (tester) async {
      route(quotation: {'status': 'SentToOwner'});
      await pumpList(tester);
      expect(find.text('Triển khai: Đang lắp đặt'), findsOneWidget);
      expect(find.text('Đã gửi HĐ · chờ Owner cọc 30%'), findsWidgets);
      expect(find.text('Tổng HĐ: 13.500.000 đ'), findsWidgets);
      expect(find.text('Ngày tạo: 12/11/2026'), findsWidgets);
      // Chỉ phiếu i1 gắn đúng farm/zone nên mới có chip triển khai (một chip).
    },
  );

  testWidgets('không tràn ở 320px, chữ 1,3×', (tester) async {
    route(quotation: {'status': 'Completed'});
    await pumpList(tester, width: 320, textScale: 1.3);
    expect(find.text('SENSOR_OFFLINE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
