import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart' show ZoneModel;
import '../../core/services/api_service.dart';
import '../../core/services/gps_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import 'map_zoom_controls.dart';
import 'node_placement_logic.dart';
import 'placed_nodes_screen.dart';
import 'technician_maintenance_screen.dart' show serviceStatusOf;

/// Chấm Node trên bản đồ GIS của đúng Zone, mở sau khi backend xác nhận Owner đã ký hợp đồng và cọc 30%.
/// - Danh sách cần chấm: thiết bị đã cấp phát cho yêu cầu này; các dòng hợp đồng chỉ dùng để đối chiếu số lượng theo loại
///   (Gateway, Node cảm biến, Node điều khiển), vật tư và thi công không thành Node.
/// - Backend chỉ lưu vị trí cho thiết bị ĐÃ CẤP PHÁT; chưa cấp phát thì báo rõ và dẫn tới màn cấp phát, không tạo thiết bị giả.
/// - Sau khi lưu đọc lại vị trí từ máy chủ; kiểm tra kết nối là KTV nhập thủ công, tách khỏi heartbeat thực tế của thiết bị.
class NodePlacementScreen extends StatefulWidget {
  final String serviceRequestId;
  final String farmId;
  final String zoneId;
  final String deploymentRequestId;
  final ZoneModel? zone;
  final GpsProvider gps;

  const NodePlacementScreen({
    super.key,
    required this.serviceRequestId,
    required this.farmId,
    required this.zoneId,
    required this.deploymentRequestId,
    this.zone,
    this.gps = const GeolocatorGpsProvider(),
  });

  @override
  State<NodePlacementScreen> createState() => _NodePlacementScreenState();
}

class _Draft {
  final double lat;
  final double lng;
  final String source; // MobileGPS | MobileMap
  final double? accuracyM;
  const _Draft(this.lat, this.lng, this.source, this.accuracyM);
}

class _NodePlacementScreenState extends State<NodePlacementScreen> {
  Quotation? _quotation;
  DeploymentRequest? _deployment;
  ZoneModel?
  _zone; // Zone kèm ranh giới: lấy từ màn gọi, không có thì tự tải theo mã Zone
  NodePlacementGate?
  _gate; // null = chưa xác nhận được từ backend (đang tải/lỗi): khoá
  List<IotDevice> _devices = [];
  Map<String, Map<String, dynamic>> _deviceRaw = {};
  List<Map<String, dynamic>> _gateways = [];
  Map<String, Map<String, dynamic>> _saved =
      {}; // vị trí đã lưu trên máy chủ theo deviceId (chữ thường)
  final Map<String, _Draft> _drafts = {};
  String? _selected;
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _gpsBusy = false;
  bool _completing = false;
  bool _provisioning = false;
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
      _gate = null; // không giữ quyền cũ trong lúc tải lại
    });
    try {
      // Mọi nguồn dữ liệu bắt buộc phải tải được: lỗi thì báo lỗi và cho thử lại, không coi là "danh sách trống".
      final results = await Future.wait<Object?>([
        SupportApi.getQuotation(widget.serviceRequestId),
        DeploymentApi.getDeploymentRequest(
          widget.deploymentRequestId,
          technician: true,
        ),
        DeploymentApi.getFarmDevicesRaw(widget.farmId),
        DeploymentApi.getFarmGatewaysRaw(widget.farmId),
        FarmApi.getDeviceMapLocations(widget.zoneId),
        SupportApi.getServiceRequest(widget.serviceRequestId),
        // Ranh giới Zone: kỹ thuật viên thường không có Zone trong danh sách trang trại nên tự tải; lỗi thì chỉ thiếu ranh giới.
        if (_zone == null)
          FarmApi.getZone(
            widget.zoneId,
          ).then<ZoneModel?>((z) => z).catchError((_) => null),
      ]);
      if (_zone == null && results.length > 6 && results[6] is ZoneModel) {
        _zone = results[6] as ZoneModel;
      }
      final sr = results[5] as Map<String, dynamic>;
      final dep = results[1] as DeploymentRequest;
      final quotation = results[0] as Quotation?;
      final rawDevices = (results[2] as List<Map<String, dynamic>>)
          .where(
            (d) => '${d['deploymentRequestId']}' == widget.deploymentRequestId,
          )
          .toList();
      final saved = <String, Map<String, dynamic>>{
        for (final l in results[4] as List<Map<String, dynamic>>)
          '${l['deviceId']}'.toLowerCase(): l,
      };
      if (!mounted) return;
      setState(() {
        _quotation = quotation;
        _deployment = dep;
        // Cổng chung: hợp đồng cọc 30% do backend xác nhận, chưa kết thúc, đúng Farm/Zone/triển khai (xem checkNodePlacement).
        final sameArgs =
            '${sr['zoneId']}'.toLowerCase() == widget.zoneId.toLowerCase() &&
            '${sr['deploymentRequestId']}'.toLowerCase() ==
                widget.deploymentRequestId.toLowerCase() &&
            '${sr['farmId']}'.toLowerCase() == widget.farmId.toLowerCase();
        _gate = checkNodePlacement(
          serviceStatus: serviceStatusOf(sr),
          quotationLoaded: true,
          quotationStatus: quotation?.status,
          deploymentStatus: dep.status,
          linkValid:
              sameArgs &&
              deploymentLinkValid(
                serviceFarmId: '${sr['farmId'] ?? ''}',
                serviceZoneId: '${sr['zoneId'] ?? ''}',
                serviceDeploymentId: '${sr['deploymentRequestId'] ?? ''}',
                deploymentId: dep.requestId,
                deploymentFarmId: dep.farmId,
                deploymentZoneId: dep.zoneId,
              ),
        );
        _deviceRaw = {
          for (final d in rawDevices) '${d['deviceId']}'.toLowerCase(): d,
        };
        _devices = [for (final d in rawDevices) IotDevice.fromJson(d)];
        _gateways = (results[3] as List<Map<String, dynamic>>)
            .where(
              (g) =>
                  '${g['deploymentRequestId']}' == widget.deploymentRequestId,
            )
            .toList();
        _saved = saved;
        _loading = false;
        _selected ??= _devices.isEmpty ? null : _devices.first.deviceId;
      });
      _refreshMqtt();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  List<({double lat, double lng})>? get _polygon => _zone?.polygon == null
      ? null
      : [for (final p in _zone!.polygon!) (lat: p.latitude, lng: p.longitude)];

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
  }

  IotDevice? get _selectedDevice => _devices
      .where((d) => d.deviceId.toLowerCase() == _selected?.toLowerCase())
      .firstOrNull;

  /// Lấy GPS hiện tại làm điểm của Node đang chọn; xử lý quyền, GPS lỗi, sai số lớn và điểm ngoài Zone.
  Future<void> _useGps() async {
    final d = _selectedDevice;
    if (d == null) {
      _snack('Hãy chọn một thiết bị trước khi cập nhật vị trí.', error: true);
      return;
    }
    if (_gpsBusy) return;
    setState(() => _gpsBusy = true);
    try {
      final fix = await widget.gps.current();
      if (!mounted) return;
      final verdict = evaluateFix(
        lat: fix.latitude,
        lng: fix.longitude,
        accuracyM: fix.accuracyM,
        polygon: _polygon,
      );
      switch (verdict) {
        case FixVerdict.outsideZone:
          _snack(
            'Vị trí GPS hiện tại nằm ngoài ranh giới Zone. Hãy đứng trong Zone hoặc chấm tay trên bản đồ.',
            error: true,
          );
          return;
        case FixVerdict.tooInaccurate:
          _snack(
            'GPS quá kém (sai số ±${fix.accuracyM.round()} m, cần ≤ ${gpsRejectAccuracyM.round()} m). Ra chỗ thoáng rồi thử lại.',
            error: true,
          );
          return;
        case FixVerdict.poorAccuracy:
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Độ chính xác GPS thấp'),
              content: Text(
                'Sai số khoảng ±${fix.accuracyM.round()} m (tốt là ≤ ${gpsGoodAccuracyM.round()} m). Vẫn dùng điểm này cho ${d.hardwareAddress}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Đo lại'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Vẫn dùng'),
                ),
              ],
            ),
          );
          if (ok != true || !mounted) return;
        case FixVerdict.noBoundary:
          _snack(
            'Zone chưa có ranh giới GIS nên không kiểm tra được điểm có nằm trong Zone.',
          );
        case FixVerdict.ok:
          break;
      }
      setState(() {
        _drafts[d.deviceId.toLowerCase()] = _Draft(
          fix.latitude,
          fix.longitude,
          'MobileGPS',
          fix.accuracyM,
        );
      });
      _map.move(LatLng(fix.latitude, fix.longitude), 19);
    } on GpsException catch (e) {
      _snack(e.message, error: true);
    } catch (e) {
      _snack('Không đọc được GPS: ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _gpsBusy = false);
    }
  }

  /// Lưu các điểm đã chấm. Chặn bấm lưu liên tục; xong thì đọc lại vị trí từ máy chủ để đối chiếu.
  Future<void> _save() async {
    if (_saving || _drafts.isEmpty) return;
    setState(() => _saving = true);
    final sent = Map<String, _Draft>.of(_drafts);
    try {
      final nodes = <Map<String, dynamic>>[];
      for (final e in sent.entries) {
        final d = _devices.firstWhere((x) => x.deviceId.toLowerCase() == e.key);
        nodes.add({
          'deviceId': d.deviceId,
          'latitude': e.value.lat,
          'longitude': e.value.lng,
          'hardwareAddress': d.hardwareAddress,
          'deviceType': d.deviceType,
          'locationSource': e.value.source,
          'deviceName': e.value.accuracyM == null
              ? d.hardwareAddress
              : '${d.hardwareAddress} (GPS ±${e.value.accuracyM!.round()} m)',
        });
      }
      await FarmApi.updateDeviceLocations(
        widget.zoneId,
        nodes,
        serviceRequestId: widget.serviceRequestId,
        deploymentRequestId: widget.deploymentRequestId,
      );
      // Đọc lại từ máy chủ: chỉ coi là đã lưu khi thấy đúng toạ độ.
      final back = await FarmApi.getDeviceMapLocations(widget.zoneId);
      final byId = {for (final l in back) '${l['deviceId']}'.toLowerCase(): l};
      final missing = <String>[];
      for (final e in sent.entries) {
        final l = byId[e.key];
        final lat = (l?['latitude'] as num?)?.toDouble();
        final lng = (l?['longitude'] as num?)?.toDouble();
        if (lat == null ||
            lng == null ||
            (lat - e.value.lat).abs() > 1e-5 ||
            (lng - e.value.lng).abs() > 1e-5) {
          missing.add(e.key);
        }
      }
      if (!mounted) return;
      setState(() {
        _saved = byId;
        for (final k in sent.keys.where((k) => !missing.contains(k))) {
          _drafts.remove(k);
        }
      });
      await _load();
      _snack(
        missing.isEmpty
            ? 'Đã lưu và đọc lại từ máy chủ: ${sent.length} node.'
            : 'Đã gửi nhưng máy chủ chưa trả đúng vị trí cho ${missing.length} node. Hãy bấm Lưu lại.',
        error: missing.isNotEmpty,
      );
    } catch (e) {
      _snack('Không lưu được vị trí: ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// KTV tự nhập kết quả kiểm tra kết nối: không phải telemetry/heartbeat thật.
  Future<void> _recordTest(IotDevice d) async {
    final input = await showDialog<_TestInput>(
      context: context,
      builder: (_) => _TestDialog(label: d.hardwareAddress),
    );
    if (input == null || !mounted) return;
    try {
      await DeploymentApi.recordConnectionTest(
        widget.deploymentRequestId,
        deviceId: d.deviceId,
        succeeded: input.succeeded,
        rssi: input.rssi,
        snr: input.snr,
        latencyMs: input.latencyMs,
        errorCode: input.errorCode,
        errorMessage: input.errorMessage,
      );
      await _load();
      _snack('Đã ghi kết quả kiểm tra kết nối (KTV xác nhận thủ công).');
    } catch (e) {
      _snack('Không ghi được kết quả: ${friendlyError(e)}', error: true);
    }
  }

  Future<void> _complete() async {
    if (_completing) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hoàn tất lắp đặt?'),
        content: const Text(
          'Triển khai sẽ chuyển sang Hoàn tất và Owner được thanh toán 70% để nghiệm thu. Backend sẽ kiểm tra lại số lượng thiết bị và kết quả kết nối.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Chưa'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _completing = true);
    try {
      await DeploymentApi.completeDeploymentRequest(widget.deploymentRequestId);
      await _load();
      _snack('Đã hoàn tất lắp đặt. Owner có thể thanh toán 70% và nghiệm thu.');
    } catch (e) {
      _snack('Chưa hoàn tất được: ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Cấp phát thiết bị thật cho một dòng hợp đồng chưa có thiết bị: KTV nhập địa chỉ phần cứng của thiết bị đã lắp, app gọi API cấp phát
  /// hiện có (backend yêu cầu Gateway của đợt này và triển khai ở bước Đang lắp đặt; lỗi nào backend trả thì báo đúng lỗi đó).
  /// Không tự đẩy trạng thái triển khai, không tạo thiết bị giả. Xong tải lại và chọn thiết bị mới để chấm.
  Future<void> _provisionSlot(ContractSlot slot) async {
    if (_provisioning) return;
    if (_gateways.isEmpty) {
      _snack(
        'Chưa có Gateway nào được cấp phát cho yêu cầu này nên chưa cấp phát được Node. Cần cấp phát Gateway trước.',
        error: true,
      );
      return;
    }
    final address = await showDialog<String>(
      context: context,
      builder: (_) =>
          _ProvisionDialog(slotLabel: '${slot.kind.label} · ${slot.label}'),
    );
    if (address == null || !mounted) return;
    setState(() => _provisioning = true);
    try {
      final devices = await DeploymentApi.provisionDevices(
        deploymentRequestId: widget.deploymentRequestId,
        gatewayId: '${_gateways.first['gatewayId']}',
        farmId: widget.farmId,
        nodes: [
          {
            'hardwareAddress': address,
            'deviceType': slot.kind == NodeKind.actuator
                ? 'ActuatorNode'
                : 'SensorNode',
          },
        ],
      );
      await _load();
      if (!mounted) return;
      final created = devices.isEmpty ? null : devices.first.deviceId;
      if (created != null) setState(() => _selected = created);
      _snack(
        'Đã cấp phát ${address.toUpperCase()}. Chọn thiết bị rồi chạm bản đồ để chấm vị trí.',
      );
    } catch (e) {
      _snack('Không cấp phát được: ${friendlyError(e)}', error: true);
    } finally {
      if (mounted) setState(() => _provisioning = false);
    }
  }

  String _savedText(IotDevice d) {
    final l = _saved[d.deviceId.toLowerCase()];
    final lat = (l?['latitude'] as num?)?.toDouble();
    final lng = (l?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return 'Chưa có vị trí trên máy chủ';
    return 'Máy chủ: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  // ═════════════ Giao diện và thao tác theo trang "Thực địa Chấm Node" của web (ZoneNodeMapperModal) ═════════════
  // Trái: Thiết bị chờ chấm + Gateway ngoài Zone + Thiết bị trong hợp đồng + Node đã định vị. Phải: bản đồ GIS của Zone
  // (ranh giới, đỉnh #1…, loại bản đồ, Căn Zoom) + thông tin Node. Chân trang tối: tổng Node và "Lưu Sơ đồ GIS & Đồng bộ Backend".

  // Nguồn ảnh bản đồ: Vệ tinh/Đường phố dùng Google (các màn bản đồ khác của app đã dùng và chạy được); OSM kèm ảnh dự phòng
  // khi máy không phân giải được tile.openstreetmap.org (lỗi DNS/mạng như đã gặp).
  static const _tileUrls = <String, String>{
    'osm': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'street': 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    'satellite': 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
  };
  static const _tileFallback =
      'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  bool _tileFailed = false;
  static const _webGreen = Color(0xFF119653);

  String _mapType = 'satellite';
  bool? _mqtt; // null = chưa kiểm tra / không đọc được
  bool _checkingMqtt = false;

  bool _isPlaced(IotDevice d) {
    final k = d.deviceId.toLowerCase();
    final s = _saved[k];
    return _drafts.containsKey(k) ||
        (s?['latitude'] != null && s?['longitude'] != null);
  }

  /// Trạng thái MQTT thật của Gateway đầu tiên của yêu cầu (GET /gateways/{id}/mqtt-status). Thử tối đa [attempts] lần như web.
  Future<bool?> _checkMqtt({int attempts = 1}) async {
    if (_gateways.isEmpty) return null;
    final id = '${_gateways.first['gatewayId']}';
    for (var i = 0; i < attempts; i++) {
      try {
        final r = await SupportApi.getGatewayMqttStatus(id);
        final ok = r['mqttConnected'] == true;
        if (ok || i == attempts - 1) return ok;
      } catch (_) {
        if (i == attempts - 1) return null;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<void> _refreshMqtt() async {
    final v = await _checkMqtt();
    if (mounted) setState(() => _mqtt = v);
  }

  /// "Chọn Gateway & kết nối": xem Gateway của yêu cầu, kiểm tra MQTT thật hoặc mô phỏng kết nối (API sẵn có của backend).
  Future<void> _openGatewayDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _GatewayDialog(
        gateways: _gateways,
        initialConnected: _mqtt == true,
        onCheck: () async {
          setState(() => _checkingMqtt = true);
          final v = await _checkMqtt(attempts: 5);
          if (mounted) {
            setState(() {
              _checkingMqtt = false;
              _mqtt = v;
            });
          }
          return v;
        },
        onSimulate: () async {
          final id = '${_gateways.first['gatewayId']}';
          await DeploymentApi.simulateGatewayConnection(id);
          if (mounted) setState(() => _mqtt = true);
        },
      ),
    );
  }

  /// Nhập tọa độ thủ công cho Node đang chọn (phải nằm trong ranh giới Zone), như web.
  Future<void> _manualCoordinate() async {
    final d = _selectedDevice;
    if (d == null) {
      _snack('Vui lòng chọn Node cần định vị.', error: true);
      return;
    }
    final p = await showDialog<LatLng>(
      context: context,
      builder: (_) => _ManualCoordinateDialog(label: d.hardwareAddress),
    );
    if (p == null || !mounted) return;
    _placeAt(p.latitude, p.longitude, 'MobileMap');
  }

  /// Đặt điểm (chạm bản đồ / nhập tọa độ) cho thiết bị đang chọn; ngoài ranh giới Zone thì chặn.
  void _placeAt(double lat, double lng, String source) {
    final d = _selectedDevice;
    if (d == null) {
      _snack(
        'Hãy chọn một thiết bị trong danh sách trước khi chấm điểm.',
        error: true,
      );
      return;
    }
    final verdict = evaluateFix(
      lat: lat,
      lng: lng,
      accuracyM: 0,
      polygon: _polygon,
    );
    if (verdict == FixVerdict.outsideZone) {
      _snack(
        'Điểm này nằm ngoài ranh giới Zone, hãy chọn điểm bên trong.',
        error: true,
      );
      return;
    }
    final next = _waitingAfter(d);
    setState(() {
      _drafts[d.deviceId.toLowerCase()] = _Draft(lat, lng, source, null);
      // Như web: chấm xong thì tự chọn thiết bị chờ chấm kế tiếp.
      if (next != null) _selected = next.deviceId;
    });
    if (verdict == FixVerdict.noBoundary) {
      _snack(
        'Zone chưa có ranh giới GIS nên không kiểm tra được điểm có nằm trong Zone.',
      );
    }
  }

  /// Thiết bị chờ chấm kế tiếp sau [d] (chưa có vị trí lưu/nháp), null nếu không còn.
  IotDevice? _waitingAfter(IotDevice d) {
    for (final x in _devices) {
      if (x.deviceId == d.deviceId) continue;
      if (!_isPlaced(x)) return x;
    }
    return null;
  }

  /// "Gỡ Node": bỏ điểm nháp chưa lưu để chấm lại. Vị trí ĐÃ lưu trên máy chủ không có API xóa, nên chỉ chọn lại để đặt vị trí mới.
  void _unplace(IotDevice d) {
    final k = d.deviceId.toLowerCase();
    if (_drafts.containsKey(k)) {
      setState(() {
        _drafts.remove(k);
        _selected = d.deviceId;
      });
      _snack('Đã gỡ điểm chưa lưu của ${d.hardwareAddress}.');
    } else {
      setState(() => _selected = d.deviceId);
      _snack(
        'Vị trí đã lưu trên máy chủ không xóa được. Đã chọn ${d.hardwareAddress}: chạm bản đồ để đặt vị trí mới.',
      );
    }
  }

  /// "Cấu hình cảm biến": chọn cảm biến từ kho Technician rồi gán cho Node (PUT /devices/{id}/sensors); backend trừ kho.
  Future<void> _configureSensors(IotDevice d) async {
    List<Map<String, dynamic>> parts;
    try {
      parts = await DeploymentApi.getTechnicianSpareParts();
    } catch (e) {
      _snack('Không tải được kho Technician: ${friendlyError(e)}', error: true);
      return;
    }
    final re = RegExp(r'SENSOR|CẢM BIẾN|DHT|SHT|CO2|RS485|NHIỆT|ẨM|VI KHÍ HẬU');
    final stock = [
      for (final p in parts)
        if (re.hasMatch(
              '${p['category']} ${p['type']} ${p['code']} ${p['name']}'
                  .toUpperCase(),
            ) &&
            ((p['quantityInStock'] ?? p['quantity'] ?? 0) as num) > 0)
          p,
    ];
    if (!mounted) return;
    final picked = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) =>
          _SensorConfigDialog(label: d.hardwareAddress, stock: stock),
    );
    if (picked == null || !mounted) return;
    try {
      await DeploymentApi.configureDeviceSensors(d.deviceId, [
        for (final p in picked)
          {
            'sensorType': '${p['code'] ?? p['serialNumber'] ?? p['name']}',
            'unit':
                RegExp(
                  r'DHT|SHT|TEMP|NHIỆT|ẨM',
                  caseSensitive: false,
                ).hasMatch('${p['code']} ${p['name']}')
                ? '°C/%RH'
                : 'raw',
            'samplingIntervalSec': 60,
          },
      ]);
      await _load();
      _snack(
        'Đã lưu ${picked.length} cảm biến cho Node ${d.hardwareAddress}; kho Technician do backend trừ.',
      );
    } catch (e) {
      _snack(
        'Không lưu được cấu hình cảm biến: ${friendlyError(e)}',
        error: true,
      );
    }
  }

  // ───────── Thành phần giao diện ─────────

  Widget _card({required Widget child, Color? color, Color? border}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: border ?? AppColors.border),
        ),
        child: child,
      );

  Widget _heading(IconData icon, String text, {Widget? trailing}) => Row(
    children: [
      Icon(icon, size: 16, color: _webGreen),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
      ?trailing,
    ],
  );

  Widget _pill(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
    ),
  );

  /// Banner xanh đầu trang: nhãn loại việc, mã yêu cầu, tên Zone và nông trại (như tiêu đề modal web).
  Widget _headerBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [_webGreen, Color(0xFF059669), Color(0xFF0F766E)],
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.place_outlined,
            color: Color(0xFFA7F3D0),
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(
                    'LẮP ĐẶT MỚI & CHẤM VỊ TRÍ GIS',
                    Colors.black.withValues(alpha: 0.25),
                    const Color(0xFFD1FAE5),
                  ),
                  Text(
                    'Request #${widget.serviceRequestId}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD1FAE5),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Thực địa Chấm Node Phân khu (Zone): ${_zone?.name ?? 'Zone'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              Text(
                'Nông trại: ${_zone?.farmName.isNotEmpty == true ? _zone!.farmName : '—'} • Ranh giới GIS Zone màu xanh lá. Chấm thiết bị vào đúng ranh giới của Zone.',
                style: const TextStyle(
                  color: Color(0xFFD1FAE5),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Thẻ Gateway hạ tầng ngoài Zone: không chấm lên bản đồ; hiện trạng thái MQTT và nút kết nối.
  Widget _gatewayCard() => _card(
    color: const Color(0xFFFFFBEB),
    border: const Color(0xFFFDE68A),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi, size: 16, color: Color(0xFF78350F)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Gateway hạ tầng ngoài Zone',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF78350F),
                ),
              ),
            ),
            _mqtt == true
                ? _pill('MQTT ONLINE', const Color(0xFF059669), Colors.white)
                : _pill(
                    'CHƯA KẾT NỐI',
                    const Color(0xFFE2E8F0),
                    const Color(0xFF334155),
                  ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Gateway đặt tại nhà kho / cột anten, không chấm lên bản đồ Zone: chỉ cần có Gateway là chấm được Node.',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            color: Color(0xFF92400E),
          ),
        ),
        const SizedBox(height: 8),
        ..._gatewayRows(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _gateways.isEmpty || _checkingMqtt
                ? null
                : _openGatewayDialog,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
            ),
            child: Text(
              _checkingMqtt
                  ? 'Đang kiểm tra MQTT...'
                  : 'Chọn Gateway & kết nối',
            ),
          ),
        ),
        if (_mqtt == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Gateway đã online. Vị trí Gateway quản lý bằng mô tả hạ tầng, không đưa lên GIS.',
              style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
            ),
          ),
      ],
    ),
  );

  /// Khung "Thiết bị trong hợp đồng": số Node đã chấm / số lượng theo từng dòng hợp đồng, đếm Gateway, và vật tư chỉ xem.
  Widget _contractBox() {
    final items = _quotation?.items ?? const <QuotationItem>[];
    final nodeLines = [
      for (final i in items)
        if (nodeKindOfItem(i) == NodeKind.sensor ||
            nodeKindOfItem(i) == NodeKind.actuator)
          i,
    ];
    final others = contractNonPlaceableLines(items);
    return _card(
      color: const Color(0xFFF0F9FF),
      border: const Color(0xFFBAE6FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thiết bị trong hợp đồng',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0C4A6E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mô-đun nút (${nodeLines.fold<int>(0, (s, i) => s + i.quantity)})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
          if (nodeLines.isEmpty)
            const Text(
              'Không có mô-đun nút.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          for (final i in nodeLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      i.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  Text(
                    '${_placedCountForLine(i)}/${i.quantity}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          _contractSummary(),
          if (others.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Vật tư & thi công theo hợp đồng',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const Text(
              'Chỉ xem: các hạng mục này không chấm vị trí trên bản đồ.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            for (final i in others)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.name,
                        style: const TextStyle(fontSize: 11.5, height: 1.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${i.quantity} ${i.unit}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Số Node đã chấm vị trí thuộc dòng hợp đồng [line] (ghép thiết bị đã cấp phát theo loại, theo thứ tự như danh sách chỗ).
  int _placedCountForLine(QuotationItem line) {
    final slots = contractSlots(_quotation?.items ?? const []);
    final m = matchNodeSlots(slots, _devices);
    return m.slots
        .where(
          (s) =>
              s.slot.code == line.code &&
              s.device != null &&
              _isPlaced(s.device!),
        )
        .length;
  }

  /// Thẻ thiết bị chờ chấm (như web: mã, tên dòng hợp đồng, địa chỉ phần cứng, ĐANG CHỌN, nhập tọa độ).
  Widget _waitingCard(IotDevice d, {String? contractName}) {
    final selected = d.deviceId.toLowerCase() == _selected?.toLowerCase();
    final kind = nodeKindOfDeviceType(d.deviceType);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF047857) : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: selected ? const Color(0xFF34D399) : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: () => setState(() => _selected = d.deviceId),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${kind?.label ?? d.deviceType} · ${d.hardwareAddress}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: selected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                  if (selected)
                    _pill('ĐANG CHỌN', const Color(0xFF10B981), Colors.white),
                ],
              ),
              if (contractName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    contractName,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: selected
                          ? const Color(0xFFA7F3D0)
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  'MAC: ${d.hardwareAddress}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: selected
                        ? const Color(0xFFA7F3D0)
                        : AppColors.textMuted,
                  ),
                ),
              ),
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _manualCoordinate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFA7F3D0)),
                      ),
                      child: const Text('Nhập tọa độ cho Node'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dòng "Node đã định vị": mã + tên, Cấu hình cảm biến, Gỡ.
  Widget _placedRow(IotDevice d, {String? contractName}) {
    final k = d.deviceId.toLowerCase();
    final draft = _drafts[k];
    final selected = k == _selected?.toLowerCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFF34D399) : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selected = d.deviceId),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: draft != null
                    ? AppColors.warning
                    : const Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.hardwareAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    draft != null
                        ? 'Điểm mới (chưa lưu): ${draft.lat.toStringAsFixed(6)}, ${draft.lng.toStringAsFixed(6)}'
                              '${draft.accuracyM == null ? '' : ' · GPS ±${draft.accuracyM!.round()} m'}'
                        : _savedText(d),
                    style: TextStyle(
                      fontSize: 11,
                      color: draft != null
                          ? AppColors.warning
                          : AppColors.textMuted,
                    ),
                  ),
                  if (contractName != null)
                    Text(
                      contractName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _configureSensors(d),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              child: const Text('Cấu hình', style: TextStyle(fontSize: 11)),
            ),
            IconButton(
              tooltip: 'Gỡ Node này khỏi sơ đồ để chấm lại',
              visualDensity: VisualDensity.compact,
              onPressed: () => _unplace(d),
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chỗ của hợp đồng CHƯA có thiết bị cấp phát: hiện để thấy hợp đồng cần gì; cấp phát thiết bị thật rồi mới chấm được.
  Widget _slotPlaceholder(ContractSlot s) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      border: Border.all(color: AppColors.borderStrong),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.pending_outlined, size: 20, color: AppColors.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.kind.label} · ${s.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Chưa cấp phát thiết bị cho dòng hợp đồng này nên chưa chấm vị trí được.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.3,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _provisioning ? null : () => _provisionSlot(s),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Cấp phát thiết bị & chấm'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Gateway theo hợp đồng: từng đơn vị Gateway của hợp đồng (ghép Gateway đã cấp phát theo thứ tự), rồi Gateway dư ngoài hợp đồng.
  List<Widget> _gatewayRows() {
    final slots = contractSlots(_quotation?.items ?? const []);
    final matched = matchGatewaySlots(slots, _gateways);
    final extra = _gateways.skip(matched.length).toList();
    Widget row(String title, String subtitle, bool ok) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.router,
        color: ok ? AppColors.primaryDark : AppColors.warning,
      ),
      title: Text(title, style: const TextStyle(fontSize: 12)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5)),
    );
    return [
      for (final m in matched)
        m.gateway == null
            ? row(
                m.slot.label,
                'Chưa cấp phát Gateway cho dòng hợp đồng này.',
                false,
              )
            : row(
                '${m.gateway!['gatewaySerial'] ?? m.gateway!['macAddress']}',
                '${m.slot.label} · Đã cấp phát',
                true,
              ),
      for (final g in extra)
        row(
          '${g['gatewaySerial'] ?? g['macAddress']}',
          'Ngoài hợp đồng (đã cấp phát thêm)',
          true,
        ),
    ];
  }

  Widget _contractSummary() {
    final contract = _quotation == null
        ? <NodeKind, int>{}
        : contractUnitsByKind(_quotation!.items);
    final have = provisionedUnitsByKind(
      devices: _devices,
      gateways: _gateways.length,
    );
    if (contract.isEmpty) {
      return const Text(
        'Hợp đồng không có dòng Gateway/Node nào để chấm.',
        style: TextStyle(fontSize: 12),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in contract.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  (have[e.key] ?? 0) >= e.value
                      ? Icons.check_circle
                      : Icons.pending_outlined,
                  size: 16,
                  color: (have[e.key] ?? 0) >= e.value
                      ? AppColors.primaryDark
                      : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${e.key.label}: hợp đồng ${e.value}, đã cấp phát ${have[e.key] ?? 0}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Cột trái: chờ chấm, Gateway, hợp đồng, Node đã định vị, hoàn tất.
  List<Widget> _leftColumn(
    DeploymentRequest dep,
    bool completed,
    List<String> blockers,
  ) {
    final slots = contractSlots(_quotation?.items ?? const []);
    final match = matchNodeSlots(slots, _devices);
    final nameOf = <String, String>{
      for (final s in match.slots)
        if (s.device != null) s.device!.deviceId: s.slot.label,
    };
    final waiting = [
      for (final d in _devices)
        if (!_isPlaced(d)) d,
    ];
    final placed = [
      for (final d in _devices)
        if (_isPlaced(d)) d,
    ];
    final placeholders = [
      for (final s in match.slots)
        if (s.device == null) s.slot,
    ];
    return [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Không tải lại được: $_error',
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      _card(
        color: AppColors.surfaceMuted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              Icons.memory,
              waiting.isEmpty && placeholders.isEmpty && placed.isNotEmpty
                  ? 'Tất cả Node đã chấm'
                  : 'Thiết bị chờ chấm (${waiting.length + placeholders.length})',
              trailing: _pill(
                '${placed.length} / ${_devices.length + placeholders.length} Đã xong',
                waiting.isEmpty && placeholders.isEmpty
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFFEF3C7),
                waiting.isEmpty && placeholders.isEmpty
                    ? const Color(0xFF065F46)
                    : const Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 10),
            if (dep.status != 'Installing' && !completed) ...[
              _notice(
                dep.status == 'PlanConfirmed'
                    ? 'Hợp đồng đã cọc: bạn có thể chọn vị trí Node. Cấp phát và hoàn tất vẫn được backend kiểm tra theo trạng thái triển khai.'
                    : 'Hợp đồng đã cọc: bạn có thể chọn vị trí Node. Trạng thái triển khai hiện tại: ${deploymentStatusLabels[dep.status] ?? dep.status}.',
              ),
              const SizedBox(height: 10),
            ],
            _gatewayCard(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _selectedDevice == null ? null : _manualCoordinate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF065F46),
                  side: const BorderSide(color: Color(0xFF6EE7B7)),
                ),
                child: const Text('Nhập tọa độ thủ công'),
              ),
            ),
            const SizedBox(height: 10),
            _contractBox(),
            if (_devices.isEmpty && !completed)
              _card(
                color: const Color(0xFFFFFBEB),
                border: const Color(0xFFFCD34D),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa có Node thật để chấm',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Chưa có thiết bị nào được cấp phát cho yêu cầu này. Backend chỉ lưu vị trí cho thiết bị đã cấp phát; app không tạo thiết bị thay backend.',
                      style: TextStyle(fontSize: 11.5, height: 1.4),
                    ),
                  ],
                ),
              )
            else if (waiting.isNotEmpty || placeholders.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Chọn thiết bị bên dưới, sau đó chạm vào vị trí bất kỳ bên trong Zone (đa giác xanh) trên bản đồ để định vị Node.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              _card(
                color: const Color(0xFFECFDF5),
                border: const Color(0xFFA7F3D0),
                child: Text(
                  'Đã chấm hết tất cả ${placed.length} Node! Tất cả thiết bị của hợp đồng đã có vị trí trong ranh giới Zone. Chọn một Node rồi chạm bản đồ để tinh chỉnh.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            for (final d in waiting)
              _waitingCard(d, contractName: nameOf[d.deviceId]),
            for (final s in placeholders) _slotPlaceholder(s),
            for (final d in match.extras.where((d) => !_isPlaced(d)))
              _waitingCard(
                d,
                contractName: 'Ngoài hợp đồng (đã cấp phát thêm)',
              ),
          ],
        ),
      ),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading(
              Icons.check,
              'Node đã định vị (${placed.length})',
              trailing: placed.isEmpty
                  ? null
                  : const Text(
                      'Đã ghim trên Map',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            if (placed.isEmpty)
              const Text(
                'Chưa có Node nào được chấm.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            for (final d in placed)
              _placedRow(d, contractName: nameOf[d.deviceId]),
          ],
        ),
      ),
      _card(
        color: const Color(0xFFECFDF5),
        border: const Color(0xFFA7F3D0),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thao tác trên bản đồ Zone',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Color(0xFF065F46),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '• Chấm Node: chọn thiết bị rồi chạm vào vị trí bên trong Zone (đa giác xanh lá).\n'
              '• Cập nhật vị trí: lấy GPS hiện tại của bạn làm điểm của Node đang chọn.\n'
              '• Gỡ / dời: bấm biểu tượng thùng rác để chấm lại điểm chưa lưu.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ),
      ),
      _completionSection(blockers, completed),
    ];
  }

  Widget _completionSection(List<String> blockers, bool completed) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(Icons.flag_outlined, 'Hoàn tất lắp đặt'),
        const SizedBox(height: 8),
        if (completed)
          _notice(
            'Đã hoàn tất lắp đặt. Owner thanh toán 70% và nghiệm thu ở bước tiếp theo.',
            good: true,
          )
        else if (blockers.isEmpty)
          const Text(
            'Đủ điều kiện phía ứng dụng. Backend sẽ kiểm tra lại khi hoàn tất.',
            style: TextStyle(fontSize: 12),
          )
        else
          for (final b in blockers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.radio_button_unchecked,
                      size: 14,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 10),
        if (!completed)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  (_completing || blockers.isNotEmpty || _drafts.isNotEmpty)
                  ? null
                  : _complete,
              child: Text(
                _completing ? 'Đang hoàn tất...' : 'Hoàn tất lắp đặt',
              ),
            ),
          ),
        if (_drafts.isNotEmpty && !completed)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Còn điểm chưa lưu: lưu vị trí trước khi hoàn tất.',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ),
      ],
    ),
  );

  /// Bản đồ GIS của Zone: ranh giới xanh (tô nhạt), đỉnh #1…, Node (nhãn mã, màu theo loại), chip tâm/diện tích,
  /// chú giải; chạm bản đồ để chấm Node đang chọn.
  Widget _mapView({double? height}) {
    final poly = _zone?.polygon;
    final hasPoly = poly != null && poly.length >= 3;
    final markers = <Marker>[];
    if (hasPoly) {
      for (var i = 0; i < poly.length; i++) {
        markers.add(
          Marker(
            point: poly[i],
            width: 30,
            height: 30,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _webGreen,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Text(
                  '#${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    for (final d in _devices) {
      final k = d.deviceId.toLowerCase();
      final draft = _drafts[k];
      final s = _saved[k];
      final lat = draft?.lat ?? (s?['latitude'] as num?)?.toDouble();
      final lng = draft?.lng ?? (s?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final selected = k == _selected?.toLowerCase();
      final actuator = nodeKindOfDeviceType(d.deviceType) == NodeKind.actuator;
      final color = draft != null
          ? AppColors.warning
          : (actuator ? const Color(0xFF0284C7) : const Color(0xFF059669));
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 90,
          height: 52,
          child: GestureDetector(
            onTap: () => setState(() => _selected = d.deviceId),
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
                    border: Border.all(
                      color: const Color(0xFF34D399).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    d.hardwareAddress,
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
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? const Color(0xFF38BDF8) : Colors.white,
                      width: selected ? 3 : 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6),
                    ],
                  ),
                  child: Icon(
                    actuator ? Icons.bolt : Icons.sensors,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final center = hasPoly
        ? LatLng(
            poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length,
            poly.map((p) => p.longitude).reduce((a, b) => a + b) / poly.length,
          )
        : (markers.isNotEmpty
              ? markers.first.point
              : const LatLng(11.94, 108.44));
    final areaM2 = _zone?.areaM2 ?? 0;
    final map = ClipRRect(
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
                      bounds: LatLngBounds.fromPoints(poly),
                      padding: const EdgeInsets.all(48),
                      maxZoom: 19,
                    )
                  : null,
              minZoom: 3,
              maxZoom: 22,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, p) => _placeAt(
                double.parse(p.latitude.toStringAsFixed(6)),
                double.parse(p.longitude.toStringAsFixed(6)),
                'MobileMap',
              ),
            ),
            children: [
              TileLayer(
                key: ValueKey(_mapType),
                urlTemplate: _tileUrls[_mapType]!,
                fallbackUrl: _mapType == 'osm' ? _tileFallback : null,
                userAgentPackageName: 'com.smartfarm.mobile',
                maxZoom: 22,
                maxNativeZoom: 19,
                errorTileCallback: (tile, error, stack) {
                  if (_tileFailed) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_tileFailed)
                      setState(() => _tileFailed = true);
                  });
                },
              ),
              if (hasPoly)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: poly,
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      borderColor: const Color(0xFF10B981),
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(markers: markers),
            ],
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
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasPoly
                          ? '${_zone?.name ?? 'Zone'}${areaM2 > 0 ? ' · ${areaM2.round()} m²' : ''}'
                          : 'Zone chưa có ranh giới GIS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasPoly)
                      Text(
                        'Tâm: ${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)} · ${poly.length - (poly.first == poly.last ? 1 : 0)} đỉnh',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: MapZoomControls(controller: _map),
          ),
          if (_tileFailed)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Không tải được một số ảnh bản đồ (mạng). Thử loại bản đồ khác.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                      border: Border.all(color: const Color(0xFF10B981)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Zone hiện tại', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 10),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF059669),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Node đã định vị (${_devices.where(_isPlaced).length})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return height == null ? map : SizedBox(height: height, child: map);
  }

  void _fitZone() {
    final poly = _zone?.polygon;
    if (poly == null || poly.length < 3) return;
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(poly),
        padding: const EdgeInsets.all(48),
        maxZoom: 19,
      ),
    );
  }

  /// Hàng điều khiển bản đồ như web: Căn Zoom và loại bản đồ OSM / Đường phố / Vệ tinh.
  Widget _mapToolbar() {
    Widget type(String key, String label) => Padding(
      padding: const EdgeInsets.only(left: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: _mapType == key,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: _webGreen,
        labelStyle: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _mapType == key ? Colors.white : AppColors.text,
        ),
        onSelected: (_) => setState(() => _mapType = key),
      ),
    );
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _fitZone,
          icon: const Icon(Icons.fit_screen, size: 16),
          label: const Text('Căn Zoom'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
        type('osm', 'OSM'),
        type('street', 'Đường phố'),
        type('satellite', 'Vệ tinh'),
      ],
    );
  }

  Widget _mapControls(bool completed) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: (_gpsBusy || _selectedDevice == null || completed)
              ? null
              : _useGps,
          icon: _gpsBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location, size: 18),
          label: Text(_gpsBusy ? 'Đang lấy GPS...' : 'Cập nhật vị trí'),
        ),
      ),
    ],
  );

  Widget _mapCard(bool completed, {double? mapHeight}) => _card(
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.place, size: 16, color: _webGreen),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Vị trí GIS Map của Zone này',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Chọn thiết bị ở danh sách rồi chạm bản đồ trong ranh giới Zone, hoặc bấm "Cập nhật vị trí" để lấy GPS hiện tại.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        _mapToolbar(),
        const SizedBox(height: 8),
        mapHeight == null
            ? Expanded(child: _mapView())
            : _mapView(height: mapHeight),
        const SizedBox(height: 8),
        _mapControls(completed),
      ],
    ),
  );

  /// Thẻ "Thông tin Node": trạng thái từng Node đã cấp phát (kết nối KTV nhập, heartbeat thật) và ghi kiểm tra kết nối.
  Widget _nodeInfoCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          Icons.memory,
          'Thông tin Node cảm biến & vi khí hậu',
          trailing: _pill(
            '${_devices.length} Node',
            const Color(0xFFF0F9FF),
            const Color(0xFF0369A1),
          ),
        ),
        const SizedBox(height: 8),
        if (_devices.isEmpty)
          const Text(
            'Chưa có Node nào được cấp phát trong yêu cầu này.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        for (final d in _devices) _deviceTile(d),
      ],
    ),
  );

  Widget _statusRow(IconData icon, String text, Color color) => Padding(
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

  Widget _deviceTile(IotDevice d) {
    final k = d.deviceId.toLowerCase();
    final draft = _drafts[k];
    final raw = _deviceRaw[k];
    final seen = '${raw?['lastSeenAtUtc'] ?? ''}';
    final t = d.latestTest;
    final kind = nodeKindOfDeviceType(d.deviceType);
    final selected = k == _selected?.toLowerCase();
    final hasServerPos = _savedText(d).startsWith('Máy chủ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.info.withValues(alpha: 0.06)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(
          color: selected ? AppColors.info : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        onTap: () => setState(() => _selected = d.deviceId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${kind?.label ?? d.deviceType} · ${d.hardwareAddress}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              _statusRow(
                draft != null ? Icons.edit_location_alt : Icons.place_outlined,
                draft != null
                    ? 'Điểm mới (chưa lưu): ${draft.lat.toStringAsFixed(6)}, ${draft.lng.toStringAsFixed(6)}'
                          '${draft.accuracyM == null ? '' : ' · GPS ±${draft.accuracyM!.round()} m'}'
                    : _savedText(d),
                draft != null
                    ? AppColors.warning
                    : (hasServerPos
                          ? AppColors.primaryDark
                          : AppColors.textMuted),
              ),
              _statusRow(
                t == null
                    ? Icons.help_outline
                    : (t.succeeded
                          ? Icons.check_circle_outline
                          : Icons.error_outline),
                t == null
                    ? 'Kiểm tra kết nối (KTV nhập): chưa có'
                    : 'Kiểm tra kết nối (KTV nhập thủ công): ${t.succeeded ? 'đạt' : 'không đạt'}',
                t == null
                    ? AppColors.textMuted
                    : (t.succeeded ? AppColors.primaryDark : AppColors.danger),
              ),
              _statusRow(
                Icons.wifi_tethering,
                seen.isEmpty || seen == 'null'
                    ? 'Heartbeat thực tế: chưa nhận'
                    : 'Heartbeat thực tế gần nhất: $seen',
                AppColors.textMuted,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _recordTest(d),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Ghi kiểm tra kết nối'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chân trang tối như web: tổng Node định vị, còn bao nhiêu thiết bị chờ, Hủy và lưu sơ đồ.
  Widget _footer() {
    final placed = _devices.where(_isPlaced).length;
    final slots = contractSlots(_quotation?.items ?? const []);
    final missing = matchNodeSlots(
      slots,
      _devices,
    ).slots.where((s) => s.device == null).length;
    final waiting = _devices.length - placed + missing;
    final note = _drafts.isNotEmpty
        ? '(${_drafts.length} điểm chưa lưu)'
        : (placed > 0 && waiting == 0
              ? '(Đã định vị đủ 100% thiết bị hợp đồng)'
              : (waiting > 0
                    ? '(Còn $waiting thiết bị chờ chấm)'
                    : '(Chưa có Node thật để chấm)'));
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Tổng số Node định vị trong Phân khu: ',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                  ),
                  TextSpan(
                    text: '$placed Nodes ',
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  TextSpan(
                    text: note,
                    style: TextStyle(
                      color: _drafts.isNotEmpty
                          ? const Color(0xFFFBBF24)
                          : (waiting == 0 && placed > 0
                                ? const Color(0xFF34D399)
                                : const Color(0xFFFBBF24)),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_saving || _drafts.isEmpty) ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: const Color(0xFF020617),
                    ),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(
                      _saving
                          ? 'Đang lưu sơ đồ GIS...'
                          : 'Lưu Sơ đồ GIS & Đồng bộ Backend',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gắn Node · ${_zone?.name ?? 'Zone'}'),
        actions: [
          IconButton(
            tooltip: 'Xem Node đã chấm và tình trạng',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => PlacedNodesScreen(
                  zoneId: widget.zoneId,
                  farmId: widget.farmId,
                  zone: _zone,
                ),
              ),
            ),
          ),
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
    if (_loading && _gate == null) {
      return const AppLoading(message: 'Đang tải dữ liệu gắn node...');
    }
    // Lỗi tải hoặc chưa xác nhận được từ backend: khoá, không dùng dữ liệu/quyền cũ.
    if (_gate == null || _deployment == null) {
      return AppErrorState(
        message: _error ?? 'Chưa xác nhận được hợp đồng và cọc 30% từ backend.',
        onRetry: _load,
      );
    }
    final gate = _gate!;
    if (!gate.allowed) {
      return AppErrorState(message: gate.message, onRetry: _load);
    }
    final dep = _deployment!;
    final contract = _quotation == null
        ? <NodeKind, int>{}
        : contractUnitsByKind(_quotation!.items);
    final provisioned = provisionedUnitsByKind(
      devices: _devices,
      gateways: _gateways.length,
    );
    final placedIds = <String>{
      for (final e in _saved.entries)
        if (e.value['latitude'] != null && e.value['longitude'] != null) e.key,
    };
    final blockers = completionBlockers(
      deploymentStatus: dep.status,
      devices: _devices,
      placed: placedIds,
      contractUnits: contract,
      provisioned: provisioned,
    );
    final completed = dep.status == 'Completed';

    return Column(
      children: [
        _headerBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth >= 760) {
                  // Màn rộng như web: danh sách bên trái, bản đồ GIS + thông tin Node bên phải.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 400,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                          children: _leftColumn(dep, completed, blockers),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                          children: [
                            _mapCard(completed, mapHeight: 420),
                            _nodeInfoCard(),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                // Màn hẹp: bản đồ trên, danh sách bên dưới.
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _mapCard(completed, mapHeight: 320),
                    ..._leftColumn(dep, completed, blockers),
                    _nodeInfoCard(),
                  ],
                );
              },
            ),
          ),
        ),
        _footer(),
      ],
    );
  }

  Widget _notice(String text, {bool good = false}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (good ? AppColors.primaryDark : AppColors.warning).withValues(
        alpha: 0.1,
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: good ? AppColors.primaryDark : AppColors.warning,
      ),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
  );
}

/// Hộp thoại Gateway: thông tin Gateway của yêu cầu, kiểm tra MQTT thật hoặc mô phỏng kết nối (như web).
class _GatewayDialog extends StatefulWidget {
  final List<Map<String, dynamic>> gateways;
  final bool initialConnected;
  final Future<bool?> Function() onCheck;
  final Future<void> Function() onSimulate;
  const _GatewayDialog({
    required this.gateways,
    required this.initialConnected,
    required this.onCheck,
    required this.onSimulate,
  });

  @override
  State<_GatewayDialog> createState() => _GatewayDialogState();
}

class _GatewayDialogState extends State<_GatewayDialog> {
  bool? _connected;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _connected = widget.initialConnected ? true : null;
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final v = await widget.onCheck();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _connected = v;
      _message = v == true
          ? 'Gateway đã xác nhận kết nối MQTT thật.'
          : (v == false
                ? 'Gateway chỉ đang Online trên Backend, chưa xác nhận MQTT thật (cần nạp WiFi + JSON firmware và kiểm tra ESP báo MQTT_CONNECTED).'
                : 'Không thể xác minh kết nối MQTT với Gateway.');
    });
  }

  Future<void> _simulate() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.onSimulate();
      if (!mounted) return;
      setState(() {
        _connected = true;
        _message =
            'Đã mô phỏng Gateway Online. Đây không phải kết nối MQTT thật.';
      });
    } catch (e) {
      if (mounted)
        setState(
          () => _message = 'Mô phỏng Gateway thất bại: ${friendlyError(e)}',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gateway & kết nối', style: TextStyle(fontSize: 15)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gateway đặt ngoài Zone, không tạo marker Gateway trên bản đồ.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            for (final g in widget.gateways)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Serial: ${g['gatewaySerial'] ?? '—'}\nMAC: ${g['macAddress'] ?? '—'}\nTrạng thái: ${g['status'] ?? '—'}\nLast seen: ${g['lastSeenAtUtc'] ?? '—'}\nVị trí: Ngoài Zone',
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _message!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _connected == true
                        ? const Color(0xFF065F46)
                        : AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _simulate,
          child: const Text('Mô phỏng'),
        ),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: Text(
            _busy
                ? 'Đang kiểm tra MQTT...'
                : (_connected == true ? 'MQTT đã kết nối' : 'Kết nối thật'),
          ),
        ),
      ],
    );
  }
}

/// Nhập tọa độ thủ công (vĩ độ, kinh độ hợp lệ); việc kiểm tra nằm trong Zone do màn gọi thực hiện.
class _ManualCoordinateDialog extends StatefulWidget {
  final String label;
  const _ManualCoordinateDialog({required this.label});

  @override
  State<_ManualCoordinateDialog> createState() =>
      _ManualCoordinateDialogState();
}

class _ManualCoordinateDialogState extends State<_ManualCoordinateDialog> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _submit() {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    if (lat == null ||
        lng == null ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      setState(
        () => _error =
            'Nhập tọa độ hợp lệ: vĩ độ từ -90 đến 90, kinh độ từ -180 đến 180.',
      );
      return;
    }
    Navigator.pop(
      context,
      LatLng(
        double.parse(lat.toStringAsFixed(6)),
        double.parse(lng.toStringAsFixed(6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Nhập tọa độ Node thủ công',
        style: TextStyle(fontSize: 15),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Node đang chọn: ${widget.label}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lat,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Vĩ độ',
              hintText: '11.006700',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lng,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: 'Kinh độ',
              hintText: '106.513900',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tọa độ phải nằm trong ranh giới GIS của Zone.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Đặt Node tại tọa độ'),
        ),
      ],
    );
  }
}

/// Chọn cảm biến từ kho Technician để gán cho Node (như web "Cấu hình cảm biến").
class _SensorConfigDialog extends StatefulWidget {
  final String label;
  final List<Map<String, dynamic>> stock;
  const _SensorConfigDialog({required this.label, required this.stock});

  @override
  State<_SensorConfigDialog> createState() => _SensorConfigDialogState();
}

class _SensorConfigDialogState extends State<_SensorConfigDialog> {
  final _picked = <String>{};

  String _code(Map<String, dynamic> s) =>
      '${s['code'] ?? s['serialNumber'] ?? s['name']}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Cấu hình cảm biến cho Node ${widget.label}',
        style: const TextStyle(fontSize: 14.5),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn cảm biến từ kho Technician để gán vào đúng Node. Không cần cấp phát cảm biến riêng.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              if (widget.stock.isEmpty)
                const Text('Kho Technician chưa có cảm biến.'),
              for (final s in widget.stock)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _picked.contains(_code(s)),
                  onChanged: (v) => setState(
                    () => v == true
                        ? _picked.add(_code(s))
                        : _picked.remove(_code(s)),
                  ),
                  title: Text('${s['name'] ?? _code(s)}'),
                  subtitle: Text(
                    'Mã: ${_code(s)} · Tồn kho: ${s['quantityInStock'] ?? s['quantity'] ?? 0}',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final s in widget.stock)
                    if (_picked.contains(_code(s))) s,
                ]),
          child: const Text('Lưu cấu hình cảm biến'),
        ),
      ],
    );
  }
}

class _TestInput {
  final bool succeeded;
  final double? rssi;
  final double? snr;
  final int? latencyMs;
  final String? errorCode;
  final String? errorMessage;
  const _TestInput(
    this.succeeded,
    this.rssi,
    this.snr,
    this.latencyMs,
    this.errorCode,
    this.errorMessage,
  );
}

/// Hộp thoại ghi kết quả kiểm tra kết nối do KTV quan sát: phải chọn đạt/không đạt; không đạt thì bắt buộc mã lỗi.
class _TestDialog extends StatefulWidget {
  final String label;
  const _TestDialog({required this.label});

  @override
  State<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends State<_TestDialog> {
  bool? _ok;
  final _rssi = TextEditingController();
  final _snr = TextEditingController();
  final _latency = TextEditingController();
  final _code = TextEditingController();
  final _msg = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_rssi, _snr, _latency, _code, _msg]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_ok == null) {
      setState(() => _error = 'Hãy chọn kết quả: đạt hoặc không đạt.');
      return;
    }
    if (!_ok! && _code.text.trim().isEmpty) {
      setState(() => _error = 'Kiểm tra không đạt thì cần nhập mã lỗi.');
      return;
    }
    Navigator.pop(
      context,
      _TestInput(
        _ok!,
        double.tryParse(_rssi.text.trim().replaceAll(',', '.')),
        double.tryParse(_snr.text.trim().replaceAll(',', '.')),
        int.tryParse(_latency.text.trim()),
        _code.text.trim(),
        _msg.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Kiểm tra kết nối · ${widget.label}',
        style: const TextStyle(fontSize: 14.5),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kết quả do bạn quan sát và xác nhận thủ công, không phải dữ liệu telemetry tự động.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: true, label: Text('Đạt')),
                ButtonSegment(value: false, label: Text('Không đạt')),
              ],
              selected: {?_ok},
              onSelectionChanged: (s) => setState(() {
                _ok = s.isEmpty ? null : s.first;
                _error = null;
              }),
            ),
            TextField(
              controller: _rssi,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'RSSI (dBm, tùy chọn)',
              ),
            ),
            TextField(
              controller: _snr,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'SNR (dB, tùy chọn)',
              ),
            ),
            TextField(
              controller: _latency,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Độ trễ (ms, tùy chọn)',
              ),
            ),
            if (_ok == false) ...[
              TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Mã lỗi *'),
              ),
              TextField(
                controller: _msg,
                decoration: const InputDecoration(labelText: 'Mô tả lỗi'),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ghi nhận')),
      ],
    );
  }
}

/// Hộp thoại nhập địa chỉ phần cứng của thiết bị thật để cấp phát (bắt buộc, 3–64 ký tự, không khoảng trắng).
class _ProvisionDialog extends StatefulWidget {
  final String slotLabel;
  const _ProvisionDialog({required this.slotLabel});

  @override
  State<_ProvisionDialog> createState() => _ProvisionDialogState();
}

class _ProvisionDialogState extends State<_ProvisionDialog> {
  final _address = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _address.text.trim();
    if (v.length < 3 || v.length > 64 || v.contains(RegExp(r'\s'))) {
      setState(
        () => _error =
            'Nhập địa chỉ phần cứng 3–64 ký tự, không có khoảng trắng.',
      );
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cấp phát thiết bị', style: TextStyle(fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.slotLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Nhập địa chỉ phần cứng in trên thiết bị đã lắp. Thiết bị được cấp phát vào Gateway của yêu cầu này qua backend.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _address,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Địa chỉ phần cứng',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Cấp phát')),
      ],
    );
  }
}
