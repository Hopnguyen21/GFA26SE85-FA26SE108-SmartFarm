import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../services/api_service.dart';
import 'zone_default_box.dart';
import '../utils/user_error.dart';
import '../utils/haptics.dart';

part 'parts/mini_gis_map_picker_map_layer.dart';
part 'parts/mini_gis_map_picker_overlays.dart';

part 'parts/mini_gis_map_picker_geometry.dart';
part 'parts/mini_gis_map_picker_interaction.dart';
part 'parts/mini_gis_map_picker_geocode.dart';

/// Một node thiết bị đã được chấm toạ độ GIS, vẽ trên bản đồ (chỉ để xem).
class MapNodeMarker {
  final LatLng point;
  final String label;
  final String type; // SensorNode | ActuatorNode | ...
  final String status; // Online | Offline | ...
  const MapNodeMarker({
    required this.point,
    required this.label,
    required this.type,
    this.status = '',
  });

  /// Dựng từ một dòng của GET /zones/{id}/devices/map-locations; null khi thiếu hoặc sai toạ độ.
  static MapNodeMarker? fromJson(Map<String, dynamic> j) {
    final lat = (j['latitude'] as num?)?.toDouble();
    final lng = (j['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0))
      return null;
    final name = '${j['deviceName'] ?? ''}'.trim();
    final addr = '${j['hardwareAddress'] ?? ''}'.trim();
    return MapNodeMarker(
      point: LatLng(lat, lng),
      label: name.isNotEmpty ? name : (addr.isNotEmpty ? addr : 'Node'),
      type: '${j['deviceType'] ?? ''}',
      status: '${j['status'] ?? ''}',
    );
  }
}

/// Điểm có nằm trong đa giác (ray casting, toạ độ lng/lat) không. Đa giác dưới 3 đỉnh → false.
bool pointInPolygon(LatLng p, List<LatLng> poly) {
  if (poly.length < 3) return false;
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    final crosses =
        (a.latitude > p.latitude) != (b.latitude > p.latitude) &&
        p.longitude <
            (b.longitude - a.longitude) *
                    (p.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude;
    if (crosses) inside = !inside;
  }
  return inside;
}

class MiniGISMapPicker extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final ValueChanged<LatLng>? onCenterChanged;
  final List<LatLng>? initialPolygon;
  final ValueChanged<List<LatLng>>? onPolygonChanged;
  final String level; // 'FARM', 'FIELD', 'ZONE'
  final List<LatLng>? parentPolygon;
  final List<Map<String, dynamic>>?
  existingZones; // [{name: 'Nhà màng 01', polygon: [...]}]
  final List<Map<String, dynamic>>?
  existingPolygons; // [{name: 'Lô đất A1', polygon: [...]}]
  final double height;
  final ValueChanged<double>?
  onAreaCalculated; // Callback diện tích tính toán (m²)

  /// Chỉ được gọi với tên địa điểm THẬT từ backend (không bao giờ là toạ độ hay chữ "đang lấy").
  final ValueChanged<String>? onAddressResolved;

  /// Bắt đầu lấy địa chỉ cho vị trí mới.
  final VoidCallback? onAddressLoading;

  /// Lấy địa chỉ thất bại hoặc không tìm thấy; tham số là câu báo lỗi cho người dùng.
  final ValueChanged<String>? onAddressFailed;
  final ValueChanged<String>? onRegionNameResolved;
  final bool isReadOnly;

  /// Có tự tra địa chỉ cho vị trí khởi tạo hay không. Form tạo Farm tắt đi vì vị trí khởi tạo chưa phải vị trí người dùng chọn.
  final bool autoResolveOnInit;

  /// Báo ngay ranh giới mặc định (ô vuông quanh tâm) cho onPolygonChanged khi mở bản đồ FIELD/ZONE,
  /// để người dùng không cần chạm vào bản đồ mới có ranh giới. Mặc định tắt để không đổi hành vi các màn cũ.
  final bool emitInitialPolygon;

  /// Diện tích tối đa (m²) của ranh giới Zone gợi ý sẵn, thường là phần còn trống của thửa đất. null = không giới hạn.
  final double? maxDefaultAreaM2;

  /// Fit an existing boundary and let the camera pan independently of it.
  final bool fitBoundaryOnOpen;

  /// Node thiết bị đã chấm toạ độ (hiển thị trên ranh giới; không sửa được ở đây).
  final List<MapNodeMarker> nodeMarkers;

  const MiniGISMapPicker({
    super.key,
    required this.initialCenter,
    this.initialZoom = 16.5,
    this.onCenterChanged,
    this.onAddressResolved,
    this.onAddressLoading,
    this.autoResolveOnInit = true,
    this.onAddressFailed,
    this.onRegionNameResolved,
    this.initialPolygon,
    this.onPolygonChanged,
    this.onAreaCalculated,
    this.level = 'FARM',
    this.parentPolygon,
    this.existingZones,
    this.existingPolygons,
    this.height = 220,
    this.isReadOnly = false,
    this.emitInitialPolygon = false,
    this.maxDefaultAreaM2,
    this.fitBoundaryOnOpen = false,
    this.nodeMarkers = const [],
  });

  /// Kiểm tra 2 polygon có chồng lấn lên nhau không
  static bool polygonsOverlap(List<LatLng> polyA, List<LatLng> polyB) =>
      _MiniGISMapPickerState.polygonsOverlap(polyA, polyB);

  /// Kiểm tra đa giác có tự cắt chính nó không (hình số 8 / hình nơ)
  static bool polygonSelfIntersects(List<LatLng> pts) =>
      _MiniGISMapPickerState.polygonSelfIntersects(pts);

  /// Đa giác nằm trọn trong vùng mẹ (mọi đỉnh trong và không cạnh nào cắt cạnh vùng mẹ).
  static bool polygonInsideParent(List<LatLng> points, List<LatLng> parent) =>
      _MiniGISMapPickerState.polygonInsideParent(points, parent);

  /// Kiểm tra tính hợp lệ toàn diện của ranh giới trước khi gửi API
  static String? validateBoundary(
    List<LatLng>? points, {
    List<LatLng>? parentPolygon,
    List<Map<String, dynamic>>? existingPolygons,
    String level = 'ZONE',
  }) => _MiniGISMapPickerState.validateBoundary(
    points,
    parentPolygon: parentPolygon,
    existingPolygons: existingPolygons,
    level: level,
  );

  @override
  State<MiniGISMapPicker> createState() => _MiniGISMapPickerState();
}

class _MiniGISMapPickerState extends State<MiniGISMapPicker> {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  final GlobalKey _mapKey = GlobalKey();
  Offset? _dragStartTouchOffset;

  late final MapController _mapController;
  late LatLng _currentCenter;
  late List<LatLng> _polygonPoints;
  late final ValueNotifier<LatLng> _coordNotifier;
  Timer? _debounceTimer;
  String _mapType = 'osm';

  int _requestId = 0; // chỉ response của request mới nhất được nhận
  bool _addressPending = false; // đã báo "đang lấy địa chỉ" cho parent chưa
  String _displayPlaceName = 'Đang định vị...';
  bool _isExpanded = false; // Trạng thái mở rộng / thu nhỏ bản đồ

  // Điều chỉnh kích thước polygon (scale) & Chọn đỉnh đang thao tác
  final double _polygonScale = 1.0;
  int?
  _selectedVertexIndex; // null: di chuyển toàn bộ ranh giới, 0..3: di chuyển đỉnh cụ thể #1..#4
  bool _isDraggingVertex =
      false; // Đang kéo đỉnh: vô hiệu hóa pan map để không giật lag

  void _deleteSelectedVertex() {
    if (_selectedVertexIndex == null || _polygonPoints.length <= 3) return;
    AppHaptics.warning();
    _rebuild(() {
      _polygonPoints.removeAt(_selectedVertexIndex!);
      _selectedVertexIndex = null;
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  void _nudgeSelectedVertex(double dLatMeters, double dLngMeters) {
    if (_selectedVertexIndex == null) return;
    final idx = _selectedVertexIndex!;
    if (idx < 0 || idx >= _polygonPoints.length) return;
    AppHaptics.light();
    final latRad = _currentCenter.latitude * math.pi / 180.0;
    final dLat = dLatMeters / 110540.0;
    final dLng = dLngMeters / (111320.0 * math.cos(latRad));
    _rebuild(() {
      final p = _polygonPoints[idx];
      _polygonPoints[idx] = LatLng(p.latitude + dLat, p.longitude + dLng);
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  static const double _pinSize = 42;
  static const double _pinTipInset = 3.5; // khoảng trống dưới đầu nhọn của icon

  bool get _isLockedCenter => widget.level == 'FIELD' || widget.level == 'ZONE';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    final effectiveCenter =
        widget.parentPolygon != null && widget.parentPolygon!.isNotEmpty
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
        if (widget.autoResolveOnInit) _resolveAddress(_currentCenter);
        _notifyArea();
        if (widget.emitInitialPolygon &&
            widget.level != 'FARM' &&
            _polygonPoints.length >= 3) {
          widget.onPolygonChanged?.call(List<LatLng>.from(_polygonPoints));
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MiniGISMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final boundaryChanged = !listEquals(
      widget.initialPolygon,
      oldWidget.initialPolygon,
    );
    // Parent thường truyền lại đúng ranh giới vừa nhận từ onPolygonChanged (wizard): đó không phải ranh giới mới,
    // nạp lại sẽ bỏ chọn đỉnh đang thao tác sau mỗi lần sửa.
    if (boundaryChanged &&
        widget.initialPolygon != null &&
        widget.initialPolygon!.length >= 3 &&
        !listEquals(widget.initialPolygon, _polygonPoints)) {
      setState(() {
        _polygonPoints = List<LatLng>.from(widget.initialPolygon!);
        _selectedVertexIndex = null;
      });
      _notifyArea();
    }
    if (widget.initialCenter != oldWidget.initialCenter ||
        !listEquals(widget.parentPolygon, oldWidget.parentPolygon)) {
      final newCenter =
          widget.parentPolygon != null && widget.parentPolygon!.isNotEmpty
          ? _calculateCentroid(widget.parentPolygon!)
          : widget.initialCenter;
      _currentCenter = newCenter;
      _coordNotifier.value = newCenter;
      setState(() {
        if (widget.initialPolygon == null ||
            widget.initialPolygon!.length < 3) {
          _polygonPoints = widget.level == 'FARM'
              ? []
              : _generateDefaultBox(newCenter, scale: _polygonScale);
        }
        _selectedVertexIndex = null;
      });
      try {
        final fit = _boundaryCameraFit();
        if (fit != null) {
          _mapController.fitCamera(fit);
        } else {
          _mapController.move(newCenter, widget.initialZoom);
        }
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

  /// Danh sách các polygon đã có cần tránh đè lên (Zone hoặc Field)
  List<Map<String, dynamic>> get _otherPolygons =>
      widget.existingPolygons ?? widget.existingZones ?? [];

  String? _computeOverlappedZoneName() {
    // Chỉ kiểm tra chồng đè ở cấp ZONE (các nhà màng/lô trong cùng một thửa đất không được đè lên nhau).
    // Ở cấp FIELD người dùng có thể thoải mái phân định thửa đất trên trang trại mà không bị báo đỏ cản trở.
    if (widget.level != 'ZONE') return null;
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

  /// Có đỉnh nào thò ra ngoài Thửa đất không — dùng kết quả đã lưu đệm.
  bool get _hasPointOutsideParent => _validity().outside;

  bool _computeHasPointOutsideParent() {
    if (widget.parentPolygon == null || widget.parentPolygon!.length < 3)
      return false;
    return !polygonInsideParent(_polygonPoints, widget.parentPolygon!);
  }

  /// Kiểm tra 2 đa giác có giao nhau / đè lên nhau không
  static bool polygonsOverlap(List<LatLng> polyA, List<LatLng> polyB) {
    if (polyA.length < 3 || polyB.length < 3) return false;
    for (final pt in polyA) {
      if (pointInPolygon(pt, polyB)) return true;
    }
    for (final pt in polyB) {
      if (pointInPolygon(pt, polyA)) return true;
    }
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

  /// Đa giác nằm trọn trong vùng mẹ: mọi đỉnh nằm trong VÀ không cạnh nào cắt cạnh của vùng mẹ
  /// (vùng mẹ lõm: các đỉnh đều ở trong nhưng cạnh vẫn có thể lòi ra ngoài).
  static bool polygonInsideParent(List<LatLng> points, List<LatLng> parent) {
    if (points.length < 3 || parent.length < 3) return true;
    if (points.any((p) => !pointInPolygon(p, parent))) return false;
    for (int i = 0; i < points.length; i++) {
      final a1 = points[i];
      final a2 = points[(i + 1) % points.length];
      for (int j = 0; j < parent.length; j++) {
        if (_segmentsIntersect(
          a1,
          a2,
          parent[j],
          parent[(j + 1) % parent.length],
        )) {
          return false;
        }
      }
    }
    return true;
  }

  /// Kiểm tra tính hợp lệ toàn diện của ranh giới trước khi gửi API (số đỉnh, tự cắt chéo, lòi ra ngoài vùng mẹ, đè lên vùng khác).
  /// Trả về chuỗi thông báo lỗi bằng tiếng Việt nếu không hợp lệ, hoặc null nếu hợp lệ.
  static String? validateBoundary(
    List<LatLng>? points, {
    List<LatLng>? parentPolygon,
    List<Map<String, dynamic>>? existingPolygons,
    String level = 'ZONE',
  }) {
    if (points == null || points.length < 3) {
      return 'Ranh giới cần ít nhất 3 đỉnh.';
    }
    if (polygonSelfIntersects(points)) {
      return 'Ranh giới bị tự cắt chéo (hình số 8). Vui lòng kéo các đỉnh không cắt nhau.';
    }
    if (parentPolygon != null && parentPolygon.length >= 3) {
      if (!polygonInsideParent(points, parentPolygon)) {
        return 'Ranh giới đang vượt ra ngoài ${level == 'ZONE' ? 'Thửa đất mẹ' : 'Trang trại'}! Vui lòng chỉnh lại vào trong.';
      }
    }
    if (level == 'ZONE' &&
        existingPolygons != null &&
        existingPolygons.isNotEmpty) {
      for (final other in existingPolygons) {
        final pts = other['polygon'] as List<LatLng>?;
        if (pts != null && pts.length >= 3) {
          if (polygonsOverlap(points, pts)) {
            final name = other['name']?.toString() ?? 'vùng đã có';
            return 'Ranh giới đang chồng đè lên "$name"! Vui lòng điều chỉnh lại.';
          }
        }
      }
    }
    return null;
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
  bool get _isPolygonInvalid => _validity().invalid;

  // Lưu đệm kết quả kiểm tra hợp lệ: các getter trên được gọi nhiều lần trong mỗi lần dựng lại (lớp vùng, đỉnh, nhãn, chú thích),
  // mỗi lần đều duyệt mọi cặp cạnh/đỉnh. Khi kéo bản đồ hay kéo đỉnh, dựng lại diễn ra theo từng khung hình nên rất nặng.
  // Chỉ tính lại khi hình dạng ranh giới (hoặc ranh giới mẹ/vùng khác) thật sự đổi.
  int _validityKey = 0;
  ({bool invalid, bool outside, String? overlap})? _validityCache;

  ({bool invalid, bool outside, String? overlap}) _validity() {
    final key = Object.hash(
      Object.hashAll([
        for (final pt in _polygonPoints) Object.hash(pt.latitude, pt.longitude),
      ]),
      identityHashCode(widget.parentPolygon),
      widget.parentPolygon?.length,
      identityHashCode(widget.existingPolygons ?? widget.existingZones),
      (widget.existingPolygons ?? widget.existingZones)?.length,
      widget.level,
    );
    final cached = _validityCache;
    if (cached != null && key == _validityKey) return cached;
    final outside = _computeHasPointOutsideParent();
    final overlap = _computeOverlappedZoneName();
    final invalid =
        polygonSelfIntersects(_polygonPoints) ||
        (widget.level != 'FARM' && (outside || overlap != null));
    _validityKey = key;
    return _validityCache = (
      invalid: invalid,
      outside: outside,
      overlap: overlap,
    );
  }

  /// Dịch polygon theo độ lệch tâm, giữ nguyên hình dạng.
  List<LatLng> _shiftPolygon(List<LatLng> pts, double dLat, double dLng) =>
      pts.map((p) => LatLng(p.latitude + dLat, p.longitude + dLng)).toList();

  String _coordFallback(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}°B, ${p.longitude.toStringAsFixed(5)}°Đ';

  String _getTileUrl() {
    switch (_mapType) {
      case 'osm':
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case 'street':
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case 'satellite':
      default:
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chiều cao mặc định to hơn (250px), khi mở rộng lên 420px
    final currentHeight = _isExpanded
        ? 420.0
        : (widget.height < 250 ? 250.0 : widget.height);

    // Chặn Scrollable cha (như SingleChildScrollView hay BottomSheet) cướp cử chỉ kéo/chạm khi người dùng đang thao tác trên bản đồ GIS
    // Đăng ký bộ nhận diện kéo (nằm sâu hơn Scrollable cha) để cú kéo trên bản đồ không bị danh sách cha cướp để cuộn trang.
    // KHÔNG dùng EagerGestureRecognizer: nó thắng mọi cuộc tranh chấp ngay khi chạm nên các đỉnh, nút chỉnh toạ độ và thao tác chạm
    // bên trong không còn nhận được cử chỉ nào. Cú chạm (tap) vẫn đi tới các điều khiển bên trong.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) {},
      onPanUpdate: (_) {},
      child: AnimatedContainer(
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
              ..._mapLayerSection(context, currentHeight),
              ..._topOverlaysSection(context, currentHeight),
              ..._bottomOverlaysSection(context, currentHeight),
            ],
          ),
        ),
      ),
    );
  }
}
