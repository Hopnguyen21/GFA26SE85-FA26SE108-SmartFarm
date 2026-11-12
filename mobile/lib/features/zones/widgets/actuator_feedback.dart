import 'package:flutter/material.dart';
import '../../../core/providers/farm_provider.dart';

/// Bật/tắt thiết bị chấp hành và báo kết quả thật cho người dùng.
/// Trả về true khi backend xác nhận lệnh; ngược lại hiện lý do bị từ chối.
Future<bool> toggleActuatorWithFeedback(
  BuildContext context,
  FarmProvider provider,
  String actuatorId, {
  int? durationMinutes,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final error = await provider.toggleActuator(
    actuatorId,
    durationMinutes: durationMinutes,
  );
  if (error != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Lệnh điều khiển thất bại: $error'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
    return false;
  }
  return true;
}
