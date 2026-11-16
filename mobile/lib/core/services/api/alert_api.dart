part of '../api_service.dart';

/// Quy tắc cảnh báo của Zone và cảnh báo đã phát sinh (`/api/v1/zones/{id}/alert-rules`, `/alerts`).
/// Owner tạo/sửa/xóa quy tắc; Owner và Farmer xem quy tắc, xác nhận và đóng cảnh báo (khớp backend).
abstract final class AlertApi {
  /// Quy tắc của giai đoạn hiện tại của vụ đang canh tác (backend lọc theo giai đoạn).
  static Future<List<Map<String, dynamic>>> getRules(String zoneId) async =>
      ApiService._asMapList(
        ApiService._decodeUtf8OrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/alert-rules',
          ),
        ),
      );

  /// severity: Info | Warning | Critical; parameterCode: Temperature | SoilMoisture | AirHumidity | Ph | LightIntensity | Ec.
  static Future<Map<String, dynamic>> createRule(
    String zoneId, {
    required String parameterCode,
    required double minThreshold,
    required double maxThreshold,
    required String severity,
    required int cooldownMinutes,
  }) async => Map<String, dynamic>.from(
    ApiService._decodeUtf8OrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/alert-rules',
            {
              'parameterCode': parameterCode,
              'minThreshold': minThreshold,
              'maxThreshold': maxThreshold,
              'severity': severity,
              'cooldownMinutes': cooldownMinutes,
              'isActive': true,
            },
          ),
        )
        as Map,
  );

  static Future<Map<String, dynamic>> updateRule(
    String zoneId,
    String ruleId, {
    required String parameterCode,
    required double minThreshold,
    required double maxThreshold,
    required String severity,
    required int cooldownMinutes,
    required bool isActive,
  }) async => Map<String, dynamic>.from(
    ApiService._decodeUtf8OrThrow(
          await ApiService._putWithAuth(
            '${ApiService.baseUrl}/api/v1/zones/$zoneId/alert-rules/$ruleId',
            {
              'parameterCode': parameterCode,
              'minThreshold': minThreshold,
              'maxThreshold': maxThreshold,
              'severity': severity,
              'cooldownMinutes': cooldownMinutes,
              'isActive': isActive,
            },
          ),
        )
        as Map,
  );

  /// Xóa mềm (lưu trữ) quy tắc; quy tắc do hệ thống sinh từ giai đoạn bị backend từ chối (409).
  static Future<void> archiveRule(String zoneId, String ruleId) async {
    final resp = await ApiService._deleteWithAuth(
      '${ApiService.baseUrl}/api/v1/zones/$zoneId/alert-rules/$ruleId',
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 204)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
  }

  static Future<List<Map<String, dynamic>>> getZoneAlerts(
    String zoneId,
  ) async => ApiService._asMapList(
    ApiService._decodeUtf8OrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/alerts',
      ),
    ),
  );

  /// Xác nhận đã nhận cảnh báo (Open → Acknowledged). Ném lỗi kèm lý do của backend.
  static Future<void> acknowledge(String alertId, {String? notes}) async {
    ApiService._decodeUtf8OrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/alerts/$alertId/acknowledge',
        {'notes': ?notes},
      ),
    );
  }

  /// Đóng cảnh báo: bắt buộc ghi hành động đã làm (tối đa 500 ký tự).
  static Future<void> resolve(
    String alertId, {
    required String actionTaken,
    String? notes,
  }) async {
    ApiService._decodeUtf8OrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/alerts/$alertId/resolve',
        {'actionTaken': actionTaken, 'notes': ?notes},
      ),
    );
  }
}
