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
import 'package:smartfarm_mobile/core/theme/app_theme.dart';
import 'package:smartfarm_mobile/features/inventory/inventory_screen.dart';

// Hộp thoại sổ kho: nhập sai không được lặng lẽ thành "không đổi"/0, bấm đúp không ghi hai dòng sổ,
// và xuất kho chỉ chọn được Zone của đúng trang trại đang chọn.
Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<http.Response> route(http.Request r) async {
  final p = r.url.path;
  if (p == '/api/v1/users/me') {
    return json({'userId': 'u1', 'fullName': 'Chủ trại', 'role': 'FarmOwner'});
  }
  if (p == '/api/v1/farms') {
    return json([
      {
        'farmId': 'f1',
        'name': 'Trại 1',
        'totalAreaM2': 1000,
        'latitude': 11.9,
        'longitude': 108.4,
      },
      {
        'farmId': 'f2',
        'name': 'Trại 2',
        'totalAreaM2': 1000,
        'latitude': 11.9,
        'longitude': 108.4,
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/fields') {
    return json([
      {'fieldId': 'fl1', 'farmId': 'f1', 'name': 'Lô 1', 'areaM2': 500},
    ]);
  }
  if (p == '/api/v1/farms/f2/fields') {
    return json([
      {'fieldId': 'fl2', 'farmId': 'f2', 'name': 'Lô 2', 'areaM2': 500},
    ]);
  }
  if (p == '/api/v1/fields/fl1/zones') {
    return json([
      {
        'zoneId': 'z1',
        'farmId': 'f1',
        'fieldId': 'fl1',
        'name': 'Zone Trại1',
        'areaM2': 100,
      },
    ]);
  }
  if (p == '/api/v1/fields/fl2/zones') {
    return json([
      {
        'zoneId': 'z2',
        'farmId': 'f2',
        'fieldId': 'fl2',
        'name': 'Zone Trại2',
        'areaM2': 100,
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/inventory' && r.method == 'GET') {
    return json([
      {
        'id': 'i1',
        'farmId': 'f1',
        'name': 'Phân NPK',
        'materialType': 'Fertilizer',
        'quantityOnHand': 10,
        'unit': 'kg',
        'lowStockThreshold': 2,
      },
    ]);
  }
  if (p.endsWith('/inventory/issues') && r.method == 'POST') {
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    ); // mạng chậm: cửa sổ để bấm đúp
    return json({'ok': true});
  }
  return http.Response('[]', 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((r) async {
        calls.add(r);
        return handler(r);
      }),
    );
  });

  setUp(() {
    calls.clear();
    handler = route;
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  Future<void> openAdjust(WidgetTester tester) async {
    tester.view.physicalSize = const Size(700, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = FarmProvider()..switchRole('OWNER');
    await provider
        .fetchFromApi(); // chọn sẵn trang trại đầu tiên (f1) và nạp kho của nó
    expect(provider.selectedFarmId, 'f1');
    expect(provider.inventoryItemsForCurrentFarm, isNotEmpty);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const InventoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điều chỉnh / Xuất nhập kho'));
    await tester.pumpAndSettle();
  }

  // Ô nhập trong bottom sheet (màn còn có ô tìm kiếm).
  final sheetField = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byType(TextField),
  );

  Iterable<http.Request> writes() => calls.where(
    (c) => c.method == 'POST' && c.url.path.contains('/inventory'),
  );

  testWidgets('số không hợp lệ: báo lỗi, không đóng hộp thoại, không ghi sổ', (
    tester,
  ) async {
    await openAdjust(tester);
    await tester.enterText(sheetField, 'abc');
    await tester.tap(find.text('XÁC NHẬN CẬP NHẬT TỒN KHO'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nhập số lượng tồn là một số không âm'),
      findsOneWidget,
    );
    expect(
      find.text('XÁC NHẬN CẬP NHẬT TỒN KHO'),
      findsOneWidget,
      reason: 'hộp thoại vẫn mở',
    );
    expect(writes(), isEmpty);
  });

  testWidgets(
    'xuất kho: chỉ liệt kê Zone của trang trại đang chọn và bấm đúp chỉ ghi MỘT lần',
    (tester) async {
      await openAdjust(tester);
      await tester.enterText(
        sheetField,
        '7,5',
      ); // dấu phẩy kiểu Việt, tồn 10 → xuất 2,5
      await tester.tap(find.text('XÁC NHẬN CẬP NHẬT TỒN KHO'));
      await tester.pumpAndSettle();
      expect(find.text('Xuất cho Zone nào?'), findsOneWidget);
      expect(find.text('Zone Trại1'), findsOneWidget);
      expect(
        find.text('Zone Trại2'),
        findsNothing,
        reason: 'Zone của trang trại khác không được hiện',
      );

      await tester.tap(find.text('Zone Trại1'));
      // Bấm đúp "Xác nhận" trong lúc yêu cầu đầu còn đang chờ.
      await tester.pump(const Duration(milliseconds: 20));
      final confirm = find.text('XÁC NHẬN CẬP NHẬT TỒN KHO');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm, warnIfMissed: false);
      }
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      final issues = writes()
          .where((c) => c.url.path.endsWith('/inventory/issues'))
          .toList();
      expect(issues, hasLength(1));
      final body = jsonDecode(issues.single.body) as Map<String, dynamic>;
      expect(body['zoneId'], 'z1');
      expect((body['quantity'] as num).toDouble(), 2.5);
    },
  );
}
