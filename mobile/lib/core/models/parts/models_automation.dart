part of '../models.dart';

// ─────────────────────────────────────────
// Schedule Model
// ─────────────────────────────────────────
class ScheduleModel {
  final String scheduleId;
  final String zoneId;
  final String actuatorId;
  final String name;
  final String zoneName;
  final String actuatorName;
  final bool isEnabled;
  bool isActive;
  final String startTime;
  final int durationMinutes;
  final int durationSeconds;
  final List<String> daysOfWeek;
  final String? nextRunFormatted;
  final String cronExpression;
  final bool enableRainDelay;
  final double rainThresholdPercent;

  ScheduleModel({
    required this.scheduleId,
    this.zoneId = '',
    this.actuatorId = '',
    required this.name,
    required this.zoneName,
    required this.actuatorName,
    this.isEnabled = true,
    this.isActive = true,
    this.startTime = '06:30',
    this.durationMinutes = 15,
    this.durationSeconds = 900,
    this.daysOfWeek = const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
    this.nextRunFormatted,
    this.cronExpression = '',
    this.enableRainDelay = true,
    this.rainThresholdPercent = 70.0,
  });

  factory ScheduleModel.fromJson(
    Map<String, dynamic> json, {
    String defaultZoneName = 'Nhà màng',
  }) {
    final nextRun = json['nextRunAtUtc']?.toString();
    String? formattedNext;
    if (nextRun != null && nextRun.length >= 16) {
      try {
        final dt = DateTime.parse(nextRun).toLocal();
        final h = dt.hour.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        final mo = dt.month.toString().padLeft(2, '0');
        formattedNext = '$h:$m ngày $d/$mo/${dt.year}';
      } catch (_) {
        formattedNext = nextRun.substring(0, 16).replaceAll('T', ' ');
      }
    }

    final durSec = (json['durationSeconds'] as num?)?.toInt() ?? 900;
    final durMin = durSec ~/ 60;
    final enabled =
        json['isEnabled'] as bool? ?? json['isActive'] as bool? ?? true;
    final zId = json['zoneId']?.toString() ?? '';
    final aId = json['actuatorId']?.toString() ?? '';
    final rainDelay = json['enableRainDelay'] as bool? ?? true;
    final rainThreshold =
        (json['rainThresholdPercent'] as num?)?.toDouble() ?? 70.0;

    return ScheduleModel(
      scheduleId: json['scheduleId']?.toString() ?? '',
      zoneId: zId,
      actuatorId: aId,
      name: json['name']?.toString() ?? 'Lịch tưới định kỳ',
      zoneName:
          json['zoneName']?.toString() ??
          (zId.isNotEmpty ? zId : defaultZoneName),
      actuatorName:
          json['actuatorName']?.toString() ??
          (aId.isNotEmpty ? aId : 'Bơm tưới nhỏ giọt'),
      isEnabled: enabled,
      isActive: enabled,
      // Giờ đọc từ cron hằng ngày của backend; cron khác dạng thì hiện chính chuỗi cron, không bịa giờ.
      startTime:
          cronToHhmm(json['cronExpression']?.toString() ?? '') ??
          (json['cronExpression']?.toString() ?? '—'),
      durationMinutes: durMin > 0 ? durMin : 15,
      durationSeconds: durSec,
      daysOfWeek: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      nextRunFormatted: formattedNext,
      cronExpression: json['cronExpression']?.toString() ?? '',
      enableRainDelay: rainDelay,
      rainThresholdPercent: rainThreshold,
    );
  }
}

class AutomationRuleModel {
  final String ruleId;
  final String name;
  final String zoneName;
  final String parameterCode; // SOIL_MOISTURE, AIR_TEMP, AIR_HUMIDITY
  final String operator; // <, >, <=, >=
  final double thresholdValue;
  final String actuatorName;
  final String actionType; // ON, OFF
  final int actionDurationMinutes;
  bool isActive;

  /// Dữ liệu gốc của API, cần để gửi lại khi cập nhật rule.
  final String? zoneId;
  final Map<String, dynamic>? raw;

  AutomationRuleModel({
    required this.ruleId,
    required this.name,
    required this.zoneName,
    required this.parameterCode,
    required this.operator,
    required this.thresholdValue,
    required this.actuatorName,
    required this.actionType,
    required this.actionDurationMinutes,
    this.isActive = true,
    this.zoneId,
    this.raw,
  });

  factory AutomationRuleModel.fromJson(
    Map<String, dynamic> json, {
    String? actuatorName,
    String defaultZoneName = 'Nhà màng',
  }) {
    return AutomationRuleModel(
      ruleId: json['ruleId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Luật tự động hóa',
      zoneName: defaultZoneName,
      parameterCode: switch (json['parameterCode']?.toString()) {
        'SoilMoisture' => 'Độ ẩm đất',
        'Temperature' => 'Nhiệt độ',
        'AirHumidity' => 'Độ ẩm không khí',
        'LightIntensity' => 'Ánh sáng',
        'Ph' => 'pH',
        'Ec' => 'EC',
        final other => other ?? '',
      },
      operator: switch (json['operator']?.toString()) {
        'LessThan' => '<',
        'LessThanOrEqual' => '<=',
        'GreaterThan' => '>',
        'GreaterThanOrEqual' => '>=',
        final other => other ?? '',
      },
      thresholdValue: (json['threshold'] as num?)?.toDouble() ?? 0,
      actuatorName: actuatorName ?? 'Thiết bị chấp hành',
      actionType: json['action']?.toString() == 'TurnOff'
          ? 'TẮT (OFF)'
          : 'BẬT (ON)',
      actionDurationMinutes:
          ((json['durationSeconds'] as num?)?.toInt() ?? 0) ~/ 60,
      isActive: json['isActive'] == true,
      zoneId: json['zoneId']?.toString(),
      raw: json,
    );
  }
}
