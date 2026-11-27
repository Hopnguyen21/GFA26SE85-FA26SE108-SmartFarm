import 'package:flutter/painting.dart';

/// Bỏ mã kỹ thuật (GUID/UUID thiết bị) khỏi câu trả lời của AI, giống `cleanTechnicalIds` trên web.
String cleanTechnicalIds(String? text) {
  if (text == null || text.isEmpty) return '';
  const guid =
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';
  return text
      .replaceAll(
        RegExp(
          r'\s*\((?:Mã\s*(?:ID|thiết bị)?|ID|ActuatorId)?:?\s*' + guid + r'\)',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'(?:mã\s*(?:ID|thiết bị)?|ID\s*thiết\s*bị|thiết\s*bị\s*mã)?:?\s*' +
              guid,
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(guid), '')
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

/// Chuyển đổi cú pháp Markdown inline cơ bản (**in đậm**, `mã`) thành danh sách InlineSpan hiển thị đẹp.
List<InlineSpan> parseAiMarkdownSpans(String text, TextStyle baseStyle) {
  if (text.isEmpty) return const [];
  final spans = <InlineSpan>[];
  final regex = RegExp(r'(\*\*(.*?)\*\*)|(`(.*?)`)', dotAll: true);
  var lastIndex = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: baseStyle,
      ));
    }
    if (match.group(2) != null) {
      spans.add(TextSpan(
        text: match.group(2),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
    } else if (match.group(4) != null) {
      spans.add(TextSpan(
        text: match.group(4),
        style: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: const Color(0x1A000000),
        ),
      ));
    }
    lastIndex = match.end;
  }
  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: baseStyle,
    ));
  }
  return spans;
}

/// Nhãn trạng thái lệnh điều khiển sau khi Owner duyệt khuyến nghị (khớp `COMMAND_LABEL` trên web).
const Map<String, String> aiCommandLabels = {
  'Pending': 'Lệnh đang chờ gửi',
  'Sent': 'Đã gửi lệnh, chờ thiết bị xác nhận',
  'Acknowledged': 'Thiết bị đã xác nhận lệnh',
  'Failed': 'Gửi lệnh thất bại',
  'TimedOut': 'Thiết bị không xác nhận trước thời hạn',
  'Cancelled': 'Lệnh đã bị hủy',
};
