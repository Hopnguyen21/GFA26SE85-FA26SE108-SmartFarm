import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart' show ZoneModel;
import '../../core/services/api_service.dart';
import 'acceptance_report.dart';

/// Tải dữ liệu thật để dựng biên bản nghiệm thu của một Zone: Node đã gắn, vị trí đã lưu, tên nông trại/thửa đất.
/// Dùng cho cả KTV (lúc hoàn tất) và Owner (lúc nghiệm thu). Lỗi tải → null (không bịa số liệu).
Future<AcceptanceReport?> loadAcceptanceReport({
  required String farmId,
  required String zoneId,
  ZoneModel? zone,
  String note = '',
}) async {
  if (zoneId.isEmpty) return null;
  try {
    final results = await Future.wait<Object?>([
      DeploymentApi.getZoneDevices(zoneId),
      FarmApi.getDeviceMapLocations(zoneId),
      FarmApi.getFarmName(farmId),
    ]);
    final z = zone ?? await FarmApi.getZone(zoneId);
    final fieldName = await FarmApi.getFieldName(z.fieldId);
    final devices = [
      for (final d in results[0] as List<Map<String, dynamic>>)
        IotDevice.fromJson(d),
    ];
    final saved = {
      for (final l in results[1] as List<Map<String, dynamic>>)
        '${l['deviceId']}'.toLowerCase(): l,
    };
    String? real(String? fetched, String zoneVal, String placeholder) =>
        (fetched != null && fetched.isNotEmpty)
        ? fetched
        : (zoneVal != placeholder && zoneVal.isNotEmpty ? zoneVal : null);
    return buildAcceptanceReport(
      farm: real(results[2] as String?, z.farmName, 'Nông trại SmartFarm'),
      field: real(fieldName, z.fieldName, 'Lô đất'),
      zone: z.name,
      areaM2: z.areaM2,
      devices: devices.where((d) => d.status != 'Decommissioned'),
      saved: saved,
      note: note,
    );
  } catch (_) {
    return null;
  }
}
