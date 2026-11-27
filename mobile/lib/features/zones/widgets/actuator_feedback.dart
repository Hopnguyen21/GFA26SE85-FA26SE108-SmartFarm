import 'package:flutter/material.dart';
import '../../../core/providers/farm_provider.dart';
import 'actuator_command_dialog.dart';

/// Bật/tắt thiết bị chấp hành như web: hỏi xác nhận (khóa interlock bơm, hẹn giờ tự ngắt 1–30 phút),
/// gửi lệnh rồi báo kết quả thật — "đã ACK" hay "đã gửi, chờ gateway" — hoặc lý do bị từ chối.
/// Trả về true khi backend nhận lệnh; false khi hủy hoặc bị từ chối.
Future<bool> toggleActuatorWithFeedback(
  BuildContext context,
  FarmProvider provider,
  String actuatorId, {
  int? durationMinutes,
  bool confirm = true,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final act = provider.actuators
      .where((a) => a.actuatorId == actuatorId)
      .firstOrNull;
  var minutes = durationMinutes;
  if (confirm && act != null) {
    final turnOn = !act.isRunning;
    final picked = await showActuatorCommandDialog(
      context,
      actuator: act,
      turnOn: turnOn,
      zoneActuators: provider.actuators.where((a) => a.zoneId == act.zoneId),
    );
    if (picked == null) return false; // Hủy bỏ
    if (turnOn) minutes = picked;
  }
  final error = await provider.toggleActuator(
    actuatorId,
    durationMinutes: minutes,
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
  messenger.showSnackBar(
    SnackBar(
      content: Text(provider.lastActuatorNotice ?? 'Đã gửi lệnh điều khiển.'),
      backgroundColor: const Color(0xFF047857),
    ),
  );
  return true;
}
