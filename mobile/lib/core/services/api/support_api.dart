part of '../api_service.dart';

/// Yêu cầu hỗ trợ/bảo trì, báo giá & ký hợp đồng lắp đặt, thay nóng thiết bị.
abstract final class SupportApi {
  // ─── Báo giá & hợp đồng lắp đặt (service request) ───────────────────
  static Future<Quotation?> getQuotation(String serviceRequestId) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/service-requests/$serviceRequestId/quotation',
    );
    if (resp != null &&
        resp.statusCode == 200 &&
        resp.body.isNotEmpty &&
        resp.body != 'null') {
      return Quotation.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    if (resp != null && (resp.statusCode == 204 || resp.statusCode == 404))
      return null;
    throw Exception(ApiService._apiErrorMessage(resp));
  }

  /// Bản nháp báo giá dựng từ dự toán thiết bị Owner đã lưu kèm yêu cầu triển khai liên kết (chỉ kỹ thuật viên được giao).
  /// Trả danh sách rỗng nếu Owner chưa lưu dự toán. Kỹ thuật viên chỉnh sửa rồi gửi bằng [createQuotation].
  static Future<List<QuotationItem>> getQuotationEstimateDraft(
    String serviceRequestId,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/service-requests/$serviceRequestId/quotation/estimate-draft',
      ),
    );
    final items = data is Map ? data['items'] : null;
    if (items is! List)
      throw Exception('Máy chủ trả về bản nháp báo giá sai cấu trúc.');
    return [
      for (final e in items)
        if (e is Map) QuotationItem.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  static Future<Quotation> createQuotation(
    String serviceRequestId, {
    required List<Map<String, dynamic>> items,
    String? notes,
    String? contractTerms,
  }) async => Quotation.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/service-requests/$serviceRequestId/quotation',
            {
              'items': items,
              if (notes != null && notes.isNotEmpty) 'notes': notes,
              if (contractTerms != null && contractTerms.isNotEmpty)
                'contractTerms': contractTerms,
            },
          ),
        )
        as Map<String, dynamic>,
  );

  /// Backend chỉ ghi nhận khoản thanh toán do người ký khai báo (chưa có cổng thanh toán);
  /// tên người ký và mã giao dịch do người dùng nhập, không tự sinh.
  static Future<ServicePayment> signContractAndPayDeposit(
    String serviceRequestId, {
    required String signerFullName,
    required String paymentMethod,
    required String transactionReference,
  }) async => ServicePayment.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/service-requests/$serviceRequestId/sign-contract-deposit',
            {
              'signerFullName': signerFullName,
              'paymentMethod': paymentMethod,
              'transactionReference': transactionReference,
            },
          ),
        )
        as Map<String, dynamic>,
  );

  static Future<ServicePayment> signAcceptanceAndPayFinal(
    String serviceRequestId, {
    required String signerFullName,
    required String paymentMethod,
    required String transactionReference,
  }) async => ServicePayment.fromJson(
    ApiService._decodeOrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/service-requests/$serviceRequestId/sign-acceptance-final',
            {
              'signerFullName': signerFullName,
              'paymentMethod': paymentMethod,
              'transactionReference': transactionReference,
            },
          ),
        )
        as Map<String, dynamic>,
  );

  // ─── Service requests (Hỗ trợ kỹ thuật) ─────────────────────────────
  static Future<List<Map<String, dynamic>>> getServiceRequests() async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/service-requests',
    );
    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createServiceRequest({
    required String farmId,
    required String zoneId,
    required String failureCode,
    required String description,
    String? deploymentRequestId,
    String? deviceId,
  }) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/service-requests',
      {
        'zoneId': zoneId,
        'deviceId': ?deviceId,
        'failureCode': failureCode,
        'description': description,
        'deploymentRequestId': ?deploymentRequestId,
      },
    );
    if (resp == null || (resp.statusCode != 201 && resp.statusCode != 200)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ─── Bảo trì / sửa chữa (Kỹ thuật viên) ─────────────────────────────
  static const Set<String> _serviceActions = {
    'accept',
    'diagnosis',
    'work',
    'replacement',
    'connection-tests',
    'close',
  };

  static Future<Map<String, dynamic>> getServiceRequest(String id) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/service-requests/$id',
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// Thao tác trên yêu cầu dịch vụ: accept | diagnosis | work | replacement | connection-tests | close
  static Future<Map<String, dynamic>> serviceRequestAction(
    String id,
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (!_serviceActions.contains(action))
      throw ArgumentError('Thao tác không hợp lệ: $action');
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/service-requests/$id/$action',
      body,
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listZoneDevices(
    String zoneId,
  ) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices',
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    return (jsonDecode(utf8.decode(resp.bodyBytes)) as List)
        .cast<Map<String, dynamic>>();
  }

  /// Thay nóng thiết bị: POST /zones/{zoneId}/devices/{oldDeviceId}/hot-swap
  static Future<Map<String, dynamic>> hotSwapDevice({
    required String zoneId,
    required String oldDeviceId,
    required String serviceRequestId,
    required String newDeviceId,
    String? notes,
  }) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices/$oldDeviceId/hot-swap',
      {
        'serviceRequestId': serviceRequestId,
        'newDeviceId': newDeviceId,
        'notes': ?notes,
      },
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// Trạng thái MQTT thật của gateway: { gatewayId, mqttConnected }
  static Future<Map<String, dynamic>> getGatewayMqttStatus(
    String gatewayId,
  ) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/gateways/$gatewayId/mqtt-status',
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }
}
