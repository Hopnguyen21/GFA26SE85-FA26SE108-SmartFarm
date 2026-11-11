import 'package:flutter/material.dart';
import 'quotation_editor.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';

/// Hỗ trợ kỹ thuật cho Farm Owner: danh sách và tạo yêu cầu bảo trì thiết bị
/// (GET /api/v1/service-requests, POST /api/v1/farms/{farmId}/service-requests).
///
/// Mở từ Zone Detail: truyền [zone] để chỉ hiển thị yêu cầu CỦA Zone đó và khóa form tạo vào đúng Zone (không chọn được Zone khác).
/// Mở từ Trang chủ/Hồ sơ (không có [zone]): màn tổng hợp toàn Farm. Khác với yêu cầu triển khai IoT, hợp đồng và khấu hao.
class SupportRequestsScreen extends StatefulWidget {
  final ZoneModel? zone;
  const SupportRequestsScreen({super.key, this.zone});

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
    'INSTALLATION': 'Lắp đặt thiết bị mới',
    'MAINTENANCE': 'Bảo trì & thay thế phần cứng',
  };

  /// Các mã sự cố cụ thể (chỉ dùng khi loại yêu cầu là Bảo trì).
  static const _incidentCodes = <String>[
    'SENSOR_OFFLINE',
    'SENSOR_INACCURATE',
    'ACTUATOR_FAULT',
    'GATEWAY_OFFLINE',
    'OTHER',
  ];

  /// Zone đã có hợp đồng còn hiệu lực (khớp web: Zone này không mở yêu cầu lắp đặt mới).
  Future<bool> _hasActiveContract(String zoneId) async {
    try {
      final list = await ContractApi.getZoneContracts(zoneId: zoneId);
      return list.any(
        (c) => c.zoneId.toLowerCase() == zoneId.toLowerCase() && (c.status == 'Active' || c.status == 'ExpiringSoon'),
      );
    } catch (_) {
      return false;
    }
  }

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
      final all = await SupportApi.getServiceRequests();
      final zone = widget.zone;
      final list = zone == null
          ? all
          : [
              for (final r in all)
                if ('${r['zoneId']}'.toLowerCase() == zone.zoneId.toLowerCase()) r,
            ];
      if (mounted) setState(() => _requests = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final locked = widget.zone;
    final zones = locked != null ? [locked] : Provider.of<FarmProvider>(context, listen: false).allZones;
    if (zones.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có khu vực (Zone) nào để tạo yêu cầu.')));
      return;
    }
    var zoneId = zones.first.zoneId;
    String? deploymentId;
    List<DeploymentRequest> deployments = [];
    try {
      deployments = await DeploymentApi.getOwnerDeploymentRequests();
    } catch (_) {
      // Không tải được danh sách: vẫn tạo được yêu cầu không liên kết.
    }
    if (!mounted) return;
    var hasContract = await _hasActiveContract(zoneId);
    if (!mounted) return;
    var type = hasContract ? 'MAINTENANCE' : 'INSTALLATION';
    var code = _incidentCodes.first;
    final zoneName0 = zones.first.name;
    final title = TextEditingController(
      text: hasContract
          ? 'Yêu cầu bảo trì thiết bị tại $zoneName0'
          : 'Khảo sát & báo giá hợp đồng thiết bị IoT cho $zoneName0',
    );
    final description = TextEditingController(
      text: hasContract
          ? ''
          : 'Trang trại đề nghị khảo sát thực địa, báo giá thiết bị IoT và lập hợp đồng phân khu cho $zoneName0.',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tạo yêu cầu hỗ trợ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${locked.farmName} · ${locked.name} (cố định theo Zone đang xem)',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
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
                    onChanged: (v) async {
                      zoneId = v ?? zoneId;
                      deploymentId = null;
                      final has = await _hasActiveContract(zoneId);
                      setLocal(() {
                        hasContract = has;
                        if (has && type == 'INSTALLATION') type = 'MAINTENANCE';
                      });
                    },
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
                        child: Text(
                          '${d.requestId.substring(0, 8)} · ${deploymentStatusLabels[d.status] ?? d.status}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => deploymentId = v),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('type-$zoneId-$hasContract'),
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Loại yêu cầu *'),
                  items: [
                    DropdownMenuItem(
                      value: 'INSTALLATION',
                      enabled: !hasContract,
                      child: Text(
                        hasContract ? 'Lắp đặt mới (Zone đã có hợp đồng)' : 'Lắp đặt thiết bị mới & chấm node',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo trì & thay thế phần cứng')),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                if (hasContract)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Zone này đã có hợp đồng đang hiệu lực: không mở yêu cầu lắp đặt mới. Hãy chọn Bảo trì hoặc tái ký hợp đồng trong tab Hợp đồng.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF4338CA)),
                    ),
                  ),
                if (type == 'MAINTENANCE')
                  DropdownButtonFormField<String>(
                    initialValue: code,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Loại sự cố'),
                    items: [for (final k in _incidentCodes) DropdownMenuItem(value: k, child: Text(_failureCodes[k]!))],
                    onChanged: (v) => setLocal(() => code = v ?? code),
                  ),
                TextField(
                  controller: title,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Tiêu đề yêu cầu *'),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Mô tả chi tiết *'),
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
    final bodyText = description.text.trim();
    final titleText = title.text.trim();
    description.dispose();
    title.dispose();
    if (ok != true || !mounted) return;
    if (titleText.isEmpty || bodyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần nhập tiêu đề và mô tả chi tiết.')));
      return;
    }
    if (type == 'INSTALLATION' && hasContract) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zone đã có hợp đồng: không mở yêu cầu lắp đặt mới. Hãy tái ký hợp đồng hoặc chọn Bảo trì.'),
        ),
      );
      return;
    }
    // Backend chỉ có failureCode + description: tiêu đề đưa vào đầu mô tả để kỹ thuật viên thấy.
    final text = '$titleText\n\n$bodyText';
    try {
      final farmId = zones.firstWhere((z) => z.zoneId == zoneId).farmId;
      await SupportApi.createServiceRequest(
        farmId: farmId,
        zoneId: zoneId,
        failureCode: type == 'INSTALLATION' ? 'INSTALLATION' : code,
        description: text,
        deploymentRequestId: deploymentId,
      );
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
        title: Text(
          widget.zone == null ? 'Hỗ trợ kỹ thuật' : 'Hỗ trợ kỹ thuật · ${widget.zone!.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (ApiService.appRole == AppRole.farmOwner ||
              (!ApiService.isAuthenticated && context.read<FarmProvider>().currentRole == 'OWNER'))
            IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Tạo yêu cầu', onPressed: _create),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [Padding(padding: const EdgeInsets.all(24), child: Text('Không tải được yêu cầu: $_error'))],
              )
            : _requests.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.zone == null ? 'Chưa có yêu cầu hỗ trợ nào.' : 'Zone này chưa có yêu cầu hỗ trợ nào.',
                    ),
                  ),
                ],
              )
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

  bool get _isOwner =>
      ApiService.appRole == AppRole.farmOwner ||
      (!ApiService.isAuthenticated && context.read<FarmProvider>().currentRole == 'OWNER');
  bool get _isTechnician =>
      ApiService.appRole == AppRole.platformTechnician ||
      (!ApiService.isAuthenticated && context.read<FarmProvider>().currentRole == 'TECHNICIAN');

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
      final q = await SupportApi.getQuotation(widget.serviceRequestId);
      String? depStatus;
      final depId = widget.deploymentRequestId;
      if (_isOwner && depId != null && depId.isNotEmpty) {
        try {
          depStatus = (await DeploymentApi.getDeploymentRequest(depId, technician: false)).status;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Số tiền: ${_money(amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Hệ thống ghi nhận khoản thanh toán bạn khai báo bên dưới; chưa có cổng thanh toán trực tuyến. Hãy thanh toán trước rồi nhập mã giao dịch thật.',
                  style: TextStyle(fontSize: 11),
                ),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Họ tên người ký'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Phương thức'),
                  items: const [
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Chuyển khoản')),
                    DropdownMenuItem(value: 'CASH', child: Text('Tiền mặt')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? method),
                ),
                TextField(
                  controller: ref,
                  decoration: const InputDecoration(labelText: 'Mã giao dịch / biên nhận'),
                ),
              ],
            ),
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
          ? await SupportApi.signContractAndPayDeposit(
              widget.serviceRequestId,
              signerFullName: signer,
              paymentMethod: method,
              transactionReference: reference,
            )
          : await SupportApi.signAcceptanceAndPayFinal(
              widget.serviceRequestId,
              signerFullName: signer,
              paymentMethod: method,
              transactionReference: reference,
            );
      _lastPayment = payment;
      await _load();
    } catch (e) {
      if (mounted) _snack('Không ghi nhận được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createQuotation() async {
    if (!_isTechnician || _busy || (_quotation != null && _quotation!.status != 'SentToOwner')) return;
    final draft = await Navigator.push<QuotationDraft>(
      context,
      MaterialPageRoute(builder: (_) => QuotationEditor(initial: _quotation)),
    );
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await SupportApi.createQuotation(
        widget.serviceRequestId,
        items: draft.items,
        notes: draft.notes,
        contractTerms: draft.terms,
      );
      await _load();
    } catch (e) {
      if (mounted) _snack('Không lập được báo giá: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Không tải được báo giá: $_error'),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      );
    }
    final q = _quotation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Báo giá & hợp đồng lắp đặt', style: TextStyle(fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 4),
          child: Text(
            'Cọc 30% và nghiệm thu 70% ở đây thuộc báo giá lắp đặt thiết bị của yêu cầu dịch vụ này. '
            'Không liên quan tới hợp đồng thuê Zone (mục Hợp đồng thuê & Khấu hao), vốn là nhánh tuỳ chọn riêng.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
          ),
        ),
        if (q == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Kỹ thuật viên sẽ khảo sát, trao đổi với Owner và lập danh mục thiết bị cùng báo giá để xác nhận hợp đồng.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        if (q != null) ...[
          Text('Trạng thái: ${_statusText[q.status] ?? q.status}', style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final i in q.items)
            Text(
              '• ${i.code} · ${i.name}: ${i.quantity} ${i.unit} × ${_money(i.unitPrice)} — ${_money(i.totalAmount)} (đã gồm VAT ${i.vatPercent.toStringAsFixed(0)}%)${i.notes?.isNotEmpty == true ? " · ${i.notes}" : ""}',
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 4),
          Text(
            'Tổng: ${_money(q.totalAmount)} · Cọc 30%: ${_money(q.deposit30)} · Còn lại 70%: ${_money(q.remaining70)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (q.notes?.isNotEmpty == true) Text('Trao đổi / bổ sung: ${q.notes}', style: const TextStyle(fontSize: 12)),
          if (q.status != 'SentToOwner')
            const Text('Hợp đồng đã ký: danh mục thiết bị và báo giá không còn chỉnh sửa tại đây.'),
          if (q.contractTerms != null) Text('Điều khoản: ${q.contractTerms}', style: const TextStyle(fontSize: 12)),
          if (_lastPayment != null)
            Text(
              'Đã ghi nhận ${_lastPayment!.paymentStage}: ${_money(_lastPayment!.amount)} bởi ${_lastPayment!.signerFullName} (${_lastPayment!.status})',
              style: const TextStyle(fontSize: 12, color: Color(0xFF059669)),
            ),
        ],
        if (_isOwner && q != null && q.status == 'SentToOwner')
          FilledButton(
            onPressed: _busy ? null : () => _sign(deposit: true),
            child: const Text('Ký hợp đồng & xác nhận cọc 30%'),
          ),
        if (_isOwner && q != null && q.status == 'SignedByOwner') ...[
          if (_deploymentStatus != 'Completed')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Chỉ ký nghiệm thu khi đợt lắp đặt liên kết đã hoàn tất (hiện: ${deploymentStatusLabels[_deploymentStatus ?? ''] ?? 'chưa xác định'}).',
                style: const TextStyle(fontSize: 12, color: Color(0xFFD97706)),
              ),
            ),
          FilledButton(
            onPressed: _busy || _deploymentStatus != 'Completed' ? null : () => _sign(deposit: false),
            child: const Text('Ký nghiệm thu & thanh toán 70%'),
          ),
        ],
        if (_isTechnician && (q == null || q.status == 'SentToOwner'))
          OutlinedButton(
            onPressed: _busy ? null : _createQuotation,
            child: Text(q == null ? 'Lập thiết bị & báo giá hợp đồng' : 'Chỉnh thiết bị & báo giá trước khi ký'),
          ),
      ],
    );
  }
}
