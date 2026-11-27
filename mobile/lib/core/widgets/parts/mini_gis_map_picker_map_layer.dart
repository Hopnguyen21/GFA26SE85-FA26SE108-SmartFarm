part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateMapLayer on _MiniGISMapPickerState {
  /// Các vùng khác có nhãn không đè lên nhau: duyệt lần lượt, bỏ nhãn nào có tâm (trên màn hình) nằm trong hộp 140×24 của nhãn đã giữ.
  /// Vùng bị ẩn nhãn vẫn được vẽ đường viền; phóng to thì nhãn tự hiện khi đủ chỗ.
  List<Map<String, dynamic>> _nonOverlappingLabelZones(MapCamera camera) {
    final kept = <Offset>[];
    final result = <Map<String, dynamic>>[];
    for (final z in _otherPolygons) {
      final pts = z['polygon'] as List<LatLng>?;
      if (pts == null || pts.length < 3) continue;
      final c = camera.latLngToScreenOffset(
        _MiniGISMapPickerState._calculateCentroid(pts),
      );
      final clash = kept.any(
        (o) => (o.dx - c.dx).abs() < 140 && (o.dy - c.dy).abs() < 24,
      );
      if (clash) continue;
      kept.add(c);
      result.add(z);
    }
    return result;
  }

  /// Ranh giới truyền sẵn nhưng quá nhỏ ở zoom mở đầu (cạnh dài < ~90px): các đỉnh #1…#4 chồng lên nhau, không thao tác được.
  bool _isTinyOnScreen() {
    final lats = _polygonPoints.map((e) => e.latitude);
    final lngs = _polygonPoints.map((e) => e.longitude);
    final dLat = lats.reduce(math.max) - lats.reduce(math.min);
    final dLng = lngs.reduce(math.max) - lngs.reduce(math.min);
    final latRad = _polygonPoints.first.latitude * math.pi / 180.0;
    final metersPerPixel =
        156543.03392 * math.cos(latRad) / math.pow(2, widget.initialZoom);
    final longestMeters = math.max(
      dLat * 110540.0,
      dLng * 111320.0 * math.cos(latRad),
    );
    return longestMeters / metersPerPixel < 90;
  }

  CameraFit? _boundaryCameraFit() {
    // Ô mặc định (Zone/Thửa đất mới, chưa có ranh giới) chỉ rộng ~15 m: ở zoom mặc định nó nhỏ hơn các nút đỉnh (#1…#4)
    // nên đường nối bị che hết, trông như các đỉnh rời nhau. Căn khung ôm vừa ô (tối đa zoom 20) để thấy rõ cạnh và vùng.
    if (widget.level != 'FARM' &&
        !widget.isReadOnly &&
        _polygonPoints.length >= 3 &&
        (widget.initialPolygon == null || _isTinyOnScreen())) {
      return CameraFit.coordinates(
        coordinates: _polygonPoints,
        padding: const EdgeInsets.fromLTRB(60, 70, 70, 70),
        maxZoom: 20,
      );
    }
    if ((!widget.isReadOnly && !widget.fitBoundaryOnOpen) ||
        (_polygonPoints.length < 3 && widget.nodeMarkers.isEmpty)) {
      return null;
    }
    return CameraFit.coordinates(
      coordinates: [
        ..._polygonPoints,
        for (final node in widget.nodeMarkers) node.point,
      ],
      padding: const EdgeInsets.fromLTRB(28, 44, 52, 44),
      maxZoom: 19,
    );
  }

  /// Kích thước (px màn hình) của khung bao ranh giới hiện tại; null khi bản đồ chưa sẵn sàng.
  Size? _polygonPixelExtent() {
    if (_polygonPoints.length < 3) return null;
    try {
      final cam = _mapController.camera;
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final pt in _polygonPoints) {
        final o = cam.latLngToScreenOffset(pt);
        if (o.dx < minX) minX = o.dx;
        if (o.dx > maxX) maxX = o.dx;
        if (o.dy < minY) minY = o.dy;
        if (o.dy > maxY) maxY = o.dy;
      }
      return Size(maxX - minX, maxY - minY);
    } catch (_) {
      return null;
    }
  }

  /// Vùng chạm kéo cả ô: cố định 140px làm ô nhỏ (vài chục px) bị nuốt hết cú chạm, không kéo được bản đồ hay chọn đỉnh.
  /// Co theo kích thước ô thật trên màn hình (60% cạnh ngắn, 36–140px) để phần rìa ô vẫn kéo được bản đồ.
  double _bodyHitSize() {
    final ext = _polygonPixelExtent();
    if (ext == null) return 140;
    final shortest = ext.width < ext.height ? ext.width : ext.height;
    return (shortest * 0.6).clamp(36.0, 140.0).toDouble();
  }

  List<Widget> _mapLayerSection(BuildContext context, double currentHeight) {
    return [
      FlutterMap(
        key: _mapKey,
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentCenter,
          initialZoom: widget.initialZoom,
          initialCameraFit: _boundaryCameraFit(),
          minZoom: 9.0,
          maxZoom: 20.0,
          interactionOptions: InteractionOptions(
            flags: _isDraggingVertex
                ? (InteractiveFlag.all &
                      ~InteractiveFlag.drag &
                      ~InteractiveFlag.pinchMove)
                : InteractiveFlag.all,
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
          if (widget.parentPolygon != null && widget.parentPolygon!.length >= 3)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: widget.parentPolygon!,
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderColor: const Color(0xFF0284C7),
                  borderStrokeWidth: 2.2,
                  pattern: StrokePattern.dashed(segments: const [6, 6]),
                ),
              ],
            ),

          // Các Vùng đã có (Zone mẹ hoặc Field khác trên cùng Farm)
          if (_otherPolygons.isNotEmpty)
            PolygonLayer(
              polygons: _otherPolygons
                  .where((z) {
                    final pts = z['polygon'] as List<LatLng>?;
                    return pts != null && pts.length >= 3;
                  })
                  .map((z) {
                    final pts = z['polygon'] as List<LatLng>;
                    return Polygon(
                      points: pts,
                      // Giống web: các vùng đã có là xám nét đứt để phân biệt với vùng đang vẽ (xanh lá).
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                      borderColor: const Color(0xFF64748B),
                      borderStrokeWidth: 1.5,
                      pattern: StrokePattern.dashed(segments: const [3, 3]),
                    );
                  })
                  .toList(),
            ),

          // Nhãn tên các Vùng đã có — chỉ vẽ các nhãn không chồng nhau (tính theo vị trí trên màn hình, cập nhật khi zoom/kéo)
          if (_otherPolygons.isNotEmpty)
            Builder(
              builder: (labelCtx) => MarkerLayer(
                markers: _nonOverlappingLabelZones(MapCamera.of(labelCtx))
                    .where((z) {
                      final pts = z['polygon'] as List<LatLng>?;
                      return pts != null && pts.length >= 3;
                    })
                    .map((z) {
                      final pts = z['polygon'] as List<LatLng>;
                      final centroid =
                          _MiniGISMapPickerState._calculateCentroid(pts);
                      final name = z['name']?.toString() ?? 'Vùng đất';
                      final isFieldLevel = widget.level == 'FIELD';
                      return Marker(
                        point: centroid,
                        width: 140,
                        height: 24,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isFieldLevel
                                ? const Color(
                                    0xFF0C4A6E,
                                  ).withValues(alpha: 0.85)
                                : const Color(
                                    0xFF064E3B,
                                  ).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isFieldLevel
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF34D399),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),

          // Polygon ranh giới hiện tại (Màu sắc: BÁO ĐỎ khi tự cắt chéo hoặc vượt ranh giới)
          if (_polygonPoints.length >= 3)
            PolygonLayer(
              key: ValueKey(
                'gis-boundary-polygon-${_polygonPoints.length}-$_isPolygonInvalid',
              ),
              simplificationTolerance: 0,
              polygonCulling: false,
              polygons: [
                Polygon(
                  points: List<LatLng>.from(_polygonPoints),
                  color: _isPolygonInvalid
                      ? const Color(0xFFEF4444).withValues(alpha: 0.38)
                      : const Color(0xFF10B981).withValues(alpha: 0.35),
                  borderColor: _isPolygonInvalid
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669),
                  borderStrokeWidth: _isPolygonInvalid ? 3.8 : 3.2,
                ),
              ],
            ),
          // Đường viền nối các đỉnh ranh giới (PolylineLayer chuẩn native của FlutterMap)
          if (_polygonPoints.length >= 2)
            PolylineLayer(
              key: const ValueKey('gis-boundary-outline'),
              simplificationTolerance: 0,
              cullingMargin: null,
              polylines: [
                // Viền bóng lót ngoài (White Halo Casing) giúp đường viền nổi bật tuyệt đối trên ảnh vệ tinh & mọi nền
                Polyline(
                  points: _polygonPoints.length >= 3
                      ? [..._polygonPoints, _polygonPoints.first]
                      : List<LatLng>.from(_polygonPoints),
                  strokeWidth: 6.0,
                  color: Colors.white,
                  strokeJoin: StrokeJoin.round,
                  strokeCap: StrokeCap.round,
                ),
                // Đường nét viền chính màu xanh ngọc bích rực rỡ chuẩn Web (hoặc đỏ cảnh báo)
                Polyline(
                  points: _polygonPoints.length >= 3
                      ? [..._polygonPoints, _polygonPoints.first]
                      : List<LatLng>.from(_polygonPoints),
                  strokeWidth: _isPolygonInvalid ? 3.8 : 3.5,
                  color: _isPolygonInvalid
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                  strokeJoin: StrokeJoin.round,
                  strokeCap: StrokeCap.round,
                ),
              ],
            ),
          // Lớp vẽ trực tiếp (Direct Canvas Vector) đảm bảo 100% đường nối các đỉnh #1-#2-#3-#4
          // luôn hiển thị sắc nét trên cả Flutter Web (HTML/CanvasKit) và Mobile mà không bị culling hay lỗi renderer.
          if (_polygonPoints.length >= 2)
            Builder(
              builder: (boundaryContext) {
                final camera = MapCamera.of(boundaryContext);
                if (camera.size.isEmpty ||
                    !camera.size.width.isFinite ||
                    !camera.size.height.isFinite ||
                    camera.size.width <= 0 ||
                    camera.size.height <= 0) {
                  return const SizedBox.shrink();
                }
                final screenOffsets = _polygonPoints
                    .map(camera.latLngToScreenOffset)
                    .where((o) => o.dx.isFinite && o.dy.isFinite)
                    .toList(growable: false);
                if (screenOffsets.length < 2) return const SizedBox.shrink();

                return SizedBox(
                  width: camera.size.width,
                  height: camera.size.height,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: camera.size,
                      painter: _GisBoundaryPainter(
                        points: screenOffsets,
                        isInvalid: _isPolygonInvalid,
                      ),
                    ),
                  ),
                );
              },
            ),
          // Marker ghim trên bản đồ (Nếu ở FIELD sẽ cố định chính xác tại tọa độ của Farm)
          if (widget.level == 'FIELD')
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.initialCenter,
                  width: _MiniGISMapPickerState._pinSize,
                  height: _MiniGISMapPickerState._pinSize,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(
                      0,
                      -(_MiniGISMapPickerState._pinSize / 2) +
                          _MiniGISMapPickerState._pinTipInset,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: _MiniGISMapPickerState._pinTipInset - 2,
                          child: Container(
                            width: 10,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.location_on_rounded,
                          size: _MiniGISMapPickerState._pinSize,
                          color: Color(0xFF0284C7),
                        ),
                        const Positioned(
                          top: 10.75,
                          child: CircleAvatar(
                            radius: 5,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // Vùng cảm ứng kéo trực tiếp & Marker tâm ranh giới (Concentric Green Disc chuẩn giống Web)
          if (!widget.isReadOnly && _polygonPoints.length >= 3)
            MarkerLayer(
              markers: [
                // Vùng cảm ứng kéo rộng để vuốt ở giữa ô dễ dàng trên mobile
                Marker(
                  point: _getPolygonCentroid(),
                  width: _bodyHitSize(),
                  height: _bodyHitSize(),
                  alignment: Alignment.center,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) => AppHaptics.light(),
                    onPanUpdate: _onPolygonBodyDragUpdate,
                    child: const SizedBox.expand(),
                  ),
                ),
                // Center Pin Marker: Đĩa tròn đồng tâm xanh lá + viền trắng (chuẩn GISLocationPicker web)
                Marker(
                  point: _getPolygonCentroid(),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF119653),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

          // Marker các đỉnh ranh giới (#1, #2, #3...) có thể chạm & kéo trực tiếp (chỉ khi được phép sửa)
          if (!widget.isReadOnly && _polygonPoints.isNotEmpty)
            MarkerLayer(
              markers: List.generate(_polygonPoints.length, (idx) {
                final pt = _polygonPoints[idx];
                final isSelected = _selectedVertexIndex == idx;
                final isInvalid = _isVertexInvalid(pt);
                final isBeingDragged = _isDraggingVertex && isSelected;

                return Marker(
                  point: pt,
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.selection();
                      _rebuild(() {
                        _selectedVertexIndex = isSelected ? null : idx;
                      });
                    },
                    onPanStart: (details) => _onVertexDragStart(idx, details),
                    onPanUpdate: (details) => _onVertexDragUpdate(idx, details),
                    onPanEnd: (_) => _onVertexDragEnd(),
                    onPanCancel: () => _onVertexDragEnd(),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Vùng nhận cảm ứng ngón tay 72x72px rộng rãi, chống trượt
                        Container(
                          width: 72,
                          height: 72,
                          color: Colors.transparent,
                        ),
                        // Vòng halo phát sáng xung quanh khi đang chọn hoặc đang kéo
                        if (isSelected || isBeingDragged)
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  (isInvalid
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981))
                                      .withValues(alpha: 0.25),
                              border: Border.all(
                                color: isInvalid
                                    ? const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.6)
                                    : const Color(
                                        0xFF34D399,
                                      ).withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                          ),
                        // Điểm chấm tròn vertex
                        Container(
                          width: (isSelected || isInvalid) ? 22 : 17,
                          height: (isSelected || isInvalid) ? 22 : 17,
                          decoration: BoxDecoration(
                            color: isInvalid
                                ? const Color(0xFFEF4444)
                                : isSelected
                                ? const Color(0xFF059669)
                                : const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: (isSelected || isInvalid) ? 2.8 : 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isInvalid
                                    ? const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.6)
                                    : Colors.black.withValues(alpha: 0.4),
                                blurRadius: isInvalid ? 8 : 6,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                        ),
                        // Nhãn Pill: #1, #2, #3, #4
                        Positioned(
                          top: (isSelected || isBeingDragged) ? 4 : 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isInvalid
                                  ? const Color(0xFFDC2626)
                                  : isSelected
                                  ? const Color(0xFF047857)
                                  : const Color(0xFF119653),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isInvalid
                                    ? const Color(0xFFFEE2E2)
                                    : isSelected
                                    ? Colors.white
                                    : const Color(0x6634D399),
                                width: isSelected ? 1.2 : 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              '#${idx + 1}${isInvalid ? ' ⚠️' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
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

          // Node thiết bị đã chấm toạ độ (cảm biến xanh dương, van/bơm cam; offline xám).
          if (widget.nodeMarkers.isNotEmpty)
            MarkerLayer(
              markers: [
                for (final n in widget.nodeMarkers)
                  Marker(
                    point: n.point,
                    width: 26,
                    height: 26,
                    child: Tooltip(
                      message:
                          '${n.label}${n.status.isEmpty ? '' : ' · ${n.status}'}',
                      triggerMode: TooltipTriggerMode.tap,
                      child: Container(
                        key: const Key('gis_node_marker'),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              n.status.toLowerCase() == 'online' ||
                                  n.status.isEmpty
                              ? (n.type == 'ActuatorNode'
                                    ? const Color(0xFFEA580C)
                                    : const Color(0xFF0284C7))
                              : const Color(0xFF64748B),
                          // Node nằm ngoài ranh giới Zone: viền đỏ để dễ thấy toạ độ sai.
                          border: Border.all(
                            color:
                                _polygonPoints.length >= 3 &&
                                    !pointInPolygon(n.point, _polygonPoints)
                                ? const Color(0xFFDC2626)
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          n.type == 'ActuatorNode'
                              ? Icons.water_drop
                              : Icons.sensors,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    ];
  }
}

class _GisBoundaryPainter extends CustomPainter {
  const _GisBoundaryPainter({required this.points, required this.isInvalid});

  final List<Offset> points;
  final bool isInvalid;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final closed = points.length >= 3;

    // Xây dựng path bằng moveTo/lineTo thủ công thay vì addPolygon
    // để tương thích 100% với HTML5 Canvas2D, WebGL và Impeller mà không bị rụng nét trên Web.
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    if (closed) {
      path.close();
    }

    final color = isInvalid ? const Color(0xFFDC2626) : const Color(0xFF10B981);

    // 1. Tô nền polygon bán trong suốt
    if (closed) {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = (isInvalid ? const Color(0xFFEF4444) : const Color(0xFF10B981))
            .withValues(alpha: 0.35);
      canvas.drawPath(path, fillPaint);
    }

    // 2. Viền trắng phát sáng lót ngoài (Halo Casing 6.0px) giúp đường viền nổi bật trên mọi nền
    final haloStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white
      ..strokeWidth = 6.0;
    canvas.drawPath(path, haloStroke);

    // 3. Viền màu chính nối từng cặp đỉnh (#1 -> #2 -> #3 -> #4 -> #1)
    final mainStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..strokeWidth = isInvalid ? 3.8 : 3.5;
    canvas.drawPath(path, mainStroke);
  }

  @override
  bool shouldRepaint(_GisBoundaryPainter oldDelegate) => true;
}
