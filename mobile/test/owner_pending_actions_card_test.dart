import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/home/widgets/owner_pending_actions_card.dart';

ZoneModel _zone(String id, String name) => ZoneModel(
  zoneId: id,
  farmId: 'f1',
  name: name,
  currentCrop: 'Cà chua',
  currentStage: 'Ra hoa',
  areaM2: 500,
  currentSoilMoisture: 61.5,
  currentTemp: 25,
  currentHumidity: 70,
  currentLux: 500,
  telemetryIsFresh: true,
);

Map<String, dynamic> _sr(String id, String zoneId, String title) => {
  'id': id,
  'zoneId': zoneId,
  'farmId': 'f1',
  'failureCode': 'INSTALLATION',
  'description': title,
  'status': 'Assigned',
};

Map<String, dynamic> _quote(String srId) => {
  'id': 'q-$srId',
  'serviceRequestId': srId,
  'status': 'SentToOwner',
  'items': <Object>[],
  'subtotal': 100,
  'vatAmount': 8,
  'totalAmount': 108,
  'deposit30Percent': 31,
  'remaining70Percent': 77,
};

/// Việc chờ Owner ở thẻ trang chủ chỉ thuộc ĐÚNG Zone đang chọn (hợp đồng của Zone khác không hiện lẫn vào).
void main() {
  http.Response ok(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Client mock() => MockClient((req) async {
    final p = req.url.path;
    if (p.endsWith('/service-requests')) {
      return ok([
        _sr('sr-a-0001', 'zone-a', 'Lắp đặt cho Zone A'),
        _sr('sr-b-0001', 'zone-b', 'Lắp đặt cho Zone B'),
      ]);
    }
    if (p.endsWith('/quotation')) {
      final id = p.split('/').reversed.elementAt(1);
      return ok(_quote(id));
    }
    return http.Response('{}', 404);
  });

  setUpAll(() async {
    await http.runWithClient(() => SupportApi.getServiceRequests(), mock);
  });

  final zones = [_zone('zone-a', 'Zone A'), _zone('zone-b', 'Zone B')];

  Future<void> pump(WidgetTester tester, {String? zoneId}) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnerPendingActionsCard(zones: zones, zoneId: zoneId),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> flush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('chọn Zone A: chỉ hiện hợp đồng của Zone A, kèm tên Zone', (
    tester,
  ) async {
    await pump(tester, zoneId: 'zone-a');
    expect(find.text('Việc cần bạn xử lý (1)'), findsOneWidget);
    expect(find.text('Lắp đặt cho Zone A'), findsOneWidget);
    expect(find.text('Lắp đặt cho Zone B'), findsNothing);
    expect(find.textContaining('Zone A ·'), findsOneWidget);
    await flush(tester);
  });

  testWidgets('chọn Zone B: chỉ hiện hợp đồng của Zone B', (tester) async {
    await pump(tester, zoneId: 'zone-b');
    expect(find.text('Việc cần bạn xử lý (1)'), findsOneWidget);
    expect(find.text('Lắp đặt cho Zone B'), findsOneWidget);
    expect(find.text('Lắp đặt cho Zone A'), findsNothing);
    await flush(tester);
  });

  testWidgets('Zone đang chọn không có hợp đồng nào chờ: thẻ ẩn', (
    tester,
  ) async {
    await pump(tester, zoneId: 'zone-c');
    expect(find.textContaining('Việc cần bạn xử lý'), findsNothing);
    await flush(tester);
  });

  testWidgets('không truyền Zone: giữ hành vi cũ, hiện của mọi Zone', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Việc cần bạn xử lý (2)'), findsOneWidget);
    await flush(tester);
  });
}
