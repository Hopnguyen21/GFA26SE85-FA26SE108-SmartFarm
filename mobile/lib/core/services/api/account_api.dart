part of '../api_service.dart';

/// Hồ sơ cá nhân, mật khẩu, lời mời vào trang trại và quyền Zone của nhân công.
abstract final class AccountApi {
  static Future<List<Map<String, dynamic>>> getMyInvitations() async =>
      ApiService._asMapList(
        ApiService._decodeOrThrow(
          await ApiService._getWithAuth(
            '${ApiService.baseUrl}/api/v1/farm-invitations/mine',
          ),
        ),
      );

  static Future<void> respondInvitation(String id, bool accept) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farm-invitations/$id/${accept ? 'accept' : 'decline'}',
        {},
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> getFarmInvitations(
    String farmId,
  ) async => ApiService._asMapList(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/invitations',
      ),
    ),
  );

  static Future<void> inviteFarmer(String farmId, String email) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/invitations',
        {'email': email},
      ),
    );
  }

  /// action: resend hoặc cancel.
  static Future<void> invitationAction(String id, String action) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farm-invitations/$id/$action',
        {},
      ),
    );
  }

  static Future<void> updateFarmerZoneAccess(
    String farmerId,
    List<Map<String, dynamic>> access,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/users/$farmerId/zone-access',
        {'access': access},
      ),
    );
  }

  /// GET /tenants/me: tổ chức (tenant) của tài khoản. Trả null khi tài khoản không thuộc tenant
  /// (vd. kỹ thuật viên nền tảng) hoặc backend từ chối — khi đó UI ẩn thông tin tổ chức, không bịa tên.
  static Future<Map<String, dynamic>?> getMyTenant() async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/tenants/me',
      );
      if (resp == null || resp.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getMe() async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/users/me',
      );
      if (resp == null || resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Cập nhật họ tên và số điện thoại của tài khoản đang đăng nhập (PUT /users/me).
  static Future<Map<String, dynamic>?> updateProfile(
    String fullName,
    String? phone,
  ) async {
    final resp = await ApiService._putWithAuth(
      '${ApiService.baseUrl}/api/v1/users/me',
      {'fullName': fullName, 'phone': phone},
    );
    if (resp == null || resp.statusCode != 200) return null;
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ─── Mật khẩu tài khoản ─────────────────────────────────────────────
  // Backend hiện CHƯA có các endpoint này (404/405/501 → UnsupportedApiException), app không giả lập thành công.
  static Never _throwPasswordError(http.Response? resp) {
    final code = resp?.statusCode;
    if (code == 404 || code == 405 || code == 501) {
      throw UnsupportedApiException('Máy chủ chưa hỗ trợ chức năng này.');
    }
    throw Exception(ApiService._apiErrorMessage(resp));
  }

  static Future<void> forgotPassword(String email) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/auth/forgot-password');
    ApiService._assertSecureRequest(uri);
    final resp = await ApiService._client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 &&
        resp.statusCode != 202 &&
        resp.statusCode != 204)
      _throwPasswordError(resp);
  }

  static Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/api/v1/auth/reset-password');
    ApiService._assertSecureRequest(uri);
    final resp = await ApiService._client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'token': token,
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 204)
      _throwPasswordError(resp);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final resp = await ApiService._putWithAuth(
      '${ApiService.baseUrl}/api/v1/users/me/password',
      {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 204))
      _throwPasswordError(resp);
  }
}
