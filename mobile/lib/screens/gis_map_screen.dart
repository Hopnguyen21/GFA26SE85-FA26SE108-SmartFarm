import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/farm_provider.dart';

/// Bản đồ GIS hiển thị ranh giới Thửa đất/Zone THẬT lấy từ backend (không có dữ liệu mẫu).
/// Gateway/Node/Actuator không được vẽ vì API hiện không trả toạ độ cho chúng.
class GISMapScreen extends StatefulWidget {
  const GISMapScreen({super.key});

  @override
  State<GISMapScreen> createState() => _GISMapScreenState();
}

class _GISMapScreenState extends State<GISMapScreen> {
  final MapController _mapController = MapController();
  String _mapType = 'satellite';
  String? _selectedZoneId;

  static const LatLng _fallbackCenter = LatLng(16.0, 106.0);

  String _tileUrl() {
    switch (_mapType) {
      case 'satellite':
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'street':
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  bool _inPolygon(LatLng p, List<LatLng> poly) {
    var inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].latitude > p.latitude) != (poly[j].latitude > p.latitude)) &&
          (p.longitude <
              (poly[j].longitude - poly[i].longitude) * (p.latitude - poly[i].latitude) /
                      (poly[j].latitude - poly[i].latitude) +
                  poly[i].longitude)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Tâm bản đồ: toạ độ trang trại nếu có, nếu không thì tâm đa giác đầu tiên, cuối cùng là toàn quốc.
  (LatLng, double) _initialView(FarmProvider p) {
    final farm = p.currentFarm;
    final allPolys = [
      ...p.fields.map((f) => f.polygon),
      ...p.allZones.map((z) => z.polygon),
    ].whereType<List<LatLng>>().where((x) => x.isNotEmpty).toList();
    if (allPolys.isNotEmpty) {
      final pts = allPolys.expand((x) => x).toList();
      final lat = pts.map((e) => e.latitude).reduce((a, b) => a + b) / pts.length;
      final lng = pts.map((e) => e.longitude).reduce((a, b) => a + b) / pts.length;
      return (LatLng(lat, lng), 16);
    }
    if (farm.latitude != 0 || farm.longitude != 0) return (LatLng(farm.latitude, farm.longitude), 15);
    return (_fallbackCenter, 5);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final (center, zoom) = _initialView(provider);
    final zones = provider.allZones.where((z) => z.polygon != null && z.polygon!.length >= 3).toList();
    final fields = provider.fields.where((f) => f.polygon != null && f.polygon!.length >= 3).toList();
    ZoneModel? selected;
    for (final z in provider.allZones) {
      if (z.zoneId == _selectedZoneId) selected = z;
    }
    final hasGeometry = zones.isNotEmpty || fields.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          provider.currentFarm.farmId.isEmpty ? 'Bản đồ GIS' : provider.currentFarm.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers, color: Colors.white),
            tooltip: 'Loại bản đồ',
            onSelected: (v) => setState(() => _mapType = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'satellite', child: Text('Vệ tinh')),
              PopupMenuItem(value: 'street', child: Text('Đường phố')),
              PopupMenuItem(value: 'osm', child: Text('OpenStreetMap')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            key: ValueKey('${center.latitude},${center.longitude},$zoom'),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, point) {
                for (final z in zones) {
                  if (_inPolygon(point, z.polygon!)) {
                    setState(() => _selectedZoneId = z.zoneId);
                    return;
                  }
                }
                if (_selectedZoneId != null) setState(() => _selectedZoneId = null);
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_mapType),
                urlTemplate: _tileUrl(),
                userAgentPackageName: 'com.smartfarm.mobile',
                maxZoom: 20,
              ),
              PolygonLayer(
                polygons: [
                  for (final f in fields)
                    Polygon(
                      points: f.polygon!,
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderColor: const Color(0xFF0284C7),
                      borderStrokeWidth: 2,
                    ),
                  for (final z in zones)
                    Polygon(
                      points: z.polygon!,
                      color: const Color(0xFF10B981).withValues(alpha: z.zoneId == _selectedZoneId ? 0.45 : 0.25),
                      borderColor: z.zoneId == _selectedZoneId ? Colors.white : const Color(0xFF10B981),
                      borderStrokeWidth: z.zoneId == _selectedZoneId ? 3 : 2,
                    ),
                ],
              ),
            ],
          ),
          if (!hasGeometry)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    provider.isLoadingApi
                        ? 'Đang tải dữ liệu bản đồ…'
                        : 'Chưa có ranh giới Thửa đất/Zone nào được vẽ cho trang trại này.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          if (selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Thửa đất: ${selected.fieldName.isEmpty ? '—' : selected.fieldName}', style: const TextStyle(fontSize: 12)),
                      Text('Cây trồng: ${selected.currentCrop}', style: const TextStyle(fontSize: 12)),
                      Text('Diện tích: ${selected.areaM2 > 0 ? '${selected.areaM2.toStringAsFixed(0)} m²' : '—'}', style: const TextStyle(fontSize: 12)),
                      if (selected.telemetryIsFresh)
                        Text(
                          'Ẩm đất ${selected.currentSoilMoisture}% · ${selected.currentTemp}°C · Ẩm KK ${selected.currentHumidity}%',
                          style: const TextStyle(fontSize: 12),
                        )
                      else
                        const Text('Chưa có số đo mới từ cảm biến.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
