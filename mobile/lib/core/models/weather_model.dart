import 'package:flutter/material.dart';

/// Mục dự báo thời tiết theo ngày trong danh sách `dailyForecast` từ backend OpenMeteo
class DailyForecastModel {
  final DateTime date;
  final num? maxTemperature;
  final num? minTemperature;
  final num? precipitationProbability;
  final String description;

  const DailyForecastModel({
    required this.date,
    this.maxTemperature,
    this.minTemperature,
    this.precipitationProbability,
    this.description = '',
  });

  factory DailyForecastModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      final rawDate = json['date']?.toString();
      parsedDate = rawDate != null ? DateTime.parse(rawDate) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return DailyForecastModel(
      date: parsedDate,
      maxTemperature: json['maxTemperature'] as num?,
      minTemperature: json['minTemperature'] as num?,
      precipitationProbability: json['precipitationProbability'] as num?,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'maxTemperature': maxTemperature,
    'minTemperature': minTemperature,
    'precipitationProbability': precipitationProbability,
    'description': description,
  };

  /// Nhãn thứ trong tuần tiếng Việt: "Hôm nay", "Ngày mai", "T2", "T3"...
  String get dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Hôm nay';
    if (diff == 1) return 'Ngày mai';

    switch (date.weekday) {
      case DateTime.monday:
        return 'Thứ 2';
      case DateTime.tuesday:
        return 'Thứ 3';
      case DateTime.wednesday:
        return 'Thứ 4';
      case DateTime.thursday:
        return 'Thứ 5';
      case DateTime.friday:
        return 'Thứ 6';
      case DateTime.saturday:
        return 'Thứ 7';
      case DateTime.sunday:
        return 'Chủ nhật';
      default:
        return '';
    }
  }

  /// Định dạng ngày: "21/11"
  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  /// Icon đại diện theo mô tả thời tiết
  IconData get icon => WeatherModel.mapWeatherIcon(description);

  /// Màu sắc theo trạng thái thời tiết
  Color get iconColor => WeatherModel.mapWeatherColor(description);

  /// Có nguy cơ mưa cao (>= 50%)
  bool get hasHighRainRisk => (precipitationProbability ?? 0) >= 50;

  /// Kích hoạt hoãn tưới tự động (mưa > 70%)
  bool get triggersRainDelayRule => (precipitationProbability ?? 0) >= 70;
}

/// Mô hình thời tiết trang trại phân giải từ OpenMeteo theo tọa độ hiệu lực
class WeatherModel {
  final num? temperature;
  final num? humidity;
  final num? precipitationProbability;
  final num? windSpeed;
  final String weatherDescription;
  final List<DailyForecastModel> dailyForecast;
  final DateTime? lastUpdatedAtUtc;

  const WeatherModel({
    this.temperature,
    this.humidity,
    this.precipitationProbability,
    this.windSpeed,
    this.weatherDescription = 'Khí hậu địa phương',
    this.dailyForecast = const [],
    this.lastUpdatedAtUtc,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    final daily = <DailyForecastModel>[];
    if (json['dailyForecast'] is List) {
      for (final item in json['dailyForecast'] as List) {
        if (item is Map<String, dynamic>) {
          daily.add(DailyForecastModel.fromJson(item));
        } else if (item is Map) {
          daily.add(
            DailyForecastModel.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    DateTime? lastUpdate;
    try {
      final raw = json['lastUpdatedAtUtc']?.toString();
      if (raw != null) lastUpdate = DateTime.parse(raw);
    } catch (_) {}

    final directRain = json['precipitationProbability'] as num?;
    final firstDailyRain = daily.isNotEmpty
        ? daily.first.precipitationProbability
        : null;

    return WeatherModel(
      temperature: json['temperature'] as num?,
      humidity: json['humidity'] as num?,
      precipitationProbability: directRain ?? firstDailyRain,
      windSpeed: json['windSpeed'] as num?,
      weatherDescription:
          json['weatherDescription']?.toString() ?? 'Khí hậu địa phương',
      dailyForecast: daily,
      lastUpdatedAtUtc: lastUpdate,
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'humidity': humidity,
    'precipitationProbability': precipitationProbability,
    'windSpeed': windSpeed,
    'weatherDescription': weatherDescription,
    'dailyForecast': dailyForecast.map((d) => d.toJson()).toList(),
    'lastUpdatedAtUtc': lastUpdatedAtUtc?.toIso8601String(),
  };

  /// Ánh xạ từ mô tả thời tiết sang IconData Flutter Material chuẩn
  static IconData mapWeatherIcon(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('sấm') ||
        desc.contains('dông') ||
        desc.contains('giông') ||
        desc.contains('bão')) {
      return Icons.thunderstorm_rounded;
    }
    if (desc.contains('mưa rào')) {
      return Icons.grain_rounded;
    }
    if (desc.contains('mưa phùn') || desc.contains('phùn')) {
      return Icons.water_drop_outlined;
    }
    if (desc.contains('mưa')) {
      return Icons.beach_access_rounded;
    }
    if (desc.contains('sương mù') || desc.contains('sương')) {
      return Icons.cloudy_snowing;
    }
    if (desc.contains('âm u') || desc.contains('nhiều mây')) {
      return Icons.cloud_rounded;
    }
    if (desc.contains('mây')) {
      return Icons.wb_cloudy_rounded;
    }
    if (desc.contains('quang') || desc.contains('nắng')) {
      return Icons.wb_sunny_rounded;
    }
    return Icons.wb_cloudy_rounded;
  }

  /// Ánh xạ màu sắc đại diện cho thời tiết
  static Color mapWeatherColor(String description) {
    final desc = description.toLowerCase();
    if (desc.contains('sấm') ||
        desc.contains('dông') ||
        desc.contains('giông') ||
        desc.contains('bão')) {
      return const Color(0xFF818CF8);
    }
    if (desc.contains('mưa')) {
      return const Color(0xFF38BDF8);
    }
    if (desc.contains('sương')) {
      return const Color(0xFF94A3B8);
    }
    if (desc.contains('quang') || desc.contains('nắng')) {
      return const Color(0xFFFBBF24);
    }
    return const Color(0xFF99F6E4);
  }

  IconData get icon => mapWeatherIcon(weatherDescription);
  Color get iconColor => mapWeatherColor(weatherDescription);

  String get formattedTemp =>
      temperature != null ? '${temperature!.toStringAsFixed(1)}°C' : '--°C';
  String get formattedHumidity =>
      humidity != null ? '${humidity!.toInt()}%' : '--';
  String get formattedRain => precipitationProbability != null
      ? '${precipitationProbability!.toInt()}%'
      : '--';
  String get formattedWind =>
      windSpeed != null ? '${windSpeed!.toStringAsFixed(1)} km/h' : '--';

  /// Rủi ro mưa cao (ảnh hưởng kế hoạch thu hoạch hoặc tưới ngoài trời)
  bool get isRainRisk => (precipitationProbability ?? 0) >= 50;

  /// Hoãn tưới tự động (mưa > 70%)
  bool get triggersRainDelay => (precipitationProbability ?? 0) >= 70;
}
