import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/farms/gis_map_screen.dart';

http.Response Function(http.Request) handler = (_) => http.Response('[]', 200);

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _polygon(List<List<double>> lngLat) => {
  'type': 'Polygon',
  'coordinates': [lngLat],
};

final _square = _polygon([
  [108.0, 11.0],
  [108.1, 11.0],
  [108.1, 11.1],
  [108.0, 11.1],
  [108.0, 11.0],
]);

ZoneModel _zone(Map<String, dynamic> extra) =>
    ZoneModel.fromJson({'zoneId': 'z1', 'name': 'Zone A', 'areaM2': 100, ...extra}, farmId: 'f1', fieldId: 'fl1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // flutter_map ghi cache ô bản đồ qua path_provider; giả lập thư mục tạm để không cần plugin thật.
    final tmp = Directory.systemTemp.createTempSync('gis_test').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp,
    );
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(() => SupportApi.getServiceRequests(), () => MockClient((req) async => handler(req)));
  });

  setUp(() {
    handler = (_) => http.Response('[]', 200);
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('parseGeoJsonPolygon', () {
    test('Polygon hợp lệ: đảo [lng, lat] thành LatLng(lat, lng)', () {
      final r = parseGeoJsonPolygon(_square);
      expect(r.problem, isNull);
      expect(r.points!.first, const LatLng(11.0, 108.0));
      expect(r.points![1], const LatLng(11.0, 108.1));
    });

    test('chấp nhận chuỗi JSON và Feature', () {
      expect(parseGeoJsonPolygon(jsonEncode(_square)).points, isNotNull);
      expect(parseGeoJsonPolygon({'type': 'Feature', 'geometry': _square}).points, isNotNull);
    });

    test('null / rỗng = chưa có ranh giới, không phải lỗi', () {
      expect(parseGeoJsonPolygon(null).isMissing, isTrue);
      expect(parseGeoJsonPolygon('').isMissing, isTrue);
    });

    test('dữ liệu hỏng = lỗi hình học có lý do, không bị coi là chưa có', () {
      expect(
        parseGeoJsonPolygon({
          'type': 'Point',
          'coordinates': [1, 2],
        }).problem,
        contains('Point'),
      );
      expect(parseGeoJsonPolygon({'type': 'Polygon'}).problem, isNotNull);
      expect(parseGeoJsonPolygon('{khong phai json').problem, isNotNull);
      final outOfRange = parseGeoJsonPolygon(
        _polygon([
          [108.0, 95.0],
          [108.1, 11.0],
          [108.1, 11.1],
        ]),
      );
      expect(outOfRange.problem, contains('ngoài phạm vi'));
      final tooFew = parseGeoJsonPolygon(
        _polygon([
          [1, 1],
          [1, 1],
          [2, 2],
        ]),
      );
      expect(tooFew.problem, contains('3 đỉnh'));
    });

    test('Field/Zone.fromJson giữ lý do lỗi hình học', () {
      expect(_zone({'boundaryGeoJson': _square}).polygon, isNotNull);
      expect(_zone({'BoundaryGeoJson': _square}).polygon, isNotNull);
      final bad = _zone({'boundaryGeoJson': 'xyz'});
      expect(bad.polygon, isNull);
      expect(bad.boundaryProblem, isNotNull);
      expect(_zone({}).boundaryProblem, isNull);
      final f = FieldModel.fromJson({
        'fieldId': 'fl1',
        'name': 'Lô 1',
        'boundaryGeoJson': {'type': 'Polygon'},
      });
      expect(f.polygon, isNull);
      expect(f.boundaryProblem, isNotNull);
    });
  });

  group('FarmApi không nuốt lỗi tải', () {
    test('getFields: 500 / 403 ném lỗi thay vì trả danh sách rỗng', () async {
      handler = (_) => http.Response('{"title":"boom"}', 500);
      await expectLater(FarmApi.getFields('f1'), throwsException);
      handler = (_) => http.Response('', 403);
      await expectLater(FarmApi.getFields('f1'), throwsException);
    });

    test('getZones: lỗi ném ra; 200 đọc đúng ranh giới', () async {
      handler = (_) => http.Response('', 500);
      await expectLater(FarmApi.getZones('fl1', farmId: 'f1'), throwsException);
      handler = (_) => utf8Json([
        {'zoneId': 'z1', 'name': 'A', 'areaM2': 10, 'boundaryGeoJson': _square},
      ]);
      final zones = await FarmApi.getZones('fl1', farmId: 'f1');
      expect(zones.single.polygon!.length, 5);
    });

    test('getFields 200 đọc ranh giới và gọi đúng đường dẫn', () async {
      late http.Request req;
      handler = (r) {
        req = r;
        return utf8Json([
          {'fieldId': 'fl1', 'farmId': 'f1', 'name': 'Lô', 'areaM2': 5, 'boundaryGeoJson': _square},
        ]);
      };
      final fields = await FarmApi.getFields('f1');
      expect(req.url.path, '/api/v1/farms/f1/fields');
      expect(fields.single.polygon, isNotNull);
    });
  });

  group('GISMapScreen trạng thái', () {
    Future<void> pump(WidgetTester tester, {List<FieldModel>? fields, List<ZoneModel>? zones, String? error}) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late FarmProvider p;
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => p = FarmProvider(),
          child: const MaterialApp(home: GISMapScreen()),
        ),
      );
      // Chờ lần đồng bộ nền của constructor kết thúc (không có backend nên lỗi) rồi mới đặt trạng thái cần thử.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      p.setStructureForTesting(fields: fields ?? [], zones: zones ?? [], error: error);
      await tester.pump();
    }

    testWidgets('lỗi tải hiển thị lỗi tải, KHÔNG nói chưa có ranh giới', (tester) async {
      await pump(tester, error: 'Không tải được Thửa đất: 403');
      expect(find.textContaining('Lỗi tải dữ liệu bản đồ'), findsOneWidget);
      expect(find.textContaining('Chưa có ranh giới nào'), findsNothing);
      expect(find.text('Tải lại'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Zone chưa có ranh giới được liệt kê và chạm được', (tester) async {
      await pump(tester, zones: [_zone({})]);
      expect(find.textContaining('Chưa có ranh giới nào'), findsOneWidget);
      expect(find.textContaining('Zone: Zone A'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('dữ liệu ranh giới hỏng báo lỗi hình học riêng', (tester) async {
      await pump(
        tester,
        zones: [
          _zone({'boundaryGeoJson': 'xyz'}),
        ],
      );
      expect(find.textContaining('không hợp lệ'), findsOneWidget);
      expect(find.textContaining('Chưa có ranh giới nào'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('có ranh giới hợp lệ: không hiện cảnh báo thiếu/lỗi', (tester) async {
      await pump(
        tester,
        zones: [
          _zone({'boundaryGeoJson': _square}),
        ],
      );
      expect(find.textContaining('Chưa có ranh giới'), findsNothing);
      expect(find.textContaining('Lỗi tải'), findsNothing);
    });
  });
}
