import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

/// Phát hiện khi chạy thật: danh sách rơ-le của backend báo "ON" ngay khi lệnh vừa gửi (PendingFeedback),
/// nên mobile phải đối chiếu /status — chỉ RUNNING mới là đang chạy.
http.Response Function(http.Request) handler = (_) => http.Response('[]', 200);

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void route(Map<String, dynamic> status) {
  handler = (r) {
    if (r.url.path == '/api/v1/zones/z1/actuators') {
      return utf8Json([
        {
          'actuatorId': 'a1',
          'zoneId': 'z1',
          'name': 'Bơm',
          'actuatorType': 'PUMP',
          'status': 'ON',
        },
        {
          'actuatorId': 'a2',
          'zoneId': 'z1',
          'name': 'Quạt',
          'actuatorType': 'FAN',
          'status': 'OFF',
        },
      ]);
    }
    if (r.url.path == '/api/v1/zones/z1/actuators/a1/status') {
      return utf8Json(status);
    }
    return http.Response('[]', 200);
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async => handler(req)),
    );
  });

  setUp(() {
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  test(
    'danh sách báo ON nhưng /status là PendingFeedback → chưa chạy, chờ ACK',
    () async {
      route({'currentState': 'PendingFeedback', 'remainingSeconds': null});
      final list = await FarmApi.fetchZoneActuators('z1');
      final pump = list.firstWhere((a) => a.actuatorId == 'a1');
      expect(pump.isRunning, isFalse);
      expect(pump.awaitingAck, isTrue);
      expect(pump.remainingMinutes, 0);
    },
  );

  test('/status là Running → đang chạy với số phút còn lại thật', () async {
    route({'currentState': 'Running', 'remainingSeconds': 301});
    final pump = (await FarmApi.fetchZoneActuators(
      'z1',
    )).firstWhere((a) => a.actuatorId == 'a1');
    expect(pump.isRunning, isTrue);
    expect(pump.awaitingAck, isFalse);
    expect(pump.remainingMinutes, 6);
  });

  test('/status là Off → tắt; rơ-le đang OFF không gọi /status', () async {
    route({'currentState': 'Off'});
    final list = await FarmApi.fetchZoneActuators('z1');
    expect(list.firstWhere((a) => a.actuatorId == 'a1').isRunning, isFalse);
    expect(list.firstWhere((a) => a.actuatorId == 'a2').awaitingAck, isFalse);
  });

  test(
    'không đọc được /status: giữ giá trị của danh sách (không bịa)',
    () async {
      handler = (r) {
        if (r.url.path == '/api/v1/zones/z1/actuators') {
          return utf8Json([
            {
              'actuatorId': 'a1',
              'zoneId': 'z1',
              'name': 'Bơm',
              'actuatorType': 'PUMP',
              'status': 'ON',
            },
          ]);
        }
        return http.Response('lỗi', 500);
      };
      final pump = (await FarmApi.fetchZoneActuators('z1')).single;
      expect(pump.isRunning, isTrue);
    },
  );
}
