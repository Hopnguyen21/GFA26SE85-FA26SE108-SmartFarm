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

http.Response _json(Object o) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _contract(String no, String status, DateTime end) => {
  'id': no,
  'zoneId': 'z1',
  'zoneName': 'Zone 1',
  'contractNumber': no,
  'status': status,
  'startDate': '2025-01-01',
  'endDate': _ymd(end),
  'daysRemaining': end.difference(DateTime.now()).inDays,
  'lesseeName': 'Owner',
  'monthlyRentVnd': 1000000,
  'depositVnd': 0,
  'totalContractValueVnd': 12000000,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var contracts = <Map<String, dynamic>>[];

  Future<http.Response> handler(http.Request r) async {
    if (r.url.path == '/api/v1/zones/z1/contracts') return _json(contracts);
    return http.Response('[]', 200);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'o@b.c',
      role: 'FarmOwner',
    );
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient(handler),
    );
  });

  testWidgets(
    'Owner: hợp đồng còn hạn có nút "Yêu cầu gia hạn"; hợp đồng đã hết hạn chỉ có "Tạo yêu cầu mới"',
    (tester) async {
      contracts = [
        _contract(
          'HD-CON-HAN',
          'Active',
          DateTime.now().add(const Duration(days: 200)),
        ),
        _contract(
          'HD-HET-HAN',
          'Expired',
          DateTime.now().subtract(const Duration(days: 30)),
        ),
      ];
      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final zone = ZoneModel.fromJson(
        {'zoneId': 'z1', 'name': 'Zone 1', 'areaM2': 10},
        farmId: 'f1',
        fieldId: 'fl1',
        farmName: 'Farm',
      );
      final provider = FarmProvider()..switchRole('OWNER');
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              home: ContractsDepreciationScreen(lockedZone: zone),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('HD-CON-HAN'), findsWidgets);
        expect(find.textContaining('HD-HET-HAN'), findsWidgets);
        expect(find.text('Yêu cầu gia hạn'), findsOneWidget);
        expect(find.text('Tạo yêu cầu mới'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        await tester.pump(const Duration(seconds: 12));
      }, () => MockClient(handler));
    },
  );
}
