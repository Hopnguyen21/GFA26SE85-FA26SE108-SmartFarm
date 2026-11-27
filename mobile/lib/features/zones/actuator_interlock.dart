import '../../core/models/models.dart';

/// Khóa an toàn công suất BR-INTERLOCK-01 (giống web `ActuatorControlGrid`): không bật đồng thời 2 bơm công suất lớn
/// trong cùng hệ thống. Trả về câu cảnh báo khi vi phạm, hoặc null nếu được phép.
String? actuatorInterlockError(
  ActuatorModel target,
  bool turnOn,
  Iterable<ActuatorModel> actuators,
) {
  if (!turnOn || target.actuatorType != 'PUMP') return null;
  final other = actuators
      .where(
        (a) =>
            a.actuatorId != target.actuatorId &&
            a.actuatorType == 'PUMP' &&
            a.isRunning,
      )
      .firstOrNull;
  if (other == null) return null;
  return 'Khóa an toàn công suất: Không kích hoạt đồng thời 2 bơm công suất lớn trong cùng hệ thống. '
      'Bơm [${other.name}] đang hoạt động!';
}

/// Thời gian tự ngắt (failsafe) cho phép: 1–30 phút, mặc định 15 như web.
const int kFailsafeMinMinutes = 1;
const int kFailsafeMaxMinutes = 30;
const int kFailsafeDefaultMinutes = 15;
