part of '../deployment_screens.dart';

extension _DeploymentRequestDetailScreenStateHardware
    on _DeploymentRequestDetailScreenState {
  // ─── Cấp phát phần cứng (chỉ khi Installing) ───────────────────────────
  List<Widget> _hardware(DeploymentRequest r) {
    if (r.status != 'Installing' && _gateways.isEmpty && _devices.isEmpty)
      return const [];
    final installing = r.status == 'Installing';
    return [
      const Divider(height: 24),
      const Text(
        'Gateway & thiết bị',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Mã/MAC/serial do kỹ thuật viên nhập từ nhãn thiết bị; app không tạo giá trị giả.',
        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      for (final g in _gateways)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.router),
          title: Text('${g.gatewaySerial} · ${g.macAddress}'),
          subtitle: Text('Trạng thái: ${g.status}'),
        ),
      if (installing)
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _provisionGateway(r),
              icon: const Icon(Icons.add),
              label: const Text('Cấp phát Gateway'),
            ),
            if (_gateways.isNotEmpty)
              TextButton.icon(
                onPressed: _busy ? null : () => _provisionNodes(r),
                icon: const Icon(Icons.add),
                label: const Text('Cấp phát Node'),
              ),
          ],
        ),
      for (final d in _devices) _deviceTile(r, d, installing),
    ];
  }

  Widget _deviceTile(DeploymentRequest r, IotDevice d, bool installing) {
    final t = d.latestTest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.hardwareAddress} · ${d.deviceType}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Trạng thái: ${d.status}${d.zoneId == null ? ' · chưa gán Zone' : ' · đã gán Zone'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              t == null
                  ? 'Chưa có kiểm tra kết nối'
                  : 'Kiểm tra gần nhất: ${t.succeeded ? 'thành công' : 'thất bại'} (${t.observedAtUtc})${t.errorMessage == null ? '' : ' · ${t.errorMessage}'}',
              style: TextStyle(
                fontSize: 12,
                color: t == null
                    ? const Color(0xFF64748B)
                    : (t.succeeded
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626)),
              ),
            ),
            if (installing)
              Wrap(
                spacing: 8,
                children: [
                  if (d.zoneId == null && d.status == 'Unassigned')
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _act(
                              () async => DeploymentApi.assignDeviceToZone(
                                r.zoneId,
                                d.deviceId,
                              ),
                              confirmTitle: 'Gán thiết bị vào Zone',
                              confirmBody: d.hardwareAddress,
                            ),
                      child: const Text('Gán vào Zone'),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _connectionTest(r, d),
                    child: const Text('Ghi kết quả kiểm tra'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<List<String?>?> _form(String title, List<String> labels) async {
    final controllers = [for (final _ in labels) TextEditingController()];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                TextField(
                  controller: controllers[i],
                  decoration: InputDecoration(labelText: labels[i]),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
    final values = [for (final c in controllers) c.text.trim()];
    for (final c in controllers) {
      c.dispose();
    }
    if (ok != true) return null;
    if (values.any((v) => v.isEmpty)) {
      if (mounted) _toast(context, 'Cần nhập đủ các trường.');
      return null;
    }
    return values;
  }

  Future<void> _provisionGateway(DeploymentRequest r) async {
    final v = await _form('Cấp phát Gateway', [
      'MAC address',
      'Serial',
      'Băng tần (vd 868MHz)',
      'Phiên bản firmware',
      'MQTT client ID',
      'Fingerprint chứng chỉ client',
    ]);
    if (v == null || !mounted) return;
    await _act(
      () async => DeploymentApi.provisionGateway(
        deploymentRequestId: r.requestId,
        farmId: r.farmId,
        macAddress: v[0]!,
        gatewaySerial: v[1]!,
        frequencyBand: v[2]!,
        firmwareVersion: v[3]!,
        mqttClientId: v[4]!,
        clientCertificateFingerprint: v[5]!,
      ),
    );
  }

  Future<void> _provisionNodes(DeploymentRequest r) async {
    final addr = TextEditingController();
    var modelId = r.planItems.isEmpty ? null : r.planItems.first.deviceModelId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Cấp phát Node'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: modelId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Model theo kế hoạch',
                ),
                items: [
                  for (final i in r.planItems)
                    DropdownMenuItem(
                      value: i.deviceModelId,
                      child: Text(i.modelName, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setLocal(() => modelId = v),
              ),
              TextField(
                controller: addr,
                decoration: const InputDecoration(
                  labelText: 'Hardware address (trên nhãn Node)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cấp phát'),
            ),
          ],
        ),
      ),
    );
    final address = addr.text.trim();
    addr.dispose();
    if (ok != true || !mounted) return;
    if (address.isEmpty || modelId == null) {
      _toast(context, 'Cần nhập hardware address và chọn model.');
      return;
    }
    final item = r.planItems.firstWhere((i) => i.deviceModelId == modelId);
    await _act(
      () async => DeploymentApi.provisionDevices(
        deploymentRequestId: r.requestId,
        gatewayId: _gateways.first.gatewayId,
        farmId: r.farmId,
        nodes: [
          {
            'hardwareAddress': address,
            'deviceType': item.deviceType,
            'deviceModelId': item.deviceModelId,
          },
        ],
      ),
    );
  }

  Future<void> _connectionTest(DeploymentRequest r, IotDevice d) async {
    var succeeded = true;
    final rssi = TextEditingController();
    final snr = TextEditingController();
    final latency = TextEditingController();
    final error = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text('Kiểm tra kết nối ${d.hardwareAddress}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập kết quả bạn quan sát được trên thiết bị. App không tự kiểm tra MQTT.',
                  style: TextStyle(fontSize: 11),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kết nối thành công'),
                  value: succeeded,
                  onChanged: (v) => setLocal(() => succeeded = v),
                ),
                TextField(
                  controller: rssi,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'RSSI (dBm)'),
                ),
                TextField(
                  controller: snr,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'SNR (dB)'),
                ),
                TextField(
                  controller: latency,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Độ trễ (ms)'),
                ),
                if (!succeeded)
                  TextField(
                    controller: error,
                    decoration: const InputDecoration(labelText: 'Mô tả lỗi'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Lưu kết quả'),
            ),
          ],
        ),
      ),
    );
    final rs = double.tryParse(rssi.text.trim());
    final sn = double.tryParse(snr.text.trim());
    final lat = int.tryParse(latency.text.trim());
    final err = error.text.trim();
    rssi.dispose();
    snr.dispose();
    latency.dispose();
    error.dispose();
    if (ok != true || !mounted) return;
    await _act(
      () async => DeploymentApi.recordConnectionTest(
        r.requestId,
        deviceId: d.deviceId,
        succeeded: succeeded,
        rssi: rs,
        snr: sn,
        latencyMs: lat,
        errorCode: succeeded ? null : 'CONNECTION_FAILED',
        errorMessage: succeeded ? null : err,
      ),
    );
  }
}
