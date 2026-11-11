part of '../api_service.dart';

/// Triển khai IoT: yêu cầu lắp đặt, gateway/node, cấu hình thiết bị (Owner & Kỹ thuật viên).
abstract final class DeploymentApi {
  /// Danh mục phần cứng nền tảng (đơn giá thiết bị): Owner được phép đọc.
  static Future<List<Map<String, dynamic>>> getHardwareItems() async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/platform/hardware-items'),
    );
    // Chấp nhận mảng trần hoặc {value:[...]}; sai cấu trúc thì báo rõ, không trả danh sách rỗng giả.
    final list = data is List ? data : (data is Map ? data['value'] : null);
    if (list is! List) throw Exception('Máy chủ trả về danh mục thiết bị sai cấu trúc.');
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  /// Thiết bị ĐÃ GẮN vào Zone (không gồm thiết bị đã ngừng): GET /zones/{id}/devices. Dùng để dự toán phần bổ sung.
  static Future<List<Map<String, dynamic>>> getZoneDevices(String zoneId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/zones/$zoneId/devices'),
    );
    final list = data is List ? data : (data is Map ? data['value'] : null);
    if (list is! List) throw Exception('Máy chủ trả về danh sách thiết bị của Zone sai cấu trúc.');
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static Future<IotRequirements> getIotRequirements(String zoneId) async => IotRequirements.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/zones/$zoneId/iot-requirements'),
        )
        as Map<String, dynamic>,
  );

  static Future<List<DeviceRecommendation>> getDeviceRecommendations(String zoneId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/zones/$zoneId/device-recommendations', {}),
    );
    return (data as List).map((e) => DeviceRecommendation.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Yêu cầu triển khai của Tenant trong JWT (lọc theo Zone nếu có); thay cho việc lưu mã trên máy.
  static Future<List<DeploymentRequest>> getOwnerDeploymentRequests({String? zoneId}) async {
    final query = zoneId == null ? '' : '?zoneId=$zoneId';
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/deployment-requests$query'),
    );
    return (data as List).map((e) => DeploymentRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DeploymentRequest> createDeploymentRequest(
    String zoneId,
    List<PlanItem> items, {
    String? notes,
  }) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/zones/$zoneId/deployment-requests', {
            'items': items.map((i) => i.toRequestJson()).toList(),
            if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          }),
        )
        as Map<String, dynamic>,
  );

  static Future<DeploymentRequest> updateOwnerDeploymentPlan(String requestId, List<PlanItem> items) async =>
      DeploymentRequest.fromJson(
        ApiService._decodeOrThrow(
              await ApiService._putWithAuth('${ApiService.baseUrl}/api/v1/deployment-requests/$requestId/plan', {
                'items': items.map((i) => i.toRequestJson()).toList(),
              }),
            )
            as Map<String, dynamic>,
      );

  static Future<DeploymentRequest> submitDeploymentRequest(String requestId) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/deployment-requests/$requestId/submit', {}),
        )
        as Map<String, dynamic>,
  );

  /// Owner đọc theo `/deployment-requests/{id}`, kỹ thuật viên theo `/platform/deployment-requests/{id}`.
  static Future<DeploymentRequest> getDeploymentRequest(String requestId, {required bool technician}) async =>
      DeploymentRequest.fromJson(
        ApiService._decodeOrThrow(
              await ApiService._getWithAuth(
                technician
                    ? '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$requestId'
                    : '${ApiService.baseUrl}/api/v1/deployment-requests/$requestId',
              ),
            )
            as Map<String, dynamic>,
      );

  static Future<List<DeploymentRequest>> getTechnicianDeploymentRequests() async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/platform/deployment-requests'),
    );
    return (data as List).map((e) => DeploymentRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DeploymentRequest> _technicianPost(
    String requestId,
    String action, [
    Map<String, dynamic> body = const {},
  ]) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$requestId/$action',
            body,
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<DeploymentRequest> acceptDeploymentRequest(String id) => _technicianPost(id, 'accept');

  static Future<DeploymentRequest> surveyDeploymentRequest(
    String id, {
    required bool isFeasible,
    required String siteConditions,
    required String notes,
  }) => _technicianPost(id, 'survey', {'isFeasible': isFeasible, 'siteConditions': siteConditions, 'notes': notes});

  static Future<DeploymentRequest> updateTechnicianDeploymentPlan(String id, List<PlanItem> items) async =>
      DeploymentRequest.fromJson(
        ApiService._decodeOrThrow(
              await ApiService._putWithAuth('${ApiService.baseUrl}/api/v1/platform/deployment-requests/$id/plan', {
                'items': items.map((i) => i.toRequestJson()).toList(),
              }),
            )
            as Map<String, dynamic>,
      );

  static Future<DeploymentRequest> confirmDeploymentPlan(String id) => _technicianPost(id, 'confirm');

  static Future<DeploymentRequest> startDeploymentInstallation(String id) => _technicianPost(id, 'installation/start');

  static Future<DeploymentRequest> completeDeploymentRequest(String id) => _technicianPost(id, 'complete');

  /// Trả về mã service request bảo trì mà backend tạo khi triển khai thất bại.
  static Future<String> failDeploymentRequest(
    String id, {
    required String failureCode,
    required String description,
    String? deviceId,
  }) async {
    final data =
        ApiService._decodeOrThrow(
              await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/platform/deployment-requests/$id/fail', {
                'failureCode': failureCode,
                'description': description,
                'deviceId': ?deviceId,
              }),
            )
            as Map<String, dynamic>;
    return '${data['serviceRequestId']}';
  }

  /// Ghi kết quả kiểm tra kết nối do kỹ thuật viên quan sát được; app không tự suy ra thành công.
  static Future<ConnectionTest> recordConnectionTest(
    String requestId, {
    required String deviceId,
    required bool succeeded,
    double? rssi,
    double? snr,
    int? latencyMs,
    String? errorCode,
    String? errorMessage,
  }) async => ConnectionTest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$requestId/connection-tests',
            {
              'deviceId': deviceId,
              'succeeded': succeeded,
              'rssi': ?rssi,
              'snr': ?snr,
              'roundTripLatencyMs': ?latencyMs,
              'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
              if (errorCode != null && errorCode.isNotEmpty) 'errorCode': errorCode,
              if (errorMessage != null && errorMessage.isNotEmpty) 'errorMessage': errorMessage,
            },
          ),
        )
        as Map<String, dynamic>,
  );

  /// JSON thô của gateway (có lastSeenAtUtc, telemetryIntervalSec...) cho màn tình trạng thiết bị.
  static Future<List<Map<String, dynamic>>> getFarmGatewaysRaw(String farmId) async => ApiService._listOf(
    ApiService._decodeUtf8OrThrow(await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/farms/$farmId/gateways')),
  );

  /// JSON thô của node (có lastSeenAtUtc, heartbeatIntervalSeconds, zoneId...).
  static Future<List<Map<String, dynamic>>> getFarmDevicesRaw(String farmId) async => ApiService._listOf(
    ApiService._decodeUtf8OrThrow(await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/farms/$farmId/devices')),
  );

  static Future<List<IotGateway>> getFarmGateways(String farmId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/farms/$farmId/gateways'),
    );
    return (data as List).map((e) => IotGateway.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<IotDevice>> getFarmDevices(String farmId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/farms/$farmId/devices'),
    );
    return (data as List).map((e) => IotDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<IotGateway> provisionGateway({
    required String deploymentRequestId,
    required String farmId,
    required String macAddress,
    required String gatewaySerial,
    required String frequencyBand,
    required String firmwareVersion,
    required String mqttClientId,
    required String clientCertificateFingerprint,
  }) async => IotGateway.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/gateways', {
            'deploymentRequestId': deploymentRequestId,
            'farmId': farmId,
            'macAddress': macAddress,
            'gatewaySerial': gatewaySerial,
            'frequencyBand': frequencyBand,
            'firmwareVersion': firmwareVersion,
            'mqttClientId': mqttClientId,
            'clientCertificateFingerprint': clientCertificateFingerprint,
          }),
        )
        as Map<String, dynamic>,
  );

  static Future<List<IotDevice>> provisionDevices({
    required String deploymentRequestId,
    required String gatewayId,
    required String farmId,
    required List<Map<String, dynamic>> nodes,
  }) async {
    final data =
        ApiService._decodeOrThrow(
              await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/devices/provision', {
                'deploymentRequestId': deploymentRequestId,
                'gatewayId': gatewayId,
                'farmId': farmId,
                'nodes': nodes,
              }),
            )
            as Map<String, dynamic>;
    return (data['devices'] as List? ?? const []).map((e) => IotDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<IotDevice> assignDeviceToZone(String zoneId, String deviceId, {String? installationNotes}) async =>
      IotDevice.fromJson(
        ApiService._decodeOrThrow(
              await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/zones/$zoneId/devices/$deviceId/assign', {
                if (installationNotes != null && installationNotes.trim().isNotEmpty)
                  'installationNotes': installationNotes.trim(),
              }),
            )
            as Map<String, dynamic>,
      );

  // Technician: cấu hình gateway / node, kho linh kiện
  static Future<Map<String, dynamic>> getGatewayDetail(String gatewayId) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/gateways/$gatewayId')) as Map,
  );

  static Future<Map<String, dynamic>> getGatewayFirmwareConfig(String gatewayId) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/gateways/$gatewayId/firmware-config'),
        )
        as Map,
  );

  static Future<Map<String, dynamic>> simulateGatewayConnection(String gatewayId) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/gateways/$gatewayId/simulate-connection', {}),
        )
        as Map,
  );

  static Future<Map<String, dynamic>> configureGateway(
    String gatewayId, {
    required List<String> nodeIds,
    required int telemetryIntervalSec,
    required int samplesPerInterval,
    String? installationLocation,
  }) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._putWithAuth('${ApiService.baseUrl}/api/v1/gateways/$gatewayId/configuration', {
            'nodeIds': nodeIds,
            'telemetryIntervalSec': telemetryIntervalSec,
            'samplesPerInterval': samplesPerInterval,
            if (installationLocation != null && installationLocation.isNotEmpty)
              'installationLocation': installationLocation,
          }),
        )
        as Map,
  );

  /// PUT /devices/{id}/sensors: mỗi phần tử cần sensorType, unit; samplingIntervalSec 10..3600.
  static Future<void> configureDeviceSensors(String deviceId, List<Map<String, dynamic>> sensors) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth('${ApiService.baseUrl}/api/v1/devices/$deviceId/sensors', {'sensors': sensors}),
    );
  }

  static Future<List<Map<String, dynamic>>> getTechnicianSpareParts() async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/platform/technicians/me/spare-parts'),
    ),
  );
}
