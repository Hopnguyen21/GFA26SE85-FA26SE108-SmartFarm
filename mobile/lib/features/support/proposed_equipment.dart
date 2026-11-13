import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../zones/honeycomb_estimate.dart';

/// Đổi bảng dự toán "Thiết bị đề xuất" (thuật toán tổ ong theo diện tích Zone) thành các dòng báo giá.
/// Chỉ lấy dòng cần bổ sung và có thiết bị kèm đơn giá trong kho; dòng thiếu thiết bị/đơn giá bị bỏ (không bịa giá).
/// Có dòng hàng thì thêm dòng thi công như phần đề xuất của chủ trại. Ghi chú nói rõ đây là ước tính.
List<QuotationItem> quotationItemsFromEstimate(
  HoneycombEstimate est, {
  double vatPercent = 8,
}) {
  QuotationItem line({
    required String code,
    required String name,
    required String category,
    required String unit,
    required int quantity,
    required double unitPrice,
    required String notes,
  }) => QuotationItem(
    code: code,
    name: name,
    category: category,
    unit: unit,
    quantity: quantity,
    unitPrice: unitPrice,
    vatPercent: vatPercent,
    totalAmount: quantity * unitPrice * (1 + vatPercent / 100),
    notes: notes,
  );

  (String, String) shape(EstimateRole role) => switch (role) {
    EstimateRole.gateway => ('GATEWAY', 'Trạm'),
    EstimateRole.sensorNode => ('SENSOR_NODE', 'Node'),
    EstimateRole.actuatorNode => ('ACTUATOR_NODE', 'Node'),
    EstimateRole.installKit => ('ACCESSORY', 'Bộ'),
  };

  final items = <QuotationItem>[];
  for (final l in est.lines) {
    final item = l.item;
    if (l.covered || item == null || l.quantity <= 0 || item.unitPrice <= 0) {
      continue;
    }
    final (category, unit) = shape(l.role);
    items.add(
      line(
        code: item.code,
        name: item.name,
        category: category,
        unit: unit,
        quantity: l.quantity,
        unitPrice: item.unitPrice,
        notes:
            'Cần ${l.neededTotal}, đã gắn ${l.installed}, bổ sung ${l.requiredUnits} ${l.role.label.toLowerCase()} · ước tính theo diện tích Zone',
      ),
    );
  }
  if (items.isNotEmpty && est.installationCost > 0) {
    items.add(
      line(
        code: 'INSTALLATION',
        name: 'Thi công, định vị GPS & cấu hình mạng mesh',
        category: 'SERVICE',
        unit: 'Gói',
        quantity: 1,
        unitPrice: est.installationCost,
        notes: 'Ước tính theo diện tích Zone',
      ),
    );
  }
  return items;
}

/// Dự toán thiết bị đề xuất cho một Zone, tính ngay trên máy theo cùng cách với màn gửi yêu cầu của chủ trại:
/// diện tích và chu vi Zone, cây trồng, thông số cần đo, thiết bị đã gắn và đơn giá trong kho.
/// Dùng khi chủ trại chưa lưu dự toán kèm yêu cầu. Lỗi tải kho/thiết bị thì ném ra để người gọi báo rõ.
Future<List<QuotationItem>> proposedItemsForZone(
  ZoneModel zone, {
  List<String> requiredParameters = const [],
}) async {
  final results = await Future.wait<List<Map<String, dynamic>>>([
    DeploymentApi.getHardwareItems(),
    DeploymentApi.getZoneDevices(zone.zoneId),
  ]);
  final polygon = zone.polygon;
  final est = computeHoneycombEstimate(
    areaM2: zone.areaM2,
    radiusM: honeycombFixedRadiusM,
    actuatorRatio: honeycombActuatorRatio(zone.currentCrop),
    catalog: HoneycombCatalog.fromHardwareItems(results[0]),
    requiredParameters: requiredParameters,
    installed: ZoneInstalledDevices.fromJson(results[1]),
    perimeterM: polygon == null
        ? null
        : convexHullPerimeterM([
            for (final p in polygon) (lat: p.latitude, lng: p.longitude),
          ]),
  );
  return quotationItemsFromEstimate(est);
}
