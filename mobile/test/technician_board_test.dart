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
import 'package:smartfarm_mobile/features/devices/deployment_screens.dart';

Map<String, dynamic> _req(
  String id,
  String status, {
  String zone = 'Nhà màng 1',
  String farm = 'Trang trại A',
  List<Map<String, dynamic>> plan = const [],
}) => {
  'requestId': id,
  'farmId': 'f',
  'zoneId': 'z',
  'status': status,
  'requiredParameters': ['Temperature'],
  'planItems': plan,
  'surveys': <Map<String, dynamic>>[],
  'decisionHistory': <Map<String, dynamic>>[],
  'context': {
    'farmName': farm,
    'farmLocation': 'Đà Lạt, Lâm Đồng',
    'fieldName': 'Lô A1',
    'zoneName': zone,
    'zoneType': 'Greenhouse',
    'zoneAreaM2': 507.0,
    'cropName': 'Cà chua',
    'seasonName': 'Vụ đông',
    'seasonStatus': 'InProgress',
    'seasonStartDate': '2026-11-01',
    'seasonExpectedEndDate': '2027-02-01',
  },
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

  Future<void> pumpBoard(
    WidgetTester tester, {
    double width = 390,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>(
        create: (_) => FarmProvider(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const TechnicianDeploymentsScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  final sample = [
    _req('a1', 'Submitted', zone: 'Zone chờ', farm: 'Trang trại Mới'),
    _req(
      'a2',
      'Accepted',
      zone: 'Zone khảo sát',
      plan: [
        {
          'deviceModelId': 'm1',
          'modelName': 'Node đất',
          'deviceType': 'SensorNode',
          'quantity': 2,
        },
      ],
    ),
    _req('a3', 'Installing', zone: 'Zone lắp'),
    _req('a4', 'MaintenanceRequired', zone: 'Zone hỏng'),
    _req('a5', 'Completed', zone: 'Zone xong'),
  ];

  testWidgets(
    'bảng việc: tóm tắt đủ 4 nhóm, thẻ xếp theo mức khẩn, có việc tiếp theo và tiến trình',
    (tester) async {
      handler = (r) async => json(sample);
      await pumpBoard(tester);

      expect(find.text('Công việc triển khai'), findsOneWidget);
      for (final label in [
        'Chờ tiếp nhận',
        'Đang xử lý',
        'Cần bảo trì',
        'Hoàn tất triển khai',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Thứ tự: đang lắp (khẩn nhất) trước, hoàn tất cuối.
      final lap = tester.getTopLeft(find.textContaining('Zone lắp')).dy;
      final ks = tester.getTopLeft(find.textContaining('Zone khảo sát')).dy;
      final cho = tester.getTopLeft(find.textContaining('Zone chờ')).dy;
      final xong = tester.getTopLeft(find.textContaining('Zone xong')).dy;
      expect(lap < ks && ks < cho && cho < xong, isTrue);

      expect(find.text('Khảo sát địa điểm'), findsOneWidget);
      expect(find.text('2× Node đất'), findsOneWidget);
      expect(find.textContaining('Bước 2/6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('chạm ô tóm tắt để lọc, chạm lần nữa hoặc "Bỏ lọc" để bỏ', (
    tester,
  ) async {
    handler = (r) async => json(sample);
    await pumpBoard(tester);

    await tester.tap(find.text('Đang xử lý'));
    await tester.pump();
    expect(find.textContaining('Zone khảo sát'), findsOneWidget);
    expect(find.textContaining('Zone lắp'), findsOneWidget);
    expect(find.textContaining('Zone chờ'), findsNothing);
    expect(find.textContaining('Hiển thị 2/5 yêu cầu'), findsOneWidget);

    await tester.tap(find.text('Bỏ lọc'));
    await tester.pump();
    expect(find.textContaining('Zone chờ'), findsOneWidget);
    expect(find.textContaining('Hiển thị'), findsNothing);
  });

  testWidgets(
    'tìm kiếm theo Zone/trang trại; không có kết quả thì báo và cho bỏ lọc',
    (tester) async {
      handler = (r) async => json(sample);
      await pumpBoard(tester);

      await tester.enterText(find.byType(TextField), 'trang trại mới');
      await tester.pump();
      expect(find.textContaining('Zone chờ'), findsOneWidget);
      expect(find.textContaining('Zone lắp'), findsNothing);

      await tester.enterText(find.byType(TextField), 'không tồn tại');
      await tester.pump();
      expect(find.text('Không có yêu cầu phù hợp với bộ lọc.'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Bỏ lọc'));
      await tester.pump();
      expect(find.textContaining('Zone lắp'), findsOneWidget);
    },
  );

  testWidgets('chưa có yêu cầu nào: báo rõ, không hiện ô lọc rỗng gây rối', (
    tester,
  ) async {
    handler = (r) async => json(<Object>[]);
    await pumpBoard(tester);
    expect(
      find.textContaining('Chưa có yêu cầu nào chờ tiếp nhận hoặc được giao'),
      findsOneWidget,
    );
    expect(find.textContaining('Kéo xuống để làm mới'), findsOneWidget);
  });

  testWidgets(
    'lỗi tải: nêu lý do và cho thử lại; thử lại thành công thì hiện bảng',
    (tester) async {
      handler = (r) async => json({'message': 'Máy chủ bận'}, 500);
      await pumpBoard(tester);
      expect(find.textContaining('Không tải được danh sách'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      handler = (r) async => json(sample);
      await tester.tap(find.text('Thử lại'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.textContaining('Zone lắp'), findsOneWidget);
    },
  );

  testWidgets('không tràn ở 320px, chữ 1,3×', (tester) async {
    handler = (r) async => json(sample);
    await pumpBoard(tester, width: 320, textScale: 1.3);
    expect(find.textContaining('Zone lắp'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chi tiết yêu cầu của kỹ thuật viên: tiến trình, việc tiếp theo và nút thao tác ở đầu màn',
    (tester) async {
      handler = (r) async =>
          json(_req('4fd9ce0e-b78f-4132-aaec-ca8efe97372d', 'Accepted'));
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<FarmProvider>(
          create: (_) => FarmProvider(),
          child: const MaterialApp(
            home: DeploymentRequestDetailScreen(
              requestId: '4fd9ce0e-b78f-4132-aaec-ca8efe97372d',
              technician: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.textContaining('Việc tiếp theo:'), findsOneWidget);
      expect(
        find.text('Khảo sát'),
        findsOneWidget,
        reason: 'nhãn bước tiến trình',
      );
      final action = find.text('Ghi nhận khảo sát địa điểm');
      expect(action, findsOneWidget);
      final place = find.text('Nơi lắp đặt');
      expect(
        tester.getTopLeft(action).dy < tester.getTopLeft(place).dy,
        isTrue,
        reason: 'nút thao tác nằm trên thẻ thông tin, không cuối danh sách',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
