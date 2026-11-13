part of '../api_service.dart';

/// Cây trồng, hồ sơ sinh trưởng, giai đoạn, mùa vụ và vụ trồng.
abstract final class CropApi {
  /// GET /planting-seasons?farmId=&zoneId=: các vụ trồng của Zone/Farm. Mobile không dùng mùa vụ chung (FarmingSeason).
  static Future<List<Map<String, dynamic>>> getPlantingSeasons({
    String? farmId,
    String? zoneId,
  }) async {
    final q = <String, String>{'farmId': ?farmId, 'zoneId': ?zoneId};
    final query = q.isEmpty ? '' : '?${Uri(queryParameters: q).query}';
    return ApiService._listOf(
      ApiService._decodeOrThrow(
        await ApiService._getWithAuth(
          '${ApiService.baseUrl}/api/v1/planting-seasons$query',
        ),
      ),
    );
  }

  /// PUT /zones/{z}/planting-seasons/{s}/yield (Owner, Farmer): ghi sản lượng thực tế.
  static Future<Map<String, dynamic>> recordSeasonYield(
    String zoneId,
    String seasonId, {
    required double actualYieldKg,
    DateTime? actualEndDate,
    String? notes,
    bool markCompleted = false,
  }) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/planting-seasons/$seasonId/yield',
        {
          'actualYieldKg': actualYieldKg,
          if (actualEndDate != null)
            'actualEndDate': ApiService._isoDate(actualEndDate),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          'markCompleted': markCompleted,
        },
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// GET /varieties?cropId=: giống cây.
  static Future<List<Map<String, dynamic>>> getVarieties({
    String? cropId,
  }) async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/varieties${cropId == null ? '' : '?cropId=$cropId'}',
      ),
    ),
  );

  /// GET /crops/{id}/growth-profiles: hồ sơ sinh trưởng của một cây.
  static Future<List<Map<String, dynamic>>> getCropGrowthProfiles(
    String cropId,
  ) async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/crops/$cropId/growth-profiles',
      ),
    ),
  );

  /// GET /growth-profiles/{id}/stages: các giai đoạn sinh trưởng và yêu cầu môi trường.
  static Future<List<Map<String, dynamic>>> getGrowthStages(
    String profileId,
  ) async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/growth-profiles/$profileId/stages',
      ),
    ),
  );

  /// GET /zones/{id}/report/season-summary/excel: tổng kết vụ dạng Excel.
  static Future<Uint8List> downloadSeasonSummaryExcel(String zoneId) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/report/season-summary/excel',
      timeout: const Duration(seconds: 60),
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    return resp.bodyBytes;
  }

  /// PUT /growth-stages/{id} (Owner: chỉ bản sao của trang trại; Admin: hồ sơ hệ thống).
  static Future<void> updateStageDuration(
    String stageId,
    int durationDays,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/growth-stages/$stageId',
        {'durationDays': durationDays},
      ),
    );
  }

  /// PUT /growth-stages/{id}/requirements. Nếu là hồ sơ hệ thống, backend tạo bản sao cho trang trại
  /// và trả về effectiveProfileId/effectiveStageId mới (clonedFromSystem = true).
  static Future<Map<String, dynamic>> updateStageRequirements(
    String stageId,
    List<Map<String, dynamic>> requirements,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/growth-stages/$stageId/requirements',
        {'requirements': requirements},
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  static Future<List<Map<String, dynamic>>> getCropsForProfiles() async {
    final response = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/crops',
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? decoded['value'] : null);
    if (rawList is! List)
      throw const FormatException(
        'Danh sách cây trồng/hồ sơ từ máy chủ không hợp lệ.',
      );
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getGrowthProfiles() async {
    final response = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/growth-profiles',
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? decoded['value'] : null);
    if (rawList is! List)
      throw const FormatException(
        'Danh sách cây trồng/hồ sơ từ máy chủ không hợp lệ.',
      );
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// POST /api/v1/zones/{zoneId}/planting-seasons (Owner). Tạo vụ là cách duy nhất gán cây cho Zone.
  static Future<Map<String, dynamic>> createPlantingSeason(
    String zoneId,
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/planting-seasons',
      payload,
    );
    if (response == null ||
        (response.statusCode != 201 && response.statusCode != 200)) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// PUT /growth-profiles/{id} (Owner: chỉ bản sao của trang trại; profile hệ thống bị backend từ chối): đổi tên/mô tả.
  static Future<Map<String, dynamic>> updateGrowthProfile(
    String profileId, {
    required String name,
    String? description,
    bool isDefault = false,
  }) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/growth-profiles/$profileId',
        {'name': name, 'description': ?description, 'isDefault': isDefault},
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// GET /growth-profiles/{id}/irrigation-schedule: lịch tưới theo giai đoạn của profile (Source: Profile | Crop | None).
  static Future<Map<String, dynamic>> getProfileIrrigation(
    String profileId,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/growth-profiles/$profileId/irrigation-schedule',
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// PUT /growth-profiles/{id}/irrigation-schedule (Owner, chỉ bản sao của trang trại): thay các ca tưới của những giai đoạn gửi lên.
  /// stages: [{stageId, sessions: [{title, startTime HH:mm, durationSeconds, enabled, method?, waterPerPlantMl?}]}]
  static Future<Map<String, dynamic>> updateProfileIrrigation(
    String profileId,
    List<Map<String, dynamic>> stages,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/growth-profiles/$profileId/irrigation-schedule',
        {'stages': stages},
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ─── Lịch tưới tùy chỉnh THEO NGÀY của vụ trồng (Zone + mùa vụ) ───
  static String _seasonIrrigationUrl(String zoneId, String seasonId) =>
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/planting-seasons/$seasonId/irrigation-calendar';

  /// GET: toàn bộ ngày của vụ (kèm nguồn: Override/Profile/Crop/None), trạng thái Current/Stale/NoOverrides.
  static Future<Map<String, dynamic>> getSeasonIrrigation(
    String zoneId,
    String seasonId,
  ) async {
    final data = ApiService._decodeUtf8OrThrow(
      await ApiService._getWithAuth(_seasonIrrigationUrl(zoneId, seasonId)),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// PUT (Owner): ghi đè các ngày [days] = [{dayNumber, sessions:[...]}]; trả lịch đã lưu để hiển thị lại.
  static Future<Map<String, dynamic>> updateSeasonIrrigation(
    String zoneId,
    String seasonId,
    List<Map<String, dynamic>> days,
  ) async {
    final data = ApiService._decodeUtf8OrThrow(
      await ApiService._putWithAuth(_seasonIrrigationUrl(zoneId, seasonId), {
        'days': days,
      }),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// DELETE (Owner): khôi phục một ngày ([dayNumber]) hoặc cả mùa vụ ([dayNumber] == null) về lịch mẫu của hồ sơ.
  static Future<Map<String, dynamic>> resetSeasonIrrigation(
    String zoneId,
    String seasonId, {
    int? dayNumber,
  }) async {
    final base = _seasonIrrigationUrl(zoneId, seasonId);
    final data = ApiService._decodeUtf8OrThrow(
      await ApiService._deleteWithAuth(
        dayNumber == null ? base : '$base/days/$dayNumber',
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> createGrowthProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/growth-profiles',
      payload,
    );
    if (response == null ||
        (response.statusCode != 201 && response.statusCode != 200)) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
