import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/offline_gis_cache_service.dart';
import '../../core/widgets/mini_gis_map_picker.dart';
import '../../core/utils/haptics.dart';
import '../zones/zone_detail_screen.dart';

/// Bản đồ GIS hiển thị ranh giới Thửa đất/Zone THẬT lấy từ backend (không có dữ liệu mẫu).
/// Node đã chấm toạ độ được vẽ từ GET /zones/{id}/devices/map-locations (mất mạng thì dùng bản lưu đệm, có ghi chú).
class GISMapScreen extends StatefulWidget {
  const GISMapScreen({super.key});

  @override
  State<GISMapScreen> createState() => _GISMapScreenState();
}

class _GISMapScreenState extends State<GISMapScreen> {
  final MapController _mapController = MapController();
  String _mapType = 'osm';
  String? _selectedZoneId;

  static const LatLng _fallbackCenter = LatLng(16.0, 106.0);

  // Node thiết bị đã chấm toạ độ (GET /zones/{id}/devices/map-locations) của mọi Zone có ranh giới.
  List<MapNodeMarker> _nodes = const [];
  String _nodesKey = '';
  bool _nodesFailed = false;

  /// Tải node khi danh sách Zone có ranh giới đổi; lỗi/không có quyền thì bản đồ vẫn hiện ranh giới, chỉ báo "chưa tải được node".
  void _syncNodes(List<ZoneModel> zones) {
    final key = zones.map((z) => z.zoneId).join(',');
    if (key == _nodesKey) return;
    _nodesKey = key;
    () async {
      var failed = false;
      final results = await Future.wait(
        zones.map((z) async {
          try {
            final locs = await FarmApi.getDeviceMapLocations(z.zoneId);
            if (locs.isNotEmpty) {
              await OfflineGisCacheService.cacheZoneNodes(z.zoneId, locs);
            }
            return locs;
          } catch (_) {
            failed = true;
            final cached = await OfflineGisCacheService.getCachedZoneNodes(z.zoneId);
            if (cached != null && cached.isNotEmpty) {
              return cached;
            }
            return const <Map<String, dynamic>>[];
          }
        }),
      );
      final all = <MapNodeMarker>[];
      for (final rows in results) {
        for (final r in rows) {
          final m = MapNodeMarker.fromJson(r);
          if (m != null) all.add(m);
        }
      }
      if (mounted && key == _nodesKey) {
        setState(() {
          _nodes = all;
          _nodesFailed = failed;
        });
      }
    }();
  }

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

  void _fitAll(List<LatLng> allPoints, LatLng fallbackCenter) {
    AppHaptics.light();
    try {
      if (allPoints.length >= 3) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: allPoints,
            padding: const EdgeInsets.all(56),
            maxZoom: 18,
          ),
        );
      } else {
        _mapController.move(fallbackCenter, 15);
      }
    } catch (_) {}
  }

  void _zoomIn() {
    AppHaptics.light();
    try {
      _mapController.move(
        _mapController.camera.center,
        _mapController.camera.zoom + 1,
      );
    } catch (_) {}
  }

  void _zoomOut() {
    AppHaptics.light();
    try {
      _mapController.move(
        _mapController.camera.center,
        _mapController.camera.zoom - 1,
      );
    } catch (_) {}
  }

  void _showFarmSelector(BuildContext context, FarmProvider provider) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Chọn Trang Trại Hiển Thị',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final f in provider.farms)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                leading: Icon(
                  Icons.eco,
                  color: f.farmId == provider.currentFarm.farmId
                      ? const Color(0xFF10B981)
                      : const Color(0xFF94A3B8),
                ),
                title: Text(
                  f.name,
                  style: TextStyle(
                    fontWeight: f.farmId == provider.currentFarm.farmId
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  f.address.isNotEmpty ? f.address : 'Chưa có địa chỉ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: f.farmId == provider.currentFarm.farmId
                    ? const Icon(Icons.check, color: Color(0xFF10B981))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (f.farmId != provider.currentFarm.farmId) {
                    AppHaptics.selection();
                    provider.selectFarm(f.farmId);
                    setState(() {
                      _selectedZoneId = null;
                      _nodes = const [];
                      _nodesKey = '';
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showNodeDetailSheet(BuildContext context, MapNodeMarker node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          16 + MediaQuery.of(ctx).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (node.status.toLowerCase() == 'online'
                            ? const Color(0xFF059669)
                            : const Color(0xFF64748B))
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    node.type == 'ActuatorNode'
                        ? Icons.water_drop
                        : Icons.sensors,
                    color: node.status.toLowerCase() == 'online'
                        ? const Color(0xFF059669)
                        : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.type == 'ActuatorNode'
                            ? 'Trạm điều khiển rơ-le / van'
                            : 'Trạm cảm biến vi khí hậu',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: node.status.toLowerCase() == 'online'
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    node.status.isEmpty ? 'Chưa rõ' : node.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: node.status.toLowerCase() == 'online'
                          ? const Color(0xFF065F46)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Toạ độ định vị trên bản đồ:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${node.point.latitude.toStringAsFixed(6)}, ${node.point.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerPills() {
    const types = [
      ('osm', 'OSM'),
      ('street', 'Đường phố'),
      ('satellite', 'Vệ tinh'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, label) in types)
            InkWell(
              onTap: () {
                if (_mapType != id) {
                  AppHaptics.selection();
                  setState(() => _mapType = id);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _mapType == id ? const Color(0xFF047857) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: _mapType == id ? FontWeight.bold : FontWeight.w500,
                    color: _mapType == id ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingMapTools(List<LatLng> allPoints, LatLng center) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 20, color: Color(0xFF0F172A)),
            tooltip: 'Phóng to',
            onPressed: _zoomIn,
          ),
          const Divider(height: 1, indent: 6, endIndent: 6),
          IconButton(
            icon: const Icon(Icons.remove, size: 20, color: Color(0xFF0F172A)),
            tooltip: 'Thu nhỏ',
            onPressed: _zoomOut,
          ),
          const Divider(height: 1, indent: 6, endIndent: 6),
          IconButton(
            icon: const Icon(Icons.my_location, size: 18, color: Color(0xFF047857)),
            tooltip: 'Căn giữa trang trại',
            onPressed: () => _fitAll(allPoints, center),
          ),
        ],
      ),
    );
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
    _syncNodes(zones);
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
    // Kỹ thuật viên chỉ thấy trang trại có yêu cầu được giao và không đọc được số đo cảm biến của trang trại.
    final isTech = provider.currentRole == 'TECHNICIAN';
    final techNoAssignment =
        isTech &&
        !provider.isLoadingApi &&
        loadError == null &&
        provider.allZones.isEmpty &&
        provider.fields.isEmpty;
    final hasTopBanner = provider.isLoadingApi ||
        loadError != null ||
        invalidGeo.isNotEmpty ||
        (hasGeometry && hasMissingGeo) ||
        techNoAssignment ||
        (!hasGeometry && !techNoAssignment);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        iconTheme: const IconThemeData(color: Colors.white),
        title: provider.farms.length > 1
            ? InkWell(
                onTap: () => _showFarmSelector(context, provider),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
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
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    ],
                  ),
                ),
              )
            : Text(
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
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            tooltip: 'Căn giữa trang trại',
            onPressed: () => _fitAll(allPoints, center),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers, color: Colors.white),
            tooltip: 'Loại bản đồ',
            onSelected: (v) {
              AppHaptics.selection();
              setState(() => _mapType = v);
            },
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
          RepaintBoundary(
            child: FlutterMap(
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
                      borderStrokeWidth: 2.2,
                      pattern: StrokePattern.dashed(segments: const [6, 6]),
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
                      height: 28,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _selectedZoneId = z.zoneId);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: z.zoneId == _selectedZoneId
                                ? const Color(0xFF047857)
                                : const Color(0xFF064E3B).withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: z.zoneId == _selectedZoneId
                                  ? Colors.white
                                  : const Color(0x6634D399),
                              width: z.zoneId == _selectedZoneId ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            z.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Node cảm biến/chấp hành đã chấm toạ độ: xanh = Online, xám = Offline/chưa rõ
              MarkerLayer(
                markers: [
                  for (final n in _nodes)
                    Marker(
                      point: n.point,
                      width: 32,
                      height: 32,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          AppHaptics.light();
                          _showNodeDetailSheet(context, n);
                        },
                        child: Tooltip(
                          message:
                              '${n.label}${n.status.isEmpty ? '' : ' · ${n.status}'}',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: n.status.toLowerCase() == 'online'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              n.type == 'ActuatorNode'
                                  ? Icons.water_drop
                                  : Icons.sensors,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          ),

          // ── Cụm chọn lớp bản đồ nổi (OSM / Đường phố / Vệ tinh) ────────────
          Positioned(
            right: 14,
            top: hasTopBanner ? 88 : 14,
            child: _buildLayerPills(),
          ),

          // ── Cụm công cụ bản đồ nổi (Zoom In / Out / Fit) ──────────────────
          Positioned(
            right: 14,
            bottom: (selected != null ? 240 : 65) +
                MediaQuery.of(context).padding.bottom,
            child: _buildFloatingMapTools(allPoints, center),
          ),

          // ── Chú giải node ─────────────────────────────────────────────────
          if (hasGeometry && selected == null)
            Positioned(
              left: 14,
              bottom: 14 + MediaQuery.of(context).padding.bottom,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _nodesFailed && _nodes.isNotEmpty
                      ? 'Mất kết nối: đang hiện ${_nodes.length} node từ bản lưu trước (vị trí/trạng thái có thể đã cũ)'
                      : _nodesFailed
                      ? 'Chưa tải được vị trí node'
                      : _nodes.isEmpty
                      ? 'Chưa có node nào được chấm toạ độ'
                      : '${_nodes.length} node trên bản đồ (xanh: Online · xám: Offline/chưa rõ)',
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
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
                onRetry: () {
                  // Xoá khoá để lần build sau tải lại cả toạ độ node (cùng danh sách Zone thì _syncNodes bỏ qua).
                  _nodesKey = '';
                  provider.fetchFromApi();
                },
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
          if (techNoAssignment)
            const Positioned(
              left: 16,
              right: 16,
              top: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.map_outlined, color: Color(0xFF0284C7)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Chưa có trang trại nào được giao cho bạn. '
                          'Tiếp nhận một yêu cầu ở tab Dịch Vụ (Yêu cầu triển khai) để xem vị trí lắp đặt trên bản đồ.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!provider.isLoadingApi &&
              loadError == null &&
              invalidGeo.isEmpty &&
              !hasGeometry &&
              !techNoAssignment)
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
              left: 14,
              right: 14,
              bottom: 14 + MediaQuery.of(context).padding.bottom,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF047857,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded,
                            color: Color(0xFF047857),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selected.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            AppHaptics.light();
                            setState(() => _selectedZoneId = null);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Thửa đất: ${selected.fieldName.isEmpty ? '—' : selected.fieldName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'Cây trồng: ${selected.currentCrop.trim().isEmpty ? '—' : selected.currentCrop}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                        Text(
                          'Diện tích: ${selected.areaM2 > 0 ? '${selected.areaM2.toStringAsFixed(0)} m²' : '—'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isTech)
                      const SizedBox.shrink()
                    else if (selected.telemetryIsFresh)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sensors,
                              size: 14,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ẩm đất ${selected.currentSoilMoisture}% · ${selected.currentTemp}°C · Ẩm KK ${selected.currentHumidity}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCD34D)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.sensors_off_outlined,
                              size: 14,
                              color: Color(0xFFB45309),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Chưa có số đo mới từ cảm biến.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          AppHaptics.light();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ZoneDetailScreen(zone: selected!),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text(
                          'Xem chi tiết Zone',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      shadowColor: Colors.black26,
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      shadowColor: Colors.black26,
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
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      shadowColor: Colors.black26,
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
