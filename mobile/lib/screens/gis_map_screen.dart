import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GISMapScreen extends StatefulWidget {
  const GISMapScreen({super.key});

  @override
  State<GISMapScreen> createState() => _GISMapScreenState();
}

class _GISMapScreenState extends State<GISMapScreen> {
  // Map Controller
  final MapController _mapController = MapController();

  // Map display settings: 'osm' | 'street' | 'satellite'
  String _mapType = 'satellite';

  // Layer filters
  bool _showGateways = true;
  bool _showNodes = true;
  bool _showActuators = true;
  bool _showZones = true;

  // Selected item (Node, Gateway, Actuator, Zone)
  Map<String, dynamic>? _selectedItem;

  // Coordinate reference system center (Da Lat Farm)
  static const LatLng _centerCoord = LatLng(11.9404, 108.4583);
  static const double _initialZoom = 16.2;

  // Data matching Farm & IoT exactly
  static const Map<String, dynamic> _farm = {
    'id': 'farm-01',
    'name': 'Trang trại Nông nghiệp Thông minh Đà Lạt',
    'address': 'Phường 11, TP. Đà Lạt, Lâm Đồng',
    'area': '5.0 ha (50,000 m²)',
    'status': 'ACTIVE',
  };

  static const List<Map<String, dynamic>> _fields = [
    {
      'id': 'field-01',
      'name': 'Lô A – Khu Nhà kính Công nghệ cao',
      'area': '2.8 ha',
      'status': 'ACTIVE',
      'color': Color(0xFF0284C7),
      'polygon': [
        LatLng(11.9422, 108.4560),
        LatLng(11.9422, 108.4606),
        LatLng(11.9403, 108.4606),
        LatLng(11.9403, 108.4560),
      ]
    },
    {
      'id': 'field-02',
      'name': 'Lô B – Vườn thực nghiệm Ngoài trời',
      'area': '2.2 ha',
      'status': 'ACTIVE',
      'color': Color(0xFF10B981),
      'polygon': [
        LatLng(11.9401, 108.4560),
        LatLng(11.9401, 108.4606),
        LatLng(11.9382, 108.4606),
        LatLng(11.9382, 108.4560),
      ]
    },
  ];

  static const List<Map<String, dynamic>> _zones = [
    {
      'id': 'zone-01',
      'fieldId': 'field-01',
      'name': 'Nhà màng 01 – Dâu tây New Zealand',
      'crop': 'Dâu tây New Zealand',
      'stage': 'Ra hoa & Nuôi quả',
      'area': '8,000 m²',
      'system': 'Thủy canh hồi lưu tự động',
      'color': Color(0xFF3B82F6),
      'polygon': [
        LatLng(11.9420, 108.4564),
        LatLng(11.9420, 108.4583),
        LatLng(11.9405, 108.4583),
        LatLng(11.9405, 108.4564),
      ]
    },
    {
      'id': 'zone-02',
      'fieldId': 'field-01',
      'name': 'Nhà màng 02 – Rau Thủy canh NFT',
      'crop': 'Xà lách Lollo Bionda',
      'stage': 'Tăng trưởng sinh dưỡng',
      'area': '7,500 m²',
      'system': 'Hệ thống NFT đa tầng',
      'color': Color(0xFFF59E0B),
      'polygon': [
        LatLng(11.9420, 108.4585),
        LatLng(11.9420, 108.4603),
        LatLng(11.9405, 108.4603),
        LatLng(11.9405, 108.4585),
      ]
    },
    {
      'id': 'zone-03',
      'fieldId': 'field-02',
      'name': 'Nhà màng 03 – Cà chua Cherry Nova',
      'crop': 'Cà chua Cherry Nova & Socola',
      'stage': 'Thu hoạch đợt 2',
      'area': '12,000 m²',
      'system': 'Tưới nhỏ giọt bù áp tự động',
      'color': Color(0xFF8B5CF6),
      'polygon': [
        LatLng(11.9398, 108.4564),
        LatLng(11.9398, 108.4602),
        LatLng(11.9385, 108.4602),
        LatLng(11.9385, 108.4564),
      ]
    },
  ];

  static const List<Map<String, dynamic>> _gateways = [
    {
      'id': 'gw-01',
      'code': 'GW-LORA-01',
      'name': 'Gateway LoRa Trạm Trung Tâm',
      'lat': 11.9410,
      'lng': 108.4578,
      'status': 'ONLINE',
      'mac': 'A8:40:41:1B:5F:80',
      'rssi': -72,
      'channels': '8 kênh LoRa',
      'type': 'GATEWAY',
    },
  ];

  static const List<Map<String, dynamic>> _nodes = [
    {
      'id': 'node-01',
      'code': 'NODE-01-STRAWBERRY',
      'name': 'Node Cảm Biến – Nhà màng 01',
      'zone': 'Nhà màng 01',
      'lat': 11.9413,
      'lng': 108.4573,
      'status': 'ONLINE',
      'battery': 88,
      'rssi': -68,
      'temp': 24.5,
      'humidity': 78,
      'soilMoisture': 65,
      'type': 'SENSOR_NODE',
    },
    {
      'id': 'node-02',
      'code': 'NODE-02-HYDROPONIC',
      'name': 'Node Cảm Biến – Nhà màng 02',
      'zone': 'Nhà màng 02',
      'lat': 11.9411,
      'lng': 108.4593,
      'status': 'WARNING',
      'battery': 24,
      'rssi': -89,
      'temp': 28.2,
      'humidity': 61,
      'soilMoisture': 42,
      'type': 'SENSOR_NODE',
    },
    {
      'id': 'node-03',
      'code': 'NODE-03-TOMATO',
      'name': 'Node Cảm Biến – Nhà màng 03',
      'zone': 'Nhà màng 03',
      'lat': 11.9392,
      'lng': 108.4580,
      'status': 'ONLINE',
      'battery': 95,
      'rssi': -65,
      'temp': 23.8,
      'humidity': 81,
      'soilMoisture': 70,
      'type': 'SENSOR_NODE',
    },
  ];

  static const List<Map<String, dynamic>> _actuatorInitialData = [
    {
      'id': 'act-01',
      'code': 'PUMP-01-MAIN',
      'name': 'Máy Bơm Tưới Nhỏ Giọt Zone 01',
      'zone': 'Nhà màng 01',
      'lat': 11.9416,
      'lng': 108.4570,
      'status': 'ACTIVE',
      'state': 'BẬT (Tự động theo lịch)',
      'power': '1.5 kW',
      'flow': '24.5 L/min',
      'type': 'ACTUATOR',
    },
    {
      'id': 'act-02',
      'code': 'VALVE-02-FERT',
      'name': 'Van Châm Phân Vi Lượng Zone 02',
      'zone': 'Nhà màng 02',
      'lat': 11.9415,
      'lng': 108.4590,
      'status': 'STANDBY',
      'state': 'TẮT (Chờ đo EC/pH)',
      'power': '24V DC',
      'flow': '0.0 L/min',
      'type': 'ACTUATOR',
    },
  ];

  late List<Map<String, dynamic>> _actuators;

  @override
  void initState() {
    super.initState();
    _actuators = _actuatorInitialData.map((a) => Map<String, dynamic>.from(a)).toList();
  }

  void _toggleActuator(String actId) {
    setState(() {
      final index = _actuators.indexWhere((a) => a['id'] == actId);
      if (index != -1) {
        final current = _actuators[index];
        final bool isNowActive = current['status'] != 'ACTIVE';
        _actuators[index] = {
          ...current,
          'status': isNowActive ? 'ACTIVE' : 'STANDBY',
          'state': isNowActive ? 'BẬT (Thủ công qua App)' : 'TẮT (Thủ công)',
          'flow': isNowActive ? '22.0 L/min' : '0.0 L/min',
        };
        if (_selectedItem != null && _selectedItem!['id'] == actId) {
          _selectedItem = _actuators[index];
        }
      }
    });
  }

  void _resetZoom() {
    _mapController.move(_centerCoord, _initialZoom);
  }

  void _zoomIn() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (current + 0.6).clamp(3.0, 19.0));
  }

  void _zoomOut() {
    final current = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, (current - 0.6).clamp(3.0, 19.0));
  }

  String _getTileUrl() {
    switch (_mapType) {
      case 'satellite':
        // Google Maps Satellite Tiles (Fast, high-res, reliable in VN)
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 'street':
        // Google Maps Road & Street Map
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
      case 'osm':
      default:
        // OpenStreetMap standard tiles
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  bool _isPointInPolygon(LatLng p, List<LatLng> poly) {
    bool inside = false;
    for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      if (((poly[i].latitude > p.latitude) != (poly[j].latitude > p.latitude)) &&
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 2,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bản Đồ Nông Trại GIS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _farm['name'] as String,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF34D399),
              ),
            ),
          ],
        ),
        actions: [
          // Reset Zoom / Fit
          IconButton(
            icon: const Icon(Icons.fullscreen, color: Colors.white),
            tooltip: 'Căn vừa bản đồ (Fit Zoom)',
            onPressed: _resetZoom,
          ),
          // Layers menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.layers_outlined, color: Colors.white),
            tooltip: 'Chọn chế độ bản đồ',
            onSelected: (value) => setState(() => _mapType = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'satellite',
                child: Row(
                  children: [
                    Icon(Icons.satellite_alt,
                        color: _mapType == 'satellite'
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                        size: 18),
                    const SizedBox(width: 8),
                    Text('Vệ tinh (Google)',
                        style: TextStyle(
                            fontWeight: _mapType == 'satellite'
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'street',
                child: Row(
                  children: [
                    Icon(Icons.alt_route,
                        color: _mapType == 'street'
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                        size: 18),
                    const SizedBox(width: 8),
                    Text('Đường phố (Google)',
                        style: TextStyle(
                            fontWeight: _mapType == 'street'
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'osm',
                child: Row(
                  children: [
                    Icon(Icons.map,
                        color: _mapType == 'osm'
                            ? const Color(0xFF10B981)
                            : Colors.grey,
                        size: 18),
                    const SizedBox(width: 8),
                    Text('Bản đồ OSM',
                        style: TextStyle(
                            fontWeight: _mapType == 'osm'
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Real Tile Map with flutter_map (Esri Satellite, Street, OSM)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerCoord,
              initialZoom: _initialZoom,
              minZoom: 4.0,
              maxZoom: 19.0,
              onTap: (tapPosition, point) {
                // Check if tapped inside any Zone
                for (final zone in _zones) {
                  final poly = zone['polygon'] as List<LatLng>;
                  if (_isPointInPolygon(point, poly)) {
                    setState(() {
                      _selectedItem = {
                        ...zone,
                        'type': 'ZONE',
                      };
                    });
                    return;
                  }
                }
                if (_selectedItem != null) {
                  setState(() => _selectedItem = null);
                }
              },
            ),
            children: [
              // 1. Real Tile Layer
              TileLayer(
                key: ValueKey(_mapType),
                urlTemplate: _getTileUrl(),
                userAgentPackageName: 'com.smartfarm.mobile',
                maxZoom: 20,
              ),

              // 2. Field & Zone Polygons Layer
              if (_showZones)
                PolygonLayer(
                  polygons: [
                    // Fields (parent)
                    ..._fields.map(
                      (field) => Polygon(
                        points: field['polygon'] as List<LatLng>,
                        color: (field['color'] as Color).withValues(alpha: 0.12),
                        borderColor: (field['color'] as Color),
                        borderStrokeWidth: 2.0,
                      ),
                    ),
                    // Zones (children)
                    ..._zones.map(
                      (zone) {
                        final isSelected = _selectedItem?['id'] == zone['id'];
                        return Polygon(
                          points: zone['polygon'] as List<LatLng>,
                          color: (zone['color'] as Color).withValues(alpha: isSelected ? 0.45 : 0.25),
                          borderColor: isSelected ? Colors.white : (zone['color'] as Color),
                          borderStrokeWidth: isSelected ? 3.0 : 2.0,
                        );
                      },
                    ),
                  ],
                ),

              // 3. Markers Layer (Gateways, Sensor Nodes, Actuators)
              MarkerLayer(
                markers: [
                  // Gateways
                  if (_showGateways)
                    ..._gateways.map((gw) {
                      return Marker(
                        point: LatLng(gw['lat'] as double, gw['lng'] as double),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedItem = gw),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.cell_tower, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      );
                    }),

                  // Actuators (Pumps / Valves)
                  if (_showActuators)
                    ..._actuators.map((act) {
                      final bool isActive = act['status'] == 'ACTIVE';
                      return Marker(
                        point: LatLng(act['lat'] as double, act['lng'] as double),
                        width: 42,
                        height: 42,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedItem = act),
                          child: Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFEC4899) : const Color(0xFF94A3B8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isActive ? const Color(0xFFEC4899) : Colors.black).withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.power, color: Colors.white, size: 15),
                            ),
                          ),
                        ),
                      );
                    }),

                  // Sensor Nodes
                  if (_showNodes)
                    ..._nodes.map((node) {
                      final bool isWarn = node['status'] == 'WARNING';
                      final Color pinColor = isWarn ? const Color(0xFFEAB308) : const Color(0xFF16A34A);
                      return Marker(
                        point: LatLng(node['lat'] as double, node['lng'] as double),
                        width: 80,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedItem = node),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: pinColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: pinColor.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.sensors, color: Colors.white, size: 13),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  node['id'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),

          // Top Header Filter Bar
          Positioned(
            top: 10,
            left: 12,
            right: 56, // Leave room for right zoom controls
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // Map type pill
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypePill('osm', 'OSM'),
                        _buildTypePill('street', 'Đường'),
                        _buildTypePill('satellite', 'Vệ tinh'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Filter Chips
                  _buildFilterChip('Khu vực', _showZones, (v) {
                    setState(() => _showZones = v);
                  }, const Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  _buildFilterChip('Node IoT', _showNodes, (v) {
                    setState(() => _showNodes = v);
                  }, const Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  _buildFilterChip('Gateway', _showGateways, (v) {
                    setState(() => _showGateways = v);
                  }, const Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  _buildFilterChip('Thiết bị điều khiển', _showActuators, (v) {
                    setState(() => _showActuators = v);
                  }, const Color(0xFFEC4899)),
                ],
              ),
            ),
          ),

          // Right Zoom Controls Floating Bar
          Positioned(
            top: 10,
            right: 12,
            child: Column(
              children: [
                _buildActionIconButton(Icons.add, 'Phóng to', _zoomIn),
                const SizedBox(height: 6),
                _buildActionIconButton(Icons.remove, 'Thu nhỏ', _zoomOut),
                const SizedBox(height: 6),
                _buildActionIconButton(Icons.center_focus_strong, 'Về tâm', _resetZoom),
              ],
            ),
          ),

          // Bottom Left FE-Style Legend
          Positioned(
            bottom: _selectedItem != null ? 240 : 16,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CHÚ THÍCH GIS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 5),
                  _buildLegendItem(
                    color: const Color(0xFF16A34A),
                    isCircle: true,
                    label: 'Node Online',
                  ),
                  _buildLegendItem(
                    color: const Color(0xFFEAB308),
                    isCircle: true,
                    label: 'Node Cảnh báo',
                  ),
                  _buildLegendItem(
                    color: const Color(0xFF0284C7),
                    isCircle: false,
                    label: 'Gateway LoRa',
                  ),
                  _buildLegendItem(
                    color: const Color(0xFFEC4899),
                    isCircle: true,
                    label: 'Bơm / Van tưới',
                  ),
                ],
              ),
            ),
          ),

          // Bottom Selected Item Info Card (Popup / Drawer)
          if (_selectedItem != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildDetailCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildTypePill(String type, String label) {
    final bool active = _mapType == type;
    return GestureDetector(
      onTap: () => setState(() => _mapType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF062326) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, bool isSelected, Function(bool) onToggle, Color accentColor) {
    return GestureDetector(
      onTap: () => onToggle(!isSelected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF334155).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white24,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required bool isCircle,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle ? null : BorderRadius.circular(3),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    final item = _selectedItem!;
    final String type = item['type'] ?? 'ZONE';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getBadgeBg(type),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getBadgeIcon(type), size: 16, color: _getBadgeColor(type)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (item['code'] != null)
                        Text(
                          item['code'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
                onPressed: () => setState(() => _selectedItem = null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          if (type == 'ZONE') ...[
            _buildDetailRow('Cây trồng:', item['crop'] ?? ''),
            _buildDetailRow('Giai đoạn:', item['stage'] ?? ''),
            _buildDetailRow('Diện tích:', item['area'] ?? ''),
            _buildDetailRow('Hệ thống:', item['system'] ?? ''),
          ] else if (type == 'GATEWAY') ...[
            _buildDetailRow('MAC Gateway:', item['mac'] ?? ''),
            _buildDetailRow('Trạng thái:', item['status'] ?? '', isStatus: true),
            _buildDetailRow('Sóng RSSI:', '${item['rssi']} dBm'),
            _buildDetailRow('Băng thông:', item['channels'] ?? ''),
          ] else if (type == 'SENSOR_NODE') ...[
            _buildDetailRow('Vị trí:', item['zone'] ?? ''),
            _buildDetailRow('Trạng thái:', item['status'] ?? '', isStatus: true),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow('Pin:', '${item['battery']}%'),
                ),
                Expanded(
                  child: _buildDetailRow('Sóng RSSI:', '${item['rssi']} dBm'),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow('Nhiệt độ:', '${item['temp']} °C'),
                ),
                Expanded(
                  child: _buildDetailRow('Độ ẩm:', '${item['humidity']} %'),
                ),
              ],
            ),
          ] else if (type == 'ACTUATOR') ...[
            _buildDetailRow('Vị trí:', item['zone'] ?? ''),
            _buildDetailRow('Trạng thái:', item['state'] ?? '', isStatus: true),
            _buildDetailRow('Công suất:', item['power'] ?? ''),
            _buildDetailRow('Lưu lượng:', item['flow'] ?? ''),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _toggleActuator(item['id'] as String),
                icon: Icon(
                  item['status'] == 'ACTIVE' ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  item['status'] == 'ACTIVE' ? 'Dừng thiết bị ngay' : 'Kích hoạt thiết bị ngay',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: item['status'] == 'ACTIVE' ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String val, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isStatus
                  ? (val.contains('ONLINE') || val.contains('ACTIVE') || val.contains('BẬT')
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEAB308))
                  : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeBg(String type) {
    switch (type) {
      case 'GATEWAY':
        return const Color(0xFFE0F2FE);
      case 'SENSOR_NODE':
        return const Color(0xFFDCFCE7);
      case 'ACTUATOR':
        return const Color(0xFFFCE7F3);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getBadgeColor(String type) {
    switch (type) {
      case 'GATEWAY':
        return const Color(0xFF0284C7);
      case 'SENSOR_NODE':
        return const Color(0xFF16A34A);
      case 'ACTUATOR':
        return const Color(0xFFDB2777);
      default:
        return const Color(0xFFD97706);
    }
  }

  IconData _getBadgeIcon(String type) {
    switch (type) {
      case 'GATEWAY':
        return Icons.cell_tower;
      case 'SENSOR_NODE':
        return Icons.sensors;
      case 'ACTUATOR':
        return Icons.power;
      default:
        return Icons.grass;
    }
  }
}
