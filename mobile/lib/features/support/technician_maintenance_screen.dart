import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';

const Map<String, String> serviceStatusLabels = {
  'Open': 'Mới tạo',
  'Assigned': 'Đã giao',
  'InProgress': 'Đang xử lý',
  'Diagnosed': 'Đã chẩn đoán',
  'WorkCompleted': 'Đã sửa/thay xong',
  'Verified': 'Đã kiểm tra kết nối',
  'Resolved': 'Đã giải quyết',
  'Closed': 'Đã đóng',
};
const _statusByIndex = [
  'Open',
  'Assigned',
  'InProgress',
  'Diagnosed',
  'WorkCompleted',
  'Verified',
  'Resolved',
  'Closed',
];
const _resolutionByIndex = ['Maintenance', 'Repair', 'Replacement'];
const Map<String, String> resolutionLabels = {
  'Maintenance': 'Bảo trì',
  'Repair': 'Sửa chữa',
  'Replacement': 'Thay thế thiết bị',
};

/// Backend có thể trả enum dạng chuỗi hoặc số; chuẩn hoá về tên.
String enumName(dynamic v, List<String> byIndex) {
  if (v is int && v >= 0 && v < byIndex.length) return byIndex[v];
  return '${v ?? ''}';
}

String serviceStatusOf(Map<String, dynamic> r) => enumName(r['status'], _statusByIndex);
String resolutionOf(Map<String, dynamic> r) => enumName(r['resolutionAction'], _resolutionByIndex);

/// Danh sách yêu cầu bảo trì được giao cho Kỹ thuật viên (backend lọc theo người dùng).
class TechnicianMaintenanceScreen extends StatefulWidget {
  const TechnicianMaintenanceScreen({super.key});

  @override
  State<TechnicianMaintenanceScreen> createState() => _TechnicianMaintenanceScreenState();
}

class _TechnicianMaintenanceScreenState extends State<TechnicianMaintenanceScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  bool get _isTech => parseAppRole(ApiService.userRole) == AppRole.platformTechnician;

  @override
  void initState() {
    super.initState();
    if (_isTech) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await SupportApi.getServiceRequests();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTech) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bảo trì & sửa chữa')),
        body: const Center(child: Text('Chức năng dành cho Kỹ thuật viên.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảo trì & sửa chữa'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Làm mới', onPressed: _loading ? null : _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Chưa có yêu cầu bảo trì nào được giao.')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = _items[i];
                        final st = serviceStatusOf(r);
                        return Card(
                          child: ListTile(
                            title: Text('${r['failureCode'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${r['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Chip(
                              label: Text(serviceStatusLabels[st] ?? st, style: const TextStyle(fontSize: 11)),
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ServiceRequestDetailScreen(requestId: '${r['id']}')),
                              );
                              if (mounted) _load();
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() => _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState extends State<ServiceRequestDetailScreen> {
  Map<String, dynamic>? _req;
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
      _loading = true;
      _error = null;
    });
    try {
      final r = await SupportApi.getServiceRequest(widget.requestId);
      if (mounted) setState(() => _req = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<Map<String, dynamic>> Function() call, String okMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await call();
      if (!mounted) return;
      setState(() => _req = r);
      _snack(okMsg);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _form(String title, List<(String key, String label, bool required)> fields) async {
    final ctrls = {for (final f in fields) f.$1: TextEditingController()};
    String? err;
    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in fields)
                  TextField(
                    controller: ctrls[f.$1],
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(labelText: f.$2),
                  ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(err!, style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              onPressed: () {
                for (final f in fields) {
                  if (f.$3 && ctrls[f.$1]!.text.trim().isEmpty) {
                    setLocal(() => err = 'Vui lòng nhập: ${f.$2}');
                    return;
                  }
                }
                Navigator.pop(ctx, {for (final e in ctrls.entries) e.key: e.value.text.trim()});
              },
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
    return res;
  }

  Future<void> _diagnose() async {
    final v = await _form('Chẩn đoán sự cố', [
      ('notes', 'Ghi chú kiểm tra', true),
      ('diag', 'Kết luận chẩn đoán', true),
    ]);
    if (v == null || !mounted) return;
    var action = 'Repair';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Hướng xử lý'),
          content: DropdownButtonFormField<String>(
            initialValue: action,
            items: [for (final e in resolutionLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (x) => setLocal(() => action = x ?? action),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => SupportApi.serviceRequestAction(widget.requestId, 'diagnosis', {
        'inspectionNotes': v['notes'],
        'diagnosis': v['diag'],
        'resolutionAction': action,
      }),
      'Đã ghi nhận chẩn đoán.',
    );
  }

  Future<void> _recordWork() async {
    final v = await _form('Ghi nhận kết quả sửa chữa', [('work', 'Công việc đã thực hiện', true)]);
    if (v == null) return;
    await _run(
      () => SupportApi.serviceRequestAction(widget.requestId, 'work', {'workPerformed': v['work']}),
      'Đã ghi nhận công việc.',
    );
  }

  Future<void> _connectionTest() async {
    var succeeded = true;
    final rssi = TextEditingController();
    final latency = TextEditingController();
    final errCode = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Kết quả kiểm tra kết nối'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập kết quả bạn quan sát được trên thiết bị. App không tự suy ra kết nối thành công.',
                  style: TextStyle(fontSize: 12),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kết nối thành công'),
                  value: succeeded,
                  onChanged: (x) => setLocal(() => succeeded = x),
                ),
                TextField(
                  controller: rssi,
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: const InputDecoration(labelText: 'RSSI (tuỳ chọn)'),
                ),
                TextField(
                  controller: latency,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Độ trễ ms (tuỳ chọn)'),
                ),
                if (!succeeded)
                  TextField(
                    controller: errCode,
                    decoration: const InputDecoration(labelText: 'Mã lỗi'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi')),
          ],
        ),
      ),
    );
    final body = <String, dynamic>{
      'succeeded': succeeded,
      'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
      if (num.tryParse(rssi.text.trim()) != null) 'rssi': num.parse(rssi.text.trim()),
      if (int.tryParse(latency.text.trim()) != null) 'roundTripLatencyMs': int.parse(latency.text.trim()),
      if (!succeeded && errCode.text.trim().isNotEmpty) 'errorCode': errCode.text.trim(),
    };
    rssi.dispose();
    latency.dispose();
    errCode.dispose();
    if (ok != true) return;
    await _run(
      () => SupportApi.serviceRequestAction(widget.requestId, 'connection-tests', body),
      'Đã ghi nhận kết quả kiểm tra.',
    );
  }

  /// Thay nóng: chọn thiết bị mới trong cùng zone → xác nhận cũ/mới/zone → gọi API hot-swap.
  Future<void> _hotSwap(Map<String, dynamic> r) async {
    final zoneId = '${r['zoneId']}';
    final oldId = '${r['currentDeviceId'] ?? r['originalDeviceId'] ?? ''}';
    if (oldId.isEmpty) {
      _snack('Yêu cầu chưa gắn thiết bị cần thay.');
      return;
    }
    List<Map<String, dynamic>> devices;
    try {
      devices = await SupportApi.listZoneDevices(zoneId);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    final candidates = devices.where((d) => '${d['deviceId']}' != oldId).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      _snack('Zone chưa có thiết bị thay thế khả dụng. Cần cấp phát thiết bị mới trước.');
      return;
    }
    String? newId;
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Thay nóng thiết bị'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thiết bị cũ: $oldId', style: const TextStyle(fontSize: 12)),
                Text('Zone: $zoneId', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: newId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Thiết bị thay thế'),
                  items: [
                    for (final d in candidates)
                      DropdownMenuItem(
                        value: '${d['deviceId']}',
                        child: Text(
                          '${d['hardwareAddress'] ?? d['deviceId']} · ${d['status'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (x) => setLocal(() => newId = x),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Backend chịu trách nhiệm giữ liên kết dữ liệu lịch sử của thiết bị cũ.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(
              onPressed: newId == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận thay nóng'),
            ),
          ],
        ),
      ),
    );
    final noteText = notes.text.trim();
    notes.dispose();
    if (confirmed != true || newId == null) return;
    await _run(
      () => SupportApi.hotSwapDevice(
        zoneId: zoneId,
        oldDeviceId: oldId,
        serviceRequestId: widget.requestId,
        newDeviceId: newId!,
        notes: noteText.isEmpty ? null : noteText,
      ),
      'Đã gửi yêu cầu thay nóng thiết bị.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết sự cố'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Làm mới', onPressed: _loading || _busy ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _req == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? 'Không có dữ liệu', style: const TextStyle(color: Color(0xFFDC2626))),
              ),
            )
          : _body(_req!),
    );
  }

  Widget _body(Map<String, dynamic> r) {
    final st = serviceStatusOf(r);
    final res = resolutionOf(r);
    final history = (r['history'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final actions = <Widget>[];
    void add(String label, VoidCallback f) =>
        actions.add(FilledButton(onPressed: _busy ? null : f, child: Text(label)));
    switch (st) {
      case 'Assigned':
        add(
          'Nhận việc',
          () => _run(() => SupportApi.serviceRequestAction(widget.requestId, 'accept'), 'Đã nhận việc.'),
        );
      case 'InProgress':
        add('Ghi chẩn đoán', _diagnose);
      case 'Diagnosed':
        add('Ghi kết quả sửa chữa', _recordWork);
        if (res == 'Replacement') add('Thay nóng thiết bị', () => _hotSwap(r));
      case 'WorkCompleted':
        add('Ghi kết quả kiểm tra kết nối', _connectionTest);
      case 'Verified' || 'Resolved':
        add(
          'Đóng yêu cầu',
          () => _run(() => SupportApi.serviceRequestAction(widget.requestId, 'close'), 'Đã đóng yêu cầu.'),
        );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${r['failureCode'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('${r['description'] ?? ''}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(serviceStatusLabels[st] ?? st)),
              if (res.isNotEmpty) Chip(label: Text(resolutionLabels[res] ?? res)),
            ],
          ),
          if ('${r['inspectionNotes'] ?? ''}'.isNotEmpty) _kv('Ghi chú kiểm tra', '${r['inspectionNotes']}'),
          if ('${r['diagnosis'] ?? ''}'.isNotEmpty) _kv('Chẩn đoán', '${r['diagnosis']}'),
          if ('${r['workPerformed'] ?? ''}'.isNotEmpty) _kv('Công việc đã làm', '${r['workPerformed']}'),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (actions.isEmpty)
            const Text('Không có thao tác khả dụng ở trạng thái này.', style: TextStyle(fontSize: 12))
          else
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          const Divider(height: 32),
          const Text('Lịch sử xử lý', style: TextStyle(fontWeight: FontWeight.bold)),
          if (history.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Chưa có lịch sử.')),
          for (final h in history)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${h['eventType']} → ${enumName(h['toStatus'], _statusByIndex)}'),
              subtitle: Text(
                '${h['createdAtUtc'] ?? ''}${(h['notes'] ?? '').toString().isEmpty ? '' : '\n${h['notes']}'}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        Text(v),
      ],
    ),
  );
}
