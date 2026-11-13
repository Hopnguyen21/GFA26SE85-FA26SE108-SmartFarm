part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateGeometry on _MiniGISMapPickerState {
  List<LatLng> _generateDefaultBox(LatLng center, {double scale = 1.0}) {
    if (widget.level == 'ZONE' &&
        widget.parentPolygon != null &&
        widget.parentPolygon!.length >= 3) {
      // Ưu tiên ô nằm trọn trong thửa đất, không chồng Zone đã có và không vượt diện tích còn trống.
      final suggested = suggestZoneBox(
        parent: widget.parentPolygon!,
        others: [
          for (final z in _otherPolygons)
            if (z['polygon'] case final List<LatLng> pts) pts,
        ],
        maxAreaM2: widget.maxDefaultAreaM2,
      );
      if (suggested != null) return suggested;

      // Thửa đất không còn chỗ trống phù hợp: vẫn đặt một ô nhỏ quanh tâm để người dùng tự chỉnh (bản đồ sẽ cảnh báo).
      double minLat = double.infinity, maxLat = -double.infinity;
      double minLng = double.infinity, maxLng = -double.infinity;
      for (final p in widget.parentPolygon!) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      // Không ép kích thước tối thiểu: ô tối thiểu cũ (~66×86 m) lớn hơn cả thửa đất nhỏ nên luôn thò ra ngoài.
      final double latHalfSpan = math.min((maxLat - minLat) * 0.1, 0.0008);
      final double lngHalfSpan = math.min((maxLng - minLng) * 0.1, 0.0010);
      return [
        LatLng(center.latitude + latHalfSpan, center.longitude - lngHalfSpan),
        LatLng(center.latitude + latHalfSpan, center.longitude + lngHalfSpan),
        LatLng(center.latitude - latHalfSpan, center.longitude + lngHalfSpan),
        LatLng(center.latitude - latHalfSpan, center.longitude - lngHalfSpan),
      ];
    }

    final double baseLatDelta = widget.level == 'FARM'
        ? 0.0018
        : widget.level == 'FIELD'
        ? 0.0010
        : 0.0004;
    final double baseLngDelta = widget.level == 'FARM'
        ? 0.0025
        : widget.level == 'FIELD'
        ? 0.0014
        : 0.0005;

    final double latDelta = baseLatDelta * scale;
    final double lngDelta = baseLngDelta * scale;

    return [
      LatLng(
        center.latitude + latDelta,
        center.longitude - lngDelta,
      ), // #1 Tây Bắc
      LatLng(
        center.latitude + latDelta,
        center.longitude + lngDelta,
      ), // #2 Đông Bắc
      LatLng(
        center.latitude - latDelta,
        center.longitude + lngDelta,
      ), // #3 Đông Nam
      LatLng(
        center.latitude - latDelta,
        center.longitude - lngDelta,
      ), // #4 Tây Nam
    ];
  }

  /// Tính diện tích ước tính m2 (xấp xỉ phẳng theo kinh vĩ độ tại Việt Nam)
  double _calculateApproxAreaM2(List<LatLng> pts) {
    if (pts.length < 3) return 10000.0;
    // Công thức Shoelace polygon tính diện tích m2 chuẩn xác
    double area = 0.0;
    final int n = pts.length;
    for (int i = 0; i < n; i++) {
      final int j = (i + 1) % n;
      final LatLng p1 = pts[i];
      final LatLng p2 = pts[j];
      final double latRad = (p1.latitude * 3.141592653589793) / 180.0;
      final double x1 = p1.longitude * 111320.0 * math.cos(latRad);
      final double y1 = p1.latitude * 110540.0;
      final double x2 = p2.longitude * 111320.0 * math.cos(latRad);
      final double y2 = p2.latitude * 110540.0;
      area += (x1 * y2) - (x2 * y1);
    }
    return (area.abs() / 2.0).roundToDouble();
  }

  /// Tính tâm (centroid) của polygon hiện tại
  LatLng _getPolygonCentroid() {
    if (_polygonPoints.isEmpty) return _currentCenter;
    double sumLat = 0;
    double sumLng = 0;
    for (final p in _polygonPoints) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(
      sumLat / _polygonPoints.length,
      sumLng / _polygonPoints.length,
    );
  }

  /// Chuyển đổi độ lệch cảm ứng màn hình (DragUpdateDetails.delta) sang độ lệch tọa độ LatLng
  LatLng _screenOffsetToLatLngDelta(Offset delta) {
    try {
      final zoom = _mapController.camera.zoom;
      final latRad = _currentCenter.latitude * math.pi / 180.0;
      // Số mét tương ứng 1 pixel theo chuẩn Web Mercator ở mức zoom hiện tại
      final metersPerPixel =
          156543.03392 * math.cos(latRad) / math.pow(2, zoom);
      // 1 độ vĩ độ ~ 110540 mét; 1 độ kinh độ ~ 111320 mét * cos(lat)
      final dLat = -delta.dy * metersPerPixel / 110540.0;
      final dLng = delta.dx * metersPerPixel / (111320.0 * math.cos(latRad));
      return LatLng(dLat, dLng);
    } catch (_) {
      return LatLng(-delta.dy * 0.000005, delta.dx * 0.000005);
    }
  }

  /// Kiểm tra 1 điểm có nằm bên trong đa giác hay không (Ray-casting Algorithm)
  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    final double px = point.longitude;
    final double py = point.latitude;
    bool inside = false;
    final int n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final bool intersect =
          ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Kiểm tra 2 đa giác có giao nhau / đè lên nhau không
  bool _doPolygonsOverlap(List<LatLng> polyA, List<LatLng> polyB) {
    if (polyA.length < 3 || polyB.length < 3) return false;

    // 1. Kiểm tra đỉnh của A có nằm trong B không
    for (final pt in polyA) {
      if (_isPointInsidePolygon(pt, polyB)) return true;
    }
    // 2. Kiểm tra đỉnh của B có nằm trong A không
    for (final pt in polyB) {
      if (_isPointInsidePolygon(pt, polyA)) return true;
    }
    // 3. Kiểm tra các cạnh của A có cắt các cạnh của B không
    for (int i = 0; i < polyA.length; i++) {
      final a1 = polyA[i];
      final a2 = polyA[(i + 1) % polyA.length];
      for (int j = 0; j < polyB.length; j++) {
        final b1 = polyB[j];
        final b2 = polyB[(j + 1) % polyB.length];
        if (_MiniGISMapPickerState._segmentsIntersect(a1, a2, b1, b2))
          return true;
      }
    }
    return false;
  }

  /// Kiểm tra đỉnh có đè lên bất kỳ vùng nào khác đã có
  bool _isVertexInsideAnyOtherZone(LatLng vertex) {
    for (final z in _otherPolygons) {
      final pts = z['polygon'] as List<LatLng>?;
      if (pts != null && pts.length >= 3) {
        if (_isPointInsidePolygon(vertex, pts)) return true;
      }
    }
    return false;
  }

  /// Kiểm tra đỉnh có bị nằm ngoài viền của Thửa đất (Field) mẹ hoặc đè lên Zone khác hay không
  bool _isVertexOutsideParent(LatLng vertex) {
    if (widget.parentPolygon == null || widget.parentPolygon!.length < 3)
      return false;
    return !_isPointInsidePolygon(vertex, widget.parentPolygon!);
  }

  /// Kiểm tra xem đỉnh có bị vi phạm (ngoài Field hoặc đè vùng khác)
  bool _isVertexInvalid(LatLng vertex) {
    return _isVertexOutsideParent(vertex) ||
        _isVertexInsideAnyOtherZone(vertex);
  }

  /// Khoảng cách bình phương xấp xỉ từ điểm P tới đoạn thẳng AB
  double _distToSegment(LatLng p, LatLng a, LatLng b) {
    final double l2 =
        (b.latitude - a.latitude) * (b.latitude - a.latitude) +
        (b.longitude - a.longitude) * (b.longitude - a.longitude);
    if (l2 == 0) {
      return (p.latitude - a.latitude) * (p.latitude - a.latitude) +
          (p.longitude - a.longitude) * (p.longitude - a.longitude);
    }
    final double t =
        (((p.latitude - a.latitude) * (b.latitude - a.latitude) +
                    (p.longitude - a.longitude) * (b.longitude - a.longitude)) /
                l2)
            .clamp(0.0, 1.0);
    final double projLat = a.latitude + t * (b.latitude - a.latitude);
    final double projLng = a.longitude + t * (b.longitude - a.longitude);
    return (p.latitude - projLat) * (p.latitude - projLat) +
        (p.longitude - projLng) * (p.longitude - projLng);
  }
}
