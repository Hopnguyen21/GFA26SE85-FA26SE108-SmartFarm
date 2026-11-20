part of '../models.dart';

/// Nhãn thông số môi trường cho câu cảnh báo.
String _alertParamLabel(String code) =>
    const {
      'soilmoisture': 'Độ ẩm đất',
      'temperature': 'Nhiệt độ',
      'airhumidity': 'Độ ẩm không khí',
      'lightintensity': 'Ánh sáng',
      'ph': 'pH',
      'ec': 'EC',
      'co2': 'CO₂',
    }[code.toLowerCase()] ??
    '';

/// Số gọn: bỏ phần thập phân thừa ("65.1000" → "65,1", "70.0000" → "70").
String _alertNum(Object? v) {
  final d = v is num ? v.toDouble() : double.tryParse('$v');
  if (d == null) return '$v';
  final s = d.toStringAsFixed(1);
  return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll(
    '.',
    ',',
  );
}

/// Chuẩn hóa số trong chuỗi thông báo cảnh báo: loại bỏ các số 0 thừa (vd: "70.000" -> "70", "80.000" -> "80", "65.100" -> "65.1", "70.00" -> "70").
String cleanTrailingZeros(String text) {
  if (text.isEmpty) return text;
  return text
      .replaceAllMapped(RegExp(r'(\d+)[.,]000(?!\d)'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'(\d+)[.,]00(?!\d)'), (m) => m[1]!)
      .replaceAllMapped(RegExp(r'(\d+)\.(\d*?)0+(?!\d)'), (m) => m[2]!.isEmpty ? m[1]! : '${m[1]}.${m[2]}')
      .replaceAllMapped(RegExp(r'(\d+),(\d*?)0+(?!\d)'), (m) => m[2]!.isEmpty ? m[1]! : '${m[1]},${m[2]}');
}

/// Câu cảnh báo khi backend không gửi `message`: nêu THÔNG SỐ, giá trị đo và ngưỡng (trước đây chỉ có "Giá trị đo được: 65.1 %"
/// nên không biết đó là độ ẩm hay nhiệt độ).
String _thresholdMessage(Map<String, dynamic> json) {
  final label = _alertParamLabel(json['parameterCode']?.toString() ?? '');
  final unit = json['unit']?.toString() ?? '';
  final obs = json['observedValue'];
  final lo = json['minThreshold'];
  final hi = json['maxThreshold'];
  final u = unit.isEmpty ? '' : ' $unit';
  final range = (lo != null && hi != null)
      ? ' (ngưỡng ${_alertNum(lo)}–${_alertNum(hi)}$u)'
      : ' (ngoài ngưỡng tối ưu)';
  final value = obs == null ? '' : '${_alertNum(obs)}$u';
  return '${label.isEmpty ? 'Giá trị đo được' : label}: $value$range'
      .replaceAll(': (', ' (');
}

class AlertModel {
  final String alertId;
  final String title;
  final String message;
  final String severity; // CRITICAL, WARNING, INFO
  final String
  category; // THRESHOLD_VIOLATION, BOUNDARY_VIOLATION, HARDWARE_FAULT, OFFLINE
  final String time;
  bool isAcknowledged;
  final String zoneId;
  final String zoneName;

  /// Thời điểm phát sinh (UTC) để sắp xếp mới nhất trước.
  final DateTime? createdAtUtc;

  AlertModel({
    required this.alertId,
    required this.title,
    required this.message,
    required this.severity,
    this.category = 'THRESHOLD_VIOLATION',
    required this.time,
    this.isAcknowledged = false,
    this.zoneId = '',
    this.zoneName = '',
    this.createdAtUtc,
  });

  bool get isBoundaryViolation =>
      category == 'BOUNDARY_VIOLATION' || title.contains('RANH GIỚI');

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    final severityRaw = json['severity']?.toString().toUpperCase() ?? 'WARNING';
    String sev = 'WARNING';
    if (severityRaw.contains('CRITICAL')) {
      sev = 'CRITICAL';
    } else if (severityRaw.contains('INFO')) {
      sev = 'INFO';
    }

    final createdAt = json['createdAtUtc']?.toString();
    String formattedTime = 'Hôm nay';
    if (createdAt != null && createdAt.length >= 16) {
      formattedTime = createdAt.substring(11, 16);
    }

    final param = json['parameterCode']?.toString() ?? '';
    final category =
        json['alertCategory']?.toString() ??
        (param == 'BOUNDARY' ? 'BOUNDARY_VIOLATION' : 'THRESHOLD_VIOLATION');
    final title =
        json['title']?.toString() ??
        (category == 'BOUNDARY_VIOLATION'
            ? 'Cảnh báo ranh giới thiết bị'
            : 'Cảnh báo vi khí hậu $param');
    final message = cleanTrailingZeros(
      json['message']?.toString() ?? _thresholdMessage(json),
    );

    return AlertModel(
      alertId: json['alertId']?.toString() ?? '',
      title: title,
      message: message,
      severity: sev,
      category: category,
      time: formattedTime,
      isAcknowledged:
          json['acknowledgedAtUtc'] != null ||
          json['status']?.toString() == 'Acknowledged',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? '',
      createdAtUtc: parseTime(createdAt),
    );
  }
}

class TaskAssignmentModel {
  final String farmerId;
  final String farmerName;
  final String status;
  final int progressPercent;
  final String? progressNote;
  final String? result;
  final String? failureReason;

  const TaskAssignmentModel({
    required this.farmerId,
    required this.farmerName,
    required this.status,
    this.progressPercent = 0,
    this.progressNote,
    this.result,
    this.failureReason,
  });

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json) =>
      TaskAssignmentModel(
        farmerId: json['farmerId']?.toString() ?? '',
        farmerName: json['farmerName']?.toString() ?? 'Nhân công',
        status: json['status']?.toString() ?? '',
        progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
        progressNote: json['progressNote']?.toString(),
        result: json['result']?.toString(),
        failureReason: json['failureReason']?.toString(),
      );
}

class TaskModel {
  final String taskId;
  final String title;
  final String zoneName;
  final String priority;
  final String dueDate;
  final String? assignedFarmerName;
  final String? assignedFarmerId;
  final String? description;
  final String? requirements;
  bool isCompleted;
  final String status;
  final String? zoneId;
  final List<TaskAssignmentModel> assignments;

  /// Hạn chót và ngày tạo gốc (UTC) để tính nhãn "Quá hạn / Hôm nay / Còn N ngày" như web.
  final DateTime? dueAtUtc;
  final DateTime? createdAtUtc;

  TaskModel({
    required this.taskId,
    required this.title,
    required this.zoneName,
    required this.priority,
    required this.dueDate,
    this.assignedFarmerName,
    this.assignedFarmerId,
    this.description,
    this.requirements,
    this.isCompleted = false,
    this.status = '',
    this.zoneId,
    this.assignments = const [],
    this.dueAtUtc,
    this.createdAtUtc,
  });

  factory TaskModel.fromJson(
    Map<String, dynamic> json, {
    String defaultZoneName = 'Khu vực canh tác',
  }) {
    final status = json['status']?.toString() ?? '';
    final assignments = [
      for (final a in (json['assignments'] as List<dynamic>? ?? const []))
        TaskAssignmentModel.fromJson(Map<String, dynamic>.from(a as Map)),
    ];
    final isDone = status == 'Approved' || status == 'CompletedPendingReview';
    final due = json['dueAtUtc']?.toString();
    String dueStr = 'Chưa đặt hạn';
    final dueAt = due == null ? null : DateTime.tryParse(due)?.toLocal();
    if (dueAt != null) {
      String two(int v) => v.toString().padLeft(2, '0');
      dueStr =
          '${two(dueAt.day)}/${two(dueAt.month)}/${dueAt.year} ${two(dueAt.hour)}:${two(dueAt.minute)}';
    }

    return TaskModel(
      taskId: json['id']?.toString() ?? json['taskId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Công việc chăm sóc đồng ruộng',
      zoneName: json['zoneName']?.toString() ?? defaultZoneName,
      priority: json['priority']?.toString() ?? 'Trung bình',
      dueDate: dueStr,
      assignedFarmerName: assignments.isNotEmpty
          ? assignments.map((a) => a.farmerName).join(', ')
          : json['assignedFarmerName']?.toString(),
      assignedFarmerId: assignments.isNotEmpty
          ? assignments.first.farmerId
          : json['assignedFarmerId']?.toString(),
      status: status,
      zoneId: json['zoneId']?.toString(),
      assignments: assignments,
      description: json['description']?.toString(),
      requirements: json['requirements']?.toString(),
      isCompleted: isDone,
      dueAtUtc: due == null ? null : DateTime.tryParse(due),
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? ''),
    );
  }
}

class AppNotificationModel {
  final String notificationId;
  final String title;
  final String message;
  final String type; // System, Alert, Task, IoT, Inventory, Advice
  final String severity; // Info, Warning, Critical
  final bool isRead;
  final String? targetUrl;
  final String? referenceId;
  final String createdAt;

  const AppNotificationModel({
    required this.notificationId,
    required this.title,
    required this.message,
    this.type = 'System',
    this.severity = 'Info',
    this.isRead = false,
    this.targetUrl,
    this.referenceId,
    required this.createdAt,
  });

  AppNotificationModel copyWith({bool? isRead}) {
    return AppNotificationModel(
      notificationId: notificationId,
      title: title,
      message: message,
      type: type,
      severity: severity,
      isRead: isRead ?? this.isRead,
      targetUrl: targetUrl,
      referenceId: referenceId,
      createdAt: createdAt,
    );
  }

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      notificationId: json['notificationId']?.toString() ?? '',
      title: cleanTrailingZeros(json['title']?.toString() ?? 'Thông báo hệ thống'),
      message: cleanTrailingZeros(json['message']?.toString() ?? ''),
      type: json['type']?.toString() ?? 'System',
      severity: json['severity']?.toString() ?? 'Info',
      isRead: json['isRead'] == true,
      targetUrl: json['targetUrl']?.toString(),
      referenceId: json['referenceId']?.toString(),
      createdAt: json['createdAtUtc']?.toString() ?? 'Vừa xong',
    );
  }
}
