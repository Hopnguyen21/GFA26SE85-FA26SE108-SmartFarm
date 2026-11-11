import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Kết quả đọc `BoundaryGeoJson` từ backend. Phân biệt rõ 3 trường hợp:
///  - chưa có ranh giới (`points == null && problem == null`),
///  - có ranh giới hợp lệ (`points != null`),
///  - có dữ liệu nhưng không đọc được (`problem != null`) — KHÔNG được coi là "chưa có ranh giới".
class GeoParseResult {
  final List<LatLng>? points;
  final String? problem;
  const GeoParseResult({this.points, this.problem});
  bool get isMissing => points == null && problem == null;
}

/// Đọc GeoJSON Polygon. Backend trả object JSON; vẫn chấp nhận chuỗi JSON và Feature để không vỡ khi định dạng đổi.
/// Thứ tự toạ độ GeoJSON là [kinh độ, vĩ độ] nên đảo lại thành LatLng(vĩ độ, kinh độ).
GeoParseResult parseGeoJsonPolygon(dynamic raw) {
  if (raw == null) return const GeoParseResult();
  try {
    var value = raw;
    if (value is String) {
      if (value.trim().isEmpty || value.trim() == 'null') return const GeoParseResult();
      value = jsonDecode(value);
    }
    if (value is! Map) return const GeoParseResult(problem: 'Ranh giới không phải đối tượng GeoJSON.');
    if (value['type'] == 'Feature' && value['geometry'] != null) return parseGeoJsonPolygon(value['geometry']);
    final type = value['type'];
    if (type != null && type != 'Polygon') {
      return GeoParseResult(problem: 'Loại hình học "$type" chưa được hỗ trợ (cần Polygon).');
    }
    final coordinates = value['coordinates'];
    if (coordinates is! List || coordinates.isEmpty || coordinates[0] is! List) {
      return const GeoParseResult(problem: 'Thiếu mảng toạ độ của Polygon.');
    }
    final ring = coordinates[0] as List;
    final pts = <LatLng>[];
    for (final c in ring) {
      double? lng;
      double? lat;
      if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
        lng = (c[0] as num).toDouble();
        lat = (c[1] as num).toDouble();
      } else if (c is String) {
        final parts = c.trim().split(RegExp(r'[\s,]+'));
        if (parts.length >= 2) {
          lng = double.tryParse(parts[0]);
          lat = double.tryParse(parts[1]);
        }
      }
      if (lng == null || lat == null) {
        return const GeoParseResult(problem: 'Có đỉnh không hợp lệ trong toạ độ [kinh độ, vĩ độ].');
      }
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        return GeoParseResult(problem: 'Toạ độ ngoài phạm vi hợp lệ (vĩ độ $lat, kinh độ $lng).');
      }
      pts.add(LatLng(lat, lng));
    }
    final distinct = {for (final p in pts) '${p.latitude},${p.longitude}'};
    if (distinct.length < 3) return const GeoParseResult(problem: 'Ranh giới cần ít nhất 3 đỉnh khác nhau.');
    return GeoParseResult(points: pts);
  } catch (e) {
    return GeoParseResult(problem: 'Không đọc được GeoJSON: $e');
  }
}
