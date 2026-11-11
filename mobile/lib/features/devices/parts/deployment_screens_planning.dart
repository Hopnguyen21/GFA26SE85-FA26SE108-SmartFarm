part of '../deployment_screens.dart';

// ════════════════════════════════════════════════════════════════════════
//  OWNER: lập kế hoạch thiết bị cho Zone
// ════════════════════════════════════════════════════════════════════════
class DeploymentPlanningScreen extends StatefulWidget {
  /// Zone chọn sẵn (vd. mở từ màn chi tiết Zone); màn hình tự phân tích nhu cầu IoT ngay.
  final String? initialZoneId;
  const DeploymentPlanningScreen({super.key, this.initialZoneId});

  @override
  State<DeploymentPlanningScreen> createState() => _DeploymentPlanningScreenState();
}

class _DeploymentPlanningScreenState extends State<DeploymentPlanningScreen> {
  String? _zoneId;
  IotRequirements? _requirements;
  final List<DeviceRecommendation> _recommendations = [];
  final Map<String, int> _quantities = {};
  final _notes = TextEditingController();
  bool _loading = false;
  bool _busy = false;
  String? _error;
  List<DeploymentRequest> _myRequests = [];

  @override
  void initState() {
    super.initState();
    _loadMine();
    final initial = widget.initialZoneId;
    if (initial != null) {
      _zoneId = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _analyse();
      });
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  // Danh sách lấy từ backend (GET /api/v1/deployment-requests), không phụ thuộc thiết bị đang dùng.
  Future<void> _loadMine() async {
    try {
      final list = await DeploymentApi.getOwnerDeploymentRequests();
      if (mounted) setState(() => _myRequests = list);
    } catch (e) {
      if (mounted) _toast(context, 'Không tải được danh sách yêu cầu: $e');
    }
  }

  Future<void> _analyse() async {
    final zoneId = _zoneId;
    if (zoneId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _requirements = null;
      _recommendations.clear();
      _quantities.clear();
    });
    try {
      final req = await DeploymentApi.getIotRequirements(zoneId);
      final rec = await DeploymentApi.getDeviceRecommendations(zoneId);
      if (!mounted) return;
      setState(() {
        _requirements = req;
        _recommendations.addAll(rec);
        for (final r in rec) {
          _quantities[r.deviceModelId] = r.quantity;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final zoneId = _zoneId;
    if (zoneId == null) return;
    final items = [
      for (final r in _recommendations)
        if ((_quantities[r.deviceModelId] ?? 0) > 0)
          PlanItem(
            deviceModelId: r.deviceModelId,
            modelName: r.modelName,
            deviceType: r.deviceType,
            quantity: _quantities[r.deviceModelId]!,
          ),
    ];
    if (items.isEmpty) {
      _toast(context, 'Kế hoạch cần ít nhất một thiết bị.');
      return;
    }
    if (!await _confirm(
      context,
      'Tạo bản nháp',
      'Tạo yêu cầu triển khai ở trạng thái nháp. Chưa gửi cho kỹ thuật viên.',
    )) {
      return;
    }
    if (mounted) setState(() => _busy = true);
    try {
      final created = await DeploymentApi.createDeploymentRequest(zoneId, items, notes: _notes.text);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeploymentRequestDetailScreen(requestId: created.requestId, technician: false),
        ),
      );
      await _loadMine();
    } catch (e) {
      if (mounted) _toast(context, 'Không tạo được yêu cầu: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zones = Provider.of<FarmProvider>(context).allZones;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _appBar('Lắp đặt thiết bị IoT cho Zone'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _zoneId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chọn Zone', border: OutlineInputBorder()),
            items: [
              for (final z in zones)
                DropdownMenuItem(
                  value: z.zoneId,
                  child: Text('${z.farmName} · ${z.name}', overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _zoneId = v;
              _requirements = null;
              _recommendations.clear();
            }),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _zoneId == null || _loading ? null : _analyse,
            icon: const Icon(Icons.sensors),
            label: const Text('Xem nhu cầu đo & đề xuất thiết bị'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                  TextButton(onPressed: _analyse, child: const Text('Thử lại')),
                ],
              ),
            ),
          if (_requirements != null) ..._planSection(_requirements!),
          const SizedBox(height: 24),
          const Text('Yêu cầu triển khai của trang trại', style: TextStyle(fontWeight: FontWeight.bold)),
          if (_myRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Chưa có yêu cầu nào.', style: TextStyle(color: Color(0xFF64748B))),
            ),
          for (final r in _myRequests)
            Card(
              child: ListTile(
                title: Text('Yêu cầu ${r.requestId.substring(0, 8)}'),
                subtitle: Text(
                  r.planItems.map((i) => '${i.quantity}× ${i.modelName}').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _statusChip(r.status),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeploymentRequestDetailScreen(requestId: r.requestId, technician: false),
                    ),
                  );
                  _loadMine();
                },
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _planSection(IotRequirements req) => [
    const SizedBox(height: 16),
    Text(
      'Diện tích Zone: ${req.zoneAreaM2.toStringAsFixed(0)} m²',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 6),
    const Text(
      'Thông số cần đo (từ mùa vụ đang canh tác và ngưỡng giai đoạn hiện tại):',
      style: TextStyle(fontSize: 12),
    ),
    Wrap(
      spacing: 6,
      children: [for (final p in req.parameters) Chip(label: Text(p, style: const TextStyle(fontSize: 11)))],
    ),
    const Divider(height: 24),
    const Text(
      'Thiết bị đề xuất (số lượng = diện tích Zone / vùng phủ của model, tối thiểu 1)',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    for (final r in _recommendations)
      Card(
        child: ListTile(
          title: Text(r.modelName),
          subtitle: Text(
            'Phủ ${r.coverageAreaM2.toStringAsFixed(0)} m² · đo: ${r.coveredParameters.join(', ')}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Giảm số lượng',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(
                  () => _quantities[r.deviceModelId] = ((_quantities[r.deviceModelId] ?? 0) - 1).clamp(0, 100),
                ),
              ),
              Text('${_quantities[r.deviceModelId] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                tooltip: 'Tăng số lượng',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(
                  () => _quantities[r.deviceModelId] = ((_quantities[r.deviceModelId] ?? 0) + 1).clamp(0, 100),
                ),
              ),
            ],
          ),
        ),
      ),
    TextField(
      controller: _notes,
      maxLines: 2,
      decoration: const InputDecoration(labelText: 'Ghi chú cho kỹ thuật viên'),
    ),
    const SizedBox(height: 10),
    FilledButton(
      onPressed: _busy ? null : _create,
      child: Text(_busy ? 'Đang tạo…' : 'Tạo bản nháp yêu cầu triển khai'),
    ),
    const Text(
      'Backend xác thực lại kế hoạch bạn chỉnh. Mỗi Zone chỉ có một yêu cầu đang chạy.',
      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
    ),
  ];
}
