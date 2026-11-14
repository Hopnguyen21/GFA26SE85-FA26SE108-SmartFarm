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

/// Nhãn trạng thái lệnh điều khiển sau khi Owner duyệt khuyến nghị (khớp `COMMAND_LABEL` trên web).
const Map<String, String> aiCommandLabels = {
  'Pending': 'Lệnh đang chờ gửi',
  'Sent': 'Đã gửi lệnh, chờ thiết bị xác nhận',
  'Acknowledged': 'Thiết bị đã xác nhận lệnh',
  'Failed': 'Gửi lệnh thất bại',
  'TimedOut': 'Thiết bị không xác nhận trước thời hạn',
  'Cancelled': 'Lệnh đã bị hủy',
};
