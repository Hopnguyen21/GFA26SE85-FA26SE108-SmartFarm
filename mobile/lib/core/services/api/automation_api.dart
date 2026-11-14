part of '../api_service.dart';

/// Điều khiển thiết bị chấp hành, dừng khẩn cấp, luật tự động, lịch tưới.
abstract final class AutomationApi {
  // ─── AutoRule & ngưỡng môi trường ────────
  static Future<List<Map<String, dynamic>>> getAutoRules(String zoneId) async =>
      ApiService._asMapList(
        ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/rules',
          ),
        ),
      );

  static Future<void> createAutoRule(
    String zoneId,
    Map<String, dynamic> body,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/rules',
        body,
      ),
    );
  }

  static Future<void> updateAutoRule(
    String zoneId,
    String ruleId,
    Map<String, dynamic> body,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/rules/$ruleId',
        body,
      ),
    );
  }

  static Future<void> updateEnvironmentalThresholds(
    String zoneId, {
    required double minSoil,
    required double maxSoil,
    required double maxTemp,
  }) async {
    final configs = ApiService._asMapList(
      ApiService._decodeOrThrow(
        await ApiService._getWithAuth(
          '${ApiService.baseUrl}/api/v1/control/environmental-configs?zoneId=$zoneId',
        ),
      ),
    );
    final current = configs.isNotEmpty
        ? configs.first
        : const <String, dynamic>{};
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/control/environmental-configs',
        {
          'zoneId': zoneId,
          'targetSoilMoisture': (minSoil + maxSoil) / 2,
          'minSoilMoisture': minSoil,
          'maxSoilMoisture': maxSoil,
          'maxTemperature': maxTemp,
          'targetHumidity': current['targetHumidity'] ?? 0,
          'targetLux': current['targetLux'] ?? 0,
          'powerWatts': current['powerWatts'],
        },
      ),
    );
  }

  // ─── 10. Actuator Command ─────────────────────────────────────────────
  /// POST /zones/{z}/actuators/{a}/command. Ném Exception kèm lý do của backend khi bị từ chối
  /// (không có quyền, thiết bị offline, vi phạm khóa an toàn...).
  static Future<void> sendActuatorCommand({
    required String zoneId,
    required String actuatorId,
    required String action, // TurnOn, TurnOff
    int durationSeconds = 600,
  }) async {
    // Backend validates [Range(1, 1800)] DurationSeconds for both TurnOn and TurnOff
    final safeDuration = durationSeconds <= 0
        ? 1
        : durationSeconds.clamp(1, 1800);
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/actuators/$actuatorId/command',
      {
        'action': action,
        'durationSeconds': safeDuration,
        'overrideActiveSchedules': true,
        'idempotencyKey': 'mob_${DateTime.now().microsecondsSinceEpoch}',
        'notes': 'Điều khiển từ SmartFarm Mobile App',
      },
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 202)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
  }

  // ─── 10b. Emergency Stop (BR-CANCEL-01) ───────────────────────────────
  /// POST /api/v1/control/emergency-stop (FarmOwner, Farmer).
  /// zoneId = null → dừng mọi rơ-le trong tenant; Farmer chỉ dừng được Zone có quyền điều khiển.
  /// Ném Exception kèm thông báo lỗi của backend khi thất bại.
  static Future<EmergencyStopResult> emergencyStop({String? zoneId}) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/control/emergency-stop',
        {'zoneId': zoneId, 'notes': 'Dừng khẩn cấp từ SmartFarm Mobile App'},
      ),
    );
    return EmergencyStopResult.fromJson(
      data is Map<String, dynamic> ? data : const <String, dynamic>{},
    );
  }

  /// GET /zones/{id}/actuators/history: nhật ký lệnh điều khiển (mặc định 7 ngày gần nhất).
  static Future<List<Map<String, dynamic>>> getActuatorHistory(
    String zoneId, {
    DateTime? from,
    DateTime? to,
    int limit = 50,
  }) async {
    final now = DateTime.now().toUtc();
    final f = (from ?? now.subtract(const Duration(days: 7)))
        .toUtc()
        .toIso8601String();
    final t = (to ?? now).toUtc().toIso8601String();
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/actuators/history'
        '?fromUtc=${Uri.encodeQueryComponent(f)}&toUtc=${Uri.encodeQueryComponent(t)}&limit=$limit',
      ),
    );
    if (data is Map && data['commands'] is List)
      return ApiService._asMapList(data['commands']);
    return ApiService._listOf(data);
  }

  /// POST /zones/{id}/schedules/sync-from-crop: sinh lịch tưới từ hồ sơ sinh trưởng của cây.
  static Future<List<Map<String, dynamic>>> syncScheduleFromCrop(
    String zoneId, {
    required String cropId,
    required String actuatorId,
  }) async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules/sync-from-crop',
        {'cropId': cropId, 'actuatorId': actuatorId},
      ),
    ),
  );

  /// POST /zones/{id}/schedules/sync-from-profile (Owner): sinh ControlSchedule từ lịch của HỒ SƠ đang gắn trên Zone
  /// (không nhận cây tùy ý). Trả {profileId, profileName, stageId, stageName, source, actuatorId, schedules[]}.
  static Future<Map<String, dynamic>> syncScheduleFromProfile(
    String zoneId, {
    required String actuatorId,
    String? stageId,
  }) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules/sync-from-profile',
        {'actuatorId': actuatorId, 'growthStageId': ?stageId},
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ─── 14. Schedules ─────────────────────────────────────────────────────
  /// Lấy danh sách lịch tưới của một Zone (GET /zones/{zoneId}/schedules).
  /// Backend không có API lịch theo Farm: muốn lịch cả Farm, gọi lần lượt từng Zone (xem FarmProvider.fetchSchedules).
  static Future<List<ScheduleModel>> getSchedules({
    required String zoneId,
  }) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules',
      );
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((item) => ScheduleModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// GET /zones/{id}/schedules, NÉM lỗi (mạng/403/5xx) thay vì trả danh sách rỗng như [getSchedules].
  static Future<List<ScheduleModel>> fetchZoneSchedules(String zoneId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules',
      ),
    );
    return ApiService._asMapList(
      data,
    ).map((m) => ScheduleModel.fromJson(m)).toList();
  }

  /// PUT /zones/{zoneId}/schedules/{id} (Owner). Gửi đủ các trường backend yêu cầu; ném lỗi thật của backend.
  static Future<Map<String, dynamic>> updateSchedule(
    String zoneId,
    String scheduleId, {
    required String name,
    required String cronExpression,
    required int durationSeconds,
    required bool enableRainDelay,
    required double rainThresholdPercent,
    required bool isActive,
  }) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules/$scheduleId',
        {
          'name': name,
          'cronExpression': cronExpression,
          'durationSeconds': durationSeconds,
          'enableRainDelay': enableRainDelay,
          'rainThresholdPercent': rainThresholdPercent,
          'isActive': isActive,
        },
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ─── 15. Toggle Schedule ───────────────────────────────────────────────
  static Future<bool> toggleSchedule(
    String scheduleId,
    bool enable, {
    String? zoneId,
    String? name,
    String? cronExpression,
    int? durationSeconds,
    bool enableRainDelay = true,
    double? rainThresholdPercent,
  }) async {
    try {
      if (zoneId != null && zoneId.isNotEmpty) {
        final payload = {
          'name': (name != null && name.isNotEmpty)
              ? name
              : 'Lịch tưới định kỳ',
          'cronExpression':
              (cronExpression != null && cronExpression.isNotEmpty)
              ? cronExpression
              : '0 6 * * *',
          'durationSeconds': (durationSeconds != null && durationSeconds > 0)
              ? durationSeconds
              : 900,
          'enableRainDelay': enableRainDelay,
          'rainThresholdPercent':
              rainThresholdPercent ??
              BusinessParametersStore.current.rainGuardThresholdPercent,
          'isActive': enable,
        };
        final resp = await ApiService._putWithAuth(
          '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules/$scheduleId',
          payload,
        );
        return resp != null &&
            (resp.statusCode == 200 || resp.statusCode == 204);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Tạo lịch tưới thật: POST /zones/{zoneId}/schedules (cron 5 trường, chạy hằng ngày lúc HH:mm).
  static Future<Map<String, dynamic>> createSchedule({
    required String zoneId,
    required String actuatorId,
    required String name,
    required String startTime, // HH:mm
    required int durationMinutes,
  }) async {
    final parts = startTime.split(':');
    final h = int.tryParse(parts.first);
    final mi = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (parts.length != 2 ||
        h == null ||
        mi == null ||
        h < 0 ||
        h > 23 ||
        mi < 0 ||
        mi > 59) {
      throw Exception('Giờ bắt đầu phải có dạng HH:mm (vd 06:30).');
    }
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/schedules',
      {
        'name': name,
        'actuatorId': actuatorId,
        'cronExpression': '$mi $h * * *',
        'durationSeconds': (durationMinutes * 60).clamp(1, 1800),
        'enableRainDelay': true,
        'rainThresholdPercent':
            BusinessParametersStore.current.rainGuardThresholdPercent,
        'isActive': true,
      },
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }
}
