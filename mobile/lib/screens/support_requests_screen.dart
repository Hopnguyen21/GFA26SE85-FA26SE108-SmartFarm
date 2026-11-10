import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/iot_deployment.dart';
import '../services/api_service.dart';
import '../services/app_role.dart';

/// Hỗ trợ kỹ thuật cho Farm Owner: danh sách và tạo yêu cầu bảo trì thiết bị
/// (GET /api/v1/service-requests, POST /api/v1/farms/{farmId}/service-requests).
class SupportRequestsScreen extends StatefulWidget {
  const SupportRequestsScreen({super.key});

  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  static const _failureCodes = <String, String>{
    'SENSOR_OFFLINE': 'Cảm biến mất kết nối',
    'SENSOR_INACCURATE': 'Cảm biến đo sai',
    'ACTUATOR_FAULT': 'Thiết bị chấp hành lỗi',
    'GATEWAY_OFFLINE': 'Gateway mất kết nối',
    'OTHER': 'Sự cố khác',
  };

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
      final list = await ApiService.getServiceRequests();
      if (mounted) setState(() => _requests = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final zones = Provider.of<FarmProvider>(context, listen: false).allZones;
    if (zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có khu vực (Zone) nào để tạo yêu cầu.')),
      );
      return;
    }
    var zoneId = zones.first.zoneId;
    String? deploymentId;
    List<DeploymentRequest> deployments = [];
    try {
      deployments = await ApiService.getOwnerDeploymentRequests();
    } catch (_) {
      // Không tải được danh sách: vẫn tạo được yêu cầu không liên kết.
    }
    if (!mounted) return;
    var code = _failureCodes.keys.first;
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo yêu cầu hỗ trợ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: zoneId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Khu vực'),
                  items: [
                    for (final z in zones)
                      DropdownMenuItem(
                        value: z.zoneId,
                        child: Text('${z.farmName} · ${z.name}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setLocal(() {
                    zoneId = v ?? zoneId;
                    deploymentId = null;
                  }),
                ),
                DropdownButtonFormField<String?>(
                  key: ValueKey('dep-$zoneId'),
                  initialValue: deploymentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Liên kết yêu cầu triển khai (tuỳ chọn)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Không liên kết')),
                    for (final d in deployments.where((d) => d.zoneId == zoneId))
                      DropdownMenuItem<String?>(
                        value: d.requestId,
                        child: Text('${d.requestId.substring(0, 8)} · ${deploymentStatusLabels[d.status] ?? d.status}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => deploymentId = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: code,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Loại sự cố'),
                  items: [
                    for (final e in _failureCodes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setLocal(() => code = v ?? code),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả sự cố'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi')),
          ],
        ),
      ),
    );
    final text = description.text.trim();
    description.dispose();
    if (ok != true || !mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần mô tả sự cố.')));
      return;
    }
    try {
      final farmId = zones.firstWhere((z) => z.zoneId == zoneId).farmId;
      await ApiService.createServiceRequest(farmId: farmId, zoneId: zoneId, failureCode: code, description: text, deploymentRequestId: deploymentId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tạo yêu cầu thất bại: $e')));
      }
    }
  }

  void _showDetail(Map<String, dynamic> r) {
    final history = (r['history'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _failureCodes[r['failureCode']] ?? '${r['failureCode']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('${r['description'] ?? ''}'),
            if (r['diagnosis'] != null) ...[const SizedBox(height: 10), Text('Chẩn đoán: ${r['diagnosis']}')],
            if (r['workPerformed'] != null) ...[const SizedBox(height: 6), Text('Đã xử lý: ${r['workPerformed']}')],
            const Divider(height: 24),
            _QuotationPanel(serviceRequestId: '${r['id']}', deploymentRequestId: r['deploymentRequestId']?.toString()),
            const Divider(height: 24),
            const Text('Lịch sử', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final h in history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${h['toStatus']}'),
                subtitle: Text('${h['createdAtUtc'] ?? ''}${h['notes'] == null ? '' : '\n${h['notes']}'}'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: const Text('Hỗ trợ kỹ thuật', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          if (ApiService.appRole == AppRole.farmOwner)
            IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Tạo yêu cầu', onPressed: _create),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Không tải được yêu cầu: $_error'))])
                : _requests.isEmpty
                    ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('Chưa có yêu cầu hỗ trợ nào.'))])
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final r = _requests[i];
                          return Card(
                            child: ListTile(
                              onTap: () => _showDetail(r),
                              title: Text(_failureCodes[r['failureCode']] ?? '${r['failureCode']}'),
                              subtitle: Text('${r['description'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: Text('${r['status']}', style: const TextStyle(fontSize: 11)),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Báo giá & hợp đồng lắp đặt của một service request. Owner xem, ký hợp đồng + cọc 30%, ký nghiệm thu + 70%;
/// kỹ thuật viên được giao lập báo giá. Trạng thái chỉ lấy từ backend (SentToOwner → SignedByOwner → Completed).
class _QuotationPanel extends StatefulWidget {
  final String serviceRequestId;
  final String? deploymentRequestId;
  const _QuotationPanel({required this.serviceRequestId, this.deploymentRequestId});

  @override
  State<_QuotationPanel> createState() => _QuotationPanelState();
}

class _QuotationPanelState extends State<_QuotationPanel> {
  Quotation? _quotation;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  ServicePayment? _lastPayment;
  String? _deploymentStatus; // trạng thái yêu cầu triển khai liên kết, lấy từ backend

  bool get _isOwner => ApiService.appRole == AppRole.farmOwner;
  bool get _isTechnician => ApiService.appRole == AppRole.platformTechnician;

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
      final q = await ApiService.getQuotation(widget.serviceRequestId);
      String? depStatus;
      final depId = widget.deploymentRequestId;
      if (_isOwner && depId != null && depId.isNotEmpty) {
        try {
          depStatus = (await ApiService.getDeploymentRequest(depId, technician: false)).status;
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _quotation = q;
          _deploymentStatus = depStatus;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$b đ';
  }

  static const _statusText = <String, String>{
    'SentToOwner': 'Chờ chủ trang trại ký hợp đồng',
    'SignedByOwner': 'Đã ký hợp đồng, đã ghi nhận cọc 30%',
    'Completed': 'Đã ký nghiệm thu, đã ghi nhận 70%',
  };

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// Backend chỉ ghi nhận khoản thanh toán do người ký khai báo (chưa tích hợp cổng thanh toán),
  /// nên tên người ký, phương thức và mã giao dịch phải do người dùng tự nhập.
  Future<void> _sign({required bool deposit}) async {
    final q = _quotation!;
    final name = TextEditingController();
    final ref = TextEditingController();
    var method = 'BANK_TRANSFER';
    final amount = deposit ? q.deposit30 : q.remaining70;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          title: Text(deposit ? 'Ký hợp đồng & cọc 30%' : 'Ký nghiệm thu & thanh toán 70%'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Số tiền: ${_money(amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Hệ thống ghi nhận khoản thanh toán bạn khai báo bên dưới; chưa có cổng thanh toán trực tuyến. Hãy thanh toán trước rồi nhập mã giao dịch thật.', style: TextStyle(fontSize: 11)),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên người ký')),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Phương thức'),
                items: const [
                  DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Chuyển khoản')),
                  DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                ],
                onChanged: (v) => setLocal(() => method = v ?? method),
              ),
              TextField(controller: ref, decoration: const InputDecoration(labelText: 'Mã giao dịch / biên nhận')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ký & ghi nhận')),
          ],
        ),
      ),
    );
    final signer = name.text.trim();
    final reference = ref.text.trim();
    name.dispose();
    ref.dispose();
    if (ok != true || !mounted) return;
    if (signer.isEmpty || reference.isEmpty) {
      _snack('Cần nhập họ tên người ký và mã giao dịch.');
      return;
    }
    setState(() => _busy = true);
    try {
      final payment = deposit
          ? await ApiService.signContractAndPayDeposit(widget.serviceRequestId, signerFullName: signer, paymentMethod: method, transactionReference: reference)
          : await ApiService.signAcceptanceAndPayFinal(widget.serviceRequestId, signerFullName: signer, paymentMethod: method, transactionReference: reference);
      _lastPayment = payment;
      await _load();
    } catch (e) {
      if (mounted) _snack('Không ghi nhận được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createQuotation() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    final vat = TextEditingController(text: '8');
    final terms = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Lập báo giá'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: code, decoration: const InputDecoration(labelText: 'Mã hạng mục')),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Tên hạng mục')),
            TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số lượng')),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Đơn giá (đ)')),
            TextField(controller: vat, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'VAT (%)')),
            TextField(controller: terms, maxLines: 2, decoration: const InputDecoration(labelText: 'Điều khoản hợp đồng')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Gửi cho chủ trang trại')),
        ],
      ),
    );
    final item = <String, dynamic>{
      'code': code.text.trim(),
      'name': name.text.trim(),
      'category': 'HARDWARE',
      'unit': 'Cái',
      'quantity': int.tryParse(qty.text.trim()) ?? 0,
      'unitPrice': double.tryParse(price.text.trim()) ?? 0,
      'vatPercent': double.tryParse(vat.text.trim()) ?? 0,
    };
    final termsText = terms.text.trim();
    for (final c in [code, name, qty, price, vat, terms]) {
      c.dispose();
    }
    if (ok != true || !mounted) return;
    if ((item['code'] as String).isEmpty || (item['name'] as String).isEmpty || (item['quantity'] as int) < 1 || (item['unitPrice'] as double) <= 0) {
      _snack('Cần nhập mã, tên, số lượng và đơn giá hợp lệ.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.createQuotation(widget.serviceRequestId, items: [item], contractTerms: termsText);
      await _load();
    } catch (e) {
      if (mounted) _snack('Không lập được báo giá: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
    if (_error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Không tải được báo giá: $_error'),
        TextButton(onPressed: _load, child: const Text('Thử lại')),
      ]);
    }
    final q = _quotation;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Báo giá & hợp đồng lắp đặt', style: TextStyle(fontWeight: FontWeight.bold)),
      if (q == null) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Chưa có báo giá cho yêu cầu này.', style: TextStyle(color: Color(0xFF64748B)))),
      if (q != null) ...[
        Text('Trạng thái: ${_statusText[q.status] ?? q.status}', style: const TextStyle(fontWeight: FontWeight.w600)),
        for (final i in q.items) Text('• ${i.quantity}× ${i.name} — ${_money(i.totalAmount)} (đã gồm VAT ${i.vatPercent.toStringAsFixed(0)}%)', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text('Tổng: ${_money(q.totalAmount)} · Cọc 30%: ${_money(q.deposit30)} · Còn lại 70%: ${_money(q.remaining70)}', style: const TextStyle(fontSize: 12)),
        if (q.contractTerms != null) Text('Điều khoản: ${q.contractTerms}', style: const TextStyle(fontSize: 12)),
        if (_lastPayment != null)
          Text('Đã ghi nhận ${_lastPayment!.paymentStage}: ${_money(_lastPayment!.amount)} bởi ${_lastPayment!.signerFullName} (${_lastPayment!.status})', style: const TextStyle(fontSize: 12, color: Color(0xFF059669))),
      ],
      if (_isOwner && q != null && q.status == 'SentToOwner')
        FilledButton(onPressed: _busy ? null : () => _sign(deposit: true), child: const Text('Ký hợp đồng & xác nhận cọc 30%')),
      if (_isOwner && q != null && q.status == 'SignedByOwner') ...[
        if (_deploymentStatus != 'Completed')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Chỉ ký nghiệm thu khi đợt lắp đặt liên kết đã hoàn tất (hiện: ${deploymentStatusLabels[_deploymentStatus ?? ''] ?? 'chưa xác định'}).',
              style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
            ),
          ),
        FilledButton(onPressed: _busy || _deploymentStatus != 'Completed' ? null : () => _sign(deposit: false), child: const Text('Ký nghiệm thu & thanh toán 70%')),
      ],
      if (_isTechnician && (q == null || q.status == 'SentToOwner'))
        OutlinedButton(onPressed: _busy ? null : _createQuotation, child: Text(q == null ? 'Lập báo giá' : 'Lập lại báo giá')),
    ]);
  }
}
