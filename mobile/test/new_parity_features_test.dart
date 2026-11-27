import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/farms/farm_setup_logic.dart';
import 'package:smartfarm_mobile/features/monitoring/monitoring_history_logic.dart';
import 'package:smartfarm_mobile/features/support/estimate_snapshot_dialog.dart';
import 'package:smartfarm_mobile/features/zones/honeycomb_estimate.dart';

Map<String, dynamic> _hw(
  String id,
  String code,
  String role,
  num price, {
  List<String> measured = const [],
  int units = 1,
}) => {
  'id': id,
  'code': code,
  'name': 'Thiết bị $code',
  'category': 'IoT',
  'model': 'M-$code',
  'quantityInStock': 10,
  'unitPrice': price,
  'status': 'InStock',
  'estimateRole': role,
  'estimateUnits': units,
  'measuredParameters': measured,
};

void main() {
  group('Newly Pulled Parity Models & Functions', () {
    test('FirmwareJob and FirmwareRelease JSON serialization', () {
      final jobJson = {
        'otaJobId': 'job-123',
        'gatewayId': 'gw-456',
        'firmwareReleaseId': 'rel-789',
        'targetVersion': '1.2.0',
        'firmwareUrl': 'https://storage.smartfarm.vn/fw/1.2.0.bin',
        'artifactSha256': 'abc123sha',
        'scheduledAtUtc': '2026-11-26T00:00:00Z',
        'status': 'Scheduled',
        'attemptCount': 1,
        'errorMessage': null,
      };

      final job = FirmwareJob.fromJson(jobJson);
      expect(job.otaJobId, 'job-123');
      expect(job.gatewayId, 'gw-456');
      expect(job.firmwareReleaseId, 'rel-789');
      expect(job.targetVersion, '1.2.0');
      expect(job.status, 'Scheduled');
      expect(job.attemptCount, 1);

      final releaseJson = {
        'id': 'rel-789',
        'hardwareTarget': 'ESP32_GATEWAY',
        'version': '1.2.0',
        'protocolVersion': 'MQTT_V1',
        'artifactUrl': 'https://storage.smartfarm.vn/fw/1.2.0.bin',
        'artifactSha256': 'abc123sha',
        'releaseNotes': 'Bug fixes and performance improvements',
        'status': 'Approved',
        'publishedAtUtc': '2026-11-25T10:00:00Z',
      };

      final release = FirmwareRelease.fromJson(releaseJson);
      expect(release.id, 'rel-789');
      expect(release.hardwareTarget, 'ESP32_GATEWAY');
      expect(release.version, '1.2.0');
      expect(release.status, 'Approved');
      expect(release.releaseNotes, contains('Bug fixes'));
    });

    test(
      'IotGateway carries farmName and DeploymentRequest carries estimateSnapshotJson',
      () {
        final gwJson = {
          'gatewayId': 'gw-01',
          'gatewaySerial': 'GW-SERIAL-99',
          'macAddress': 'AA:BB:CC:DD:EE:FF',
          'status': 'Online',
          'farmId': 'farm-01',
          'farmName': 'Trang trại Đà Lạt Farm',
        };

        final gw = IotGateway.fromJson(gwJson);
        expect(gw.gatewayId, 'gw-01');
        expect(gw.farmName, 'Trang trại Đà Lạt Farm');

        final depJson = {
          'requestId': 'req-01',
          'farmId': 'farm-01',
          'zoneId': 'zone-01',
          'status': 'Draft',
          'estimateSnapshotJson':
              '{"algorithmVersion":"honeycomb-v1","sensingRadiusMeters":25.0,"gateways":2,"sensors":6,"actuators":4}',
        };

        final dep = DeploymentRequest.fromJson(depJson);
        expect(dep.requestId, 'req-01');
        expect(dep.estimateSnapshotJson, isNotNull);
        expect(dep.estimateSnapshotJson, contains('honeycomb-v1'));
      },
    );

    test(
      'buildWizardEstimateSnapshot produces valid Honeycomb snapshot Map matching Web',
      () {
        final catalog = [
          _hw('gw-1', 'GW', 'Gateway', 3500000),
          _hw(
            'node-1',
            'NODE',
            'SensorNode',
            1200000,
            measured: ['Temperature', 'SoilMoisture'],
          ),
          _hw('valve-1', 'VALVE', 'ActuatorNode', 1500000),
          _hw('kit-1', 'KIT', 'InstallKit', 200000),
        ];

        final honeycombEst = computeHoneycombEstimate(
          areaM2: 25000,
          radiusM: 30,
          actuatorRatio: 0.5,
          catalog: HoneycombCatalog.fromHardwareItems(catalog),
          requiredParameters: ['Temperature'],
        );

        final snapshot = buildWizardEstimateSnapshot(
          honeycombEst,
          areaM2: 25000.0,
        );
        expect(snapshot, isNotEmpty);
        expect(snapshot['algorithmVersion'], 'v1');
        expect(snapshot['areaM2'], 25000.0);
        expect(snapshot['sensingRadiusM'], 30.0);
        expect(snapshot['gateways'], honeycombEst.gateways);
        expect(snapshot['sensors'], honeycombEst.sensors);
        expect(snapshot['actuators'], honeycombEst.actuators);
        expect((snapshot['estimateItems'] as List).isNotEmpty, true);
      },
    );

    test(
      'historyKey in monitoring_history_logic accepts optional deviceId',
      () {
        final keyWithoutDev = historyKey('z-1', 'TEMP', '24 Giờ');
        expect(keyWithoutDev, 'z-1|TEMP|24 Giờ|');

        final keyWithDev = historyKey('z-1', 'TEMP', '24 Giờ', 'dev-99');
        expect(keyWithDev, 'z-1|TEMP|24 Giờ|dev-99');
      },
    );

    testWidgets(
      'EstimateSnapshotDialog renders Honeycomb snapshot details correctly',
      (tester) async {
        final snapshot = jsonEncode({
          'algorithmVersion': 'v1',
          'areaM2': 15000.0,
          'sensingRadiusM': 25.0,
          'gateways': 1,
          'sensors': 4,
          'actuators': 2,
          'totalCostVnd': 18500000.0,
          'estimateItems': [
            {
              'name': 'Bộ Gateway Trung tâm',
              'role': 'Gateway',
              'quantity': 1,
              'unitPrice': 3500000.0,
              'lineTotal': 3500000.0,
            },
            {
              'name': 'Node Cảm biến Vi khí hậu',
              'role': 'SensorNode',
              'quantity': 4,
              'unitPrice': 2500000.0,
              'lineTotal': 10000000.0,
            },
            {
              'name': 'Node Điều khiển Tưới',
              'role': 'ActuatorNode',
              'quantity': 2,
              'unitPrice': 2500000.0,
              'lineTotal': 5000000.0,
            },
          ],
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => EstimateSnapshotDialog.show(ctx, snapshot),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Dự toán thuật toán Tổ ong đã lưu'), findsOneWidget);
        expect(find.text('15.000 m²'), findsOneWidget);
        expect(find.text('Bộ Gateway Trung tâm'), findsOneWidget);
        expect(find.text('Node Cảm biến Vi khí hậu'), findsOneWidget);
        expect(find.text('Node Điều khiển Tưới'), findsOneWidget);
        expect(find.text('Đóng'), findsOneWidget);
      },
    );
  });
}
