import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/agriculture_document.dart';
import '../models/iot_deployment.dart';
import 'app_role.dart';

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
  static const Set<String> _trustedReleaseHosts = {
    'api.smartfarm.vn',
    'smartfarm.vn',
    'app.smartfarm.vn',
  };

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
      final isTrusted = _trustedReleaseHosts.contains(host) ||
          (envHost.isNotEmpty && host == envHost.toLowerCase());
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

  static void setTokens({
    String? accessToken,
    String? refreshToken,
    String? email,
    String? role,
  }) {
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
  static Future<http.Response?> _getWithAuth(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client
        .get(uri, headers: _headers)
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .get(uri, headers: _headers)
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
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .post(uri, headers: _headers, body: jsonEncode(body))
            .timeout(timeout);
      }
    }
    return resp;
  }

  static Future<http.Response?> _deleteWithAuth(
    String url, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client
        .delete(uri, headers: _headers)
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .delete(uri, headers: _headers)
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
    final uri = Uri.parse(url);
    _assertSecureRequest(uri);
    var resp = await _client
        .put(uri, headers: _headers, body: jsonEncode(body))
        .timeout(timeout);
    if (resp.statusCode == 401) {
      final ok = await refreshToken();
      if (ok) {
        resp = await _client
            .put(uri, headers: _headers, body: jsonEncode(body))
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
        final role = (data['user'] is Map ? data['user']['role'] : data['role'])
            ?.toString();
        if (parseAppRole(role) == null) {
          // Role không hỗ trợ: không lưu phiên, thu hồi token vừa cấp (best effort).
          _accessToken = token;
          _refreshToken = rToken;
          await logout();
          return {'error': 'unsupported_role', 'message': unsupportedRoleMessage(role)};
        }
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
              body: jsonEncode({
                'refreshToken': _refreshToken,
                'revokeAllDevices': false,
              }),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    await clearTokens();
    return true;
  }

  // ─── Refresh Token (Concurrency Guarded) ───────────────────────────
  static Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
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

  static Future<IotRequirements> getIotRequirements(String zoneId) async =>
      IotRequirements.fromJson(
        _decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/zones/$zoneId/iot-requirements')) as Map<String, dynamic>,
      );

  static Future<List<DeviceRecommendation>> getDeviceRecommendations(String zoneId) async {
    final data = _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/device-recommendations', {}));
    return (data as List).map((e) => DeviceRecommendation.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Yêu cầu triển khai của Tenant trong JWT (lọc theo Zone nếu có); thay cho việc lưu mã trên máy.
  static Future<List<DeploymentRequest>> getOwnerDeploymentRequests({String? zoneId}) async {
    final query = zoneId == null ? '' : '?zoneId=$zoneId';
    final data = _decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/deployment-requests$query'));
    return (data as List).map((e) => DeploymentRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DeploymentRequest> createDeploymentRequest(String zoneId, List<PlanItem> items, {String? notes}) async =>
      DeploymentRequest.fromJson(
        _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/deployment-requests', {
          'items': items.map((i) => i.toRequestJson()).toList(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })) as Map<String, dynamic>,
      );

  static Future<DeploymentRequest> updateOwnerDeploymentPlan(String requestId, List<PlanItem> items) async =>
      DeploymentRequest.fromJson(
        _decodeOrThrow(await _putWithAuth('$baseUrl/api/v1/deployment-requests/$requestId/plan', {
          'items': items.map((i) => i.toRequestJson()).toList(),
        })) as Map<String, dynamic>,
      );

  static Future<DeploymentRequest> submitDeploymentRequest(String requestId) async =>
      DeploymentRequest.fromJson(
        _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/deployment-requests/$requestId/submit', {})) as Map<String, dynamic>,
      );

  /// Owner đọc theo `/deployment-requests/{id}`, kỹ thuật viên theo `/platform/deployment-requests/{id}`.
  static Future<DeploymentRequest> getDeploymentRequest(String requestId, {required bool technician}) async =>
      DeploymentRequest.fromJson(
        _decodeOrThrow(await _getWithAuth(
          technician
              ? '$baseUrl/api/v1/platform/deployment-requests/$requestId'
              : '$baseUrl/api/v1/deployment-requests/$requestId',
        )) as Map<String, dynamic>,
      );

  static Future<List<DeploymentRequest>> getTechnicianDeploymentRequests() async {
    final data = _decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/platform/deployment-requests'));
    return (data as List).map((e) => DeploymentRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<DeploymentRequest> _technicianPost(String requestId, String action, [Map<String, dynamic> body = const {}]) async =>
      DeploymentRequest.fromJson(
        _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/platform/deployment-requests/$requestId/$action', body))
            as Map<String, dynamic>,
      );

  static Future<DeploymentRequest> acceptDeploymentRequest(String id) => _technicianPost(id, 'accept');

  static Future<DeploymentRequest> surveyDeploymentRequest(
    String id, {
    required bool isFeasible,
    required String siteConditions,
    required String notes,
  }) => _technicianPost(id, 'survey', {'isFeasible': isFeasible, 'siteConditions': siteConditions, 'notes': notes});

  static Future<DeploymentRequest> updateTechnicianDeploymentPlan(String id, List<PlanItem> items) async =>
      DeploymentRequest.fromJson(
        _decodeOrThrow(await _putWithAuth('$baseUrl/api/v1/platform/deployment-requests/$id/plan', {
          'items': items.map((i) => i.toRequestJson()).toList(),
        })) as Map<String, dynamic>,
      );

  static Future<DeploymentRequest> confirmDeploymentPlan(String id) => _technicianPost(id, 'confirm');
  static Future<DeploymentRequest> startDeploymentInstallation(String id) => _technicianPost(id, 'installation/start');
  static Future<DeploymentRequest> completeDeploymentRequest(String id) => _technicianPost(id, 'complete');

  /// Trả về mã service request bảo trì mà backend tạo khi triển khai thất bại.
  static Future<String> failDeploymentRequest(String id, {required String failureCode, required String description, String? deviceId}) async {
    final data = _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/platform/deployment-requests/$id/fail', {
      'failureCode': failureCode,
      'description': description,
      'deviceId': ?deviceId,
    })) as Map<String, dynamic>;
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
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/platform/deployment-requests/$requestId/connection-tests', {
      'deviceId': deviceId,
      'succeeded': succeeded,
      'rssi': ?rssi,
      'snr': ?snr,
      'roundTripLatencyMs': ?latencyMs,
      'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
      if (errorCode != null && errorCode.isNotEmpty) 'errorCode': errorCode,
      if (errorMessage != null && errorMessage.isNotEmpty) 'errorMessage': errorMessage,
    })) as Map<String, dynamic>,
  );

  static Future<List<IotGateway>> getFarmGateways(String farmId) async {
    final data = _decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/farms/$farmId/gateways'));
    return (data as List).map((e) => IotGateway.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<IotDevice>> getFarmDevices(String farmId) async {
    final data = _decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/farms/$farmId/devices'));
    return (data as List).map((e) => IotDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<IotGateway> provisionGateway({
    required String deploymentRequestId,
    required String farmId,
    required String macAddress,
    required String gatewaySerial,
    required String frequencyBand,
    required String firmwareVersion,
    required String mqttClientId,
    required String clientCertificateFingerprint,
  }) async => IotGateway.fromJson(
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/gateways', {
      'deploymentRequestId': deploymentRequestId,
      'farmId': farmId,
      'macAddress': macAddress,
      'gatewaySerial': gatewaySerial,
      'frequencyBand': frequencyBand,
      'firmwareVersion': firmwareVersion,
      'mqttClientId': mqttClientId,
      'clientCertificateFingerprint': clientCertificateFingerprint,
    })) as Map<String, dynamic>,
  );

  static Future<List<IotDevice>> provisionDevices({
    required String deploymentRequestId,
    required String gatewayId,
    required String farmId,
    required List<Map<String, dynamic>> nodes,
  }) async {
    final data = _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/devices/provision', {
      'deploymentRequestId': deploymentRequestId,
      'gatewayId': gatewayId,
      'farmId': farmId,
      'nodes': nodes,
    })) as Map<String, dynamic>;
    return (data['devices'] as List? ?? const []).map((e) => IotDevice.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<IotDevice> assignDeviceToZone(String zoneId, String deviceId, {String? installationNotes}) async =>
      IotDevice.fromJson(
        _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/devices/$deviceId/assign', {
          if (installationNotes != null && installationNotes.trim().isNotEmpty) 'installationNotes': installationNotes.trim(),
        })) as Map<String, dynamic>,
      );

  // ─── Báo giá & hợp đồng lắp đặt (service request) ───────────────────
  static Future<Quotation?> getQuotation(String serviceRequestId) async {
    final resp = await _getWithAuth('$baseUrl/api/v1/service-requests/$serviceRequestId/quotation');
    if (resp != null && resp.statusCode == 200 && resp.body.isNotEmpty && resp.body != 'null') {
      return Quotation.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    if (resp != null && (resp.statusCode == 204 || resp.statusCode == 404)) return null;
    throw Exception(_apiErrorMessage(resp));
  }

  static Future<Quotation> createQuotation(
    String serviceRequestId, {
    required List<Map<String, dynamic>> items,
    String? notes,
    String? contractTerms,
  }) async => Quotation.fromJson(
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/service-requests/$serviceRequestId/quotation', {
      'items': items,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (contractTerms != null && contractTerms.isNotEmpty) 'contractTerms': contractTerms,
    })) as Map<String, dynamic>,
  );

  /// Backend chỉ ghi nhận khoản thanh toán do người ký khai báo (chưa có cổng thanh toán);
  /// tên người ký và mã giao dịch do người dùng nhập, không tự sinh.
  static Future<ServicePayment> signContractAndPayDeposit(
    String serviceRequestId, {
    required String signerFullName,
    required String paymentMethod,
    required String transactionReference,
  }) async => ServicePayment.fromJson(
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/service-requests/$serviceRequestId/sign-contract-deposit', {
      'signerFullName': signerFullName,
      'paymentMethod': paymentMethod,
      'transactionReference': transactionReference,
    })) as Map<String, dynamic>,
  );

  static Future<ServicePayment> signAcceptanceAndPayFinal(
    String serviceRequestId, {
    required String signerFullName,
    required String paymentMethod,
    required String transactionReference,
  }) async => ServicePayment.fromJson(
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/service-requests/$serviceRequestId/sign-acceptance-final', {
      'signerFullName': signerFullName,
      'paymentMethod': paymentMethod,
      'transactionReference': transactionReference,
    })) as Map<String, dynamic>,
  );

  // ─── Service requests (Hỗ trợ kỹ thuật) ─────────────────────────────
  static Future<List<Map<String, dynamic>>> getServiceRequests() async {
    final resp = await _getWithAuth('$baseUrl/api/v1/service-requests');
    if (resp == null || resp.statusCode != 200) {
      throw Exception(_apiErrorMessage(resp));
    }
    return (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createServiceRequest({
    required String farmId,
    required String zoneId,
    required String failureCode,
    required String description,
    String? deploymentRequestId,
  }) async {
    final resp = await _postWithAuth('$baseUrl/api/v1/farms/$farmId/service-requests', {
      'zoneId': zoneId,
      'failureCode': failureCode,
      'description': description,
      'deploymentRequestId': ?deploymentRequestId,
    });
    if (resp == null || (resp.statusCode != 201 && resp.statusCode != 200)) {
      throw Exception(_apiErrorMessage(resp));
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ─── 2. Farms ────────────────────────────────────────────────────────
  static Future<List<FarmModel>> getFarms() async {
    // Ném lỗi khi mạng/máy chủ lỗi để phân biệt với "tài khoản chưa có trang trại" (danh sách rỗng thật).
    final resp = await _getWithAuth('$baseUrl/api/v1/farms');
    if (resp == null || resp.statusCode != 200) throw Exception(_apiErrorMessage(resp));
    final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
    return list.map((item) => FarmModel.fromJson(item)).toList();
  }

  // ─── 3. Farm Structure ───────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getFarmStructure(String farmId) async {
    try {
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/farms/$farmId/structure',
      );
      if (resp != null && resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (_) {}
    return null;
  }

  // ─── 4. Fields ───────────────────────────────────────────────────────
  static Future<List<FieldModel>> getFields(String farmId) async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/farms/$farmId/fields');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
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
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
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
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
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
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
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
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
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
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((item) => TaskModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Giao việc cho các Farmer đã có quyền Zone; lỗi nghiệp vụ được báo nguyên văn từ backend.
  static Future<TaskModel> createTask(String farmId, Map<String, dynamic> data) async {
    final resp = await _postWithAuth('$baseUrl/api/v1/farms/$farmId/tasks', data);
    return TaskModel.fromJson(_decodeOrThrow(resp) as Map<String, dynamic>);
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

  static Future<void> createInventoryItem(String farmId, Map<String, dynamic> body) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/farms/$farmId/inventory', body));
  }

  static Future<void> receiveInventory(String farmId, String itemId, double quantity) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/farms/$farmId/inventory/$itemId/receipts', {'quantity': quantity}));
  }

  static Future<void> issueInventory(String farmId, String itemId, double quantity, String zoneId) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/farms/$farmId/inventory/issues', {
      'inventoryItemId': itemId,
      'quantity': quantity,
      'zoneId': zoneId,
    }));
  }

  // ─── AutoRule & ngưỡng môi trường ────────
  static Future<List<Map<String, dynamic>>> getAutoRules(String zoneId) async =>
      _asMapList(_decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/zones/$zoneId/rules')));

  static Future<void> createAutoRule(String zoneId, Map<String, dynamic> body) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/rules', body));
  }

  static Future<void> updateAutoRule(String zoneId, String ruleId, Map<String, dynamic> body) async {
    _decodeOrThrow(await _putWithAuth('$baseUrl/api/v1/zones/$zoneId/rules/$ruleId', body));
  }

  static Future<void> updateEnvironmentalThresholds(String zoneId, {required double minSoil, required double maxSoil, required double maxTemp}) async {
    final configs = _asMapList(_decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/control/environmental-configs?zoneId=$zoneId')));
    final current = configs.isNotEmpty ? configs.first : const <String, dynamic>{};
    _decodeOrThrow(await _putWithAuth('$baseUrl/api/v1/control/environmental-configs', {
      'zoneId': zoneId,
      'targetSoilMoisture': (minSoil + maxSoil) / 2,
      'minSoilMoisture': minSoil,
      'maxSoilMoisture': maxSoil,
      'maxTemperature': maxTemp,
      'targetHumidity': current['targetHumidity'] ?? 0,
      'targetLux': current['targetLux'] ?? 0,
      'powerWatts': current['powerWatts'],
    }));
  }

  // ─── Lời mời & quyền Zone của nhân công ──────────
  static List<Map<String, dynamic>> _asMapList(dynamic data) => [
    for (final item in (data as List? ?? const [])) Map<String, dynamic>.from(item as Map),
  ];

  static Future<List<Map<String, dynamic>>> getMyInvitations() async =>
      _asMapList(_decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/farm-invitations/mine')));

  static Future<void> respondInvitation(String id, bool accept) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/farm-invitations/$id/${accept ? 'accept' : 'decline'}', {}));
  }

  static Future<List<Map<String, dynamic>>> getFarmInvitations(String farmId) async =>
      _asMapList(_decodeOrThrow(await _getWithAuth('$baseUrl/api/v1/farms/$farmId/invitations')));

  static Future<void> inviteFarmer(String farmId, String email) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/farms/$farmId/invitations', {'email': email}));
  }

  /// action: resend hoặc cancel.
  static Future<void> invitationAction(String id, String action) async {
    _decodeOrThrow(await _postWithAuth('$baseUrl/api/v1/farm-invitations/$id/$action', {}));
  }

  static Future<void> updateFarmerZoneAccess(String farmerId, List<Map<String, dynamic>> access) async {
    _decodeOrThrow(await _putWithAuth('$baseUrl/api/v1/users/$farmerId/zone-access', {'access': access}));
  }

  static Future<Map<String, dynamic>?> getMe() async {
    final resp = await _getWithAuth('$baseUrl/api/v1/users/me');
    if (resp == null || resp.statusCode != 200) return null;
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Cập nhật họ tên và số điện thoại của tài khoản đang đăng nhập (PUT /users/me).
  static Future<Map<String, dynamic>?> updateProfile(String fullName, String? phone) async {
    final resp = await _putWithAuth('$baseUrl/api/v1/users/me', {
      'fullName': fullName,
      'phone': phone,
    });
    if (resp == null || resp.statusCode != 200) return null;
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ─── 10. Actuator Command ─────────────────────────────────────────────
  static Future<bool> sendActuatorCommand({
    required String zoneId,
    required String actuatorId,
    required String action, // TurnOn, TurnOff
    int durationSeconds = 600,
  }) async {
    try {
      // Backend validates [Range(1, 1800)] DurationSeconds for both TurnOn and TurnOff
      final safeDuration = durationSeconds <= 0
          ? 1
          : durationSeconds.clamp(1, 1800);
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/actuators/$actuatorId/command',
        {
          'action': action,
          'durationSeconds': safeDuration,
          'overrideActiveSchedules': true,
          'idempotencyKey': 'mob_${DateTime.now().microsecondsSinceEpoch}',
          'notes': 'Điều khiển từ SmartFarm Mobile App',
        },
      );
      return resp != null && (resp.statusCode == 200 || resp.statusCode == 202);
    } catch (_) {
      return false;
    }
  }

  // ─── 11. Acknowledge Alert ─────────────────────────────────────────────
  static Future<bool> acknowledgeAlert(String alertId, {String? notes}) async {
    try {
      final resp = await _putWithAuth(
        '$baseUrl/api/v1/alerts/$alertId/acknowledge',
        {'notes': notes ?? 'Đã xác nhận từ ứng dụng di động'},
      );
      return resp != null && resp.statusCode == 200;
    } catch (_) {
      return false;
    }
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
      final resp = await _deleteWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/ai/history',
      );
      return resp != null && (resp.statusCode == 200 || resp.statusCode == 204);
    } catch (_) {
      return false;
    }
  }

  // ─── 14. Schedules ─────────────────────────────────────────────────────
  /// Lấy danh sách lịch tưới của một Zone (GET /zones/{zoneId}/schedules).
  /// Backend không có API lịch theo Farm: muốn lịch cả Farm, gọi lần lượt từng Zone (xem FarmProvider.fetchSchedules).
  static Future<List<ScheduleModel>> getSchedules({required String zoneId}) async {
    try {
      final resp = await _getWithAuth('$baseUrl/api/v1/zones/$zoneId/schedules');
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((item) => ScheduleModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
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
    double rainThresholdPercent = 70.0,
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
          'rainThresholdPercent': rainThresholdPercent,
          'isActive': enable,
        };
        final resp = await _putWithAuth(
          '$baseUrl/api/v1/zones/$zoneId/schedules/$scheduleId',
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

  /// Lấy số lượng thông báo chưa đọc
  static Future<int> getUnreadNotificationCount() async {
    try {
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/notifications/unread-count',
      );
      if (resp != null && resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded.containsKey('unreadCount')) {
          return (decoded['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Đánh dấu một thông báo đã đọc
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final resp = await _client
          .put(
            Uri.parse('$baseUrl/api/v1/notifications/$notificationId/read'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Đánh dấu tất cả thông báo đã đọc
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final resp = await _client
          .put(
            Uri.parse('$baseUrl/api/v1/notifications/read-all'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Xóa một thông báo
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final resp = await _client
          .delete(
            Uri.parse('$baseUrl/api/v1/notifications/$notificationId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Xóa tất cả thông báo đã đọc
  static Future<int> deleteAllReadNotifications() async {
    try {
      final resp = await _client
          .delete(
            Uri.parse('$baseUrl/api/v1/notifications/read-all'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['deletedCount'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ─── 17. Zone Contracts (Quản lý Hợp đồng thuê Zone) ──────────────────
  /// Lấy danh sách hợp đồng (có thể lọc theo farmId hoặc zoneId)
  static Future<List<ZoneContractModel>> getZoneContracts({
    String? farmId,
    String? zoneId,
  }) async {
    try {
      String url = '$baseUrl/api/v1/zone-contracts';
      if (zoneId != null) {
        url = '$baseUrl/api/v1/zones/$zoneId/contracts';
      } else if (farmId != null) {
        url = '$baseUrl/api/v1/farms/$farmId/zone-contracts';
      }
      final resp = await _getWithAuth(url);
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list
            .map(
              (item) =>
                  ZoneContractModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Xem chi tiết một hợp đồng
  static Future<ZoneContractModel?> getZoneContractById(
    String contractId,
  ) async {
    try {
      final resp = await _getWithAuth(
        '$baseUrl/api/v1/zone-contracts/$contractId',
      );
      if (resp != null && resp.statusCode == 200) {
        return ZoneContractModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Tạo hợp đồng mới cho Zone
  static Future<ZoneContractModel?> createZoneContract(
    String zoneId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/contracts',
        data,
      );
      if (resp != null && (resp.statusCode == 200 || resp.statusCode == 201)) {
        return ZoneContractModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Gia hạn hợp đồng
  static Future<ZoneContractModel?> renewZoneContract(
    String contractId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/zone-contracts/$contractId/renew',
        data,
      );
      if (resp != null && resp.statusCode == 200) {
        return ZoneContractModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Cảnh báo hợp đồng sắp hết hạn (< 30 ngày)
  static Future<List<ExpiringContractAlertModel>> getExpiringContracts({
    String? farmId,
    int daysThreshold = 30,
  }) async {
    try {
      String url =
          '$baseUrl/api/v1/zone-contracts/expiring?daysThreshold=$daysThreshold';
      if (farmId != null) url += '&farmId=$farmId';
      final resp = await _getWithAuth(url);
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list
            .map(
              (item) => ExpiringContractAlertModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 18. Device Depreciations (Khấu hao thiết bị) ─────────────────────
  /// Lấy danh sách khấu hao thiết bị theo Zone hoặc Farm
  static Future<List<DeviceDepreciationModel>> getDeviceDepreciations({
    String? zoneId,
    String? farmId,
  }) async {
    try {
      String url;
      if (zoneId != null) {
        url = '$baseUrl/api/v1/zones/$zoneId/depreciations';
      } else if (farmId != null) {
        url = '$baseUrl/api/v1/farms/$farmId/depreciations';
      } else {
        return [];
      }
      final resp = await _getWithAuth(url);
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list
            .map(
              (item) => DeviceDepreciationModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Tạo hồ sơ trích khấu hao thiết bị cho Zone
  static Future<DeviceDepreciationModel?> createDeviceDepreciation(
    String zoneId,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/zones/$zoneId/depreciations',
        data,
      );
      if (resp != null && (resp.statusCode == 200 || resp.statusCode == 201)) {
        return DeviceDepreciationModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  // ─── 19. Farming Seasons (Khung Mùa Vụ Canh Tác) ──────────────────────
  /// Lấy danh sách mùa vụ
  static Future<List<FarmingSeasonModel>> getFarmingSeasons({
    int? year,
    String? status,
  }) async {
    try {
      String query = '';
      if (year != null) query += 'year=$year&';
      if (status != null) query += 'status=$status&';
      final url = '$baseUrl/api/v1/seasons${query.isNotEmpty ? '?$query' : ''}';
      final resp = await _getWithAuth(url);
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list
            .map(
              (item) =>
                  FarmingSeasonModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Tạo mới mùa vụ canh tác
  static Future<FarmingSeasonModel?> createFarmingSeason(
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _postWithAuth('$baseUrl/api/v1/seasons', data);
      if (resp != null && (resp.statusCode == 200 || resp.statusCode == 201)) {
        return FarmingSeasonModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Cập nhật mùa vụ canh tác
  static Future<FarmingSeasonModel?> updateFarmingSeason(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final resp = await _putWithAuth('$baseUrl/api/v1/seasons/$id', data);
      if (resp != null && resp.statusCode == 200) {
        return FarmingSeasonModel.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Xóa / Lưu trữ mùa vụ
  static Future<bool> deleteFarmingSeason(String id) async {
    try {
      final resp = await _deleteWithAuth('$baseUrl/api/v1/seasons/$id');
      return resp != null && (resp.statusCode == 200 || resp.statusCode == 204);
    } catch (_) {
      return false;
    }
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

  static Future<List<AgricultureDocumentModel>>
  getAgricultureDocuments() async {
    final response = await _getWithAuth(
      '$baseUrl/api/v1/ai/knowledge/documents',
      timeout: const Duration(seconds: 30),
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(_apiErrorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? decoded['value'] : null);
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map(
          (item) => AgricultureDocumentModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Future<AgricultureDocumentModel> getAgricultureDocument(
    String id,
  ) async {
    final response = await _getWithAuth(
      '$baseUrl/api/v1/ai/knowledge/documents/$id',
      timeout: const Duration(seconds: 30),
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(_apiErrorMessage(response));
    }
    return AgricultureDocumentModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Chỉ cần file; các trường mô tả để trống thì server tự lấy từ nội dung file.
  static Future<AgricultureDocumentModel> uploadAgricultureDocument({
    required String fileName,
    required List<int> bytes,
    String? title,
    String category = 'general',
    String? cropScope,
    String? authorOrganization,
    String? version,
  }) async {
    if (bytes.isEmpty) throw Exception('File rỗng.');
    if (bytes.length > 50 * 1024 * 1024) {
        throw Exception('File vượt giới hạn 50 MB.');
    }
    Future<http.Response> send() async {
      final uploadUri = Uri.parse('$baseUrl/api/v1/ai/knowledge/documents');
      _assertSecureRequest(uploadUri);
      final request = http.MultipartRequest(
        'POST',
        uploadUri,
      );
      if (_accessToken != null) {
          request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        if (title != null && title.trim().isNotEmpty) 'Title': title.trim(),
        'Category': category,
        if (cropScope != null && cropScope.trim().isNotEmpty)
          'CropScope': cropScope.trim(),
        if (version != null && version.trim().isNotEmpty)
          'Version': version.trim(),
        if (authorOrganization != null && authorOrganization.trim().isNotEmpty)
          'AuthorOrganization': authorOrganization.trim(),
      });
      request.files.add(
        http.MultipartFile.fromBytes('File', bytes, filename: fileName),
      );
      final streamed = await _client.send(request).timeout(const Duration(minutes: 3));
      return http.Response.fromStream(
        streamed,
      ).timeout(const Duration(minutes: 3));
    }

    var response = await send();
    if (response.statusCode == 401 && await refreshToken()) {
        response = await send();
    }
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(_apiErrorMessage(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final id = (body['id'] ?? body['documentId'])?.toString();
    if (id == null || id.isEmpty) {
        throw Exception('Máy chủ không trả về ID tài liệu.');
    }
    return getAgricultureDocument(id);
  }

  static Future<Map<String, dynamic>> reviewAgricultureDocument({
    required String id,
    required String contentText,
    required bool approve,
    String? reviewNotes,
    // Chỉnh metadata sau khi đối chiếu file gốc; null = giữ giá trị hệ thống đã nhận diện.
    String? title,
    String? cropScope,
    String? authorOrganization,
    String? version,
    String? documentType,
    bool confirmGeneralScope = false,
  }) async {
    final response = await _postWithAuth(
      '$baseUrl/api/v1/ai/knowledge/documents/$id/review',
      {
        'contentText': contentText,
        'approve': approve,
        if (reviewNotes != null && reviewNotes.trim().isNotEmpty)
          'reviewNotes': reviewNotes.trim(),
        'title': ?title,
        'cropScope': ?cropScope,
        'authorOrganization': ?authorOrganization,
        'version': ?version,
        'documentType': ?documentType,
        if (confirmGeneralScope) 'confirmGeneralScope': true,
      },
      timeout: const Duration(seconds: 90),
    );
    if (response == null ||
        (response.statusCode != 200 && response.statusCode != 204)) {
      throw Exception(_apiErrorMessage(response));
    }
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<int>> downloadAgricultureOriginalFile(String id) async {
    final response = await _getWithAuth(
      '$baseUrl/api/v1/ai/knowledge/documents/$id/file',
      timeout: const Duration(seconds: 90),
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(_apiErrorMessage(response));
    }
    return response.bodyBytes;
  }

  static Future<List<Map<String, dynamic>>> getCropsForProfiles() async {
    final response = await _getWithAuth('$baseUrl/api/v1/crops');
    if (response == null || response.statusCode != 200) {
      throw Exception(_apiErrorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? decoded['value'] : null);
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getGrowthProfiles() async {
    final response = await _getWithAuth('$baseUrl/api/v1/growth-profiles');
    if (response == null || response.statusCode != 200) {
      throw Exception(_apiErrorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? decoded['value'] : null);
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// POST /api/v1/zones/{zoneId}/planting-seasons (Owner). Tạo vụ là cách duy nhất gán cây cho Zone.
  static Future<Map<String, dynamic>> createPlantingSeason(String zoneId, Map<String, dynamic> payload) async {
    final response = await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/planting-seasons', payload);
    if (response == null || (response.statusCode != 201 && response.statusCode != 200)) {
      throw Exception(_apiErrorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createGrowthProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _postWithAuth(
      '$baseUrl/api/v1/growth-profiles',
      payload,
    );
    if (response == null ||
        (response.statusCode != 201 && response.statusCode != 200)) {
      throw Exception(_apiErrorMessage(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Tìm kiếm địa danh qua backend proxy bằng POST (bảo vệ query không bị ghi vào reverse proxy access logs)
  static Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    try {
      final resp = await _postWithAuth(
        '$baseUrl/api/v1/gis/search-location',
        {
          'query': query.trim(),
        },
      );
      if (resp != null && resp.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is List) {
          return decoded.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {}
    return [];
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

  // ─── Mật khẩu tài khoản ─────────────────────────────────────────────
  // Backend hiện CHƯA có các endpoint này (404/405/501 → UnsupportedApiException), app không giả lập thành công.
  static Never _throwPasswordError(http.Response? resp) {
    final code = resp?.statusCode;
    if (code == 404 || code == 405 || code == 501) {
      throw UnsupportedApiException('Máy chủ chưa hỗ trợ chức năng này.');
    }
    throw Exception(_apiErrorMessage(resp));
  }

  static Future<void> forgotPassword(String email) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/forgot-password');
    _assertSecureRequest(uri);
    final resp = await _client
        .post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email}))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 202 && resp.statusCode != 204) _throwPasswordError(resp);
  }

  static Future<void> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/reset-password');
    _assertSecureRequest(uri);
    final resp = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'token': token, 'newPassword': newPassword}),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200 && resp.statusCode != 204) _throwPasswordError(resp);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final resp = await _putWithAuth('$baseUrl/api/v1/users/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 204)) _throwPasswordError(resp);
  }

  // ─── Bảo trì / sửa chữa (Kỹ thuật viên) ─────────────────────────────
  static const Set<String> _serviceActions = {
    'accept', 'diagnosis', 'work', 'replacement', 'connection-tests', 'close',
  };

  static Future<Map<String, dynamic>> getServiceRequest(String id) async {
    final resp = await _getWithAuth('$baseUrl/api/v1/service-requests/$id');
    if (resp == null || resp.statusCode != 200) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// Thao tác trên yêu cầu dịch vụ: accept | diagnosis | work | replacement | connection-tests | close
  static Future<Map<String, dynamic>> serviceRequestAction(
    String id,
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (!_serviceActions.contains(action)) throw ArgumentError('Thao tác không hợp lệ: $action');
    final resp = await _postWithAuth('$baseUrl/api/v1/service-requests/$id/$action', body);
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(_apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> listZoneDevices(String zoneId) async {
    final resp = await _getWithAuth('$baseUrl/api/v1/zones/$zoneId/devices');
    if (resp == null || resp.statusCode != 200) throw Exception(_apiErrorMessage(resp));
    return (jsonDecode(utf8.decode(resp.bodyBytes)) as List).cast<Map<String, dynamic>>();
  }

  /// Thay nóng thiết bị: POST /zones/{zoneId}/devices/{oldDeviceId}/hot-swap
  static Future<Map<String, dynamic>> hotSwapDevice({
    required String zoneId,
    required String oldDeviceId,
    required String serviceRequestId,
    required String newDeviceId,
    String? notes,
  }) async {
    final resp = await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/devices/$oldDeviceId/hot-swap', {
      'serviceRequestId': serviceRequestId,
      'newDeviceId': newDeviceId,
      'notes': ?notes,
    });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(_apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// Trạng thái MQTT thật của gateway: { gatewayId, mqttConnected }
  static Future<Map<String, dynamic>> getGatewayMqttStatus(String gatewayId) async {
    final resp = await _getWithAuth('$baseUrl/api/v1/gateways/$gatewayId/mqtt-status');
    if (resp == null || resp.statusCode != 200) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  // ─── Báo cáo ────────────────────────────────────────────────────────
  static const Set<String> _reportKinds = {
    'overview', 'water-usage', 'electricity', 'inventory', 'tasks', 'maintenance',
  };

  static String _reportQuery(DateTime? from, DateTime? to) {
    final q = <String>[
      if (from != null) 'fromUtc=${Uri.encodeComponent(from.toUtc().toIso8601String())}',
      if (to != null) 'toUtc=${Uri.encodeComponent(to.toUtc().toIso8601String())}',
    ];
    return q.isEmpty ? '' : '?${q.join('&')}';
  }

  static Future<Map<String, dynamic>> getFarmReport(
    String farmId,
    String kind, {
    DateTime? from,
    DateTime? to,
  }) async {
    if (!_reportKinds.contains(kind)) throw ArgumentError('Loại báo cáo không hợp lệ: $kind');
    final resp = await _getWithAuth('$baseUrl/api/v1/farms/$farmId/report/$kind${_reportQuery(from, to)}');
    if (resp == null || resp.statusCode != 200) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// Tải tệp Excel do backend tạo. kind = null → báo cáo tài nguyên tổng hợp (/report/excel).
  static Future<Uint8List> downloadFarmReportExcel(
    String farmId, {
    String? kind,
    DateTime? from,
    DateTime? to,
  }) async {
    if (kind != null && !_reportKinds.contains(kind)) throw ArgumentError('Loại báo cáo không hợp lệ: $kind');
    final path = kind == null ? 'report/excel' : 'report/$kind/excel';
    final resp = await _getWithAuth(
      '$baseUrl/api/v1/farms/$farmId/$path${kind == 'overview' ? '' : _reportQuery(from, to)}',
      timeout: const Duration(seconds: 60),
    );
    if (resp == null || resp.statusCode != 200) throw Exception(_apiErrorMessage(resp));
    return resp.bodyBytes;
  }

  // ─── Tạo Trang trại / Thửa đất / Zone (lưu vào DB qua backend) ─────────
  static Map<String, dynamic> polygonGeoJson(List<List<double>> latLngPoints) {
    final ring = [for (final p in latLngPoints) [p[1], p[0]]]; // GeoJSON: [lng, lat]
    if (ring.isNotEmpty && (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) ring.add(List.of(ring.first));
    return {'type': 'Polygon', 'coordinates': [ring]};
  }

  static Future<Map<String, dynamic>> createFarm({
    required String name,
    String? locationText,
    double? latitude,
    double? longitude,
    required double totalAreaM2,
  }) async {
    final resp = await _postWithAuth('$baseUrl/api/v1/farms', {
      'name': name,
      'locationText': ?locationText,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'totalAreaM2': totalAreaM2,
      'timeZone': 'Asia/Ho_Chi_Minh',
    });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createField({
    required String farmId,
    required String name,
    required double areaM2,
    required Map<String, dynamic> boundaryGeoJson,
    double? latitude,
    double? longitude,
  }) async {
    final resp = await _postWithAuth('$baseUrl/api/v1/farms/$farmId/fields', {
      'name': name,
      'areaM2': areaM2,
      'boundaryGeoJson': boundaryGeoJson,
      'latitude': ?latitude,
      'longitude': ?longitude,
    });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createZone({
    required String fieldId,
    required String name,
    required double areaM2,
    required Map<String, dynamic> polygonGeoJson,
    String zoneType = 'Greenhouse',
    String? notes,
  }) async {
    final resp = await _postWithAuth('$baseUrl/api/v1/fields/$fieldId/zones', {
      'name': name,
      'areaM2': areaM2,
      'polygonGeoJson': polygonGeoJson,
      'zoneType': zoneType,
      'notes': ?notes,
    });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
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
    if (parts.length != 2 || h == null || mi == null || h < 0 || h > 23 || mi < 0 || mi > 59) {
      throw Exception('Giờ bắt đầu phải có dạng HH:mm (vd 06:30).');
    }
    final resp = await _postWithAuth('$baseUrl/api/v1/zones/$zoneId/schedules', {
      'name': name,
      'actuatorId': actuatorId,
      'cronExpression': '$mi $h * * *',
      'durationSeconds': (durationMinutes * 60).clamp(1, 1800),
      'enableRainDelay': true,
      'rainThresholdPercent': 70,
      'isActive': true,
    });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) throw Exception(_apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }
}

/// Backend chưa cung cấp endpoint tương ứng.
class UnsupportedApiException implements Exception {
  final String message;
  UnsupportedApiException(this.message);
  @override
  String toString() => message;
}
