import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/honeycomb_estimate.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_honeycomb_estimate_card.dart';

// Bản sao dữ liệu thật của DB dev (xem honeycomb_estimate_test.dart).
const _gw = {
  'id': '1',
  'code': 'HW-GW-01',
  'name': 'LoRaWAN Gateway Cong Nghiep 8-Channel',
  'category': 'Gateway',
  'model': 'LG308N',
  'quantityInStock': 15,
  'unitPrice': 4500000,
  'status': 'InStock',
};
const _probe = {
  'id': '2',
  'code': 'HW-SN-01',
  'name': 'Cam bien Dat 5 trong 1',
  'category': 'Sensor',
  'model': 'RS485-SOIL-5IN1',
  'quantityInStock': 40,
  'unitPrice': 1850000,
  'status': 'InStock',
};

Future<http.Response> Function(http.Request) _handler = (r) async =>
    http.Response('[]', 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  Future<void> pumpCard(WidgetTester tester, Widget card) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
  }

  Widget card({
    Key? key,
    double area = 4500,
    ValueChanged<HoneycombEstimate?>? onEstimate,
  }) => ZoneHoneycombEstimateCard(
    key: key,
    areaM2: area,
    cropName: 'Cà chua',
    measurementParameters: const ['Temperature', 'Ph'],
    onEstimate: onEstimate,
  );

  testWidgets(
    'dữ liệu DB thật: hiện tên/model/giá Gateway; node/van/phụ kiện báo thiếu; không có tổng; không có thanh kéo/nút tải',
    (tester) async {
      _handler = (r) async => http.Response(jsonEncode([_gw, _probe]), 200);
      HoneycombEstimate? emitted;
      await http.runWithClient(() async {
        await pumpCard(tester, card(onEstimate: (e) => emitted = e));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.textContaining('LG308N'), findsWidgets);
        expect(find.textContaining('4.500.000 đ'), findsWidgets);
        expect(find.textContaining('Node cảm biến'), findsWidgets);
        // 3 dòng chi tiết (node, van, phụ kiện) + 2 thẻ tóm tắt (node, van) cùng báo thiếu dữ liệu.
        expect(find.text('Chưa có dữ liệu'), findsNWidgets(5));
        expect(find.textContaining('Chưa tính được tổng'), findsOneWidget);
        expect(find.textContaining('TỔNG CHI PHÍ ƯỚC TÍNH'), findsNothing);
        expect(find.byType(Slider), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(ElevatedButton), findsNothing);
        expect(
          find.textContaining('chưa phải báo giá hay hợp đồng'),
          findsOneWidget,
        );
        expect(emitted?.total, isNull);
        expect(emitted?.gatewayCost, 4500000);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((req) => _handler(req)));
    },
  );

  testWidgets(
    'lỗi 403: báo lỗi rõ, không có giá/tổng, không có nút tải lại; không gọi lặp khi rebuild',
    (tester) async {
      var calls = 0;
      _handler = (r) async {
        calls++;
        return http.Response(jsonEncode({'title': 'Forbidden'}), 403);
      };
      await http.runWithClient(() async {
        await pumpCard(tester, card());
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.textContaining('không có quyền'), findsOneWidget);
        expect(find.textContaining('4.500.000'), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        // rebuild nhiều lần (đổi diện tích) không gọi lại API
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: card(area: 6000)),
            ),
          ),
        );
        await tester.pump();
        expect(calls, 1);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((req) => _handler(req)));
    },
  );

  testWidgets('response sai cấu trúc: báo rõ, không hiện danh mục rỗng giả', (
    tester,
  ) async {
    _handler = (r) async => http.Response(jsonEncode({'oops': 1}), 200);
    await http.runWithClient(() async {
      await pumpCard(tester, card());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      expect(find.textContaining('sai cấu trúc'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient((req) => _handler(req)));
  });

  testWidgets(
    'đổi Zone nhanh: phản hồi của Zone cũ về trễ bị bỏ qua, không ghi đè dữ liệu Zone mới',
    (tester) async {
      final slow = Completer<http.Response>();
      var n = 0;
      _handler = (r) {
        n++;
        return n == 1
            ? slow.future
            : Future.value(http.Response(jsonEncode([_gw]), 200));
      };
      final emitted = <double?>[];
      await http.runWithClient(() async {
        await pumpCard(
          tester,
          card(
            key: const ValueKey('zone-A'),
            onEstimate: (e) => emitted.add(e?.gatewayCost),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: card(
                  key: const ValueKey('zone-B'),
                  onEstimate: (e) => emitted.add(e?.gatewayCost),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.textContaining('4.500.000 đ'), findsWidgets);
        // phản hồi Zone A đến muộn (giá khác) -> không được ảnh hưởng
        slow.complete(
          http.Response(
            jsonEncode([
              {..._gw, 'unitPrice': 999},
            ]),
            200,
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.textContaining('999 đ'), findsNothing);
        expect(emitted, [4500000.0]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((req) => _handler(req)));
    },
  );

  testWidgets(
    'đầy đủ dữ liệu: có tổng khớp từng dòng; không tràn ngang ở 320px, chữ 1.3×',
    (tester) async {
      final node = {
        'id': '3',
        'code': 'N-1',
        'name': 'Node cam bien LoRa hoan chinh nhieu chu de kiem tra tran dong',
        'category': 'Sensor',
        'model': 'MODEL-DAI-123456',
        'quantityInStock': 0,
        'unitPrice': '3000000',
        'status': 'InStock',
        'estimateRole': 'SensorNode',
        'estimateUnits': 1,
        'measuredParameters': ['Temperature', 'Ph', 'Ec'],
      };
      final relay = {
        'id': '4',
        'code': 'R-4',
        'name': 'Hop Relay 4 Kenh',
        'category': 'Actuator',
        'model': 'LSP-RELAY4',
        'quantityInStock': 25,
        'unitPrice': 1200000,
        'status': 'InStock',
        'estimateRole': 'ActuatorNode',
        'estimateUnits': 4,
      };
      final kit = {
        'id': '5',
        'code': 'K-1',
        'name': 'Bo phu kien',
        'category': 'Peripheral',
        'quantityInStock': 9,
        'unitPrice': 150000,
        'status': 'InStock',
        'estimateRole': 'InstallKit',
        'estimateUnits': 1,
      };
      _handler = (r) async =>
          http.Response(jsonEncode([_gw, _probe, node, relay, kit]), 200);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(1.3),
              ),
              child: Scaffold(body: SingleChildScrollView(child: card())),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(find.textContaining('TỔNG CHI PHÍ ƯỚC TÍNH'), findsOneWidget);
        expect(find.textContaining('22.400.000 đ'), findsWidgets);
        expect(find.text('Chưa có dữ liệu'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((req) => _handler(req)));
    },
  );

  testWidgets(
    'có zoneId: tải cả thiết bị đã gắn, chỉ tính phần bổ sung và hiện số đã gắn',
    (tester) async {
      final catalog = [
        {
          'id': 'g',
          'code': 'GW',
          'name': 'Gateway',
          'category': 'Gateway',
          'unitPrice': 3800000,
          'status': 'InStock',
          'estimateRole': 'Gateway',
          'estimateUnits': 1,
        },
        {
          'id': 'n',
          'code': 'NODE',
          'name': 'Node',
          'category': 'Sensor',
          'unitPrice': 1000000,
          'status': 'InStock',
          'estimateRole': 'SensorNode',
          'estimateUnits': 1,
          'measuredParameters': ['Temperature', 'Ph'],
        },
        {
          'id': 'v',
          'code': 'VALVE',
          'name': 'Van',
          'category': 'Valve',
          'unitPrice': 2000000,
          'status': 'InStock',
          'estimateRole': 'ActuatorNode',
          'estimateUnits': 1,
        },
        {
          'id': 'k',
          'code': 'KIT',
          'name': 'Phu kien',
          'category': 'Kit',
          'unitPrice': 100000,
          'status': 'InStock',
          'estimateRole': 'InstallKit',
          'estimateUnits': 1,
        },
      ];
      final devices = [
        for (var i = 0; i < 3; i++)
          {
            'deviceType': 'SensorNode',
            'gatewayId': 'g1',
            'status': 'Online',
            'sensors': ['Temperature', 'Ph'],
          },
        {
          'deviceType': 'ActuatorNode',
          'gatewayId': 'g1',
          'status': 'Online',
          'sensors': [],
        },
      ];
      final paths = <String>[];
      _handler = (r) async {
        paths.add(r.url.path);
        return http.Response(
          jsonEncode(r.url.path.endsWith('/devices') ? devices : catalog),
          200,
        );
      };
      await http.runWithClient(() async {
        await pumpCard(
          tester,
          ZoneHoneycombEstimateCard(
            zoneId: 'z1',
            areaM2: 2500,
            cropName: 'Cà chua',
            measurementParameters: const ['Temperature', 'Ph'],
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(
          paths,
          containsAll([
            '/api/v1/zones/z1/devices',
            '/api/v1/platform/hardware-items',
          ]),
        );
        expect(
          find.textContaining(
            'Đã gắn trong Zone: 1 gateway, 3 node cảm biến, 1 node van/bơm',
          ),
          findsOneWidget,
        );
        // cần 2 van, đã gắn 1 → bổ sung 1 van (2.000.000) + 1 phụ kiện (100.000) + thi công 500.000 = 2.600.000
        expect(find.textContaining('2.600.000 đ'), findsWidgets);
        expect(find.textContaining('TỔNG CHI PHÍ ƯỚC TÍNH'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((req) => _handler(req)));
    },
  );

  testWidgets(
    'có zoneId nhưng không tải được thiết bị đã gắn: báo lỗi, KHÔNG hiện giá (tránh dự toán thừa)',
    (tester) async {
      _handler = (r) async => r.url.path.endsWith('/devices')
          ? http.Response(jsonEncode({'title': 'Forbidden'}), 403)
          : http.Response(jsonEncode([_gw]), 200);
      await http.runWithClient(() async {
        await pumpCard(
          tester,
          ZoneHoneycombEstimateCard(
            zoneId: 'z1',
            areaM2: 2500,
            cropName: 'Cà chua',
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
        expect(
          find.textContaining('Không lấy được danh mục thiết bị'),
          findsOneWidget,
        );
        expect(find.textContaining('4.500.000'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient((req) => _handler(req)));
    },
  );
}
