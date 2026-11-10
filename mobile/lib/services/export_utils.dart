import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ô CSV: bọc nháy kép, nhân đôi nháy, và chặn CSV/Formula injection (=, +, -, @ ở đầu chuỗi chữ).
String csvCell(Object? value) {
  var text = value == null ? '' : '$value';
  if (value is String && text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
    text = '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

String buildCsv(List<String> header, List<List<Object?>> rows) {
  final b = StringBuffer('﻿'); // BOM để Excel đọc đúng UTF-8
  b.writeln(header.map(csvCell).join(','));
  for (final r in rows) {
    b.writeln(r.map(csvCell).join(','));
  }
  return b.toString();
}

/// CSV lịch sử cảm biến từ các điểm đã tải (giữ nguyên zone, chỉ số, khoảng thời gian đã chọn).
String buildTelemetryCsv({
  required String zoneName,
  required String metric,
  required String range,
  required List<Map<String, dynamic>> points,
}) {
  return buildCsv(
    ['Zone', 'Chỉ số', 'Khoảng thời gian', 'Bắt đầu (UTC)', 'Trung bình', 'Nhỏ nhất', 'Lớn nhất', 'Số mẫu'],
    [
      for (final p in points)
        [
          zoneName,
          metric,
          range,
          p['bucketStartUtc'],
          p['average'],
          p['min'] ?? p['minimum'],
          p['max'] ?? p['maximum'],
          p['count'] ?? p['sampleCount'],
        ],
    ],
  );
}

/// Tên tệp an toàn (không chứa ký tự đường dẫn).
String safeFileName(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

/// Ghi tệp vào thư mục tạm của ứng dụng rồi mở hộp thoại chia sẻ/lưu của hệ điều hành.
/// Ném Exception có thông điệp rõ ràng khi thất bại.
Future<void> saveAndShareFile(String fileName, List<int> bytes, {String? mimeType}) async {
  if (bytes.isEmpty) throw Exception('Tệp rỗng, không có dữ liệu để xuất.');
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}${safeFileName(fileName)}');
    await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mimeType)], subject: fileName));
  } on FileSystemException catch (e) {
    throw Exception('Không thể ghi tệp: ${e.message}');
  }
}

/// Chuẩn hoá số điện thoại VN/quốc tế: chỉ giữ chữ số và '+' đầu; 8–15 chữ số. Trả null nếu không hợp lệ.
String? normalizePhone(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) return null;
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// URI tel:/sms: đã mã hoá an toàn. Trả null nếu số không hợp lệ.
Uri? buildPhoneUri(String scheme, String? rawPhone) {
  if (scheme != 'tel' && scheme != 'sms') return null;
  final phone = normalizePhone(rawPhone);
  if (phone == null) return null;
  return Uri(scheme: scheme, path: phone);
}

/// Mở ứng dụng Điện thoại/Tin nhắn; người dùng tự xác nhận gọi/gửi trong ứng dụng đó. Trả false nếu không mở được.
Future<bool> launchPhoneAction(String scheme, String? rawPhone) async {
  final uri = buildPhoneUri(scheme, rawPhone);
  if (uri == null) return false;
  try {
    if (!await canLaunchUrl(uri)) return false;
    return await launchUrl(uri);
  } catch (_) {
    return false;
  }
}

/// Quy tắc mật khẩu phía giao diện (backend vẫn là nơi xác thực cuối cùng). Trả null nếu hợp lệ.
String? validateNewPassword(String value) {
  if (value.length < 8) return 'Mật khẩu mới phải có tối thiểu 8 ký tự.';
  if (!RegExp(r'[A-Za-z]').hasMatch(value) || !RegExp(r'\d').hasMatch(value)) {
    return 'Mật khẩu mới cần có cả chữ và số.';
  }
  return null;
}
