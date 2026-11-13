part of '../zone_operations_screens.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 2. Node trong Zone: số đo theo từng node + vị trí GIS (sửa hàng loạt cho Owner/KTV)
// ═══════════════════════════════════════════════════════════════════════════
class ZoneNodesScreen extends StatelessWidget {
  final String zoneId;
  final String zoneName;

  /// Cho phép sửa toạ độ (Owner/Technician). Farmer chỉ xem.
  final bool canEditLocations;
  final String? deploymentRequestId;
  final String? serviceRequestId;

  const ZoneNodesScreen({
    super.key,
    required this.zoneId,
    required this.zoneName,
    this.canEditLocations = false,
    this.deploymentRequestId,
    this.serviceRequestId,
  });

  static const _paramVi = {
    'SoilMoisture': 'Độ ẩm đất',
    'Temperature': 'Nhiệt độ',
    'AirHumidity': 'Độ ẩm KK',
    'LightIntensity': 'Ánh sáng',
    'Ph': 'pH',
    'Ec': 'EC',
  };

  /// Số đo mới nhất (chỉ Owner/Nhân công được đọc) là tùy chọn: kỹ thuật viên bị chặn route này nhưng vẫn phải thấy và
  /// sửa được toạ độ node. Vị trí node lỗi thì vẫn báo lỗi như cũ.
  Future<(List<Map<String, dynamic>>, List<Map<String, dynamic>>, bool)>
  _load() async {
    var telemetryOk = true;
    final results = await Future.wait<List<Map<String, dynamic>>>([
      FarmApi.getLatestTelemetryByDevice(zoneId).catchError((Object _) {
        telemetryOk = false;
        return <Map<String, dynamic>>[];
      }),
      FarmApi.getDeviceMapLocations(zoneId),
    ]);
    return (results[0], results[1], telemetryOk);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Node trong Zone · $zoneName',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body:
          _AsyncList<
            (List<Map<String, dynamic>>, List<Map<String, dynamic>>, bool)
          >(
            load: _load,
            builder: (context, data, reload) {
              final (devices, locations, telemetryOk) = data;
              final locById = {
                for (final l in locations) '${l['deviceId']}'.toLowerCase(): l,
              };
              final ids = <String>{
                ...devices.map((d) => '${d['deviceId']}'.toLowerCase()),
                ...locById.keys,
              }.toList();
              if (ids.isEmpty)
                return _empty(
                  'Zone chưa có node nào được gán.',
                  Icons.sensors_off,
                );
              final devById = {
                for (final d in devices) '${d['deviceId']}'.toLowerCase(): d,
              };
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!telemetryOk)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Chưa có số đo mới nhất của node (tài khoản này không được xem số đo); vẫn xem và sửa được toạ độ.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _muted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (canEditLocations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_location_alt_outlined),
                        label: const Text('Cập nhật toạ độ các node'),
                        onPressed: () async {
                          final saved = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _EditNodeLocationsScreen(
                                zoneId: zoneId,
                                locations: locations,
                                deploymentRequestId: deploymentRequestId,
                                serviceRequestId: serviceRequestId,
                              ),
                            ),
                          );
                          if (saved == true) await reload();
                        },
                      ),
                    ),
                  for (final id in ids) _nodeCard(devById[id], locById[id]),
                ],
              );
            },
          ),
    );
  }

  Widget _nodeCard(Map<String, dynamic>? d, Map<String, dynamic>? loc) {
    final addr = d?['hardwareAddress'] ?? loc?['hardwareAddress'] ?? '—';
    final type = d?['deviceType'] ?? loc?['deviceType'] ?? '';
    final status = '${d?['status'] ?? loc?['status'] ?? ''}';
    final battery = d?['batteryLevel'] ?? loc?['batteryLevel'];
    final rssi = d?['rssi'] ?? loc?['rssi'];
    final metrics = (d?['metrics'] as List? ?? const []).cast<Map>();
    final lat = (loc?['latitude'] as num?)?.toDouble();
    final lng = (loc?['longitude'] as num?)?.toDouble();
    final online = status == 'Online';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: online ? _green : _muted, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${loc?['deviceName'] ?? addr}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                status.isEmpty ? '' : status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: online ? _green : _muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$type · $addr'
            '${battery != null ? ' · 🔋 $battery%' : ''}'
            '${rssi != null ? ' · 📶 $rssi dBm' : ''}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          const SizedBox(height: 4),
          Text(
            lat != null && lng != null
                ? '📍 ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'
                : '📍 Chưa có toạ độ',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in metrics)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: m['isFresh'] == true
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_paramVi['${m['parameterCode']}'] ?? m['parameterCode']}: ${m['value']} ${m['unit'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: _ink),
                    ),
                  ),
              ],
            ),
          ] else if (d != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Chưa có số đo.',
                style: TextStyle(fontSize: 11, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditNodeLocationsScreen extends StatefulWidget {
  final String zoneId;
  final List<Map<String, dynamic>> locations;
  final String? deploymentRequestId;
  final String? serviceRequestId;
  const _EditNodeLocationsScreen({
    required this.zoneId,
    required this.locations,
    this.deploymentRequestId,
    this.serviceRequestId,
  });
  @override
  State<_EditNodeLocationsScreen> createState() =>
      _EditNodeLocationsScreenState();
}

class _EditNodeLocationsScreenState extends State<_EditNodeLocationsScreen> {
  late final List<
    (Map<String, dynamic>, TextEditingController, TextEditingController)
  >
  _rows = [
    for (final l in widget.locations)
      (
        l,
        TextEditingController(text: l['latitude']?.toString() ?? ''),
        TextEditingController(text: l['longitude']?.toString() ?? ''),
      ),
  ];
  bool _saving = false;

  @override
  void dispose() {
    for (final r in _rows) {
      r.$2.dispose();
      r.$3.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final nodes = <Map<String, dynamic>>[];
    for (final (l, latC, lngC) in _rows) {
      if (latC.text.trim().isEmpty && lngC.text.trim().isEmpty) continue;
      final lat = double.tryParse(latC.text.trim().replaceAll(',', '.'));
      final lng = double.tryParse(lngC.text.trim().replaceAll(',', '.'));
      if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
        _toast(
          context,
          'Toạ độ của ${l['hardwareAddress']} không hợp lệ.',
          error: true,
        );
        return;
      }
      nodes.add({
        'deviceId': l['deviceId'],
        'latitude': lat,
        'longitude': lng,
        'batteryLevel': l['batteryLevel'],
        'rssi': l['rssi'],
        'hardwareAddress': l['hardwareAddress'],
        'deviceType': l['deviceType'],
        'deviceName': l['deviceName'],
        'locationSource': 'MobileManual',
      });
    }
    if (nodes.isEmpty) {
      _toast(context, 'Chưa nhập toạ độ cho node nào.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await FarmApi.updateDeviceLocations(
        widget.zoneId,
        nodes,
        deploymentRequestId: widget.deploymentRequestId,
        serviceRequestId: widget.serviceRequestId,
      );
      if (!mounted) return;
      _toast(context, 'Đã lưu toạ độ ${nodes.length} node.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toạ độ node', style: TextStyle(fontSize: 15)),
      ),
      body: _rows.isEmpty
          ? const Center(
              child: Text(
                'Không có node nào để cập nhật.',
                style: TextStyle(color: _muted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (l, latC, lngC) in _rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l['deviceName'] ?? l['hardwareAddress']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: latC,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Vĩ độ',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: lngC,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Kinh độ',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving || _rows.isEmpty ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Lưu toạ độ'),
          ),
        ),
      ),
    );
  }
}
