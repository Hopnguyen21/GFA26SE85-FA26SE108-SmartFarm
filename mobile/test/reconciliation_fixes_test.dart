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
import 'package:smartfarm_mobile/features/auth/register_screen.dart';
import 'package:smartfarm_mobile/features/farmer/farmer_dashboard_screen.dart';
import 'package:smartfarm_mobile/features/profile/connection_notification_screens.dart';
import 'package:smartfarm_mobile/features/profile/profile_screen.dart';
import 'package:smartfarm_mobile/features/reports/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<http.Request> calls = [];
  late http.Response Function(http.Request) handler;

  http.Response jsonResp(dynamic body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    handler = (_) => jsonResp([]);
    await http.runWithClient(
      () => FarmApi.getFarms(),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() {
    calls.clear();
    handler = (r) => r.url.path.contains('/users/me') ? jsonResp({}) : jsonResp([]);
    ApiService.setTokens(
      accessToken: 'token-xyz',
      refreshToken: 'ref-xyz',
      email: 'farmer@smartfarm.vn',
      role: 'Farmer',
    );
  });

  group('1. Farmer Dashboard & Me reconciliation', () {
    test('Farmer role does NOT call GET /api/v1/users?role=Farmer during fetchFromApi', () async {
      handler = (r) {
        if (r.url.path == '/api/v1/users/me') {
          return jsonResp({
            'userId': 'farmer-001',
            'fullName': 'Nguyễn Văn Nông Dân',
            'email': 'farmer@smartfarm.vn',
            'role': 'Farmer',
            'status': 'Active',
            'zoneAccess': [
              {'zoneId': 'zone-123', 'canControl': true},
            ],
          });
        }
        if (r.url.path == '/api/v1/farms') {
          return jsonResp([
            {'farmId': 'farm-001', 'name': 'Trang trại Dalat', 'address': 'Lâm Đồng', 'totalAreaM2': 5000},
          ]);
        }
        if (r.url.path == '/api/v1/farms/farm-001/fields') {
          return jsonResp([
            {'fieldId': 'field-001', 'farmId': 'farm-001', 'name': 'Khu A', 'areaM2': 2500},
          ]);
        }
        if (r.url.path == '/api/v1/fields/field-001/zones') {
          return jsonResp([
            {
              'zoneId': 'zone-123',
              'fieldId': 'field-001',
              'name': 'Zone Cà chua',
              'currentCrop': 'Cà chua Beef',
              'currentStage': 'Thu hoạch',
              'areaM2': 1000,
            },
            {
              'zoneId': 'zone-456',
              'fieldId': 'field-001',
              'name': 'Zone Dưa leo',
              'currentCrop': 'Dưa leo',
              'currentStage': 'Phát triển',
              'areaM2': 1000,
            },
          ]);
        }
        return jsonResp([]);
      };

      final provider = FarmProvider();
      provider.switchRole('FARMER');
      await provider.fetchFromApi();

      // Ensure that GET /api/v1/users was NOT requested
      final userListCalls = calls.where((c) => c.url.path == '/api/v1/users');
      expect(userListCalls, isEmpty);

      // Verify profile loaded from /users/me
      expect(provider.currentUserFarmer, isNotNull);
      expect(provider.currentUserFarmer!.name, 'Nguyễn Văn Nông Dân');
      expect(provider.currentUserFarmer!.farmerId, 'farmer-001');

      // Verify assigned zones filter: only zone-123 is assigned, zone-456 must NOT be in assignedZones
      expect(provider.assignedZonesForCurrentFarmer.length, 1);
      expect(provider.assignedZonesForCurrentFarmer.first.zoneId, 'zone-123');

      // Verify control permissions
      expect(provider.canControlZone('zone-123'), isTrue);
      expect(provider.canControlZone('zone-456'), isFalse);
      expect(provider.canControlZone('unknown-zone'), isFalse);

      provider.dispose();
    });

    test('Farmer with no zoneAccess has empty assignedZones and does not fallback', () async {
      handler = (r) {
        if (r.url.path == '/api/v1/users/me') {
          return http.Response(
            jsonEncode({
              'userId': 'farmer-unassigned',
              'fullName': 'Nông dân mới',
              'email': 'unassigned@smartfarm.vn',
              'role': 'Farmer',
              'zoneAccess': [],
            }),
            200,
          );
        }
        if (r.url.path == '/api/v1/farms') {
          return http.Response(
            jsonEncode([
              {'farmId': 'farm-001', 'name': 'Trang trại Dalat', 'address': 'Lâm Đồng', 'totalAreaM2': 5000},
            ]),
            200,
          );
        }
        if (r.url.path == '/api/v1/farms/farm-001/fields') {
          return http.Response(
            jsonEncode([
              {'fieldId': 'field-001', 'farmId': 'farm-001', 'name': 'Khu A', 'areaM2': 2500},
            ]),
            200,
          );
        }
        if (r.url.path == '/api/v1/fields/field-001/zones') {
          return http.Response(
            jsonEncode([
              {
                'zoneId': 'zone-1',
                'fieldId': 'field-001',
                'name': 'Zone 1',
                'currentCrop': 'Xà lách',
                'currentStage': 'Cây con',
                'areaM2': 500,
              },
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      };

      final provider = FarmProvider();
      provider.switchRole('FARMER');
      await provider.fetchFromApi();

      // Must be empty list, NO fallback to allZones or demo data
      expect(provider.assignedZonesForCurrentFarmer, isEmpty);
      expect(provider.canControlZone('zone-1'), isFalse);

      provider.dispose();
    });

    test('Owner role has full control over all zones and calls users list', () async {
      handler = (r) {
        if (r.url.path == '/api/v1/users/me') {
          return http.Response(
            jsonEncode({
              'userId': 'owner-001',
              'fullName': 'Chủ Trang Trại A',
              'email': 'owner@smartfarm.vn',
              'role': 'FarmOwner',
            }),
            200,
          );
        }
        if (r.url.path == '/api/v1/farms') {
          return http.Response(
            jsonEncode([
              {'farmId': 'farm-001', 'name': 'Farm 1', 'address': 'A', 'totalAreaM2': 1000},
            ]),
            200,
          );
        }
        if (r.url.path == '/api/v1/farms/farm-001/fields') {
          return http.Response('[]', 200);
        }
        if (r.url.path == '/api/v1/users') {
          return http.Response(
            jsonEncode([
              {'userId': 'farmer-001', 'fullName': 'Nông Dân 1', 'role': 'Farmer'},
            ]),
            200,
          );
        }
        return http.Response('[]', 200);
      };

      final provider = FarmProvider();
      provider.switchRole('OWNER');
      await provider.fetchFromApi();

      final usersCalls = calls.where((c) => c.url.path == '/api/v1/users');
      expect(usersCalls, isNotEmpty);
      expect(provider.canControlZone('any-zone-id'), isTrue);

      provider.dispose();
    });
  });

  group('2. Telemetry History & Sensor Cards', () {
    test('FarmApi.getTelemetryHistory correctly returns data from API', () async {
      handler = (r) {
        if (r.url.path.contains('/telemetry/history')) {
          return http.Response(
            jsonEncode({
              'zoneId': 'zone-001',
              'parameterCode': 'SoilMoisture',
              'interval': '1h',
              'data': [
                {
                  'bucketStartUtc': '2026-11-09T08:00:00Z',
                  'average': 65.5,
                  'minimum': 60.0,
                  'maximum': 70.0,
                  'count': 6,
                },
                {
                  'bucketStartUtc': '2026-11-09T09:00:00Z',
                  'average': 64.2,
                  'minimum': 59.0,
                  'maximum': 68.0,
                  'count': 6,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('[]', 200);
      };

      final data = await FarmApi.getTelemetryHistory(zoneId: 'zone-001', parameterCode: 'SoilMoisture');

      expect(data.length, 2);
      expect((data.first['average'] as num).toDouble(), 65.5);
    });

    test('FarmApi.getTelemetryHistory returns empty list when API returns empty data', () async {
      handler = (r) {
        if (r.url.path.contains('/telemetry/history')) {
          return http.Response(
            jsonEncode({'zoneId': 'zone-001', 'parameterCode': 'SoilMoisture', 'interval': '1h', 'data': []}),
            200,
          );
        }
        return http.Response('[]', 200);
      };

      final data = await FarmApi.getTelemetryHistory(zoneId: 'zone-001', parameterCode: 'SoilMoisture');

      expect(data, isEmpty);
    });
  });

  group('3. Register Screen Role Validation', () {
    testWidgets('RegisterScreen only offers Farmer and FarmOwner in dropdown (no Technician)', (tester) async {
      await tester.pumpWidget(MaterialApp(home: RegisterScreen(onRegisterSuccess: () {})));
      await tester.pumpAndSettle();

      // Open the Dropdown
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Verify Farmer and FarmOwner are present
      expect(find.text('👤 Nông dân thực địa (Worker)'), findsWidgets);
      expect(find.text('👑 Chủ trang trại (Farm Owner)'), findsWidgets);

      // Verify Technician is strictly NOT an option
      expect(find.textContaining('Kỹ thuật viên IoT (Technician)'), findsNothing);

      // Verify explanatory text about PlatformTechnician being admin-provisioned
      expect(find.textContaining('PlatformTechnician'), findsOneWidget);
    });
  });

  group('4. Role-based Menu Access and 403 handling', () {
    testWidgets('ReportsScreen handles 403 Forbidden gracefully without crash', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('OWNER');
      provider.setSelectedFarmIdForTesting('farm-001');

      handler = (r) {
        if (r.url.path.contains('/report/')) {
          return http.Response(jsonEncode({'message': 'Forbidden'}), 403);
        }
        return http.Response('[]', 200);
      };

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Should show clear permission denied message
      expect(find.textContaining('không có quyền truy cập Báo cáo'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('Non-owner is blocked upfront in ReportsScreen', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('FARMER');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Yêu cầu tài khoản Chủ trang trại'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('MqttStatusScreen handles non-authorized roles and 403', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('FARMER');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const MqttStatusScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Yêu cầu tài khoản Chủ trang trại hoặc Kỹ thuật viên'), findsOneWidget);
      provider.dispose();
    });

    testWidgets('ProfileScreen hides Reports and MQTT from Farmer', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('FARMER');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Báo cáo VietGAP should NOT be visible to Farmer
      expect(find.text('Báo cáo & Xuất dữ liệu VietGAP'), findsNothing);
      // MQTT Status should NOT be visible to Farmer
      expect(find.text('Trạng thái kết nối MQTT'), findsNothing);

      provider.dispose();
    });

    testWidgets('ProfileScreen shows Reports and MQTT to FarmOwner', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('OWNER');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo & Xuất dữ liệu VietGAP'), findsOneWidget);
      expect(find.text('Trạng thái kết nối MQTT'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('ProfileScreen shows MQTT but hides Reports for PlatformTechnician', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('TECHNICIAN');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo & Xuất dữ liệu VietGAP'), findsNothing);
      expect(find.text('Trạng thái kết nối MQTT'), findsOneWidget);

      provider.dispose();
    });
  });

  group('5. Farmer Dashboard Diary Session Badge', () {
    testWidgets('FarmerDashboardScreen shows unsynced session status note and badges', (tester) async {
      final provider = FarmProvider();
      provider.switchRole('FARMER');
      provider.setMeForTesting({
        'userId': 'f1',
        'fullName': 'Farmer One',
        'email': 'f1@smartfarm.vn',
        'role': 'Farmer',
        'zoneAccess': [
          {'zoneId': 'z1', 'canControl': true},
        ],
      });
      provider.setZonesForTesting([
        ZoneModel(
          zoneId: 'z1',
          farmId: 'farm1',
          name: 'Zone Cà chua',
          currentCrop: 'Cà chua',
          currentStage: 'Ra hoa',
          areaM2: 500,
          currentSoilMoisture: 70,
          currentTemp: 25,
          currentHumidity: 60,
          currentLux: 500,
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<FarmProvider>.value(value: provider, child: const FarmerDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tab 3: Nhật Ký
      final diaryTab = find.text('Nhật Ký');
      expect(diaryTab, findsOneWidget);
      await tester.tap(diaryTab);
      await tester.pumpAndSettle();

      // Verify clear disclaimer that diary is only stored locally during session
      expect(find.textContaining('máy chủ chưa có API nhật ký'), findsOneWidget);

      provider.dispose();
    });
  });
}
