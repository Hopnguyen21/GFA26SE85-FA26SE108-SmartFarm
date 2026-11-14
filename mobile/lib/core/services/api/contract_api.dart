part of '../api_service.dart';

/// Hợp đồng thuê Zone và khấu hao thiết bị.
abstract final class ContractApi {
  // ─── 17. Zone Contracts (Quản lý Hợp đồng thuê Zone) ──────────────────
  /// Lấy danh sách hợp đồng (có thể lọc theo farmId hoặc zoneId)
  static Future<List<ZoneContractModel>> getZoneContracts({
    String? farmId,
    String? zoneId,
  }) async {
    String url = '${ApiService.baseUrl}/api/v1/zone-contracts';
    if (zoneId != null) {
      url = '${ApiService.baseUrl}/api/v1/zones/$zoneId/contracts';
    } else if (farmId != null) {
      url = '${ApiService.baseUrl}/api/v1/farms/$farmId/zone-contracts';
    }
    return [
      for (final m in ApiService._listOf(
        ApiService._decodeUtf8OrThrow(await ApiService._getWithAuth(url)),
      ))
        ZoneContractModel.fromJson(m),
    ];
  }

  /// Xem chi tiết một hợp đồng (kèm thiết bị, lịch sử gia hạn, VAT/chiết khấu).
  static Future<ZoneContractModel> getZoneContractById(
    String contractId,
  ) async => ZoneContractModel.fromJson(
    ApiService._decodeUtf8OrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/zone-contracts/$contractId',
          ),
        )
        as Map<String, dynamic>,
  );

  /// Tạo hợp đồng mới cho Zone. Ném Exception với thông báo của backend khi bị từ chối.
  static Future<ZoneContractModel> createZoneContract(
    String zoneId,
    Map<String, dynamic> data,
  ) async => ZoneContractModel.fromJson(
    ApiService._decodeUtf8OrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/contracts',
            data,
          ),
        )
        as Map<String, dynamic>,
  );

  /// Gia hạn hợp đồng (durationPreset: 6_MONTHS | 1_YEAR | 3_YEARS | CUSTOM + customEndDate).
  static Future<ZoneContractModel> renewZoneContract(
    String contractId,
    Map<String, dynamic> data,
  ) async => ZoneContractModel.fromJson(
    ApiService._decodeUtf8OrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/zone-contracts/$contractId/renew',
            data,
          ),
        )
        as Map<String, dynamic>,
  );

  /// Cảnh báo hợp đồng sắp hết hạn.
  static Future<List<ExpiringContractAlertModel>> getExpiringContracts({
    String? farmId,
    String? zoneId,
    int daysThreshold = 30,
  }) async {
    var url =
        '${ApiService.baseUrl}/api/v1/zone-contracts/expiring?daysThreshold=$daysThreshold';
    if (farmId != null) url += '&farmId=$farmId';
    if (zoneId != null) url += '&zoneId=$zoneId';
    return [
      for (final m in ApiService._listOf(
        ApiService._decodeUtf8OrThrow(await ApiService._getWithAuth(url)),
      ))
        ExpiringContractAlertModel.fromJson(m),
    ];
  }

  // ─── 18. Device Depreciations (Khấu hao thiết bị) ─────────────────────
  /// Lấy danh sách khấu hao thiết bị theo Zone hoặc Farm
  static Future<List<DeviceDepreciationModel>> getDeviceDepreciations({
    String? zoneId,
    String? farmId,
  }) async {
    final String url;
    if (zoneId != null) {
      url = '${ApiService.baseUrl}/api/v1/zones/$zoneId/depreciations';
    } else if (farmId != null) {
      url = '${ApiService.baseUrl}/api/v1/farms/$farmId/depreciations';
    } else {
      return [];
    }
    return [
      for (final m in ApiService._listOf(
        ApiService._decodeUtf8OrThrow(await ApiService._getWithAuth(url)),
      ))
        DeviceDepreciationModel.fromJson(m),
    ];
  }

  /// Tạo hồ sơ khấu hao cho một thiết bị THẬT trong Zone (backend từ chối thiết bị ngoài Zone hoặc đã có hồ sơ).
  static Future<DeviceDepreciationModel> createDeviceDepreciation(
    String zoneId,
    Map<String, dynamic> data,
  ) async => DeviceDepreciationModel.fromJson(
    ApiService._decodeUtf8OrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/depreciations',
            data,
          ),
        )
        as Map<String, dynamic>,
  );
}

/// Tham số nghiệp vụ hiện hành, giữ trong bộ nhớ; màn hình gọi [refresh] khi mở để lấy giá trị Admin vừa đổi.
abstract final class BusinessParametersStore {
  static BusinessParameters current = BusinessParameters.fallback;

  static Future<BusinessParameters> refresh() async {
    try {
      current = BusinessParameters.fromJson(
        ApiService._decodeUtf8OrThrow(
              await ApiService._getWithAuth(
                '${ApiService.baseUrl}/api/v1/platform/business-parameters',
              ),
            )
            as Map<String, dynamic>,
      );
    } catch (_) {
      // Giữ giá trị gần nhất (hoặc mặc định) khi không gọi được server.
    }
    BusinessParameters.active = current;
    return current;
  }
}
