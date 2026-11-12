import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../zones/zone_detail_screen.dart';

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
      if (((poly[i].latitude > p.latitude) !=
              (poly[j].latitude > p.latitude)) &&
          (p.longitude <
              (poly[j].longitude - poly[i].longitude) *
                      (p.latitude - poly[i].latitude) /
                      (poly[j].latitude - poly[i].latitude) +
                  poly[i].longitude)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Mọi đỉnh của Field/Zone có ranh giới hợp lệ, dùng để căn khung bản đồ ôm trọn toàn bộ.
  List<LatLng> _allPoints(FarmProvider p) =>
      [...p.fields.map((f) => f.polygon), ...p.allZones.map((z) => z.polygon)]
          .whereType<List<LatLng>>()
          .where((x) => x.length >= 3)
          .expand((x) => x)
          .toList();

  /// Tâm bản đồ: toạ độ trang trại nếu có, nếu không thì tâm đa giác đầu tiên, cuối cùng là toàn quốc.
  (LatLng, double) _initialView(FarmProvider p) {
    final farm = p.currentFarm;
    final allPolys = [
      ...p.fields.map((f) => f.polygon),
      ...p.allZones.map((z) => z.polygon),
    ].whereType<List<LatLng>>().where((x) => x.isNotEmpty).toList();
    if (allPolys.isNotEmpty) {
      final pts = allPolys.expand((x) => x).toList();
      final lat =
          pts.map((e) => e.latitude).reduce((a, b) => a + b) / pts.length;
      final lng =
          pts.map((e) => e.longitude).reduce((a, b) => a + b) / pts.length;
      return (LatLng(lat, lng), 16);
    }
    if (farm.latitude != 0 || farm.longitude != 0)
      return (LatLng(farm.latitude, farm.longitude), 15);
    return (_fallbackCenter, 5);
  }

  /// Tâm polygon để đặt nhãn.
  LatLng _centroid(List<LatLng> pts) {
    final lat = pts.map((e) => e.latitude).reduce((a, b) => a + b) / pts.length;
    final lng =
        pts.map((e) => e.longitude).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final (center, zoom) = _initialView(provider);
    final allPoints = _allPoints(provider);
    final loadError = provider.structureError ?? provider.syncError;
    final zones = provider.allZones
        .where((z) => z.polygon != null && z.polygon!.length >= 3)
        .toList();
    final fields = provider.fields
        .where((f) => f.polygon != null && f.polygon!.length >= 3)
        .toList();
    ZoneModel? selected;
    for (final z in provider.allZones) {
      if (z.zoneId == _selectedZoneId) selected = z;
    }
    final hasGeometry = zones.isNotEmpty || fields.isNotEmpty;

    // Các Field/Zone tồn tại nhưng chưa có ranh giới
    final fieldsNoGeo = provider.fields
        .where(
          (f) =>
              (f.polygon == null || f.polygon!.length < 3) &&
              f.boundaryProblem == null,
        )
        .toList();
    final zonesNoGeo = provider.allZones
        .where(
          (z) =>
              (z.polygon == null || z.polygon!.length < 3) &&
              z.boundaryProblem == null,
        )
        .toList();
    // Có dữ liệu ranh giới nhưng không đọc được: lỗi dữ liệu hình học, không phải "chưa vẽ".
    final invalidGeo = <String>[
      for (final f in provider.fields)
        if (f.boundaryProblem != null)
          'Thửa đất "${f.name}": ${f.boundaryProblem}',
      for (final z in provider.allZones)
        if (z.boundaryProblem != null) 'Zone "${z.name}": ${z.boundaryProblem}',
    ];
    final hasMissingGeo = fieldsNoGeo.isNotEmpty || zonesNoGeo.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          provider.currentFarm.farmId.isEmpty
              ? 'Bản đồ GIS'
              : provider.currentFarm.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
            key: ValueKey(
              '${center.latitude},${center.longitude},$zoom,${allPoints.length}',
            ),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              // Có ranh giới thì ôm trọn toàn bộ Field/Zone thay vì zoom cố định (trang trại lớn không bị lệch khỏi màn hình).
              initialCameraFit: allPoints.length >= 3
                  ? CameraFit.coordinates(
                      coordinates: allPoints,
                      padding: const EdgeInsets.all(56),
                      maxZoom: 18,
                    )
                  : null,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, point) {
                for (final z in zones) {
                  if (_inPolygon(point, z.polygon!)) {
                    setState(() => _selectedZoneId = z.zoneId);
                    return;
                  }
                }
                if (_selectedZoneId != null)
                  setState(() => _selectedZoneId = null);
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
                      color: const Color(0xFF10B981).withValues(
                        alpha: z.zoneId == _selectedZoneId ? 0.45 : 0.25,
                      ),
                      borderColor: z.zoneId == _selectedZoneId
                          ? Colors.white
                          : const Color(0xFF10B981),
                      borderStrokeWidth: z.zoneId == _selectedZoneId ? 3 : 2,
                    ),
                ],
              ),
              // Nhãn Field (tên Thửa đất)
              MarkerLayer(
                markers: [
                  for (final f in fields)
                    Marker(
                      point: _centroid(f.polygon!),
                      width: 120,
                      height: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0284C7,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          f.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  // Nhãn Zone (tên Zone)
                  for (final z in zones)
                    Marker(
                      point: _centroid(z.polygon!),
                      width: 110,
                      height: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF064E3B,
                          ).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          z.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Trạng thái: Đang tải ──────────────────────────────────────────
          if (provider.isLoadingApi)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _InfoCard(
                icon: Icons.sync,
                color: const Color(0xFF0284C7),
                text: 'Đang tải dữ liệu bản đồ…',
              ),
            ),

          // ── Trạng thái: Lỗi API ───────────────────────────────────────────
          if (!provider.isLoadingApi && loadError != null)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _InfoCard(
                icon: Icons.cloud_off,
                color: Colors.red.shade700,
                text: hasGeometry
                    ? 'Lỗi tải dữ liệu, bản đồ có thể chưa đầy đủ: $loadError'
                    : 'Lỗi tải dữ liệu bản đồ: $loadError',
                onRetry: () => provider.fetchFromApi(),
              ),
            ),
          if (!provider.isLoadingApi &&
              loadError == null &&
              invalidGeo.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _InfoCard(
                icon: Icons.report_problem_outlined,
                color: const Color(0xFFB45309),
                text:
                    'Dữ liệu ranh giới không hợp lệ (máy chủ đã trả nhưng không vẽ được):\n${invalidGeo.join('\n')}',
              ),
            ),

          // ── Trạng thái: Có ranh giới nhưng một số chưa có ─────────────────
          if (!provider.isLoadingApi &&
              loadError == null &&
              invalidGeo.isEmpty &&
              hasGeometry &&
              hasMissingGeo)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _MissingGeoBanner(
                fieldsNoGeo: fieldsNoGeo,
                zonesNoGeo: zonesNoGeo,
              ),
            ),

          // ── Trạng thái: Không có ranh giới nào và không lỗi API ───────────
          if (!provider.isLoadingApi &&
              loadError == null &&
              invalidGeo.isEmpty &&
              !hasGeometry)
            Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: _NoGeometryCard(
                fieldsNoGeo: fieldsNoGeo,
                zonesNoGeo: zonesNoGeo,
              ),
            ),

          // ── Panel thông tin Zone được chọn ────────────────────────────────
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
                      Text(
                        selected.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thửa đất: ${selected.fieldName.isEmpty ? '—' : selected.fieldName}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Cây trồng: ${selected.currentCrop}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Diện tích: ${selected.areaM2 > 0 ? '${selected.areaM2.toStringAsFixed(0)} m²' : '—'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (selected.telemetryIsFresh)
                        Text(
                          'Ẩm đất ${selected.currentSoilMoisture}% · ${selected.currentTemp}°C · Ẩm KK ${selected.currentHumidity}%',
                          style: const TextStyle(fontSize: 12),
                        )
                      else
                        const Text(
                          'Chưa có số đo mới từ cảm biến.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                          ),
                        ),
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

// ─────────────────────────── Helper Widgets ───────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onRetry;
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.text,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Tải lại')),
          ],
        ),
      ),
    );
  }
}

/// Banner cảnh báo khi một số Field/Zone chưa có ranh giới (nhưng có cái khác đã có).
class _MissingGeoBanner extends StatelessWidget {
  final List<FieldModel> fieldsNoGeo;
  final List<ZoneModel> zonesNoGeo;
  const _MissingGeoBanner({
    required this.fieldsNoGeo,
    required this.zonesNoGeo,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFB45309),
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Chưa có ranh giới:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...fieldsNoGeo.map(
              (f) => Text(
                '• Thửa đất: ${f.name}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
              ),
            ),
            ..._zoneLinks(context, zonesNoGeo, const Color(0xFF78350F)),
            const SizedBox(height: 4),
            const Text(
              'Chạm vào tên Zone để mở chi tiết và vẽ ranh giới (chủ trang trại). Thửa đất chưa có ranh giới: app chưa có chức năng vẽ, cần bổ sung trên web.',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card khi không có ranh giới nào.
class _NoGeometryCard extends StatelessWidget {
  final List<FieldModel> fieldsNoGeo;
  final List<ZoneModel> zonesNoGeo;
  const _NoGeometryCard({required this.fieldsNoGeo, required this.zonesNoGeo});

  @override
  Widget build(BuildContext context) {
    final hasItems = fieldsNoGeo.isNotEmpty || zonesNoGeo.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF6B7280),
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Chưa có ranh giới nào được vẽ.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (hasItems) ...[
              const SizedBox(height: 6),
              ...fieldsNoGeo.map(
                (f) => Text(
                  '• Thửa đất: ${f.name}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              ..._zoneLinks(context, zonesNoGeo, const Color(0xFF6B7280)),
              const SizedBox(height: 6),
              const Text(
                'Chạm vào tên Zone để mở chi tiết và vẽ ranh giới (chủ trang trại). Thửa đất chưa có ranh giới: app chưa có chức năng vẽ, cần bổ sung trên web.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
            ] else
              const Text(
                'Trang trại chưa có Thửa đất hoặc Zone nào.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Zone chưa có ranh giới: chạm để mở chi tiết Zone (nơi có nút "Vẽ ranh giới" cho chủ trang trại).
List<Widget> _zoneLinks(
  BuildContext context,
  List<ZoneModel> zones,
  Color color,
) {
  return [
    for (final z in zones)
      InkWell(
        onTap: () {
          // Mở theo zoneId: màn chi tiết tự tra Zone theo ID trong provider.
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ZoneDetailScreen(zone: z)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            '• Zone: ${z.name}  ›',
            style: TextStyle(
              fontSize: 11,
              color: color,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
  ];
}
