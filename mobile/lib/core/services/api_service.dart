import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, ValueNotifier, debugPrint;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/agriculture_document.dart';
import '../models/iot_deployment.dart';
import 'app_role.dart';
import 'geocode_result.dart';
export 'geocode_result.dart';
part 'api/deployment_api.dart';
part 'api/support_api.dart';
part 'api/farm_api.dart';
part 'api/task_api.dart';
part 'api/automation_api.dart';
part 'api/account_api.dart';
part 'api/crop_api.dart';
part 'api/ai_api.dart';
part 'api/contract_api.dart';
part 'api/document_api.dart';
part 'api/report_api.dart';

class SecurityException implements Exception {
  final String message;
  const SecurityException(this.message);
  @override
  String toString() => 'SecurityException: $message';
}

class ApiService {
  // Dùng chung một client để tái sử dụng kết nối (keep-alive) thay vì mở kết nối mới ở mỗi lệnh gọi.
  static final http.Client _client = http.Client();

  // Danh sách host phát hành chính thức được tin cậy
  static const Set<String> _trustedReleaseHosts = {'api.smartfarm.vn', 'smartfarm.vn', 'app.smartfarm.vn'};

  /// Base URL mặc định theo môi trường
  static String get defaultBaseUrl {
    if (kReleaseMode) {
      const envUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.smartfarm.vn');
      return envUrl;
    }
    // Debug / Development
    if (kIsWeb || !Platform.isAndroid) {
      return 'http://localhost:5144';
    } else {
      return 'http://10.0.2.2:5144';
    }
  }

  // Base URL hiện tại
  static String _baseUrl = defaultBaseUrl;
  static String get baseUrl => _baseUrl;
  static set baseUrl(String value) => setBaseUrl(value);

  // Token đăng nhập lưu trong kho an toàn của hệ điều hành (Keystore/Keychain), TUYỆT ĐỐI không để trong SharedPreferences.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();
  static String? _accessToken;
  static String? _refreshToken;
  static String? _userEmail;
  static String? _userRole;
  static Completer<bool>? _refreshCompleter;

  /// Kiểm tra và chuẩn hoá Base URL:
  /// - Bản Release: bắt buộc scheme là HTTPS, từ chối HTTP, chỉ cho phép host tin cậy.
  /// - Bản Debug: cho phép HTTP/HTTPS cục bộ.
  static String validateAndNormalizeBaseUrl(String url, {bool isRelease = kReleaseMode}) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FormatException('URL API không hợp lệ: $url');
    }

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    if (isRelease) {
      if (scheme != 'https') {
        throw SecurityException('Bản release từ chối kết nối không mã hóa HTTP. Bắt buộc dùng HTTPS: $url');
      }
      const envHost = String.fromEnvironment('API_HOST');
      final isTrusted = _trustedReleaseHosts.contains(host) || (envHost.isNotEmpty && host == envHost.toLowerCase());
      if (!isTrusted) {
        throw SecurityException('Host không nằm trong danh sách máy chủ tin cậy được phát hành: $host');
      }
    } else {
      if (scheme != 'http' && scheme != 'https') {
        throw FormatException('Scheme không được hỗ trợ: ${uri.scheme}');
      }
    }

    return cleaned;
  }

  /// Bảo đảm các yêu cầu API trong bản release không bao giờ gửi qua kênh HTTP không mã hoá
  static void _assertSecureRequest(Uri uri) => assertSecureRequest(uri);

  /// Kiểm tra URL đích trước khi gửi (kèm token): release bắt buộc HTTPS và host tin cậy.
  static void assertSecureRequest(Uri uri, {bool isRelease = kReleaseMode}) {
    if (!isRelease) return;
    if (uri.scheme.toLowerCase() != 'https') {
      throw SecurityException(
        'Bản release nghiêm cấm gửi yêu cầu hoặc thông tin xác thực qua kết nối không mã hóa HTTP.',
      );
    }
    validateAndNormalizeBaseUrl('${uri.scheme}://${uri.host}', isRelease: true);
  }

  /// Tăng mỗi khi phiên bị xoá (đăng xuất / refresh thất bại) để UI quay về màn đăng nhập.
  static final ValueNotifier<int> sessionVersion = ValueNotifier<int>(0);

  static void setBaseUrl(String url) {
    final validated = validateAndNormalizeBaseUrl(url);
    if (!kIsWeb && !kReleaseMode && Platform.isAndroid) {
      _baseUrl = validated.replaceAll('localhost', '10.0.2.2');
    } else {
      _baseUrl = validated;
    }
  }

  static void setTokens({String? accessToken, String? refreshToken, String? email, String? role}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userEmail = email;
    _userRole = role;
  }

  static bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  static String? get userEmail => _userEmail;
  static String? get userRole => _userRole;

  /// Role đã chuẩn hoá (null nếu không được mobile hỗ trợ).
  static AppRole? get appRole => parseAppRole(_userRole);

  /// Nạp token đã lưu từ kho an toàn (FlutterSecureStorage) khi ứng dụng khởi động
  static Future<bool> loadSavedTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Đảm bảo không tồn tại token lưu trái phép trong SharedPreferences
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');

      // Đọc token từ kho an toàn duy nhất (Keystore/Keychain)
      _accessToken = await _secure.read(key: 'access_token');
      _refreshToken = await _secure.read(key: 'refresh_token');
      _userEmail = prefs.getString('user_email');
      _userRole = prefs.getString('user_role');
      if (_accessToken != null && parseAppRole(_userRole) == null) {
        // Phiên cũ có role thiếu/không hỗ trợ: xoá sạch, buộc đăng nhập lại.
        await clearTokens();
        return false;
      }

      final savedUrl = prefs.getString('base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        try {
          setBaseUrl(savedUrl);
        } catch (_) {
          // Nếu URL đã lưu không vượt qua kiểm định an toàn ở bản release, hoàn nguyên về default
          _baseUrl = defaultBaseUrl;
          await prefs.remove('base_url');
        }
      } else {
        _baseUrl = defaultBaseUrl;
      }
      return _accessToken != null && _accessToken!.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Lưu token DUY NHẤT vào kho an toàn (FlutterSecureStorage) và thông tin phiên không nhạy cảm vào SharedPreferences
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
      // 1. Ghi token vào kho an toàn hệ thống
      await _secure.write(key: 'access_token', value: accessToken);
      await _secure.write(key: 'refresh_token', value: refreshToken);

      // 2. Bảo đảm KHÔNG BAO GIỜ lưu token vào SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');

      if (email != null) await prefs.setString('user_email', email);
      if (role != null) await prefs.setString('user_role', role);

      // Chỉ lưu baseUrl nếu hợp lệ
      if (kReleaseMode) {
        if (Uri.tryParse(_baseUrl)?.scheme == 'https') {
          await prefs.setString('base_url', _baseUrl);
        }
      } else {
        await prefs.setString('base_url', _baseUrl);
      }
    } catch (_) {}
  }

  /// Xóa sạch token trong kho an toàn và toàn bộ thông tin phiên khi đăng xuất
  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _userEmail = null;
    _userRole = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _secure.delete(key: 'access_token');
      await _secure.delete(key: 'refresh_token');
      await _secure.deleteAll();

      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_email');
      await prefs.remove('user_role');
      await prefs.remove('base_url');
    } catch (_) {}
    sessionVersion.value++;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ─── Helper: auto refresh on 401 ────────────────────────────────────
  static Future<http.Response?> _getWithAuth(String url, {Duration timeout = const Duration(seconds: 15)}) async {
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client.get(uri, headers: _headers).timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client.get(uri, headers: _headers).timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _postWithAuth(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client.post(uri, headers: _headers, body: jsonEncode(body)).timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client.post(uri, headers: _headers, body: jsonEncode(body)).timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _deleteWithAuth(String url, {Duration timeout = const Duration(seconds: 15)}) async {
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client.delete(uri, headers: _headers).timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client.delete(uri, headers: _headers).timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _putWithAuth(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client.put(uri, headers: _headers, body: jsonEncode(body)).timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client.put(uri, headers: _headers, body: jsonEncode(body)).timeout(timeout);
      }
    }
    return resp;
  }

  // ─── 1. Auth: Đăng nhập ─────────────────────────────────────────────
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final loginUri = Uri.parse('$baseUrl/api/v1/auth/login');
      _assertSecureRequest(loginUri);
      final response = await _client
          .post(
            loginUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['accessToken'] as String?;
        final rToken = data['refreshToken'] as String?;
        final role = (data['user'] is Map ? data['user']['role'] : data['role'])?.toString();
        if (parseAppRole(role) == null) {
          // Role không hỗ trợ: không lưu phiên, thu hồi token vừa cấp (best effort).
          _accessToken = token;
          _refreshToken = rToken;
          await logout();
          return {'error': 'unsupported_role', 'message': unsupportedRoleMessage(role)};
        }
        if (token != null && rToken != null) {
          await saveTokens(accessToken: token, refreshToken: rToken, email: email, role: role);
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
      final registerUri = Uri.parse('$baseUrl/api/v1/auth/register');
      _assertSecureRequest(registerUri);
      final response = await _client
          .post(
            registerUri,
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

  // ─── Auth: Đăng xuất ────────────────────────────────────────────────
  static Future<bool> logout() async {
    try {
      if (_accessToken != null) {
        final logoutUri = Uri.parse('$baseUrl/api/v1/auth/logout');
        _assertSecureRequest(logoutUri);
        await _client
            .post(
              logoutUri,
              headers: _headers,
              body: jsonEncode({'refreshToken': _refreshToken, 'revokeAllDevices': false}),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    await clearTokens();
    return true;
  }

  // ─── Refresh Token (Concurrency Guarded) ───────────────────────────
  static Future<bool> refreshToken() async {
    if (_refreshToken == null || _refreshToken!.trim().isEmpty) {
      // Do not leave a stale access token active in the UI after the server rejects it.
      // The session listener will route the app back to sign-in.
      if (_accessToken != null && _accessToken!.isNotEmpty) await clearTokens();
      return false;
    }
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final refreshUri = Uri.parse('$baseUrl/api/v1/auth/refresh');
      _assertSecureRequest(refreshUri);
      final response = await _client
          .post(
            refreshUri,
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
      if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
        // Refresh token bị từ chối/hết hạn/bị thu hồi: xoá phiên.
        await clearTokens();
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

  // ─── Lời mời & quyền Zone của nhân công ──────────
  static List<Map<String, dynamic>> _asMapList(dynamic data) => [
    for (final item in (data as List? ?? const [])) Map<String, dynamic>.from(item as Map),
  ];

  // ─── 10c. Luồng đồng bộ với Web FE ────────────────────────────────────
  static List<Map<String, dynamic>> _listOf(dynamic data) {
    final raw = data is Map && data['value'] is List ? data['value'] : data;
    return raw is List ? _asMapList(raw) : <Map<String, dynamic>>[];
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Giống _decodeOrThrow nhưng luôn giải mã UTF-8 (tên tiếng Việt) bất kể header charset.
  static dynamic _decodeUtf8OrThrow(http.Response? resp, {Set<int> ok = const {200, 201}}) {
    if (resp == null || !ok.contains(resp.statusCode)) throw Exception(_apiErrorMessage(resp));
    return resp.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(resp.bodyBytes));
  }

  // ─── VietGAP Knowledge Documents ──────────────────────────────────────────
  static String _apiErrorMessage(http.Response? response) => errorMessageFor(response);

  /// Thông báo lỗi dễ hiểu cho người dùng từ phản hồi của backend.
  /// Ưu tiên nội dung do backend trả về (detail/message/errors); khi không có hoặc chỉ là tiêu đề chung
  /// ("Forbidden", "Bad Request"...) thì dùng câu tiếng Việt theo mã HTTP, đặc biệt 401/403.
  static String errorMessageFor(http.Response? response) {
    if (response == null) return 'Không nhận được phản hồi từ máy chủ.';
    String? fromBody;
    String? problemTitle;
    String? problemDetail;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        problemTitle = body['title']?.toString().trim();
        problemDetail = body['detail']?.toString().trim();
        final errors = body['errors'];
        String? validation;
        if (errors is Map) {
          final parts = <String>[
            for (final v in errors.values)
              if (v is List) ...v.map((e) => '$e') else '$v',
          ].where((e) => e.trim().isNotEmpty).toList();
          if (parts.isNotEmpty) validation = parts.join(' ');
        }
        final candidates = [body['detail'], body['message'], validation, body['title']];
        for (final c in candidates) {
          final t = c?.toString().trim();
          if (t != null && t.isNotEmpty && !_genericHttpTitles.contains(t.toLowerCase())) {
            fromBody = t;
            break;
          }
        }
      } else if (body is String && body.trim().isNotEmpty) {
        fromBody = body.trim();
      }
    } catch (_) {
      final raw = response.body.trim();
      if (raw.isNotEmpty && raw.length < 300 && !raw.startsWith('<')) fromBody = raw;
    }
    if (response.statusCode == 401 &&
        (problemTitle?.toLowerCase() == 'authentication required' ||
            problemDetail?.toLowerCase().contains('valid, active bearer token') == true)) {
      return 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại rồi thử lại.';
    }
    if (fromBody != null) return fromBody;
    switch (response.statusCode) {
      case 400:
      case 422:
        return 'Dữ liệu gửi lên chưa hợp lệ. Vui lòng kiểm tra lại các trường đã nhập.';
      case 401:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 403:
        return 'Tài khoản của bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu yêu cầu (có thể đã bị xóa hoặc không thuộc tài khoản của bạn).';
      case 409:
        return 'Thao tác xung đột với dữ liệu hiện có. Hãy tải lại rồi thử lại.';
      case 429:
        return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
    }
    if (response.statusCode >= 500) return 'Máy chủ đang gặp lỗi (HTTP ${response.statusCode}). Vui lòng thử lại sau.';
    return 'Yêu cầu thất bại (HTTP ${response.statusCode}).';
  }

  static const Set<String> _genericHttpTitles = {
    'bad request',
    'unauthorized',
    'forbidden',
    'not found',
    'conflict',
    'internal server error',
    'one or more validation errors occurred.',
    'unprocessable entity',
  };
}

/// Backend chưa cung cấp endpoint tương ứng.
class UnsupportedApiException implements Exception {
  final String message;
  UnsupportedApiException(this.message);
  @override
  String toString() => message;
}
