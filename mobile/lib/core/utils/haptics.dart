import 'package:flutter/services.dart';

/// Hỗ trợ phản hồi xúc giác (Haptic Feedback) trên thiết bị di động:
/// Giúp thao tác chạm, chọn đỉnh GIS, gạt switch, bấm nút, kéo làm mới
/// có cảm giác chân thực, tương tác mượt mà và trực quan.
class AppHaptics {
  AppHaptics._();

  /// Chạm nhẹ khi bấm nút thông thường, tab chuyển trang, chip lọc
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Cảm giác khấc (tick) khi chạm chọn đỉnh GIS, chọn item trong danh sách, gạt công tắc
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Rung xác nhận vừa (medium) khi hoàn thành thao tác thành công (lưu, tạo thửa, tạo zone)
  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Rung cảnh báo mạnh khi thao tác lỗi, vượt ranh giới GIS, chạm dừng khẩn cấp
  static Future<void> warning() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Rung cảnh báo lỗi nghiêm trọng
  static Future<void> error() async {
    try {
      await HapticFeedback.vibrate();
    } catch (_) {}
  }
}
