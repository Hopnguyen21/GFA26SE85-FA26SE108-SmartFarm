import 'models.dart' show BusinessParameters;

// DTO của luồng triển khai IoT (IOT-V1) và báo giá/hợp đồng lắp đặt (service request).
// Phản chiếu SmartFarm.Application.Features.IoTDeployment / Platform; mọi trạng thái lấy từ backend.

/// Backend serialize enum dạng chuỗi (JsonStringEnumConverter); vẫn chấp nhận số để không vỡ khi cấu hình đổi.
String enumName(dynamic value, List<String> names) {
  if (value is int && value >= 0 && value < names.length) return names[value];
  return value?.toString() ?? '';
}

const deploymentStatuses = [
  'Draft',
  'Submitted',
  'Accepted',
  'Surveyed',
  'PlanConfirmed',
  'Installing',
  'Completed',
  'MaintenanceRequired',
];
const deviceTypes = ['SensorNode', 'ActuatorNode'];
const deviceStatuses = [
  'Unassigned',
  'Assigned',
  'SensorsConfigured',
  'ActuatorsConfigured',
  'Online',
  'Offline',
  'MaintenanceRequired',
  'Decommissioned',
];

const deploymentStatusLabels = <String, String>{
  'Draft': 'Bản nháp',
  'Submitted': 'Đã gửi, chờ kỹ thuật viên',
  'Accepted': 'KTV đã tiếp nhận',
  'Surveyed': 'Đã khảo sát',
  'PlanConfirmed': 'Đã xác nhận kế hoạch',
  'Installing': 'Đang lắp đặt',
  'Completed': 'Hoàn tất triển khai',
  'MaintenanceRequired': 'Thất bại, chuyển bảo trì',
  'Cancelled': 'Đã hủy',
};

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
List<String> _strings(dynamic v) =>
    (v as List? ?? const []).map((e) => e.toString()).toList();

class IotRequirements {
  final String zoneId;
  final double zoneAreaM2;
  final List<String> parameters;
  IotRequirements({
    required this.zoneId,
    required this.zoneAreaM2,
    required this.parameters,
  });
  factory IotRequirements.fromJson(Map<String, dynamic> j) => IotRequirements(
    zoneId: '${j['zoneId']}',
    zoneAreaM2: _num(j['zoneAreaM2']),
    parameters: _strings(j['parameters']),
  );
}

class PlanItem {
  final String deviceModelId;
  final String modelName;
  final String deviceType;
  final int quantity;
  final String? installationNotes;
  PlanItem({
    required this.deviceModelId,
    required this.modelName,
    required this.deviceType,
    required this.quantity,
    this.installationNotes,
  });
  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    deviceModelId: '${j['deviceModelId']}',
    modelName: '${j['modelName']}',
    deviceType: enumName(j['deviceType'], deviceTypes),
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    installationNotes: j['installationNotes'] as String?,
  );
  Map<String, dynamic> toRequestJson() => {
    'deviceModelId': deviceModelId,
    'quantity': quantity,
    if (installationNotes != null && installationNotes!.trim().isNotEmpty)
      'installationNotes': installationNotes,
  };
}

class DeploymentSurvey {
  final bool isFeasible;
  final String siteConditions;
  final String notes;
  final String surveyedAtUtc;
  DeploymentSurvey({
    required this.isFeasible,
    required this.siteConditions,
    required this.notes,
    required this.surveyedAtUtc,
  });
  factory DeploymentSurvey.fromJson(Map<String, dynamic> j) => DeploymentSurvey(
    isFeasible: j['isFeasible'] == true,
    siteConditions: '${j['siteConditions'] ?? ''}',
    notes: '${j['notes'] ?? ''}',
    surveyedAtUtc: '${j['surveyedAtUtc'] ?? ''}',
  );
}

class DeploymentDecision {
  final String decisionType;
  final String fromStatus;
  final String toStatus;
  final String? notes;
  final String decidedAtUtc;
  DeploymentDecision({
    required this.decisionType,
    required this.fromStatus,
    required this.toStatus,
    this.notes,
    required this.decidedAtUtc,
  });
  factory DeploymentDecision.fromJson(Map<String, dynamic> j) =>
      DeploymentDecision(
        decisionType: '${j['decisionType'] ?? ''}',
        fromStatus: enumName(j['fromStatus'], deploymentStatuses),
        toStatus: enumName(j['toStatus'], deploymentStatuses),
        notes: j['notes'] as String?,
        decidedAtUtc: '${j['decidedAtUtc'] ?? ''}',
      );
}

/// Dòng dự toán thiết bị Owner đã lưu cùng yêu cầu (ảnh chụp mã/tên/đơn giá lúc lưu). Là nguồn để kỹ thuật viên chỉnh sửa
/// và đưa vào báo giá/hợp đồng; chưa phải kế hoạch thiết bị chính thức.
class EstimateItem {
  final String id;
  final String? hardwareItemId;
  final String code;
  final String name;
  final String? model;
  final String role;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? notes;
  EstimateItem({
    required this.id,
    this.hardwareItemId,
    required this.code,
    required this.name,
    this.model,
    required this.role,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.notes,
  });
  factory EstimateItem.fromJson(Map<String, dynamic> j) {
    final qty = (j['quantity'] as num?)?.toInt() ?? 0;
    final price = (j['unitPrice'] as num?)?.toDouble() ?? 0;
    return EstimateItem(
      id: '${j['estimateItemId']}',
      hardwareItemId: j['hardwareItemId']?.toString(),
      code: '${j['code'] ?? ''}',
      name: '${j['name'] ?? ''}',
      model: j['model']?.toString(),
      role: '${j['role'] ?? ''}',
      quantity: qty,
      unitPrice: price,
      lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? qty * price,
      notes: j['notes']?.toString(),
    );
  }
}

const zoneTypeLabels = {
  'Greenhouse': 'Nhà màng',
  'OpenField': 'Ngoài trời',
  'NetHouse': 'Nhà lưới',
};
const soilTypeLabels = {
  'Loam': 'Đất thịt',
  'Clay': 'Đất sét',
  'Sandy': 'Đất cát',
  'Silt': 'Đất phù sa',
};
const seasonStatusLabels = {
  'Planned': 'Kế hoạch',
  'InProgress': 'Đang canh tác',
  'Completed': 'Đã kết thúc',
  'Cancelled': 'Đã hủy',
};

/// Ngữ cảnh của yêu cầu triển khai: lắp đặt ở farm/thửa đất/Zone nào, cây và vụ mùa nào (backend trả kèm yêu cầu).
class DeploymentContext {
  final String farmName;
  final String? farmLocation;
  final String fieldName;
  final String? soilType;
  final String zoneName;
  final String zoneType;
  final double zoneAreaM2;
  final String? cropName;
  final String? varietyName;
  final String seasonName;
  final String seasonStatus;
  final String seasonStart; // yyyy-MM-dd
  final String seasonExpectedEnd;
  DeploymentContext({
    required this.farmName,
    this.farmLocation,
    required this.fieldName,
    this.soilType,
    required this.zoneName,
    required this.zoneType,
    required this.zoneAreaM2,
    this.cropName,
    this.varietyName,
    required this.seasonName,
    required this.seasonStatus,
    required this.seasonStart,
    required this.seasonExpectedEnd,
  });
  factory DeploymentContext.fromJson(Map<String, dynamic> j) =>
      DeploymentContext(
        farmName: '${j['farmName'] ?? ''}',
        farmLocation: j['farmLocation']?.toString(),
        fieldName: '${j['fieldName'] ?? ''}',
        soilType: j['soilType']?.toString(),
        zoneName: '${j['zoneName'] ?? ''}',
        zoneType: '${j['zoneType'] ?? ''}',
        zoneAreaM2: (j['zoneAreaM2'] as num?)?.toDouble() ?? 0,
        cropName: j['cropName']?.toString(),
        varietyName: j['varietyName']?.toString(),
        seasonName: '${j['seasonName'] ?? ''}',
        seasonStatus: '${j['seasonStatus'] ?? ''}',
        seasonStart: '${j['seasonStartDate'] ?? ''}',
        seasonExpectedEnd: '${j['seasonExpectedEndDate'] ?? ''}',
      );

  /// yyyy-MM-dd → dd/MM/yyyy (giữ nguyên nếu không đúng định dạng).
  static String vnDate(String iso) {
    final p = iso.split('-');
    return p.length == 3 && p[0].length == 4 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}

class DeploymentRequest {
  final String requestId;
  final String farmId;
  final String zoneId;
  final String? technicianUserId;
  final String status;
  final List<String> requiredParameters;
  final String? ownerNotes;
  final String? failureCode;
  final String? failureDescription;
  final List<PlanItem> planItems;
  final List<EstimateItem> estimateItems;
  final DeploymentContext? context;
  final List<DeploymentSurvey> surveys;
  final List<DeploymentDecision> history;

  DeploymentRequest({
    required this.requestId,
    required this.farmId,
    required this.zoneId,
    this.technicianUserId,
    required this.status,
    required this.requiredParameters,
    this.ownerNotes,
    this.failureCode,
    this.failureDescription,
    required this.planItems,
    this.estimateItems = const [],
    this.context,
    required this.surveys,
    required this.history,
  });

  factory DeploymentRequest.fromJson(Map<String, dynamic> j) =>
      DeploymentRequest(
        requestId: '${j['requestId']}',
        farmId: '${j['farmId']}',
        zoneId: '${j['zoneId']}',
        technicianUserId: j['technicianUserId']?.toString(),
        status: enumName(j['status'], deploymentStatuses),
        requiredParameters: _strings(j['requiredParameters']),
        ownerNotes: j['ownerNotes'] as String?,
        failureCode: j['failureCode'] as String?,
        failureDescription: j['failureDescription'] as String?,
        planItems: (j['planItems'] as List? ?? const [])
            .map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        estimateItems: (j['estimateItems'] as List? ?? const [])
            .map((e) => EstimateItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        context: j['context'] is Map<String, dynamic>
            ? DeploymentContext.fromJson(j['context'] as Map<String, dynamic>)
            : null,
        surveys: (j['surveys'] as List? ?? const [])
            .map((e) => DeploymentSurvey.fromJson(e as Map<String, dynamic>))
            .toList(),
        history: (j['decisionHistory'] as List? ?? const [])
            .map((e) => DeploymentDecision.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Lần khảo sát mới nhất quyết định có được xác nhận kế hoạch hay không (backend vẫn kiểm tra lại).
  bool get latestSurveyFeasible =>
      surveys.isNotEmpty && surveys.last.isFeasible;
}

class ConnectionTest {
  final bool succeeded;
  final double? rssi;
  final double? snr;
  final int? latencyMs;
  final String observedAtUtc;
  final String? errorCode;
  final String? errorMessage;
  ConnectionTest({
    required this.succeeded,
    this.rssi,
    this.snr,
    this.latencyMs,
    required this.observedAtUtc,
    this.errorCode,
    this.errorMessage,
  });
  factory ConnectionTest.fromJson(Map<String, dynamic> j) => ConnectionTest(
    succeeded: j['succeeded'] == true,
    rssi: (j['rssi'] as num?)?.toDouble(),
    snr: (j['snr'] as num?)?.toDouble(),
    latencyMs: (j['roundTripLatencyMs'] as num?)?.toInt(),
    observedAtUtc: '${j['observedAtUtc'] ?? ''}',
    errorCode: j['errorCode'] as String?,
    errorMessage: j['errorMessage'] as String?,
  );
}

class IotDevice {
  final String deviceId;
  final String gatewayId;
  final String deploymentRequestId;
  final String? zoneId;
  final String? deviceModelId;
  final String hardwareAddress;
  final String deviceType;
  final String status;
  final ConnectionTest? latestTest;
  IotDevice({
    required this.deviceId,
    required this.gatewayId,
    required this.deploymentRequestId,
    this.zoneId,
    this.deviceModelId,
    required this.hardwareAddress,
    required this.deviceType,
    required this.status,
    this.latestTest,
  });
  factory IotDevice.fromJson(Map<String, dynamic> j) => IotDevice(
    deviceId: '${j['deviceId']}',
    gatewayId: '${j['gatewayId']}',
    deploymentRequestId: '${j['deploymentRequestId']}',
    zoneId: j['zoneId']?.toString(),
    deviceModelId: j['deviceModelId']?.toString(),
    hardwareAddress: '${j['hardwareAddress']}',
    deviceType: enumName(j['deviceType'], deviceTypes),
    status: enumName(j['status'], deviceStatuses),
    latestTest: j['latestConnectionTest'] is Map<String, dynamic>
        ? ConnectionTest.fromJson(
            j['latestConnectionTest'] as Map<String, dynamic>,
          )
        : null,
  );
}

class IotGateway {
  final String gatewayId;
  final String deploymentRequestId;
  final String macAddress;
  final String gatewaySerial;
  final String status;
  IotGateway({
    required this.gatewayId,
    required this.deploymentRequestId,
    required this.macAddress,
    required this.gatewaySerial,
    required this.status,
  });
  factory IotGateway.fromJson(Map<String, dynamic> j) => IotGateway(
    gatewayId: '${j['gatewayId']}',
    deploymentRequestId: '${j['deploymentRequestId']}',
    macAddress: '${j['macAddress']}',
    gatewaySerial: '${j['gatewaySerial']}',
    status: '${j['status']}',
  );
}

class QuotationItem {
  final String? notes;
  final String code;
  final String name;
  final String category;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double vatPercent;
  final double totalAmount;
  QuotationItem({
    this.notes,
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.vatPercent,
    required this.totalAmount,
  });
  factory QuotationItem.fromJson(Map<String, dynamic> j) => QuotationItem(
    notes: j['notes'] as String?,
    code: '${j['code']}',
    name: '${j['name']}',
    category: '${j['category']}',
    unit: '${j['unit']}',
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    unitPrice: _num(j['unitPrice']),
    vatPercent: _num(j['vatPercent']),
    totalAmount: _num(j['totalAmount']),
  );
}

class Quotation {
  final String? serviceRequestId;
  final String? technicianUserId;
  final DateTime? createdAtUtc;
  final double? vatPercent;
  final String id;
  final double subtotal;
  final double vatAmount;
  final double totalAmount;
  final double deposit30;
  final double remaining70;
  final String? notes;
  final String? contractTerms;
  final String status; // SentToOwner → SignedByOwner → Completed
  final List<QuotationItem> items;

  /// Tỷ lệ cọc ĐÃ áp cho hợp đồng này, suy ra từ số tiền backend trả (cọc ÷ tổng). Hợp đồng chưa cọc theo tỷ lệ Admin hiện hành;
  /// hợp đồng đã cọc / đã nghiệm thu giữ số đã chốt nên nhãn không đổi khi Admin sửa tỷ lệ về sau.
  double get appliedDepositPercent {
    if (totalAmount <= 0 || deposit30 <= 0) {
      return BusinessParameters.active.depositPercent;
    }
    final p = deposit30 / totalAmount * 100;
    return double.parse(p.toStringAsFixed(2));
  }

  String get depositLabel =>
      '${BusinessParameters.fmt(appliedDepositPercent)}%';
  String get remainingLabel =>
      '${BusinessParameters.fmt(double.parse((100 - appliedDepositPercent).toStringAsFixed(2)))}%';

  Quotation({
    this.serviceRequestId,
    this.technicianUserId,
    this.createdAtUtc,
    this.vatPercent,
    required this.id,
    required this.subtotal,
    required this.vatAmount,
    required this.totalAmount,
    required this.deposit30,
    required this.remaining70,
    this.notes,
    this.contractTerms,
    required this.status,
    required this.items,
  });
  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
    serviceRequestId: j['serviceRequestId'] as String?,
    technicianUserId: j['technicianUserId'] as String?,
    createdAtUtc: DateTime.tryParse('${j['createdAtUtc'] ?? ''}'),
    vatPercent: (j['vatPercent'] as num?)?.toDouble(),
    id: '${j['id']}',
    subtotal: _num(j['subtotal']),
    vatAmount: _num(j['vatAmount']),
    totalAmount: _num(j['totalAmount']),
    deposit30: _num(j['deposit30Percent']),
    remaining70: _num(j['remaining70Percent']),
    notes: j['notes'] as String?,
    contractTerms: j['contractTerms'] as String?,
    status: '${j['status']}',
    items: (j['items'] as List? ?? const [])
        .map((e) => QuotationItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ServicePayment {
  final String paymentStage;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final String signerFullName;
  final String status;
  final String? paidAtUtc;
  ServicePayment({
    required this.paymentStage,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    required this.signerFullName,
    required this.status,
    this.paidAtUtc,
  });
  factory ServicePayment.fromJson(Map<String, dynamic> j) => ServicePayment(
    paymentStage: '${j['paymentStage']}',
    amount: _num(j['amount']),
    paymentMethod: '${j['paymentMethod']}',
    transactionReference: j['transactionReference'] as String?,
    signerFullName: '${j['signerFullName']}',
    status: '${j['status']}',
    paidAtUtc: j['paidAtUtc'] as String?,
  );
}
