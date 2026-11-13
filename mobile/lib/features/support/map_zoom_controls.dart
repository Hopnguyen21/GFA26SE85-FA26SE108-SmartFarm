import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Nút phóng to / thu nhỏ bản đồ (+ / −) đặt chồng lên bản đồ, để phóng được cả khi không dùng được cử chỉ hai ngón.
class MapZoomControls extends StatelessWidget {
  final MapController controller;
  final double minZoom;
  final double maxZoom;
  const MapZoomControls({
    super.key,
    required this.controller,
    this.minZoom = 3,
    this.maxZoom = 22,
  });

  void _zoom(double delta) {
    final cam = controller.camera;
    controller.move(
      cam.center,
      (cam.zoom + delta).clamp(minZoom, maxZoom).toDouble(),
    );
  }

  Widget _btn(IconData icon, String tip, double delta) => Material(
    color: Colors.white,
    elevation: 2,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _zoom(delta),
      child: Tooltip(
        message: tip,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 24, color: const Color(0xFF0F172A)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _btn(Icons.add, 'Phóng to', 1),
      const SizedBox(height: 8),
      _btn(Icons.remove, 'Thu nhỏ', -1),
    ],
  );
}
