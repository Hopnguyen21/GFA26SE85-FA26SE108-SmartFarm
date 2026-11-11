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
import 'package:smartfarm_mobile/features/contracts/contracts_depreciation_screen.dart';
import 'package:smartfarm_mobile/features/support/support_requests_screen.dart';
import 'package:smartfarm_mobile/features/zones/widgets/emergency_stop_button.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_workers_section.dart';

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

ZoneModel _zone(String id, {String farm = 'f1', String name = 'Zone'}) => ZoneModel.fromJson(
  {'zoneId': id, 'name': name, 'areaM2': 10},
  farmId: farm,
  fieldId: 'fl1',
  farmName: 'Farm $farm',
);

FarmerModel _farmer(String id, String farm, List<ZoneAccessItem> access, {bool active = true}) => FarmerModel(
  farmerId: id,
  name: 'NV $id',
  role: 'Nông dân',
  phone: '09$id',
  email: '$id@x.vn',
  farmId: farm,
  isActive: active,
  zoneAccess: access,
);

Future<FarmProvider> _pump(WidgetTester tester, Widget child, {String role = 'OWNER'}) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = FarmProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  provider.switchRole(role);
  return provider;
}

Future<void> _dispose(WidgetTester tester, FarmProvider p) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  p.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('quyền điều khiển theo vai trò (khớp backend)', () {
    test('Owner điều khiển mọi Zone; Technician KHÔNG ra lệnh; Farmer chỉ Zone được cấp canControl', () async {
      final p = FarmProvider();
      expect(p.canControlZone('any'), isTrue, reason: 'Owner');
      p.switchRole('TECHNICIAN');
      expect(p.canControlZone('any'), isFalse);
      expect(p.canEmergencyStop, isFalse);
      p.switchRole('FARMER');
      expect(p.canControlZone('z1'), isFalse, reason: 'Farmer chưa có thông tin quyền');
      p.dispose();
    });

    testWidgets('nút dừng khẩn cấp theo Zone ẩn với Farmer không có canControl của Zone đó', (tester) async {
      final p = await _pump(
        tester,
        const EmergencyStopButton(zoneId: 'z1', zoneName: 'Z1'),
        role: 'FARMER',
      );
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
      await _dispose(tester, p);

      final owner = await _pump(tester, const EmergencyStopButton(zoneId: 'z1', zoneName: 'Z1'));
      await tester.pump();
      expect(find.byType(FilledButton), findsOneWidget);
      await _dispose(tester, owner);
    });
  });

  group('nhân công theo Farm của Zone', () {
    test('farmersForFarm lấy đúng Farm của Zone (không theo Farm đang chọn) và bỏ người ngừng hoạt động', () async {
      final p = FarmProvider();
      p.setSelectedFarmIdForTesting('f1');
      p.setFarmersForTesting([_farmer('1', 'f1', []), _farmer('2', 'f2', []), _farmer('3', 'f2', [], active: false)]);
      expect(p.farmersForFarm('f2').map((f) => f.farmerId), ['2']);
      expect(p.farmersForFarm('F1').map((f) => f.farmerId), ['1']);
      p.dispose();
    });

    testWidgets('khu vực nhân công chỉ liệt kê người được gán đúng Zone; gỡ chỉ bỏ Zone này khỏi quyền', (
      tester,
    ) async {
      final zone = _zone('z1');
      final p = await _pump(tester, ZoneWorkersSection(zone: zone, onAssign: () async {}));
      p.setZonesForTesting([zone]);
      p.setFarmersForTesting([
        _farmer('1', 'f1', [
          const ZoneAccessItem(zoneId: 'z1', canControl: true),
          const ZoneAccessItem(zoneId: 'z9', canControl: false),
        ]),
        _farmer('2', 'f1', [const ZoneAccessItem(zoneId: 'z9', canControl: true)]),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('NV 1'), findsOneWidget);
      expect(
        find.text('NV 2'),
        findsNothing,
        reason: 'không hiển thị nhân công của Zone khác như thể phụ trách Zone này',
      );
      expect(find.textContaining('được điều khiển thiết bị'), findsOneWidget);

      await tester.tap(find.text('Gỡ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gỡ khỏi Zone'));
      await tester.pumpAndSettle();
      final put = calls.firstWhere((c) => c.method == 'PUT' && c.url.path == '/api/v1/users/1/zone-access');
      final access = (jsonDecode(put.body) as Map<String, dynamic>)['access'] as List;
      expect(access, [
        {'zoneId': 'z9', 'canControl': false},
      ], reason: 'quyền Zone khác giữ nguyên, chỉ bỏ z1');
      await _dispose(tester, p);
    });

    testWidgets('Farmer không thấy nút gán/gỡ', (tester) async {
      final zone = _zone('z1');
      final p = await _pump(
        tester,
        ZoneWorkersSection(zone: zone, onAssign: () async {}),
        role: 'FARMER',
      );
      await tester.pump();
      expect(find.text('Gán / đổi nhân công'), findsNothing);
      expect(find.text('Phân công ngay'), findsNothing);
      expect(find.text('Gỡ'), findsNothing);
      await _dispose(tester, p);
    });
  });

  group('hỗ trợ kỹ thuật theo Zone', () {
    testWidgets('mở từ Zone: chỉ liệt kê yêu cầu của Zone; form khóa vào Zone, không có ô chọn Zone khác', (
      tester,
    ) async {
      handler = (r) async {
        if (r.url.path == '/api/v1/service-requests') {
          return utf8Json([
            {
              'id': 'r1',
              'zoneId': 'z1',
              'failureCode': 'SENSOR_OFFLINE',
              'description': 'Của Zone 1',
              'status': 'Open',
            },
            {'id': 'r2', 'zoneId': 'z2', 'failureCode': 'OTHER', 'description': 'Của Zone 2', 'status': 'Open'},
          ]);
        }
        return utf8Json([]);
      };
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = FarmProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: SupportRequestsScreen(zone: _zone('z1', name: 'Nhà màng 1')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Của Zone 1'), findsOneWidget);
      expect(find.text('Của Zone 2'), findsNothing);
      expect(find.textContaining('Hỗ trợ kỹ thuật · Nhà màng 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      provider.dispose();
    });
  });

  group('hợp đồng & khấu hao theo Zone', () {
    testWidgets('mọi tab chỉ dùng zoneId đang xem; cảnh báo hết hạn gửi zoneId và được lọc lại phía app', (
      tester,
    ) async {
      handler = (r) async {
        final p = r.url.path;
        if (p == '/api/v1/zones/z1/contracts') {
          return utf8Json([
            {'id': 'c1', 'zoneId': 'z1', 'contractNumber': 'HD-Z1'},
            {'id': 'c2', 'zoneId': 'z2', 'contractNumber': 'HD-Z2'},
          ]);
        }
        if (p == '/api/v1/zone-contracts/expiring') {
          return utf8Json([
            {
              'contractId': 'c1',
              'contractNumber': 'HD-Z1',
              'zoneId': 'z1',
              'zoneName': 'Z1',
              'endDate': '2026-12-01',
              'daysRemaining': 10,
            },
            {
              'contractId': 'c2',
              'contractNumber': 'HD-Z2',
              'zoneId': 'z2',
              'zoneName': 'Z2',
              'endDate': '2026-12-01',
              'daysRemaining': 10,
            },
          ]);
        }
        return utf8Json([]);
      };
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = FarmProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: ContractsDepreciationScreen(lockedZone: _zone('z1'))),
        ),
      );
      await tester.pumpAndSettle();
      final exp = calls.firstWhere((c) => c.url.path == '/api/v1/zone-contracts/expiring');
      expect(exp.url.queryParameters['zoneId'], 'z1');
      expect(calls.any((c) => c.url.path == '/api/v1/zones/z1/contracts'), isTrue);
      expect(calls.any((c) => c.url.path == '/api/v1/zone-contracts'), isFalse, reason: 'không tải hợp đồng toàn Farm');
      expect(find.textContaining('HD-Z2'), findsNothing, reason: 'không hiển thị hợp đồng của Zone khác');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      provider.dispose();
    });
  });
}
