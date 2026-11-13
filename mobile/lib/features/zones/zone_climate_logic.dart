import '../../core/utils/json_utils.dart';
import 'zone_crop_plan_logic.dart';

// Logic thuần cho tab "Vi khí hậu" của Zone Detail. Hai nguồn độc lập, KHÔNG suy đoán lẫn nhau:
//  - Telemetry mới nhất của Zone (GET /zones/{id}/telemetry/latest): số đo, thời điểm, cờ isFresh từ backend;
//  - Ngưỡng: của hồ sơ canh tác GẮN TRỰC TIẾP cho Zone, ở GIAI ĐOẠN hiện tại của vụ đang canh tác.
// Thiếu một trong hai thì không đánh giá đạt/không đạt (không dùng ngưỡng giả).

/// Mã tham số chuẩn hóa: 'light' → 'lightintensity', bỏ dấu gạch dưới, chữ thường.
String normalizeParameterCode(Object? raw) {
  final code = '$raw'.replaceAll('_', '').toLowerCase();
  return switch (code) {
    'light' => 'lightintensity',
    'soilph' => 'ph',
    'soilec' => 'ec',
    _ => code,
  };
}

class TelemetryMetric {
  final String code; // đã chuẩn hóa
  final double value;
  final String unit;
  final DateTime? capturedAtUtc;
  final bool isFresh;
  final String
  thresholdStatus; // do backend tính theo vụ đang chạy (có thể rỗng/Unknown)

  const TelemetryMetric({
    required this.code,
    required this.value,
    required this.unit,
    required this.capturedAtUtc,
    required this.isFresh,
    required this.thresholdStatus,
  });
}

class ZoneTelemetrySnapshot {
  final DateTime? latestReceivedAtUtc;
  final bool hasFreshTelemetry;
  final Map<String, TelemetryMetric> metrics;

  const ZoneTelemetrySnapshot({
    required this.latestReceivedAtUtc,
    required this.hasFreshTelemetry,
    required this.metrics,
  });

  bool get isEmpty => metrics.isEmpty;

  factory ZoneTelemetrySnapshot.fromJson(Map<String, dynamic> j) {
    final metrics = <String, TelemetryMetric>{};
    for (final m in jsonList(jsonField(j, 'metrics'))) {
      if (m is! Map) continue;
      final value = jsonNumber(jsonField(m, 'value'));
      final code = normalizeParameterCode(jsonField(m, 'parameterCode'));
      if (value == null || code.isEmpty) continue; // không bịa số đo
      metrics[code] = TelemetryMetric(
        code: code,
        value: value,
        unit: '${jsonField(m, 'unit') ?? ''}',
        capturedAtUtc: DateTime.tryParse(
          '${jsonField(m, 'capturedAtUtc') ?? ''}',
        )?.toUtc(),
        isFresh: jsonField(m, 'isFresh') == true,
        thresholdStatus: '${jsonField(m, 'thresholdStatus') ?? ''}',
      );
    }
    return ZoneTelemetrySnapshot(
      latestReceivedAtUtc: DateTime.tryParse(
        '${jsonField(j, 'latestReceivedAtUtc') ?? ''}',
      )?.toUtc(),
      hasFreshTelemetry: jsonField(j, 'hasFreshTelemetry') == true,
      metrics: metrics,
    );
  }
}

/// Giai đoạn hiện tại của Zone trong HỒ SƠ GẮN CHO ZONE: chỉ xác định được khi Zone có vụ đang canh tác (API tính
/// `seasonStatus == InProgress`) và tên giai đoạn của vụ trùng một giai đoạn của hồ sơ. Không đoán giai đoạn đầu tiên.
StageDraft? currentStageOfZone({
  required List<StageDraft> profileStages,
  required String seasonStatus,
  required String currentStageName,
}) {
  if (seasonStatus != 'InProgress') return null;
  final name = currentStageName.trim().toLowerCase();
  if (name.isEmpty) return null;
  return profileStages
      .where((s) => s.name.trim().toLowerCase() == name)
      .firstOrNull;
}

enum MetricVerdict { ok, below, above, noThreshold, stale, noData }

/// Đánh giá một số đo theo ngưỡng của giai đoạn. Số đo cũ → [MetricVerdict.stale] (không đánh giá);
/// không có ngưỡng cho tham số này → [MetricVerdict.noThreshold].
MetricVerdict evaluateMetric(
  TelemetryMetric? metric,
  RequirementDraft? requirement,
) {
  if (metric == null) return MetricVerdict.noData;
  if (!metric.isFresh) return MetricVerdict.stale;
  if (requirement == null) return MetricVerdict.noThreshold;
  if (metric.value < requirement.min) return MetricVerdict.below;
  if (metric.value > requirement.max) return MetricVerdict.above;
  return MetricVerdict.ok;
}

/// "vừa xong", "5 phút trước", "3 giờ trước", "2 ngày trước"; null khi không có thời điểm.
String? ageText(DateTime? whenUtc, DateTime nowUtc) {
  if (whenUtc == null) return null;
  final d = nowUtc.difference(whenUtc);
  if (d.isNegative || d.inMinutes < 1) return 'vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  return '${d.inDays} ngày trước';
}
