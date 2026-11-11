part of '../mini_gis_map_picker.dart';

extension _MiniGISMapPickerStateInteraction on _MiniGISMapPickerState {
  void _notifyArea() {
    final area = _calculateApproxAreaM2(_polygonPoints);
    widget.onAreaCalculated?.call(area);
  }

  /// Cảm ứng kéo trực tiếp để di chuyển toàn bộ ô thửa đất
  void _onPolygonBodyDragUpdate(DragUpdateDetails details) {
    if (_polygonPoints.isEmpty) return;
    final dGeo = _screenOffsetToLatLngDelta(details.delta);
    _rebuild(() {
      _polygonPoints = _shiftPolygon(_polygonPoints, dGeo.latitude, dGeo.longitude);
      _selectedVertexIndex = null;
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  /// Thêm đỉnh mới vào vị trí cạnh gần nhất của polygon
  void _insertPointIntoPolygon(LatLng newPoint) {
    if (_polygonPoints.length < 3) {
      _rebuild(() {
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

    _rebuild(() {
      _polygonPoints.insert(bestIndex, newPoint);
      _selectedVertexIndex = bestIndex;
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
  }

  /// Cảm ứng kéo trực tiếp một đỉnh cụ thể (#1..#4)
  void _onVertexDragUpdate(int index, DragUpdateDetails details) {
    if (index < 0 || index >= _polygonPoints.length) return;
    final dGeo = _screenOffsetToLatLngDelta(details.delta);
    _rebuild(() {
      _selectedVertexIndex = index;
      final p = _polygonPoints[index];
      _polygonPoints[index] = LatLng(p.latitude + dGeo.latitude, p.longitude + dGeo.longitude);
    });
    widget.onPolygonChanged?.call(_polygonPoints);
    _notifyArea();
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
    _rebuild(() {
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
    if (widget.isReadOnly) return;
    if (widget.level == 'FIELD' || widget.level == 'ZONE') {
      // Nếu đang chọn một đỉnh (#1, #2, #3...): Chạm bất kỳ đâu trên bản đồ để di chuyển đỉnh đó tới vị trí mới
      if (_selectedVertexIndex != null) {
        final idx = _selectedVertexIndex!;
        if (idx >= 0 && idx < _polygonPoints.length) {
          // Kiểm tra vi phạm ranh giới mẹ nếu có
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

          _rebuild(() {
            _polygonPoints[idx] = point;
          });
          widget.onPolygonChanged?.call(_polygonPoints);
          _notifyArea();
          return;
        }
      }

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
        _rebuild(() {
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
    _rebuild(() => _polygonPoints = _shiftPolygon(_polygonPoints, dLat, dLng));
    widget.onCenterChanged?.call(c);

    // Vô hiệu response cũ ngay lập tức, báo "đang lấy" một lần
    _debounceTimer?.cancel();
    _requestId++;
    if (!_addressPending) {
      _addressPending = true;
      widget.onAddressLoading?.call();
    }

    // Reverse-geocoding goes through the shared public Nominatim provider; wait until the user stops moving the map.
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      widget.onPolygonChanged?.call(_polygonPoints);
      _resolveAddress(_currentCenter); // luôn dùng tâm mới nhất
    });
  }
}
