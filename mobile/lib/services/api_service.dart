import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/agriculture_document.dart';
import '../models/iot_deployment.dart';

class ApiService {
  // Dùng chung một client để tái sử dụng kết nối (keep-alive) thay vì mở kết nối mới ở mỗi lệnh gọi.
  static final http.Client _client = http.Client();

  // Base URL – Android emulator dùng 10.0.2.2 thay cho localhost
  static String baseUrl = (kIsWeb || (!kIsWeb && !Platform.isAndroid))
      ? 'http://localhost:5144'
      : 'http://10.0.2.2:5144';

  // Token đăng nhập lưu trong kho an toàn của hệ điều hành (Keystore/Keychain), không để dạng chữ thường trong SharedPreferences.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static String? _accessToken;

  static String? _refreshToken;

  static String? _userEmail;

  static String? _userRole;

  static Completer<bool>? _refreshCompleter;

  static void setBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (!kIsWeb && Platform.isAndroid) {
      baseUrl = cleaned.replaceAll('localhost', '10.0.2.2');
    } else {
      baseUrl = cleaned;
    }
  }

  static bool get isAuthenticated => _accessToken != null;

  static String? get userRole => _userRole;

  /// Nạp token đã lưu (kho an toàn) khi ứng dụng khởi động
  static Future<bool> loadSavedTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = await _secure.read(key: 'access_token');
      _refreshToken = await _secure.read(key: 'refresh_token');
      // Bản cũ lưu token trong SharedPreferences: chuyển sang kho an toàn một lần rồi xóa bản chữ thường.
      if (_accessToken == null && prefs.getString('access_token') != null) {
        _accessToken = prefs.getString('access_token');
        _refreshToken = prefs.getString('refresh_token');
        if (_accessToken != null) await _secure.write(key: 'access_token', value: _accessToken);
        if (_refreshToken != null) await _secure.write(key: 'refresh_token', value: _refreshToken);
      }
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      _userEmail = prefs.getString('user_email');
      _userRole = prefs.getString('user_role');
      final savedUrl = prefs.getString('base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        baseUrl = savedUrl;
      }
      return _accessToken != null;
    } catch (_) {
      return false;
    }
  }

  /// Lưu token vào kho an toàn và thông tin phiên vào SharedPreferences
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? email,
    String? role,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userEmail = email;
    _userRole = role;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _secure.write(key: 'access_token', value: accessToken);
      await _secure.write(key: 'refresh_token', value: refreshToken);
      if (email != null) await prefs.setString('user_email', email);
      if (role != null) await prefs.setString('user_role', role);
      await prefs.setString('base_url', baseUrl);
    } catch (_) {}
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ─── Helper: auto refresh on 401 ────────────────────────────────────
  static Future<http.Response?> _getWithAuth(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var resp = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _postWithAuth(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var resp = await _client
        .post(Uri.parse(url), headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .post(Uri.parse(url), headers: _headers, body: jsonEncode(body))
            .timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _deleteWithAuth(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var resp = await _client
        .delete(Uri.parse(url), headers: _headers)
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .delete(Uri.parse(url), headers: _headers)
            .timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _putWithAuth(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var resp = await _client
        .put(Uri.parse(url), headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .put(Uri.parse(url), headers: _headers, body: jsonEncode(body))
            .timeout(timeout);
      }
    }
    return resp;
  }

  // ─── 1. Auth: Đăng nhập ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> login(
    String email,
    String password,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['accessToken'] as String?;
        final rToken = data['refreshToken'] as String?;
        final role = (data['user'] is Map ? data['user']['role'] : data['role'])
            ?.toString();
        if (token != null && rToken != null) {
          await saveTokens(
            accessToken: token,
            refreshToken: rToken,
            email: email,
            role: role,
          );
        }
        return data;
      }
      return {'error': response.statusCode, 'body': response.body};
    } catch (e) {
      return {'error': 'network', 'message': e.toString()};
    }
  }

  // ─── Auth: Đăng ký tài khoản ─────────────────────────────────────────
  static Future<Map<String, dynamic>?> register({
    required String email,
    required String fullName,
    required String password,
    String? phone,
    String role = 'Farmer',
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'fullName': fullName,
              'phone': phone,
              'password': password,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'error': response.statusCode, 'body': response.body};
    } catch (e) {
      return {'error': 'network', 'message': e.toString()};
    }
  }

  // ─── Refresh Token (Concurrency Guarded) ───────────────────────────
  static Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['accessToken'];
        _refreshToken = data['refreshToken'] ?? _refreshToken;
        if (_accessToken != null && _refreshToken != null) {
          await saveTokens(
            accessToken: _accessToken!,
            refreshToken: _refreshToken!,
            email: _userEmail,
            role: _userRole,
          );
        }
        _refreshCompleter!.complete(true);
        return true;
      }
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  // ─── IoT deployment (IOT-V1) ────────────────────────────────────────
  // TenantId/FarmId không do client quyết định: backend lấy từ JWT và từ deployment request.
  static dynamic _decodeOrThrow(http.Response? resp, {Set<int> ok = const {200, 201}}) {
    if (resp == null || !ok.contains(resp.statusCode)) {
      throw Exception(_apiErrorMessage(resp));
    }
    return resp.body.isEmpty ? null : jsonDecode(resp.body);
  }

  // ─── 2. Farms ────────────────────────────────────────────────────────
  static Future<List<FarmModel>> getFarms() async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/farms');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list.map((item) => FarmModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 4. Fields ───────────────────────────────────────────────────────
  static Future<List<FieldModel>> getFields(String farmId) async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/farms/$farmId/fields');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list
            .map((item) => FieldModel.fromJson(item, defaultFarmId: farmId))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 5. Zones ────────────────────────────────────────────────────────
  static Future<List<ZoneModel>> getZones(
    String fieldId, {
    String farmId = '',
    String farmName = '',
    String fieldName = '',
  }) async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/fields/$fieldId/zones');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list
            .map(
              (item) => ZoneModel.fromJson(
                item,
                farmId: farmId,
                fieldId: fieldId,
                farmName: farmName,
                fieldName: fieldName,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 6. Latest Telemetry ─────────────────────────────────────────────
  static Future<Map<String, double>?> getLatestTelemetry(String zoneId) async {
    try {
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/telemetry/latest',
      );
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final metrics = data['metrics'] as List<dynamic>?;
        if (metrics != null) {
          final result = <String, double>{
            '__hasFreshTelemetry': data['hasFreshTelemetry'] == true
                ? 1.0
                : 0.0,
          };
          for (var m in metrics) {
            if (m['isFresh'] != true || m['value'] is! num) continue;
            final rawCode = m['parameterCode']?.toString() ?? '';
            final code = rawCode.replaceAll('_', '').toLowerCase();
            final key = switch (code) {
              'temperature' => 'TEMPERATURE',
              'soilmoisture' => 'SOILMOISTURE',
              'airhumidity' => 'AIRHUMIDITY',
              'light' || 'lightintensity' => 'LIGHTINTENSITY',
              'ph' || 'soilph' => 'PH',
              'ec' || 'soilec' => 'EC',
              _ => rawCode.toUpperCase(),
            };
            result[key] = (m['value'] as num).toDouble();
          }
          return result;
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 6.5. Zone Actuators ──────────────────────────────────────────────
  static Future<List<ActuatorModel>> getZoneActuators(String zoneId) async {
    try {
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/actuators',
      );
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list
            .map((item) => ActuatorModel.fromJson(item, defaultZoneId: zoneId))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 6.6. Telemetry History (Database backed) ────────────────────────
  static Future<List<Map<String, dynamic>>> getTelemetryHistory({
    required String zoneId,
    required String parameterCode,
    DateTime? fromUtc,
    DateTime? toUtc,
    String interval = '1h',
  }) async {
    try {
      final from =
          (fromUtc ??
                  DateTime.now().toUtc().subtract(const Duration(hours: 24)))
              .toIso8601String();
      final to = (toUtc ?? DateTime.now().toUtc()).toIso8601String();
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/telemetry/history?parameterCode=$parameterCode&fromUtc=$from&toUtc=$to&interval=$interval',
      );
      if (resp != null && resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = decoded['data'] as List<dynamic>?;
        if (list != null) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    } catch (_) {}
    return [];
  }

  // ─── 7. Farmers (Users) ──────────────────────────────────────────────
  static Future<List<FarmerModel>> getFarmers() async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/users?role=Farmer');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list.map((item) => FarmerModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 8. Alerts ───────────────────────────────────────────────────────
  static Future<List<AlertModel>> getAlerts(String farmId) async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/farms/$farmId/alerts');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list.map((item) => AlertModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 9. Tasks ────────────────────────────────────────────────────────
  static Future<List<TaskModel>> getTasks(String farmId) async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/farms/$farmId/tasks');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        return list.map((item) => TaskModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Một thao tác trên công việc: Accept, Decline, Start, UpdateProgress, Complete, Fail, Approve.
  static Future<TaskModel> updateTaskAction(String farmId, String taskId, Map<String, dynamic> body) async {
    final resp = await _putWithAuth('$baseUrl/api/v1/farms/$farmId/tasks/$taskId', body);
    return TaskModel.fromJson(_decodeOrThrow(resp) as Map<String, dynamic>);
  }

  // ─── Kho vật tư ──────────────────────────
  static Future<List<MaterialInventoryModel>> getInventory(String farmId) async {
    final data = _decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/farms/$farmId/inventory'));
    return [for (final m in _asMapList(data)) MaterialInventoryModel.fromJson(m)];
  }

  // ─── AutoRule & ngưỡng môi trường ────────
  static Future<List<Map<String, dynamic>>> getAutoRules(String zoneId) async =>
      _asMapList(_decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/zones/$zoneId/rules')));

  // ─── Lời mời & quyền Zone của nhân công ──────────
  static List<Map<String, dynamic>> _asMapList(dynamic data) => [
    for (final item in (data as List? ?? const [])) Map<String, dynamic>.from(item as Map),
  ];

  static Future<Map<String, dynamic>?> getMe() async {
    final resp = await _getWithAuth('$baseUrl/api/v1/users/me');
    if (resp == null || resp.statusCode != 200) return null;
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ─── 12. AI Ask ────────────────────────────────────────────────────────
  /// Gửi câu hỏi đến AI Advisory, trả về AiRecommendationModel (Timeout 60s cho LLM Gemini)
  static Future<AiRecommendationModel?> askAi({
    required String zoneId,
    required String prompt,
  }) async {
    try {
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/ai/ask',
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
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/ai/context',
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
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/ai/history',
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
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/ai/apply-recommendation',
        {'recommendationId': recommendationId, 'decision': decision},
      );
      if (resp == null)
        return {'success': false, 'message': 'Không thể kết nối máy chủ'};
      if (resp.statusCode == 200 || resp.statusCode == 202) {
        final body = jsonDecode(resp.body);
        final command = body is Map<String, dynamic> ? body['command'] : null;
        final commandStatus = command is Map<String, dynamic>
            ? command['status']?.toString()
            : null;
        return {'success': true, 'commandStatus': commandStatus};
      }
      if (resp.statusCode == 409) {
        try {
          final body = jsonDecode(resp.body);
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
      final resp = await _deleteWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/ai/history',
      );
      return resp != null && (resp.statusCode == 200 || resp.statusCode == 204);
    } catch (_) {
      return false;
    }
  }

  // ─── 16. Notifications (Hệ thống Thông Báo) ────────────────────────────
  /// Lấy danh sách thông báo của tài khoản hiện tại
  static Future<List<AppNotificationModel>> getNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      String query = 'page=$page&pageSize=$pageSize';
      if (isRead != null) query += '&isRead=$isRead';
      final resp = await _getWithAuth('$baseUrl/api/v1/notifications?$query');
      if (resp != null && resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = (decoded is Map && decoded.containsKey('value'))
            ? decoded['value']
            : decoded;
        if (list is List) {
          return list
              .map(
                (item) =>
                    AppNotificationModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // ─── VietGAP Knowledge Documents ──────────────────────────────────────────
  static String _apiErrorMessage(http.Response? response) {
    if (response == null) return 'Không nhận được phản hồi từ máy chủ.';
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        return (body['message'] ??
                body['detail'] ??
                body['title'] ??
                response.body)
            .toString();
      }
    } catch (_) {}
    return response.body.isEmpty
        ? 'HTTP ${response.statusCode}'
        : response.body;
  }

  // ─── 22. GIS Geocoding Proxy (Bảo mật định vị & ẩn danh khách hàng) ───────
  /// Reverse geocoding qua backend proxy bằng POST (bảo vệ tọa độ không bị ghi vào reverse proxy access logs)
  static Future<Map<String, dynamic>?> reverseGeocode(double latitude, double longitude) async {
    try {
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/gis/reverse-geocode',
        {
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      if (resp != null && resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─── 23. Farm Weather (Thời tiết theo vị trí hiệu lực Farm/Field/Zone) ────
  /// Lấy dữ liệu thời tiết trạm địa phương từ backend theo vị trí hiệu lực
  static Future<Map<String, dynamic>?> getFarmWeather(String farmId) async {
    try {
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/farms/$farmId/weather',
        timeout: const Duration(seconds: 12),
      );
      if (resp != null && resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
