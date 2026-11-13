import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

DefaultCropProfile _profile() => defaultCropProfileFromApi({
  'profileId': 'p1',
  'cropId': 'c1',
  'varietyId': 'v1',
  'cropName': 'Dưa lưới',
  'name': 'VietGAP',
  'stages': [
    {
      'stageId': 'st1',
      'name': 'Cây con',
      'stageOrder': 1,
      'durationDays': 20,
      'requirements': [],
    },
  ],
}, null);

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
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  FarmProvider provider() {
    final p = FarmProvider();
    final profile = _profile();
    p.defaultCropProfiles.add(profile);
    p.setZonesForTesting([
      ZoneModel.fromJson(
        {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
        farmId: 'f1',
        fieldId: 'fl1',
      ),
    ]);
    return p;
  }

  test(
    'áp dụng hồ sơ cho Zone mà không chọn khung mùa vụ: gắn trực tiếp qua PUT /zones, KHÔNG tạo vụ trồng',
    () async {
      handler = (r) async =>
          r.method == 'PUT' ? utf8Json({'zoneId': 'z1'}) : utf8Json([]);
      final p = provider();
      final profile = p.defaultCropProfiles.single;

      final err = await p.applyCropProfile(profile.cropId, targetZoneId: 'z1');

      expect(err, isNull);
      final put = calls.firstWhere((c) => c.method == 'PUT');
      expect(put.url.path, '/api/v1/zones/z1');
      expect(
        (jsonDecode(put.body) as Map<String, dynamic>)['growthProfileId'],
        'p1',
      );
      expect(
        calls.where(
          (c) => c.method == 'POST' && c.url.path.contains('planting-seasons'),
        ),
        isEmpty,
      );
      p.dispose();
    },
  );

  test('backend từ chối gắn hồ sơ → trả lỗi thật', () async {
    handler = (r) async => r.method == 'PUT'
        ? utf8Json({
            'message':
                'Hồ sơ canh tác không tồn tại hoặc không thuộc danh mục của bạn.',
          }, 400)
        : utf8Json([]);
    final p = provider();
    final err = await p.applyCropProfile(
      p.defaultCropProfiles.single.cropId,
      targetZoneId: 'z1',
    );
    expect(err, contains('không thuộc danh mục'));
    p.dispose();
  });
}
