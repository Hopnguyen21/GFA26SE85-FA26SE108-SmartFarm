import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/zones/actuator_interlock.dart';
import 'package:smartfarm_mobile/features/zones/widgets/actuator_command_dialog.dart';

/// Tưới thủ công / gửi lệnh rơ-le giống web: payload, chỉ báo chạy khi gateway ACK, khóa interlock bơm,
/// hộp xác nhận với hẹn giờ tự ngắt 1–30 phút.
http.Response Function(http.Request) handler = (_) => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

ActuatorModel pump(String id, {bool running = false, String zone = 'z1'}) =>
    ActuatorModel(
      actuatorId: id,
      zoneId: zone,
      name: 'Bơm $id',
      actuatorType: 'PUMP',
      isRunning: running,
      relayChannel: 1,
    );

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
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('payload gửi lệnh', () {
    test('mặc định KHÔNG ngắt lệnh tự động đang chạy (như web)', () async {
      handler = (_) => utf8Json({'status': 'Pending'}, 202);
      await AutomationApi.sendActuatorCommand(
        zoneId: 'z1',
        actuatorId: 'a1',
        action: 'TurnOn',
        durationSeconds: 900,
      );
      final b = jsonDecode(calls.single.body) as Map<String, dynamic>;
      expect(b['overrideActiveSchedules'], false);
      expect(b['durationSeconds'], 900);
    });

    test('đọc trạng thái lệnh: Acknowledged / Pending / Failed', () async {
      handler = (_) => utf8Json({'status': 'Acknowledged'}, 202);
      var r = await AutomationApi.sendActuatorCommand(
        zoneId: 'z1',
        actuatorId: 'a1',
        action: 'TurnOn',
      );
      expect(r.acknowledged, isTrue);
      handler = (_) => utf8Json({'status': 'Pending'}, 202);
      r = await AutomationApi.sendActuatorCommand(
        zoneId: 'z1',
        actuatorId: 'a1',
        action: 'TurnOn',
      );
      expect(r.acknowledged, isFalse);
      expect(r.failed, isFalse);
      handler = (_) => utf8Json({'status': 'TimedOut'}, 202);
      r = await AutomationApi.sendActuatorCommand(
        zoneId: 'z1',
        actuatorId: 'a1',
        action: 'TurnOn',
      );
      expect(r.failed, isTrue);
    });

    test('getActuatorStatus đọc currentState và thời gian còn lại', () async {
      handler = (_) =>
          utf8Json({'currentState': 'Running', 'remainingSeconds': 301});
      final s = await AutomationApi.getActuatorStatus('z1', 'a1');
      expect(calls.single.url.path, '/api/v1/zones/z1/actuators/a1/status');
      expect(s!.isOn, isTrue);
      expect(s.remainingSeconds, 301);
    });
  });

  group('FarmProvider.toggleActuator', () {
    test('202 chưa ACK: không báo đang chạy, thông báo chờ gateway', () async {
      handler = (_) => utf8Json({'status': 'Pending'}, 202);
      final p = FarmProvider();
      p.setActuatorsForTesting([pump('a1')]);
      final err = await p.toggleActuator('a1', durationMinutes: 10);
      expect(err, isNull);
      expect(p.actuators.single.isRunning, isFalse);
      expect(p.lastActuatorNotice, contains('chờ gateway xác nhận'));
      p.dispose();
    });

    test(
      'đã ACK: báo đang chạy kèm số phút và thông báo qua gateway',
      () async {
        handler = (_) => utf8Json({'status': 'Acknowledged'}, 202);
        final p = FarmProvider();
        p.setActuatorsForTesting([pump('a1')]);
        expect(await p.toggleActuator('a1', durationMinutes: 12), isNull);
        expect(p.actuators.single.isRunning, isTrue);
        expect(p.actuators.single.remainingMinutes, 12);
        expect(p.lastActuatorNotice, contains('BẬT'));
        expect(p.lastActuatorNotice, contains('LoRa Gateway'));
        p.dispose();
      },
    );

    test('thời lượng bị ép vào 1–30 phút', () async {
      handler = (_) => utf8Json({'status': 'Pending'}, 202);
      final p = FarmProvider();
      p.setActuatorsForTesting([pump('a1')]);
      await p.toggleActuator('a1', durationMinutes: 99);
      final b =
          jsonDecode(
                calls.firstWhere((c) => c.url.path.endsWith('/command')).body,
              )
              as Map<String, dynamic>;
      expect(b['durationSeconds'], 1800);
      p.dispose();
    });

    test('lệnh Failed/TimedOut: trả lỗi, thiết bị không đổi', () async {
      handler = (_) => utf8Json({
        'status': 'Failed',
        'errorMessage': 'Gateway mất kết nối',
      }, 202);
      final p = FarmProvider();
      p.setActuatorsForTesting([pump('a1')]);
      expect(await p.toggleActuator('a1'), 'Gateway mất kết nối');
      expect(p.actuators.single.isRunning, isFalse);
      p.dispose();
    });

    test('đang có lệnh tự động chạy (409): báo tiếng Việt dễ hiểu', () async {
      handler = (_) => utf8Json({
        'message':
            'An automated command is active; set overrideActiveSchedules to request safe preemption.',
      }, 409);
      final p = FarmProvider();
      p.setActuatorsForTesting([pump('a1')]);
      final err = await p.toggleActuator('a1');
      expect(err, contains('lệnh tự động'));
      expect(p.actuators.single.isRunning, isFalse);
      p.dispose();
    });

    test('TẮT thiết bị đang chạy gửi TurnOff và đưa về tắt khi ACK', () async {
      handler = (_) => utf8Json({'status': 'Acknowledged'}, 202);
      final p = FarmProvider();
      p.setActuatorsForTesting([pump('a1', running: true)]);
      expect(await p.toggleActuator('a1'), isNull);
      expect(
        (jsonDecode(
              calls.firstWhere((c) => c.url.path.endsWith('/command')).body,
            )
            as Map)['action'],
        'TurnOff',
      );
      expect(p.actuators.single.isRunning, isFalse);
      p.dispose();
    });
  });

  group('khóa interlock bơm (BR-INTERLOCK-01)', () {
    test('bơm khác đang chạy: chặn BẬT, vẫn cho TẮT', () {
      final a = pump('a1');
      final b = pump('a2', running: true);
      expect(actuatorInterlockError(a, true, [a, b]), contains('Bơm a2'));
      expect(actuatorInterlockError(a, false, [a, b]), isNull);
    });

    test('không có bơm nào khác chạy, hoặc không phải bơm: cho phép', () {
      final a = pump('a1');
      final fan = ActuatorModel(
        actuatorId: 'f1',
        zoneId: 'z1',
        name: 'Quạt',
        actuatorType: 'FAN',
        isRunning: true,
      );
      expect(actuatorInterlockError(a, true, [a, fan]), isNull);
      expect(actuatorInterlockError(fan, true, [a, fan]), isNull);
    });
  });

  group('hộp xác nhận lệnh rơ-le', () {
    Future<int?> open(
      WidgetTester t, {
      required bool turnOn,
      required List<ActuatorModel> all,
    }) async {
      int? result = -1;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showActuatorCommandDialog(
                    ctx,
                    actuator: all.first,
                    turnOn: turnOn,
                    zoneActuators: all,
                  );
                },
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      return result;
    }

    testWidgets('BẬT: mặc định 15 phút, chỉnh được và trả về số phút', (
      t,
    ) async {
      final acts = [pump('a1')];
      await open(t, turnOn: true, all: acts);
      expect(find.text('15 phút'), findsOneWidget);
      expect(find.byKey(const ValueKey('interlock-warning')), findsNothing);
      final slider = t.widget<Slider>(
        find.byKey(const ValueKey('failsafe-slider')),
      );
      expect(slider.min, 1);
      expect(slider.max, 30);
      slider.onChanged!(7);
      await t.pump();
      expect(find.text('7 phút'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('actuator-confirm')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('actuator-command-dialog')),
        findsNothing,
      );
    });

    testWidgets('bơm khác đang chạy: hiện cảnh báo và khóa nút xác nhận', (
      t,
    ) async {
      final acts = [pump('a1'), pump('a2', running: true)];
      await open(t, turnOn: true, all: acts);
      expect(find.byKey(const ValueKey('interlock-warning')), findsOneWidget);
      expect(find.textContaining('Bơm a2'), findsOneWidget);
      final btn = t.widget<FilledButton>(
        find.byKey(const ValueKey('actuator-confirm')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('TẮT: không có thanh hẹn giờ, nút xác nhận TẮT dùng được', (
      t,
    ) async {
      final acts = [pump('a1', running: true), pump('a2', running: true)];
      await open(t, turnOn: false, all: acts);
      expect(find.byKey(const ValueKey('failsafe-slider')), findsNothing);
      expect(find.text('Xác nhận TẮT RƠ-LE'), findsOneWidget);
      final btn = t.widget<FilledButton>(
        find.byKey(const ValueKey('actuator-confirm')),
      );
      expect(btn.onPressed, isNotNull);
    });
  });
}
