part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateMapLayer on _MiniGISMapPickerState {
  List<Widget> _mapLayerSection(BuildContext context, double currentHeight) {
    return [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentCenter,
          initialZoom: widget.initialZoom,
          minZoom: 9.0,
          maxZoom: 20.0,
          interactionOptions: InteractionOptions(
            flags: _isDraggingVertex ? (InteractiveFlag.all & ~InteractiveFlag.drag) : InteractiveFlag.all,
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
                    final isFieldLevel = widget.level == 'FIELD';
                    return Polygon(
                      points: pts,
                      color: isFieldLevel
                          ? const Color(0xFF0284C7).withValues(alpha: 0.16)
                          : const Color(0xFF10B981).withValues(alpha: 0.16),
                      borderColor: isFieldLevel ? const Color(0xFF0284C7) : const Color(0xFF059669),
                      borderStrokeWidth: 1.8,
                    );
                  })
                  .toList(),
            ),

          // Nhãn tên các Vùng đã có
          if (_otherPolygons.isNotEmpty)
            MarkerLayer(
              markers: _otherPolygons
                  .where((z) {
                    final pts = z['polygon'] as List<LatLng>?;
                    return pts != null && pts.length >= 3;
                  })
                  .map((z) {
                    final pts = z['polygon'] as List<LatLng>;
                    final centroid = _MiniGISMapPickerState._calculateCentroid(pts);
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
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  })
                  .toList(),
            ),

          // Polygon ranh giới hiện tại (Màu sắc: BÁO ĐỎ khi vượt ranh giới Thửa đất mẹ HOẶC đè lên Zone khác)
          if (_polygonPoints.length >= 3)
            PolygonLayer(
              polygons: [
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
              ],
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
                      -(_MiniGISMapPickerState._pinSize / 2) + _MiniGISMapPickerState._pinTipInset,
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
                        const Positioned(top: 10.75, child: CircleAvatar(radius: 5, backgroundColor: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

          // Vùng cảm ứng kéo trực tiếp để di chuyển cả ô thửa đất khi chạm & vuốt ở giữa ô (chỉ khi được phép sửa)
          if (!widget.isReadOnly && _polygonPoints.length >= 3)
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

          // Marker các đỉnh ranh giới (#1, #2, #3...) có thể chạm & kéo trực tiếp (chỉ khi được phép sửa)
          if (!widget.isReadOnly && _polygonPoints.isNotEmpty)
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
                      _rebuild(() {
                        _selectedVertexIndex = isSelected ? null : idx;
                      });
                    },
                    onPanStart: (details) {
                      _rebuild(() {
                        _isDraggingVertex = true;
                        _selectedVertexIndex = idx;
                      });
                    },
                    onPanUpdate: (details) => _onVertexDragUpdate(idx, details),
                    onPanEnd: (_) {
                      _rebuild(() {
                        _isDraggingVertex = false;
                      });
                    },
                    onPanCancel: () {
                      _rebuild(() {
                        _isDraggingVertex = false;
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Vòng tròn lớn tăng diện tích nhận cảm ứng khi kéo ngón tay
                        Container(width: 44, height: 44, color: Colors.transparent),
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
                            border: Border.all(color: Colors.white, width: (isSelected || isInvalid) ? 2.5 : 2.0),
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
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 3)],
                            ),
                            child: Text(
                              '#${idx + 1}',
                              style: TextStyle(
                                color: (isSelected || isInvalid) ? Colors.white : const Color(0xFF38BDF8),
                                fontSize: 11,
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
    ];
  }
}
