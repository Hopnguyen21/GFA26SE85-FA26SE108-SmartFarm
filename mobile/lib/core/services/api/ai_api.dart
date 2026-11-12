part of '../api_service.dart';

/// Trợ lý AI nông học theo Zone.
abstract final class AiApi {
  // ─── 12. AI Ask ────────────────────────────────────────────────────────
  /// Gửi câu hỏi đến AI Advisory, trả về AiRecommendationModel (Timeout 60s cho LLM Gemini)
  static Future<AiRecommendationModel?> askAi({
    required String zoneId,
    required String prompt,
  }) async {
    try {
      final resp = await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/ai/ask',
        {'question': prompt},
        timeout: const Duration(seconds: 60),
      );
      if (resp != null && (resp.statusCode == 200 || resp.statusCode == 201)) {
        final data = jsonDecode(resp.body);
        return AiRecommendationModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  // ─── 12.5. AI Context ─────────────────────────────────────────────────
  /// Lấy toàn bộ bối cảnh AI của một Zone (Cây trồng, hồ sơ VietGAP, giai đoạn sinh trưởng, telemetry realtime, thời tiết)
  static Future<Map<String, dynamic>?> getAiContext(String zoneId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/ai/context',
        timeout: const Duration(seconds: 30),
      );
      if (resp != null && resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─── 13. AI History ──────────────────────────────────────────────────
  /// Lấy lịch sử hội thoại và khuyến nghị AI của một Zone
  static Future<List<Map<String, dynamic>>> getAiHistory(String zoneId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/ai/history',
      );
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic> && data['recommendations'] is List) {
          return List<Map<String, dynamic>>.from(data['recommendations']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (_) {}
    return [];
  }

  // ─── 14. Apply AI Recommendation ───────────────────────────────────────
  /// Phê duyệt khuyến nghị AI → backend sẽ chạy safety check và kích hoạt lệnh
  static Future<Map<String, dynamic>> applyAiRecommendation({
    required String zoneId,
    required String recommendationId,
    String decision = 'Accepted',
  }) async {
    try {
      final resp = await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/ai/apply-recommendation',
        {'recommendationId': recommendationId, 'decision': decision},
      );
      if (resp == null) {
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      }
      if (resp.statusCode == 200 || resp.statusCode == 202) {
        final body = jsonDecode(utf8.decode(resp.bodyBytes));
        final command = body is Map<String, dynamic> ? body['command'] : null;
        final commandStatus = command is Map<String, dynamic>
            ? command['status']?.toString()
            : null;
        return {'success': true, 'commandStatus': commandStatus};
      }
      if (resp.statusCode == 409) {
        try {
          final body = jsonDecode(utf8.decode(resp.bodyBytes));
          return {
            'success': false,
            'blocked': true,
            'message':
                body['message'] ??
                body['detail'] ??
                'Không đủ điều kiện an toàn',
          };
        } catch (_) {
          return {
            'success': false,
            'blocked': true,
            'message': 'Hệ thống từ chối: kiểm tra an toàn không đạt',
          };
        }
      }
      return {'success': false, 'message': 'Lỗi máy chủ (${resp.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Lỗi mạng: $e'};
    }
  }

  // ─── 14.5. Clear AI History ───────────────────────────────────────────
  /// Xóa lịch sử tư vấn AI hiển thị của một Zone (API catalog #88)
  static Future<bool> clearAiHistory(String zoneId) async {
    try {
      final resp = await ApiService._deleteWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/ai/history',
      );
      return resp != null && (resp.statusCode == 200 || resp.statusCode == 204);
    } catch (_) {
      return false;
    }
  }
}
