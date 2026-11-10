// ─────────────────────────────────────────
// Domain Models – SmartFarm Mobile
// ─────────────────────────────────────────
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class FarmModel {
  final String farmId;
  final String name;
  final String address;
  final String province;
  final String district;
  final String ward;
  final String addressDetail;
  final String legacyLocationName;
  final double totalAreaM2;
  final double latitude;
  final double longitude;

  FarmModel({
    required this.farmId,
    required this.name,
    required this.address,
    this.province = 'Lâm Đồng',
    this.district = 'TP. Đà Lạt',
    this.ward = 'Phường 12',
    this.addressDetail = '',
    this.legacyLocationName = '',
    required this.totalAreaM2,
    this.latitude = 11.9404,
    this.longitude = 108.4583,
  });

  String get formattedArea {
    final ha = totalAreaM2 / 10000.0;
    return '${totalAreaM2.toStringAsFixed(0)} m² (${ha.toStringAsFixed(2)} ha)';
  }

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    return FarmModel(
      farmId: json['farmId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nông trại',
      address: json['locationText']?.toString() ?? json['address']?.toString() ?? 'Lâm Đồng, Việt Nam',
      province: json['province']?.toString() ?? 'Lâm Đồng',
      district: json['district']?.toString() ?? 'TP. Đà Lạt',
      ward: json['ward']?.toString() ?? 'Phường 12',
      addressDetail: json['addressDetail']?.toString() ?? '',
      legacyLocationName: json['legacyLocationName']?.toString() ?? '',
      totalAreaM2: (json['totalAreaM2'] as num?)?.toDouble() ?? 10000.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 11.9404,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 108.4583,
    );
  }
}

class ZoneAccessItem {
  final String zoneId;
  final bool canControl;
  const ZoneAccessItem({required this.zoneId, required this.canControl});
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

  factory TaskAssignmentModel.fromJson(Map<String, dynamic> json) => TaskAssignmentModel(
    farmerId: json['farmerId']?.toString() ?? '',
    farmerName: json['farmerName']?.toString() ?? 'Nhân công',
    status: json['status']?.toString() ?? '',
    progressPercent: (json['progressPercent'] as num?)?.toInt() ?? 0,
    result: json['result']?.toString(),
  );
}

class FarmerModel {
  final String farmerId;
  final String name;
  final String role; // Nông dân Thực địa (CF2), Kỹ thuật viên IoT (CF1), Quản lý vườn
  final String phone;
  final String email;
  final String username;
  final String password;
  final String? avatar;
  final String? farmId; // Gắn với nông trại của owner
  final bool isActive;
  final String joinedDate;
  final List<String> assignedZoneNames;
  final List<ZoneAccessItem> zoneAccess;
  final List<String> permissions; // CAN_CONTROL_PUMP, CAN_LOG_DIARY, CAN_VIEW_REPORTS, CAN_CONFIG_SCHEDULE, CAN_MANAGE_HARDWARE

  FarmerModel({
    required this.farmerId,
    required this.name,
    required this.role,
    required this.phone,
    this.email = '',
    this.username = '',
    this.password = 'Farmer@12345',
    this.avatar,
    this.farmId,
    this.isActive = true,
    this.joinedDate = '01/2026',
    this.assignedZoneNames = const [],
    this.zoneAccess = const [],
    this.permissions = const ['CAN_CONTROL_PUMP', 'CAN_LOG_DIARY'],
  });

  FarmerModel copyWith({
    String? name,
    String? role,
    String? phone,
    String? email,
    String? username,
    String? password,
    String? avatar,
    String? farmId,
    bool? isActive,
    List<String>? assignedZoneNames,
    List<String>? permissions,
  }) {
    return FarmerModel(
      farmerId: farmerId,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      farmId: farmId ?? this.farmId,
      isActive: isActive ?? this.isActive,
      joinedDate: joinedDate,
      assignedZoneNames: assignedZoneNames ?? this.assignedZoneNames,
      zoneAccess: zoneAccess,
      permissions: permissions ?? this.permissions,
    );
  }

  factory FarmerModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role']?.toString() ?? 'Farmer';
    String displayRole = 'Nông dân Thực địa (CF2)';
    if (rawRole == 'PlatformTechnician' || rawRole.contains('Technician')) {
      displayRole = 'Kỹ thuật viên IoT (CF1)';
    } else if (rawRole == 'FarmOwner' || rawRole.contains('Owner')) {
      displayRole = 'Chủ trang trại (Owner)';
    }

    final permissionsList = <String>['CAN_LOG_DIARY'];
    final zoneAccess = json['zoneAccess'] as List<dynamic>?;
    final rawPerms = json['permissions'] as List<dynamic>?;
    if ((zoneAccess != null && zoneAccess.any((z) => z['canControl'] == true)) ||
        (rawPerms != null && rawPerms.contains('CAN_CONTROL_PUMP')) ||
        json['canControl'] == true) {
      permissionsList.add('CAN_CONTROL_PUMP');
    }

    return FarmerModel(
      farmerId: json['userId']?.toString() ?? json['farmerId']?.toString() ?? '',
      name: json['fullName']?.toString() ?? json['name']?.toString() ?? 'Nông dân',
      role: displayRole,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['email']?.toString() ?? '',
      farmId: json['farmId']?.toString(),
      isActive: json['status']?.toString() == 'Active' || json['status'] == null,
      joinedDate: json['createdAtUtc'] != null ? json['createdAtUtc'].toString().substring(0, 10) : '01/2026',
      assignedZoneNames: const [],
      zoneAccess: [
        for (final z in zoneAccess ?? const [])
          ZoneAccessItem(zoneId: z['zoneId']?.toString() ?? '', canControl: z['canControl'] == true),
      ],
      permissions: permissionsList,
    );
  }
}

class FieldModel {
  final String fieldId;
  final String farmId;
  final String name;
  final String description;
  final double areaM2;
  final List<LatLng>? polygon;

  FieldModel({
    required this.fieldId,
    required this.farmId,
    required this.name,
    required this.description,
    required this.areaM2,
    this.polygon,
  });

  factory FieldModel.fromJson(Map<String, dynamic> json, {String defaultFarmId = ''}) {
    List<LatLng>? parsedPolygon;
    try {
      final boundary = json['boundaryGeoJson'];
      if (boundary != null && boundary['coordinates'] != null) {
        final coords = boundary['coordinates'][0] as List<dynamic>;
        parsedPolygon = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      }
    } catch (_) {}

    return FieldModel(
      fieldId: json['fieldId']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? defaultFarmId,
      name: json['name']?.toString() ?? 'Lô đất',
      description: json['soilType']?.toString() ?? 'Đất đỏ bazan màu mỡ',
      areaM2: (json['areaM2'] as num?)?.toDouble() ?? 5000.0,
      polygon: parsedPolygon,
    );
  }
}

class ZoneModel {
  final String zoneId;
  final String farmId;
  final String farmName;
  final String fieldId;
  final String fieldName;
  final String name;
  String currentCrop;
  String currentStage;
  String? farmingSeasonId;
  /// None | InProgress | Mismatch | PlannedOnly (do API tính; vụ chỉ cho giai đoạn khi cùng cây với Zone).
  final String seasonStatus;
  /// Zone chưa có vụ đang canh tác (chưa có vụ hoặc chỉ có vụ dự kiến): hiển thị gợi ý tạo vụ trên web.
  bool get needsSeason => seasonStatus == 'None' || seasonStatus == 'PlannedOnly';
  final double areaM2;
  final double currentSoilMoisture;
  final double currentTemp;
  final double currentHumidity;
  final double currentLux;
  final bool telemetryIsFresh;
  final bool cropContextIsDbBacked;
  // Người phụ trách được phân công cho zone này
  final String? assignedWorkerName;
  final String? workerRole; // 'Nông dân', 'Kỹ thuật viên', etc.
  final List<LatLng>? polygon;

  ZoneModel({
    required this.zoneId,
    required this.farmId,
    this.farmName = 'Nông trại Thông minh Đà Lạt',
    this.fieldId = 'field-01',
    this.fieldName = 'Lô đất A1 (Khu CNC)',
    required this.name,
    required this.currentCrop,
    required this.currentStage,
    this.farmingSeasonId,
    this.seasonStatus = 'None',
    required this.areaM2,
    required this.currentSoilMoisture,
    required this.currentTemp,
    required this.currentHumidity,
    required this.currentLux,
    this.telemetryIsFresh = false,
    this.cropContextIsDbBacked = false,
    this.assignedWorkerName,
    this.workerRole,
    this.polygon,
  });

  ZoneModel copyWith({
    String? currentCrop,
    String? currentStage,
    String? seasonStatus,
    double? areaM2,
    double? currentSoilMoisture,
    double? currentTemp,
    double? currentHumidity,
    double? currentLux,
    bool? telemetryIsFresh,
    bool? cropContextIsDbBacked,
    String? assignedWorkerName,
    String? workerRole,
    List<LatLng>? polygon,
  }) {
    return ZoneModel(
      zoneId: zoneId,
      farmId: farmId,
      farmName: farmName,
      fieldId: fieldId,
      fieldName: fieldName,
      name: name,
      currentCrop: currentCrop ?? this.currentCrop,
      currentStage: currentStage ?? this.currentStage,
      seasonStatus: seasonStatus ?? this.seasonStatus,
      areaM2: areaM2 ?? this.areaM2,
      currentSoilMoisture: currentSoilMoisture ?? this.currentSoilMoisture,
      currentTemp: currentTemp ?? this.currentTemp,
      currentHumidity: currentHumidity ?? this.currentHumidity,
      currentLux: currentLux ?? this.currentLux,
      telemetryIsFresh: telemetryIsFresh ?? this.telemetryIsFresh,
      cropContextIsDbBacked: cropContextIsDbBacked ?? this.cropContextIsDbBacked,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      workerRole: workerRole ?? this.workerRole,
      polygon: polygon ?? this.polygon,
    );
  }

  factory ZoneModel.fromJson(Map<String, dynamic> json, {String farmId = '', String fieldId = '', String farmName = '', String fieldName = ''}) {
    List<LatLng>? parsedPolygon;
    try {
      final boundary = json['boundaryGeoJson'] ?? json['polygonGeoJson'];
      if (boundary != null && boundary['coordinates'] != null) {
        final coords = boundary['coordinates'][0] as List<dynamic>;
        parsedPolygon = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      }
    } catch (_) {}

    return ZoneModel(
      zoneId: json['zoneId']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? farmId,
      farmName: farmName.isNotEmpty ? farmName : 'Nông trại SmartFarm',
      fieldId: json['fieldId']?.toString() ?? fieldId,
      fieldName: fieldName.isNotEmpty ? fieldName : 'Lô đất',
      name: json['name']?.toString() ?? 'Nhà màng',
      // Cây là thuộc tính của Zone; giai đoạn chỉ có khi vụ đang canh tác cùng cây. Không có thì hiển thị trạng thái rỗng, không dùng giá trị mặc định.
      currentCrop: json['currentCrop']?.toString() ??
          (json['seasonStatus'] == 'PlannedOnly' && json['plannedCrop'] != null
              ? 'Chưa gán cây (vụ dự kiến: ${json['plannedCrop']})'
              : 'Chưa gán cây'),
      currentStage: json['currentStage']?.toString() ??
          switch (json['seasonStatus']) {
            'Mismatch' => 'Vụ đang chạy thuộc cây khác (${json['seasonCropName'] ?? 'không rõ'}) — cần cập nhật trên web',
            'PlannedOnly' => 'Chưa có vụ đang canh tác (có vụ dự kiến)',
            _ => 'Chưa có vụ đang canh tác',
          },
      seasonStatus: json['seasonStatus']?.toString() ?? 'None',
      areaM2: (json['areaM2'] as num?)?.toDouble() ?? 5000.0,
      currentSoilMoisture: 65.0,
      currentTemp: 24.5,
      currentHumidity: 70.0,
      currentLux: 750.0,
      assignedWorkerName: json['assignedWorkerName']?.toString(),
      workerRole: 'Nông dân Thực địa (CF2)',
      polygon: parsedPolygon,
      cropContextIsDbBacked: json['currentCrop'] != null && json['currentStage'] != null && json['appliedRequirements'] is List,
    );
  }
}


class ActuatorModel {
  final String actuatorId;
  final String zoneId;
  final String name;
  final String actuatorType; // PUMP, FAN, VALVE, GROW_LIGHT
  bool isRunning;
  int remainingMinutes;

  ActuatorModel({
    required this.actuatorId,
    required this.zoneId,
    required this.name,
    required this.actuatorType,
    this.isRunning = false,
    this.remainingMinutes = 0,
  });

  factory ActuatorModel.fromJson(Map<String, dynamic> json, {String defaultZoneId = ''}) {
    final rawType = (json['actuatorType'] ?? json['type'])?.toString().toUpperCase() ?? 'PUMP';
    final type = switch (rawType) {
      'IRRIGATIONPUMP' || 'PUMP' => 'PUMP',
      'VENTILATIONFAN' || 'FAN' => 'FAN',
      'MISTSPRAYER' || 'VALVE' => 'VALVE',
      'GROWLIGHT' || 'GROW_LIGHT' => 'GROW_LIGHT',
      _ => rawType,
    };
    final state = (json['status'] ?? json['currentState'] ?? '')?.toString().toUpperCase() ?? '';
    final isRunning = state == 'ON' || state == 'ACTIVE' || state == 'RUNNING';
    final remainingSec = (json['remainingSeconds'] as num?)?.toInt() ?? 0;

    return ActuatorModel(
      actuatorId: json['actuatorId']?.toString() ?? json['id']?.toString() ?? '',
      zoneId: json['zoneId']?.toString() ?? defaultZoneId,
      name: json['name']?.toString() ?? (type == 'PUMP' ? 'Máy bơm tưới nhỏ giọt' : 'Thiết bị chấp hành'),
      actuatorType: type,
      isRunning: isRunning,
      remainingMinutes: (remainingSec / 60).ceil(),
    );
  }
}

class AlertModel {
  final String alertId;
  final String title;
  final String message;
  final String severity; // CRITICAL, WARNING, INFO
  final String category; // THRESHOLD_VIOLATION, BOUNDARY_VIOLATION, HARDWARE_FAULT, OFFLINE
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

  bool get isBoundaryViolation => category == 'BOUNDARY_VIOLATION' || title.contains('RANH GIỚI');

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
    final category = json['alertCategory']?.toString() ?? (param == 'BOUNDARY' ? 'BOUNDARY_VIOLATION' : 'THRESHOLD_VIOLATION');
    final title = json['title']?.toString() ?? (category == 'BOUNDARY_VIOLATION' ? 'Cảnh báo ranh giới thiết bị' : 'Cảnh báo vi khí hậu $param');
    final message = json['message']?.toString() ?? 'Giá trị đo được: $obs $unit (ngoài ngưỡng tối ưu)';

    return AlertModel(
      alertId: json['alertId']?.toString() ?? '',
      title: title,
      message: message,
      severity: sev,
      category: category,
      time: formattedTime,
      isAcknowledged: json['acknowledgedAtUtc'] != null || json['status']?.toString() == 'Acknowledged',
    );
  }
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

  factory TaskModel.fromJson(Map<String, dynamic> json, {String defaultZoneName = 'Khu vực canh tác'}) {
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
      dueStr = '${two(dueAt.day)}/${two(dueAt.month)}/${dueAt.year} ${two(dueAt.hour)}:${two(dueAt.minute)}';
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

class ChatMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final String time;
  final String? actionProposal;
  // For AI recommendation cards
  final String? recommendationId;
  String? recommendationStatus; // PROPOSED, APPLIED, REJECTED
  final List<String>? sources;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.time,
    this.actionProposal,
    this.recommendationId,
    this.recommendationStatus,
    this.sources,
  });
}

// ─────────────────────────────────────────
// AI Recommendation Model
// ─────────────────────────────────────────
class AiRecommendationModel {
  final String recommendationId;
  final String rationale;
  final String? riskWarning;
  final String? suggestedActionSummary;
  final String status; // PROPOSED, APPLIED, REJECTED, EXPIRED
  final String? actuatorId;
  final int? durationSeconds;
  final List<String>? sources;

  AiRecommendationModel({
    required this.recommendationId,
    required this.rationale,
    this.riskWarning,
    this.suggestedActionSummary,
    required this.status,
    this.actuatorId,
    this.durationSeconds,
    this.sources,
  });

  factory AiRecommendationModel.fromJson(Map<String, dynamic> json) {
    // 1. Support Backend AiRecommendationView (summary, details, proposedAction, proposedDurationSeconds)
    final summary = json['summary']?.toString() ?? json['rationale']?.toString() ?? '';
    final details = json['details']?.toString();
    final rationaleText = details != null && details.isNotEmpty ? details : summary;

    final proposedAction = json['proposedAction']?.toString();
    final isActionable = json['isActionable'] == true;
    final proposedDur = (json['proposedDurationSeconds'] as num?)?.toInt();
    final proposedActId = json['proposedActuatorId']?.toString();

    String? actionSummary;
    String? actuatorId = proposedActId;
    int? durationSeconds = proposedDur;

    if (isActionable && proposedAction != null) {
      if (proposedDur != null && proposedDur > 0) {
        final mins = (proposedDur / 60).round();
        actionSummary = mins > 0 ? 'Bật tưới $mins phút' : 'Bật tưới $proposedDur giây';
      } else {
        actionSummary = 'Kích hoạt: $proposedAction';
      }
    }

    // 2. Fallback to legacy suggestedAction object if present
    final action = json['suggestedAction'] as Map<String, dynamic>?;
    if (action != null) {
      final type = action['actionType']?.toString() ?? '';
      final dur = (action['durationSeconds'] as num?)?.toInt();
      if (type == 'IrrigateZone' && dur != null) {
        final mins = (dur / 60).round();
        actionSummary = 'Tưới $mins phút';
        durationSeconds = dur;
      } else if (type == 'NoAction') {
        actionSummary = null;
      } else {
        actionSummary = type;
      }
      actuatorId = action['actuatorId']?.toString() ?? actuatorId;
    }

    final sourcesList = (json['sources'] as List<dynamic>?)
        ?.map((s) => s is Map ? (s['title']?.toString() ?? '') : s.toString())
        .where((t) => t.isNotEmpty)
        .toList();

    return AiRecommendationModel(
      recommendationId: json['recommendationId']?.toString() ?? json['id']?.toString() ?? '',
      rationale: rationaleText,
      riskWarning: json['riskWarning']?.toString() ?? (json['limitations'] is List ? (json['limitations'] as List).join('; ') : null),
      suggestedActionSummary: actionSummary,
      status: json['status']?.toString() ?? 'PROPOSED',
      actuatorId: actuatorId,
      durationSeconds: durationSeconds,
      sources: sourcesList,
    );
  }
}

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

  factory ScheduleModel.fromJson(Map<String, dynamic> json, {String defaultZoneName = 'Nhà màng'}) {
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
    final enabled = json['isEnabled'] as bool? ?? json['isActive'] as bool? ?? true;
    final zId = json['zoneId']?.toString() ?? '';
    final aId = json['actuatorId']?.toString() ?? '';
    final rainDelay = json['enableRainDelay'] as bool? ?? true;
    final rainThreshold = (json['rainThresholdPercent'] as num?)?.toDouble() ?? 70.0;

    return ScheduleModel(
      scheduleId: json['scheduleId']?.toString() ?? '',
      zoneId: zId,
      actuatorId: aId,
      name: json['name']?.toString() ?? 'Lịch tưới định kỳ',
      zoneName: json['zoneName']?.toString() ?? (zId.isNotEmpty ? zId : defaultZoneName),
      actuatorName: json['actuatorName']?.toString() ?? (aId.isNotEmpty ? aId : 'Bơm tưới nhỏ giọt'),
      isEnabled: enabled,
      isActive: enabled,
      startTime: '06:30',
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


// ─────────────────────────────────────────
// Vấn đề 6: Default Crop Profile Models
// ─────────────────────────────────────────

// ─────────────────────────────────────────
// Vấn đề 6: Default Crop Profile Models
// ─────────────────────────────────────────

class EnvironmentalRange {
  final double soilMoistureMin;
  final double soilMoistureMax;
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;
  final int irrigationDurationMin;
  final int irrigationFrequencyPerDay;

  const EnvironmentalRange({
    required this.soilMoistureMin,
    required this.soilMoistureMax,
    required this.tempMin,
    required this.tempMax,
    required this.humidityMin,
    required this.humidityMax,
    required this.irrigationDurationMin,
    required this.irrigationFrequencyPerDay,
  });
}

class GrowthStageProfile {
  final String stageId;
  final String name;
  final String nameEn;
  final int startDayFromPlanting;
  final int endDayFromPlanting;
  final String description;
  final String iconEmoji;
  final EnvironmentalRange requirements;
  final List<String> keyActivities;

  int get durationDays => (endDayFromPlanting - startDayFromPlanting) > 0 ? (endDayFromPlanting - startDayFromPlanting) : 1;

  const GrowthStageProfile({
    required this.stageId,
    required this.name,
    required this.nameEn,
    required this.startDayFromPlanting,
    required this.endDayFromPlanting,
    required this.description,
    required this.iconEmoji,
    required this.requirements,
    required this.keyActivities,
  });
}

class DefaultCropProfile {
  final String cropId;
  final String name;
  final String nameEn;
  final String variety;
  final String emoji;
  final String standardType; // 'VietGAP', 'GlobalGAP'
  final int totalCycleDays;
  final String description;
  final String origin;
  final String difficulty;
  final String suitableRegion;
  final List<String> compatibleActuators;
  final List<String> commonPests;
  final List<GrowthStageProfile> growthStages;
  bool isApplied;

  DefaultCropProfile({
    required this.cropId,
    required this.name,
    required this.nameEn,
    required this.variety,
    required this.emoji,
    required this.standardType,
    required this.totalCycleDays,
    required this.description,
    required this.origin,
    required this.difficulty,
    required this.suitableRegion,
    required this.compatibleActuators,
    required this.commonPests,
    required this.growthStages,
    this.isApplied = false,
  });
}

// ─────────────────────────────────────────
// Device Health Models (CF1 - Kỹ thuật viên)
// ─────────────────────────────────────────

class DeviceHealthModel {
  final String nodeId;
  final String name;
  final String type; // GATEWAY, SENSOR_NODE, ACTUATOR_NODE
  final DateTime lastSeenAt;
  final int expectedIntervalSeconds;
  final double signalRssi;
  final int batteryPercent;

  DeviceHealthModel({
    required this.nodeId,
    required this.name,
    required this.type,
    required this.lastSeenAt,
    required this.expectedIntervalSeconds,
    required this.signalRssi,
    required this.batteryPercent,
  });

  String get healthStatus {
    final diffSec = DateTime.now().difference(lastSeenAt).inSeconds;
    if (diffSec <= expectedIntervalSeconds * 2) {
      return 'ONLINE';
    } else if (diffSec <= expectedIntervalSeconds * 5) {
      return 'WARNING';
    }
    return 'OFFLINE';
  }

  String get lastSeenText {
    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s trước';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}p trước';
    } else {
      return '${diff.inHours}h trước';
    }
  }
}

// ─────────────────────────────────────────
// Tự động hóa & Lịch tưới Models (CF2 / CF3)
// ─────────────────────────────────────────

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

  factory AutomationRuleModel.fromJson(Map<String, dynamic> json, {String? actuatorName, String defaultZoneName = 'Nhà màng'}) {
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
      actionType: json['action']?.toString() == 'TurnOff' ? 'TẮT (OFF)' : 'BẬT (ON)',
      actionDurationMinutes: ((json['durationSeconds'] as num?)?.toInt() ?? 0) ~/ 60,
      isActive: json['isActive'] == true,
      zoneId: json['zoneId']?.toString(),
      raw: json,
    );
  }
}


// ─────────────────────────────────────────
// Mô phỏng Thiết bị & Dự toán Chi phí theo Diện tích Zone

// ─────────────────────────────────────────
class ZoneEquipmentItem {
  final String name;
  final String category; // 'SENSOR', 'ACTUATOR', 'IRRIGATION', 'NETWORK'
  final int quantity;
  final String unit;
  final double unitPriceVND;
  final String description;

  double get totalPriceVND => quantity * unitPriceVND;

  const ZoneEquipmentItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.unitPriceVND,
    required this.description,
  });

  ZoneEquipmentItem copyWith({
    String? name,
    String? category,
    int? quantity,
    String? unit,
    double? unitPriceVND,
    String? description,
  }) {
    return ZoneEquipmentItem(
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPriceVND: unitPriceVND ?? this.unitPriceVND,
      description: description ?? this.description,
    );
  }
}

// ─────────────────────────────────────────
// Mô hình Mạng Tổ Ong (Lục Giác - Honeycomb IoT Topology) chuẩn FE
// ─────────────────────────────────────────
class HoneycombTopologySimulation {
  final double areaM2;
  final String cropName;
  final String cropIcon;
  final String cropColor;
  final int gateways;
  final int sensors;
  final int actuators;
  final int hexagonCells;

  // Đơn giá chuẩn FE (VNĐ)
  final double gatewayUnitPrice;
  final double sensorUnitPrice;
  final double actuatorUnitPrice;
  final double installationFee;

  // Tổng & Dải dao động chi phí
  final double totalDeviceCostVND;
  final double minCostVND;
  final double maxCostVND;

  // Metadata Template VietGAP
  final String growthCycle;
  final String nutritionInfo;
  final String lightRequirement;
  final String tempRange;
  final String humidityRange;
  final String seasonDuration;
  final String note;
  final List<String> varieties;

  const HoneycombTopologySimulation({
    required this.areaM2,
    required this.cropName,
    required this.cropIcon,
    required this.cropColor,
    required this.gateways,
    required this.sensors,
    required this.actuators,
    required this.hexagonCells,
    required this.gatewayUnitPrice,
    required this.sensorUnitPrice,
    required this.actuatorUnitPrice,
    required this.installationFee,
    required this.totalDeviceCostVND,
    required this.minCostVND,
    required this.maxCostVND,
    required this.growthCycle,
    required this.nutritionInfo,
    required this.lightRequirement,
    required this.tempRange,
    required this.humidityRange,
    required this.seasonDuration,
    required this.note,
    required this.varieties,
  });

  const HoneycombTopologySimulation.empty()
      : areaM2 = 0,
        cropName = '',
        cropIcon = '🌱',
        cropColor = 'emerald',
        gateways = 1,
        sensors = 2,
        actuators = 1,
        hexagonCells = 1,
        gatewayUnitPrice = 3500000,
        sensorUnitPrice = 850000,
        actuatorUnitPrice = 650000,
        installationFee = 500000,
        totalDeviceCostVND = 5850000,
        minCostVND = 4972500,
        maxCostVND = 7312500,
        growthCycle = '',
        nutritionInfo = '',
        lightRequirement = '',
        tempRange = '',
        humidityRange = '',
        seasonDuration = '',
        note = '',
        varieties = const [];

  factory HoneycombTopologySimulation.calculate({
    required double areaM2,
    required String cropName,
  }) {
    final validArea = areaM2 <= 0 ? 500.0 : areaM2;
    final lower = cropName.toLowerCase();

    // Chuẩn FE CreateFarmWizard.tsx:
    double sensorsPer500m2 = 1.0;
    double actuatorsPer500m2 = 1.2;
    double gatewayPer3000m2 = 1.0;
    String icon = '🍅';
    String color = 'emerald';
    List<String> varieties = ['Beefsteak Đà Lạt F1', 'Cherry Vàng F1', 'Bi đỏ VN888', 'Pink Lady F1'];
    String note = 'Cà chua cần theo dõi độ ẩm đất & nhiệt độ chặt chẽ';
    String growthStage = 'Mầm ➔ Sinh trưởng ➔ Ra hoa ➔ Tạo quả';
    String nutrition = 'N-P-K (5-10-5 mầm, 5-10-10 hoa)';
    String light = '12-14 giờ/ngày';
    String temp = 'Ngày: 21-29°C, Đêm: 15-20°C';
    String humidity = '60-70%';
    String duration = '90-120 ngày';

    if (lower.contains('ớt') || lower.contains('pepper') || lower.contains('capsicum')) {
      icon = '🫑';
      color = 'red';
      sensorsPer500m2 = 0.8;
      actuatorsPer500m2 = 1.0;
      gatewayPer3000m2 = 1.0;
      varieties = ['Ớt Đà Lạt F1', 'California Wonder', 'Chuông Đỏ Hà Lan', 'Sweet Baby'];
      note = 'Ớt cần cảm biến ánh sáng và kiểm soát tưới chính xác';
      growthStage = 'Mầm ➔ Phát triển cành ➔ Ra hoa ➔ Kết trái';
      nutrition = 'N-P-K (Tăng Kali khi kết trái)';
      light = '10-12 giờ/ngày';
      temp = 'Ngày: 25-28°C, Đêm: 18-20°C';
      humidity = '55-65%';
      duration = '100-150 ngày';
    } else if (lower.contains('dưa') || lower.contains('cucumber') || lower.contains('cucumis')) {
      icon = '🥒';
      color = 'green';
      sensorsPer500m2 = 0.8;
      actuatorsPer500m2 = 0.8;
      gatewayPer3000m2 = 1.0;
      varieties = ['Dưa Nhật TN-088', 'Dưa baby VN', 'Cucumber F1 Hà Lan', 'Mini Cuke'];
      note = 'Dưa leo phát triển nhanh, cần theo dõi độ ẩm không khí';
      growthStage = 'Mầm ➔ Leo giàn ➔ Ra hoa cái ➔ Trái non';
      nutrition = 'Tăng Đạm giai đoạn đầu, Lân giai đoạn hoa';
      light = '10-14 giờ/ngày';
      temp = 'Ngày: 24-30°C, Đêm: 18-22°C';
      humidity = '70-85%';
      duration = '60-80 ngày';
    } else if (lower.contains('xà lách') || lower.contains('thủy canh') || lower.contains('cải') || lower.contains('lactuca')) {
      icon = '🥬';
      color = 'lime';
      sensorsPer500m2 = 1.2;
      actuatorsPer500m2 = 1.5;
      gatewayPer3000m2 = 1.0;
      varieties = ['Butterhead F1', 'Romaine Viet', 'Oakleaf xanh', 'Lollo Rossa'];
      note = 'Thủy canh cần giám sát EC/pH + van bơm dinh dưỡng liên tục';
      growthStage = 'Ươm hạt ➔ Lên giàn ➔ Phát triển lá ➔ Thu hoạch';
      nutrition = 'EC: 1.2 - 1.8 mS/cm, pH: 5.8 - 6.2';
      light = '14-16 giờ/ngày';
      temp = 'Ngày: 18-24°C, Đêm: 15-18°C';
      humidity = '50-70%';
      duration = '40-50 ngày';
    } else if (lower.contains('dâu') || lower.contains('strawberry') || lower.contains('fragaria')) {
      icon = '🍓';
      color = 'red';
      sensorsPer500m2 = 1.2;
      actuatorsPer500m2 = 1.2;
      gatewayPer3000m2 = 1.0;
      varieties = ['Dâu New Zealand', 'Dâu Nhật Hana', 'Dâu Mỹ Albion', 'Dâu Bạch Tuyết'];
      note = 'Rất nhạy cảm với độ ẩm giá thể & nấm rễ, cần tưới nhỏ giọt chính xác';
      growthStage = 'Cây giống ➔ Phân hóa chồi hoa ➔ Đậu quả ➔ Thu hoạch';
      nutrition = 'Dinh dưỡng hữu cơ vi lượng chelate';
      light = '12-14 giờ/ngày';
      temp = 'Ngày: 20-25°C, Đêm: 12-16°C';
      humidity = '65-75%';
      duration = '90-110 ngày';
    }

    const gatewayUnitPrice = 3500000.0;
    const sensorUnitPrice = 850000.0;
    const actuatorUnitPrice = 650000.0;
    const installationFee = 500000.0;

    final gateways = math.max(1, (validArea / 3000.0 * gatewayPer3000m2).ceil());
    final sensors = math.max(2, (validArea / 500.0 * sensorsPer500m2).ceil());
    final actuators = math.max(1, (validArea / 500.0 * actuatorsPer500m2).ceil());
    final hexagonCells = math.max(1, (validArea / 500.0).ceil());

    final totalCost = (gateways * gatewayUnitPrice) +
        (sensors * sensorUnitPrice) +
        (actuators * actuatorUnitPrice) +
        installationFee;
    final minCost = (totalCost * 0.85).roundToDouble();
    final maxCost = (totalCost * 1.25).roundToDouble();

    return HoneycombTopologySimulation(
      areaM2: validArea,
      cropName: cropName,
      cropIcon: icon,
      cropColor: color,
      gateways: gateways,
      sensors: sensors,
      actuators: actuators,
      hexagonCells: hexagonCells,
      gatewayUnitPrice: gatewayUnitPrice,
      sensorUnitPrice: sensorUnitPrice,
      actuatorUnitPrice: actuatorUnitPrice,
      installationFee: installationFee,
      totalDeviceCostVND: totalCost,
      minCostVND: minCost,
      maxCostVND: maxCost,
      growthCycle: growthStage,
      nutritionInfo: nutrition,
      lightRequirement: light,
      tempRange: temp,
      humidityRange: humidity,
      seasonDuration: duration,
      note: note,
      varieties: varieties,
    );
  }
}

class ZoneCostSimulation {
  final double areaM2;
  final String cropName;
  final int estimatedPlants;
  final double plantsPerM2;

  // Thiết bị phần cứng
  final List<ZoneEquipmentItem> equipmentItems;
  final double totalEquipmentCostVND;

  // Mô hình mạng tổ ong (Lục giác) chuẩn FE
  final HoneycombTopologySimulation honeycomb;

  // Dự toán vận hành mùa vụ (BR-ELEC-01: 2,587 VND/kWh, nước 10,000 VND/m3)
  final double dailyWaterLiters;
  final double monthlyWaterCostVND;
  final double dailyElectricityKwh;
  final double monthlyElectricityCostVND;
  final double estimatedLaborCostMonthlyVND;

  double get monthlyOperatingCostVND =>
      monthlyWaterCostVND + monthlyElectricityCostVND + estimatedLaborCostMonthlyVND;

  const ZoneCostSimulation({
    required this.areaM2,
    required this.cropName,
    required this.estimatedPlants,
    required this.plantsPerM2,
    required this.equipmentItems,
    required this.totalEquipmentCostVND,
    this.honeycomb = const HoneycombTopologySimulation.empty(),
    required this.dailyWaterLiters,
    required this.monthlyWaterCostVND,
    required this.dailyElectricityKwh,
    required this.monthlyElectricityCostVND,
    required this.estimatedLaborCostMonthlyVND,
  });

  ZoneCostSimulation copyWithCustomItems({
    required List<ZoneEquipmentItem> updatedItems,
  }) {
    double totalEquip = 0;
    for (final it in updatedItems) {
      totalEquip += it.totalPriceVND;
    }
    return ZoneCostSimulation(
      areaM2: areaM2,
      cropName: cropName,
      estimatedPlants: estimatedPlants,
      plantsPerM2: plantsPerM2,
      equipmentItems: updatedItems,
      totalEquipmentCostVND: totalEquip,
      honeycomb: honeycomb,
      dailyWaterLiters: dailyWaterLiters,
      monthlyWaterCostVND: monthlyWaterCostVND,
      dailyElectricityKwh: dailyElectricityKwh,
      monthlyElectricityCostVND: monthlyElectricityCostVND,
      estimatedLaborCostMonthlyVND: estimatedLaborCostMonthlyVND,
    );
  }

  /// Factory tính toán mô phỏng động dựa trên diện tích (areaM2) và loại cây trồng
  factory ZoneCostSimulation.calculate({
    required double areaM2,
    required String cropName,
  }) {
    // 1. Mật độ cây trồng theo chuẩn VietGAP
    double density = 3.5; // mặc định cà chua / ớt
    if (cropName.contains('Dâu')) {
      density = 6.0;
    } else if (cropName.contains('Xà lách') || cropName.contains('Cải')) {
      density = 16.0;
    } else if (cropName.contains('Dưa')) {
      density = 2.8;
    }
    final int plantCount = (areaM2 * density).round();

    // 2. Định mức phần cứng IoT theo diện tích
    // Cứ mỗi 1,500 m2 cần 1 LoRa Sensor Node (Độ ẩm đất đa tầng, Temp, Humi, Lux)
    final int sensorNodes = (areaM2 / 1500).ceil().clamp(1, 20);

    // Cứ mỗi 2,500 m2 cần 1 Bơm tưới áp lực (1.5HP - 2HP)
    final int pumpCount = (areaM2 / 2500).ceil().clamp(1, 10);

    // Van điện từ Solenoid phân khu tưới (mỗi 800 - 1,000 m2 cần 1 van độc lập)
    final int valveCount = (areaM2 / 800).ceil().clamp(2, 30);

    // Quạt thông gió đối lưu (1 quạt / 500 m2)
    final int fanCount = (areaM2 / 500).ceil().clamp(2, 40);

    // Đường ống tưới nhỏ giọt / bù áp (m mét dài ~ 2.5m ống / m2)
    final int dripPipeMeters = (areaM2 * 2.5).round();

    // Đầu bù áp nhỏ giọt (tương đương số cây + 10% dự phòng)
    final int drippers = (plantCount * 1.1).round();

    final items = <ZoneEquipmentItem>[
      ZoneEquipmentItem(
        name: 'Trạm LoRa Sensor Node 4-trong-1',
        category: 'SENSOR',
        quantity: sensorNodes,
        unit: 'Bộ',
        unitPriceVND: 2450000,
        description: 'Đo ẩm đất 3 độ sâu, nhiệt ẩm không khí, quang kỳ PAR ($sensorNodes bộ cho ${areaM2.toInt()}m²)',
      ),
      ZoneEquipmentItem(
        name: 'Máy bơm tưới tăng áp tự động 1.5HP',
        category: 'ACTUATOR',
        quantity: pumpCount,
        unit: 'Chiếc',
        unitPriceVND: 3800000,
        description: 'Lưu lượng 12-15 m³/h, tích hợp khởi động mềm và rơle bảo vệ quá tải',
      ),
      ZoneEquipmentItem(
        name: 'Van điện từ Solenoid DC 24V',
        category: 'ACTUATOR',
        quantity: valveCount,
        unit: 'Chiếc',
        unitPriceVND: 420000,
        description: 'Chia phân khu tưới luân phiên chống tụt áp đường ống chính',
      ),
      ZoneEquipmentItem(
        name: 'Quạt thông gió đối lưu nhà màng',
        category: 'ACTUATOR',
        quantity: fanCount,
        unit: 'Chiếc',
        unitPriceVND: 1650000,
        description: 'Công suất 350W, điều hòa vi khí hậu giảm nấm bệnh VietGAP',
      ),
      ZoneEquipmentItem(
        name: 'Ống tưới PE 16mm & dây tưới nhỏ giọt',
        category: 'IRRIGATION',
        quantity: dripPipeMeters,
        unit: 'Mét',
        unitPriceVND: 5500,
        description: 'Độ bền chống tia UV trên 5 năm ngoài trời',
      ),
      ZoneEquipmentItem(
        name: 'Đầu nhỏ giọt bù áp chống rò 2L/h',
        category: 'IRRIGATION',
        quantity: drippers,
        unit: 'Cái',
        unitPriceVND: 2200,
        description: 'Cấp chính xác lượng dinh dưỡng đều nhau cho từng gốc cây',
      ),
      const ZoneEquipmentItem(
        name: 'Tủ điều khiển IoT Actuator Driver Box',
        category: 'NETWORK',
        quantity: 1,
        unit: 'Tủ',
        unitPriceVND: 4500000,
        description: 'Vỏ chống nước IP66, chống sét lan truyền, kết nối LoRa/RS485 Modbus',
      ),
    ];

    double totalEquip = 0;
    for (final it in items) {
      totalEquip += it.totalPriceVND;
    }

    // 3. Ước tính vận hành (Nước, Điện, Nhân công)
    // Nước: trung bình 3.5 - 4 lít / m2 / ngày
    final dailyWater = areaM2 * 3.8;
    // Giá nước thủy lợi / giếng khoan xử lý: 10,000 đ / m3 (10 đ / lít)
    final monthlyWaterCost = (dailyWater * 30 / 1000) * 10000;

    // Điện: Máy bơm + Quạt chạy trung bình 2h/ngày
    // Công suất bơm (pumpCount * 1.1kW) + quạt (fanCount * 0.35kW * 0.5 thời gian)
    final double totalWatt = (pumpCount * 1100.0) + (fanCount * 350.0 * 0.4);
    final double dailyKwh = (totalWatt * 2.5) / 1000.0;
    // BR-ELEC-01: 2,587 VND/kWh (nông nghiệp)
    final double monthlyElecCost = dailyKwh * 30 * 2587.0;

    // Nhân công: 1 công nhân phụ trách trung bình 2,500 m2 (~7,500,000 đ/tháng)
    final double laborCost = (areaM2 / 2500.0) * 7500000.0;

    final honeycomb = HoneycombTopologySimulation.calculate(
      areaM2: areaM2,
      cropName: cropName,
    );

    return ZoneCostSimulation(
      areaM2: areaM2,
      cropName: cropName,
      estimatedPlants: plantCount,
      plantsPerM2: density,
      equipmentItems: items,
      totalEquipmentCostVND: totalEquip,
      honeycomb: honeycomb,
      dailyWaterLiters: dailyWater,
      monthlyWaterCostVND: monthlyWaterCost,
      dailyElectricityKwh: dailyKwh,
      monthlyElectricityCostVND: monthlyElecCost,
      estimatedLaborCostMonthlyVND: laborCost,
    );
  }
}

// ─────────────────────────────────────────
// Yêu cầu Kiểm tra Thực địa (Gửi Admin Duyệt & Điều Kỹ thuật viên)
// ─────────────────────────────────────────
class FieldInspectionRequestModel {
  final String requestId;
  final String farmId;
  final String farmName;
  final String zoneId;
  final String zoneName;
  final double areaM2;
  final String cropName;
  final double estimatedCostVND;
  final String contactName;
  final String contactPhone;
  final String preferredDate;
  final String note;
  final String status; // 'PENDING' (Chờ Admin duyệt), 'APPROVED' (Đã duyệt), 'DISPATCHED' (Đã phái KTV), 'COMPLETED' (Đã khảo sát)
  final String createdAt;
  final String? assignedTechnicianName;
  final String? technicianPhone;
  final String? adminNote;
  final String? inspectionNotes; // Ghi chú / Biên bản do KTV điền sau khi khảo sát thực địa
  final List<String>? inspectionFindings; // Danh mục đánh giá (nguồn điện, nước, sóng LoRa, vị trí lắp tủ)
  final List<ZoneEquipmentItem>? customEquipmentItems; // Danh mục thiết bị cụ thể được gắn kèm yêu cầu

  const FieldInspectionRequestModel({
    required this.requestId,
    required this.farmId,
    required this.farmName,
    required this.zoneId,
    required this.zoneName,
    required this.areaM2,
    required this.cropName,
    required this.estimatedCostVND,
    required this.contactName,
    required this.contactPhone,
    required this.preferredDate,
    required this.note,
    this.status = 'PENDING',
    required this.createdAt,
    this.assignedTechnicianName,
    this.technicianPhone,
    this.adminNote,
    this.inspectionNotes,
    this.inspectionFindings,
    this.customEquipmentItems,
  });

  FieldInspectionRequestModel copyWith({
    String? status,
    String? assignedTechnicianName,
    String? technicianPhone,
    String? adminNote,
    String? inspectionNotes,
    List<String>? inspectionFindings,
    List<ZoneEquipmentItem>? customEquipmentItems,
  }) {
    return FieldInspectionRequestModel(
      requestId: requestId,
      farmId: farmId,
      farmName: farmName,
      zoneId: zoneId,
      zoneName: zoneName,
      areaM2: areaM2,
      cropName: cropName,
      estimatedCostVND: estimatedCostVND,
      contactName: contactName,
      contactPhone: contactPhone,
      preferredDate: preferredDate,
      note: note,
      status: status ?? this.status,
      createdAt: createdAt,
      assignedTechnicianName: assignedTechnicianName ?? this.assignedTechnicianName,
      technicianPhone: technicianPhone ?? this.technicianPhone,
      adminNote: adminNote ?? this.adminNote,
      inspectionNotes: inspectionNotes ?? this.inspectionNotes,
      inspectionFindings: inspectionFindings ?? this.inspectionFindings,
      customEquipmentItems: customEquipmentItems ?? this.customEquipmentItems,
    );
  }
}

// ─────────────────────────────────────────
// Đơn Hàng Mua Sắm & Lắp Đặt Thiết Bị IoT (Owner Đặt Cọc 30%)
// ─────────────────────────────────────────
class EquipmentOrderModel {
  final String orderId;
  final String requestId;
  final String farmId;
  final String farmName;
  final String zoneId;
  final String zoneName;
  final List<ZoneEquipmentItem> items;
  final double totalAmountVND;
  final double depositAmountVND; // 30% của tổng tiền
  final double remainingAmountVND; // 70% còn lại sau khi nghiệm thu
  final String status; // 'AWAITING_PAYMENT' (Chờ đặt cọc 30%), 'CONFIRMED' (Đã cọc 30% - Đang xuất kho), 'DISPATCHING' (Đang vận chuyển/lắp đặt), 'COMPLETED' (Đã nghiệm thu thanh toán 100%)
  final String createdAt;
  final String? paymentMethod; // 'BANK_TRANSFER', 'MOMO', 'VNPAY', 'CASH'
  final String? paymentProofNote;
  final String? confirmedAt;

  double get depositRate => 0.30;

  const EquipmentOrderModel({
    required this.orderId,
    required this.requestId,
    required this.farmId,
    required this.farmName,
    required this.zoneId,
    required this.zoneName,
    required this.items,
    required this.totalAmountVND,
    required this.depositAmountVND,
    required this.remainingAmountVND,
    this.status = 'AWAITING_PAYMENT',
    required this.createdAt,
    this.paymentMethod,
    this.paymentProofNote,
    this.confirmedAt,
  });

  EquipmentOrderModel copyWith({
    String? status,
    String? paymentMethod,
    String? paymentProofNote,
    String? confirmedAt,
  }) {
    return EquipmentOrderModel(
      orderId: orderId,
      requestId: requestId,
      farmId: farmId,
      farmName: farmName,
      zoneId: zoneId,
      zoneName: zoneName,
      items: items,
      totalAmountVND: totalAmountVND,
      depositAmountVND: depositAmountVND,
      remainingAmountVND: remainingAmountVND,
      status: status ?? this.status,
      createdAt: createdAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentProofNote: paymentProofNote ?? this.paymentProofNote,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

// ─────────────────────────────────────────
// Kho Vật Tư Nông Nghiệp (Farm Material Stock)
// ─────────────────────────────────────────
class MaterialInventoryModel {
  final String inventoryId;
  final String farmId;
  final String materialName;
  final String code;
  final String category; // 'FERTILIZER', 'SEED', 'PESTICIDE', 'EQUIPMENT'
  final double quantity;
  final String unit;
  final double minimumStock;
  final String storageLocation;
  final String updatedAt;

  bool get isLowStock => quantity <= minimumStock;

  const MaterialInventoryModel({
    required this.inventoryId,
    required this.farmId,
    required this.materialName,
    required this.code,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.minimumStock,
    required this.storageLocation,
    required this.updatedAt,
  });

  factory MaterialInventoryModel.fromJson(Map<String, dynamic> json) => MaterialInventoryModel(
    inventoryId: json['id']?.toString() ?? '',
    farmId: json['farmId']?.toString() ?? '',
    materialName: json['name']?.toString() ?? '',
    code: '',
    category: switch (json['materialType']?.toString()) {
      'Seed' => 'SEED',
      'Fertilizer' => 'FERTILIZER',
      'Pesticide' => 'PESTICIDE',
      _ => 'EQUIPMENT',
    },
    quantity: (json['quantityOnHand'] as num?)?.toDouble() ?? 0,
    unit: json['unit']?.toString() ?? '',
    minimumStock: (json['lowStockThreshold'] as num?)?.toDouble() ?? 0,
    storageLocation: '',
    updatedAt: '',
  );

  MaterialInventoryModel copyWith({
    double? quantity,
    double? minimumStock,
    String? storageLocation,
    String? updatedAt,
  }) {
    return MaterialInventoryModel(
      inventoryId: inventoryId,
      farmId: farmId,
      materialName: materialName,
      code: code,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit,
      minimumStock: minimumStock ?? this.minimumStock,
      storageLocation: storageLocation ?? this.storageLocation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ─────────────────────────────────────────
// Hệ thống Thông Báo (Notification Model)
// ─────────────────────────────────────────

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

  AppNotificationModel copyWith({
    bool? isRead,
  }) {
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

// ─────────────────────────────────────────
// Quản lý Hợp Đồng Thuê Vùng Trồng (Zone Contracts)
// ─────────────────────────────────────────

class ZoneContractRenewalModel {
  final String id;
  final String contractId;
  final String newEndDate;
  final double? newMonthlyRentVnd;
  final double renewalValueVnd;
  final String? notes;
  final String createdAt;

  const ZoneContractRenewalModel({
    required this.id,
    required this.contractId,
    required this.newEndDate,
    this.newMonthlyRentVnd,
    required this.renewalValueVnd,
    this.notes,
    required this.createdAt,
  });

  factory ZoneContractRenewalModel.fromJson(Map<String, dynamic> json) {
    return ZoneContractRenewalModel(
      id: json['id']?.toString() ?? '',
      contractId: json['contractId']?.toString() ?? '',
      newEndDate: json['newEndDate']?.toString() ?? '',
      newMonthlyRentVnd: (json['newMonthlyRentVnd'] as num?)?.toDouble(),
      renewalValueVnd: (json['renewalValueVnd'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: json['createdAtUtc']?.toString() ?? '',
    );
  }
}

class ZoneContractModel {
  final String id;
  final String tenantId;
  final String farmId;
  final String farmName;
  final String zoneId;
  final String zoneName;
  final String? parentContractId;
  final String? parentContractNumber;
  final String contractNumber;
  final String? cropType;
  final double monthlyRentVnd;
  final double depositVnd;
  final double totalContractValueVnd;
  final String startDate;
  final String endDate;
  final String status; // 'Active', 'Expired', 'Renewed', 'Terminated'
  final String statusText;
  final int daysRemaining;
  final String lesseeName;
  final String? lesseePhone;
  final String? lesseeIdentityNumber;
  final String? lesseeAddress;
  final String? specialTerms;
  final String? notes;
  final String? signedAtUtc;
  final List<ZoneContractRenewalModel> renewals;
  final String createdAt;

  const ZoneContractModel({
    required this.id,
    required this.tenantId,
    required this.farmId,
    required this.farmName,
    required this.zoneId,
    required this.zoneName,
    this.parentContractId,
    this.parentContractNumber,
    required this.contractNumber,
    this.cropType,
    required this.monthlyRentVnd,
    required this.depositVnd,
    required this.totalContractValueVnd,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.statusText,
    required this.daysRemaining,
    required this.lesseeName,
    this.lesseePhone,
    this.lesseeIdentityNumber,
    this.lesseeAddress,
    this.specialTerms,
    this.notes,
    this.signedAtUtc,
    this.renewals = const [],
    required this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active' || status == '0';
  bool get isExpiringSoon => daysRemaining >= 0 && daysRemaining <= 30;

  factory ZoneContractModel.fromJson(Map<String, dynamic> json) {
    var rawRenewals = json['renewals'];
    List<ZoneContractRenewalModel> parsedRenewals = [];
    if (rawRenewals is List) {
      parsedRenewals = rawRenewals
          .map((r) => ZoneContractRenewalModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }

    final rawStatus = json['status']?.toString() ?? 'Active';
    String displayStatus = rawStatus;
    if (rawStatus == '0' || rawStatus.toLowerCase() == 'active') {
      displayStatus = 'Active';
    } else if (rawStatus == '1' || rawStatus.toLowerCase() == 'expired') {
      displayStatus = 'Expired';
    } else if (rawStatus == '2' || rawStatus.toLowerCase() == 'renewed') {
      displayStatus = 'Renewed';
    } else if (rawStatus == '3' || rawStatus.toLowerCase() == 'terminated') {
      displayStatus = 'Terminated';
    }

    return ZoneContractModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? '',
      farmName: json['farmName']?.toString() ?? 'Nông trại',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? 'Vùng trồng',
      parentContractId: json['parentContractId']?.toString(),
      parentContractNumber: json['parentContractNumber']?.toString(),
      contractNumber: json['contractNumber']?.toString() ?? 'HD-000',
      cropType: json['cropType']?.toString(),
      monthlyRentVnd: (json['monthlyRentVnd'] as num?)?.toDouble() ?? 0.0,
      depositVnd: (json['depositVnd'] as num?)?.toDouble() ?? 0.0,
      totalContractValueVnd: (json['totalContractValueVnd'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      status: displayStatus,
      statusText: json['statusText']?.toString() ?? (displayStatus == 'Active' ? 'Đang hiệu lực' : displayStatus),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      lesseeName: json['lesseeName']?.toString() ?? 'Bên thuê',
      lesseePhone: json['lesseePhone']?.toString(),
      lesseeIdentityNumber: json['lesseeIdentityNumber']?.toString(),
      lesseeAddress: json['lesseeAddress']?.toString(),
      specialTerms: json['specialTerms']?.toString(),
      notes: json['notes']?.toString(),
      signedAtUtc: json['signedAtUtc']?.toString(),
      renewals: parsedRenewals,
      createdAt: json['createdAtUtc']?.toString() ?? '',
    );
  }
}

// ─────────────────────────────────────────
// Khấu Hao Thiết Bị (Device Depreciation)
// ─────────────────────────────────────────

class DeviceDepreciationModel {
  final String id;
  final String zoneId;
  final String zoneName;
  final String deviceId;
  final String deviceName;
  final String hardwareAddress;
  final String deviceType;
  final double originalCostVnd;
  final double monthlyDepreciationVnd;
  final double accumulatedDepreciationVnd;
  final double currentBookValueVnd;
  final int depreciationLifetimeMonths;
  final int monthsElapsed;
  final int remainingMonths;
  final String method;
  final String startDate;
  final String depreciationStatus; // 'Active', 'ExpiringSoon', 'FullyDepreciated'
  final bool isNearContractRenewal;
  final String? notes;
  final String createdAt;

  const DeviceDepreciationModel({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.deviceId,
    required this.deviceName,
    required this.hardwareAddress,
    required this.deviceType,
    required this.originalCostVnd,
    required this.monthlyDepreciationVnd,
    required this.accumulatedDepreciationVnd,
    required this.currentBookValueVnd,
    required this.depreciationLifetimeMonths,
    required this.monthsElapsed,
    required this.remainingMonths,
    required this.method,
    required this.startDate,
    required this.depreciationStatus,
    required this.isNearContractRenewal,
    this.notes,
    required this.createdAt,
  });

  double get progressPercentage {
    if (depreciationLifetimeMonths <= 0) return 1.0;
    final p = monthsElapsed / depreciationLifetimeMonths;
    return p.clamp(0.0, 1.0);
  }

  factory DeviceDepreciationModel.fromJson(Map<String, dynamic> json) {
    return DeviceDepreciationModel(
      id: json['id']?.toString() ?? '',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? 'Khu vực',
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Thiết bị IoT',
      hardwareAddress: json['hardwareAddress']?.toString() ?? '',
      deviceType: json['deviceType']?.toString() ?? 'Node',
      originalCostVnd: (json['originalCostVnd'] as num?)?.toDouble() ?? 0.0,
      monthlyDepreciationVnd: (json['monthlyDepreciationVnd'] as num?)?.toDouble() ?? 0.0,
      accumulatedDepreciationVnd: (json['accumulatedDepreciationVnd'] as num?)?.toDouble() ?? 0.0,
      currentBookValueVnd: (json['currentBookValueVnd'] as num?)?.toDouble() ?? 0.0,
      depreciationLifetimeMonths: (json['depreciationLifetimeMonths'] as num?)?.toInt() ?? 24,
      monthsElapsed: (json['monthsElapsed'] as num?)?.toInt() ?? 0,
      remainingMonths: (json['remainingMonths'] as num?)?.toInt() ?? 0,
      method: json['method']?.toString() ?? 'STRAIGHT_LINE',
      startDate: json['startDate']?.toString() ?? '',
      depreciationStatus: json['depreciationStatus']?.toString() ?? 'Active',
      isNearContractRenewal: json['isNearContractRenewal'] == true,
      notes: json['notes']?.toString(),
      createdAt: json['createdAtUtc']?.toString() ?? '',
    );
  }
}

class ExpiringContractAlertModel {
  final String contractId;
  final String contractNumber;
  final String farmId;
  final String farmName;
  final String zoneId;
  final String zoneName;
  final String? cropType;
  final String endDate;
  final int daysRemaining;
  final String status;
  final double totalContractValueVnd;

  const ExpiringContractAlertModel({
    required this.contractId,
    required this.contractNumber,
    required this.farmId,
    required this.farmName,
    required this.zoneId,
    required this.zoneName,
    this.cropType,
    required this.endDate,
    required this.daysRemaining,
    required this.status,
    required this.totalContractValueVnd,
  });

  factory ExpiringContractAlertModel.fromJson(Map<String, dynamic> json) {
    return ExpiringContractAlertModel(
      contractId: json['contractId']?.toString() ?? '',
      contractNumber: json['contractNumber']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? '',
      farmName: json['farmName']?.toString() ?? '',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? '',
      cropType: json['cropType']?.toString(),
      endDate: json['endDate']?.toString() ?? '',
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Active',
      totalContractValueVnd: (json['totalContractValueVnd'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─────────────────────────────────────────
// Khung Mùa Vụ Canh Tác (Farming Season)
// ─────────────────────────────────────────

class FarmingSeasonModel {
  final String id;
  final String code;
  final String name;
  final int year;
  final String startDate;
  final String endDate;
  final String? description;
  final String status; // 'Active', 'Completed', 'Upcoming'
  final bool isActive;
  final int plantingSeasonsCount;

  const FarmingSeasonModel({
    required this.id,
    required this.code,
    required this.name,
    required this.year,
    required this.startDate,
    required this.endDate,
    this.description,
    this.status = 'Active',
    this.isActive = true,
    this.plantingSeasonsCount = 0,
  });

  factory FarmingSeasonModel.fromJson(Map<String, dynamic> json) {
    return FarmingSeasonModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Vụ mùa canh tác',
      year: (json['year'] as num?)?.toInt() ?? 2026,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      description: json['description']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      isActive: json['isActive'] != false,
      plantingSeasonsCount: (json['plantingSeasonsCount'] as num?)?.toInt() ?? 0,
    );
  }
}
