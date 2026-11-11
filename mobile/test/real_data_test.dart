import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

/// Không dùng dữ liệu giả: trạng thái thiết bị tính từ dữ liệu thật, Zone mới gán nhân công qua API quyền Zone,
/// tìm địa điểm báo lỗi thật thay vì trả danh sách rỗng.
http.Response Function(http.Request) handler = (_) => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

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
    handler = (_) => http.Response('[]', 200);
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('DeviceHealthModel', () {
    DeviceHealthModel at(Duration ago, {int interval = 60}) => DeviceHealthModel(
      nodeId: 'n',
      name: 'n',
      type: 'SENSOR_NODE',
      lastSeenAt: DateTime.now().subtract(ago),
      expectedIntervalSeconds: interval,
    );

    test('≤ 3× chu kỳ → ONLINE', () => expect(at(const Duration(seconds: 150)).healthStatus, 'ONLINE'));
    test('3–12× chu kỳ → WARNING', () => expect(at(const Duration(minutes: 8)).healthStatus, 'WARNING'));
    test('> 12× chu kỳ → OFFLINE', () => expect(at(const Duration(hours: 1)).healthStatus, 'OFFLINE'));
    test('chưa từng nhận dữ liệu → OFFLINE, không bịa thời điểm', () {
      final d = DeviceHealthModel(
        nodeId: 'n',
        name: 'n',
        type: 'GATEWAY',
        lastSeenAt: null,
        expectedIntervalSeconds: 60,
      );
      expect(d.healthStatus, 'OFFLINE');
      expect(d.lastSeenText, 'Chưa có dữ liệu');
      expect(d.batteryPercent, isNull);
      expect(d.signalRssi, isNull);
    });
  });

  group('FarmProvider.addNewZone', () {
    final box = [const LatLng(0, 0), const LatLng(0, 1), const LatLng(1, 1)];

    test('tạo Zone rồi cấp quyền Zone mới cho nhân công được chọn', () async {
      handler = (r) {
        if (r.method == 'POST' && r.url.path == '/api/v1/fields/fld/zones') {
          return utf8Json({'zoneId': 'z9'}, 201);
        }
        if (r.method == 'PUT' && r.url.path == '/api/v1/users/f1/zone-access') return utf8Json({});
        return http.Response('[]', 200);
      };
      final p = FarmProvider();
      final res = await p.addNewZone(
        name: 'Nhà màng 9',
        areaM2: 500,
        assignFarmerId: 'f1',
        customFieldId: 'fld',
        polygon: box,
      );
      expect(res.error, isNull);
      expect(res.warning, isNull);
      expect(res.zoneId, 'z9');
      final put = calls.firstWhere((c) => c.method == 'PUT' && c.url.path == '/api/v1/users/f1/zone-access');
      final access = (jsonDecode(put.body) as Map)['access'] as List;
      expect(access.single, {'zoneId': 'z9', 'canControl': false});
      p.dispose();
    });

    test('Zone đã tạo nhưng gán nhân công lỗi → warning rõ ràng, không báo thành công giả', () async {
      handler = (r) {
        if (r.method == 'POST' && r.url.path == '/api/v1/fields/fld/zones') return utf8Json({'zoneId': 'z9'}, 201);
        if (r.method == 'PUT' && r.url.path == '/api/v1/users/f1/zone-access') {
          return utf8Json({'message': 'Farmer không thuộc trang trại này.'}, 403);
        }
        return http.Response('[]', 200);
      };
      final p = FarmProvider();
      final res = await p.addNewZone(name: 'Z', areaM2: 500, assignFarmerId: 'f1', customFieldId: 'fld', polygon: box);
      expect(res.error, isNull);
      expect(res.warning, contains('Farmer không thuộc trang trại này.'));
      p.dispose();
    });

    test('backend từ chối tạo Zone → error, không gọi API gán quyền', () async {
      handler = (r) {
        if (r.method == 'POST' && r.url.path == '/api/v1/fields/fld/zones') {
          return utf8Json({'message': 'Zone vượt ngoài ranh giới thửa đất.'}, 400);
        }
        return http.Response('[]', 200);
      };
      final p = FarmProvider();
      final res = await p.addNewZone(name: 'Z', areaM2: 500, assignFarmerId: 'f1', customFieldId: 'fld', polygon: box);
      expect(res.error, contains('vượt ngoài ranh giới'));
      expect(calls.where((c) => c.url.path.contains('zone-access')), isEmpty);
      p.dispose();
    });
  });

  group('FarmApi.searchLocation', () {
    test('đọc danh sách địa điểm từ backend', () async {
      handler = (_) => utf8Json([
        {'displayName': 'Đà Lạt, Lâm Đồng', 'latitude': 11.94, 'longitude': 108.44},
      ]);
      final r = await FarmApi.searchLocation(' Đà Lạt ');
      expect(calls.single.url.path, '/api/v1/gis/search-location');
      expect((jsonDecode(calls.single.body) as Map)['query'], 'Đà Lạt');
      expect(r.single['displayName'], 'Đà Lạt, Lâm Đồng');
    });

    test('backend lỗi → ném lỗi thay vì trả rỗng giả', () async {
      handler = (_) => http.Response('', 500);
      expect(FarmApi.searchLocation('abc'), throwsA(isA<Exception>()));
    });
  });

  test('getFarmDevicesRaw/getFarmGatewaysRaw giữ nguyên lastSeenAtUtc cho màn tình trạng thiết bị', () async {
    handler = (_) => utf8Json([
      {
        'deviceId': 'd1',
        'hardwareAddress': 'AA:01',
        'lastSeenAtUtc': '2026-11-10T01:00:00Z',
        'heartbeatIntervalSeconds': 30,
      },
    ]);
    final devices = await DeploymentApi.getFarmDevicesRaw('f1');
    expect(calls.single.url.path, '/api/v1/farms/f1/devices');
    expect(devices.single['lastSeenAtUtc'], '2026-11-10T01:00:00Z');
    expect(devices.single['heartbeatIntervalSeconds'], 30);
  });
}
