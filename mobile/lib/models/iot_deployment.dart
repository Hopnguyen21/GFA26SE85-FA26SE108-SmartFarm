// DTO của luồng triển khai IoT (IOT-V1) và báo giá/hợp đồng lắp đặt (service request).
// Phản chiếu SmartFarm.Application.Features.IoTDeployment / Platform; mọi trạng thái lấy từ backend.

/// Backend serialize enum dạng chuỗi (JsonStringEnumConverter); vẫn chấp nhận số để không vỡ khi cấu hình đổi.
String enumName(dynamic value, List<String> names) {
  if (value is int && value >= 0 && value < names.length) return names[value];
  return value?.toString() ?? '';
}

const deploymentStatuses = [
  'Draft', 'Submitted', 'Accepted', 'Surveyed', 'PlanConfirmed', 'Installing', 'Completed', 'MaintenanceRequired',
];
const deviceTypes = ['SensorNode', 'ActuatorNode'];
const deviceStatuses = [
  'Unassigned', 'Assigned', 'SensorsConfigured', 'ActuatorsConfigured', 'Online', 'Offline', 'MaintenanceRequired', 'Decommissioned',
];

const deploymentStatusLabels = <String, String>{
  'Draft': 'Bản nháp',
  'Submitted': 'Đã gửi, chờ kỹ thuật viên',
  'Accepted': 'KTV đã tiếp nhận',
  'Surveyed': 'Đã khảo sát',
  'PlanConfirmed': 'Đã xác nhận kế hoạch',
  'Installing': 'Đang lắp đặt',
  'Completed': 'Hoàn tất',
  'MaintenanceRequired': 'Thất bại, chuyển bảo trì',
};

double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
List<String> _strings(dynamic v) => (v as List? ?? const []).map((e) => e.toString()).toList();

class IotRequirements {
  final String zoneId;
  final double zoneAreaM2;
  final List<String> parameters;
  IotRequirements({required this.zoneId, required this.zoneAreaM2, required this.parameters});
  factory IotRequirements.fromJson(Map<String, dynamic> j) => IotRequirements(
    zoneId: '${j['zoneId']}',
    zoneAreaM2: _num(j['zoneAreaM2']),
    parameters: _strings(j['parameters']),
  );
}

class DeviceRecommendation {
  final String deviceModelId;
  final String modelName;
  final String deviceType;
  final double coverageAreaM2;
  final int quantity;
  final List<String> coveredParameters;
  DeviceRecommendation({
    required this.deviceModelId,
    required this.modelName,
    required this.deviceType,
    required this.coverageAreaM2,
    required this.quantity,
    required this.coveredParameters,
  });
  factory DeviceRecommendation.fromJson(Map<String, dynamic> j) => DeviceRecommendation(
    deviceModelId: '${j['deviceModelId']}',
    modelName: '${j['modelName']}',
    deviceType: enumName(j['deviceType'], deviceTypes),
    coverageAreaM2: _num(j['coverageAreaM2']),
    quantity: (j['quantity'] as num?)?.toInt() ?? 1,
    coveredParameters: _strings(j['coveredParameters']),
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
    if (installationNotes != null && installationNotes!.trim().isNotEmpty) 'installationNotes': installationNotes,
  };
}

class DeploymentSurvey {
  final bool isFeasible;
  final String siteConditions;
  final String notes;
  final String surveyedAtUtc;
  DeploymentSurvey({required this.isFeasible, required this.siteConditions, required this.notes, required this.surveyedAtUtc});
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
  DeploymentDecision({required this.decisionType, required this.fromStatus, required this.toStatus, this.notes, required this.decidedAtUtc});
  factory DeploymentDecision.fromJson(Map<String, dynamic> j) => DeploymentDecision(
    decisionType: '${j['decisionType'] ?? ''}',
    fromStatus: enumName(j['fromStatus'], deploymentStatuses),
    toStatus: enumName(j['toStatus'], deploymentStatuses),
    notes: j['notes'] as String?,
    decidedAtUtc: '${j['decidedAtUtc'] ?? ''}',
  );
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
    required this.surveys,
    required this.history,
  });

  factory DeploymentRequest.fromJson(Map<String, dynamic> j) => DeploymentRequest(
    requestId: '${j['requestId']}',
    farmId: '${j['farmId']}',
    zoneId: '${j['zoneId']}',
    technicianUserId: j['technicianUserId']?.toString(),
    status: enumName(j['status'], deploymentStatuses),
    requiredParameters: _strings(j['requiredParameters']),
    ownerNotes: j['ownerNotes'] as String?,
    failureCode: j['failureCode'] as String?,
    failureDescription: j['failureDescription'] as String?,
    planItems: (j['planItems'] as List? ?? const []).map((e) => PlanItem.fromJson(e as Map<String, dynamic>)).toList(),
    surveys: (j['surveys'] as List? ?? const []).map((e) => DeploymentSurvey.fromJson(e as Map<String, dynamic>)).toList(),
    history: (j['decisionHistory'] as List? ?? const []).map((e) => DeploymentDecision.fromJson(e as Map<String, dynamic>)).toList(),
  );

  /// Lần khảo sát mới nhất quyết định có được xác nhận kế hoạch hay không (backend vẫn kiểm tra lại).
  bool get latestSurveyFeasible => surveys.isNotEmpty && surveys.last.isFeasible;
}

class ConnectionTest {
  final bool succeeded;
  final double? rssi;
  final double? snr;
  final int? latencyMs;
  final String observedAtUtc;
  final String? errorCode;
  final String? errorMessage;
  ConnectionTest({required this.succeeded, this.rssi, this.snr, this.latencyMs, required this.observedAtUtc, this.errorCode, this.errorMessage});
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
        ? ConnectionTest.fromJson(j['latestConnectionTest'] as Map<String, dynamic>)
        : null,
  );
}

class IotGateway {
  final String gatewayId;
  final String deploymentRequestId;
  final String macAddress;
  final String gatewaySerial;
  final String status;
  IotGateway({required this.gatewayId, required this.deploymentRequestId, required this.macAddress, required this.gatewaySerial, required this.status});
  factory IotGateway.fromJson(Map<String, dynamic> j) => IotGateway(
    gatewayId: '${j['gatewayId']}',
    deploymentRequestId: '${j['deploymentRequestId']}',
    macAddress: '${j['macAddress']}',
    gatewaySerial: '${j['gatewaySerial']}',
    status: '${j['status']}',
  );
}

class QuotationItem {
  final String code;
  final String name;
  final String category;
  final String unit;
  final int quantity;
  final double unitPrice;
  final double vatPercent;
  final double totalAmount;
  QuotationItem({
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
  Quotation({
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
    id: '${j['id']}',
    subtotal: _num(j['subtotal']),
    vatAmount: _num(j['vatAmount']),
    totalAmount: _num(j['totalAmount']),
    deposit30: _num(j['deposit30Percent']),
    remaining70: _num(j['remaining70Percent']),
    notes: j['notes'] as String?,
    contractTerms: j['contractTerms'] as String?,
    status: '${j['status']}',
    items: (j['items'] as List? ?? const []).map((e) => QuotationItem.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class ServicePayment {
  final String paymentStage;
  final double amount;
  final String paymentMethod;
  final String? transactionReference;
  final String signerFullName;
  final String status;
  ServicePayment({
    required this.paymentStage,
    required this.amount,
    required this.paymentMethod,
    this.transactionReference,
    required this.signerFullName,
    required this.status,
  });
  factory ServicePayment.fromJson(Map<String, dynamic> j) => ServicePayment(
    paymentStage: '${j['paymentStage']}',
    amount: _num(j['amount']),
    paymentMethod: '${j['paymentMethod']}',
    transactionReference: j['transactionReference'] as String?,
    signerFullName: '${j['signerFullName']}',
    status: '${j['status']}',
  );
}
