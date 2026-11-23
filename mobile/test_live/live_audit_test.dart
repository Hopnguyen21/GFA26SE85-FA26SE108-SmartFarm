// ignore_for_file: invalid_use_of_visible_for_testing_member
// Kiểm tra dữ liệu mobile với BACKEND THẬT đang chạy ở localhost:5144 (tài khoản demo của dự án): so model sau fetchFromApi với JSON thô của API.
// Không nằm trong bộ test thường: chạy thủ công `flutter test --no-pub test_live/live_audit_test.dart`; in danh sách chênh lệch ở cuối.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

const base = 'http://localhost:5144';
String? token;

Future<dynamic> raw(String path) async {
  final c = HttpClient();
  final req = await c.getUrl(Uri.parse('$base$path'));
  req.headers.set('Authorization', 'Bearer $token');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  c.close();
  if (res.statusCode != 200) return null;
  final j = jsonDecode(body);
  return j is Map && j['value'] is List ? j['value'] : j;
}

dynamic f(Map m, String k) => m[k] ?? m[k[0].toUpperCase() + k.substring(1)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final issues = <String>[];

  for (final acc in [
    ['OWNER', 'owner@smartfarm.demo'],
    ['FARMER', 'farmer@smartfarm.demo'],
    ['TECHNICIAN', 'technician@smartfarm.demo'],
  ]) {
    test('live audit ${acc[0]}', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final login = await ApiService.login(acc[1], 'Demo@12345');
      expect(login, isNotNull, reason: 'login');
      final c0 = HttpClient();
      final rq = await c0.postUrl(Uri.parse('$base/api/v1/auth/login'));
      rq.headers.contentType = ContentType.json;
      rq.write(jsonEncode({'email': acc[1], 'password': 'Demo@12345'}));
      final rs = await rq.close();
      token =
          jsonDecode(await rs.transform(utf8.decoder).join())['accessToken']
              as String?;
      c0.close();
      final p = FarmProvider();
      p.switchRole(acc[0]);
      await p.fetchFromApi();
      await Future<void>.delayed(
        const Duration(seconds: 9),
      ); // chờ vòng cập nhật telemetry định kỳ
      void bad(String s) => issues.add('[${acc[0]}] $s');

      final farmsRaw = await raw('/api/v1/farms') as List?;
      if (farmsRaw == null || farmsRaw.length != p.farms.length) {
        bad('farms raw=${farmsRaw?.length} model=${p.farms.length}');
      }
      final farmId = p.currentFarm.farmId;
      // Zones: so từng trường với API thô
      if (acc[0] == 'TECHNICIAN') {
        p.dispose();
        return;
      }
      for (final fld in p.fields) {
        final zr = await raw('/api/v1/zones?fieldId=${fld.fieldId}') as List?;
        final models = p.allZones
            .where((z) => z.fieldId == fld.fieldId)
            .toList();
        if (zr == null) continue;
        if (zr.length != models.length) {
          bad(
            'field ${fld.name}: zones raw=${zr.length} model=${models.length}',
          );
        }
        for (final r in zr.cast<Map>()) {
          final id = '${f(r, 'zoneId') ?? f(r, 'id')}';
          final m = models.where((z) => z.zoneId == id).firstOrNull;
          if (m == null) {
            bad('zone $id missing in model');
            continue;
          }
          final rc = '${f(r, 'currentCrop')}';
          final rs = '${f(r, 'currentStage')}';
          final ss = '${f(r, 'seasonStatus')}';
          if (f(r, 'currentCrop') != null && rc != m.currentCrop) {
            bad('zone ${m.name}: crop API="$rc" model="${m.currentCrop}"');
          }
          if (f(r, 'currentStage') != null && rs != m.currentStage) {
            bad(
              'zone ${m.name}: stage Zone-API="$rs" model="${m.currentStage}" (season=$ss)',
            );
          }
          if (ss != m.seasonStatus)
            bad('zone ${m.name}: seasonStatus API=$ss model=${m.seasonStatus}');
          final area = (f(r, 'areaM2') as num?)?.toDouble();
          if (area != null && (area - m.areaM2).abs() > 0.01)
            bad('zone ${m.name}: area API=$area model=${m.areaM2}');
          final gp = f(r, 'growthProfileId');
          if ('$gp' != '${m.growthProfileId}' &&
              !(gp == null && m.growthProfileId == null)) {
            bad(
              'zone ${m.name}: growthProfileId API=$gp model=${m.growthProfileId}',
            );
          }
          if (m.seasonStatus == 'InProgress' && m.appliedRequirements.isEmpty)
            bad('zone ${m.name}: vụ đang chạy nhưng appliedRequirements rỗng');
          // telemetry
          final tl = await raw('/api/v1/zones/$id/telemetry/latest');
          if (tl is Map && tl['metrics'] is List) {
            double? tv(String c) =>
                ((tl['metrics'] as List)
                            .cast<Map>()
                            .where((x) => x['parameterCode'] == c)
                            .firstOrNull?['value']
                        as num?)
                    ?.toDouble();
            final t = tl['hasFreshTelemetry'] == true
                ? tv('Temperature')
                : null;
            if (t != null && (t - m.currentTemp).abs() > 0.05)
              bad('zone ${m.name}: temp API=$t model=${m.currentTemp}');
            final so = tl['hasFreshTelemetry'] == true
                ? tv('SoilMoisture')
                : null;
            if (so != null && (so - m.currentSoilMoisture).abs() > 0.05)
              bad(
                'zone ${m.name}: soil API=$so model=${m.currentSoilMoisture}',
              );
            final h = tl['hasFreshTelemetry'] == true
                ? tv('AirHumidity')
                : null;
            if (h != null && (h - m.currentHumidity).abs() > 0.05)
              bad('zone ${m.name}: humidity API=$h model=${m.currentHumidity}');
            final lx = tl['hasFreshTelemetry'] == true
                ? tv('LightIntensity')
                : null;
            if (lx != null && (lx - m.currentLux).abs() > 0.5)
              bad('zone ${m.name}: lux API=$lx model=${m.currentLux}');
            if (tl['hasFreshTelemetry'] != true) {
              /* số đo cũ: cố ý không hiển thị */
            } else if (true != m.telemetryIsFresh)
              bad(
                'zone ${m.name}: fresh API=${tl['hasFreshTelemetry']} model=${m.telemetryIsFresh}',
              );
          }
          // vụ đang chạy thực tế (planting-seasons) so với trạng thái/giai đoạn trên model
          final seasons =
              await raw('/api/v1/planting-seasons?zoneId=$id') as List?;
          final run = seasons
              ?.cast<Map>()
              .where((s) => s['status'] == 'InProgress')
              .firstOrNull;
          if (run != null) {
            if (m.seasonStatus != 'InProgress')
              bad(
                'zone ${m.name}: có vụ InProgress "${run['name']}" nhưng model seasonStatus=${m.seasonStatus}',
              );
            final st = '${run['currentGrowthStageName']}';
            if (st != m.currentStage)
              bad(
                'zone ${m.name}: giai đoạn của vụ đang chạy="$st" nhưng model.currentStage="${m.currentStage}"',
              );
          } else if (m.seasonStatus == 'InProgress') {
            bad(
              'zone ${m.name}: model báo InProgress nhưng không có vụ đang chạy',
            );
          }
        }
      }
      // tasks/alerts/notifications/inventory số lượng
      final tr = await raw('/api/v1/farms/$farmId/tasks') as List?;
      if (acc[0] != 'TECHNICIAN' && tr != null && tr.length != p.tasks.length)
        bad('tasks raw=${tr.length} model=${p.tasks.length}');
      final ar = await raw('/api/v1/farms/$farmId/alerts') as List?;
      if (ar != null && ar.length != p.alerts.length)
        bad('alerts raw=${ar.length} model=${p.alerts.length}');
      final nr = await raw('/api/v1/notifications') as List?;
      if (nr != null && nr.length != p.notifications.length)
        bad('notifications raw=${nr.length} model=${p.notifications.length}');
      final ir = await raw('/api/v1/farms/$farmId/inventory') as List?;
      if (ir != null && ir.length != p.inventoryItemsForCurrentFarm.length)
        bad(
          'inventory raw=${ir.length} model=${p.inventoryItemsForCurrentFarm.length}',
        );
      // thời tiết
      final wr = await raw('/api/v1/farms/$farmId/weather');
      final w = p.farmWeather;
      if (wr is Map && w != null) {
        for (final k in ['temperature', 'humidity', 'windSpeed']) {
          if (wr[k] != w[k]) bad('weather $k raw=${wr[k]} model=${w[k]}');
        }
      } else if (wr is Map && w == null) {
        bad('weather API ok nhưng model null');
      }
      p.dispose();
    });
  }

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== ISSUES (${issues.length}) =====');
    for (final i in issues) {
      // ignore: avoid_print
      print(i);
    }
  });
}
