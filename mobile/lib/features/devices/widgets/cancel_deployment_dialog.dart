import 'package:flutter/material.dart';
import '../../../core/widgets/state_views.dart';

/// Hỏi chủ trại lý do hủy yêu cầu triển khai (không bắt buộc). Trả về null nếu chủ trại bấm "Giữ lại",
/// còn lại là lý do đã cắt khoảng trắng (có thể rỗng).
Future<String?> askCancelDeploymentReason(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _CancelReasonDialog(),
    );

/// Hộp thoại tự giữ và tự hủy controller: hủy sau khi hiệu ứng đóng kết thúc, tránh dùng controller đã hủy.
class _CancelReasonDialog extends StatefulWidget {
  const _CancelReasonDialog();

  @override
  State<_CancelReasonDialog> createState() => _CancelReasonDialogState();
}

class _CancelReasonDialogState extends State<_CancelReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hủy yêu cầu triển khai?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yêu cầu sẽ dừng lại và Zone được gửi yêu cầu mới. '
              'Chỉ hủy được khi chưa ký hợp đồng và chưa bắt đầu lắp đặt.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Giữ lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Hủy yêu cầu'),
        ),
      ],
    );
  }
}

/// Câu báo lỗi dễ hiểu cho các lỗi 409 của backend khi hủy; lỗi khác giữ nguyên chữ của máy chủ.
String cancelDeploymentErrorText(Object error) {
  final m = friendlyError(error);
  final l = m.toLowerCase();
  if (l.contains('contract is already signed') ||
      l.contains('deposit is paid')) {
    return 'Hợp đồng đã được ký hoặc đã đóng cọc nên không tự hủy được. Hãy liên hệ quản trị nền tảng.';
  }
  if (l.contains('before installation starts')) {
    return 'Yêu cầu đã bắt đầu lắp đặt hoặc đã kết thúc nên không hủy được.';
  }
  return m;
}
