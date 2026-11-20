import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/home/zone_sensor_thresholds.dart';

/// Mọi Zone phải có cùng loại dữ liệu (số đo, cây, ngưỡng), không chỉ Zone đang chọn.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  http.Response Function(http.Request) handler = (_) =>
      http.Response('[]', 200);

  http.Response j(dynamic body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, dynamic> telemetry(double t, double s, double h, double l) => {
    'hasFreshTelemetry': true,
    'metrics': [
      for (final m in [
        ['Temperature', t, '°C'],
        ['SoilMoisture', s, '%'],
        ['AirHumidity', h, '%'],
        ['LightIntensity', l, 'Lux'],
      ])
        {'parameterCode': m[0], 'value': m[1], 'unit': m[2], 'isFresh': true},
    ],
  };

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => FarmApi.getFarms(),
      () => MockClient((req) async => handler(req)),
    );
  });

  setUp(() {
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'o@b.c',
      role: 'FarmOwner',
    );
    handler = (r) {
      final p = r.url.path;
      if (p == '/api/v1/users/me') {
        return j({'userId': 'u1', 'fullName': 'Chủ', 'role': 'FarmOwner'});
      }
      if (p == '/api/v1/farms') {
        return j([
          {
            'farmId': 'f1',
            'name': 'Trại',
            'address': 'LĐ',
            'totalAreaM2': 5000,
          },
        ]);
      }
      if (p == '/api/v1/farms/f1/fields') {
        return j([
          {'fieldId': 'fl1', 'farmId': 'f1', 'name': 'Khu', 'areaM2': 2500},
        ]);
      }
      if (p == '/api/v1/fields/fl1/zones') {
        return j([
          {
            'zoneId': 'zA',
            'fieldId': 'fl1',
            'name': 'Zone A',
            'currentCrop': 'Cà Chua Beefsteak (Tomato) (Beef F1)',
            'currentStage': 'Cây con',
            'seasonStatus': 'InProgress',
            'areaM2': 1000,
          },
          {
            'zoneId': 'zB',
            'fieldId': 'fl1',
            'name': 'Zone B',
            'currentCrop': 'Dưa leo màu',
            'currentStage': 'Ra hoa',
            'seasonStatus': 'InProgress',
            'areaM2': 800,
          },
        ]);
      }
      if (p == '/api/v1/zones/zA/telemetry/latest') {
        return j(telemetry(23, 72, 75, 20000));
      }
      if (p == '/api/v1/zones/zB/telemetry/latest') {
        return j(telemetry(31, 55, 80, 28000));
      }
      if (p == '/api/v1/zones/zA/ai/context') {
        return j({
          'cropName': 'Cà Chua Beefsteak (Tomato)',
          'growthStageName': 'Cây con',
          'requirements': [
            {
              'parameterCode': 'SoilMoisture',
              'minValue': 70,
              'maxValue': 80,
              'targetValue': 75,
              'unit': '%',
            },
            {
              'parameterCode': 'Temperature',
              'minValue': 20,
              'maxValue': 25,
              'targetValue': 23,
              'unit': '°C',
            },
          ],
        });
      }
      if (p == '/api/v1/zones/zB/ai/context') {
        return j({'cropName': 'Dưa leo màu', 'growthStageName': 'Ra hoa'});
      }
      return j([]);
    };
  });

  test('số đo được nạp cho MỌI Zone, không chỉ Zone đang chọn', () async {
    await http.runWithClient(() async {
      final p = FarmProvider()..switchRole('OWNER');
      await p.fetchFromApi();
      final a = p.allZones.firstWhere((z) => z.zoneId == 'zA');
      final b = p.allZones.firstWhere((z) => z.zoneId == 'zB');
      expect(
        (a.currentTemp, a.currentSoilMoisture, a.telemetryIsFresh),
        (23.0, 72.0, true),
      );
      expect(
        (b.currentTemp, b.currentSoilMoisture, b.telemetryIsFresh),
        (31.0, 55.0, true),
      );
      p.dispose();
    }, () => MockClient((r) async => handler(r)));
  });

  test(
    'cây của Zone giữ đúng chuỗi từ Zone API (kèm giống), không bị ghi đè bởi AI context',
    () async {
      await http.runWithClient(() async {
        final p = FarmProvider()..switchRole('OWNER');
        await p.fetchFromApi();
        final a = p.allZones.firstWhere((z) => z.zoneId == 'zA');
        expect(a.currentCrop, 'Cà Chua Beefsteak (Tomato) (Beef F1)');
        expect(a.currentStage, 'Cây con');
        p.dispose();
      }, () => MockClient((r) async => handler(r)));
    },
  );

  test(
    'ngưỡng của giai đoạn hiện tại có trên Zone; Zone không có ngưỡng thì không bịa',
    () async {
      await http.runWithClient(() async {
        final p = FarmProvider()..switchRole('OWNER');
        await p.fetchFromApi();
        final a = p.allZones.firstWhere((z) => z.zoneId == 'zA');
        final b = p.allZones.firstWhere((z) => z.zoneId == 'zB');
        expect(requirementFor(a, 'SoilMoisture')!.min, 70);
        expect(thresholdCaption(a, 'SoilMoisture', '%'), 'Ngưỡng 70–80%');
        // soil 72 trong ngưỡng, 55 (zone B) chưa có ngưỡng → không đánh giá
        expect(outOfRange(a, 'SoilMoisture', a.currentSoilMoisture), false);
        expect(outOfRange(b, 'SoilMoisture', b.currentSoilMoisture), isNull);
        expect(
          thresholdCaption(b, 'SoilMoisture', '%'),
          'Giai đoạn này chưa có ngưỡng',
        );
        p.dispose();
      }, () => MockClient((r) async => handler(r)));
    },
  );
}
