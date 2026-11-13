import 'dart:convert';

/// Loại lỗi của POST /gis/reverse-geocode, để UI báo đúng nguyên nhân và log đủ thông tin chẩn đoán.
enum GeocodeFailureKind {
  network, // không kết nối được backend (sai host/port, backend chưa chạy, mất mạng)
  timeout, // backend/nhà cung cấp quá chậm
  unauthorized, // 401: phiên đăng nhập hết hạn
  forbidden, // 403
  routeMissing, // 404 không có nội dung JSON "message" của backend: route/host sai
  notFound, // 404 từ backend: không có địa chỉ cho toạ độ (hoặc nhà cung cấp lỗi/giới hạn)
  rateLimited, // 429
  invalidCoordinate, // 400
  providerUnavailable, // 502/503: backend không gọi được nhà cung cấp tên địa điểm (DNS/mạng/5xx của nhà cung cấp)
  server, // 5xx khác
  badResponse, // 200 nhưng JSON không có tên địa điểm
}

/// Kết quả reverse-geocode: hoặc có địa chỉ, hoặc có lý do thất bại. Không bao giờ giả địa chỉ bằng toạ độ.
class GeocodeResult {
  final String? displayName;
  final String region; // quận/huyện, thành phố hoặc tỉnh (rỗng nếu không có)
  final GeocodeFailureKind? failure;
  final int? statusCode;

  /// Thông điệp chẩn đoán do backend trả (nếu có), ví dụ lỗi DNS tới nhà cung cấp.
  final String? serverMessage;

  const GeocodeResult._({
    this.displayName,
    this.region = '',
    this.failure,
    this.statusCode,
    this.serverMessage,
  });

  bool get ok => displayName != null;

  factory GeocodeResult.success(String displayName, {String region = ''}) =>
      GeocodeResult._(
        displayName: displayName,
        region: region,
        statusCode: 200,
      );

  factory GeocodeResult.failed(
    GeocodeFailureKind kind, {
    int? statusCode,
    String? serverMessage,
  }) => GeocodeResult._(
    failure: kind,
    statusCode: statusCode,
    serverMessage: serverMessage,
  );

  /// Câu thông báo cho người dùng (tiếng Việt, dễ hiểu).
  String get message => switch (failure) {
    null => '',
    GeocodeFailureKind.providerUnavailable =>
      serverMessage ??
          'Máy chủ không gọi được dịch vụ tên địa điểm. Kiểm tra Internet/DNS của máy chạy backend.',
    GeocodeFailureKind.network =>
      'Không kết nối được máy chủ để lấy tên địa điểm. Kiểm tra backend/mạng rồi thử lại.',
    GeocodeFailureKind.timeout =>
      serverMessage ??
          'Lấy tên địa điểm quá lâu. Hãy thử lại hoặc nhập địa chỉ thủ công.',
    GeocodeFailureKind.unauthorized =>
      'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
    GeocodeFailureKind.forbidden =>
      'Tài khoản không có quyền dùng tìm địa điểm.',
    GeocodeFailureKind.routeMissing =>
      'Máy chủ không có dịch vụ tìm địa điểm (sai địa chỉ máy chủ hoặc phiên bản).',
    GeocodeFailureKind.notFound =>
      'Chưa tìm được tên địa điểm cho vị trí này. Bạn có thể nhập địa chỉ thủ công.',
    GeocodeFailureKind.rateLimited =>
      'Dịch vụ địa điểm đang giới hạn tần suất. Hãy chờ vài giây rồi thử lại.',
    GeocodeFailureKind.invalidCoordinate => 'Vị trí ghim không hợp lệ.',
    GeocodeFailureKind.server =>
      'Máy chủ lỗi khi lấy tên địa điểm. Hãy thử lại sau.',
    GeocodeFailureKind.badResponse =>
      'Máy chủ trả dữ liệu địa điểm không đọc được.',
  };

  /// Phân tích phản hồi HTTP (thuần, kiểm thử được). Chấp nhận camelCase lẫn PascalCase.
  factory GeocodeResult.fromHttp(int status, List<int> bodyBytes) {
    Object? decoded;
    try {
      decoded = bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (status == 200) {
      final map = decoded;
      if (map is Map) {
        String? s(String camel) {
          final v =
              map[camel] ?? map[camel[0].toUpperCase() + camel.substring(1)];
          final t = v?.toString().trim();
          return (t == null || t.isEmpty) ? null : t;
        }

        final name = s('displayName');
        if (name != null)
          return GeocodeResult.success(
            name,
            region: s('district') ?? s('city') ?? s('province') ?? '',
          );
      }
      return GeocodeResult.failed(
        GeocodeFailureKind.badResponse,
        statusCode: status,
      );
    }
    final backendMessage = decoded is Map && decoded['message'] is String
        ? decoded['message'] as String
        : null;
    final kind = switch (status) {
      400 => GeocodeFailureKind.invalidCoordinate,
      401 => GeocodeFailureKind.unauthorized,
      403 => GeocodeFailureKind.forbidden,
      // Backend trả 404 kèm { message, code } khi nhà cung cấp trả lời nhưng không có địa chỉ; 404 trần là sai route/host.
      404 =>
        backendMessage != null
            ? GeocodeFailureKind.notFound
            : GeocodeFailureKind.routeMissing,
      429 => GeocodeFailureKind.rateLimited,
      502 || 503 => GeocodeFailureKind.providerUnavailable,
      504 => GeocodeFailureKind.timeout,
      >= 500 => GeocodeFailureKind.server,
      _ => GeocodeFailureKind.badResponse,
    };
    return GeocodeResult.failed(
      kind,
      statusCode: status,
      serverMessage: backendMessage,
    );
  }
}
