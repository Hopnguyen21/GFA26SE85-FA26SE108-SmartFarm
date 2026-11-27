// Logic thuần của màn Lịch sử vi khí hậu (tách ra để kiểm thử được, không phụ thuộc giao diện).

/// Khoảng thời gian người dùng chọn.
const monitoringRanges = ['24 Giờ', '7 Ngày', '30 Ngày'];

/// Mã tham số backend theo khóa chỉ số của màn hình.
String monitoringParameterCode(String metricKey) => switch (metricKey) {
  'TEMP' => 'Temperature',
  'HUMIDITY' => 'AirHumidity',
  'LIGHT' => 'LightIntensity',
  'PH' => 'Ph',
  'EC' => 'Ec',
  _ => 'SoilMoisture',
};

String _two(int n) => n.toString().padLeft(2, '0');

/// Nhãn trục X của một mốc lịch sử theo GIỜ ĐỊA PHƯƠNG (backend trả UTC).
/// 24 giờ: "HH:mm"; 7 ngày: "dd/MM HHh" (mốc 6 giờ); 30 ngày: "dd/MM" (mốc 1 ngày).
/// Trước đây cắt chuỗi UTC (`substring(11, 16)`) nên lệch 7 giờ so với Việt Nam và mọi mốc của khoảng dài đều chỉ có giờ.
String historyBucketLabel(String? bucketStartUtc, String range) {
  final d = DateTime.tryParse(bucketStartUtc ?? '')?.toLocal();
  if (d == null) return '';
  return switch (range) {
    '7 Ngày' => '${_two(d.day)}/${_two(d.month)} ${_two(d.hour)}h',
    '30 Ngày' => '${_two(d.day)}/${_two(d.month)}',
    _ => '${_two(d.hour)}:${_two(d.minute)}',
  };
}

/// Chuỗi giá trị + nhãn của biểu đồ. Mốc không có giá trị trung bình bị bỏ CẢ giá trị lẫn nhãn,
/// để nhãn luôn cùng chỉ số với điểm (trước đây chỉ bỏ giá trị nên các điểm phía sau gắn sai nhãn).
({List<double> values, List<String> labels}) buildHistorySeries(
  List<Map<String, dynamic>> points,
  String range,
) {
  final values = <double>[];
  final labels = <String>[];
  for (final p in points) {
    final avg = p['average'];
    if (avg is! num || !avg.isFinite) continue;
    values.add(double.parse(avg.toDouble().toStringAsFixed(1)));
    labels.add(historyBucketLabel(p['bucketStartUtc']?.toString(), range));
  }
  return (values: values, labels: labels);
}

/// Định danh một lần tải (Zone + chỉ số + khoảng + thiết bị) để biết dữ liệu đang hiển thị còn khớp lựa chọn hay không.
String historyKey(
  String zoneId,
  String metricKey,
  String range, [
  String? deviceId,
]) => '$zoneId|$metricKey|$range|${deviceId ?? ''}';
