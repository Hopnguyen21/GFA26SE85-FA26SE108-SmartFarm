import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class MiniGISMapPicker extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<LatLng>? onCenterChanged;
  final List<LatLng>? initialPolygon;
  final ValueChanged<List<LatLng>>? onPolygonChanged;
  final String level; // 'FARM', 'FIELD', 'ZONE'
  final List<LatLng>? parentPolygon;
  final List<Map<String, dynamic>>? existingZones; // [{name: 'Nhà màng 01', polygon: [...]}]
  final List<Map<String, dynamic>>? existingPolygons; // [{name: 'Lô đất A1', polygon: [...]}]
  final double height;
  final ValueChanged<double>? onAreaCalculated; // Callback diện tích tính toán (m²)

  final ValueChanged<String>? onAddressResolved;
  final ValueChanged<String>? onRegionNameResolved;

  const MiniGISMapPicker({
    super.key,
    required this.initialCenter,
    this.initialZoom = 16.5,
    this.onCenterChanged,
    this.onAddressResolved,
    this.onRegionNameResolved,
    this.initialPolygon,
    this.onPolygonChanged,
    this.onAreaCalculated,
    this.level = 'FARM',
    this.parentPolygon,
    this.existingZones,
    this.existingPolygons,
    this.height = 220,
  });

  @override
  State<MiniGISMapPicker> createState() => _MiniGISMapPickerState();
}

class _ResolvedAddress {
  final String address;
  final String region;
  const _ResolvedAddress(this.address, this.region);
}

class _MiniGISMapPickerState extends State<MiniGISMapPicker> {
  late final MapController _mapController;
  late LatLng _currentCenter;
  late List<LatLng> _polygonPoints;
  late final ValueNotifier<LatLng> _coordNotifier;
  Timer? _debounceTimer;
  String _mapType = 'satellite';

  int _requestId = 0; // chỉ response của request mới nhất được nhận
  bool _addressPending = false; // đã báo "đang lấy địa chỉ" cho parent chưa
  String _displayPlaceName = 'Đang định vị...';
  bool _isExpanded = false; // Trạng thái mở rộng / thu nhỏ bản đồ

  // Điều chỉnh kích thước polygon (scale) & Chọn đỉnh đang thao tác
  final double _polygonScale = 1.0;
  int? _selectedVertexIndex; // null: di chuyển toàn bộ ranh giới, 0..3: di chuyển đỉnh cụ thể #1..#4

  static const double _pinSize = 42;
  static const double _pinTipInset = 3.5; // khoảng trống dưới đầu nhọn của icon

  bool get _isLockedCenter => widget.level == 'FIELD' || widget.level == 'ZONE';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final effectiveCenter = widget.parentPolygon != null && widget.parentPolygon!.isNotEmpty
        ? _calculateCentroid(widget.parentPolygon!)
        : widget.initialCenter;
    _currentCenter = effectiveCenter;
    _coordNotifier = ValueNotifier<LatLng>(_currentCenter);
    _polygonPoints = widget.level == 'FARM'
        ? []
        : (widget.initialPolygon != null && widget.initialPolygon!.length >= 3
            ? List<LatLng>.from(widget.initialPolygon!)
            : _generateDefaultBox(_currentCenter, scale: _polygonScale));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolveAddress(_currentCenter);
        _notifyArea();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MiniGISMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCenter != oldWidget.initialCenter ||
        widget.parentPolygon != oldWidget.parentPolygon) {
      final newCenter = widget.parentPolygon != null && widget.parentPolygon!.isNotEmpty
          ? _calculateCentroid(widget.parentPolygon!)
          : widget.initialCenter;
      _currentCenter = newCenter;
      _coordNotifier.value = newCenter;
      setState(() {
        _polygonPoints = widget.level == 'FARM'
            ? []
            : _generateDefaultBox(newCenter, scale: _polygonScale);
        _selectedVertexIndex = null;
      });
      try {
        _mapController.move(newCenter, widget.initialZoom);
      } catch (_) {}
      _notifyArea();
    }
  }

  static LatLng _calculateCentroid(List<LatLng> pts) {
    if (pts.isEmpty) return const LatLng(11.9404, 108.4583);
    double lat = 0;
    double lng = 0;
    for (final p in pts) {
      lat += p.latitude;
      lng += p.longitude;
    }
    return LatLng(lat / pts.length, lng / pts.length);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _requestId++; // vô hiệu mọi request đang bay
    _coordNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _generateDefaultBox(LatLng center, {double scale = 1.0}) {
    if (widget.level == 'ZONE' &&
        widget.parentPolygon != null &&
        widget.parentPolygon!.length >= 3) {
      // Tính độ rộng của Field mẹ để tạo ô Zone nằm gọn bên trong
      double minLat = double.infinity, maxLat = -double.infinity;
      double minLng = double.infinity, maxLng = -double.infinity;
      for (final p in widget.parentPolygon!) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
      final double latHalfSpan = ((maxLat - minLat) * 0.25).clamp(0.0003, 0.0008);
      final double lngHalfSpan = ((maxLng - minLng) * 0.25).clamp(0.0004, 0.0010);
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
      LatLng(center.latitude + latDelta, center.longitude - lngDelta), // #1 Tây Bắc
      LatLng(center.latitude + latDelta, center.longitude + lngDelta), // #2 Đông Bắc
      LatLng(center.latitude - latDelta, center.longitude + lngDelta), // #3 Đông Nam
      LatLng(center.latitude - latDelta, center.longitude - lngDelta), // #4 Tây Nam
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

  void _notifyArea() {
    final area = _calculateApproxAreaM2(_polygonPoints);
    widget.onAreaCalculated?.call(area);
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
    return LatLng(sumLat / _polygonPoints.length, sumLng / _polygonPoints.length);
  }

  /// Chuyển đổi độ lệch cảm ứng màn hình (DragUpdateDetails.delta) sang độ lệch tọa độ LatLng
  LatLng _screenOffsetToLatLngDelta(Offset delta) {
    try {
      final zoom = _mapController.camera.zoom;
      final latRad = _currentCenter.latitude * math.pi / 180.0;
      // Số mét tương ứng 1 pixel theo chuẩn Web Mercator ở mức zoom hiện tại
      final metersPerPixel = 156543.03392 * math.cos(latRad) / math.pow(2, zoom);
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

      final bool intersect = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Kiểm tra 2 đoạn thẳng AB và CD có cắt nhau hay không
  static bool _segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    double ccw(LatLng p1, LatLng p2, LatLng p3) {
      return (p2.longitude - p1.longitude) * (p3.latitude - p1.latitude) -
          (p2.latitude - p1.latitude) * (p3.longitude - p1.longitude);
    }

    final double d1 = ccw(c, d, a);
    final double d2 = ccw(c, d, b);
    final double d3 = ccw(a, b, c);
    final double d4 = ccw(a, b, d);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
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
        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  /// Danh sách các polygon đã có cần tránh đè lên (Zone hoặc Field)
  List<Map<String, dynamic>> get _otherPolygons =>
      widget.existingPolygons ?? widget.existingZones ?? [];

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

  /// Tên vùng đang bị đè lên (nếu có)
  String? get _overlappedZoneName {
    if (_otherPolygons.isEmpty || _polygonPoints.length < 3) return null;
    for (final z in _otherPolygons) {
      final pts = z['polygon'] as List<LatLng>?;
      if (pts != null && pts.length >= 3) {
        if (_doPolygonsOverlap(_polygonPoints, pts)) {
          return z['name']?.toString() ?? 'Vùng khác';
        }
      }
    }
    return null;
  }

  /// Kiểm tra đỉnh có bị nằm ngoài viền của Thửa đất (Field) mẹ hoặc đè lên Zone khác hay không
  bool _isVertexOutsideParent(LatLng vertex) {
    if (widget.parentPolygon == null || widget.parentPolygon!.length < 3) return false;
    return !_isPointInsidePolygon(vertex, widget.parentPolygon!);
  }

  /// Kiểm tra xem đỉnh có bị vi phạm (ngoài Field hoặc đè vùng khác)
  bool _isVertexInvalid(LatLng vertex) {
    return _isVertexOutsideParent(vertex) || _isVertexInsideAnyOtherZone(vertex);
  }

  /// Kiểm tra xem toàn bộ ô hiện tại có đỉnh nào bị thò ra ngoài không
  bool get _hasPointOutsideParent {
    if (widget.parentPolygon == null || widget.parentPolygon!.length < 3) return false;
    return _polygonPoints.any((pt) => !_isPointInsidePolygon(pt, widget.parentPolygon!));
  }

  /// Kiểm tra đa giác có tự cắt chính nó không (hình số 8 / hình nơ)
  static bool polygonSelfIntersects(List<LatLng> pts) {
    if (pts.length < 4) return false;
    final n = pts.length;
    for (int i = 0; i < n; i++) {
      final a1 = pts[i];
      final a2 = pts[(i + 1) % n];
      for (int j = i + 1; j < n; j++) {
        // Không kiểm tra 2 cạnh kề nhau hoặc cạnh đầu-cuối trùng đỉnh
        if ((j - i).abs() <= 1) continue;
        if (i == 0 && j == n - 1) continue;
        final b1 = pts[j];
        final b2 = pts[(j + 1) % n];
        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  /// Trạng thái vi phạm: tự cắt, hoặc lòi ra ngoài Thửa đất, hoặc đè lên Vùng khác (chỉ xét ở cấp FIELD và ZONE)
  bool get _isPolygonInvalid =>
      polygonSelfIntersects(_polygonPoints) ||
      (widget.level != 'FARM' && (_hasPointOutsideParent || _overlappedZoneName != null));

  /// Cảm ứng kéo trực tiếp để di chuyển toàn bộ ô thửa đất
  void _onPolygonBodyDragUpdate(DragUpdateDetails details) {
    if (_polygonPoints.isEmpty) return;
    final dGeo = _screenOffsetToLatLngDelta(details.delta);
    setState(() {
      _polygonPoints = _shiftPolygon(_polygonPoints, dGeo.latitude, dGeo.longitude);
      _selectedVertexIndex = null;
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  /// Thêm đỉnh mới vào vị trí cạnh gần nhất của polygon
  void _insertPointIntoPolygon(LatLng newPoint) {
    if (_polygonPoints.length < 3) {
      setState(() {
        _polygonPoints.add(newPoint);
      });
      widget.onPolygonChanged?.call(_polygonPoints);
      _notifyArea();
      return;
    }

    // Tìm cạnh gần nhất để chèn điểm vào giữa 2 đỉnh đó
    int bestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < _polygonPoints.length; i++) {
      final p1 = _polygonPoints[i];
      final p2 = _polygonPoints[(i + 1) % _polygonPoints.length];

      // Khoảng cách từ newPoint đến đoạn thẳng (p1, p2)
      final d = _distToSegment(newPoint, p1, p2);
      if (d < minDistance) {
        minDistance = d;
        bestIndex = i + 1;
      }
    }

    setState(() {
      _polygonPoints.insert(bestIndex, newPoint);
      _selectedVertexIndex = bestIndex;
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  /// Khoảng cách bình phương xấp xỉ từ điểm P tới đoạn thẳng AB
  double _distToSegment(LatLng p, LatLng a, LatLng b) {
    final double l2 = (b.latitude - a.latitude) * (b.latitude - a.latitude) +
        (b.longitude - a.longitude) * (b.longitude - a.longitude);
    if (l2 == 0) {
      return (p.latitude - a.latitude) * (p.latitude - a.latitude) +
          (p.longitude - a.longitude) * (p.longitude - a.longitude);
    }
    final double t = (((p.latitude - a.latitude) * (b.latitude - a.latitude) +
                (p.longitude - a.longitude) * (b.longitude - a.longitude)) /
            l2)
        .clamp(0.0, 1.0);
    final double projLat = a.latitude + t * (b.latitude - a.latitude);
    final double projLng = a.longitude + t * (b.longitude - a.longitude);
    return (p.latitude - projLat) * (p.latitude - projLat) +
        (p.longitude - projLng) * (p.longitude - projLng);
  }

  /// Cảm ứng kéo trực tiếp một đỉnh cụ thể (#1..#4)
  void _onVertexDragUpdate(int index, DragUpdateDetails details) {
    if (index < 0 || index >= _polygonPoints.length) return;
    final dGeo = _screenOffsetToLatLngDelta(details.delta);
    setState(() {
      _selectedVertexIndex = index;
      final p = _polygonPoints[index];
      _polygonPoints[index] = LatLng(p.latitude + dGeo.latitude, p.longitude + dGeo.longitude);
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  /// Dịch polygon theo độ lệch tâm, giữ nguyên hình dạng.
  List<LatLng> _shiftPolygon(List<LatLng> pts, double dLat, double dLng) =>
      pts.map((p) => LatLng(p.latitude + dLat, p.longitude + dLng)).toList();

  String _coordFallback(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}°B, ${p.longitude.toStringAsFixed(5)}°Đ';

  // ── Lấy địa chỉ thực tế qua Backend Proxy (chặn rò rỉ vị trí trực tiếp tới dịch vụ bên thứ ba) ───────────
  Future<void> _resolveAddress(LatLng point) async {
    if (!mounted) return;
    final int myId = ++_requestId;
    _addressPending = true;
    widget.onAddressResolved?.call('Đang lấy địa chỉ...');

    bool stale() => !mounted || myId != _requestId;

    _ResolvedAddress? result;
    // Chỉ gọi qua backend proxy, tuyệt đối không gọi trực tiếp bên thứ ba từ thiết bị client
    try {
      result = await _reverseBackendProxy(point);
    } catch (_) {}
    if (stale()) return;

    _addressPending = false;
    final levelTag = widget.level == 'ZONE'
        ? 'Nhà màng (Zone)'
        : widget.level == 'FIELD'
            ? 'Thửa đất (Field)'
            : 'Trang trại (Farm)';

    if (result != null) {
      debugPrint('[MiniGISMapPicker][$levelTag] 📍 Địa chỉ hiện tại: ${result.address} | Vùng: ${result.region} (Tọa độ: ${point.latitude}, ${point.longitude})');
      setState(() {
        _displayPlaceName = result!.address;
      });
      widget.onAddressResolved?.call(result.address);
      if (result.region.isNotEmpty) {
        widget.onRegionNameResolved?.call(result.region);
      }
    } else {
      final fallback = _coordFallback(point);
      debugPrint('[MiniGISMapPicker][$levelTag] ⚠️ Không lấy được tên địa danh, dùng tọa độ: $fallback');
      setState(() {
        _displayPlaceName = fallback;
      });
      widget.onAddressResolved?.call(fallback);
    }
  }

  String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<_ResolvedAddress?> _reverseBackendProxy(LatLng p) async {
    try {
      final res = await ApiService.reverseGeocode(p.latitude, p.longitude);
      if (res != null) {
        final displayName = _s(res['displayName']);
        if (displayName != null) {
          final region = _s(res['district']) ?? _s(res['city']) ?? _s(res['province']) ?? '';
          return _ResolvedAddress(displayName, region);
        }
      }
    } catch (_) {}
    return null;
  }


  /// Di chuyển ghim tới điểm bất kỳ (tap / recenter) và lấy địa chỉ ngay.
  void _moveTo(LatLng point, {double? zoom}) {
    if (_isLockedCenter) {
      // Khi ở chế độ FIELD: Ghim và Polygon bị khóa cố định theo Farm, chỉ cho phép zoom hoặc ngắm nhìn
      try {
        _mapController.move(widget.initialCenter, zoom ?? _mapController.camera.zoom);
      } catch (_) {}
      return;
    }
    _debounceTimer?.cancel();
    final dLat = point.latitude - _currentCenter.latitude;
    final dLng = point.longitude - _currentCenter.longitude;
    setState(() {
      _currentCenter = point;
      _polygonPoints = _shiftPolygon(_polygonPoints, dLat, dLng);
    });
    _coordNotifier.value = point;
    try {
      _mapController.move(point, zoom ?? _mapController.camera.zoom);
    } catch (_) {}
    widget.onCenterChanged?.call(point);
    widget.onPolygonChanged?.call(_polygonPoints);
    _resolveAddress(point);
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    if (widget.level == 'FIELD' || widget.level == 'ZONE') {
      final isInside = _isPointInsidePolygon(point, _polygonPoints);
      if (!isInside) {
        // Nếu có ranh giới mẹ (Field) và điểm ấn nằm ngoài Field, nhắc người dùng
        if (widget.parentPolygon != null &&
            widget.parentPolygon!.length >= 3 &&
            !_isPointInsidePolygon(point, widget.parentPolygon!)) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vị trí ngoài ranh giới Thửa đất (Field). Vui lòng chọn bên trong!',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }

        // Kiểm tra xem vị trí chạm có đè lên Vùng khác đã có không
        if (_isVertexInsideAnyOtherZone(point)) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          final typeName = widget.level == 'FIELD' ? 'Thửa đất khác' : 'Nhà màng khác';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vị trí này đã thuộc $typeName! Vui lòng chọn khoảng trống.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }

        // Ấn ở ngoài -> Thêm điểm đỉnh mới vào ranh giới thửa đất
        _insertPointIntoPolygon(point);
      } else {
        // Ấn ở trong -> Di chuyển ô cũ tới vị trí mới
        final centroid = _getPolygonCentroid();
        final dLat = point.latitude - centroid.latitude;
        final dLng = point.longitude - centroid.longitude;
        setState(() {
          _polygonPoints = _shiftPolygon(_polygonPoints, dLat, dLng);
          _selectedVertexIndex = null;
        });
        widget.onPolygonChanged?.call(_polygonPoints);
        _notifyArea();
      }
      return;
    }
    if (_isLockedCenter) return; // Không cho phép đổi tâm Field
    _moveTo(point);
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    // Nếu ở chế độ FIELD: Khóa cứng tâm vào initialCenter của Farm
    if (_isLockedCenter) return;

    // Chỉ xử lý khi người dùng kéo/zoom. Di chuyển bằng code (_moveTo) đã tự xử lý.
    if (!hasGesture) return;

    final c = camera.center;
    final dLat = c.latitude - _currentCenter.latitude;
    final dLng = c.longitude - _currentCenter.longitude;
    _currentCenter = c;
    _coordNotifier.value = c;
    setState(() => _polygonPoints = _shiftPolygon(_polygonPoints, dLat, dLng));
    widget.onCenterChanged?.call(c);

    // Vô hiệu response cũ ngay lập tức, báo "đang lấy" một lần
    _debounceTimer?.cancel();
    _requestId++;
    if (!_addressPending) {
      _addressPending = true;
      widget.onAddressResolved?.call('Đang lấy địa chỉ...');
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      widget.onPolygonChanged?.call(_polygonPoints);
      _resolveAddress(_currentCenter); // luôn dùng tâm mới nhất
    });
  }

  String _getTileUrl() => _mapType == 'satellite'
      ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

  @override
  Widget build(BuildContext context) {
    // Chiều cao mặc định to hơn (250px), khi mở rộng lên 420px
    final currentHeight = _isExpanded ? 420.0 : (widget.height < 250 ? 250.0 : widget.height);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      height: currentHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: widget.initialZoom,
                minZoom: 9.0,
                maxZoom: 20.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: _onMapTapped,
                onPositionChanged: _onPositionChanged,
              ),
              children: [
                TileLayer(
                  key: ValueKey(_mapType),
                  urlTemplate: _getTileUrl(),
                  userAgentPackageName: 'com.smartfarm.mobile',
                  maxZoom: 20,
                ),
                if (widget.parentPolygon != null &&
                    widget.parentPolygon!.length >= 3)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: widget.parentPolygon!,
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderColor: const Color(0xFF0284C7),
                      borderStrokeWidth: 2.2,
                    ),
                  ]),

                // Các Vùng đã có (Zone mẹ hoặc Field khác trên cùng Farm)
                if (_otherPolygons.isNotEmpty)
                  PolygonLayer(
                    polygons: _otherPolygons.where((z) {
                      final pts = z['polygon'] as List<LatLng>?;
                      return pts != null && pts.length >= 3;
                    }).map((z) {
                      final pts = z['polygon'] as List<LatLng>;
                      final isFieldLevel = widget.level == 'FIELD';
                      return Polygon(
                        points: pts,
                        color: isFieldLevel
                            ? const Color(0xFF0284C7).withValues(alpha: 0.16)
                            : const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderColor: isFieldLevel
                            ? const Color(0xFF0284C7)
                            : const Color(0xFF059669),
                        borderStrokeWidth: 1.8,
                      );
                    }).toList(),
                  ),

                // Nhãn tên các Vùng đã có
                if (_otherPolygons.isNotEmpty)
                  MarkerLayer(
                    markers: _otherPolygons.where((z) {
                      final pts = z['polygon'] as List<LatLng>?;
                      return pts != null && pts.length >= 3;
                    }).map((z) {
                      final pts = z['polygon'] as List<LatLng>;
                      final centroid = _calculateCentroid(pts);
                      final name = z['name']?.toString() ?? 'Vùng đất';
                      final isFieldLevel = widget.level == 'FIELD';
                      return Marker(
                        point: centroid,
                        width: 140,
                        height: 24,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFieldLevel
                                ? const Color(0xFF0C4A6E).withValues(alpha: 0.85)
                                : const Color(0xFF064E3B).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isFieldLevel ? const Color(0xFF38BDF8) : const Color(0xFF34D399),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                // Polygon ranh giới hiện tại (Màu sắc: BÁO ĐỎ khi vượt ranh giới Thửa đất mẹ HOẶC đè lên Zone khác)
                if (_polygonPoints.length >= 3)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: _polygonPoints,
                      color: _isPolygonInvalid
                          ? const Color(0xFFEF4444).withValues(alpha: 0.38) // BÁO ĐỎ RÕ KHI VƯỢT HOẶC ĐÈ
                          : widget.level == 'FIELD'
                              ? const Color(0xFF0284C7).withValues(alpha: 0.28)
                              : widget.level == 'ZONE'
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                                  : const Color(0xFF10B981).withValues(alpha: 0.25),
                      borderColor: _isPolygonInvalid
                          ? const Color(0xFFDC2626) // VIỀN ĐỎ RỰC KHI VƯỢT HOẶC ĐÈ
                          : widget.level == 'FIELD'
                              ? const Color(0xFF0284C7)
                              : widget.level == 'ZONE'
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF10B981),
                      borderStrokeWidth: _isPolygonInvalid ? 3.2 : 2.5,
                    ),
                  ]),
                // Marker ghim trên bản đồ (Nếu ở FIELD sẽ cố định chính xác tại tọa độ của Farm)
                if (widget.level == 'FIELD')
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.initialCenter,
                        width: _pinSize,
                        height: _pinSize,
                        alignment: Alignment.topCenter,
                        child: Transform.translate(
                          offset: const Offset(0, -(_pinSize / 2) + _pinTipInset),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                bottom: _pinTipInset - 2,
                                child: Container(
                                  width: 10,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const Icon(Icons.location_on_rounded,
                                  size: _pinSize, color: Color(0xFF0284C7)),
                              const Positioned(
                                top: 10.75,
                                child: CircleAvatar(
                                    radius: 5, backgroundColor: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                // Vùng cảm ứng kéo trực tiếp để di chuyển cả ô thửa đất khi chạm & vuốt ở giữa ô
                if (_polygonPoints.length >= 3)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _getPolygonCentroid(),
                        width: 140,
                        height: 140,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onPanUpdate: _onPolygonBodyDragUpdate,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),

                // Marker các đỉnh ranh giới (#1, #2, #3...) có thể chạm & kéo trực tiếp
                if (_polygonPoints.isNotEmpty)
                  MarkerLayer(
                    markers: List.generate(_polygonPoints.length, (idx) {
                      final pt = _polygonPoints[idx];
                      final isSelected = _selectedVertexIndex == idx;

                      final isInvalid = _isVertexInvalid(pt);

                      return Marker(
                        point: pt,
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedVertexIndex = isSelected ? null : idx;
                            });
                          },
                          onPanUpdate: (details) => _onVertexDragUpdate(idx, details),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Vòng tròn lớn tăng diện tích nhận cảm ứng khi kéo ngón tay
                              Container(
                                width: 44,
                                height: 44,
                                color: Colors.transparent,
                              ),
                              // Điểm chấm tròn vertex
                              Container(
                                width: (isSelected || isInvalid) ? 22 : 16,
                                height: (isSelected || isInvalid) ? 22 : 16,
                                decoration: BoxDecoration(
                                  color: isInvalid
                                      ? const Color(0xFFEF4444)
                                      : isSelected
                                          ? const Color(0xFFF97316)
                                          : const Color(0xFF0284C7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: (isSelected || isInvalid) ? 2.5 : 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isInvalid
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                                          : Colors.black.withValues(alpha: 0.4),
                                      blurRadius: isInvalid ? 8 : 5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              // Nhãn Pill: #1, #2, #3, #4
                              Positioned(
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isInvalid
                                        ? const Color(0xFFDC2626)
                                        : isSelected
                                            ? const Color(0xFFEA580C)
                                            : const Color(0xFF062326),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isInvalid
                                          ? const Color(0xFFFEE2E2)
                                          : isSelected
                                              ? const Color(0xFFFED7AA)
                                              : const Color(0xFF38BDF8),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '#${idx + 1}',
                                    style: TextStyle(
                                      color: (isSelected || isInvalid) ? Colors.white : const Color(0xFF38BDF8),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),

            // Ghim cố định ở tâm màn hình (chỉ hiện khi định vị Farm, ẩn ở FIELD & ZONE để không vướng ô ranh giới)
            if (widget.level == 'FARM')
              Center(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -(_pinSize / 2) + _pinTipInset),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: _pinTipInset - 2,
                          child: Container(
                            width: 10,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const Icon(Icons.location_on_rounded,
                            size: _pinSize, color: Color(0xFFEA4335)),
                        const Positioned(
                          top: 10.75,
                          child: CircleAvatar(
                              radius: 5, backgroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top-Left HUD Info Badge (Địa danh thời gian thực theo ghim)
            Positioned(
              top: 8,
              left: 8,
              right: 140,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.level == 'ZONE'
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : widget.level == 'FIELD'
                            ? const Color(0xFF0284C7).withValues(alpha: 0.5)
                            : Colors.white24,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.level == 'ZONE'
                          ? Icons.grid_view_rounded
                          : widget.level == 'FIELD'
                              ? Icons.lock_rounded
                              : Icons.location_on,
                      size: 12,
                      color: widget.level == 'ZONE'
                          ? const Color(0xFF10B981)
                          : widget.level == 'FIELD'
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        widget.level == 'FIELD'
                            ? 'Trùng tọa độ Farm: $_displayPlaceName'
                            : _displayPlaceName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-Right Map Mode Pill (Vệ tinh / Bản đồ đường)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _mapType = 'satellite'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _mapType == 'satellite' ? const Color(0xFF1E293B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.satellite_alt_rounded,
                              size: 11,
                              color: _mapType == 'satellite' ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Vệ tinh',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: _mapType == 'satellite' ? FontWeight.bold : FontWeight.normal,
                                color: _mapType == 'satellite' ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _mapType = 'street'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _mapType == 'street' ? const Color(0xFF1E293B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_outlined,
                              size: 11,
                              color: _mapType == 'street' ? Colors.white : Colors.black87,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Bản đồ',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: _mapType == 'street' ? FontWeight.bold : FontWeight.normal,
                                color: _mapType == 'street' ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),


            Positioned(
              bottom: 30,
              right: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút Mở rộng / Thu nhỏ bản đồ (Fullscreen / Collapse Toggle)
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          _isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                          size: 20,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _moveTo(widget.initialCenter, zoom: widget.initialZoom),
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.gps_fixed_rounded, size: 18, color: Color(0xFF1A73E8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 3,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          onTap: () {
                            try {
                              final nextZoom = (_mapController.camera.zoom + 1.0).clamp(9.0, 20.0);
                              _mapController.move(_mapController.camera.center, nextZoom);
                            } catch (_) {}
                          },
                          child: const SizedBox(
                            width: 32,
                            height: 30,
                            child: Icon(Icons.add, size: 18, color: Colors.black87),
                          ),
                        ),
                        Container(width: 24, height: 1, color: const Color(0xFFE2E8F0)),
                        InkWell(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                          onTap: () {
                            try {
                              final nextZoom = (_mapController.camera.zoom - 1.0).clamp(9.0, 20.0);
                              _mapController.move(_mapController.camera.center, nextZoom);
                            } catch (_) {}
                          },
                          child: const SizedBox(
                            width: 32,
                            height: 30,
                            child: Icon(Icons.remove, size: 18, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Hint Pill
            Positioned(
              bottom: 6,
              left: 8,
              right: 8,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _isPolygonInvalid
                      ? const Color(0xFFDC2626) // Cảnh báo đỏ nổi bật
                      : Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _isPolygonInvalid
                      ? [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPolygonInvalid
                          ? Icons.warning_amber_rounded
                          : Icons.touch_app_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _overlappedZoneName != null
                            ? 'CẢNH BÁO: Đang chồng đè lên "$_overlappedZoneName"! Vui lòng điều chỉnh lại.'
                            : (_hasPointOutsideParent
                                ? 'CẢNH BÁO: Đỉnh đang nằm ngoài Thửa đất! Vui lòng kéo lại vào trong.'
                                : (widget.level == 'FIELD' || widget.level == 'ZONE'
                                    ? (_selectedVertexIndex != null
                                        ? 'Chạm giữ & kéo đỉnh #${_selectedVertexIndex! + 1} để điều chỉnh'
                                        : 'Chạm ở ngoài để thêm đỉnh • Chạm & kéo trong ô để di chuyển')
                                    : 'Chạm hoặc kéo bản đồ như Google Maps')),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: _isPolygonInvalid ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
