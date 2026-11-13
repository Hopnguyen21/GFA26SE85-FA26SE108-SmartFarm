import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/models.dart' show ZoneModel;
import 'map_zoom_controls.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';

/// Xem các Node đã chấm trong Zone và tình trạng của từng Node (chỉ xem, không sửa): vị trí trên bản đồ có ranh giới Zone,
/// trạng thái trực tuyến/mất kết nối, pin, tín hiệu, lần thấy gần nhất và kết quả kiểm tra kết nối.
/// Dữ liệu đọc từ backend (vị trí đã lưu + thiết bị của trang trại); không dùng telemetry vì kỹ thuật viên không có quyền đó.
/// Dùng được ở mọi giai đoạn của công việc, kể cả khi đã hoàn tất hoặc chưa đủ điều kiện gắn Node.
class PlacedNodesScreen extends StatefulWidget {
  final String zoneId;
  final String farmId;
  final ZoneModel? zone;
  const PlacedNodesScreen({
    super.key,
    required this.zoneId,
    required this.farmId,
    this.zone,
  });

  @override
  State<PlacedNodesScreen> createState() => _PlacedNodesScreenState();
}

class _PlacedNode {
  final String id;
  final String address;
  final String type;
  final double lat;
  final double lng;
  final String status;
  final num? battery;
  final num? rssi;
  final String? lastSeen;
  final bool? testOk;
  const _PlacedNode({
    required this.id,
    required this.address,
    required this.type,
    required this.lat,
    required this.lng,
    required this.status,
    this.battery,
    this.rssi,
    this.lastSeen,
    this.testOk,
  });

  bool get actuator => type.toUpperCase().contains('ACTUATOR');
}

/// Nhãn trạng thái tiếng Việt và mức độ (true = tốt, false = lỗi, null = chưa có dữ liệu).
({String label, bool? ok}) nodeStatusInfo(String status) {
  switch (status.toLowerCase()) {
    case 'online':
    case '4':
      return (label: 'Trực tuyến', ok: true);
    case 'offline':
      return (label: 'Mất kết nối', ok: false);
    case 'maintenancerequired':
      return (label: 'Cần bảo trì', ok: false);
    case 'assigned':
    case 'sensorsconfigured':
    case 'actuatorsconfigured':
      return (label: 'Đã gán, chưa nhận dữ liệu', ok: null);
    case 'unassigned':
      return (label: 'Chưa gán Zone', ok: null);
    case 'decommissioned':
      return (label: 'Đã gỡ khỏi hệ thống', ok: false);
    default:
      return (label: status.isEmpty ? 'Chưa rõ' : status, ok: null);
  }
}

class _PlacedNodesScreenState extends State<PlacedNodesScreen> {
  List<_PlacedNode> _nodes = [];
  ZoneModel? _zone;
  bool _loading = true;
  String? _error;
  String? _selected;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    _zone = widget.zone;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Vị trí đã lưu là dữ liệu bắt buộc: lỗi thì báo lỗi, không coi là "chưa có Node".
      final locs = await FarmApi.getDeviceMapLocations(widget.zoneId);
      // Thông tin bổ sung (lần thấy gần nhất, kiểm tra kết nối) và ranh giới Zone: lỗi thì chỉ thiếu phần đó.
      final results = await Future.wait<Object?>([
        DeploymentApi.getFarmDevicesRaw(
          widget.farmId,
        ).then<Object?>((v) => v).catchError((_) => null),
        if (_zone == null)
          FarmApi.getZone(
            widget.zoneId,
          ).then<Object?>((v) => v).catchError((_) => null),
      ]);
      final devices = results[0] is List
          ? (results[0] as List).cast<Map<String, dynamic>>()
          : const <Map<String, dynamic>>[];
      if (_zone == null && results.length > 1 && results[1] is ZoneModel) {
        _zone = results[1] as ZoneModel;
      }
      final byId = {
        for (final d in devices) '${d['deviceId']}'.toLowerCase(): d,
      };
      final nodes = <_PlacedNode>[];
      for (final l in locs) {
        final lat = (l['latitude'] as num?)?.toDouble();
        final lng = (l['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final id = '${l['deviceId']}';
        final raw = byId[id.toLowerCase()];
        final test = raw?['latestConnectionTest'];
        nodes.add(
          _PlacedNode(
            id: id,
            address: '${l['hardwareAddress'] ?? raw?['hardwareAddress'] ?? id}',
            type: '${l['deviceType'] ?? raw?['deviceType'] ?? ''}',
            lat: lat,
            lng: lng,
            status: '${raw?['status'] ?? l['status'] ?? ''}',
            battery: l['batteryLevel'] as num?,
            rssi: l['rssi'] as num?,
            lastSeen: raw?['lastSeenAtUtc']?.toString(),
            testOk: test is Map ? test['succeeded'] == true : null,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  Widget _map_() {
    final poly = _zone?.polygon;
    final hasPoly = poly != null && poly.length >= 3;
    final center = hasPoly
        ? LatLng(
            poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length,
            poly.map((p) => p.longitude).reduce((a, b) => a + b) / poly.length,
          )
        : (_nodes.isNotEmpty
              ? LatLng(_nodes.first.lat, _nodes.first.lng)
              : const LatLng(11.94, 108.44));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 18,
              initialCameraFit: hasPoly
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints([
                        ...poly,
                        for (final n in _nodes) LatLng(n.lat, n.lng),
                      ]),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 19,
                    )
                  : null,
              minZoom: 3,
              maxZoom: 22,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.smartfarm.mobile',
                maxZoom: 22,
                maxNativeZoom: 19,
              ),
              if (hasPoly)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: poly,
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      borderColor: const Color(0xFF10B981),
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final n in _nodes)
                    Marker(
                      point: LatLng(n.lat, n.lng),
                      width: 90,
                      height: 52,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = n.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                n.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: nodeStatusInfo(n.status).ok == false
                                    ? AppColors.danger
                                    : (n.actuator
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF059669)),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: n.id == _selected
                                      ? const Color(0xFF38BDF8)
                                      : Colors.white,
                                  width: n.id == _selected ? 3 : 2.5,
                                ),
                              ),
                              child: Icon(
                                n.actuator ? Icons.bolt : Icons.sensors,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: MapZoomControls(controller: _map),
          ),
          Positioned(
            left: 8,
            top: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hasPoly
                      ? '${_zone?.name ?? 'Zone'} · ${_nodes.length} Node'
                      : 'Zone chưa có ranh giới GIS · ${_nodes.length} Node',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, height: 1.3, color: color),
          ),
        ),
      ],
    ),
  );

  Widget _tile(_PlacedNode n) {
    final st = nodeStatusInfo(n.status);
    final color = st.ok == true
        ? AppColors.primaryDark
        : (st.ok == false ? AppColors.danger : AppColors.textMuted);
    final selected = n.id == _selected;
    final seen = n.lastSeen;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.info.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: selected ? AppColors.info : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: () {
          setState(() => _selected = n.id);
          _map.move(LatLng(n.lat, n.lng), 19);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: st.ok == true
                          ? const Color(0xFF10B981)
                          : (st.ok == false
                                ? AppColors.danger
                                : AppColors.textFaint),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      n.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 17, top: 2),
                child: Text(
                  st.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              _row(
                n.actuator ? Icons.bolt : Icons.sensors,
                n.actuator ? 'Node điều khiển' : 'Node cảm biến',
                AppColors.textMuted,
              ),
              _row(
                Icons.place_outlined,
                'Vị trí: ${n.lat.toStringAsFixed(6)}, ${n.lng.toStringAsFixed(6)}',
                AppColors.textMuted,
              ),
              _row(
                Icons.battery_std_outlined,
                n.battery == null
                    ? 'Pin: chưa có dữ liệu'
                    : 'Pin: ${n.battery}%',
                AppColors.textMuted,
              ),
              _row(
                Icons.signal_cellular_alt,
                n.rssi == null
                    ? 'Tín hiệu: chưa có dữ liệu'
                    : 'Tín hiệu (RSSI): ${n.rssi} dBm',
                AppColors.textMuted,
              ),
              _row(
                Icons.wifi_tethering,
                seen == null || seen.isEmpty || seen == 'null'
                    ? 'Heartbeat thực tế: chưa nhận'
                    : 'Thấy gần nhất: $seen',
                AppColors.textMuted,
              ),
              _row(
                n.testOk == null
                    ? Icons.help_outline
                    : (n.testOk!
                          ? Icons.check_circle_outline
                          : Icons.error_outline),
                n.testOk == null
                    ? 'Kiểm tra kết nối (KTV nhập): chưa có'
                    : 'Kiểm tra kết nối (KTV nhập thủ công): ${n.testOk! ? 'đạt' : 'không đạt'}',
                n.testOk == null
                    ? AppColors.textMuted
                    : (n.testOk! ? AppColors.primaryDark : AppColors.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Node đã chấm · ${_zone?.name ?? 'Zone'}'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _nodes.isEmpty && _error == null) {
      return const AppLoading(message: 'Đang tải các Node đã chấm...');
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    final online = _nodes
        .where((n) => nodeStatusInfo(n.status).ok == true)
        .length;
    final offline = _nodes
        .where((n) => nodeStatusInfo(n.status).ok == false)
        .length;
    final summary = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '${_nodes.length} Node đã chấm · $online trực tuyến · $offline mất kết nối/lỗi · ${_nodes.length - online - offline} chưa nhận dữ liệu',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
    final list = _nodes.isEmpty
        ? const AppEmptyState(
            icon: Icons.sensors_off_outlined,
            message: 'Chưa có Node nào được chấm vị trí trong Zone này.',
          )
        : Column(children: [for (final n in _nodes) _tile(n)]);
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    children: [summary, list],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                    child: _map_(),
                  ),
                ),
              ],
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              summary,
              SizedBox(height: 280, child: _map_()),
              const SizedBox(height: 10),
              list,
            ],
          );
        },
      ),
    );
  }
}
