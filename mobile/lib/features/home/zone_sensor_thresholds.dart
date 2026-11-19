import '../../core/models/models.dart';
import '../zones/zone_climate_logic.dart' show normalizeParameterCode;
import '../zones/zone_crop_plan_logic.dart' show RequirementDraft;

/// Ngưỡng của giai đoạn hiện tại cho một tham số (ví dụ `soilmoisture`, `temperature`), lấy từ `zone.appliedRequirements`
/// (ai/context của vụ đang canh tác). null khi Zone không có ngưỡng cho tham số này.
RequirementDraft? requirementFor(ZoneModel zone, String parameterCode) {
  final code = normalizeParameterCode(parameterCode);
  for (final r in zone.appliedRequirements) {
    final d = RequirementDraft.fromJson(r);
    if (d != null && normalizeParameterCode(d.code) == code) return d;
  }
  return null;
}

String _n(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Dòng mô tả ngưỡng dưới số đo: "Ngưỡng 70–80%" hoặc lý do chưa có (không dùng số cố định).
String thresholdCaption(ZoneModel zone, String parameterCode, String unit) {
  final r = requirementFor(zone, parameterCode);
  if (r != null) return 'Ngưỡng ${_n(r.min)}–${_n(r.max)}$unit';
  return zone.seasonStatus == 'InProgress'
      ? 'Giai đoạn này chưa có ngưỡng'
      : 'Chưa có vụ đang canh tác';
}

/// true = vượt ngưỡng; false = trong ngưỡng; null = không đánh giá (số đo cũ hoặc không có ngưỡng).
bool? outOfRange(ZoneModel zone, String parameterCode, double value) {
  if (!zone.telemetryIsFresh) return null;
  final r = requirementFor(zone, parameterCode);
  if (r == null) return null;
  return value < r.min || value > r.max;
}
