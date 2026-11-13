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
import 'package:smartfarm_mobile/features/zones/widgets/zone_contracts_section.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_seasons_section.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_support_section.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final _zone = ZoneModel.fromJson(
  {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
  farmId: 'f1',
  fieldId: 'fl1',
  farmName: 'Trang trại A',
);

FarmProvider? _provider;

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = _provider = FarmProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
  _provider?.dispose();
  _provider = null;
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
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('vụ trồng của Zone', () {
    testWidgets(
      'chỉ hiện vụ của Zone này; nút theo trạng thái; ID "null" không mở được giai đoạn',
      (tester) async {
        handler = (r) async {
          if (r.url.path == '/api/v1/planting-seasons') {
            return utf8Json([
              {
                'seasonId': 's1',
                'zoneId': 'z1',
                'name': 'Vụ đang chạy',
                'status': 'InProgress',
                'cropName': 'Dưa lưới',
                'growthProfileId': 'p1',
                'growthProfileName': 'VietGAP',
                'currentGrowthStageName': 'Cây con',
                'startDate': '2026-11-01',
                'expectedEndDate': '2027-01-20',
              },
              {
                'seasonId': 's2',
                'zoneId': 'z1',
                'name': 'Vụ đã hủy',
                'status': 'Cancelled',
                'cropName': 'Cà chua',
                'growthProfileId': null,
                'startDate': '2026-01-01',
                'expectedEndDate': '2026-03-01',
              },
              {
                'seasonId': 's3',
                'zoneId': 'khac',
                'name': 'Vụ của Zone khác',
                'status': 'InProgress',
                'startDate': '2026-11-02',
              },
            ]);
          }
          return utf8Json([]);
        };
        await _pump(tester, ZoneSeasonsSection(zone: _zone));

        expect(find.text('Vụ đang chạy'), findsOneWidget);
        expect(find.text('Vụ đã hủy'), findsOneWidget);
        expect(
          find.text('Vụ của Zone khác'),
          findsNothing,
          reason: 'không lấy vụ của Zone khác',
        );
        expect(find.text('Đang canh tác'), findsOneWidget);
        expect(find.text('Đã hủy'), findsOneWidget);
        expect(
          find.text('Lịch tưới theo ngày'),
          findsOneWidget,
          reason: 'chỉ vụ Planned/InProgress có lịch tưới',
        );
        expect(
          find.text('Ghi sản lượng'),
          findsOneWidget,
          reason: 'vụ đã hủy không ghi sản lượng',
        );
        expect(find.text('Giai đoạn (thiếu hồ sơ)'), findsOneWidget);
        final stageButton = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Giai đoạn (thiếu hồ sơ)'),
        );
        expect(stageButton.onPressed, isNull);
        expect(find.text('Tạo vụ trồng cho Zone này'), findsOneWidget);
        expect(
          calls.any((c) => c.url.queryParameters['zoneId'] == 'z1'),
          isTrue,
        );
        expect(
          calls.any((c) => c.url.toString().contains('farmingSeasonId')),
          isFalse,
        );
        await _dispose(tester);
      },
    );

    testWidgets('chưa có vụ: trạng thái rỗng; lỗi tải: có thử lại', (
      tester,
    ) async {
      handler = (_) async => utf8Json([]);
      await _pump(tester, ZoneSeasonsSection(zone: _zone));
      expect(find.text('Zone chưa có vụ trồng nào.'), findsOneWidget);
      await _dispose(tester);

      handler = (_) async => utf8Json({'message': 'Máy chủ bận'}, 500);
      await _pump(tester, ZoneSeasonsSection(zone: _zone));
      expect(find.textContaining('Không tải được vụ trồng'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      await _dispose(tester);
    });

    test('validId loại bỏ null, rỗng và chuỗi "null"', () {
      expect(validId(null), isNull);
      expect(validId(''), isNull);
      expect(validId('null'), isNull);
      expect(validId(' NULL '), isNull);
      expect(validId('abc'), 'abc');
    });
  });

  group('hợp đồng của Zone', () {
    testWidgets(
      'gọi API theo zoneId, lọc đúng Zone, hiển thị dữ liệu thật và nút tạo cho Owner',
      (tester) async {
        handler = (r) async {
          if (r.url.path == '/api/v1/zones/z1/contracts') {
            return utf8Json([
              {
                'id': 'c1',
                'zoneId': 'z1',
                'contractNumber': 'HD-2026-001',
                'startDate': '2026-01-01',
                'endDate': '2026-12-31',
                'status': 'Active',
                'statusText': 'Đang hiệu lực',
                'lesseeName': 'Công ty A',
              },
              {'id': 'c2', 'zoneId': 'khac', 'contractNumber': 'HD-KHAC'},
            ]);
          }
          return utf8Json([]);
        };
        await _pump(tester, ZoneContractsSection(zone: _zone, canManage: true));
        expect(find.text('HD-2026-001'), findsOneWidget);
        expect(find.text('HD-KHAC'), findsNothing);
        expect(find.text('Đang hiệu lực'), findsOneWidget);
        expect(find.text('Gửi yêu cầu hỗ trợ kỹ thuật'), findsOneWidget);
        expect(
          calls.any((c) => c.url.path == '/api/v1/zones/z1/contracts'),
          isTrue,
        );
        expect(
          calls.any((c) => c.url.path == '/api/v1/zone-contracts'),
          isFalse,
          reason: 'không tải toàn bộ hợp đồng',
        );
        await _dispose(tester);
      },
    );

    testWidgets(
      'chưa có hợp đồng: rỗng + nút tạo; Technician không có nút tạo; lỗi 403 hiện thông báo',
      (tester) async {
        handler = (_) async => utf8Json([]);
        await _pump(tester, ZoneContractsSection(zone: _zone, canManage: true));
        expect(find.textContaining('Zone chưa có hợp đồng.'), findsOneWidget);
        expect(find.text('Gửi yêu cầu hỗ trợ kỹ thuật'), findsOneWidget);
        await _dispose(tester);

        await _pump(
          tester,
          ZoneContractsSection(zone: _zone, canManage: false),
        );
        expect(find.textContaining('Tạo hợp đồng'), findsNothing);
        await _dispose(tester);

        handler = (_) async =>
            utf8Json({'message': 'Bạn không có quyền xem hợp đồng'}, 403);
        await _pump(
          tester,
          ZoneContractsSection(zone: _zone, canManage: false),
        );
        expect(find.textContaining('Không tải được hợp đồng'), findsOneWidget);
        await _dispose(tester);
      },
    );
  });

  group('hỗ trợ kỹ thuật của Zone', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.text('Gửi yêu cầu hỗ trợ kỹ thuật'));
      await tester.pumpAndSettle();
    }

    void route({http.Response Function(http.Request)? onPost}) {
      handler = (r) async {
        if (r.method == 'POST' &&
            r.url.path == '/api/v1/farms/f1/service-requests') {
          return onPost?.call(r) ??
              utf8Json({'id': 'abcdef12-0000', 'status': 'Open'}, 201);
        }
        if (r.url.path == '/api/v1/service-requests') {
          return utf8Json([
            {
              'id': 'r1',
              'zoneId': 'z1',
              'failureCode': 'SENSOR_OFFLINE',
              'description': 'Mất kết nối',
              'status': 'Open',
            },
            {
              'id': 'r2',
              'zoneId': 'khac',
              'failureCode': 'OTHER',
              'description': 'Zone khác',
              'status': 'Open',
            },
          ]);
        }
        if (r.url.path == '/api/v1/zones/z1/devices') {
          return utf8Json([
            {
              'deviceId': 'd1',
              'zoneId': 'z1',
              'hardwareAddress': 'AA:01',
              'deviceType': 'SensorNode',
            },
          ]);
        }
        return utf8Json([]);
      };
    }

    testWidgets(
      'nút đúng nhãn; chỉ liệt kê yêu cầu của Zone; gửi đúng API với Farm/Zone/thiết bị của Zone',
      (tester) async {
        route();
        await _pump(tester, ZoneSupportSection(zone: _zone, canCreate: true));
        expect(find.text('Gửi yêu cầu hỗ trợ kỹ thuật'), findsOneWidget);
        expect(find.text('Cảm biến mất kết nối'), findsOneWidget);
        expect(find.text('Zone khác'), findsNothing);

        await openForm(tester);
        expect(
          find.textContaining('Trang trại A › Nhà màng 1'),
          findsOneWidget,
        );
        await tester.tap(find.text('Không chọn thiết bị cụ thể'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('AA:01').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'Cảm biến độ ẩm không gửi số liệu từ sáng',
        );
        await tester.tap(find.text('Gửi'));
        await tester.pumpAndSettle();

        final post = calls.singleWhere((c) => c.method == 'POST');
        final body = jsonDecode(post.body) as Map<String, dynamic>;
        expect(post.url.path, '/api/v1/farms/f1/service-requests');
        expect(body['zoneId'], 'z1');
        expect(body['deviceId'], 'd1');
        expect(body['failureCode'], 'SENSOR_OFFLINE');
        expect(body.containsKey('farmingSeasonId'), isFalse);
        expect(
          find.textContaining(
            'Đã gửi yêu cầu hỗ trợ kỹ thuật (mã abcdef12) · trạng thái: Open',
          ),
          findsOneWidget,
        );
        await _dispose(tester);
      },
    );

    testWidgets(
      'thiếu mô tả: chặn; lỗi 409/403: giữ nội dung form và hiện lý do; không gửi lặp khi đang xử lý',
      (tester) async {
        route(
          onPost: (_) => utf8Json({
            'message': 'Thiết bị đang có yêu cầu hỗ trợ chưa đóng',
          }, 409),
        );
        await _pump(tester, ZoneSupportSection(zone: _zone, canCreate: true));
        await openForm(tester);
        await tester.tap(find.text('Gửi'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Hãy mô tả sự cố'), findsOneWidget);
        expect(calls.where((c) => c.method == 'POST'), isEmpty);

        await tester.enterText(
          find.byType(TextField),
          'Nội dung mô tả giữ nguyên khi lỗi',
        );
        await tester.tap(find.text('Gửi'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Thiết bị đang có yêu cầu hỗ trợ chưa đóng'),
          findsOneWidget,
        );
        expect(
          find.text('Nội dung mô tả giữ nguyên khi lỗi'),
          findsOneWidget,
          reason: 'giữ nội dung form',
        );
        expect(calls.where((c) => c.method == 'POST'), hasLength(1));
        await _dispose(tester);
      },
    );

    testWidgets(
      'không có quyền tạo (Technician): không có nút gửi, vẫn xem được danh sách',
      (tester) async {
        route();
        await _pump(tester, ZoneSupportSection(zone: _zone, canCreate: false));
        expect(find.text('Gửi yêu cầu hỗ trợ kỹ thuật'), findsNothing);
        expect(find.text('Cảm biến mất kết nối'), findsOneWidget);
        await _dispose(tester);
      },
    );
  });
}
