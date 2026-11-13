part of '../models.dart';

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

  int get durationDays => (endDayFromPlanting - startDayFromPlanting) > 0
      ? (endDayFromPlanting - startDayFromPlanting)
      : 1;

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

  /// Id hồ sơ sinh trưởng (growth profile) và id cây trồng thật trong CSDL.
  final String profileId;
  final String realCropId;
  final String? varietyId;

  DefaultCropProfile({
    this.profileId = '',
    this.realCropId = '',
    this.varietyId,
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

/// Dựng hồ sơ cây trồng từ dữ liệu thật của API (GET /growth-profiles + /crops).
DefaultCropProfile defaultCropProfileFromApi(
  Map<String, dynamic> p,
  Map<String, dynamic>? crop,
) {
  // Dung sai casing/danh sách bị bọc; thiếu số liệu thì 0 như trước (các màn này chưa phân biệt được "chưa có").
  double n(dynamic v) => jsonNumber(v) ?? 0;
  final rawStages =
      jsonList(
          jsonField(p, 'stages'),
        ).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort(
          (a, b) => (jsonNumber(jsonField(a, 'stageOrder')) ?? 0).compareTo(
            jsonNumber(jsonField(b, 'stageOrder')) ?? 0,
          ),
        );
  var cursor = 0;
  final stages = <GrowthStageProfile>[];
  for (final s in rawStages) {
    final days = jsonNumber(jsonField(s, 'durationDays'))?.toInt() ?? 0;
    final reqs = <String, Map<String, dynamic>>{
      for (final r in jsonList(jsonField(s, 'requirements')).whereType<Map>())
        '${jsonField(r, 'parameterCode') ?? jsonField(r, 'code')}':
            Map<String, dynamic>.from(r),
    };
    double min(String k) => n(
      reqs[k] == null
          ? null
          : jsonField(reqs[k]!, 'minValue') ?? jsonField(reqs[k]!, 'min'),
    );
    double max(String k) => n(
      reqs[k] == null
          ? null
          : jsonField(reqs[k]!, 'maxValue') ?? jsonField(reqs[k]!, 'max'),
    );
    final activities = [
      for (final k in ['description', 'fertilizerAction', 'ipmAction'])
        if ('${s[k] ?? ''}'.trim().isNotEmpty) '${s[k]}'.trim(),
    ];
    stages.add(
      GrowthStageProfile(
        stageId: '${s['stageId'] ?? ''}',
        name: '${s['name'] ?? ''}',
        nameEn: '',
        startDayFromPlanting: cursor,
        endDayFromPlanting: cursor + days,
        description: '${s['description'] ?? ''}',
        iconEmoji: '🌱',
        requirements: EnvironmentalRange(
          soilMoistureMin: min('SoilMoisture'),
          soilMoistureMax: max('SoilMoisture'),
          tempMin: min('Temperature'),
          tempMax: max('Temperature'),
          humidityMin: min('AirHumidity'),
          humidityMax: max('AirHumidity'),
          // Backend không lưu thời lượng/tần suất tưới trong ngưỡng; lịch tưới thật lấy từ API lịch tưới của hồ sơ. 0 = chưa có số liệu.
          irrigationDurationMin:
              jsonNumber(reqs['IrrigationDuration']?['targetValue'])?.toInt() ??
              0,
          irrigationFrequencyPerDay:
              jsonNumber(
                reqs['IrrigationFrequency']?['targetValue'],
              )?.toInt() ??
              0,
        ),
        keyActivities: activities,
      ),
    );
    cursor += days;
  }
  final cropName = '${p['cropName'] ?? crop?['name'] ?? ''}';
  final lower = cropName.toLowerCase();
  const emojis = {
    'cà chua': '🍅',
    'dâu': '🍓',
    'dưa': '🍈',
    'ớt': '🌶️',
    'cà rốt': '🥕',
    'xà lách': '🥬',
    'rau': '🥬',
    'hoa': '🌸',
    'lúa': '🌾',
    'ngô': '🌽',
    'bắp': '🌽',
    'khoai': '🥔',
    'cà phê': '☕',
    'nho': '🍇',
    'chuối': '🍌',
  };
  var emoji = '🌱';
  for (final e in emojis.entries) {
    if (lower.contains(e.key)) {
      emoji = e.value;
      break;
    }
  }

  List<String> pests = const [
    'Bọ trĩ',
    'Rệp muội',
    'Sâu khoang',
    'Bệnh đốm lá',
  ];
  if (lower.contains('dưa')) {
    pests = const ['Bọ phấn trắng', 'Bọ trĩ', 'Bệnh phấn trắng', 'Sương mai'];
  } else if (lower.contains('cà chua')) {
    pests = const ['Sâu đục quả', 'Bọ phấn', 'Bệnh mốc sương', 'Héo xanh'];
  } else if (lower.contains('dâu')) {
    pests = const ['Nhện đỏ', 'Bọ trĩ', 'Thối trái Botrytis', 'Phấn trắng'];
  } else if (lower.contains('cải') ||
      lower.contains('xà lách') ||
      lower.contains('rau')) {
    pests = const ['Sâu tơ', 'Bọ nhảy', 'Bệnh thối nhũn', 'Cháy lá'];
  }

  final isSystem = p['isSystemDefined'] == true;
  return DefaultCropProfile(
    profileId: '${p['profileId'] ?? ''}',
    realCropId: '${p['cropId'] ?? ''}',
    varietyId: p['varietyId']?.toString(),
    cropId:
        '${p['profileId'] ?? ''}', // khoá chọn trong giao diện = id hồ sơ sinh trưởng
    name: cropName,
    nameEn: '${crop?['scientificName'] ?? ''}',
    variety: '${p['varietyName'] ?? p['name'] ?? ''}',
    emoji: emoji,
    standardType: isSystem ? 'Hệ thống' : 'Tuỳ chỉnh',
    totalCycleDays: cursor > 0
        ? cursor
        : ((crop?['growthCycleDays'] as num?)?.toInt() ?? 0),
    description: '${p['description'] ?? crop?['description'] ?? ''}',
    origin: 'Việt Nam (TCVN 11892-1:2017)',
    difficulty: 'Trung bình',
    suitableRegion: 'Nhà màng / Nhà kính công nghệ cao',
    compatibleActuators: const ['PUMP', 'VALVE', 'FAN'],
    commonPests: pests,
    growthStages: stages,
  );
}
