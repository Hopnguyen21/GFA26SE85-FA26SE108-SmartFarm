import '../../core/utils/cron_utils.dart';

// Lịch tưới THUỘC Growth Profile, theo từng giai đoạn (backend: growth_stage_irrigation_sessions).
//  - Mọi ngày trong giai đoạn lặp hằng ngày; giờ là giờ ĐỊA PHƯƠNG theo múi giờ của Farm ("HH:mm").
//  - Thời lượng tính bằng GIÂY (1..1800, tối đa 30 phút). Lượng nước tính bằng ml cho mỗi gốc, chỉ để tham khảo.
//  - Đây là lịch KHUYẾN NGHỊ của profile; lịch điều khiển thật của thiết bị là ControlSchedule, sinh khi đồng bộ.

const maxProfileSessionsPerStage = 8;
const maxSessionSeconds = 1800;

class ProfileSession {
  final String title;
  final String startTime; // HH:mm
  final int durationSeconds;
  final bool enabled;
  final String? method;
  final int? waterPerPlantMl;

  const ProfileSession({
    required this.title,
    required this.startTime,
    required this.durationSeconds,
    this.enabled = true,
    this.method,
    this.waterPerPlantMl,
  });

  double get durationMinutes => durationSeconds / 60;

  ProfileSession copyWith({
    String? title,
    String? startTime,
    int? durationSeconds,
    bool? enabled,
    String? method,
    int? waterPerPlantMl,
    bool clearMethod = false,
    bool clearWater = false,
  }) => ProfileSession(
    title: title ?? this.title,
    startTime: startTime ?? this.startTime,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    enabled: enabled ?? this.enabled,
    method: clearMethod ? null : (method ?? this.method),
    waterPerPlantMl: clearWater
        ? null
        : (waterPerPlantMl ?? this.waterPerPlantMl),
  );

  /// Đúng schema của PUT /growth-profiles/{id}/irrigation-schedule.
  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'startTime': startTime.trim(),
    'durationSeconds': durationSeconds,
    'enabled': enabled,
    'method': ?(method == null || method!.trim().isEmpty
        ? null
        : method!.trim()),
    'waterPerPlantMl': ?waterPerPlantMl,
  };

  factory ProfileSession.fromJson(Map<String, dynamic> j) => ProfileSession(
    title: '${j['title'] ?? ''}',
    startTime: '${j['startTime'] ?? ''}',
    durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
    enabled: j['enabled'] as bool? ?? true,
    method: j['method'] as String?,
    waterPerPlantMl: (j['waterPerPlantMl'] as num?)?.toInt(),
  );
}

/// Nguồn các ca của một giai đoạn: Profile (đã lưu trong hồ sơ), Crop (hồ sơ chưa có ca, hiển thị lịch mẫu của cây, chỉ đọc), None.
class StageSchedule {
  final String stageId;
  final String name;
  final int order;
  final int durationDays;
  final String source;
  final List<ProfileSession> sessions;
  const StageSchedule({
    required this.stageId,
    required this.name,
    required this.order,
    required this.durationDays,
    required this.source,
    required this.sessions,
  });

  factory StageSchedule.fromJson(Map<String, dynamic> j) => StageSchedule(
    stageId: '${j['stageId']}',
    name: '${j['stageName'] ?? ''}',
    order: (j['stageOrder'] as num?)?.toInt() ?? 0,
    durationDays: (j['durationDays'] as num?)?.toInt() ?? 0,
    source: '${j['source'] ?? 'None'}',
    sessions: [
      for (final s in (j['sessions'] as List? ?? const []))
        if (s is Map) ProfileSession.fromJson(Map<String, dynamic>.from(s)),
    ],
  );

  bool get fromProfile => source == 'Profile';
  bool get fromCrop => source == 'Crop';
}

class ProfileSchedule {
  final String profileId;
  final String profileName;
  final bool isSystemDefined;
  final bool isEditable;
  final String repeatType;
  final String timeZone;
  final List<StageSchedule> stages;
  const ProfileSchedule({
    required this.profileId,
    required this.profileName,
    required this.isSystemDefined,
    required this.isEditable,
    required this.repeatType,
    required this.timeZone,
    required this.stages,
  });

  factory ProfileSchedule.fromJson(Map<String, dynamic> j) => ProfileSchedule(
    profileId: '${j['profileId']}',
    profileName: '${j['profileName'] ?? ''}',
    isSystemDefined: j['isSystemDefined'] as bool? ?? false,
    isEditable: j['isEditable'] as bool? ?? false,
    repeatType: '${j['repeatType'] ?? 'DAILY'}',
    timeZone: '${j['timeZone'] ?? ''}',
    stages: [
      for (final s in (j['stages'] as List? ?? const []))
        if (s is Map) StageSchedule.fromJson(Map<String, dynamic>.from(s)),
    ]..sort((a, b) => a.order.compareTo(b.order)),
  );

  /// Có ít nhất một giai đoạn có ca (từ hồ sơ hoặc từ lịch mẫu của cây).
  bool get hasAnySessions => stages.any((s) => s.sessions.isNotEmpty);
}

/// Kiểm tra các ca của MỘT giai đoạn trước khi gửi (cùng quy tắc với backend).
String? validateStageSessions(List<ProfileSession> sessions) {
  if (sessions.length > maxProfileSessionsPerStage)
    return 'Mỗi giai đoạn tối đa $maxProfileSessionsPerStage ca tưới.';
  final times = <String>{};
  for (var i = 0; i < sessions.length; i++) {
    final s = sessions[i];
    final n = i + 1;
    if (s.title.trim().isEmpty) return 'Ca $n chưa có tên.';
    final t = parseHhmm(s.startTime);
    if (t == null)
      return 'Giờ của ca $n không hợp lệ (định dạng HH:mm, 00:00–23:59).';
    if (s.durationSeconds < 1 || s.durationSeconds > maxSessionSeconds) {
      return 'Thời lượng ca $n phải từ 1 giây đến 30 phút.';
    }
    final w = s.waterPerPlantMl;
    if (w != null && (w < 0 || w > 100000))
      return 'Lượng nước ca $n phải từ 0 đến 100000 ml/gốc.';
    final normalized =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (!times.add(normalized))
      return 'Hai ca không được trùng giờ bắt đầu ($normalized).';
  }
  return null;
}

/// Body PUT cho một giai đoạn.
Map<String, dynamic> stageIrrigationPayload(
  String stageId,
  List<ProfileSession> sessions,
) => {
  'stageId': stageId,
  'sessions': [for (final s in sessions) s.toJson()],
};

/// Mô tả ngắn một ca: "Tưới sáng · 06:15 · 8 phút · 150 ml/gốc · Nhỏ giọt (tắt)".
String describeProfileSession(ProfileSession s) {
  final mins = s.durationSeconds % 60 == 0
      ? '${s.durationSeconds ~/ 60}'
      : (s.durationSeconds / 60).toStringAsFixed(1);
  final parts = [
    s.title,
    s.startTime,
    '$mins phút',
    if (s.waterPerPlantMl != null) '${s.waterPerPlantMl} ml/gốc',
    if (s.method != null && s.method!.isNotEmpty) s.method!,
  ];
  return '${parts.join(' · ')}${s.enabled ? '' : ' (tắt)'}';
}
