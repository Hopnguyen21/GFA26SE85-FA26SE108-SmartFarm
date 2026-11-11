import '../../core/utils/json_utils.dart';
import '../zones/profile_irrigation_logic.dart';

// Lịch tưới tùy chỉnh THEO NGÀY của một vụ trồng (Zone + mùa vụ), lưu ở backend (season_irrigation_*):
//  - Chỉ các ngày bị người dùng sửa ("override") được lưu, khóa theo số ngày canh tác (1 = ngày bắt đầu vụ).
//  - Ngày không override dùng lịch theo giai đoạn của hồ sơ (lịch mẫu/đề xuất); lịch mẫu này KHÔNG bị sửa ở đây.
//  - Lịch điều khiển thật của thiết bị (ControlSchedule) là thứ khác, được sinh khi đồng bộ.

/// Nguồn của ca tưới trong một ngày.
enum DaySource {
  override('Override', 'Tùy chỉnh của vụ'),
  profile('Profile', 'Lịch mẫu của hồ sơ'),
  crop('Crop', 'Lịch mẫu của cây (tham khảo)'),
  none('None', 'Chưa có lịch');

  final String code;
  final String label;
  const DaySource(this.code, this.label);

  static DaySource parse(String? s) => DaySource.values.firstWhere((e) => e.code == s, orElse: () => DaySource.none);
}

class SeasonDay {
  final int dayNumber;
  final String date; // yyyy-MM-dd (theo ngày bắt đầu hiện tại của vụ)
  final String? stageId;
  final String? stageName;
  final DaySource source;
  final bool outOfRange;
  final List<ProfileSession> sessions;

  const SeasonDay({
    required this.dayNumber,
    required this.date,
    required this.stageId,
    required this.stageName,
    required this.source,
    required this.outOfRange,
    required this.sessions,
  });

  bool get isOverride => source == DaySource.override;
  int get enabledCount => sessions.where((s) => s.enabled).length;

  /// "dd/MM" từ yyyy-MM-dd.
  String get shortDate {
    final p = date.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}' : date;
  }

  factory SeasonDay.fromJson(Map<String, dynamic> j) => SeasonDay(
    dayNumber: jsonNumber(jsonField(j, 'dayNumber'))?.toInt() ?? 0,
    date: '${jsonField(j, 'date') ?? ''}',
    stageId: jsonField(j, 'stageId')?.toString(),
    stageName: jsonField(j, 'stageName')?.toString(),
    source: DaySource.parse(jsonField(j, 'source')?.toString()),
    outOfRange: jsonField(j, 'outOfRange') == true,
    sessions: [
      for (final s in jsonList(jsonField(j, 'sessions')))
        if (s is Map) ProfileSession.fromJson(Map<String, dynamic>.from(s)),
    ],
  );
}

class SeasonIrrigationCalendar {
  final String seasonId;
  final String zoneId;
  final String seasonName;
  final String seasonStatus;
  final String profileId;
  final String profileName;
  final String startDate;
  final int totalDays;
  final int? todayDayNumber;
  final String timeZone;
  final String status; // NoOverrides | Current | Stale
  final List<String> staleReasons;
  final int overrideDayCount;
  final bool isEditable;
  final String? updatedAtUtc;
  final List<SeasonDay> days;

  const SeasonIrrigationCalendar({
    required this.seasonId,
    required this.zoneId,
    required this.seasonName,
    required this.seasonStatus,
    required this.profileId,
    required this.profileName,
    required this.startDate,
    required this.totalDays,
    required this.todayDayNumber,
    required this.timeZone,
    required this.status,
    required this.staleReasons,
    required this.overrideDayCount,
    required this.isEditable,
    required this.updatedAtUtc,
    required this.days,
  });

  bool get isStale => status == 'Stale';
  bool get hasOverrides => overrideDayCount > 0;

  /// Các ngày nằm trong vụ (không gồm ngày override đã vượt quá cuối vụ).
  List<SeasonDay> get inRangeDays => [
    for (final d in days)
      if (!d.outOfRange) d,
  ];
  List<SeasonDay> get outOfRangeDays => [
    for (final d in days)
      if (d.outOfRange) d,
  ];

  SeasonDay? day(int n) => days.where((d) => d.dayNumber == n && !d.outOfRange).firstOrNull;
  SeasonDay? get today => todayDayNumber == null ? null : day(todayDayNumber!);

  /// Tên các giai đoạn theo thứ tự xuất hiện (dùng cho bộ lọc).
  List<({String id, String name})> get stages {
    final seen = <String>{};
    final out = <({String id, String name})>[];
    for (final d in inRangeDays) {
      final id = d.stageId;
      if (id != null && seen.add(id)) out.add((id: id, name: d.stageName ?? 'Giai đoạn'));
    }
    return out;
  }

  factory SeasonIrrigationCalendar.fromJson(Map<String, dynamic> j) => SeasonIrrigationCalendar(
    seasonId: '${jsonField(j, 'seasonId') ?? ''}',
    zoneId: '${jsonField(j, 'zoneId') ?? ''}',
    seasonName: '${jsonField(j, 'seasonName') ?? ''}',
    seasonStatus: '${jsonField(j, 'seasonStatus') ?? ''}',
    profileId: '${jsonField(j, 'growthProfileId') ?? ''}',
    profileName: '${jsonField(j, 'growthProfileName') ?? ''}',
    startDate: '${jsonField(j, 'startDate') ?? ''}',
    totalDays: jsonNumber(jsonField(j, 'totalDays'))?.toInt() ?? 0,
    todayDayNumber: jsonNumber(jsonField(j, 'todayDayNumber'))?.toInt(),
    timeZone: '${jsonField(j, 'timeZone') ?? ''}',
    status: '${jsonField(j, 'status') ?? 'NoOverrides'}',
    staleReasons: [for (final r in jsonList(jsonField(j, 'staleReasons'))) '$r'],
    overrideDayCount: jsonNumber(jsonField(j, 'overrideDayCount'))?.toInt() ?? 0,
    isEditable: jsonField(j, 'isEditable') == true,
    updatedAtUtc: jsonField(j, 'updatedAtUtc')?.toString(),
    days: [
      for (final d in jsonList(jsonField(j, 'days')))
        if (d is Map) SeasonDay.fromJson(Map<String, dynamic>.from(d)),
    ],
  );
}

/// Giải thích dễ hiểu cho lý do "Stale" mà backend trả về (dữ liệu KHÔNG bị xóa).
String staleReasonText(String code) => switch (code) {
  'StartDateChanged' => 'Ngày bắt đầu của vụ đã đổi sau lần lưu cuối: các ngày tùy chỉnh dịch theo số ngày canh tác.',
  'DurationChanged' => 'Số ngày của vụ đã đổi sau lần lưu cuối.',
  'ProfileChanged' => 'Hồ sơ của vụ đã đổi: các ngày tùy chỉnh vẫn giữ, hãy kiểm tra lại với lịch mẫu mới.',
  'DaysOutOfRange' => 'Có ngày tùy chỉnh nằm ngoài vụ (vụ ngắn hơn). Chúng được giữ lại nhưng bị bỏ qua khi đồng bộ.',
  _ => code,
};

/// Body PUT một ngày.
Map<String, dynamic> dayIrrigationPayload(int dayNumber, List<ProfileSession> sessions) => {
  'dayNumber': dayNumber,
  'sessions': [for (final s in sessions) s.toJson()],
};

/// Các ngày để áp dụng ca của một ngày: cả giai đoạn của ngày đó hoặc cả vụ (không gồm ngày ngoài vụ).
List<int> targetDays(SeasonIrrigationCalendar c, SeasonDay from, {required bool wholeSeason}) => [
  for (final d in c.inRangeDays)
    if (wholeSeason || (from.stageId != null && d.stageId == from.stageId)) d.dayNumber,
];

/// Tên nguồn lịch mà việc đồng bộ thiết bị đã dùng, theo trường `source` của kết quả sync.
String syncSourceText(Map<String, dynamic> r) {
  final day = r['dayNumber'];
  return switch ('${r['source']}') {
    'SeasonOverride' => 'lịch tùy chỉnh của ngày ${day ?? 'hôm nay'} trong vụ',
    'Profile' => 'ca lưu trong hồ sơ theo giai đoạn',
    _ => 'lịch mẫu của cây vì hồ sơ chưa có ca',
  };
}
