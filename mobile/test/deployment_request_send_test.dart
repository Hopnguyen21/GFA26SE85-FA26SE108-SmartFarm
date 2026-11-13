import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/devices/deployment_request_send_screen.dart';

class _OneZone extends FarmProvider {
  @override
  List<ZoneModel> get allZones => [
    ZoneModel.fromJson(
      {'zoneId': 'z1', 'name': 'Nhà màng 01 - Khu Lâm Đồng', 'areaM2': 1458},
      farmId: 'f1',
      fieldId: 'fl1',
      farmName: 'Nông trại CNC Lâm Đồng (Cơ sở 06)',
      fieldName: 'Lô A1',
    ),
  ];
}

const gwId = '11111111-1111-1111-1111-111111111111';
const nodeId = '22222222-2222-2222-2222-222222222222';
const valveId = '33333333-3333-3333-3333-333333333333';
const kitId = '44444444-4444-4444-4444-444444444444';

Map<String, dynamic> hw(
  String id,
  String code,
  String role,
  num price, {
  List<String> measured = const [],
}) => {
  'id': id,
  'code': code,
  'name': 'Thiet bi $code',
  'category': 'X',
  'model': 'M-$code',
  'quantityInStock': 0,
  'unitPrice': price,
  'status': 'InStock',
  'estimateRole': role,
  'estimateUnits': 1,
  'measuredParameters': measured,
};

Map<String, dynamic> existingRequest(String status) => {
  'requestId': '4fd9ce0e-b78f-4132-aaec-ca8efe97372d',
  'farmId': 'f1',
  'zoneId': 'z1',
  'status': status,
  'requiredParameters': ['Temperature'],
  'planItems': [],
  'surveys': [],
  'decisionHistory': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final posts = <http.Request>[];
  var activeStatus = '';
  var seasonMissing = false;
  http.Response json(Object body, [int code = 200]) => http.Response(
    jsonEncode(body),
    code,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> handler(http.Request r) async {
    final p = r.url.path;
    if (r.method == 'POST' && p.endsWith('/deployment-requests/submit')) {
      posts.add(r);
      return json(existingRequest('Submitted'), 201);
    }
    if (p.endsWith('/iot-requirements')) {
      return seasonMissing
          ? json({
              'title': 'Resource not found',
              'detail':
                  'Zone has no InProgress Planting Season in the current Tenant.',
            }, 404)
          : json({
              'zoneId': 'z1',
              'plantingSeasonId': 's1',
              'growthStageId': 'g1',
              'zoneAreaM2': 1458,
              'parameters': [
                'Temperature',
                'SoilMoisture',
                'AirHumidity',
                'LightIntensity',
              ],
            });
    }
    if (p.endsWith('/api/v1/deployment-requests'))
      return json(activeStatus.isEmpty ? [] : [existingRequest(activeStatus)]);
    if (p.endsWith('/hardware-items')) {
      return json([
        hw(gwId, 'GW', 'Gateway', 3800000),
        hw(
          nodeId,
          'NODE',
          'SensorNode',
          950000,
          measured: [
            'Temperature',
            'SoilMoisture',
            'AirHumidity',
            'LightIntensity',
          ],
        ),
        hw(valveId, 'VALVE', 'ActuatorNode', 2150000),
        hw(kitId, 'KIT', 'InstallKit', 150000),
      ]);
    }
    if (p.endsWith('/devices')) return json([]);
    if (p.contains('/deployment-requests/4fd9ce0e'))
      return json(existingRequest('Submitted'));
    return json([]);
  }

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
      () => MockClient(handler),
    );
  });

  setUp(() {
    posts.clear();
    activeStatus = '';
    seasonMissing = false;
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>(
        create: (_) => _OneZone(),
        child: const MaterialApp(
          home: DeploymentRequestSendScreen(zoneId: 'z1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets(
    'hiển thị thông tin Zone và nội dung yêu cầu (thông số, dự toán, ghi chú, tóm tắt) trước khi gửi',
    (tester) async {
      await pumpScreen(tester);
      expect(find.text('1. Thông tin Zone'), findsOneWidget);
      expect(
        find.textContaining('Nông trại CNC Lâm Đồng (Cơ sở 06)'),
        findsWidgets,
      );
      expect(find.text('Lô A1'), findsOneWidget);
      expect(
        find.textContaining('Nhà màng 01 - Khu Lâm Đồng · 1458 m²'),
        findsOneWidget,
      );
      expect(find.text('2. Nội dung yêu cầu sẽ gửi'), findsOneWidget);
      expect(find.text('Nhiệt độ'), findsWidgets);
      expect(find.text('Độ ẩm đất'), findsWidgets);
      expect(find.textContaining('Thiết bị đề xuất & dự toán'), findsOneWidget);
      expect(find.text('3. Tóm tắt trước khi gửi'), findsOneWidget);
      expect(find.textContaining('Lưu kèm yêu cầu:'), findsOneWidget);
      expect(find.text('Xác nhận gửi yêu cầu'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bấm xác nhận → hộp thoại → gửi đúng nội dung: ghi chú, id thiết bị kho, KHÔNG gửi đơn giá thiết bị',
    (tester) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Gần cổng chính');
      await tester.pump();
      await tester.tap(find.text('Xác nhận gửi yêu cầu'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận gửi yêu cầu?'), findsOneWidget);
      expect(posts, isEmpty, reason: 'chưa xác nhận thì chưa gửi');
      await tester.tap(find.text('Gửi yêu cầu'));
      await tester.pumpAndSettle();
      expect(posts.length, 1);
      final body = jsonDecode(posts.single.body) as Map<String, dynamic>;
      expect(body['ownerNotes'], 'Gần cổng chính');
      final items = (body['estimateItems'] as List)
          .cast<Map<String, dynamic>>();
      expect(items.map((i) => i['role']), [
        'Gateway',
        'SensorNode',
        'ActuatorNode',
        'InstallKit',
        'Installation',
      ]);
      expect(items.first['hardwareItemId'], gwId);
      expect(items.take(4).every((i) => !i.containsKey('unitPrice')), isTrue);
      expect(
        body.containsKey('requiredParameters'),
        isFalse,
        reason: 'thông số cần đo do máy chủ quyết định',
      );
    },
  );

  testWidgets('chọn "Xem lại" trong hộp thoại: không gửi gì', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Xác nhận gửi yêu cầu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem lại'));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);
  });

  testWidgets(
    'Zone đã có yêu cầu đang xử lý: báo rõ, khóa nút gửi, cho mở yêu cầu đó',
    (tester) async {
      activeStatus = 'Accepted';
      await pumpScreen(tester);
      expect(find.text('Zone đã có yêu cầu đang xử lý'), findsOneWidget);
      expect(find.text('Mở yêu cầu đang xử lý'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Xác nhận gửi yêu cầu'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(posts, isEmpty);
    },
  );

  testWidgets('Zone chưa có vụ đang canh tác: giải thích và không cho gửi', (
    tester,
  ) async {
    seasonMissing = true;
    await pumpScreen(tester);
    expect(find.text('Chưa thể gửi yêu cầu'), findsOneWidget);
    expect(
      find.textContaining('chưa có vụ trồng đang canh tác'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Xác nhận gửi yêu cầu'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('không tràn ngang ở 320px, chữ 1,3×', (tester) async {
    tester.view.physicalSize = const Size(320, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>(
        create: (_) => _OneZone(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const DeploymentRequestSendScreen(zoneId: 'z1'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Xác nhận gửi yêu cầu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
