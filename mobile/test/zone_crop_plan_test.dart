import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_applier.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_logic.dart';

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

StageDraft stage(String id, int order, int days, {double min = 60, double max = 80, double target = 70}) => StageDraft(
  stageId: id,
  name: 'GĐ $order',
  order: order,
  durationDays: days,
  requirements: [RequirementDraft(code: 'SoilMoisture', min: min, max: max, target: target, unit: '%')],
);

ZoneCropSelection selection({
  ZoneProfileMode mode = ZoneProfileMode.system,
  List<StageDraft>? stages,
  List<StageDraft>? original,
  String name = 'Bản của tôi',
}) {
  final base = [stage('a', 1, 20), stage('b', 2, 40)];
  return ZoneCropSelection(
    cropId: 'crop1',
    varietyId: 'var1',
    profileId: 'sys1',
    mode: mode,
    customName: name,
    stages: stages ?? base,
    originalStages: original ?? base,
  );
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
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('validateZoneCropSelection', () {
    test('không áp dụng hồ sơ → hợp lệ, không cần gì thêm', () {
      expect(validateZoneCropSelection(const ZoneCropSelection()), isNull);
    });

    test('chưa chọn cây / cây chưa có hồ sơ / hồ sơ không có giai đoạn → chặn với lý do rõ', () {
      final s = selection();
      expect(validateZoneCropSelection(s.copyWith(profileId: null, clearProfile: true)), contains('chưa có hồ sơ'));
      expect(validateZoneCropSelection(s.copyWith(stages: [], originalStages: [])), contains('giai đoạn'));
      expect(validateZoneCropSelection(const ZoneCropSelection(mode: ZoneProfileMode.system)), contains('Chọn cây'));
    });

    test('tổng số ngày = tổng thời lượng các giai đoạn (chỉ để hiển thị, không tạo vụ)', () {
      expect(selection().totalDays, 60);
    });

    test('tùy chỉnh: cần tên, số ngày 1–365, ngưỡng min ≤ target ≤ max', () {
      final base = selection(mode: ZoneProfileMode.custom);
      expect(validateZoneCropSelection(base.copyWith(customName: 'x')), contains('tên hồ sơ'));
      expect(
        validateZoneCropSelection(base.copyWith(stages: [stage('a', 1, 0), stage('b', 2, 40)])),
        contains('1 đến 365'),
      );
      expect(
        validateZoneCropSelection(base.copyWith(stages: [stage('a', 1, 20, min: 80, max: 60), stage('b', 2, 40)])),
        contains('Ngưỡng'),
      );
      expect(validateZoneCropSelection(base), isNull);
    });

    test('stagesChanged chỉ true khi có sửa thật', () {
      expect(selection().stagesChanged, isFalse);
      expect(selection(stages: [stage('a', 1, 25), stage('b', 2, 40)]).stagesChanged, isTrue);
      expect(selection(stages: [stage('a', 1, 20, target: 65), stage('b', 2, 40)]).stagesChanged, isTrue);
    });
  });

  group('prepareZoneProfile (gắn hồ sơ trực tiếp, KHÔNG tạo vụ mùa)', () {
    bool isCreateProfile(http.Request r) => r.method == 'POST' && r.url.path == '/api/v1/growth-profiles';
    bool isSeason(http.Request r) => r.method == 'POST' && r.url.path.endsWith('/planting-seasons');
    Map<String, dynamic> cloneResponse() => {
      'profileId': 'copy1',
      'stages': [
        {'stageId': 'ca', 'stageOrder': 1},
        {'stageId': 'cb', 'stageOrder': 2},
      ],
    };

    test('không áp dụng hồ sơ → không gọi API nào', () async {
      final r = await prepareZoneProfile(selection: const ZoneCropSelection());
      expect(r.profileId, isNull);
      expect(r.error, isNull);
      expect(calls, isEmpty);
    });

    test('hồ sơ có sẵn: dùng thẳng mã hồ sơ, không sao chép, không tạo vụ', () async {
      final r = await prepareZoneProfile(selection: selection());
      expect(r.ok, isTrue);
      expect(r.profileId, 'sys1');
      expect(r.cloned, isFalse);
      expect(calls, isEmpty);
    });

    test('tùy chỉnh: sao chép hồ sơ (kèm mô tả), sửa giai đoạn trên BẢN SAO, và KHÔNG bao giờ tạo vụ mùa', () async {
      handler = (r) async => isCreateProfile(r) ? utf8Json(cloneResponse(), 201) : utf8Json({});
      final edited = [stage('a', 1, 25), stage('b', 2, 40, target: 65)];
      final sel = selection(mode: ZoneProfileMode.custom, stages: edited).copyWith(customDescription: 'Vụ đông');
      final r = await prepareZoneProfile(selection: sel);

      expect(r.ok, isTrue);
      expect(r.profileId, 'copy1');
      expect(r.cloned, isTrue);
      final clone = jsonDecode(calls.firstWhere(isCreateProfile).body) as Map<String, dynamic>;
      expect(clone['sourceProfileId'], 'sys1');
      expect(clone['description'], 'Vụ đông');
      expect(clone.containsKey('irrigationPlan'), isFalse, reason: 'backend sao chép lịch tưới của profile nguồn');
      final puts = calls.where((c) => c.method == 'PUT').map((c) => c.url.path).toList();
      expect(puts, ['/api/v1/growth-stages/ca', '/api/v1/growth-stages/cb/requirements']);
      expect(calls.where(isSeason), isEmpty);
    });

    test('tùy chỉnh không đổi giai đoạn → không gọi PUT thừa', () async {
      handler = (r) async => isCreateProfile(r) ? utf8Json(cloneResponse(), 201) : utf8Json({});
      await prepareZoneProfile(selection: selection(mode: ZoneProfileMode.custom));
      expect(calls.where((c) => c.method == 'PUT'), isEmpty);
    });

    test('sao chép lỗi → dừng, báo lý do, chưa có hồ sơ để gắn', () async {
      handler = (r) async => isCreateProfile(r) ? utf8Json({'message': 'Tên hồ sơ đã tồn tại'}, 409) : utf8Json({});
      final r = await prepareZoneProfile(selection: selection(mode: ZoneProfileMode.custom));
      expect(r.ok, isFalse);
      expect(r.profileId, isNull);
      expect(r.error, contains('hồ sơ riêng'));
    });

    test('sửa giai đoạn lỗi giữa chừng → giữ mã bản sao đã tạo để tiếp tục, không gắn hồ sơ chỉnh dở', () async {
      handler = (r) async {
        if (isCreateProfile(r)) return utf8Json(cloneResponse(), 201);
        if (r.method == 'PUT') return utf8Json({'message': 'Số ngày không hợp lệ'}, 400);
        return utf8Json({});
      };
      final r = await prepareZoneProfile(
        selection: selection(mode: ZoneProfileMode.custom, stages: [stage('a', 1, 25), stage('b', 2, 40)]),
      );
      expect(r.ok, isFalse);
      expect(r.profileId, 'copy1');
      expect(r.cloned, isTrue);
      expect(r.error, contains('GĐ 1'));
    });

    test('thử lại với bản sao đã tạo: KHÔNG tạo bản sao thứ hai, đọc lại giai đoạn và tiếp tục chỉnh', () async {
      handler = (r) async {
        if (r.method == 'GET' && r.url.path == '/api/v1/growth-profiles/copy1/stages') {
          return utf8Json([
            {'stageId': 'ca', 'stageOrder': 1},
            {'stageId': 'cb', 'stageOrder': 2},
          ]);
        }
        return utf8Json({});
      };
      final r = await prepareZoneProfile(
        selection: selection(mode: ZoneProfileMode.custom, stages: [stage('a', 1, 25), stage('b', 2, 40)]),
        reuseCloneId: 'copy1',
      );
      expect(r.ok, isTrue);
      expect(r.profileId, 'copy1');
      expect(calls.where(isCreateProfile), isEmpty);
      expect(calls.where((c) => c.method == 'PUT').map((c) => c.url.path), ['/api/v1/growth-stages/ca']);
    });

    test('response sao chép thiếu mã hồ sơ → không báo thành công', () async {
      handler = (r) async => isCreateProfile(r) ? utf8Json({'name': 'x'}, 201) : utf8Json({});
      final r = await prepareZoneProfile(selection: selection(mode: ZoneProfileMode.custom));
      expect(r.ok, isFalse);
      expect(r.error, contains('mã hồ sơ'));
    });
  });

  group('attachProfileToZone / FarmApi', () {
    test('PUT /zones/{id} gửi growthProfileId và không tạo vụ mùa', () async {
      handler = (_) async => utf8Json({'zoneId': 'z1', 'growthProfileId': 'p9'});
      final err = await attachProfileToZone(zoneId: 'z1', zoneName: 'Nhà màng 1', profileId: 'p9');
      expect(err, isNull);
      final req = calls.single;
      expect(req.method, 'PUT');
      expect(req.url.path, '/api/v1/zones/z1');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['growthProfileId'], 'p9');
      expect(body['name'], 'Nhà màng 1');
      expect(body.containsKey('clearGrowthProfile'), isFalse);
    });

    test('backend từ chối (cross-tenant, đang có vụ khác cây) → trả lý do thật', () async {
      handler = (_) async => utf8Json({'message': 'Zone đang có vụ mùa InProgress với cây/giống khác hồ sơ này.'}, 409);
      final err = await attachProfileToZone(zoneId: 'z1', zoneName: 'Z', profileId: 'p9');
      expect(err, contains('InProgress'));
    });

    test('gỡ hồ sơ gửi clearGrowthProfile', () async {
      handler = (_) async => utf8Json({});
      await FarmApi.updateZone('z1', name: 'Z', clearGrowthProfile: true);
      final body = jsonDecode(calls.single.body) as Map<String, dynamic>;
      expect(body['clearGrowthProfile'], isTrue);
      expect(body.containsKey('growthProfileId'), isFalse);
    });

    test('tạo Zone kèm hồ sơ gửi growthProfileId trong request tạo Zone', () async {
      handler = (_) async => utf8Json({'zoneId': 'z2'}, 201);
      await FarmApi.createZone(
        fieldId: 'fl1',
        name: 'Z',
        areaM2: 10,
        polygonGeoJson: {'type': 'Polygon', 'coordinates': []},
        growthProfileId: 'p9',
      );
      final req = calls.single;
      expect(req.url.path, '/api/v1/fields/fl1/zones');
      expect((jsonDecode(req.body) as Map<String, dynamic>)['growthProfileId'], 'p9');
    });

    test('ZoneModel đọc hồ sơ gắn trực tiếp từ Zone API; Zone cũ chưa gắn thì null', () {
      final withProfile = ZoneModel.fromJson({
        'zoneId': 'z1',
        'name': 'Z',
        'areaM2': 1,
        'growthProfileId': 'p9',
        'growthProfileName': 'VietGAP',
        'growthProfileIsSystemDefined': true,
      });
      expect(withProfile.growthProfileId, 'p9');
      expect(withProfile.growthProfileName, 'VietGAP');
      expect(withProfile.growthProfileIsSystem, isTrue);
      final legacy = ZoneModel.fromJson({'zoneId': 'z2', 'name': 'Z', 'areaM2': 1, 'growthProfileId': null});
      expect(legacy.growthProfileId, isNull);
      expect(legacy.copyWith(areaM2: 5).growthProfileId, isNull);
      expect(withProfile.copyWith(areaM2: 5).growthProfileId, 'p9', reason: 'copyWith giữ hồ sơ');
    });
  });
}
