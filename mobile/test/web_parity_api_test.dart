import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

/// Kiểm tra các API mobile bổ sung để khớp luồng Web: đúng đường dẫn, phương thức, payload và cách đọc phản hồi.
http.Response Function(http.Request) handler = (_) => http.Response('{}', 200);
final calls = <http.Request>[];

Map<String, dynamic> body(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    handler = (_) => http.Response('[]', 200);
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
    handler = (_) => http.Response('{}', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  test('emergencyStop gửi zoneId và đọc stoppedCount', () async {
    handler = (_) => http.Response(
      jsonEncode({'success': true, 'stoppedCount': 3, 'message': 'ok'}),
      200,
    );
    final r = await AutomationApi.emergencyStop(zoneId: 'z1');
    expect(calls.single.method, 'POST');
    expect(calls.single.url.path, '/api/v1/control/emergency-stop');
    expect(body(calls.single)['zoneId'], 'z1');
    expect(r.stoppedCount, 3);
  });

  test('emergencyStop lỗi 403 không báo thành công', () async {
    handler = (_) => http.Response(jsonEncode({'message': 'forbidden'}), 403);
    expect(AutomationApi.emergencyStop(), throwsA(isA<Exception>()));
  });

  test(
    'getActuatorHistory đọc mảng commands và gửi khoảng thời gian',
    () async {
      handler = (_) => http.Response(
        jsonEncode({
          'zoneId': 'z1',
          'commands': [
            {'commandId': 'c1', 'action': 'TurnOn'},
          ],
        }),
        200,
      );
      final list = await AutomationApi.getActuatorHistory('z1', limit: 10);
      expect(list.single['commandId'], 'c1');
      final q = calls.single.url.queryParameters;
      expect(calls.single.url.path, '/api/v1/zones/z1/actuators/history');
      expect(q['limit'], '10');
      expect(q.containsKey('fromUtc') && q.containsKey('toUtc'), isTrue);
    },
  );

  test(
    'updateZone chỉ gửi trường có giá trị; archiveZone dùng DELETE',
    () async {
      handler = (_) => http.Response(jsonEncode({'zoneId': 'z1'}), 200);
      await FarmApi.updateZone('z1', name: 'Nhà màng A', areaM2: 120);
      expect(calls.single.method, 'PUT');
      expect(body(calls.single), {'name': 'Nhà màng A', 'areaM2': 120});

      calls.clear();
      handler = (_) => http.Response('', 204);
      await FarmApi.archiveZone('z1');
      expect(calls.single.method, 'DELETE');
      expect(calls.single.url.path, '/api/v1/zones/z1');
    },
  );

  test('getLatestTelemetryByDevice đọc mảng devices', () async {
    handler = (_) => http.Response(
      jsonEncode({
        'zoneId': 'z1',
        'devices': [
          {'deviceId': 'd1', 'metrics': []},
        ],
      }),
      200,
    );
    final list = await FarmApi.getLatestTelemetryByDevice('z1');
    expect(list.single['deviceId'], 'd1');
  });

  test('updateDeviceLocations gửi nodes + deploymentRequestId', () async {
    handler = (_) => http.Response('', 204);
    await FarmApi.updateDeviceLocations('z1', [
      {'deviceId': 'd1', 'latitude': 10.5, 'longitude': 106.7},
    ], deploymentRequestId: 'dr1');
    expect(calls.single.url.path, '/api/v1/zones/z1/devices/bulk-locations');
    expect(body(calls.single)['deploymentRequestId'], 'dr1');
    expect((body(calls.single)['nodes'] as List).single['latitude'], 10.5);
  });

  test('recordSeasonYield gửi ngày dạng yyyy-MM-dd', () async {
    handler = (_) => http.Response(jsonEncode({'seasonId': 's1'}), 200);
    await CropApi.recordSeasonYield(
      'z1',
      's1',
      actualYieldKg: 250.5,
      actualEndDate: DateTime(2026, 3, 7),
      markCompleted: true,
    );
    final b = body(calls.single);
    expect(calls.single.url.path, '/api/v1/zones/z1/planting-seasons/s1/yield');
    expect(b['actualEndDate'], '2026-03-07');
    expect(b['actualYieldKg'], 250.5);
    expect(b['markCompleted'], isTrue);
  });

  test('task assignees: POST thêm, DELETE gỡ, đọc task trả về', () async {
    final task = {
      'taskId': 't1',
      'title': 'Tưới',
      'status': 'Pending',
      'assignments': [],
    };
    handler = (_) => http.Response.bytes(
      utf8.encode(jsonEncode(task)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    final added = await TaskApi.addTaskAssignees('f1', 't1', ['u1', 'u2']);
    expect(calls.single.method, 'POST');
    expect(body(calls.single)['farmerIds'], ['u1', 'u2']);
    expect(added.taskId, 't1');

    calls.clear();
    await TaskApi.removeTaskAssignee('f1', 't1', 'u1');
    expect(calls.single.method, 'DELETE');
    expect(calls.single.url.path, '/api/v1/farms/f1/tasks/t1/assignees/u1');
  });

  test('configureGateway gửi danh sách node và chu kỳ', () async {
    handler = (_) => http.Response(jsonEncode({'gatewayId': 'g1'}), 200);
    await DeploymentApi.configureGateway(
      'g1',
      nodeIds: ['d1'],
      telemetryIntervalSec: 120,
      samplesPerInterval: 2,
    );
    final b = body(calls.single);
    expect(calls.single.url.path, '/api/v1/gateways/g1/configuration');
    expect(b['nodeIds'], ['d1']);
    expect(b['telemetryIntervalSec'], 120);
    expect(b.containsKey('installationLocation'), isFalse);
  });

  test(
    'getTechnicianSpareParts chấp nhận cả mảng lẫn {value: [...]}',
    () async {
      handler = (_) => http.Response(
        jsonEncode({
          'value': [
            {'code': 'LORA-01'},
          ],
        }),
        200,
      );
      final parts = await DeploymentApi.getTechnicianSpareParts();
      expect(parts.single['code'], 'LORA-01');
    },
  );

  test(
    'farmWizardSetup gửi đủ cấp Farm → Zone và trả về các id đã tạo',
    () async {
      handler = (_) => http.Response(
        jsonEncode({
          'farmId': 'f1',
          'fieldId': 'fl1',
          'zoneId': 'z1',
          'seasonId': null,
        }),
        200,
      );
      final r = await FarmApi.farmWizardSetup({
        'farm': {
          'name': 'Farm A',
          'latitude': 11.9,
          'longitude': 108.4,
          'totalAreaM2': 10000,
        },
        'field': {'name': 'Lô A1', 'areaM2': 5000},
        'zone': {'name': 'Z01', 'areaM2': 2000},
        'season': null,
        'initialDeploymentRequest': null,
      });
      expect(calls.single.method, 'POST');
      expect(calls.single.url.path, '/api/v1/farms/wizard-setup');
      expect((body(calls.single)['farm'] as Map)['name'], 'Farm A');
      expect(r['zoneId'], 'z1');
    },
  );

  test(
    'updateStageRequirements trả về hồ sơ bản sao khi sửa hồ sơ hệ thống',
    () async {
      handler = (_) => http.Response(
        jsonEncode({
          'effectiveProfileId': 'p2',
          'effectiveStageId': 's2',
          'clonedFromSystem': true,
          'requirements': [],
        }),
        200,
      );
      final r = await CropApi.updateStageRequirements('s1', [
        {
          'parameterCode': 'SoilMoisture',
          'minValue': 60,
          'maxValue': 80,
          'targetValue': 70,
          'unit': '%',
        },
      ]);
      expect(calls.single.method, 'PUT');
      expect(calls.single.url.path, '/api/v1/growth-stages/s1/requirements');
      expect(
        (body(calls.single)['requirements'] as List).single['parameterCode'],
        'SoilMoisture',
      );
      expect(r['clonedFromSystem'], isTrue);
      expect(r['effectiveProfileId'], 'p2');
    },
  );

  test(
    'updateStageDuration lỗi 403 được báo lên, không coi là thành công',
    () async {
      handler = (_) =>
          http.Response(jsonEncode({'message': 'system profile'}), 403);
      expect(CropApi.updateStageDuration('s1', 20), throwsA(isA<Exception>()));
    },
  );

  group('Hợp đồng thuê Zone & khấu hao', () {
    http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(o)),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    test(
      'createZoneContract để backend tính tổng (total = 0) và gửi đủ trường',
      () async {
        handler = (_) => utf8Json({
          'id': 'c1',
          'contractNumber': 'HD-1',
          'totalContractValueVnd': 42000000,
        });
        final c = await ContractApi.createZoneContract('z1', {
          'farmId': 'f1',
          'monthlyRentVnd': 3500000,
          'totalContractValueVnd': 0,
          'startDate': '2026-01-01',
          'endDate': '2027-01-01',
          'lesseeName': 'Nguyễn Văn A',
          'lesseeAddress': 'Đà Lạt',
          'specialTerms': 'Không chuyển nhượng',
        });
        final b = body(calls.single);
        expect(calls.single.url.path, '/api/v1/zones/z1/contracts');
        expect(b['totalContractValueVnd'], 0);
        expect(b['lesseeAddress'], 'Đà Lạt');
        expect(c.totalContractValueVnd, 42000000);
      },
    );

    test(
      'createZoneContract 400 báo đúng thông báo backend, không trả null',
      () async {
        handler = (_) =>
            utf8Json({'message': 'Ngày kết thúc phải sau ngày bắt đầu.'}, 400);
        expect(
          ContractApi.createZoneContract('z1', {'lesseeName': 'A'}),
          throwsA(predicate((e) => e.toString().contains('Ngày kết thúc'))),
        );
      },
    );

    test(
      'getZoneContracts lỗi 500 ném lỗi thay vì trả danh sách rỗng',
      () async {
        handler = (_) => http.Response('', 500);
        expect(
          ContractApi.getZoneContracts(farmId: 'f1'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'getZoneContractById đọc thiết bị, VAT, chiết khấu, gia hạn',
      () async {
        handler = (_) => utf8Json({
          'id': 'c1',
          'contractNumber': 'HD-1',
          'totalContractValueVnd': 10800000,
          'subtotalVnd': 10000000,
          'discountPercent': 10,
          'discountVnd': 1000000,
          'vatPercent': 8,
          'vatAmountVnd': 800000,
          'equipment': [
            {
              'code': 'GW-01',
              'name': 'Gateway LoRa',
              'category': 'Gateway',
              'unit': 'Cái',
              'quantity': 2,
              'unitPrice': 1500000,
            },
          ],
          'renewals': [
            {
              'id': 'r1',
              'contractId': 'c1',
              'newEndDate': '2027-06-01',
              'renewalValueVnd': 5000000,
            },
          ],
        });
        final c = await ContractApi.getZoneContractById('c1');
        expect(calls.single.url.path, '/api/v1/zone-contracts/c1');
        expect(c.vatAmountVnd, 800000);
        expect(c.discountPercent, 10);
        expect(c.equipment.single.lineTotal, 3000000);
        expect(c.renewals.single.newEndDate, '2027-06-01');
      },
    );

    test('renewZoneContract gửi CUSTOM + customEndDate', () async {
      handler = (_) => utf8Json({
        'id': 'c1',
        'contractNumber': 'HD-1',
        'endDate': '2027-09-30',
      });
      await ContractApi.renewZoneContract('c1', {
        'durationPreset': 'CUSTOM',
        'customEndDate': '2027-09-30',
        'discountAmount': 500000,
      });
      final b = body(calls.single);
      expect(calls.single.url.path, '/api/v1/zone-contracts/c1/renew');
      expect(b['durationPreset'], 'CUSTOM');
      expect(b['customEndDate'], '2027-09-30');
    });

    test(
      'createDeviceDepreciation lỗi "thiết bị không thuộc Zone" được báo lên',
      () async {
        handler = (_) => utf8Json({
          'message': 'Thiết bị không tồn tại trong khu vực này.',
        }, 404);
        expect(
          ContractApi.createDeviceDepreciation('z1', {
            'deviceId': 'd1',
            'originalCostVnd': 1,
            'depreciationLifetimeMonths': 12,
          }),
          throwsA(
            predicate((e) => e.toString().contains('Thiết bị không tồn tại')),
          ),
        );
      },
    );
  });
}
