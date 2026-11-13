import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'zone_default_box.dart';

part 'parts/mini_gis_map_picker_map_layer.dart';
part 'parts/mini_gis_map_picker_overlays.dart';

part 'parts/mini_gis_map_picker_geometry.dart';
part 'parts/mini_gis_map_picker_interaction.dart';
part 'parts/mini_gis_map_picker_geocode.dart';

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
  });

  @override
  State<MiniGISMapPicker> createState() => _MiniGISMapPickerState();
}

class _MiniGISMapPickerState extends State<MiniGISMapPicker> {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

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
  int?
  _selectedVertexIndex; // null: di chuyển toàn bộ ranh giới, 0..3: di chuyển đỉnh cụ thể #1..#4
  bool _isDraggingVertex =
      false; // Đang kéo đỉnh: vô hiệu hóa pan map để không giật lag

  void _deleteSelectedVertex() {
    if (_selectedVertexIndex == null || _polygonPoints.length <= 3) return;
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
    if (widget.initialPolygon != oldWidget.initialPolygon &&
        widget.initialPolygon != null &&
        widget.initialPolygon!.length >= 3) {
      setState(() {
        _polygonPoints = List<LatLng>.from(widget.initialPolygon!);
        _selectedVertexIndex = null;
      });
      _notifyArea();
    }
    if (widget.initialCenter != oldWidget.initialCenter ||
        widget.parentPolygon != oldWidget.parentPolygon) {
      final newCenter =
          widget.parentPolygon != null && widget.parentPolygon!.isNotEmpty
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

  /// Kiểm tra xem toàn bộ ô hiện tại có đỉnh nào bị thò ra ngoài không
  bool get _hasPointOutsideParent {
    if (widget.parentPolygon == null || widget.parentPolygon!.length < 3)
      return false;
    return _polygonPoints.any(
      (pt) => !_isPointInsidePolygon(pt, widget.parentPolygon!),
    );
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
      (widget.level != 'FARM' &&
          (_hasPointOutsideParent || _overlappedZoneName != null));

  /// Dịch polygon theo độ lệch tâm, giữ nguyên hình dạng.
  List<LatLng> _shiftPolygon(List<LatLng> pts, double dLat, double dLng) =>
      pts.map((p) => LatLng(p.latitude + dLat, p.longitude + dLng)).toList();

  String _coordFallback(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}°B, ${p.longitude.toStringAsFixed(5)}°Đ';

  String _getTileUrl() => _mapType == 'satellite'
      ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
      : 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

  @override
  Widget build(BuildContext context) {
    // Chiều cao mặc định to hơn (250px), khi mở rộng lên 420px
    final currentHeight = _isExpanded
        ? 420.0
        : (widget.height < 250 ? 250.0 : widget.height);

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
            ..._mapLayerSection(context, currentHeight),
            ..._topOverlaysSection(context, currentHeight),
            ..._bottomOverlaysSection(context, currentHeight),
          ],
        ),
      ),
    );
  }
}
