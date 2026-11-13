import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Diện tích xấp xỉ (m²) của đa giác theo kinh/vĩ độ (công thức Shoelace trên mặt phẳng cục bộ).
double polygonAreaM2(List<LatLng> pts) {
  if (pts.length < 3) return 0;
  final cosLat = math.cos(pts.first.latitude * math.pi / 180.0);
  double area = 0;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    area +=
        (a.longitude * 111320.0 * cosLat) * (b.latitude * 110540.0) -
        (b.longitude * 111320.0 * cosLat) * (a.latitude * 110540.0);
  }
  return area.abs() / 2.0;
}

bool _inside(LatLng p, List<LatLng> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].longitude, yi = poly[i].latitude;
    final xj = poly[j].longitude, yj = poly[j].latitude;
    if (((yi > p.latitude) != (yj > p.latitude)) &&
        (p.longitude < (xj - xi) * (p.latitude - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}

bool _cross(LatLng a, LatLng b, LatLng c, LatLng d) {
  double ccw(LatLng p, LatLng q, LatLng r) =>
      (q.longitude - p.longitude) * (r.latitude - p.latitude) -
      (q.latitude - p.latitude) * (r.longitude - p.longitude);
  final d1 = ccw(c, d, a), d2 = ccw(c, d, b);
  final d3 = ccw(a, b, c), d4 = ccw(a, b, d);
  return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
      ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0));
}

bool _edgesCross(List<LatLng> a, List<LatLng> b) {
  for (var i = 0; i < a.length; i++) {
    for (var j = 0; j < b.length; j++) {
      if (_cross(a[i], a[(i + 1) % a.length], b[j], b[(j + 1) % b.length])) {
        return true;
      }
    }
  }
  return false;
}

bool _overlap(List<LatLng> a, List<LatLng> b) =>
    a.any((p) => _inside(p, b)) ||
    b.any((p) => _inside(p, a)) ||
    _edgesCross(a, b);

/// Gợi ý ranh giới mặc định (hình chữ nhật, thứ tự TB, ĐB, ĐN, TN) cho một Zone mới:
/// nằm TRỌN trong thửa đất [parent], KHÔNG chồng lên các Zone đã có [others], và diện tích không vượt [maxAreaM2] (nếu có).
/// Ưu tiên ô lớn nhất còn đặt được, gần tâm thửa đất nhất. Trả null khi thửa đất không còn chỗ trống phù hợp.
List<LatLng>? suggestZoneBox({
  required List<LatLng> parent,
  List<List<LatLng>> others = const [],
  double? maxAreaM2,
}) {
  if (parent.length < 3) return null;
  var minLat = double.infinity, maxLat = -double.infinity;
  var minLng = double.infinity, maxLng = -double.infinity;
  var sumLat = 0.0, sumLng = 0.0;
  for (final p in parent) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
    sumLat += p.latitude;
    sumLng += p.longitude;
  }
  final dLat = maxLat - minLat, dLng = maxLng - minLng;
  if (dLat <= 0 || dLng <= 0) return null;
  final cLat = sumLat / parent.length, cLng = sumLng / parent.length;
  final zones = [
    for (final z in others)
      if (z.length >= 3) z,
  ];

  const grid = 12;
  final centers = <(double lat, double lng, double dist)>[
    for (var i = 0; i < grid; i++)
      for (var j = 0; j < grid; j++)
        () {
          final lat = minLat + (i + 0.5) / grid * dLat;
          final lng = minLng + (j + 0.5) / grid * dLng;
          final ny = (lat - cLat) / dLat, nx = (lng - cLng) / dLng;
          return (lat, lng, nx * nx + ny * ny);
        }(),
  ]..sort((a, b) => a.$3.compareTo(b.$3));

  // Nửa cạnh của ô tính theo tỉ lệ khung bao thửa đất: thử từ lớn đến nhỏ.
  for (final half in const [0.25, 0.2, 0.15, 0.11, 0.08, 0.05, 0.03]) {
    final hLat = dLat * half, hLng = dLng * half;
    for (final c in [(cLat, cLng, 0.0), ...centers]) {
      final box = [
        LatLng(c.$1 + hLat, c.$2 - hLng),
        LatLng(c.$1 + hLat, c.$2 + hLng),
        LatLng(c.$1 - hLat, c.$2 + hLng),
        LatLng(c.$1 - hLat, c.$2 - hLng),
      ];
      if (maxAreaM2 != null && polygonAreaM2(box) > maxAreaM2) break;
      if (!box.every((p) => _inside(p, parent))) continue;
      if (_edgesCross(box, parent)) continue;
      if (zones.any((z) => _overlap(box, z))) continue;
      return box;
    }
  }
  return null;
}
