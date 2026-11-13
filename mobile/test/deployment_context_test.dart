import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/devices/deployment_screens.dart';

Map<String, dynamic> requestJson({bool withContext = true}) => {
  'requestId': '4fd9ce0e-b78f-4132-aaec-ca8efe97372d',
  'farmId': 'f',
  'zoneId': 'z',
  'status': 'Submitted',
  'requiredParameters': ['Temperature', 'SoilMoisture'],
  'planItems': [],
  'surveys': [],
  'decisionHistory': [],
  if (withContext)
    'context': {
      'farmName': 'Trang trại CNC Đà Lạt',
      'farmLocation': 'Đà Lạt, Lâm Đồng',
      'fieldName': 'Lô A1',
      'soilType': 'Loam',
      'zoneName': 'Nhà màng Z01',
      'zoneType': 'Greenhouse',
      'zoneAreaM2': 1926.0,
      'cropName': 'Cà chua',
      'varietyName': 'Beefsteak',
      'seasonName': 'Vụ Đông Xuân',
      'seasonStatus': 'Planned',
      'seasonStartDate': '2026-11-01',
      'seasonExpectedEndDate': '2027-02-01',
    },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'đọc ngữ cảnh Zone/farm/cây/vụ từ phản hồi; thiếu thì null (backend cũ)',
    () {
      final r = DeploymentRequest.fromJson(requestJson());
      final c = r.context!;
      expect(
        [c.farmName, c.fieldName, c.zoneName, c.cropName, c.varietyName],
        [
          'Trang trại CNC Đà Lạt',
          'Lô A1',
          'Nhà màng Z01',
          'Cà chua',
          'Beefsteak',
        ],
      );
      expect(c.zoneAreaM2, 1926);
      expect(DeploymentContext.vnDate(c.seasonStart), '01/11/2026');
      expect(DeploymentContext.vnDate('không-phải-ngày'), 'không-phải-ngày');
      expect(
        DeploymentRequest.fromJson(requestJson(withContext: false)).context,
        isNull,
      );
    },
  );

  // ApiService giữ một http.Client tĩnh: gắn MockClient MỘT LẦN rồi đổi handler theo từng test (như deployment_zone_race_test).
  Future<http.Response> Function(http.Request) handler = (r) async =>
      http.Response('{}', 200);
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

  Future<void> pumpDetail(
    WidgetTester tester,
    Map<String, dynamic> body,
  ) async {
    handler = (r) async => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>(
        create: (_) => FarmProvider(),
        child: const MaterialApp(
          home: DeploymentRequestDetailScreen(
            requestId: '4fd9ce0e-b78f-4132-aaec-ca8efe97372d',
            technician: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets(
    'màn chi tiết yêu cầu hiển thị nơi lắp đặt: farm, thửa đất, Zone, cây, vụ mùa',
    (tester) async {
      await pumpDetail(tester, requestJson());
      expect(find.text('Nơi lắp đặt'), findsOneWidget);
      expect(find.textContaining('Trang trại CNC Đà Lạt'), findsWidgets);
      expect(find.textContaining('Lô A1 · Đất thịt'), findsOneWidget);
      expect(
        find.textContaining('Nhà màng Z01 · Nhà màng · 1926 m²'),
        findsOneWidget,
      );
      expect(find.textContaining('Cà chua · Beefsteak'), findsOneWidget);
      expect(find.textContaining('01/11/2026 → 01/02/2027'), findsOneWidget);
      expect(find.text('Yêu cầu · Nhà màng Z01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backend cũ chưa trả ngữ cảnh: báo rõ thay vì để trống', (
    tester,
  ) async {
    await pumpDetail(tester, requestJson(withContext: false));
    expect(find.text('Nơi lắp đặt'), findsNothing);
    expect(find.textContaining('Chưa có thông tin Zone'), findsOneWidget);
    expect(find.textContaining('Yêu cầu 4fd9ce0e'), findsOneWidget);
  });

  testWidgets('màn chi tiết không tràn ở 320px, chữ 1,3×', (tester) async {
    handler = (r) async => http.Response(
      jsonEncode(requestJson()),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    tester.view.physicalSize = const Size(320, 2000);
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
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const DeploymentRequestDetailScreen(
            requestId: '4fd9ce0e-b78f-4132-aaec-ca8efe97372d',
            technician: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text('Nơi lắp đặt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('kỹ thuật thêm model vào kế hoạch rỗng và gửi đúng số lượng', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    final body = requestJson()..['status'] = 'Surveyed';
    handler = (r) async {
      Object value = body;
      if (r.url.path.endsWith('/models')) {
        value = [
          {
            'deviceModelId': 'model-a',
            'modelName': 'Node thử nghiệm',
            'deviceType': 'SensorNode',
            'quantity': 1,
          },
        ];
      } else if (r.method == 'PUT' && r.url.path.endsWith('/plan')) {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
      }
      return http.Response(
        jsonEncode(value),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    };
    tester.view.physicalSize = const Size(600, 2500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: DeploymentRequestDetailScreen(
          requestId: '4fd9ce0e-b78f-4132-aaec-ca8efe97372d',
          technician: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Điều chỉnh kế hoạch sau khảo sát'));
    await tester.tap(find.text('Điều chỉnh kế hoạch sau khảo sát'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lưu'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Sử dụng Node thử nghiệm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(sent, isNotNull);
    expect((sent!['items'] as List).single['deviceModelId'], 'model-a');
    expect((sent!['items'] as List).single['quantity'], 1);
    expect(tester.takeException(), isNull);
  });
}
