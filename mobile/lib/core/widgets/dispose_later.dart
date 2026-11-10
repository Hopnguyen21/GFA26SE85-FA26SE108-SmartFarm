import 'package:flutter/widgets.dart';

/// Giải phóng controller của hộp thoại/bottom sheet sau khi hoạt ảnh đóng kết thúc
/// (showDialog hoàn tất ngay khi pop, trong lúc TextField vẫn còn đang chạy hiệu ứng thoát).
void disposeControllersLater(List<TextEditingController> controllers) {
  Future.delayed(const Duration(milliseconds: 600), () {
    for (final c in controllers) {
      c.dispose();
    }
  });
}
