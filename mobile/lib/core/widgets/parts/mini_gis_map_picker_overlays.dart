part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateOverlays on _MiniGISMapPickerState {
  List<Widget> _topOverlaysSection(BuildContext context, double currentHeight) {
    return [
      // Ghim cố định ở tâm màn hình (chỉ hiện khi định vị Farm, ẩn ở FIELD & ZONE để không vướng ô ranh giới)
      if (widget.level == 'FARM')
        Center(
          child: IgnorePointer(
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
                    color: Color(0xFFEA4335),
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
        ),

      // Top-Left Realtime HUD Info Badge (4 đỉnh | Diện tích m² chuẩn web - chỉ cho FIELD/ZONE)
      if (widget.level != 'FARM')
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            key: const ValueKey('gis-area-chip'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isPolygonInvalid
                  ? const Color(0xFFDC2626)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isPolygonInvalid
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFFCBD5E1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _polygonPoints.length >= 3
                ? Text(
                    '${_polygonPoints.length} đỉnh · Diện tích: ${_formatAreaM2(_calculateApproxAreaM2(_polygonPoints))} m²',
                    style: TextStyle(
                      color: _isPolygonInvalid
                          ? Colors.white
                          : const Color(0xFF047857),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        size: 13,
                        color: Color(0xFF119653),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          'Cần ít nhất 3 đỉnh (đang có ${_polygonPoints.length})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

      // Với FARM: hiển thị địa danh tại vị trí ghim
      if (widget.level == 'FARM')
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            key: const ValueKey('gis-farm-address-chip'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 13,
                  color: Color(0xFF119653),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    _displayPlaceName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

      // Top-Right Map Mode Pill (OSM / Đường phố / Vệ tinh chuẩn web GISLocationPicker)
      Positioned(
        top: 8,
        right: 8,
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapTypeTab('osm', 'OSM'),
              _buildMapTypeTab('street', 'Đường phố'),
              _buildMapTypeTab('satellite', 'Vệ tinh'),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildMapTypeTab(String type, String label) {
    final isActive = _mapType == type;
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        _rebuild(() => _mapType = type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF119653) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  /// 27112 → "27.112" (dấu chấm ngăn nhóm nghìn, theo cách đọc số của Việt Nam).
  String _formatAreaM2(double v) => v.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );

  List<Widget> _bottomOverlaysSection(
    BuildContext context,
    double currentHeight,
  ) {
    final showOutsideWarning =
        !widget.isReadOnly &&
        widget.level == 'ZONE' &&
        _hasPointOutsideParent;
    return [
      // Floating Controls (Bottom-Right): Nút zoom, GPS & Nút "Mở rộng Map" xanh lá chuẩn Web
      Positioned(
        bottom: 24,
        right: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Cụm nút công cụ nhỏ (GPS, Zoom +/-)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isLockedCenter && !widget.isReadOnly) ...[
                  Material(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(6),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        AppHaptics.light();
                        _openLocationSearch();
                      },
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.search,
                          size: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      AppHaptics.selection();
                      final fit = _boundaryCameraFit();
                      if (fit != null) {
                        _mapController.fitCamera(fit);
                      } else {
                        _moveTo(widget.initialCenter, zoom: widget.initialZoom);
                      }
                    },
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.gps_fixed_rounded,
                        size: 16,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(6),
                  elevation: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(6),
                        ),
                        onTap: () {
                          AppHaptics.light();
                          try {
                            final nextZoom = (_mapController.camera.zoom + 1.0)
                                .clamp(9.0, 20.0);
                            _mapController.move(
                              _mapController.camera.center,
                              nextZoom,
                            );
                          } catch (_) {}
                        },
                        child: const SizedBox(
                          width: 28,
                          height: 30,
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 16,
                        color: const Color(0xFFE2E8F0),
                      ),
                      InkWell(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(6),
                        ),
                        onTap: () {
                          AppHaptics.light();
                          try {
                            final nextZoom = (_mapController.camera.zoom - 1.0)
                                .clamp(9.0, 20.0);
                            _mapController.move(
                              _mapController.camera.center,
                              nextZoom,
                            );
                          } catch (_) {}
                        },
                        child: const SizedBox(
                          width: 28,
                          height: 30,
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Nút "Mở rộng Map" xanh lá chuẩn Web Image 3
            GestureDetector(
              onTap: () {
                AppHaptics.light();
                _rebuild(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF119653),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.9),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF119653).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isExpanded
                          ? Icons.close_fullscreen_rounded
                          : Icons.open_in_full_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isExpanded ? 'Thu nhỏ' : 'Mở rộng Map',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Chú giải màu chuẩn Web (gis-legend): chỉ hiện ở cấp ZONE khi có ranh giới Thửa đất mẹ
      if (!widget.isReadOnly &&
          widget.level == 'ZONE' &&
          widget.parentPolygon != null &&
          widget.parentPolygon!.length >= 3)
        Positioned(
          bottom: 24,
          left: 8,
          child: IgnorePointer(
            child: Container(
              key: const ValueKey('gis-legend'),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5.5,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.parentPolygon != null &&
                      widget.parentPolygon!.length >= 3) ...[
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: const Color(0xFF0284C7),
                          width: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Phân khu mẹ',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _isPolygonInvalid
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Hiện tại (${widget.level})',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

      // Attribution Leaflet / OpenStreetMap chuẩn web GISLocationPicker
      Positioned(
        bottom: 3,
        right: 8,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(3),
            ),
            // Ghi nguồn đúng lớp bản đồ đang hiện: OSM hay ô bản đồ Google (Đường phố / Vệ tinh).
            child: Text(
              _mapType == 'osm'
                  ? '© OpenStreetMap contributors'
                  : 'Dữ liệu bản đồ © Google',
              style: const TextStyle(
                fontSize: 8.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),

      // Bottom Alert / Action / Lock Pill: chỉ hiện khi đang chọn đỉnh hoặc ở ZONE khi đỉnh ra ngoài Thửa đất mẹ
      if (widget.isReadOnly ||
          _selectedVertexIndex != null ||
          showOutsideWarning)
        Positioned(
          bottom: 4,
          left: 8,
          right: 8,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: showOutsideWarning
                  ? const Color(0xFFDC2626) // Cảnh báo đỏ nổi bật
                  : Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: showOutsideWarning
                      ? Colors.red.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isReadOnly
                      ? Icons.lock_outline_rounded
                      : (showOutsideWarning
                            ? Icons.warning_amber_rounded
                            : Icons.touch_app_rounded),
                  size: 13,
                  color: widget.isReadOnly
                      ? const Color(0xFF38BDF8)
                      : Colors.white,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    widget.isReadOnly
                        ? 'Ranh giới GIS đang khóa cố định • Bấm "Sửa GIS" để điều chỉnh'
                        : (showOutsideWarning
                              ? 'CẢNH BÁO: Đỉnh đang nằm ngoài Thửa đất! Vui lòng kéo lại vào trong.'
                              : (_selectedVertexIndex != null
                                    ? 'Đang chọn đỉnh #${_selectedVertexIndex! + 1}: Chạm vị trí mới hoặc kéo để di chuyển'
                                    : 'Chạm đỉnh để chọn • Chạm ngoài để thêm đỉnh')),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: showOutsideWarning
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!widget.isReadOnly &&
                    _selectedVertexIndex != null &&
                    _polygonPoints.length > 3) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: _deleteSelectedVertex,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 10,
                            color: Colors.white,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Xóa đỉnh',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!widget.isReadOnly && _selectedVertexIndex != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _rebuild(() => _selectedVertexIndex = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

      // Bảng phím vi chỉnh (Nudge D-pad) khi đang chọn 1 đỉnh cụ thể (chỉ khi được phép sửa)
      if (!widget.isReadOnly && _selectedVertexIndex != null)
        Positioned(
          bottom: 42,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Đỉnh #${_selectedVertexIndex! + 1}',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _nudgeBtn(
                  Icons.arrow_upward,
                  () => _nudgeSelectedVertex(1.5, 0.0),
                ),
                _nudgeBtn(
                  Icons.arrow_downward,
                  () => _nudgeSelectedVertex(-1.5, 0.0),
                ),
                _nudgeBtn(
                  Icons.arrow_back,
                  () => _nudgeSelectedVertex(0.0, -1.5),
                ),
                _nudgeBtn(
                  Icons.arrow_forward,
                  () => _nudgeSelectedVertex(0.0, 1.5),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _nudgeBtn(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.5),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
