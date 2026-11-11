import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_node_summary_card.dart';

http.Response Function(http.Request) handler = (_) => http.Response('[]', 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // _client là static lazy: khởi tạo lần đầu bên trong runWithClient để dùng MockClient.
    await http.runWithClient(() => SupportApi.getServiceRequests(), () => MockClient((req) async => handler(req)));
  });

  setUp(() => ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner'));

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZoneNodeSummaryCard(zoneId: 'z1', zoneName: 'Nhà màng A'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hiện số node online, pin thấp nhất, sóng yếu nhất từ API', (tester) async {
    handler = (_) => http.Response(
      jsonEncode({
        'zoneId': 'z1',
        'devices': [
          {'deviceId': 'd1', 'status': 'Online', 'batteryLevel': 64, 'rssi': -70, 'metrics': []},
          {'deviceId': 'd2', 'status': 'Offline', 'batteryLevel': 15, 'rssi': -98, 'metrics': []},
        ],
      }),
      200,
    );
    await pumpCard(tester);
    expect(find.text('● 1/2 online'), findsOneWidget);
    expect(find.text('🔋 thấp nhất 15%'), findsOneWidget);
    expect(find.text('📶 yếu nhất -98 dBm'), findsOneWidget);
    // Không còn số liệu giả lập cũ
    expect(find.textContaining('87%'), findsNothing);
  });

  testWidgets('Zone chưa có node thì báo rõ, không bịa số liệu', (tester) async {
    handler = (_) => http.Response(jsonEncode({'zoneId': 'z1', 'devices': []}), 200);
    await pumpCard(tester);
    expect(find.text('Zone chưa có node nào được gán.'), findsOneWidget);
  });

  testWidgets('lỗi API hiện thông báo thử lại', (tester) async {
    handler = (_) => http.Response('', 500);
    await pumpCard(tester);
    expect(find.textContaining('Không tải được trạng thái node'), findsOneWidget);
  });
}
