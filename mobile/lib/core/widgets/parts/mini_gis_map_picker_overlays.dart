part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateOverlays on _MiniGISMapPickerState {
  List<Widget> _topOverlaysSection(BuildContext context, double currentHeight) {
    return [
      // Ghim cố định ở tâm màn hình (chỉ hiện khi định vị Farm, ẩn ở FIELD & ZONE để không vướng ô ranh giới)
      if (widget.level == 'FARM')
        Center(
          child: IgnorePointer(
            child: Transform.translate(
              offset: const Offset(0, -(_MiniGISMapPickerState._pinSize / 2) + _MiniGISMapPickerState._pinTipInset),
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
                  const Positioned(top: 10.75, child: CircleAvatar(radius: 5, backgroundColor: Colors.white)),
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
                  widget.level == 'FIELD' ? 'Trùng tọa độ Farm: $_displayPlaceName' : _displayPlaceName,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _rebuild(() => _mapType = 'satellite'),
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
                          fontSize: 11,
                          fontWeight: _mapType == 'satellite' ? FontWeight.bold : FontWeight.normal,
                          color: _mapType == 'satellite' ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _rebuild(() => _mapType = 'street'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _mapType == 'street' ? const Color(0xFF1E293B) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined, size: 11, color: _mapType == 'street' ? Colors.white : Colors.black87),
                      const SizedBox(width: 3),
                      Text(
                        'Bản đồ',
                        style: TextStyle(
                          fontSize: 11,
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
    ];
  }

  List<Widget> _bottomOverlaysSection(BuildContext context, double currentHeight) {
    return [
      Positioned(
        bottom: 30,
        right: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isLockedCenter && !widget.isReadOnly) ...[
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 3,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openLocationSearch,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(Icons.search, size: 20, color: Color(0xFF0F172A)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Nút Mở rộng / Thu nhỏ bản đồ (Fullscreen / Collapse Toggle)
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              elevation: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _rebuild(() {
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
                ? [BoxShadow(color: Colors.red.withValues(alpha: 0.5), blurRadius: 6, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isReadOnly
                    ? Icons.lock_outline_rounded
                    : (_isPolygonInvalid ? Icons.warning_amber_rounded : Icons.touch_app_rounded),
                size: 13,
                color: widget.isReadOnly ? const Color(0xFF38BDF8) : Colors.white,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.isReadOnly
                      ? 'Ranh giới GIS đang khóa cố định • Bấm "Sửa GIS" để điều chỉnh'
                      : (_overlappedZoneName != null
                            ? 'CẢNH BÁO: Đang chồng đè lên "$_overlappedZoneName"! Vui lòng điều chỉnh lại.'
                            : (_hasPointOutsideParent
                                  ? 'CẢNH BÁO: Đỉnh đang nằm ngoài Thửa đất! Vui lòng kéo lại vào trong.'
                                  : (widget.level == 'FIELD' || widget.level == 'ZONE'
                                        ? (_selectedVertexIndex != null
                                              ? 'Đang chọn đỉnh #${_selectedVertexIndex! + 1}: Chạm vị trí mới hoặc kéo để di chuyển'
                                              : 'Chạm đỉnh để chọn • Chạm ngoài để thêm đỉnh • Chạm trong ô để dời cả ô')
                                        : 'Chạm hoặc kéo bản đồ như Google Maps'))),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: (!widget.isReadOnly && _isPolygonInvalid) ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!widget.isReadOnly && _selectedVertexIndex != null && _polygonPoints.length > 3) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: _deleteSelectedVertex,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 10, color: Colors.white),
                        SizedBox(width: 2),
                        Text(
                          'Xóa đỉnh',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.close, size: 11, color: Colors.white),
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
          bottom: 34,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF38BDF8), width: 0.8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đỉnh #${_selectedVertexIndex! + 1}:',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                _nudgeBtn(Icons.arrow_upward, () => _nudgeSelectedVertex(1.5, 0.0)),
                _nudgeBtn(Icons.arrow_downward, () => _nudgeSelectedVertex(-1.5, 0.0)),
                _nudgeBtn(Icons.arrow_back, () => _nudgeSelectedVertex(0.0, -1.5)),
                _nudgeBtn(Icons.arrow_forward, () => _nudgeSelectedVertex(0.0, 1.5)),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _nudgeBtn(IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(3),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
