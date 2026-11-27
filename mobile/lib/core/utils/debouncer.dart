import 'dart:async';
import 'package:flutter/foundation.dart';

/// Tiện ích trì hoãn thực thi (Debounce) cho các trường tìm kiếm và sự kiện người dùng gõ phím.
/// Ngăn chặn việc gọi API hoặc tính toán lọc danh sách liên tục ở mỗi ký tự gõ.
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 300});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  bool get isRunning => _timer?.isActive ?? false;
}
