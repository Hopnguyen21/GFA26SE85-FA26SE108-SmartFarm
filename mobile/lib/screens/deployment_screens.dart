import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/iot_deployment.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';

// Luồng triển khai thiết bị IoT cho Zone (IOT-V1). Mọi trạng thái và lịch sử lấy từ backend;
// app không tự suy ra thiết bị online hay kết nối thành công.

Color _statusColor(String s) => switch (s) {
  'Completed' => const Color(0xFF059669),
  'MaintenanceRequired' => const Color(0xFFDC2626),
  'Draft' => const Color(0xFF64748B),
  _ => const Color(0xFF0284C7),
};

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xác nhận')),
        ],
      ),
    ) ??
    false;

Widget _statusChip(String status) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: _statusColor(status).withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    deploymentStatusLabels[status] ?? status,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status)),
  ),
);

PreferredSizeWidget _appBar(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: const Color(0xFF062326),
  foregroundColor: Colors.white,
  title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  actions: actions,
);

// ════════════════════════════════════════════════════════════════════════
//  OWNER: lập kế hoạch thiết bị cho Zone
// ════════════════════════════════════════════════════════════════════════
class DeploymentPlanningScreen extends StatefulWidget {
  const DeploymentPlanningScreen({super.key});

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
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  // Danh sách lấy từ backend (GET /api/v1/deployment-requests), không phụ thuộc thiết bị đang dùng.
  Future<void> _loadMine() async {
    try {
      final list = await ApiService.getOwnerDeploymentRequests();
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
      final req = await ApiService.getIotRequirements(zoneId);
      final rec = await ApiService.getDeviceRecommendations(zoneId);
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
          PlanItem(deviceModelId: r.deviceModelId, modelName: r.modelName, deviceType: r.deviceType, quantity: _quantities[r.deviceModelId]!),
    ];
    if (items.isEmpty) {
      _toast(context, 'Kế hoạch cần ít nhất một thiết bị.');
      return;
    }
    if (!await _confirm(context, 'Tạo bản nháp', 'Tạo yêu cầu triển khai ở trạng thái nháp. Chưa gửi cho kỹ thuật viên.')) return;
    if (mounted) setState(() => _busy = true);
    try {
      final created = await ApiService.createDeploymentRequest(zoneId, items, notes: _notes.text);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => DeploymentRequestDetailScreen(requestId: created.requestId, technician: false)));
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
                DropdownMenuItem(value: z.zoneId, child: Text('${z.farmName} · ${z.name}', overflow: TextOverflow.ellipsis)),
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
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
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
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Chưa có yêu cầu nào.', style: TextStyle(color: Color(0xFF64748B)))),
          for (final r in _myRequests)
            Card(
              child: ListTile(
                title: Text('Yêu cầu ${r.requestId.substring(0, 8)}'),
                subtitle: Text(r.planItems.map((i) => '${i.quantity}× ${i.modelName}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: _statusChip(r.status),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => DeploymentRequestDetailScreen(requestId: r.requestId, technician: false)));
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
    Text('Diện tích Zone: ${req.zoneAreaM2.toStringAsFixed(0)} m²', style: const TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 6),
    const Text('Thông số cần đo (từ mùa vụ đang canh tác và ngưỡng giai đoạn hiện tại):', style: TextStyle(fontSize: 12)),
    Wrap(spacing: 6, children: [for (final p in req.parameters) Chip(label: Text(p, style: const TextStyle(fontSize: 11)))]),
    const Divider(height: 24),
    const Text('Thiết bị đề xuất (số lượng = diện tích Zone / vùng phủ của model, tối thiểu 1)', style: TextStyle(fontWeight: FontWeight.bold)),
    for (final r in _recommendations)
      Card(
        child: ListTile(
          title: Text(r.modelName),
          subtitle: Text('Phủ ${r.coverageAreaM2.toStringAsFixed(0)} m² · đo: ${r.coveredParameters.join(', ')}', style: const TextStyle(fontSize: 11)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _quantities[r.deviceModelId] = ((_quantities[r.deviceModelId] ?? 0) - 1).clamp(0, 100)),
              ),
              Text('${_quantities[r.deviceModelId] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _quantities[r.deviceModelId] = ((_quantities[r.deviceModelId] ?? 0) + 1).clamp(0, 100)),
              ),
            ],
          ),
        ),
      ),
    TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú cho kỹ thuật viên')),
    const SizedBox(height: 10),
    FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? 'Đang tạo…' : 'Tạo bản nháp yêu cầu triển khai')),
    const Text('Backend xác thực lại kế hoạch bạn chỉnh. Mỗi Zone chỉ có một yêu cầu đang chạy.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
  ];
}

// ════════════════════════════════════════════════════════════════════════
//  TECHNICIAN: danh sách yêu cầu
// ════════════════════════════════════════════════════════════════════════
class TechnicianDeploymentsScreen extends StatefulWidget {
  const TechnicianDeploymentsScreen({super.key});

  @override
  State<TechnicianDeploymentsScreen> createState() => _TechnicianDeploymentsScreenState();
}

class _TechnicianDeploymentsScreenState extends State<TechnicianDeploymentsScreen> {
  List<DeploymentRequest> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getTechnicianDeploymentRequests();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _appBar('Yêu cầu triển khai thiết bị'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [
                    Padding(padding: const EdgeInsets.all(24), child: Text('Không tải được danh sách: $_error')),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ])
                : _items.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('Chưa có yêu cầu nào chờ tiếp nhận hoặc được giao cho bạn.'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = _items[i];
                          return Card(
                            child: ListTile(
                              title: Text('Yêu cầu ${r.requestId.substring(0, 8)} · cần đo ${r.requiredParameters.length} thông số'),
                              subtitle: Text(r.planItems.map((p) => '${p.quantity}× ${p.modelName}').join(', '), maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: _statusChip(r.status),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => DeploymentRequestDetailScreen(requestId: r.requestId, technician: true)));
                                _load();
                              },
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Chi tiết yêu cầu (Owner và Technician dùng chung; hành động lọc theo role + trạng thái)
// ════════════════════════════════════════════════════════════════════════
class DeploymentRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final bool technician;
  const DeploymentRequestDetailScreen({super.key, required this.requestId, required this.technician});

  @override
  State<DeploymentRequestDetailScreen> createState() => _DeploymentRequestDetailScreenState();
}

class _DeploymentRequestDetailScreenState extends State<DeploymentRequestDetailScreen> {
  DeploymentRequest? _req;
  List<IotDevice> _devices = [];
  List<IotGateway> _gateways = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _req == null;
      _error = null;
    });
    try {
      final r = await ApiService.getDeploymentRequest(widget.requestId, technician: widget.technician);
      var devices = <IotDevice>[];
      var gateways = <IotGateway>[];
      if (widget.technician && (r.status == 'Installing' || r.status == 'Completed' || r.status == 'MaintenanceRequired')) {
        gateways = (await ApiService.getFarmGateways(r.farmId)).where((g) => g.deploymentRequestId == r.requestId).toList();
        devices = (await ApiService.getFarmDevices(r.farmId)).where((d) => d.deploymentRequestId == r.requestId).toList();
      }
      if (mounted) {
        setState(() {
          _req = r;
          _devices = devices;
          _gateways = gateways;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Chạy một thao tác đổi trạng thái: khoá nút khi đang gửi, báo lỗi backend, rồi tải lại từ backend.
  Future<void> _act(Future<void> Function() action, {String? confirmTitle, String? confirmBody}) async {
    if (_busy) return;
    if (confirmTitle != null && !await _confirm(context, confirmTitle, confirmBody ?? '')) return;
    if (mounted) setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) _toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _req;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _appBar('Yêu cầu ${widget.requestId.substring(0, 8)}', actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(padding: const EdgeInsets.all(24), child: Text('Không tải được yêu cầu: $_error')),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ]),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(children: [_statusChip(r.status), const Spacer(), if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))]),
                    const SizedBox(height: 10),
                    if (r.ownerNotes != null) Text('Ghi chú của Owner: ${r.ownerNotes}'),
                    const SizedBox(height: 8),
                    const Text('Thông số cần đo', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(spacing: 6, children: [for (final p in r.requiredParameters) Chip(label: Text(p, style: const TextStyle(fontSize: 11)))]),
                    const Divider(height: 24),
                    const Text('Kế hoạch thiết bị', style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final i in r.planItems)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${i.quantity}× ${i.modelName}'),
                        subtitle: i.installationNotes == null ? null : Text(i.installationNotes!),
                      ),
                    if (r.failureCode != null) ...[
                      const Divider(height: 24),
                      Text('Thất bại: ${r.failureCode}', style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                      if (r.failureDescription != null) Text(r.failureDescription!),
                    ],
                    ..._actions(r),
                    if (widget.technician) ..._hardware(r),
                    if (r.surveys.isNotEmpty) ...[
                      const Divider(height: 24),
                      const Text('Khảo sát', style: TextStyle(fontWeight: FontWeight.bold)),
                      for (final s in r.surveys)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(s.isFeasible ? Icons.check_circle : Icons.cancel, color: s.isFeasible ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                          title: Text(s.isFeasible ? 'Khả thi' : 'Không khả thi'),
                          subtitle: Text('${s.siteConditions}\n${s.notes}\n${s.surveyedAtUtc}'),
                        ),
                    ],
                    const Divider(height: 24),
                    const Text('Lịch sử quyết định', style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final h in r.history)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${h.decisionType}: ${deploymentStatusLabels[h.fromStatus] ?? h.fromStatus} → ${deploymentStatusLabels[h.toStatus] ?? h.toStatus}'),
                        subtitle: Text('${h.decidedAtUtc}${h.notes == null ? '' : '\n${h.notes}'}'),
                      ),
                  ],
                ),
    );
  }

  // ─── Hành động theo role + trạng thái; backend vẫn là nơi kiểm tra cuối cùng ───
  List<Widget> _actions(DeploymentRequest r) {
    final id = r.requestId;
    final buttons = <Widget>[];
    Widget btn(String label, VoidCallback onTap, {bool danger = false}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(
        style: danger ? FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)) : null,
        onPressed: _busy ? null : onTap,
        child: Text(label),
      ),
    );

    if (!widget.technician) {
      if (r.status == 'Draft') {
        buttons.add(btn('Chỉnh số lượng kế hoạch', () => _editPlan(r, technician: false)));
        buttons.add(btn(
          'Gửi yêu cầu cho kỹ thuật viên',
          () => _act(() async => ApiService.submitDeploymentRequest(id), confirmTitle: 'Gửi yêu cầu', confirmBody: 'Sau khi gửi bạn không còn sửa kế hoạch ở bước này.'),
        ));
      }
    } else {
      switch (r.status) {
        case 'Submitted':
          buttons.add(btn('Tiếp nhận yêu cầu', () => _act(() async => ApiService.acceptDeploymentRequest(id), confirmTitle: 'Tiếp nhận', confirmBody: 'Bạn sẽ chịu trách nhiệm khảo sát và lắp đặt yêu cầu này.')));
        case 'Accepted':
          buttons.add(btn('Ghi nhận khảo sát địa điểm', () => _survey(r)));
        case 'Surveyed':
          buttons.add(btn('Điều chỉnh kế hoạch sau khảo sát', () => _editPlan(r, technician: true)));
          buttons.add(btn('Ghi nhận khảo sát khác', () => _survey(r)));
          if (r.latestSurveyFeasible) {
            buttons.add(btn('Xác nhận kế hoạch', () => _act(() async => ApiService.confirmDeploymentPlan(id), confirmTitle: 'Xác nhận kế hoạch', confirmBody: 'Kế hoạch sẽ bị khoá và dùng làm căn cứ cấp phát.')));
          } else {
            buttons.add(const Padding(padding: EdgeInsets.only(top: 8), child: Text('Khảo sát mới nhất không khả thi: cần khảo sát khả thi trước khi xác nhận.', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12))));
          }
        case 'PlanConfirmed':
          buttons.add(btn('Bắt đầu lắp đặt', () => _act(() async => ApiService.startDeploymentInstallation(id), confirmTitle: 'Bắt đầu lắp đặt', confirmBody: 'Yêu cầu chuyển sang trạng thái Đang lắp đặt.')));
        case 'Installing':
          buttons.add(btn('Hoàn tất lắp đặt', () => _act(() async => ApiService.completeDeploymentRequest(id), confirmTitle: 'Hoàn tất', confirmBody: 'Backend chỉ chấp nhận khi mọi thiết bị theo kế hoạch đã gán Zone và có lần kiểm tra kết nối thành công mới nhất.')));
          buttons.add(btn('Báo thất bại & chuyển bảo trì', () => _fail(r), danger: true));
      }
    }
    return buttons;
  }

  Future<void> _editPlan(DeploymentRequest r, {required bool technician}) async {
    final qty = {for (final i in r.planItems) i.deviceModelId: i.quantity};
    final notes = {for (final i in r.planItems) i.deviceModelId: TextEditingController(text: i.installationNotes ?? '')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Chỉnh kế hoạch'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final i in r.planItems) ...[
                Text(i.modelName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setLocal(() => qty[i.deviceModelId] = ((qty[i.deviceModelId] ?? 1) - 1).clamp(1, 100))),
                  Text('${qty[i.deviceModelId]}'),
                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setLocal(() => qty[i.deviceModelId] = ((qty[i.deviceModelId] ?? 1) + 1).clamp(1, 100))),
                ]),
                TextField(controller: notes[i.deviceModelId], decoration: const InputDecoration(labelText: 'Ghi chú lắp đặt')),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    final items = [
      for (final i in r.planItems)
        PlanItem(deviceModelId: i.deviceModelId, modelName: i.modelName, deviceType: i.deviceType, quantity: qty[i.deviceModelId] ?? i.quantity, installationNotes: notes[i.deviceModelId]!.text),
    ];
    for (final c in notes.values) {
      c.dispose();
    }
    if (ok != true || !mounted) return;
    await _act(() async => technician
        ? ApiService.updateTechnicianDeploymentPlan(r.requestId, items)
        : ApiService.updateOwnerDeploymentPlan(r.requestId, items));
  }

  Future<void> _survey(DeploymentRequest r) async {
    var feasible = true;
    final site = TextEditingController();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Khảo sát địa điểm'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Khả thi để lắp đặt'), value: feasible, onChanged: (v) => setLocal(() => feasible = v)),
              TextField(controller: site, maxLines: 2, decoration: const InputDecoration(labelText: 'Điều kiện địa điểm')),
              TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Ghi chú khảo sát')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ghi nhận')),
          ],
        ),
      ),
    );
    final siteText = site.text.trim();
    final noteText = notes.text.trim();
    site.dispose();
    notes.dispose();
    if (ok != true || !mounted) return;
    if (siteText.isEmpty || noteText.isEmpty) {
      _toast(context, 'Cần nhập điều kiện địa điểm và ghi chú.');
      return;
    }
    await _act(() async => ApiService.surveyDeploymentRequest(r.requestId, isFeasible: feasible, siteConditions: siteText, notes: noteText));
  }

  Future<void> _fail(DeploymentRequest r) async {
    final code = TextEditingController();
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Báo triển khai thất bại'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã lỗi')),
          TextField(controller: desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Mô tả')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Báo thất bại')),
        ],
      ),
    );
    final codeText = code.text.trim();
    final descText = desc.text.trim();
    code.dispose();
    desc.dispose();
    if (ok != true || !mounted) return;
    if (codeText.isEmpty || descText.isEmpty) {
      _toast(context, 'Cần nhập mã lỗi và mô tả.');
      return;
    }
    await _act(() async {
      final serviceId = await ApiService.failDeploymentRequest(r.requestId, failureCode: codeText, description: descText);
      if (mounted) _toast(context, 'Đã chuyển bảo trì, mã service request: ${serviceId.substring(0, 8)}');
    });
  }

  // ─── Cấp phát phần cứng (chỉ khi Installing) ───────────────────────────
  List<Widget> _hardware(DeploymentRequest r) {
    if (r.status != 'Installing' && _gateways.isEmpty && _devices.isEmpty) return const [];
    final installing = r.status == 'Installing';
    return [
      const Divider(height: 24),
      const Text('Gateway & thiết bị', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('Mã/MAC/serial do kỹ thuật viên nhập từ nhãn thiết bị; app không tạo giá trị giả.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      for (final g in _gateways) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.router), title: Text('${g.gatewaySerial} · ${g.macAddress}'), subtitle: Text('Trạng thái: ${g.status}')),
      if (installing)
        Row(children: [
          TextButton.icon(onPressed: _busy ? null : () => _provisionGateway(r), icon: const Icon(Icons.add), label: const Text('Cấp phát Gateway')),
          if (_gateways.isNotEmpty) TextButton.icon(onPressed: _busy ? null : () => _provisionNodes(r), icon: const Icon(Icons.add), label: const Text('Cấp phát Node')),
        ]),
      for (final d in _devices) _deviceTile(r, d, installing),
    ];
  }

  Widget _deviceTile(DeploymentRequest r, IotDevice d, bool installing) {
    final t = d.latestTest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${d.hardwareAddress} · ${d.deviceType}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Trạng thái: ${d.status}${d.zoneId == null ? ' · chưa gán Zone' : ' · đã gán Zone'}', style: const TextStyle(fontSize: 12)),
          Text(
            t == null ? 'Chưa có kiểm tra kết nối' : 'Kiểm tra gần nhất: ${t.succeeded ? 'thành công' : 'thất bại'} (${t.observedAtUtc})${t.errorMessage == null ? '' : ' · ${t.errorMessage}'}',
            style: TextStyle(fontSize: 12, color: t == null ? const Color(0xFF64748B) : (t.succeeded ? const Color(0xFF059669) : const Color(0xFFDC2626))),
          ),
          if (installing)
            Wrap(spacing: 8, children: [
              if (d.zoneId == null && d.status == 'Unassigned')
                OutlinedButton(
                  onPressed: _busy ? null : () => _act(() async => ApiService.assignDeviceToZone(r.zoneId, d.deviceId), confirmTitle: 'Gán thiết bị vào Zone', confirmBody: d.hardwareAddress),
                  child: const Text('Gán vào Zone'),
                ),
              OutlinedButton(onPressed: _busy ? null : () => _connectionTest(r, d), child: const Text('Ghi kết quả kiểm tra')),
            ]),
        ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < labels.length; i++) TextField(controller: controllers[i], decoration: InputDecoration(labelText: labels[i])),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Gửi')),
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
    final v = await _form('Cấp phát Gateway', ['MAC address', 'Serial', 'Băng tần (vd 868MHz)', 'Phiên bản firmware', 'MQTT client ID', 'Fingerprint chứng chỉ client']);
    if (v == null || !mounted) return;
    await _act(() async => ApiService.provisionGateway(
      deploymentRequestId: r.requestId, farmId: r.farmId, macAddress: v[0]!, gatewaySerial: v[1]!, frequencyBand: v[2]!,
      firmwareVersion: v[3]!, mqttClientId: v[4]!, clientCertificateFingerprint: v[5]!,
    ));
  }

  Future<void> _provisionNodes(DeploymentRequest r) async {
    final addr = TextEditingController();
    var modelId = r.planItems.isEmpty ? null : r.planItems.first.deviceModelId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: const Text('Cấp phát Node'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: modelId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Model theo kế hoạch'),
              items: [for (final i in r.planItems) DropdownMenuItem(value: i.deviceModelId, child: Text(i.modelName, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setLocal(() => modelId = v),
            ),
            TextField(controller: addr, decoration: const InputDecoration(labelText: 'Hardware address (trên nhãn Node)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cấp phát')),
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
    await _act(() async => ApiService.provisionDevices(
      deploymentRequestId: r.requestId,
      gatewayId: _gateways.first.gatewayId,
      farmId: r.farmId,
      nodes: [{'hardwareAddress': address, 'deviceType': item.deviceType, 'deviceModelId': item.deviceModelId}],
    ));
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Nhập kết quả bạn quan sát được trên thiết bị. App không tự kiểm tra MQTT.', style: TextStyle(fontSize: 11)),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Kết nối thành công'), value: succeeded, onChanged: (v) => setLocal(() => succeeded = v)),
              TextField(controller: rssi, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'RSSI (dBm)')),
              TextField(controller: snr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SNR (dB)')),
              TextField(controller: latency, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Độ trễ (ms)')),
              if (!succeeded) TextField(controller: error, decoration: const InputDecoration(labelText: 'Mô tả lỗi')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lưu kết quả')),
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
    await _act(() async => ApiService.recordConnectionTest(
      r.requestId, deviceId: d.deviceId, succeeded: succeeded, rssi: rs, snr: sn, latencyMs: lat,
      errorCode: succeeded ? null : 'CONNECTION_FAILED', errorMessage: succeeded ? null : err,
    ));
  }
}
