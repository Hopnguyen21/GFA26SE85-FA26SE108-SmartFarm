import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/utils/cron_utils.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_applier.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_logic.dart';
import 'package:smartfarm_mobile/features/zones/zone_irrigation_logic.dart';

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _schedule({
  String id = 'sc1',
  String cron = '30 6 * * *',
  int seconds = 480,
  bool active = true,
}) => {
  'scheduleId': id,
  'zoneId': 'z1',
  'actuatorId': 'a1',
  'name': '[AutoSync] Dưa lưới Tưới sáng 06:30',
  'cronExpression': cron,
  'durationSeconds': seconds,
  'enableRainDelay': true,
  'rainThresholdPercent': 70,
  'isActive': active,
};

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

  group('cron hằng ngày', () {
    test('đọc/ghi "phút giờ * * *"', () {
      expect(parseDailyCron('30 6 * * *'), (hour: 6, minute: 30));
      expect(cronToHhmm('5 16 * * *'), '16:05');
      expect(buildDailyCron('06:30'), '30 6 * * *');
      expect(buildDailyCron('6:05'), '5 6 * * *');
    });
    test('không phải lịch hằng ngày thì không đoán giờ', () {
      expect(parseDailyCron('0 6 * * 1'), isNull);
      expect(parseDailyCron('*/5 * * * *'), isNull);
      expect(parseDailyCron('61 6 * * *'), isNull);
      expect(buildDailyCron('25:00'), isNull);
      expect(buildDailyCron('abc'), isNull);
    });
    test('ScheduleModel lấy giờ từ cron thật, không còn gán cứng 06:30', () {
      expect(ScheduleModel.fromJson(_schedule(cron: '45 17 * * *')).startTime, '17:45');
      expect(ScheduleModel.fromJson(_schedule(cron: '0 6 * * 1')).startTime, '0 6 * * 1');
    });
  });

  group('validateScheduleEdit', () {
    test('hợp lệ → cron + giây', () {
      final v = validateScheduleEdit(time: '06:15', minutesText: '8', rainThresholdText: '70');
      expect(v.error, isNull);
      expect(v.cron, '15 6 * * *');
      expect(v.seconds, 480);
    });
    test('giờ sai, quá 30 phút, thời lượng không phải số, ngưỡng mưa ngoài 0–100 → báo lỗi', () {
      expect(validateScheduleEdit(time: '25:00', minutesText: '8', rainThresholdText: '70').error, contains('HH:mm'));
      expect(
        validateScheduleEdit(time: '06:00', minutesText: '31', rainThresholdText: '70').error,
        contains('30 phút'),
      );
      expect(
        validateScheduleEdit(time: '06:00', minutesText: 'x', rainThresholdText: '70').error,
        contains('thời lượng'),
      );
      expect(
        validateScheduleEdit(time: '06:00', minutesText: '5', rainThresholdText: '120').error,
        contains('0 đến 100'),
      );
    });
    test('đúng 30 phút là giới hạn được phép', () {
      expect(validateScheduleEdit(time: '06:00', minutesText: '30', rainThresholdText: '70').seconds, 1800);
    });
  });

  group('classifySyncError (theo thông điệp thật của backend)', () {
    test('các lỗi của sync-from-crop được phân loại đúng', () {
      expect(
        classifySyncError("Khu vực 'A' chưa có thiết bị van hoặc máy bơm tưới (Actuator). Vui lòng cấu hình").kind,
        SyncProblemKind.noActuator,
      );
      expect(classifySyncError("Cây 'X' chưa có Lịch tưới mẫu trong thư viện cây trồng.").kind, SyncProblemKind.noPlan);
      expect(
        classifySyncError("Lịch tưới mẫu của cây 'X' lặp kiểu 'WEEKLY', còn hệ thống").kind,
        SyncProblemKind.unsupportedRepeat,
      );
      expect(
        classifySyncError("Một ca tưới trong lịch mẫu của cây 'X' dài 45 phút, tối đa 30").kind,
        SyncProblemKind.durationTooLong,
      );
      expect(
        classifySyncError('Bạn không có quyền truy cập vào Khu vực canh tác này.').kind,
        SyncProblemKind.forbidden,
      );
      expect(classifySyncError('Lỗi lạ').kind, SyncProblemKind.other);
    });
    test('thông điệp gốc của backend luôn được giữ', () {
      expect(classifySyncError('Lỗi lạ').message, 'Lỗi lạ');
    });
  });

  test('chỉ bơm/van/tưới được dùng để đồng bộ, không tự chọn quạt', () {
    final list = [
      ActuatorModel(actuatorId: '1', zoneId: 'z', name: 'Quạt', actuatorType: 'FAN'),
      ActuatorModel(actuatorId: '2', zoneId: 'z', name: 'Bơm', actuatorType: 'PUMP'),
      ActuatorModel(actuatorId: '3', zoneId: 'z', name: 'Van', actuatorType: 'VALVE'),
    ];
    expect(irrigationActuators(list).map((a) => a.actuatorId), ['2', '3']);
  });

  test('describeSchedule dùng giờ, thời lượng và hoãn mưa thật', () {
    expect(describeSchedule(ScheduleModel.fromJson(_schedule())), 'hằng ngày lúc 06:30 · 8 phút · hoãn khi mưa ≥ 70%');
    expect(
      describeSchedule(ScheduleModel.fromJson(_schedule(cron: '0 6 * * 1'))),
      contains('không phải lịch hằng ngày'),
    );
  });

  group('applyOwnProfileEdits', () {
    StageDraft st(String id, int days, {double target = 70}) => StageDraft(
      stageId: id,
      name: 'GĐ $id',
      order: 1,
      durationDays: days,
      requirements: [RequirementDraft(code: 'SoilMoisture', min: 60, max: 80, target: target, unit: '%')],
    );

    test('chỉ gọi API cho phần thật sự đổi', () async {
      handler = (_) async => utf8Json({});
      final err = await applyOwnProfileEdits(
        profileId: 'p1',
        originalName: 'Bản A',
        originalDescription: null,
        name: 'Bản A',
        description: '',
        original: [st('a', 20), st('b', 30)],
        edited: [st('a', 25), st('b', 30, target: 65)],
      );
      expect(err, isNull);
      final puts = calls.where((c) => c.method == 'PUT').map((c) => c.url.path).toList();
      expect(puts, ['/api/v1/growth-stages/a', '/api/v1/growth-stages/b/requirements']);
    });

    test('đổi tên/mô tả gọi PUT /growth-profiles và không gửi lịch tưới (backend chưa hỗ trợ)', () async {
      handler = (_) async => utf8Json({});
      await applyOwnProfileEdits(
        profileId: 'p1',
        originalName: 'Bản A',
        originalDescription: null,
        name: 'Bản A mới',
        description: 'Mô tả',
        original: [st('a', 20)],
        edited: [st('a', 20)],
      );
      final put = calls.single;
      expect(put.url.path, '/api/v1/growth-profiles/p1');
      final body = jsonDecode(put.body) as Map<String, dynamic>;
      expect(body['name'], 'Bản A mới');
      expect(body['description'], 'Mô tả');
      expect(body.containsKey('irrigationPlan'), isFalse);
    });

    test('lỗi giữa chừng: dừng, báo lý do và phần đã lưu', () async {
      handler = (r) async =>
          r.url.path.endsWith('/b') ? utf8Json({'message': 'Số ngày không hợp lệ'}, 400) : utf8Json({});
      final err = await applyOwnProfileEdits(
        profileId: 'p1',
        originalName: 'Tên X',
        originalDescription: null,
        name: 'Tên X',
        description: null,
        original: [st('a', 20), st('b', 30)],
        edited: [st('a', 25), st('b', 40)],
      );
      expect(err, contains('Số ngày không hợp lệ'));
      expect(err, contains('đã lưu'));
    });

    test('validate trước khi gọi API: tên ngắn, số ngày sai, ngưỡng sai', () async {
      Future<String?> run(String name, StageDraft stage) => applyOwnProfileEdits(
        profileId: 'p1',
        originalName: 'X',
        originalDescription: null,
        name: name,
        description: null,
        original: [st('a', 20)],
        edited: [stage],
      );
      expect(await run('a', st('a', 20)), contains('2 ký tự'));
      expect(await run('Tên', st('a', 0)), contains('1 đến 365'));
      expect(await run('Tên', st('a', 20, target: 95)), contains('mục tiêu'));
      expect(calls, isEmpty);
    });
  });

  test('sao chép hồ sơ gửi kèm mô tả khi có, và không có irrigationPlan', () {
    final s = ZoneCropSelection(
      cropId: 'c',
      profileId: 'p',
      mode: ZoneProfileMode.custom,
      customName: 'Bản của tôi',
      customDescription: '  Vụ đông  ',
    );
    final payload = buildCloneProfilePayload(s);
    expect(payload['description'], 'Vụ đông');
    expect(payload.containsKey('irrigationPlan'), isFalse);
    expect(buildCloneProfilePayload(s.copyWith(customDescription: '')).containsKey('description'), isFalse);
  });
}
