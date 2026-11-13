part of '../models.dart';

class AlertModel {
  final String alertId;
  final String title;
  final String message;
  final String severity; // CRITICAL, WARNING, INFO
  final String
  category; // THRESHOLD_VIOLATION, BOUNDARY_VIOLATION, HARDWARE_FAULT, OFFLINE
  final String time;
  bool isAcknowledged;

  AlertModel({
    required this.alertId,
    required this.title,
    required this.message,
    required this.severity,
    this.category = 'THRESHOLD_VIOLATION',
    required this.time,
    this.isAcknowledged = false,
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
    final obs = json['observedValue']?.toString() ?? '';
    final unit = json['unit']?.toString() ?? '';
    final category =
        json['alertCategory']?.toString() ??
        (param == 'BOUNDARY' ? 'BOUNDARY_VIOLATION' : 'THRESHOLD_VIOLATION');
    final title =
        json['title']?.toString() ??
        (category == 'BOUNDARY_VIOLATION'
            ? 'Cảnh báo ranh giới thiết bị'
            : 'Cảnh báo vi khí hậu $param');
    final message =
        json['message']?.toString() ??
        'Giá trị đo được: $obs $unit (ngoài ngưỡng tối ưu)';

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
    );
  }
}

class TaskAssignmentModel {
  final String farmerId;
  final String farmerName;
  final String status;
  final int progressPercent;
  final String? result;

  const TaskAssignmentModel({
    required this.farmerId,
    required this.farmerName,
    required this.status,
    this.progressPercent = 0,
    this.result,
  });

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json) =>
      TaskAssignmentModel(
        farmerId: json['farmerId']?.toString() ?? '',
        farmerName: json['farmerName']?.toString() ?? 'Nhân công',
        status: json['status']?.toString() ?? '',
        progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
        result: json['result']?.toString(),
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
  bool isCompleted;
  final String status;
  final String? zoneId;
  final List<TaskAssignmentModel> assignments;

  TaskModel({
    required this.taskId,
    required this.title,
    required this.zoneName,
    required this.priority,
    required this.dueDate,
    this.assignedFarmerName,
    this.assignedFarmerId,
    this.description,
    this.isCompleted = false,
    this.status = '',
    this.zoneId,
    this.assignments = const [],
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
      isCompleted: isDone,
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
      title: json['title']?.toString() ?? 'Thông báo hệ thống',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'System',
      severity: json['severity']?.toString() ?? 'Info',
      isRead: json['isRead'] == true,
      targetUrl: json['targetUrl']?.toString(),
      referenceId: json['referenceId']?.toString(),
      createdAt: json['createdAtUtc']?.toString() ?? 'Vừa xong',
    );
  }
}
