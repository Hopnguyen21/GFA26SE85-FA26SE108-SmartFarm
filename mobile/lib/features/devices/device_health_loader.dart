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
  // Kỹ thuật viên có nhiều trang trại: tên Zone/trang trại giúp phân biệt các node trùng tên.
  final farmNames = <String, String>{};
  final zoneNames = <String, String>{};
  final isTech = provider.currentRole == 'TECHNICIAN';
  if (isTech) {
    final requests = await DeploymentApi.getTechnicianDeploymentRequests();
    for (final r in requests) {
      // Chỉ yêu cầu đang lắp đặt hoặc đã chuyển bảo trì mới có thiết bị và còn được backend cho đọc trang trại;
      // yêu cầu chưa tiếp nhận hay đã hoàn tất thì trang trại không đọc được (404).
      if (r.farmId.isEmpty ||
          (r.status != 'Installing' && r.status != 'MaintenanceRequired')) {
        continue;
      }
      farmIds.add(r.farmId);
      final c = r.context;
      if (c != null) {
        farmNames[r.farmId] = c.farmName;
        zoneNames[r.zoneId.toLowerCase()] = c.zoneName;
      }
    }
  } else if (provider.selectedFarmId.isNotEmpty) {
    farmIds.add(provider.selectedFarmId);
  }

  final result = <DeviceHealthModel>[];
  Object? firstError;
  for (final farmId in farmIds) {
    final List<Map<String, dynamic>> gateways;
    final List<Map<String, dynamic>> devices;
    try {
      final fetched = await Future.wait([
        DeploymentApi.getFarmGatewaysRaw(farmId),
        DeploymentApi.getFarmDevicesRaw(farmId),
      ]);
      gateways = fetched[0];
      devices = fetched[1];
    } catch (e) {
      // Một trang trại không đọc được không được làm mất thiết bị của các trang trại còn lại.
      firstError ??= e;
      continue;
    }
    String where(String? zoneId) {
      final zone = zoneNames[(zoneId ?? '').toLowerCase()];
      final farm = farmNames[farmId];
      final parts = [zone, farm].whereType<String>().where((s) => s.isNotEmpty);
      return !isTech || parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
    }

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
          name: '${'Gateway ${g['gatewaySerial'] ?? ''}'.trim()}${where(null)}',
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
              '${'${isActuator ? 'Node chấp hành' : 'Node cảm biến'} ${d['hardwareAddress'] ?? ''}'.trim()}${where('${d['zoneId'] ?? ''}')}',
          type: isActuator ? 'ACTUATOR_NODE' : 'SENSOR_NODE',
          lastSeenAt: DateTime.tryParse(
            '${d['lastSeenAtUtc'] ?? ''}',
          )?.toLocal(),
          expectedIntervalSeconds:
              (d['heartbeatIntervalSeconds'] as num?)?.toInt() ?? 60,
          signalRssi: (loc?['rssi'] as num?)?.toDouble(),
          batteryPercent: (loc?['batteryLevel'] as num?)?.toInt(),
          deviceId: '${d['deviceId']}',
          zoneId: '${d['zoneId'] ?? ''}'.isEmpty ? null : '${d['zoneId']}',
        ),
      );
    }
  }
  // Chỉ báo lỗi khi KHÔNG đọc được trang trại nào; có ít nhất một trang trại thì trả phần đọc được.
  if (result.isEmpty && firstError != null) throw firstError;
  return result;
}
