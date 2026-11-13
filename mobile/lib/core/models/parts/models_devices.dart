part of '../models.dart';

class ActuatorModel {
  final String actuatorId;
  final String zoneId;
  final String name;
  final String actuatorType; // PUMP, FAN, VALVE, GROW_LIGHT
  bool isRunning;
  int remainingMinutes;

  ActuatorModel({
    required this.actuatorId,
    required this.zoneId,
    required this.name,
    required this.actuatorType,
    this.isRunning = false,
    this.remainingMinutes = 0,
  });

  factory ActuatorModel.fromJson(
    Map<String, dynamic> json, {
    String defaultZoneId = '',
  }) {
    final rawType =
        (json['actuatorType'] ?? json['type'])?.toString().toUpperCase() ??
        'PUMP';
    final type = switch (rawType) {
      'IRRIGATIONPUMP' || 'PUMP' => 'PUMP',
      'VENTILATIONFAN' || 'FAN' => 'FAN',
      'MISTSPRAYER' || 'VALVE' => 'VALVE',
      'GROWLIGHT' || 'GROW_LIGHT' => 'GROW_LIGHT',
      _ => rawType,
    };
    final state =
        (json['status'] ?? json['currentState'] ?? '')
            ?.toString()
            .toUpperCase() ??
        '';
    final isRunning = state == 'ON' || state == 'ACTIVE' || state == 'RUNNING';
    final remainingSec = (json['remainingSeconds'] as num?)?.toInt() ?? 0;

    return ActuatorModel(
      actuatorId:
          json['actuatorId']?.toString() ?? json['id']?.toString() ?? '',
      zoneId: json['zoneId']?.toString() ?? defaultZoneId,
      name:
          json['name']?.toString() ??
          (type == 'PUMP' ? 'Máy bơm tưới nhỏ giọt' : 'Thiết bị chấp hành'),
      actuatorType: type,
      isRunning: isRunning,
      remainingMinutes: (remainingSec / 60).ceil(),
    );
  }
}

class DeviceHealthModel {
  final String nodeId;
  final String name;
  final String type; // GATEWAY, SENSOR_NODE, ACTUATOR_NODE
  final DateTime? lastSeenAt; // null: chưa từng nhận dữ liệu
  final int expectedIntervalSeconds;
  final double? signalRssi; // null: backend chưa có số đo
  final int? batteryPercent; // null: backend chưa có số đo

  DeviceHealthModel({
    required this.nodeId,
    required this.name,
    required this.type,
    required this.lastSeenAt,
    required this.expectedIntervalSeconds,
    this.signalRssi,
    this.batteryPercent,
  });

  /// Phát hiện theo thời gian im lặng (timeout), không đếm gói rớt: ≤ 3× chu kỳ → ONLINE,
  /// ≤ 12× chu kỳ → WARNING, lâu hơn hoặc chưa từng thấy → OFFLINE.
  String get healthStatus {
    final seen = lastSeenAt;
    if (seen == null) return 'OFFLINE';
    final diffSec = DateTime.now().difference(seen).inSeconds;
    if (diffSec <= expectedIntervalSeconds * 3) return 'ONLINE';
    if (diffSec <= expectedIntervalSeconds * 12) return 'WARNING';
    return 'OFFLINE';
  }

  String get lastSeenText {
    final seen = lastSeenAt;
    if (seen == null) return 'Chưa có dữ liệu';
    final diff = DateTime.now().difference(seen);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
    if (diff.inHours < 48) return '${diff.inHours}h trước';
    return '${diff.inDays} ngày trước';
  }
}

/// Kết quả của POST /api/v1/control/emergency-stop.
class EmergencyStopResult {
  final bool success;
  final int stoppedCount;
  final String message;

  const EmergencyStopResult({
    required this.success,
    required this.stoppedCount,
    required this.message,
  });

  factory EmergencyStopResult.fromJson(Map<String, dynamic> json) {
    final count = (json['stoppedCount'] as num?)?.toInt() ?? 0;
    final msg = json['message']?.toString();
    return EmergencyStopResult(
      success: json['success'] == true,
      stoppedCount: count,
      message: (msg == null || msg.isEmpty)
          ? 'Đã phát lệnh dừng khẩn cấp $count rơ-le.'
          : msg,
    );
  }
}

// ─────────────────────────────────────────
// Mô hình Mạng Tổ Ong (Lục Giác - Honeycomb IoT Topology) chuẩn FE
// ─────────────────────────────────────────
class HoneycombTopologySimulation {
  final double areaM2;
  final String cropName;
  final String cropIcon;
  final String cropColor;
  final int gateways;
  final int sensors;
  final int actuators;
  final int hexagonCells;

  // Đơn giá chuẩn FE (VNĐ)
  final double gatewayUnitPrice;
  final double sensorUnitPrice;
  final double actuatorUnitPrice;
  final double installationFee;

  // Tổng & Dải dao động chi phí
  final double totalDeviceCostVND;
  final double minCostVND;
  final double maxCostVND;

  // Metadata Template VietGAP
  final String growthCycle;
  final String nutritionInfo;
  final String lightRequirement;
  final String tempRange;
  final String humidityRange;
  final String seasonDuration;
  final String note;
  final List<String> varieties;

  const HoneycombTopologySimulation({
    required this.areaM2,
    required this.cropName,
    required this.cropIcon,
    required this.cropColor,
    required this.gateways,
    required this.sensors,
    required this.actuators,
    required this.hexagonCells,
    required this.gatewayUnitPrice,
    required this.sensorUnitPrice,
    required this.actuatorUnitPrice,
    required this.installationFee,
    required this.totalDeviceCostVND,
    required this.minCostVND,
    required this.maxCostVND,
    required this.growthCycle,
    required this.nutritionInfo,
    required this.lightRequirement,
    required this.tempRange,
    required this.humidityRange,
    required this.seasonDuration,
    required this.note,
    required this.varieties,
  });

  const HoneycombTopologySimulation.empty()
    : areaM2 = 0,
      cropName = '',
      cropIcon = '🌱',
      cropColor = 'emerald',
      gateways = 1,
      sensors = 2,
      actuators = 1,
      hexagonCells = 1,
      gatewayUnitPrice = 3500000,
      sensorUnitPrice = 850000,
      actuatorUnitPrice = 650000,
      installationFee = 500000,
      totalDeviceCostVND = 5850000,
      minCostVND = 4972500,
      maxCostVND = 7312500,
      growthCycle = '',
      nutritionInfo = '',
      lightRequirement = '',
      tempRange = '',
      humidityRange = '',
      seasonDuration = '',
      note = '',
      varieties = const [];

  factory HoneycombTopologySimulation.calculate({
    required double areaM2,
    required String cropName,
  }) {
    final validArea = areaM2 <= 0 ? 500.0 : areaM2;
    final lower = cropName.toLowerCase();

    // Chuẩn FE CreateFarmWizard.tsx:
    double sensorsPer500m2 = 1.0;
    double actuatorsPer500m2 = 1.2;
    double gatewayPer3000m2 = 1.0;
    String icon = '🍅';
    String color = 'emerald';
    List<String> varieties = [
      'Beefsteak Đà Lạt F1',
      'Cherry Vàng F1',
      'Bi đỏ VN888',
      'Pink Lady F1',
    ];
    String note = 'Cà chua cần theo dõi độ ẩm đất & nhiệt độ chặt chẽ';
    String growthStage = 'Mầm ➔ Sinh trưởng ➔ Ra hoa ➔ Tạo quả';
    String nutrition = 'N-P-K (5-10-5 mầm, 5-10-10 hoa)';
    String light = '12-14 giờ/ngày';
    String temp = 'Ngày: 21-29°C, Đêm: 15-20°C';
    String humidity = '60-70%';
    String duration = '90-120 ngày';

    if (lower.contains('ớt') ||
        lower.contains('pepper') ||
        lower.contains('capsicum')) {
      icon = '🫑';
      color = 'red';
      sensorsPer500m2 = 0.8;
      actuatorsPer500m2 = 1.0;
      gatewayPer3000m2 = 1.0;
      varieties = [
        'Ớt Đà Lạt F1',
        'California Wonder',
        'Chuông Đỏ Hà Lan',
        'Sweet Baby',
      ];
      note = 'Ớt cần cảm biến ánh sáng và kiểm soát tưới chính xác';
      growthStage = 'Mầm ➔ Phát triển cành ➔ Ra hoa ➔ Kết trái';
      nutrition = 'N-P-K (Tăng Kali khi kết trái)';
      light = '10-12 giờ/ngày';
      temp = 'Ngày: 25-28°C, Đêm: 18-20°C';
      humidity = '55-65%';
      duration = '100-150 ngày';
    } else if (lower.contains('dưa') ||
        lower.contains('cucumber') ||
        lower.contains('cucumis')) {
      icon = '🥒';
      color = 'green';
      sensorsPer500m2 = 0.8;
      actuatorsPer500m2 = 0.8;
      gatewayPer3000m2 = 1.0;
      varieties = [
        'Dưa Nhật TN-088',
        'Dưa baby VN',
        'Cucumber F1 Hà Lan',
        'Mini Cuke',
      ];
      note = 'Dưa leo phát triển nhanh, cần theo dõi độ ẩm không khí';
      growthStage = 'Mầm ➔ Leo giàn ➔ Ra hoa cái ➔ Trái non';
      nutrition = 'Tăng Đạm giai đoạn đầu, Lân giai đoạn hoa';
      light = '10-14 giờ/ngày';
      temp = 'Ngày: 24-30°C, Đêm: 18-22°C';
      humidity = '70-85%';
      duration = '60-80 ngày';
    } else if (lower.contains('xà lách') ||
        lower.contains('thủy canh') ||
        lower.contains('cải') ||
        lower.contains('lactuca')) {
      icon = '🥬';
      color = 'lime';
      sensorsPer500m2 = 1.2;
      actuatorsPer500m2 = 1.5;
      gatewayPer3000m2 = 1.0;
      varieties = [
        'Butterhead F1',
        'Romaine Viet',
        'Oakleaf xanh',
        'Lollo Rossa',
      ];
      note = 'Thủy canh cần giám sát EC/pH + van bơm dinh dưỡng liên tục';
      growthStage = 'Ươm hạt ➔ Lên giàn ➔ Phát triển lá ➔ Thu hoạch';
      nutrition = 'EC: 1.2 - 1.8 mS/cm, pH: 5.8 - 6.2';
      light = '14-16 giờ/ngày';
      temp = 'Ngày: 18-24°C, Đêm: 15-18°C';
      humidity = '50-70%';
      duration = '40-50 ngày';
    } else if (lower.contains('dâu') ||
        lower.contains('strawberry') ||
        lower.contains('fragaria')) {
      icon = '🍓';
      color = 'red';
      sensorsPer500m2 = 1.2;
      actuatorsPer500m2 = 1.2;
      gatewayPer3000m2 = 1.0;
      varieties = [
        'Dâu New Zealand',
        'Dâu Nhật Hana',
        'Dâu Mỹ Albion',
        'Dâu Bạch Tuyết',
      ];
      note =
          'Rất nhạy cảm với độ ẩm giá thể & nấm rễ, cần tưới nhỏ giọt chính xác';
      growthStage = 'Cây giống ➔ Phân hóa chồi hoa ➔ Đậu quả ➔ Thu hoạch';
      nutrition = 'Dinh dưỡng hữu cơ vi lượng chelate';
      light = '12-14 giờ/ngày';
      temp = 'Ngày: 20-25°C, Đêm: 12-16°C';
      humidity = '65-75%';
      duration = '90-110 ngày';
    }

    const gatewayUnitPrice = 3500000.0;
    const sensorUnitPrice = 850000.0;
    const actuatorUnitPrice = 650000.0;
    const installationFee = 500000.0;

    final gateways = math.max(
      1,
      (validArea / 3000.0 * gatewayPer3000m2).ceil(),
    );
    final sensors = math.max(2, (validArea / 500.0 * sensorsPer500m2).ceil());
    final actuators = math.max(
      1,
      (validArea / 500.0 * actuatorsPer500m2).ceil(),
    );
    final hexagonCells = math.max(1, (validArea / 500.0).ceil());

    final totalCost =
        (gateways * gatewayUnitPrice) +
        (sensors * sensorUnitPrice) +
        (actuators * actuatorUnitPrice) +
        installationFee;
    final minCost = (totalCost * 0.85).roundToDouble();
    final maxCost = (totalCost * 1.25).roundToDouble();

    return HoneycombTopologySimulation(
      areaM2: validArea,
      cropName: cropName,
      cropIcon: icon,
      cropColor: color,
      gateways: gateways,
      sensors: sensors,
      actuators: actuators,
      hexagonCells: hexagonCells,
      gatewayUnitPrice: gatewayUnitPrice,
      sensorUnitPrice: sensorUnitPrice,
      actuatorUnitPrice: actuatorUnitPrice,
      installationFee: installationFee,
      totalDeviceCostVND: totalCost,
      minCostVND: minCost,
      maxCostVND: maxCost,
      growthCycle: growthStage,
      nutritionInfo: nutrition,
      lightRequirement: light,
      tempRange: temp,
      humidityRange: humidity,
      seasonDuration: duration,
      note: note,
      varieties: varieties,
    );
  }
}
