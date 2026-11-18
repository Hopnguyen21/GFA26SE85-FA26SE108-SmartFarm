import '../zones/zone_climate_logic.dart' show normalizeParameterCode;

/// Tham số môi trường mà backend hỗ trợ cho quy tắc cảnh báo (EnvironmentalParameterCode) kèm nhãn và đơn vị.
const alertParameters = <String, ({String label, String unit})>{
  'Temperature': (label: 'Nhiệt độ không khí', unit: '°C'),
  'SoilMoisture': (label: 'Độ ẩm đất', unit: '%'),
  'AirHumidity': (label: 'Độ ẩm không khí', unit: '%'),
  'Ph': (label: 'pH đất', unit: 'pH'),
  'LightIntensity': (label: 'Ánh sáng', unit: 'lux'),
  'Ec': (label: 'Độ dẫn điện EC', unit: 'mS/cm'),
};

/// Về mã chuẩn của backend (không phân biệt hoa thường, "light" = "LightIntensity"); null nếu không hỗ trợ.
String? canonicalParameter(String? raw) {
  final n = normalizeParameterCode(raw);
  for (final k in alertParameters.keys) {
    if (normalizeParameterCode(k) == n) return k;
  }
  return null;
}

String parameterLabel(String code) =>
    alertParameters[canonicalParameter(code)]?.label ?? code;
String parameterUnit(String code) =>
    alertParameters[canonicalParameter(code)]?.unit ?? '';

const alertSeverities = <String, String>{
  'Info': 'Thông tin',
  'Warning': 'Cảnh báo',
  'Critical': 'Nghiêm trọng',
};

String severityLabel(String s) => alertSeverities[s] ?? s;

/// Nhãn mức độ như trang web: WARNING / CRITICAL (INFO cho mức thông tin của backend).
String severityCode(String s) => s.toUpperCase();

/// Tên mức độ trong biểu mẫu như web: "Cảnh báo (WARNING)", "Nguy hiểm khẩn cấp (CRITICAL)".
const alertSeverityFormLabels = <String, String>{
  'Info': 'Thông tin (INFO)',
  'Warning': 'Cảnh báo (WARNING)',
  'Critical': 'Nguy hiểm khẩn cấp (CRITICAL)',
};

const alertStatusLabels = <String, String>{
  'Open': 'Đang mở',
  'Acknowledged': 'Đã xác nhận',
  'Resolved': 'Đã xử lý',
};

/// Kiểm tra form quy tắc theo đúng luật backend (min < max; chờ 1–1440 phút). null = hợp lệ.
String? validateRuleInput({
  required double? min,
  required double? max,
  required int? cooldownMinutes,
}) {
  if (min == null || max == null)
    return 'Nhập ngưỡng thấp nhất và cao nhất là số.';
  if (min >= max) return 'Ngưỡng thấp nhất phải nhỏ hơn ngưỡng cao nhất.';
  if (cooldownMinutes == null ||
      cooldownMinutes < 1 ||
      cooldownMinutes > 1440) {
    return 'Thời gian chờ giữa hai lần cảnh báo phải từ 1 đến 1440 phút.';
  }
  return null;
}

/// Số đo hiện tại có nằm ngoài dải của quy tắc không (chỉ đánh giá khi quy tắc bật và có số đo mới).
bool isViolating({
  required bool ruleActive,
  required double? current,
  required double min,
  required double max,
}) => ruleActive && current != null && (current < min || current > max);

/// Số đo mới nhất của một tham số trên Zone (null khi số đo cũ hoặc chưa có), dùng cho nhãn "Thực tế".
double? currentValueOf(
  String parameterCode, {
  required bool telemetryFresh,
  required double temp,
  required double soil,
  required double humidity,
  required double lux,
}) {
  if (!telemetryFresh) return null;
  return switch (canonicalParameter(parameterCode)) {
    'Temperature' => temp,
    'SoilMoisture' => soil,
    'AirHumidity' => humidity,
    'LightIntensity' => lux,
    _ => null, // pH/EC không có trên ZoneModel
  };
}
