import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import '../zones/zone_operations_screens.dart';
import 'widgets/device_actions_sheet.dart' show promptText;
import 'widgets/device_config_dialogs.dart';

/// Công cụ kỹ thuật viên trước đây chỉ có trên Web: cấu hình gateway, cấu hình cảm biến node,
/// xem cấu hình firmware, thử kết nối, cập nhật toạ độ node hàng loạt và kho linh kiện cá nhân.
class TechnicianGatewayToolsScreen extends StatefulWidget {
  const TechnicianGatewayToolsScreen({super.key});

  @override
  State<TechnicianGatewayToolsScreen> createState() =>
      _TechnicianGatewayToolsScreenState();
}

class _GatewayBundle {
  final DeploymentRequest request;
  final IotGateway gateway;
  final List<IotDevice> devices;
  _GatewayBundle(this.request, this.gateway, this.devices);
}

class _TechnicianGatewayToolsScreenState
    extends State<TechnicianGatewayToolsScreen> {
  late Future<List<_GatewayBundle>> _future = _load();

  Future<List<_GatewayBundle>> _load() async {
    final requests = await DeploymentApi.getTechnicianDeploymentRequests();
    final byFarm = <String, List<DeploymentRequest>>{};
    for (final r in requests) {
      if (r.farmId.isNotEmpty) byFarm.putIfAbsent(r.farmId, () => []).add(r);
    }
    final bundles = <_GatewayBundle>[];
    for (final entry in byFarm.entries) {
      final results = await Future.wait([
        DeploymentApi.getFarmGateways(entry.key),
        DeploymentApi.getFarmDevices(entry.key),
      ]);
      final gateways = results[0] as List<IotGateway>;
      final devices = results[1] as List<IotDevice>;
      for (final g in gateways) {
        final req = entry.value
            .where((r) => r.requestId == g.deploymentRequestId)
            .firstOrNull;
        if (req == null)
          continue; // chỉ gateway thuộc yêu cầu được giao cho KTV này
        bundles.add(
          _GatewayBundle(
            req,
            g,
            devices.where((d) => d.gatewayId == g.gatewayId).toList(),
          ),
        );
      }
    }
    return bundles;
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Gateway, Node & Linh kiện',
            style: TextStyle(fontSize: 15),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Gateway / Node'),
              Tab(text: 'Kho linh kiện'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FutureBuilder<List<_GatewayBundle>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${snap.error}'.replaceFirst('Exception: ', ''),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                final items = snap.data!;
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Chưa có gateway nào trong các yêu cầu được giao.',
                              ),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final b in items)
                              _GatewayCard(bundle: b, onChanged: _reload),
                          ],
                        ),
                );
              },
            ),
            const _SparePartsTab(),
          ],
        ),
      ),
    );
  }
}

void _snack(BuildContext context, String m, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(m),
      backgroundColor: error
          ? const Color(0xFFDC2626)
          : const Color(0xFF059669),
    ),
  );
}

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

class _GatewayCard extends StatefulWidget {
  final _GatewayBundle bundle;
  final Future<void> Function() onChanged;
  const _GatewayCard({required this.bundle, required this.onChanged});

  @override
  State<_GatewayCard> createState() => _GatewayCardState();
}

class _GatewayCardState extends State<_GatewayCard> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _simulate() => _guard(() async {
    final g = await DeploymentApi.simulateGatewayConnection(
      widget.bundle.gateway.gatewayId,
    );
    if (!mounted) return;
    _snack(
      context,
      'Kết nối thử: ${g['status'] ?? 'OK'} · ${g['connectedNodes'] ?? 0} node.',
    );
    await widget.onChanged();
  });

  Future<void> _firmware() => _guard(() async {
    final cfg = await DeploymentApi.getGatewayFirmwareConfig(
      widget.bundle.gateway.gatewayId,
    );
    if (!mounted) return;
    final text = const JsonEncoder.withIndent('  ').convert(cfg);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Cấu hình firmware'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(d);
              _snack(context, 'Đã sao chép cấu hình.');
            },
            child: const Text('Sao chép'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  });

  Future<void> _configure() async {
    Map<String, dynamic> detail;
    try {
      detail = await DeploymentApi.getGatewayDetail(
        widget.bundle.gateway.gatewayId,
      );
    } catch (e) {
      if (mounted) _snack(context, _err(e), error: true);
      return;
    }
    if (!mounted) return;
    final configured = ((detail['configuredNodeIds'] as List?) ?? const [])
        .map((e) => '$e'.toLowerCase())
        .toSet();
    final selected = <String>{
      for (final d in widget.bundle.devices)
        if (configured.isEmpty || configured.contains(d.deviceId.toLowerCase()))
          d.deviceId,
    };
    final intervalC = TextEditingController(
      text: '${detail['telemetryIntervalSec'] ?? 60}',
    );
    final samplesC = TextEditingController(
      text: '${detail['samplesPerInterval'] ?? 1}',
    );
    final locC = TextEditingController(
      text: '${detail['installationLocation'] ?? ''}',
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cấu hình gateway',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: intervalC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Chu kỳ gửi (giây, 10–86400)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: samplesC,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Số mẫu/chu kỳ (1–60)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locC,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí lắp đặt',
                    border: OutlineInputBorder(),
                  ),
                ),
                const Text(
                  'Node do gateway quản lý',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                for (final d in widget.bundle.devices)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(d.deviceId),
                    onChanged: (v) => setLocal(
                      () => v == true
                          ? selected.add(d.deviceId)
                          : selected.remove(d.deviceId),
                    ),
                    title: Text('${d.hardwareAddress} · ${d.deviceType}'),
                    subtitle: Text(d.status),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    final interval = int.tryParse(intervalC.text.trim());
                    final samples = int.tryParse(samplesC.text.trim());
                    if (interval == null ||
                        interval < 10 ||
                        interval > 86400 ||
                        samples == null ||
                        samples < 1 ||
                        samples > 60) {
                      _snack(
                        ctx,
                        'Chu kỳ 10–86400 giây, số mẫu 1–60.',
                        error: true,
                      );
                      return;
                    }
                    try {
                      await DeploymentApi.configureGateway(
                        widget.bundle.gateway.gatewayId,
                        nodeIds: selected.toList(),
                        telemetryIntervalSec: interval,
                        samplesPerInterval: samples,
                        installationLocation: locC.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) _snack(ctx, _err(e), error: true);
                    }
                  },
                  child: const Text('Lưu cấu hình'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    intervalC.dispose();
    samplesC.dispose();
    locC.dispose();
    if (saved == true && mounted) {
      _snack(context, 'Đã lưu cấu hình gateway.');
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.bundle;
    final online = b.gateway.status == 'Online';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.router,
                  color: online
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.gateway.gatewaySerial,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  b.gateway.status,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              'MAC ${b.gateway.macAddress} · ${b.devices.length} node · Yêu cầu ${b.request.status}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Wrap(
              spacing: 6,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : _configure,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Cấu hình'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _firmware,
                  icon: const Icon(Icons.memory, size: 16),
                  label: const Text('Firmware'),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _simulate,
                  icon: const Icon(Icons.wifi_tethering, size: 16),
                  label: const Text('Thử kết nối'),
                ),
                if (b.request.zoneId.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ZoneNodesScreen(
                          zoneId: b.request.zoneId,
                          zoneName: b.gateway.gatewaySerial,
                          canEditLocations: true,
                          deploymentRequestId: b.request.requestId,
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.edit_location_alt_outlined,
                      size: 16,
                    ),
                    label: const Text('Toạ độ node'),
                  ),
              ],
            ),
            for (final d in b.devices)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sensors, size: 18),
                title: Text(
                  '${d.hardwareAddress} · ${d.deviceType}',
                  style: const TextStyle(fontSize: 12),
                ),
                subtitle: Text(d.status, style: const TextStyle(fontSize: 11)),
                // Backend chỉ nhận cấu hình cảm biến cho SensorNode.
                trailing: d.deviceType == 'SensorNode'
                    ? TextButton(
                        onPressed: _busy ? null : () => _configureSensors(d),
                        child: const Text('Cảm biến'),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _configureSensors(IotDevice d) async {
    final saved = await showSensorConfigDialog(
      context,
      deviceId: d.deviceId,
      label: d.hardwareAddress,
    );
    if (saved && mounted) {
      _snack(context, 'Đã cấu hình cảm biến cho ${d.hardwareAddress}.');
      await widget.onChanged();
    }
  }
}

class _SparePartsTab extends StatefulWidget {
  const _SparePartsTab();
  @override
  State<_SparePartsTab> createState() => _SparePartsTabState();
}

class _SparePartsTabState extends State<_SparePartsTab> {
  late Future<List<Map<String, dynamic>>> _future =
      DeploymentApi.getTechnicianSpareParts();

  Future<void> _reload() async {
    final f = DeploymentApi.getTechnicianSpareParts();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  bool _busy = false;

  /// Trả linh kiện đang giữ về kho trung tâm.
  Future<void> _return(Map<String, dynamic> p) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trả linh kiện về kho?'),
        content: Text('${p['name']} (${p['code']}) sẽ về kho trung tâm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Trả kho'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await DeploymentApi.returnHardwareItem('${p['id']}');
      if (mounted) _snack(context, 'Đã trả linh kiện về kho.');
      await _reload();
    } catch (e) {
      if (mounted) _snack(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Nhận linh kiện từ kho trung tâm: chọn món, Gateway/Node nhận từng chiếc, vật tư khác hỏi số lượng.
  Future<void> _receive() async {
    if (_busy) return;
    final List<Map<String, dynamic>> stock;
    try {
      stock = await DeploymentApi.getWarehouseParts();
    } catch (e) {
      if (mounted) _snack(context, _err(e), error: true);
      return;
    }
    if (!mounted) return;
    if (stock.isEmpty) {
      _snack(context, 'Kho trung tâm hiện không còn linh kiện để nhận.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Chọn linh kiện cần nhận',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            for (final s in stock)
              ListTile(
                leading: const Icon(Icons.memory_outlined),
                title: Text('${s['name']}'),
                subtitle: Text(
                  '${s['code']} · ${s['category']} · còn ${s['quantityInStock']}',
                ),
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final category = '${picked['category']}'.toUpperCase();
    final single = category.contains('GATEWAY') || category.contains('NODE');
    var quantity = 1;
    if (!single) {
      final max = (picked['quantityInStock'] as num?)?.toInt() ?? 1;
      final text = await promptText(
        context,
        title: 'Số lượng cần nhận',
        body: 'Kho còn $max.',
        label: 'Số lượng',
        confirmLabel: 'Nhận',
        keyboardType: TextInputType.number,
      );
      if (text == null || !mounted) return;
      final n = int.tryParse(text);
      if (n == null || n < 1 || n > max) {
        _snack(context, 'Số lượng phải từ 1 đến $max.', error: true);
        return;
      }
      quantity = n;
    }
    setState(() => _busy = true);
    try {
      await DeploymentApi.assignHardwareItem(
        '${picked['id']}',
        quantity: quantity,
      );
      if (mounted) _snack(context, 'Đã nhận linh kiện từ kho.');
      await _reload();
    } catch (e) {
      if (mounted) _snack(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _receiveButton() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: OutlinedButton.icon(
      onPressed: _busy ? null : _receive,
      icon: const Icon(Icons.inventory_2_outlined),
      label: const Text('Nhận linh kiện từ kho'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_err(snap.error!), textAlign: TextAlign.center),
                TextButton(onPressed: _reload, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        final parts = snap.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: parts.isEmpty
              ? ListView(
                  children: [
                    _receiveButton(),
                    const SizedBox(height: 60),
                    const Center(child: Text('Bạn chưa giữ linh kiện nào.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: parts.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) return _receiveButton();
                    final p = parts[i - 1];
                    final rawPrice = p['unitPrice'] as num?;
                    final priceText = rawPrice != null && rawPrice > 0
                        ? NumberFormat.currency(
                            locale: 'vi_VN',
                            symbol: '₫',
                            decimalDigits: 0,
                          ).format(rawPrice)
                        : null;
                    return ListTile(
                      leading: const Icon(Icons.memory_outlined),
                      title: Text(
                        '${p['name']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${p['code']} · ${p['category']}'
                        '${p['serialNumber'] != null ? ' · SN ${p['serialNumber']}' : ''}'
                        '${p['locationRack'] != null ? ' · Kệ ${p['locationRack']}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'x${p['quantityInStock'] ?? 0}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (priceText != null)
                            Text(
                              priceText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          TextButton(
                            onPressed: _busy ? null : () => _return(p),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Trả kho',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
