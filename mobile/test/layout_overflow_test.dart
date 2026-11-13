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
import 'package:smartfarm_mobile/features/farmer/farmer_dashboard_screen.dart';
import 'package:smartfarm_mobile/features/farms/farms_management_screen.dart';
import 'package:smartfarm_mobile/features/home/home_screen.dart';
import 'package:smartfarm_mobile/features/inventory/inventory_screen.dart';
import 'package:smartfarm_mobile/features/profile/profile_screen.dart';
import 'package:smartfarm_mobile/features/tasks/alerts_tasks_screen.dart';
import 'package:smartfarm_mobile/features/zones/zone_detail_screen.dart';

/// Kiểm tra bố cục: các màn chính dựng với dữ liệu (mẫu chỉ dùng trong test, đi qua API giả) ở màn hình hẹp
/// (320px) và chữ phóng to 1.3× không được tràn (RenderFlex overflow) hay ném lỗi.
http.Response json(Object o) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response route(http.Request r) {
  final p = r.url.path;
  if (p == '/api/v1/users/me')
    return json({
      'userId': 'u1',
      'fullName': 'Chủ Trại Một Cái Tên Khá Dài',
      'role': 'FarmOwner',
    });
  if (p == '/api/v1/farms') {
    return json([
      {
        'farmId': 'f1',
        'name': 'Trang trại Đà Lạt Công Nghệ Cao Số Một',
        'locationText': 'Xã Xuân Thọ, TP. Đà Lạt, Lâm Đồng',
        'totalAreaM2': 12000,
        'latitude': 11.94,
        'longitude': 108.44,
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/fields') {
    return json([
      {
        'fieldId': 'fl1',
        'farmId': 'f1',
        'name': 'Lô đất A1 (khu canh tác phía Đông)',
        'areaM2': 6000,
        'soilType': 'Đất đỏ bazan',
      },
    ]);
  }
  if (p == '/api/v1/fields/fl1/zones') {
    return json([
      {
        'zoneId': 'z1',
        'farmId': 'f1',
        'fieldId': 'fl1',
        'name': 'Nhà màng 01 - Khu cà chua beef thủy canh',
        'areaM2': 1500,
        'currentCrop': 'Cà chua Beef',
        'currentStage': 'Ra hoa',
      },
      {
        'zoneId': 'z2',
        'farmId': 'f1',
        'fieldId': 'fl1',
        'name': 'Nhà màng 02',
        'areaM2': 900,
      },
    ]);
  }
  if (p == '/api/v1/zones/z1/actuators' || p == '/api/v1/zones/z2/actuators') {
    return json([
      {
        'actuatorId': 'a-${p.contains('z1') ? 1 : 2}',
        'zoneId': p.contains('z1') ? 'z1' : 'z2',
        'name': 'Bơm tưới nhỏ giọt khu vực trung tâm',
        'actuatorType': 'IrrigationPump',
        'status': 'Off',
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/alerts') {
    return json([
      {
        'alertId': 'al1',
        'zoneId': 'z1',
        'severity': 'Critical',
        'status': 'Open',
        'parameterCode': 'SoilMoisture',
        'observedValue': 31.5,
        'unit': '%',
        'message': 'Độ ẩm đất xuống dưới ngưỡng an toàn của giai đoạn ra hoa',
        'createdAtUtc': '2026-11-10T01:00:00Z',
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/tasks') {
    return json([
      {
        'taskId': 't1',
        'title':
            'Kiểm tra hệ thống tưới nhỏ giọt và vệ sinh béc phun khu vực phía Tây',
        'zoneId': 'z1',
        'priority': 'High',
        'status': 'Pending',
        'dueAtUtc': '2026-11-11T02:00:00Z',
        'assignments': [],
      },
    ]);
  }
  if (p == '/api/v1/farms/f1/inventory') {
    return json([
      {
        'inventoryId': 'i1',
        'itemId': 'i1',
        'name': 'Phân NPK 20-20-15 hòa tan cao cấp nhập khẩu',
        'category': 'Fertilizer',
        'quantityOnHand': 12,
        'unit': 'kg',
        'lowStockThreshold': 20,
      },
    ]);
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
      () => MockClient((req) async => route(req)),
    );
  });

  setUp(
    () => ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    ),
  );

  Future<FarmProvider> loadedProvider(String role) async {
    final provider = FarmProvider();
    provider.switchRole(role);
    await provider.fetchFromApi();
    return provider;
  }

  final layoutErrors = <String>[];

  Future<void> pumpAt(
    WidgetTester tester,
    FarmProvider provider,
    Widget screen, {
    double width = 320,
  }) async {
    layoutErrors.clear();
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      layoutErrors.add(details.exceptionAsString().split('\n').first);
      FlutterError.dumpErrorToConsole(
        details,
        forceReport: true,
      ); // in vị trí widget gây lỗi
    };
    addTearDown(() => FlutterError.onError = previous);
    tester.view.physicalSize = Size(width, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  void expectNoLayoutErrors(WidgetTester tester, String what) {
    final summary = layoutErrors
        .map((e) {
          final head =
              RegExp(r'overflowed by [^\n]*').firstMatch(e)?.group(0) ??
              e.split('\n').first;
          final where =
              RegExp(
                r'(Row|Column|Flex|Wrap|Stack):file:[^\n]*',
              ).firstMatch(e)?.group(0) ??
              '';
          return '$head $where';
        })
        .toSet()
        .join('\n');
    expect(layoutErrors, isEmpty, reason: '$what:\n$summary');
  }

  for (final width in [320.0, 360.0]) {
    group('${width.toInt()}px, chữ 1.3×', () {
      testWidgets('HomeScreen (Owner) có dữ liệu', (tester) async {
        final p = await loadedProvider('OWNER');
        await pumpAt(tester, p, const HomeScreen(), width: width);
        expectNoLayoutErrors(tester, 'HomeScreen');
        p.dispose();
      });

      testWidgets('ZoneDetailScreen có dữ liệu', (tester) async {
        final p = await loadedProvider('OWNER');
        expect(p.allZones, isNotEmpty);
        await pumpAt(
          tester,
          p,
          ZoneDetailScreen(zone: p.allZones.first),
          width: width,
        );
        expectNoLayoutErrors(tester, 'ZoneDetailScreen');
        p.dispose();
      });

      testWidgets('AlertsTasksScreen có cảnh báo và tác vụ', (tester) async {
        final p = await loadedProvider('OWNER');
        await pumpAt(tester, p, const AlertsTasksScreen(), width: width);
        expectNoLayoutErrors(tester, 'AlertsTasksScreen');
        p.dispose();
      });

      testWidgets('FarmsManagementScreen', (tester) async {
        final p = await loadedProvider('OWNER');
        await pumpAt(tester, p, const FarmsManagementScreen(), width: width);
        expectNoLayoutErrors(tester, 'FarmsManagementScreen');
        p.dispose();
      });

      testWidgets('InventoryScreen', (tester) async {
        final p = await loadedProvider('OWNER');
        await pumpAt(tester, p, const InventoryScreen(), width: width);
        expectNoLayoutErrors(tester, 'InventoryScreen');
        p.dispose();
      });

      testWidgets('FarmerDashboardScreen', (tester) async {
        final p = await loadedProvider('FARMER');
        await pumpAt(tester, p, const FarmerDashboardScreen(), width: width);
        expectNoLayoutErrors(tester, 'FarmerDashboardScreen');
        p.dispose();
      });

      testWidgets('ProfileScreen', (tester) async {
        final p = await loadedProvider('OWNER');
        await pumpAt(tester, p, const ProfileScreen(), width: width);
        expectNoLayoutErrors(tester, 'ProfileScreen');
        p.dispose();
      });
    });
  }
}
