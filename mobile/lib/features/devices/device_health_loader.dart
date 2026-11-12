import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';

/// Nạp tình trạng thiết bị IoT thật từ backend (không có dữ liệu mẫu):
/// - GET /farms/{id}/gateways → gateway (lần cuối thấy, chu kỳ gửi)
/// - GET /farms/{id}/devices  → node (lần cuối thấy, chu kỳ heartbeat)
/// - GET /zones/{id}/devices/map-locations → pin & sóng (RSSI) của từng node
/// Owner xem trang trại đang chọn; kỹ thuật viên xem các trang trại có yêu cầu triển khai được giao.
Future<List<DeviceHealthModel>> loadDeviceHealth(FarmProvider provider) async {
  final farmIds = <String>{};
  if (provider.currentRole == 'TECHNICIAN') {
    final requests = await DeploymentApi.getTechnicianDeploymentRequests();
    farmIds.addAll(requests.map((r) => r.farmId).where((id) => id.isNotEmpty));
  } else if (provider.selectedFarmId.isNotEmpty) {
    farmIds.add(provider.selectedFarmId);
  }

  final result = <DeviceHealthModel>[];
  for (final farmId in farmIds) {
    final fetched = await Future.wait([
      DeploymentApi.getFarmGatewaysRaw(farmId),
      DeploymentApi.getFarmDevicesRaw(farmId),
    ]);
    final gateways = fetched[0];
    final devices = fetched[1];

    // Pin/RSSI chỉ có ở API vị trí theo Zone.
    final zoneIds = {
      for (final d in devices)
        if ('${d['zoneId'] ?? ''}'.isNotEmpty) '${d['zoneId']}',
    };
    final telemetry = <String, Map<String, dynamic>>{};
    for (final zoneId in zoneIds) {
      try {
        for (final loc in await FarmApi.getDeviceMapLocations(zoneId)) {
          telemetry['${loc['deviceId']}'.toLowerCase()] = loc;
        }
      } catch (_) {
        // Zone không đọc được thì hiển thị node không kèm pin/sóng.
      }
    }

    for (final g in gateways) {
      result.add(
        DeviceHealthModel(
          nodeId: '${g['gatewaySerial'] ?? g['gatewayId']}',
          name: 'Gateway ${g['gatewaySerial'] ?? ''}'.trim(),
          type: 'GATEWAY',
          lastSeenAt: DateTime.tryParse(
            '${g['lastSeenAtUtc'] ?? ''}',
          )?.toLocal(),
          expectedIntervalSeconds:
              (g['telemetryIntervalSec'] as num?)?.toInt() ?? 60,
        ),
      );
    }
    for (final d in devices) {
      final loc = telemetry['${d['deviceId']}'.toLowerCase()];
      final isActuator = '${d['deviceType']}' == 'ActuatorNode';
      result.add(
        DeviceHealthModel(
          nodeId: '${d['hardwareAddress'] ?? d['deviceId']}',
          name:
              '${isActuator ? 'Node chấp hành' : 'Node cảm biến'} ${d['hardwareAddress'] ?? ''}'
                  .trim(),
          type: isActuator ? 'ACTUATOR_NODE' : 'SENSOR_NODE',
          lastSeenAt: DateTime.tryParse(
            '${d['lastSeenAtUtc'] ?? ''}',
          )?.toLocal(),
          expectedIntervalSeconds:
              (d['heartbeatIntervalSeconds'] as num?)?.toInt() ?? 60,
          signalRssi: (loc?['rssi'] as num?)?.toDouble(),
          batteryPercent: (loc?['batteryLevel'] as num?)?.toInt(),
        ),
      );
    }
  }
  return result;
}
