import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

/// Điều khiển thiết bị: lệnh bị backend từ chối phải báo lý do thật, không được im lặng hay báo thành công giả.
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

  test('sendActuatorCommand 202 → thành công, gửi đúng đường dẫn và payload', () async {
    handler = (_) => http.Response('', 202);
    await AutomationApi.sendActuatorCommand(zoneId: 'z1', actuatorId: 'a1', action: 'TurnOn', durationSeconds: 900);
    final r = calls.single;
    expect(r.method, 'POST');
    expect(r.url.path, '/api/v1/zones/z1/actuators/a1/command');
    final b = jsonDecode(r.body) as Map<String, dynamic>;
    expect(b['action'], 'TurnOn');
    expect(b['durationSeconds'], 900);
    expect((b['idempotencyKey'] as String).startsWith('mob_'), isTrue);
  });

  test('sendActuatorCommand bị từ chối → ném lỗi kèm lý do của backend', () async {
    handler = (_) => utf8Json({'message': 'Độ ẩm đất ≥ 80%: khóa an toàn chặn lệnh tưới.'}, 409);
    expect(
      AutomationApi.sendActuatorCommand(zoneId: 'z1', actuatorId: 'a1', action: 'TurnOn'),
      throwsA(predicate((e) => e.toString().contains('khóa an toàn'))),
    );
  });

  test('sendActuatorCommand ép thời lượng vào khoảng backend cho phép (1–1800 giây)', () async {
    handler = (_) => http.Response('', 200);
    await AutomationApi.sendActuatorCommand(zoneId: 'z1', actuatorId: 'a1', action: 'TurnOff', durationSeconds: 0);
    await AutomationApi.sendActuatorCommand(zoneId: 'z1', actuatorId: 'a1', action: 'TurnOn', durationSeconds: 99999);
    expect((jsonDecode(calls[0].body) as Map)['durationSeconds'], 1);
    expect((jsonDecode(calls[1].body) as Map)['durationSeconds'], 1800);
  });

  test('toggleActuator với thiết bị không tồn tại → trả lỗi, không gọi API', () async {
    final p = FarmProvider();
    calls.clear();
    final error = await p.toggleActuator('khong-co');
    expect(error, isNotNull);
    expect(calls.where((c) => c.url.path.contains('/command')), isEmpty);
    p.dispose();
  });

  test('acknowledgeAlert với cảnh báo không tồn tại → false, không gọi API', () async {
    final p = FarmProvider();
    calls.clear();
    expect(await p.acknowledgeAlert('khong-co'), isFalse);
    expect(calls.where((c) => c.url.path.contains('/acknowledge')), isEmpty);
    p.dispose();
  });

  test('TaskApi.acknowledgeAlert trả false khi backend lỗi', () async {
    handler = (_) => http.Response('', 500);
    expect(await TaskApi.acknowledgeAlert('al1'), isFalse);
    handler = (_) => http.Response('{}', 200);
    expect(await TaskApi.acknowledgeAlert('al1'), isTrue);
  });
}
