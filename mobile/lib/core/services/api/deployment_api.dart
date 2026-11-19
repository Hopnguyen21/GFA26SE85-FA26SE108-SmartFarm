part of '../api_service.dart';

/// Triển khai IoT: yêu cầu lắp đặt, gateway/node, cấu hình thiết bị (Owner & Kỹ thuật viên).
abstract final class DeploymentApi {
  /// Danh mục phần cứng nền tảng (đơn giá thiết bị): Owner được phép đọc.
  static Future<List<Map<String, dynamic>>> getHardwareItems() async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/platform/hardware-items',
      ),
    );
    // Chấp nhận mảng trần hoặc {value:[...]}; sai cấu trúc thì báo rõ, không trả danh sách rỗng giả.
    final list = data is List ? data : (data is Map ? data['value'] : null);
    if (list is! List)
      throw Exception('Máy chủ trả về danh mục thiết bị sai cấu trúc.');
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  /// Thiết bị ĐÃ GẮN vào Zone (không gồm thiết bị đã ngừng): GET /zones/{id}/devices. Dùng để dự toán phần bổ sung.
  static Future<List<Map<String, dynamic>>> getZoneDevices(
    String zoneId,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices',
      ),
    );
    final list = data is List ? data : (data is Map ? data['value'] : null);
    if (list is! List)
      throw Exception(
        'Máy chủ trả về danh sách thiết bị của Zone sai cấu trúc.',
      );
    return [
      for (final e in list)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static Future<IotRequirements> getIotRequirements(String zoneId) async =>
      IotRequirements.fromJson(
        ApiService._decodeOrThrow(
              await ApiService._getWithAuth(
                '${ApiService.baseUrl}/api/v1/zones/$zoneId/iot-requirements',
              ),
            )
            as Map<String, dynamic>,
      );

  /// Yêu cầu triển khai của Tenant trong JWT (lọc theo Zone nếu có); thay cho việc lưu mã trên máy.
  static Future<List<DeploymentRequest>> getOwnerDeploymentRequests({
    String? zoneId,
  }) async {
    final query = zoneId == null ? '' : '?zoneId=$zoneId';
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/deployment-requests$query',
      ),
    );
    return (data as List)
        .map((e) => DeploymentRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Owner xác nhận gửi yêu cầu cho Zone đã có: trạng thái Submitted ngay. Thông số cần đo do máy chủ lấy từ vụ đang canh tác;
  /// đơn giá dự toán do máy chủ lấy từ kho (app chỉ gửi id thiết bị, vai trò, số lượng; riêng dòng thi công kèm đơn giá cố định).
  static Future<DeploymentRequest> submitDeploymentRequestWithEstimate(
    String zoneId, {
    String? notes,
    List<Map<String, dynamic>> estimateItems = const [],
  }) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/deployment-requests/submit',
            {
              if (notes != null && notes.trim().isNotEmpty)
                'ownerNotes': notes.trim(),
              if (estimateItems.isNotEmpty) 'estimateItems': estimateItems,
            },
            timeout: const Duration(seconds: 30),
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<DeploymentRequest> updateOwnerDeploymentPlan(
    String requestId,
    List<PlanItem> items,
  ) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._putWithAuth(
            '${ApiService.baseUrl}/api/v1/deployment-requests/$requestId/plan',
            {'items': items.map((i) => i.toRequestJson()).toList()},
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<DeploymentRequest> submitDeploymentRequest(
    String requestId,
  ) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/deployment-requests/$requestId/submit',
            {},
          ),
        )
        as Map<String, dynamic>,
  );

  /// GET /platform/deployment-requests/{id}/models (kỹ thuật viên): các model thiết bị có thể đưa vào kế hoạch, kèm số lượng gợi ý.
  /// Chủ trại hủy yêu cầu triển khai khi chưa bắt đầu lắp đặt và chưa ký hợp đồng/đóng cọc.
  static Future<DeploymentRequest> cancelDeploymentRequest(
    String requestId, {
    String? reason,
  }) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/deployment-requests/$requestId/cancel',
            {if (reason != null && reason.isNotEmpty) 'reason': reason},
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<List<PlanItem>> getDeploymentPlanModels(
    String requestId,
  ) async => [
    for (final m in ApiService._listOf(
      ApiService._decodeOrThrow(
        await ApiService._getWithAuth(
          '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$requestId/models',
        ),
      ),
    ))
      PlanItem.fromJson(m),
  ];

  /// Owner đọc theo `/deployment-requests/{id}`, kỹ thuật viên theo `/platform/deployment-requests/{id}`.
  static Future<DeploymentRequest> getDeploymentRequest(
    String requestId, {
    required bool technician,
  }) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            technician
                ? '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$requestId'
                : '${ApiService.baseUrl}/api/v1/deployment-requests/$requestId',
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<List<DeploymentRequest>>
  getTechnicianDeploymentRequests() async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/platform/deployment-requests',
      ),
    );
    return (data as List)
        .map((e) => DeploymentRequest.fromJson(e as Map<String, dynamic>))
        .toList();
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

  static Future<DeploymentRequest> acceptDeploymentRequest(String id) =>
      _technicianPost(id, 'accept');

  static Future<DeploymentRequest> surveyDeploymentRequest(
    String id, {
    required bool isFeasible,
    required String siteConditions,
    required String notes,
  }) => _technicianPost(id, 'survey', {
    'isFeasible': isFeasible,
    'siteConditions': siteConditions,
    'notes': notes,
  });

  static Future<DeploymentRequest> updateTechnicianDeploymentPlan(
    String id,
    List<PlanItem> items,
  ) async => DeploymentRequest.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._putWithAuth(
            '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$id/plan',
            {'items': items.map((i) => i.toRequestJson()).toList()},
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<DeploymentRequest> confirmDeploymentPlan(String id) =>
      _technicianPost(id, 'confirm');

  /// Kỹ thuật viên gửi hợp đồng = xác nhận kế hoạch: nếu khảo sát thực địa ĐÃ có kết quả khả thi thì tự xác nhận kế hoạch.
  /// App KHÔNG tự bịa khảo sát thay KTV: chưa tiếp nhận/khảo sát (hoặc khảo sát không khả thi) thì ném lỗi để báo.
  static Future<DeploymentRequest> autoConfirmPlan(String id) async {
    final d = await getDeploymentRequest(id, technician: true);
    if (d.status == 'Submitted' || d.status == 'Accepted') {
      throw Exception(
        'Cần tiếp nhận và lập báo cáo khảo sát thực địa trước khi xác nhận kế hoạch.',
      );
    }
    if (d.status == 'Surveyed') {
      if (!d.latestSurveyFeasible) {
        throw Exception(
          'Khảo sát thực địa không khả thi nên chưa xác nhận kế hoạch được.',
        );
      }
      return confirmDeploymentPlan(id);
    }
    return d;
  }

  static Future<DeploymentRequest> startDeploymentInstallation(String id) =>
      _technicianPost(id, 'installation/start');

  /// Hoàn tất lắp đặt; [notes] = ghi chú nghiệm thu của KTV (backend lưu vào lịch sử quyết định, Owner đọc lại).
  static Future<DeploymentRequest> completeDeploymentRequest(
    String id, {
    String? notes,
  }) => _technicianPost(id, 'complete', {
    if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
  });

  /// Trả về mã service request bảo trì mà backend tạo khi triển khai thất bại.
  static Future<String> failDeploymentRequest(
    String id, {
    required String failureCode,
    required String description,
    String? deviceId,
  }) async {
    final data =
        ApiService._decodeOrThrow(
              await ApiService._postWithAuth(
                '${ApiService.baseUrl}/api/v1/platform/deployment-requests/$id/fail',
                {
                  'failureCode': failureCode,
                  'description': description,
                  'deviceId': ?deviceId,
                },
              ),
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
              if (errorCode != null && errorCode.isNotEmpty)
                'errorCode': errorCode,
              if (errorMessage != null && errorMessage.isNotEmpty)
                'errorMessage': errorMessage,
            },
          ),
        )
        as Map<String, dynamic>,
  );

  /// JSON thô của gateway (có lastSeenAtUtc, telemetryIntervalSec...) cho màn tình trạng thiết bị.
  static Future<List<Map<String, dynamic>>> getFarmGatewaysRaw(
    String farmId,
  ) async => ApiService._listOf(
    ApiService._decodeUtf8OrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/gateways',
      ),
    ),
  );

  /// JSON thô của node (có lastSeenAtUtc, heartbeatIntervalSeconds, zoneId...).
  static Future<List<Map<String, dynamic>>> getFarmDevicesRaw(
    String farmId,
  ) async => ApiService._listOf(
    ApiService._decodeUtf8OrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/devices',
      ),
    ),
  );

  static Future<List<IotGateway>> getFarmGateways(String farmId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/gateways',
      ),
    );
    return (data as List)
        .map((e) => IotGateway.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<IotDevice>> getFarmDevices(String farmId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/devices',
      ),
    );
    return (data as List)
        .map((e) => IotDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Cấp phát Gateway tay (`POST /gateways`) đã bị backend tắt (410): dùng getGatewayEnrollmentByHardware + activateGatewayEnrollment.

  static Future<List<IotDevice>> provisionDevices({
    required String deploymentRequestId,
    required String gatewayId,
    required String farmId,
    required List<Map<String, dynamic>> nodes,
  }) async {
    final data =
        ApiService._decodeOrThrow(
              await ApiService._postWithAuth(
                '${ApiService.baseUrl}/api/v1/devices/provision',
                {
                  'deploymentRequestId': deploymentRequestId,
                  'gatewayId': gatewayId,
                  'farmId': farmId,
                  'nodes': nodes,
                },
              ),
            )
            as Map<String, dynamic>;
    return (data['devices'] as List? ?? const [])
        .map((e) => IotDevice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<IotDevice> assignDeviceToZone(
    String zoneId,
    String deviceId, {
    String? installationNotes,
  }) async => IotDevice.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices/$deviceId/assign',
            {
              if (installationNotes != null &&
                  installationNotes.trim().isNotEmpty)
                'installationNotes': installationNotes.trim(),
            },
          ),
        )
        as Map<String, dynamic>,
  );

  // Technician: cấu hình gateway / node, kho linh kiện
  static Future<Map<String, dynamic>> getGatewayDetail(
    String gatewayId,
  ) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/gateways/$gatewayId',
          ),
        )
        as Map,
  );

  static Future<Map<String, dynamic>> getGatewayFirmwareConfig(
    String gatewayId,
  ) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/gateways/$gatewayId/firmware-config',
          ),
        )
        as Map,
  );

  static Future<Map<String, dynamic>> simulateGatewayConnection(
    String gatewayId,
  ) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/gateways/$gatewayId/simulate-connection',
            {},
          ),
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
          await ApiService._putWithAuth(
            '${ApiService.baseUrl}/api/v1/gateways/$gatewayId/configuration',
            {
              'nodeIds': nodeIds,
              'telemetryIntervalSec': telemetryIntervalSec,
              'samplesPerInterval': samplesPerInterval,
              if (installationLocation != null &&
                  installationLocation.isNotEmpty)
                'installationLocation': installationLocation,
            },
          ),
        )
        as Map,
  );

  /// PUT /devices/{id}/sensors: mỗi phần tử cần sensorType, unit; samplingIntervalSec 10..3600.
  static Future<void> configureDeviceSensors(
    String deviceId,
    List<Map<String, dynamic>> sensors,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/devices/$deviceId/sensors',
        {'sensors': sensors},
      ),
    );
  }

  /// PUT /devices/{id}/actuators: thay toàn bộ cơ cấu; mỗi phần tử cần actuatorType, relayChannel 1..8 (không trùng),
  /// maxDurationMinutes 1..30; ratedPowerWatt và flowRateLitersPerMinute (nếu có) phải lớn hơn 0.
  static Future<void> configureDeviceActuators(
    String deviceId,
    List<Map<String, dynamic>> actuators,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/devices/$deviceId/actuators',
        {'actuators': actuators},
      ),
    );
  }

  /// GET /devices/{id}: thông tin thiết bị kèm danh sách loại cảm biến/cơ cấu đang cấu hình.
  static Future<Map<String, dynamic>> getDeviceDetail(String deviceId) async =>
      Map<String, dynamic>.from(
        ApiService._decodeOrThrow(
              await ApiService._getWithAuth(
                '${ApiService.baseUrl}/api/v1/devices/$deviceId',
              ),
            )
            as Map,
      );

  /// Kết quả kiểm tra kết nối gần nhất của thiết bị (GET /devices/{id}/ping); 404 nếu chưa từng kiểm tra.
  static Future<ConnectionTest> pingDevice(String deviceId) async =>
      ConnectionTest.fromJson(
        ApiService._decodeOrThrow(
              await ApiService._getWithAuth(
                '${ApiService.baseUrl}/api/v1/devices/$deviceId/ping',
              ),
            )
            as Map<String, dynamic>,
      );

  /// Hành động chẩn đoán backend chấp nhận (khớp danh sách của IoTDeploymentService.DiagnoseAsync).
  static const diagnosticActions = <String, String>{
    'REBOOT_NODE': 'Khởi động lại node',
    'CHANGE_CHANNEL': 'Đổi kênh tần số',
    'REBOOT_AND_CHANGE_CHANNEL': 'Khởi động lại và đổi kênh',
    'CALIBRATE_SENSOR': 'Hiệu chuẩn cảm biến',
    'FACTORY_RESET': 'Khôi phục cài đặt gốc',
  };

  /// Xếp lệnh chẩn đoán vào hàng đợi (202); kết quả thực thi do thiết bị phản hồi, app không tự coi là thành công.
  static Future<Map<String, dynamic>> diagnoseDevice(
    String deviceId, {
    required String action,
    double? newFrequencyChannel,
    int? increaseTxPowerDbm,
  }) async =>
      ApiService._decodeOrThrow(
            await ApiService._postWithAuth(
              '${ApiService.baseUrl}/api/v1/devices/$deviceId/diagnose',
              {
                'action': action,
                'newFrequencyChannel': ?newFrequencyChannel,
                'increaseTxPowerDbm': ?increaseTxPowerDbm,
              },
            ),
            ok: const {200, 201, 202},
          )
          as Map<String, dynamic>;

  /// Gỡ thiết bị khỏi Zone (bắt buộc ghi lý do); thiết bị về trạng thái chưa gán.
  static Future<void> unassignDevice(
    String zoneId,
    String deviceId, {
    required String reason,
  }) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices/$deviceId/unassign',
        {'reason': reason},
      ),
    );
  }

  /// Ngừng sử dụng thiết bị; backend chỉ cho phép khi thiết bị đã được gỡ khỏi Zone.
  static Future<void> decommissionDevice(String deviceId) async {
    ApiService._decodeOrThrow(
      await ApiService._deleteWithAuth(
        '${ApiService.baseUrl}/api/v1/devices/$deviceId',
      ),
      ok: const {200, 204},
    );
  }

  /// Kho trung tâm: danh mục linh kiện còn có thể nhận (chưa giao cho kỹ thuật viên nào).
  static Future<List<Map<String, dynamic>>> getWarehouseParts() async =>
      (await getHardwareItems())
          .where(
            (e) =>
                ((e['quantityInStock'] as num?) ?? 0) > 0 &&
                (e['assignedTechnicianId'] == null ||
                    e['assignedTechnicianId'] == '') &&
                !const {
                  'faulty',
                  'maintenance',
                  'deployed',
                  'retired',
                  'intechnicianstock',
                }.contains('${e['status']}'.toLowerCase()),
          )
          .toList();

  /// Nhận linh kiện từ kho về tên mình (kỹ thuật viên lấy từ token, không gửi từ client).
  /// Gateway và Node chỉ nhận từng chiếc (số lượng 1).
  static Future<void> assignHardwareItem(String id, {int quantity = 1}) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/platform/hardware-items/$id/assign',
        {'quantity': quantity},
      ),
    );
  }

  /// Trả linh kiện đang giữ về kho trung tâm.
  static Future<void> returnHardwareItem(String id) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/platform/hardware-items/$id/return',
        {},
      ),
    );
  }

  /// Báo cáo thiết bị / linh kiện bị lỗi từ kho KTV.
  static Future<void> reportHardwareFault(String id) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/platform/hardware-items/$id/report-fault',
        {},
      ),
    );
  }

  /// Đăng ký (enrollment) của Gateway phần cứng trong kho của KTV; null khi thiết bị chưa tự đăng ký (backend trả 204).
  /// Gateway thật tự đăng ký khi bật nguồn + có mạng; KTV chỉ KÍCH HOẠT cho yêu cầu (backend đã tắt cấp phát tay `POST /gateways`).
  static Future<Map<String, dynamic>?> getGatewayEnrollmentByHardware(
    String hardwareItemId,
  ) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/gateway-enrollment/by-hardware/$hardwareItemId',
    );
    if (resp != null && resp.statusCode == 204) return null;
    final data = ApiService._decodeOrThrow(resp);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// Kích hoạt Gateway đã đăng ký cho một yêu cầu triển khai (tạo Gateway của đợt lắp đặt). Backend từ chối khi thiết bị chưa
  /// bắt tay, yêu cầu không thuộc KTV hoặc Farm không khớp: báo đúng lỗi đó.
  static Future<Map<String, dynamic>> activateGatewayEnrollment(
    String enrollmentId, {
    required String farmId,
    required String deploymentRequestId,
    String frequencyBand = '433MHz',
  }) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/gateway-enrollment/$enrollmentId/activate',
            {
              'farmId': farmId,
              'deploymentRequestId': deploymentRequestId,
              'frequencyBand': frequencyBand,
            },
          ),
        )
        as Map,
  );

  /// MÔ PHỎNG thiết bị Gateway tự đăng ký: gọi đúng API công khai mà firmware gọi khi bật nguồn (`/gateway-enrollment/auto`),
  /// dùng MAC của Gateway có thật trong kho KTV. Chỉ để chạy thử khi chưa có phần cứng thật.
  static Future<Map<String, dynamic>> simulateGatewayAutoEnroll({
    required String macAddress,
    required String chipId,
    String? gatewaySerial,
    String bootstrapFirmwareVersion = 'sim-1.0.0',
  }) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/gateway-enrollment/auto',
            {
              'macAddress': macAddress,
              'chipId': chipId,
              'gatewaySerial': ?gatewaySerial,
              'bootstrapFirmwareVersion': bootstrapFirmwareVersion,
            },
          ),
        )
        as Map,
  );

  /// MÔ PHỎNG Gateway ở backend (chỉ môi trường bật SimulatedIot:Enabled; nơi khác trả 404): dựng Gateway mô phỏng trong kho KTV rồi
  /// tự đăng ký + kích hoạt cho yêu cầu. Dùng khi KTV chưa được Admin giao Gateway nào và cũng chưa có phần cứng thật.
  static Future<Map<String, dynamic>> simulateGatewayOnBackend({
    required String farmId,
    required String deploymentRequestId,
  }) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/gateway-enrollment/simulate',
            {'farmId': farmId, 'deploymentRequestId': deploymentRequestId},
          ),
        )
        as Map,
  );

  // ── Chuẩn bị phần cứng (màn Kho & chuẩn bị thiết bị của KTV) ──
  static Future<List<Map<String, dynamic>>> listHardwarePreparations() async =>
      ApiService._listOf(
        ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/technician/hardware-preparations',
          ),
        ),
      );

  static Future<List<Map<String, dynamic>>>
  listApprovedFirmwareReleases() async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/technician/firmware/releases',
      ),
    ),
  );

  static Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth('${ApiService.baseUrl}$path', body),
        )
        as Map,
  );

  static Future<Map<String, dynamic>> startHardwarePreparation(
    String hardwareItemId,
  ) => _postMap(
    '/api/v1/technician/hardware-preparations/$hardwareItemId/start',
    {},
  );

  static Future<Map<String, dynamic>> advanceHardwarePreparation(
    String preparationId,
    String status, {
    String? nodeId,
    int? loRaAddress,
  }) => _postMap(
    '/api/v1/technician/hardware-preparations/$preparationId/status',
    {'status': status, 'nodeId': ?nodeId, 'loRaAddress': ?loRaAddress},
  );

  static Future<Map<String, dynamic>> recordHardwareConnectivityCheck(
    String preparationId, {
    required bool passed,
    required String evidence,
  }) => _postMap(
    '/api/v1/technician/hardware-preparations/$preparationId/connectivity-check',
    {'passed': passed, 'evidence': evidence},
  );

  static Future<Map<String, dynamic>> recordFirmwareInstallation(
    String preparationId, {
    required String firmwareReleaseId,
    String uploadMethod = 'UsbManual',
    String result = 'Succeeded',
    String? notes,
  }) => _postMap(
    '/api/v1/technician/hardware-preparations/$preparationId/firmware',
    {
      'firmwareReleaseId': firmwareReleaseId,
      'uploadMethod': uploadMethod,
      'result': result,
      'notes': ?notes,
    },
  );

  static Future<List<Map<String, dynamic>>> getTechnicianSpareParts() async =>
      ApiService._listOf(
        ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/platform/technicians/me/spare-parts',
          ),
        ),
      );
}
