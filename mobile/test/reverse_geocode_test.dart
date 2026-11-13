import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/widgets/address_autofill.dart';
import 'package:smartfarm_mobile/core/widgets/mini_gis_map_picker.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

List<int> body(Object o) => utf8.encode(jsonEncode(o));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final tmp = Directory.systemTemp.createTempSync('geo_test').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp,
        );
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
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('GeocodeResult.fromHttp (khớp GeocodingAddressView của backend)', () {
    test('200 camelCase: lấy displayName và vùng', () {
      final r = GeocodeResult.fromHttp(
        200,
        body({'displayName': 'Xã A, Huyện B, Lâm Đồng', 'district': 'Huyện B'}),
      );
      expect(r.ok, isTrue);
      expect(r.displayName, 'Xã A, Huyện B, Lâm Đồng');
      expect(r.region, 'Huyện B');
    });

    test('200 PascalCase vẫn đọc được; vùng lùi về city rồi province', () {
      final r = GeocodeResult.fromHttp(
        200,
        body({'DisplayName': 'Đà Lạt', 'City': 'Đà Lạt'}),
      );
      expect(r.displayName, 'Đà Lạt');
      expect(r.region, 'Đà Lạt');
    });

    test('200 nhưng không có displayName → badResponse, không có địa chỉ', () {
      final r = GeocodeResult.fromHttp(200, body({'road': 'x'}));
      expect(r.ok, isFalse);
      expect(r.failure, GeocodeFailureKind.badResponse);
      expect(
        GeocodeResult.fromHttp(200, utf8.encode('<html>')).failure,
        GeocodeFailureKind.badResponse,
      );
    });

    test('mã lỗi → loại lỗi đúng', () {
      expect(
        GeocodeResult.fromHttp(
          404,
          body({'message': 'Không tìm thấy địa chỉ cho tọa độ này.'}),
        ).failure,
        GeocodeFailureKind.notFound,
      );
      expect(
        GeocodeResult.fromHttp(404, const []).failure,
        GeocodeFailureKind.routeMissing,
      );
      expect(
        GeocodeResult.fromHttp(401, const []).failure,
        GeocodeFailureKind.unauthorized,
      );
      expect(
        GeocodeResult.fromHttp(403, const []).failure,
        GeocodeFailureKind.forbidden,
      );
      expect(
        GeocodeResult.fromHttp(429, const []).failure,
        GeocodeFailureKind.rateLimited,
      );
      expect(
        GeocodeResult.fromHttp(400, const []).failure,
        GeocodeFailureKind.invalidCoordinate,
      );
      expect(
        GeocodeResult.fromHttp(500, const []).failure,
        GeocodeFailureKind.server,
      );
      expect(GeocodeResult.fromHttp(404, const []).message, isNotEmpty);
    });

    test(
      'backend 502/504/429 (lỗi nhà cung cấp) không bị coi là "không tìm thấy" và giữ thông điệp backend',
      () {
        final bad = GeocodeResult.fromHttp(
          502,
          body({
            'message': 'Không kết nối được DNS',
            'code': 'GEOCODE_UNAVAILABLE',
          }),
        );
        expect(bad.failure, GeocodeFailureKind.providerUnavailable);
        expect(bad.message, 'Không kết nối được DNS');
        expect(
          GeocodeResult.fromHttp(503, const []).failure,
          GeocodeFailureKind.providerUnavailable,
        );
        expect(
          GeocodeResult.fromHttp(504, body({'message': 'chậm'})).failure,
          GeocodeFailureKind.timeout,
        );
        expect(
          GeocodeResult.fromHttp(429, body({'message': 'x'})).failure,
          GeocodeFailureKind.rateLimited,
        );
        expect(
          GeocodeResult.fromHttp(
            404,
            body({'message': 'm', 'code': 'GEOCODE_NOT_FOUND'}),
          ).failure,
          GeocodeFailureKind.notFound,
        );
      },
    );
  });

  group('FarmApi.reverseGeocodeDetailed', () {
    test(
      'gọi POST /api/v1/gis/reverse-geocode qua backend và trả displayName',
      () async {
        handler = (_) async =>
            utf8Json({'displayName': 'Phường 1, Đà Lạt', 'district': 'Đà Lạt'});
        final r = await FarmApi.reverseGeocodeDetailed(11.94, 108.45);
        final req = calls.single;
        expect(req.method, 'POST');
        expect(req.url.path, '/api/v1/gis/reverse-geocode');
        expect(
          req.url.host,
          isNot(contains('nominatim')),
        ); // không gọi thẳng nhà cung cấp từ mobile
        expect(jsonDecode(req.body), {'latitude': 11.94, 'longitude': 108.45});
        expect(r.displayName, 'Phường 1, Đà Lạt');
      },
    );

    test(
      '404 / 500 / timeout / mất kết nối → không có địa chỉ, đúng loại lỗi',
      () async {
        handler = (_) async => utf8Json({'message': 'x'}, 404);
        expect(
          (await FarmApi.reverseGeocodeDetailed(1, 1)).failure,
          GeocodeFailureKind.notFound,
        );
        handler = (_) async => http.Response('', 500);
        expect(
          (await FarmApi.reverseGeocodeDetailed(1, 1)).failure,
          GeocodeFailureKind.server,
        );
        handler = (_) async => throw TimeoutException('slow');
        expect(
          (await FarmApi.reverseGeocodeDetailed(1, 1)).failure,
          GeocodeFailureKind.timeout,
        );
        handler = (_) async => throw const SocketException('refused');
        final net = await FarmApi.reverseGeocodeDetailed(1, 1);
        expect(net.failure, GeocodeFailureKind.network);
        expect(net.displayName, isNull);
      },
    );

    test(
      'reverseGeocode cũ trả null khi thất bại, không bịa dữ liệu',
      () async {
        handler = (_) async => http.Response('', 500);
        expect(await FarmApi.reverseGeocode(1, 1), isNull);
      },
    );
  });

  group('Base URL trên Windows desktop', () {
    test(
      'debug dùng localhost:5144 (không dùng 10.0.2.2 của Android emulator)',
      () {
        expect(Platform.isAndroid, isFalse);
        expect(ApiService.defaultBaseUrl, 'http://localhost:5144');
        ApiService.setBaseUrl('http://localhost:5144');
        expect(ApiService.baseUrl, 'http://localhost:5144');
      },
    );

    test('release vẫn bắt buộc HTTPS và host tin cậy (không nới bảo mật)', () {
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'http://localhost:5144',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
      expect(
        () => ApiService.validateAndNormalizeBaseUrl(
          'https://evil.example.com',
          isRelease: true,
        ),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('AddressAutofill', () {
    test('địa chỉ thật được điền vào ô', () {
      final c = TextEditingController();
      final a = AddressAutofill(c)..onLoading();
      expect(
        c.text,
        isEmpty,
        reason: 'trạng thái đang tải không được ghi chữ vào ô',
      );
      a.onResolved('Xã A, Lâm Đồng');
      expect(c.text, 'Xã A, Lâm Đồng');
      expect(a.loading, isFalse);
    });

    test('onFailed một mình giữ nguyên ô (rỗng hoặc đã nhập) và báo lý do', () {
      final c = TextEditingController(text: 'Địa chỉ tôi tự nhập');
      final a = AddressAutofill(c)
        ..onLoading()
        ..onFailed('Không tìm được');
      expect(c.text, 'Địa chỉ tôi tự nhập');
      expect(a.error, 'Không tìm được');
      final empty = TextEditingController();
      AddressAutofill(empty).onFailed('x');
      expect(empty.text, isEmpty);
    });

    test('người dùng đã gõ tay thì kết quả bản đồ không ghi đè', () {
      final c = TextEditingController();
      final a = AddressAutofill(c);
      c.text = 'Thôn 3, tự gõ';
      a.onUserChanged(c.text);
      a.onResolved('Địa chỉ từ bản đồ');
      expect(c.text, 'Thôn 3, tự gõ');
    });

    test(
      'bấm "Lấy tên địa điểm từ ghim" thì được thay; lỗi thì giữ nguyên',
      () async {
        final c = TextEditingController(text: 'Tự gõ');
        final a = AddressAutofill(c)..onUserChanged('Tự gõ');
        await a.retry(
          1,
          2,
          lookup: (_, _) async =>
              GeocodeResult.failed(GeocodeFailureKind.notFound),
        );
        expect(c.text, 'Tự gõ');
        expect(a.error, isNotNull);
        await a.retry(
          1,
          2,
          lookup: (_, _) async => GeocodeResult.success('Địa chỉ mới'),
        );
        expect(c.text, 'Địa chỉ mới');
        expect(a.error, isNull);
      },
    );

    test('kết quả của lần thử cũ không ghi đè lần thử mới', () async {
      final c = TextEditingController();
      final a = AddressAutofill(c);
      final slow = Completer<GeocodeResult>();
      final first = a.retry(1, 1, lookup: (_, _) => slow.future);
      await a.retry(2, 2, lookup: (_, _) async => GeocodeResult.success('Mới'));
      slow.complete(GeocodeResult.success('Cũ'));
      await first;
      expect(c.text, 'Mới');
    });
  });

  group('MiniGISMapPicker', () {
    testWidgets('response của toạ độ cũ không ghi đè địa chỉ của toạ độ mới', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final first = Completer<http.Response>();
      var n = 0;
      handler = (_) {
        n++;
        if (n == 1) return first.future; // request đầu (vị trí khởi tạo): chậm
        return Future.value(utf8Json({'displayName': 'Địa chỉ MỚI'}));
      };
      final resolved = <String>[];
      final failed = <String>[];
      var loading = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniGISMapPicker(
              initialCenter: const LatLng(11.9, 108.4),
              level: 'FARM',
              height: 300,
              onAddressResolved: resolved.add,
              onAddressFailed: failed.add,
              onAddressLoading: () => loading++,
            ),
          ),
        ),
      );
      await tester
          .pump(); // post-frame: request #1 bay đi nhưng chưa có phản hồi
      expect(loading, greaterThan(0));

      await tester.drag(
        find.byType(MiniGISMapPicker),
        const Offset(60, 40),
      ); // dời ghim → request #2
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(resolved, ['Địa chỉ MỚI']);

      first.complete(utf8Json({'displayName': 'Địa chỉ CŨ'})); // về muộn
      await tester.pump();
      await tester.pump();
      expect(resolved, [
        'Địa chỉ MỚI',
      ], reason: 'phản hồi cũ không được gọi onAddressResolved');
      expect(failed, isEmpty);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'API lỗi: không gọi onAddressResolved, gọi onAddressFailed kèm lý do',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        handler = (_) async => utf8Json({'message': 'Không tìm thấy'}, 404);
        final resolved = <String>[];
        final failed = <String>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MiniGISMapPicker(
                initialCenter: const LatLng(11.9, 108.4),
                level: 'FARM',
                height: 300,
                onAddressResolved: resolved.add,
                onAddressFailed: failed.add,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(resolved, isEmpty);
        expect(failed, hasLength(1));
        expect(
          failed.single,
          isNot(contains('11.9')),
          reason: 'lý do lỗi không được là toạ độ',
        );
        expect(
          failed.single,
          isNot(matches(RegExp(r'd+.d+, d+.d+'))),
          reason: 'không ghi toạ độ',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
