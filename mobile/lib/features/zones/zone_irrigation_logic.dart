import '../../core/models/models.dart';
import '../../core/utils/cron_utils.dart';

// Logic thuần cho phần lịch tưới của Zone. Dữ liệu lịch có HAI nơi trong backend:
//  - Lịch MẪU thuộc CÂY (Crop.CalendarIrrigationPlan): chung cho cây, chỉ đọc ở mobile.
//  - Lịch ĐANG ÁP DỤNG của Zone (ControlSchedule): cron hằng ngày + thời lượng (1–1800 giây) + hoãn khi mưa + bật/tắt,
//    gắn với một thiết bị chấp hành. "Đồng bộ" sinh các ControlSchedule này từ lịch mẫu của cây.

/// Kiểm tra khi sửa một lịch của Zone. Trả `(error, seconds, cron)`; error != null thì không gửi.
({String? error, int seconds, String cron}) validateScheduleEdit({
  required String time,
  required String minutesText,
  required String rainThresholdText,
}) {
  final cron = buildDailyCron(time);
  if (cron == null)
    return (
      error: 'Giờ phải có dạng HH:mm (00:00–23:59).',
      seconds: 0,
      cron: '',
    );
  final minutes = double.tryParse(minutesText.trim().replaceAll(',', '.'));
  if (minutes == null || minutes <= 0)
    return (
      error: 'Nhập thời lượng tưới (phút) lớn hơn 0.',
      seconds: 0,
      cron: cron,
    );
  final seconds = (minutes * 60).round();
  if (seconds > 1800)
    return (
      error: 'Mỗi lần tưới tối đa 30 phút (giới hạn phần cứng).',
      seconds: 0,
      cron: cron,
    );
  final rain = double.tryParse(rainThresholdText.trim().replaceAll(',', '.'));
  if (rain == null || rain < 0 || rain > 100) {
    return (
      error: 'Ngưỡng hoãn khi mưa phải từ 0 đến 100%.',
      seconds: seconds,
      cron: cron,
    );
  }
  return (error: null, seconds: seconds, cron: cron);
}

bool _isIrrigationActuator(ActuatorModel a) {
  final t = a.actuatorType.toLowerCase();
  return t.contains('pump') ||
      t.contains('valve') ||
      t.contains('water') ||
      t.contains('irrigation');
}

/// Thiết bị có thể dùng để đồng bộ lịch tưới: bơm/van/tưới. Không tự chọn thiết bị khác (quạt, đèn...).
List<ActuatorModel> irrigationActuators(List<ActuatorModel> all) =>
    all.where(_isIrrigationActuator).toList();

enum SyncProblemKind {
  noActuator,
  wrongZoneActuator,
  noPlan,
  unsupportedRepeat,
  durationTooLong,
  noGrowthProfile,
  forbidden,
  other,
}

/// Phân loại lỗi đồng bộ theo thông điệp THẬT của backend để hiện gợi ý đúng; thông điệp gốc luôn được giữ nguyên.
({SyncProblemKind kind, String message, String hint}) classifySyncError(
  String backendMessage,
) {
  final m = backendMessage.toLowerCase();
  if (m.contains('chưa gắn hồ sơ')) {
    return (
      kind: SyncProblemKind.noGrowthProfile,
      message: backendMessage,
      hint: 'Hãy gắn một hồ sơ canh tác cho Zone trước khi đồng bộ lịch tưới.',
    );
  }
  if (m.contains('không thuộc khu vực')) {
    return (
      kind: SyncProblemKind.wrongZoneActuator,
      message: backendMessage,
      hint: 'Chỉ đồng bộ được vào bơm/van đã gán cho chính Zone này.',
    );
  }
  if (m.contains('chưa có thiết bị van') || m.contains('actuator')) {
    return (
      kind: SyncProblemKind.noActuator,
      message: backendMessage,
      hint:
          'Zone cần có bơm hoặc van tưới (do kỹ thuật viên lắp và gán vào Zone) trước khi đồng bộ.',
    );
  }
  if (m.contains('chưa có lịch tưới mẫu') ||
      m.contains('chưa có ca tưới') ||
      m.contains('không đọc được')) {
    return (
      kind: SyncProblemKind.noPlan,
      message: backendMessage,
      hint:
          'Cây này chưa có lịch tưới mẫu hợp lệ trong thư viện nên không có gì để đồng bộ.',
    );
  }
  if (m.contains('lặp kiểu')) {
    return (
      kind: SyncProblemKind.unsupportedRepeat,
      message: backendMessage,
      hint: 'Hệ thống điều khiển chỉ hỗ trợ lịch lặp hằng ngày.',
    );
  }
  if (m.contains('phút') && (m.contains('dài') || m.contains('tối đa'))) {
    return (
      kind: SyncProblemKind.durationTooLong,
      message: backendMessage,
      hint:
          'Mỗi ca tưới tối đa 30 phút; cần rút ngắn ca trong lịch mẫu của cây.',
    );
  }
  if (m.contains('hồ sơ sinh trưởng')) {
    return (
      kind: SyncProblemKind.noGrowthProfile,
      message: backendMessage,
      hint: 'Cây chưa có hồ sơ canh tác; hãy áp dụng hồ sơ cho Zone trước.',
    );
  }
  if (m.contains('không có quyền') || m.contains('forbidden')) {
    return (
      kind: SyncProblemKind.forbidden,
      message: backendMessage,
      hint: 'Chỉ chủ trang trại của Zone này mới đồng bộ được lịch tưới.',
    );
  }
  return (kind: SyncProblemKind.other, message: backendMessage, hint: '');
}

/// Mô tả một ControlSchedule bằng dữ liệu thật: giờ (từ cron), thời lượng, hoãn khi mưa.
String describeSchedule(ScheduleModel s) {
  final time = cronToHhmm(s.cronExpression);
  final when = time == null
      ? 'cron "${s.cronExpression}" (không phải lịch hằng ngày)'
      : 'hằng ngày lúc $time';
  final mins = s.durationSeconds % 60 == 0
      ? '${s.durationSeconds ~/ 60}'
      : (s.durationSeconds / 60).toStringAsFixed(1);
  final rain = s.enableRainDelay
      ? ' · hoãn khi mưa ≥ ${s.rainThresholdPercent.toStringAsFixed(0)}%'
      : '';
  return '$when · $mins phút$rain';
}
