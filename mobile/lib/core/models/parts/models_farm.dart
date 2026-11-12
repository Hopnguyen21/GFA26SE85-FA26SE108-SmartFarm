part of '../models.dart';

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

  /// Số Zone / Thửa đất của farm do backend đếm (GET /farms). Null khi backend không trả — khi đó UI không được suy ra
  /// từ danh sách Zone đã tải, vì danh sách đó chỉ chứa farm đang chọn.
  final int? zonesCount;
  final int? fieldsCount;

  FarmModel({
    required this.farmId,
    required this.name,
    required this.address,
    this.province = '',
    this.district = '',
    this.ward = '',
    this.addressDetail = '',
    this.legacyLocationName = '',
    required this.totalAreaM2,
    this.latitude = 0,
    this.longitude = 0,
    this.zonesCount,
    this.fieldsCount,
  });

  String get formattedArea {
    final ha = totalAreaM2 / 10000.0;
    return '${totalAreaM2.toStringAsFixed(0)} m² (${ha.toStringAsFixed(2)} ha)';
  }

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    return FarmModel(
      farmId: json['farmId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Nông trại',
      address:
          json['locationText']?.toString() ?? json['address']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      ward: json['ward']?.toString() ?? '',
      addressDetail: json['addressDetail']?.toString() ?? '',
      legacyLocationName: json['legacyLocationName']?.toString() ?? '',
      totalAreaM2: (json['totalAreaM2'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      zonesCount: (json['zonesCount'] as num?)?.toInt(),
      fieldsCount: (json['fieldsCount'] as num?)?.toInt(),
    );
  }
}

class ZoneAccessItem {
  final String zoneId;
  final bool canControl;
  const ZoneAccessItem({required this.zoneId, required this.canControl});
}

class FarmerModel {
  final String farmerId;
  final String name;
  final String
  role; // Nông dân Thực địa (CF2), Kỹ thuật viên IoT (CF1), Quản lý vườn
  final String phone;
  final String email;
  final String username;
  final String? avatar;
  final String? farmId; // Gắn với nông trại của owner
  final bool isActive;
  final String joinedDate;
  final List<String> assignedZoneNames;
  final List<ZoneAccessItem> zoneAccess;
  final List<String>
  permissions; // CAN_CONTROL_PUMP, CAN_LOG_DIARY, CAN_VIEW_REPORTS, CAN_CONFIG_SCHEDULE, CAN_MANAGE_HARDWARE

  FarmerModel({
    required this.farmerId,
    required this.name,
    required this.role,
    required this.phone,
    this.email = '',
    this.username = '',
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
    if ((zoneAccess != null &&
            zoneAccess.any((z) => z['canControl'] == true)) ||
        (rawPerms != null && rawPerms.contains('CAN_CONTROL_PUMP')) ||
        json['canControl'] == true) {
      permissionsList.add('CAN_CONTROL_PUMP');
    }

    return FarmerModel(
      farmerId:
          json['userId']?.toString() ?? json['farmerId']?.toString() ?? '',
      name:
          json['fullName']?.toString() ??
          json['name']?.toString() ??
          'Nông dân',
      role: displayRole,
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['email']?.toString() ?? '',
      farmId: json['farmId']?.toString(),
      isActive:
          json['status']?.toString() == 'Active' || json['status'] == null,
      joinedDate: json['createdAtUtc'] != null
          ? json['createdAtUtc'].toString().substring(0, 10)
          : '01/2026',
      assignedZoneNames: const [],
      zoneAccess: [
        for (final z in zoneAccess ?? const [])
          ZoneAccessItem(
            zoneId: z['zoneId']?.toString() ?? '',
            canControl: z['canControl'] == true,
          ),
      ],
      permissions: permissionsList,
    );
  }
}

String? _nonEmpty(String? v) =>
    (v == null || v.isEmpty || v == 'null') ? null : v;

class FieldModel {
  final String fieldId;
  final String farmId;
  final String name;
  final String description;
  final double areaM2;
  final List<LatLng>? polygon;

  /// Có dữ liệu ranh giới nhưng không đọc được (khác với chưa có ranh giới).
  final String? boundaryProblem;

  FieldModel({
    required this.fieldId,
    required this.farmId,
    required this.name,
    required this.description,
    required this.areaM2,
    this.polygon,
    this.boundaryProblem,
  });

  factory FieldModel.fromJson(
    Map<String, dynamic> json, {
    String defaultFarmId = '',
  }) {
    // Backend trả BoundaryGeoJson dạng object JSON (camelCase mặc định); giữ fallback PascalCase.
    final geo = parseGeoJsonPolygon(
      json['BoundaryGeoJson'] ?? json['boundaryGeoJson'],
    );

    return FieldModel(
      fieldId: json['FieldId']?.toString() ?? json['fieldId']?.toString() ?? '',
      farmId:
          json['FarmId']?.toString() ??
          json['farmId']?.toString() ??
          defaultFarmId,
      name: json['Name']?.toString() ?? json['name']?.toString() ?? 'Lô đất',
      description:
          json['SoilType']?.toString() ??
          json['soilType']?.toString() ??
          'Đất đỏ bazan màu mỡ',
      areaM2: ((json['AreaM2'] ?? json['areaM2']) as num?)?.toDouble() ?? 0.0,
      polygon: geo.points,
      boundaryProblem: geo.problem,
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

  /// None | InProgress | Mismatch | PlannedOnly (do API tính; vụ chỉ cho giai đoạn khi cùng cây với Zone).
  final String seasonStatus;

  /// Zone chưa có vụ đang canh tác (chưa có vụ hoặc chỉ có vụ dự kiến): hiển thị gợi ý tạo vụ trên web.
  bool get needsSeason =>
      seasonStatus == 'None' || seasonStatus == 'PlannedOnly';
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
  final String? boundaryProblem;

  /// Hồ sơ canh tác gắn TRỰC TIẾP với Zone (backend Zone.GrowthProfileId); null = chưa gắn. Không phụ thuộc vụ mùa.
  final String? growthProfileId;
  final String? growthProfileName;
  final bool? growthProfileIsSystem;

  /// Ghi chú của Zone (backend ghi đè khi PUT, nên mọi lần cập nhật phải gửi lại giá trị này để không làm mất).
  final String? notes;

  ZoneModel({
    required this.zoneId,
    required this.farmId,
    this.farmName = '',
    this.fieldId = '',
    this.fieldName = '',
    required this.name,
    required this.currentCrop,
    required this.currentStage,
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
    this.boundaryProblem,
    this.growthProfileId,
    this.growthProfileName,
    this.growthProfileIsSystem,
    this.notes,
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
    bool clearAssignedWorker = false,
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
      cropContextIsDbBacked:
          cropContextIsDbBacked ?? this.cropContextIsDbBacked,
      assignedWorkerName: clearAssignedWorker
          ? null
          : (assignedWorkerName ?? this.assignedWorkerName),
      workerRole: clearAssignedWorker ? null : (workerRole ?? this.workerRole),
      polygon: polygon ?? this.polygon,
      boundaryProblem: polygon != null ? null : boundaryProblem,
      growthProfileId: growthProfileId,
      growthProfileName: growthProfileName,
      growthProfileIsSystem: growthProfileIsSystem,
      notes: notes,
    );
  }

  factory ZoneModel.fromJson(
    Map<String, dynamic> json, {
    String farmId = '',
    String fieldId = '',
    String farmName = '',
    String fieldName = '',
  }) {
    // GET trả BoundaryGeoJson; phản hồi PUT có thể là PolygonGeoJson.
    final geo = parseGeoJsonPolygon(
      json['BoundaryGeoJson'] ??
          json['boundaryGeoJson'] ??
          json['PolygonGeoJson'] ??
          json['polygonGeoJson'],
    );

    // Helper để đọc key PascalCase trước, fallback camelCase (backend ASP.NET mặc định PascalCase).
    String? fieldStr(String pascal) =>
        json[pascal]?.toString() ??
        json[pascal[0].toLowerCase() + pascal.substring(1)]?.toString();
    num? fieldNum(String pascal) =>
        (json[pascal] ?? json[pascal[0].toLowerCase() + pascal.substring(1)])
            as num?;

    final seasonSt = fieldStr('SeasonStatus') ?? 'None';
    final plannedCrop = fieldStr('PlannedCrop');
    final seasonCropName = fieldStr('SeasonCropName');

    return ZoneModel(
      zoneId: fieldStr('ZoneId') ?? '',
      farmId: fieldStr('FarmId') ?? farmId,
      farmName: farmName.isNotEmpty ? farmName : 'Nông trại SmartFarm',
      fieldId: fieldStr('FieldId') ?? fieldId,
      fieldName: fieldName.isNotEmpty ? fieldName : 'Lô đất',
      name: fieldStr('Name') ?? 'Nhà màng',
      // Cây là thuộc tính của Zone; giai đoạn chỉ có khi vụ đang canh tác cùng cây. Không có thì hiển thị trạng thái rỗng, không dùng giá trị mặc định.
      currentCrop:
          fieldStr('CurrentCrop') ??
          (seasonSt == 'PlannedOnly' && plannedCrop != null
              ? 'Chưa gán cây (vụ dự kiến: $plannedCrop)'
              : 'Chưa gán cây'),
      currentStage:
          fieldStr('CurrentStage') ??
          switch (seasonSt) {
            'Mismatch' =>
              'Vụ đang chạy thuộc cây khác (${seasonCropName ?? 'không rõ'}) — cần cập nhật trên web',
            'PlannedOnly' => 'Chưa có vụ đang canh tác (có vụ dự kiến)',
            _ => 'Chưa có vụ đang canh tác',
          },
      seasonStatus: seasonSt,
      areaM2: fieldNum('AreaM2')?.toDouble() ?? 0.0,
      // Số đo thật được nạp từ API telemetry (telemetryIsFresh); chưa có thì để 0, giao diện hiển thị '—'.
      currentSoilMoisture: 0,
      currentTemp: 0,
      currentHumidity: 0,
      currentLux: 0,
      assignedWorkerName: fieldStr('AssignedWorkerName'),
      workerRole: fieldStr('AssignedWorkerName') == null ? null : 'Nông dân',
      polygon: geo.points,
      boundaryProblem: geo.problem,
      growthProfileId: _nonEmpty(fieldStr('GrowthProfileId')),
      growthProfileName: fieldStr('GrowthProfileName'),
      growthProfileIsSystem:
          (json['growthProfileIsSystemDefined'] ??
                  json['GrowthProfileIsSystemDefined'])
              as bool?,
      notes: fieldStr('Notes'),
      cropContextIsDbBacked:
          fieldStr('CurrentCrop') != null &&
          fieldStr('CurrentStage') != null &&
          (json['AppliedRequirements'] ?? json['appliedRequirements']) is List,
    );
  }
}
