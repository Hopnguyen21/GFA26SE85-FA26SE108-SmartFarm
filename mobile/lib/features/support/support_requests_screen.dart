import 'dart:async';
import 'package:flutter/material.dart';
import 'quotation_editor.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';
import 'service_board_logic.dart';
import 'technician_maintenance_screen.dart'
    show serviceStatusLabels, serviceStatusColor, serviceStatusOf;

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
  int _gen = 0; // đổi sau mỗi lần tải để thẻ đọc lại báo giá/triển khai
  bool _loading = true;
  String? _error;

  static const _failureCodes = kServiceFailureCodes;

  /// Các mã sự cố cụ thể (chỉ dùng khi loại yêu cầu là Bảo trì).
  static const _incidentCodes = <String>[
    'SENSOR_OFFLINE',
    'SENSOR_INACCURATE',
    'ACTUATOR_FAULT',
    'GATEWAY_OFFLINE',
    'OTHER',
  ];

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
                if ('${r['zoneId']}'.toLowerCase() == zone.zoneId.toLowerCase())
                  r,
            ];
      if (mounted)
        setState(() {
          _requests = list;
          _gen++;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _zoneNameOf(Map<String, dynamic> r) {
    final id = '${r['zoneId'] ?? ''}'.toLowerCase();
    final z = Provider.of<FarmProvider>(
      context,
      listen: false,
    ).allZones.where((z) => z.zoneId.toLowerCase() == id).firstOrNull;
    return z == null ? '' : '${z.name} · ${z.farmName}';
  }

  Future<void> _create() async {
    final locked = widget.zone;
    final zones = locked != null
        ? [locked]
        : Provider.of<FarmProvider>(context, listen: false).allZones;
    if (zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có khu vực (Zone) nào để tạo yêu cầu.'),
        ),
      );
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
    var type = 'INSTALLATION';
    var code = _incidentCodes.first;
    final zoneName0 = zones.first.name;
    final title = TextEditingController(
      text: 'Khảo sát & báo giá thiết bị IoT cho $zoneName0',
    );
    final description = TextEditingController(
      text:
          'Đề nghị khảo sát và thống nhất thiết bị cần lắp đặt/bổ sung cho $zoneName0.',
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
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
                          child: Text(
                            '${z.farmName} · ${z.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
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
                  decoration: const InputDecoration(
                    labelText: 'Liên kết yêu cầu triển khai (tuỳ chọn)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Không liên kết'),
                    ),
                    for (final d in deployments.where(
                      (d) => d.zoneId == zoneId,
                    ))
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
                  key: ValueKey('type-$zoneId'),
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Loại yêu cầu *',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'INSTALLATION',

                      child: Text(
                        'Lắp đặt / bổ sung thiết bị',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'MAINTENANCE',
                      child: Text('Bảo trì & thay thế phần cứng'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                if (type == 'MAINTENANCE')
                  DropdownButtonFormField<String>(
                    initialValue: code,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Loại sự cố'),
                    items: [
                      for (final k in _incidentCodes)
                        DropdownMenuItem(
                          value: k,
                          child: Text(_failureCodes[k]!),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => code = v ?? code),
                  ),
                TextField(
                  controller: title,
                  maxLength: 150,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề yêu cầu *',
                  ),
                ),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết *',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gửi'),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần nhập tiêu đề và mô tả chi tiết.')),
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
        failureCode: type == 'INSTALLATION' ? 'NEW_INSTALL' : code,
        description: text,
        deploymentRequestId: deploymentId,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Tạo yêu cầu thất bại: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: Text(
          widget.zone == null
              ? 'Hỗ trợ kỹ thuật'
              : 'Hỗ trợ kỹ thuật · ${widget.zone!.name}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (ApiService.appRole == AppRole.farmOwner ||
              (!ApiService.isAuthenticated &&
                  context.read<FarmProvider>().currentRole == 'OWNER'))
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Tạo yêu cầu',
              onPressed: _create,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Không tải được yêu cầu: $_error'),
                  ),
                ],
              )
            : _requests.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.zone == null
                          ? 'Chưa có yêu cầu hỗ trợ nào.'
                          : 'Zone này chưa có yêu cầu hỗ trợ nào.',
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
                  return OwnerRequestCard(
                    key: ValueKey('${r['id']}-$_gen'),
                    request: r,
                    zoneName: _zoneNameOf(r),
                    zone: widget.zone,
                    onChanged: _load,
                  );
                },
              ),
      ),
    );
  }
}

const Map<String, String> kServiceFailureCodes = {
  'SENSOR_OFFLINE': 'Cảm biến mất kết nối',
  'SENSOR_INACCURATE': 'Cảm biến đo sai',
  'ACTUATOR_FAULT': 'Thiết bị chấp hành lỗi',
  'GATEWAY_OFFLINE': 'Gateway mất kết nối',
  'OTHER': 'Sự cố khác',
  'INSTALLATION': 'Lắp đặt thiết bị mới',
  'NEW_INSTALL': 'Lắp đặt thiết bị mới',
  'MAINTENANCE': 'Bảo trì & thay thế phần cứng',
};

/// Báo giá và trạng thái triển khai của một phiếu, đọc từ backend. [known] = false khi không phải phiếu lắp đặt đang mở
/// hoặc khi đọc lỗi: khi đó không suy đoán việc tiếp theo.
class OwnerRequestInfo {
  final bool known;
  final Quotation? quote;
  final String? depStatus;

  /// Trạng thái báo giá hiệu lực = báo giá kết hợp cờ cọc/nghiệm thu trên phiếu (xem [effectiveQuotationStatus]).
  final String? status;
  const OwnerRequestInfo({
    this.known = false,
    this.quote,
    this.depStatus,
    this.status,
  });

  ({String text, bool needsAction})? get next => !known
      ? null
      : ownerNextAction(
          quotationStatus: status ?? quote?.status,
          deploymentStatus: depStatus,
          closed: false,
          depositLabel: quote?.depositLabel,
          remainingLabel: quote?.remainingLabel,
        );
}

Future<OwnerRequestInfo> loadOwnerRequestInfo(Map<String, dynamic> r) async {
  if (serviceKindOf(r) != ServiceKind.installation ||
      isClosedStatus(serviceStatusOf(r))) {
    return const OwnerRequestInfo();
  }
  final id = '${r['id']}';
  Quotation? q;
  try {
    q = await SupportApi.getQuotation(id);
  } catch (_) {
    return const OwnerRequestInfo();
  }
  String? dep;
  final depId = '${r['deploymentRequestId'] ?? ''}';
  if (depId.isNotEmpty) {
    try {
      final d = await DeploymentApi.getDeploymentRequest(
        depId,
        technician: false,
      );
      if (d.zoneId == '${r['zoneId']}') dep = d.status;
    } catch (_) {}
  }
  return OwnerRequestInfo(
    known: true,
    quote: q,
    depStatus: dep,
    status: effectiveQuotationStatus(q?.status, r),
  );
}

/// Mở chi tiết phiếu của Owner: mô tả, chẩn đoán, hợp đồng (ký + cọc 30%, nghiệm thu + 70%) và lịch sử.
/// [onChanged] gọi khi đóng chi tiết để nơi gọi tải lại trạng thái.
Future<void> showServiceRequestDetail(
  BuildContext context,
  Map<String, dynamic> r, {
  VoidCallback? onChanged,
  ZoneModel? zone,
}) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Hợp đồng & thanh toán')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              kServiceFailureCodes[r['failureCode']] ?? '${r['failureCode']}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('${r['description'] ?? ''}'),
            if (r['diagnosis'] != null) ...[
              const SizedBox(height: 10),
              Text('Chẩn đoán: ${r['diagnosis']}'),
            ],
            if (r['workPerformed'] != null) ...[
              const SizedBox(height: 6),
              Text('Đã xử lý: ${r['workPerformed']}'),
            ],
            const Divider(height: 24),
            QuotationPanel(
              serviceRequestId: '${r['id']}',
              deploymentRequestId: r['deploymentRequestId']?.toString(),
              zone: zone,
              farmName: zone?.farmName,
              zoneName: zone?.name,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    ),
  );
  onChanged?.call();
}

/// Thẻ yêu cầu của Owner: loại, trạng thái dịch vụ, giai đoạn hợp đồng và việc đang chờ chính Owner.
/// Tự đọc báo giá/triển khai từ backend; bấm vào để xem hợp đồng và ký/thanh toán.
class OwnerRequestCard extends StatefulWidget {
  final Map<String, dynamic> request;
  final String zoneName;
  final ZoneModel? zone;

  /// Gọi sau khi Owner đóng chi tiết (có thể đã ký/thanh toán) để danh sách tải lại.
  final VoidCallback? onChanged;
  const OwnerRequestCard({
    super.key,
    required this.request,
    this.zoneName = '',
    this.zone,
    this.onChanged,
  });

  @override
  State<OwnerRequestCard> createState() => _OwnerRequestCardState();
}

class _OwnerRequestCardState extends State<OwnerRequestCard> {
  OwnerRequestInfo _info = const OwnerRequestInfo();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final info = await loadOwnerRequestInfo(widget.request);
    if (mounted) setState(() => _info = info);
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final status = serviceStatusOf(r);
    final install = serviceKindOf(r) == ServiceKind.installation;
    final closed = isClosedStatus(status);
    final q = _info.quote;
    final next = closed ? (text: 'Đã đóng', needsAction: false) : _info.next;
    final desc = '${r['description'] ?? ''}'.trim();
    // Phiếu bảo trì lấy tên loại sự cố làm tiêu đề, mô tả hiện bên dưới; phiếu lắp đặt dùng câu đầu của mô tả.
    final title = install
        ? serviceTitle(r)
        : (kServiceFailureCodes['${r['failureCode']}'] ?? serviceTitle(r));
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await showServiceRequestDetail(
            context,
            r,
            zone: widget.zone,
            onChanged: () {
              _reload();
              widget.onChanged?.call();
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _badge(
                    install ? 'Lắp đặt thiết bị mới' : 'Bảo trì / sửa chữa',
                    install ? const Color(0xFF0369A1) : const Color(0xFFD97706),
                  ),
                  _badge(
                    'Dịch vụ: ${serviceStatusLabels[status] ?? status}',
                    serviceStatusColor(status),
                  ),
                  if (_info.known)
                    _badge(
                      contractStageLabel(
                        _info.status ?? q?.status,
                        depositLabel: q?.depositLabel,
                      ),
                      const Color(0xFF475569),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.zoneName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.zoneName,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              if (desc.isNotEmpty && desc != title && desc != '$title.')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              if (q != null && _info.known)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Tổng HĐ: ${formatMoney(q.totalAmount)} · Cọc ${q.depositLabel}: ${formatMoney(q.deposit30)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              if (next != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: next.needsAction
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: next.needsAction
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        next.needsAction
                            ? Icons.pending_actions
                            : Icons.hourglass_empty,
                        size: 16,
                        color: next.needsAction
                            ? const Color(0xFFB45309)
                            : Colors.black45,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          next.needsAction
                              ? '${next.text} · bấm để xem hợp đồng'
                              : next.text,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: next.needsAction
                                ? const Color(0xFF92400E)
                                : Colors.black54,
                          ),
                        ),
                      ),
                      if (next.needsAction)
                        const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thông báo trên bảng điều khiển Zone: có phiếu đang chờ chính Owner (ký hợp đồng, cọc, nghiệm thu) thì hiện dải
/// cảnh báo; bấm vào mở thẳng hợp đồng của phiếu đó. Không có việc chờ thì không hiện gì.
class ZonePendingActionsBanner extends StatefulWidget {
  final ZoneModel zone;
  const ZonePendingActionsBanner({super.key, required this.zone});

  @override
  State<ZonePendingActionsBanner> createState() =>
      _ZonePendingActionsBannerState();
}

class _ZonePendingActionsBannerState extends State<ZonePendingActionsBanner> {
  final List<({Map<String, dynamic> request, String text})> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZonePendingActionsBanner old) {
    super.didUpdateWidget(old);
    if (old.zone.zoneId != widget.zone.zoneId) _load();
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId.toLowerCase();
    try {
      final all = await SupportApi.getServiceRequests();
      final mine = [
        for (final r in all)
          if ('${r['zoneId']}'.toLowerCase() == zoneId) r,
      ];
      final infos = await Future.wait([
        for (final r in mine) loadOwnerRequestInfo(r),
      ]);
      final out = <({Map<String, dynamic> request, String text})>[];
      for (var i = 0; i < mine.length; i++) {
        final n = infos[i].next;
        if (n != null && n.needsAction) {
          out.add((request: mine[i], text: n.text));
        }
      }
      if (!mounted || widget.zone.zoneId.toLowerCase() != zoneId) return;
      setState(() {
        _pending
          ..clear()
          ..addAll(out);
      });
    } catch (_) {
      // Thông báo là phụ: lỗi mạng thì không chặn màn Zone.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    final first = _pending.first;
    return Material(
      color: const Color(0xFFFEF3C7),
      child: InkWell(
        onTap: () => showServiceRequestDetail(
          context,
          first.request,
          zone: widget.zone,
          onChanged: _load,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active,
                size: 18,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pending.length == 1
                      ? first.text
                      : '${_pending.length} yêu cầu đang chờ bạn · ${first.text}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              const Text(
                'Xem hợp đồng',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: Color(0xFF92400E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Báo giá & hợp đồng lắp đặt của một service request. Owner xem, ký hợp đồng + cọc 30%, ký nghiệm thu + 70%;
/// kỹ thuật viên được giao lập báo giá. Trạng thái chỉ lấy từ backend (SentToOwner → SignedByOwner → Completed).
class QuotationPanel extends StatefulWidget {
  final String serviceRequestId;
  final String? deploymentRequestId;

  /// Trang trại và phân khu hiện ở khung đầu bảng báo giá (null nếu không biết).
  final String? farmName;
  final String? zoneName;

  /// Gọi sau khi tạo/sửa báo giá hoặc ký xong để màn chứa panel tải lại trạng thái hợp đồng.
  final VoidCallback? onChanged;

  /// Zone của phiếu (nếu biết): khi Owner chưa lưu dự toán, tính "Thiết bị đề xuất" theo diện tích Zone thay cho bảng trống.
  final ZoneModel? zone;
  const QuotationPanel({
    super.key,
    required this.serviceRequestId,
    this.deploymentRequestId,
    this.farmName,
    this.zoneName,
    this.onChanged,
    this.zone,
  });

  @override
  State<QuotationPanel> createState() => _QuotationPanelState();
}

class _QuotationPanelState extends State<QuotationPanel> {
  Quotation? _quotation;
  bool _loading = true;
  bool _busy = false;
  int? _nodeCount;
  String? _ownerName;
  String? _error;
  ServicePayment? _lastPayment;
  String?
  _deploymentStatus; // trạng thái yêu cầu triển khai liên kết, lấy từ backend

  /// Nhãn tỷ lệ theo CHÍNH báo giá này (đã chốt khi cọc), không theo cấu hình hiện hành.
  String get _dep =>
      _quotation?.depositLabel ?? BusinessParameters.active.depositLabel;
  String get _rem =>
      _quotation?.remainingLabel ?? BusinessParameters.active.remainingLabel;

  bool get _isOwner =>
      ApiService.appRole == AppRole.farmOwner ||
      (!ApiService.isAuthenticated &&
          context.read<FarmProvider>().currentRole == 'OWNER');

  /// Tiêu đề hợp đồng như web: "Hợp đồng lắp đặt IoT #MÃ-PHIẾU (viết hoa)".
  String get _contractTitle =>
      'Hợp đồng lắp đặt IoT #${widget.serviceRequestId.toUpperCase()}';

  /// Mở bảng hợp đồng ở chế độ chỉ xem (đã ký hoặc đã cọc nên không sửa được).
  Future<void> _viewLocked() async {
    final q = _quotation;
    if (q == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationEditor(
          initial: q,
          contractTitle: _contractTitle,
          farmName: widget.farmName,
          zoneName: widget.zoneName,
          readOnly: true,
        ),
      ),
    );
  }

  bool get _isTechnician =>
      ApiService.appRole == AppRole.platformTechnician ||
      (!ApiService.isAuthenticated &&
          context.read<FarmProvider>().currentRole == 'TECHNICIAN');

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
      await BusinessParametersStore.refresh(); // tỷ lệ cọc do Admin cấu hình (không đoán 30%)
      final q = await SupportApi.getQuotation(widget.serviceRequestId);
      String? depStatus;
      final depId = widget.deploymentRequestId;
      if ((_isOwner || _isTechnician) && depId != null && depId.isNotEmpty) {
        try {
          final deployment = await DeploymentApi.getDeploymentRequest(
            depId,
            technician: !_isOwner,
          );
          final service = await SupportApi.getServiceRequest(
            widget.serviceRequestId,
          );
          if (deployment.farmId == service['farmId'] &&
              deployment.zoneId == service['zoneId']) {
            depStatus = deployment.status;
          }
        } catch (_) {}
      }
      String? ownerName;
      if (_isOwner) {
        try {
          final me = await AccountApi.getMe();
          final n = '${me?['fullName'] ?? ''}'.trim();
          if (n.isNotEmpty) ownerName = n;
        } catch (_) {}
      }
      int? nodes;
      if (_isOwner) {
        try {
          var zoneId = widget.zone?.zoneId ?? '';
          if (zoneId.isEmpty) {
            zoneId =
                '${(await SupportApi.getServiceRequest(widget.serviceRequestId))['zoneId'] ?? ''}';
          }
          if (zoneId.isNotEmpty) {
            nodes = (await FarmApi.getDeviceMapLocations(zoneId)).length;
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _quotation = q;
          _deploymentStatus = depStatus;
          _nodeCount = nodes;
          if (ownerName != null) {
            _ownerName = ownerName;
            if (_signer30.text == 'Chủ Trang Trại') _signer30.text = ownerName;
            if (_signer70.text == 'Chủ Trang Trại') _signer70.text = ownerName;
          }
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

  Map<String, String> get _statusText => <String, String>{
    'SentToOwner': 'Chờ chủ trang trại ký hợp đồng',
    'SignedByOwner': 'Đã ký hợp đồng, đã ghi nhận cọc $_dep',
    'Completed': 'Đã thanh toán đủ ($_rem) và đã nghiệm thu',
  };

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  /// THANH TOÁN MÔ PHỎNG: chưa tích hợp cổng thanh toán, nên app mô phỏng việc chuyển tiền. Không trừ tiền thật; mã giao dịch
  /// do app tự sinh (tiền tố SIM-). Backend vẫn ghi nhận khoản thanh toán + ký hợp đồng như thật (cọc 30% hoặc 70% nghiệm thu).
  final _signer30 = TextEditingController(text: 'Chủ Trang Trại');
  final _signer70 = TextEditingController(text: 'Chủ Trang Trại');
  String _method30 = 'BANK_TRANSFER';
  String _method70 = 'BANK_TRANSFER';
  bool _agreed = false;
  String? _signError;
  String? _okMessage;
  ServicePayment? _receipt30;
  ServicePayment? _receipt70;

  @override
  void dispose() {
    _signer30.dispose();
    _signer70.dispose();
    super.dispose();
  }

  Future<void> _sign({required bool deposit}) async {
    final signer = (deposit ? _signer30 : _signer70).text.trim();
    final method = deposit ? _method30 : _method70;
    if (signer.isEmpty) {
      setState(() => _signError = 'Cần nhập họ tên người ký.');
      return;
    }
    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    final reference = 'PAY${deposit ? '30' : '70'}-$stamp';
    setState(() {
      _busy = true;
      _signError = null;
      _okMessage = null;
    });
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
      if (deposit) {
        _receipt30 = payment;
      } else {
        _receipt70 = payment;
      }
      _okMessage = deposit
          ? 'Đã ký hợp đồng và ghi nhận thanh toán tạm ứng $_dep. Kỹ thuật viên có thể vào thực địa lắp đặt.'
          : 'Đã ký nghiệm thu và ghi nhận thanh toán $_rem. Hợp đồng hoàn tất 100%.';
      await _load();
      widget.onChanged?.call();
      if (mounted) await _showReceipt(payment);
    } catch (e) {
      if (mounted) setState(() => _signError = 'Không ghi nhận được: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showReceipt(ServicePayment p) {
    final deposit = p.paymentStage.toUpperCase().contains('30');
    Widget row(String l, String v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              l,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                fontSize: strong ? 15 : 12.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Biên lai Xác nhận Giao dịch Thanh toán',
          style: TextStyle(fontSize: 17),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(
                'Giai đoạn',
                deposit
                    ? 'Tạm ứng $_dep khi ký hợp đồng'
                    : 'Thanh toán $_rem khi nghiệm thu',
              ),
              row('Số tiền', _money(p.amount), strong: true),
              row(
                'Phương thức',
                p.paymentMethod == 'CASH'
                    ? 'Tiền mặt'
                    : p.paymentMethod == 'BANK_TRANSFER'
                    ? 'Chuyển khoản ngân hàng'
                    : p.paymentMethod,
              ),
              row('Mã giao dịch', p.transactionReference ?? '—'),
              row('Người ký', p.signerFullName),
              row(
                'Thời gian',
                DateTime.tryParse(p.paidAtUtc ?? '') == null
                    ? '—'
                    : formatContractDate(DateTime.parse(p.paidAtUtc!)),
              ),
              row('Trạng thái', p.status),
              const SizedBox(height: 6),
              const Text(
                'Giao dịch mô phỏng: chưa tích hợp cổng thanh toán, không trừ tiền thật.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    Color c,
    String title,
    List<Widget> children, {
    String? badge,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge == null)
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: c,
            ),
          )
        else
          _sectionHeader(title, badge, const Color(0xFF64748B)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _paymentForm({
    required TextEditingController signer,
    required String method,
    required ValueChanged<String> onMethod,
    required String transferNote,
    String signerLabel = 'Họ tên người ký',
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: signer,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: signerLabel, isDense: true),
      ),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'BANK_TRANSFER', label: Text('Chuyển khoản')),
          ButtonSegment(value: 'CASH', label: Text('Tiền mặt')),
        ],
        selected: {method},
        onSelectionChanged: (s) => setState(() => onMethod(s.first)),
      ),
      if (method == 'BANK_TRANSFER')
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            'Nội dung chuyển khoản (VietQR): $transferNote\nGiao dịch mô phỏng, không trừ tiền thật.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
    ],
  );

  Widget _errorBox() => _signError == null
      ? const SizedBox.shrink()
      : Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Text(
            _signError!,
            style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
          ),
        );

  Widget _receiptButton(ServicePayment? p) => p == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            onPressed: () => _showReceipt(p),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: const Text('Xem biên lai'),
          ),
        );

  List<String> get _terms => [
    'Điều 1. Phạm vi: nhà thầu cung cấp và lắp đặt thiết bị IoT theo danh mục hợp đồng.',
    'Điều 2. Thanh toán: tạm ứng $_dep khi ký hợp đồng, $_rem còn lại khi nghiệm thu.',
    'Điều 3. Bảo hành theo điều khoản ghi trong hợp đồng.',
    'Điều 4. Hợp đồng có hiệu lực khi Chủ trang trại ký và thanh toán tạm ứng.',
  ];

  /// Tiêu đề từng mục kèm nhãn trạng thái bên phải, như web.
  Widget _sectionHeader(String title, String badge, Color badgeColor) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          badge,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );

  /// Khối "đã hoàn tất" như web: tiêu đề + nhãn khóa, bảng chi tiết giao dịch, nút khóa, dòng thông báo.
  /// Chi tiết giao dịch chỉ có khi vừa ký trong phiên này (backend không có API đọc lại khoản thanh toán), còn lại hiện "—".
  Widget _doneCard({
    required String title,
    required String lockChip,
    required String signerLabel,
    required String amountLabel,
    required double amount,
    required String timeLabel,
    required ServicePayment? receipt,
    required String lockedButton,
    required String footer,
  }) {
    const green = Color(0xFF059669);
    Widget cell(String l, String v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          Text(
            v,
            style: TextStyle(
              fontSize: strong ? 14 : 13,
              fontWeight: FontWeight.w800,
              color: strong ? green : null,
            ),
          ),
        ],
      ),
    );
    final method = receipt == null
        ? '—'
        : receipt.paymentMethod == 'CASH'
        ? 'Tiền mặt'
        : 'Chuyển khoản (VietQR)';
    final when = DateTime.tryParse(receipt?.paidAtUtc ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34D399), width: 1.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: green, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFA7F3D0),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 13, color: Color(0xFF064E3B)),
                    const SizedBox(width: 4),
                    Text(
                      lockChip,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF064E3B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell(signerLabel, receipt?.signerFullName ?? _ownerName ?? '—'),
                cell(amountLabel, _money(amount), strong: true),
                cell('Phương thức thanh toán', method),
                cell(
                  timeLabel,
                  receipt == null
                      ? '—'
                      : '${receipt.transactionReference ?? '—'}${when == null ? '' : ' (${formatContractDate(when)})'}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    lockedButton,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            footer,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF064E3B),
              height: 1.35,
            ),
          ),
          _receiptButton(receipt),
        ],
      ),
    );
  }

  /// Mục 1 như web: ký hợp đồng + thanh toán tạm ứng 30%.
  Widget _ownerDepositSection(Quotation q) {
    final title = '1. Hợp đồng Báo giá Thiết bị & Thanh toán Tạm ứng $_dep';
    final paid = q.status != 'SentToOwner';
    if (paid) {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(title, 'Đã ký & cọc $_dep', const Color(0xFF059669)),
            const SizedBox(height: 8),
            _doneCard(
              title: 'ĐÃ KÝ HỢP ĐỒNG & THANH TOÁN $_dep CỌC THÀNH CÔNG',
              lockChip: 'Đã khóa thao tác',
              signerLabel: 'Đại diện ký:',
              amountLabel: 'Số tiền tạm ứng $_dep:',
              amount: q.deposit30,
              timeLabel: 'Mã GD / Thời gian:',
              receipt: _receipt30,
              lockedButton:
                  'ĐÃ KÝ HỢP ĐỒNG & THANH TOÁN $_dep CỌC (NÚT ĐÃ KHÓA HOÀN TOÀN)',
              footer:
                  'Kỹ thuật viên hiện đã được mở khóa quyền Vào Zone Chấm Node (Node Mapper) trên bản đồ!',
            ),
          ],
        ),
      );
    }
    final amber = const Color(0xFFD97706);
    return _sectionCard(amber, title, [
      Text(
        'SỐ TIỀN TẠM ỨNG $_dep CẦN THANH TOÁN TẠI ĐÂY: ${_money(q.deposit30)}',
        style: TextStyle(fontWeight: FontWeight.w800, color: amber),
      ),
      const SizedBox(height: 8),
      _paymentForm(
        signer: _signer30,
        method: _method30,
        onMethod: (m) => _method30 = m,
        transferNote: 'COC30 #$_shortId',
      ),
      const SizedBox(height: 8),
      for (final t in _terms)
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(t, style: const TextStyle(fontSize: 12.5, height: 1.35)),
        ),
      Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v ?? false),
          title: const Text(
            'Tôi đã đọc và đồng ý với các điều khoản hợp đồng.',
            style: TextStyle(fontSize: 13.5),
          ),
        ),
      ),
      if (!_agreed)
        const Text(
          'Vui lòng tích đồng ý điều khoản để mở khóa nút ký hợp đồng.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
        ),
      _errorBox(),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy || !_agreed ? null : () => _sign(deposit: true),
          child: Text(
            'KÝ HỢP ĐỒNG & THANH TOÁN $_dep CỌC (${_money(q.deposit30)})',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ]);
  }

  String get _shortId => widget.serviceRequestId.length > 8
      ? widget.serviceRequestId.substring(0, 8).toUpperCase()
      : widget.serviceRequestId.toUpperCase();

  /// Mục 2 như web: nghiệm thu + thanh toán 70% còn lại.
  Widget _ownerFinalSection(Quotation q) {
    // Chỉ hiện khi kỹ thuật viên đã bấm "Hoàn tất lắp đặt" (backend: triển khai Completed) hoặc đã nghiệm thu xong.
    if (q.status != 'Completed' && _deploymentStatus != 'Completed') {
      return const SizedBox.shrink();
    }
    final title =
        '2. Biên bản Nghiệm thu Công trình & Thanh toán $_rem còn lại';
    const green = Color(0xFF059669);
    if (q.status == 'Completed') {
      return Container(
        margin: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
              title,
              'Đã Nghiệm thu 100%',
              const Color(0xFF047857),
            ),
            const SizedBox(height: 8),
            _doneCard(
              title: 'ĐÃ KÝ NGHIỆM THU & QUYẾT TOÁN 100% CÔNG TRÌNH',
              lockChip: 'Đã khóa hoàn tất',
              signerLabel: 'Đại diện nghiệm thu:',
              amountLabel: 'Số tiền thanh toán $_rem:',
              amount: q.remaining70,
              timeLabel: 'Mã GD / Thời gian nghiệm thu:',
              receipt: _receipt70,
              lockedButton:
                  'ĐÃ HOÀN TẤT NGHIỆM THU & THANH TOÁN 100% (NÚT ĐÃ KHÓA HOÀN TOÀN)',
              footer:
                  'Đã thanh toán đầy đủ 100% giá trị hợp đồng (${_money(q.totalAmount)}). Thiết bị đã chuyển sang trạng thái Vận hành chính thức!',
            ),
          ],
        ),
      );
    }
    final signed = q.status != 'SentToOwner';
    return _sectionCard(green, title, [
      if (!signed)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Bước này bị khóa. Cần ký Hợp đồng & thanh toán $_dep cọc tại Bước 1 trước khi nghiệm thu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Color(0xFF64748B),
            ),
          ),
        )
      else
        ..._finalForm(q),
    ], badge: signed ? 'Chờ Nghiệm Thu' : 'Khóa Nghiệm thu');
  }

  /// Form nghiệm thu khi đã cọc: tiến độ chấm node, số tiền 70%, người ký, phương thức, cảnh báo triển khai, nút ký.
  List<Widget> _finalForm(Quotation q) {
    final ready = _deploymentStatus == 'Completed';
    const green = Color(0xFF059669);
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF34D399), width: 1.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Tiến độ chấm Node thực địa:',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_nodeCount ?? 'Chưa tải'} Nodes đã chấm trên GIS Map',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Color(0xFF064E3B),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SỐ TIỀN $_rem CÒN LẠI CẦN THANH TOÁN KHI NGHIỆM THU:',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(q.remaining70),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF064E3B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _paymentForm(
              signer: _signer70,
              method: _method70,
              onMethod: (m) => _method70 = m,
              transferNote: 'NT70 #$_shortId',
              signerLabel: 'Họ tên Người ký Biên bản Nghiệm thu *',
            ),
            if (!ready)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tiến độ triển khai hiện tại: ${deploymentStatusLabels[_deploymentStatus ?? ''] ?? 'chưa xác định'}. Biên bản nghiệm thu sẽ mở sau khi Kỹ thuật viên hoàn tất lắp đặt & đo kiểm tra kết nối thiết bị.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF78350F),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _errorBox(),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: green,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                ),
                onPressed: _busy || !ready ? null : () => _sign(deposit: false),
                child: Text(
                  _busy
                      ? 'Đang xác nhận Ký Nghiệm thu & Ghi nhận $_rem...'
                      : 'KÝ BÀN GIAO NGHIỆM THU & THANH TOÁN $_rem CÒN LẠI (${_money(q.remaining70)})',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Khung tóm tắt hợp đồng như web: mã, số thiết bị, tổng, cọc 30% và trạng thái khóa.
  Widget _contractBanner(Quotation q) {
    final signed = q.status != 'SentToOwner';
    final color = signed ? const Color(0xFF059669) : const Color(0xFFD97706);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hợp đồng ${q.id.length > 8 ? q.id.substring(0, 8).toUpperCase() : q.id} (${q.items.length} thiết bị)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Tổng HĐ: ${_money(q.totalAmount)} • Cọc $_dep: ${_money(q.deposit30)}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            signed
                ? 'Owner đã ký và cọc $_dep (khóa sửa)'
                : 'Chờ Owner ký và thanh toán $_dep',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (q.status == 'Completed')
            Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Owner đã ký nghiệm thu và thanh toán $_rem (hoàn tất 100%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createQuotation() async {
    if (!_isTechnician ||
        _busy ||
        (_quotation != null && _quotation!.status != 'SentToOwner'))
      return;
    // Chưa có báo giá: dựng sẵn từ dự toán Owner đã lưu để chỉnh sửa (không bịa dòng nếu Owner chưa lưu dự toán).
    var fromEstimate = const <QuotationItem>[];
    var draftFailed = false;
    if (_quotation == null) {
      setState(() => _busy = true);
      try {
        fromEstimate = await SupportApi.getQuotationEstimateDraft(
          widget.serviceRequestId,
        );
      } catch (e) {
        draftFailed = true;
        if (mounted)
          _snack('Không lấy được dự toán của Owner, bạn có thể nhập tay: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
      if (fromEstimate.isEmpty && !draftFailed) {
        _snack(
          'Owner chưa lưu dự toán thiết bị cho yêu cầu này nên bảng hợp đồng để trống (app không tự tính thay). Thêm hạng mục từ kho hoặc nhập ngoài.',
        );
      } else if (fromEstimate.isNotEmpty) {
        _snack(
          'Đã dựng ${fromEstimate.length} hạng mục từ dự toán của Owner. Chỉnh sửa rồi gửi để Owner xác nhận.',
        );
      }
    }
    final draft = await Navigator.push<QuotationDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationEditor(
          initial: _quotation,
          estimateItems: fromEstimate,
          contractTitle: _contractTitle,
          farmName: widget.farmName,
          zoneName: widget.zoneName,
        ),
      ),
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
      widget.onChanged?.call();
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
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
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
    final signed = q != null && q.status != 'SentToOwner';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 20,
              color: Color(0xFF059669),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Báo giá & hợp đồng lắp đặt',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Cọc $_dep và nghiệm thu $_rem thuộc báo giá lắp đặt thiết bị của yêu cầu này, không liên quan hợp đồng của Zone.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ),
        if (q == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Kỹ thuật viên sẽ khảo sát, trao đổi với Owner và lập danh mục thiết bị cùng báo giá để xác nhận hợp đồng.',
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ),
        if (q != null) _contractBanner(q),
        if (q != null) ...[
          _metaRow(Icons.tag, 'Mã hợp đồng', q.id, selectable: true),
          if (q.createdAtUtc != null)
            _metaRow(
              Icons.event_outlined,
              'Ngày lập',
              formatContractDate(q.createdAtUtc!),
            ),
          _metaRow(
            Icons.flag_outlined,
            'Trạng thái',
            _statusText[q.status] ?? q.status,
            bold: true,
          ),
          const SizedBox(height: 10),
          const Text(
            'Danh mục thiết bị & vật tư',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 6),
          for (final i in q.items) _itemRow(i),
          const SizedBox(height: 6),
          _totalsBox(q),
          if (q.notes?.isNotEmpty == true)
            _noteBox('Trao đổi / bổ sung', q.notes!),
          if (q.contractTerms != null && q.contractTerms!.isNotEmpty)
            _noteBox('Điều khoản', q.contractTerms!),
          if (q.status != 'SentToOwner')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Hợp đồng đã ký: danh mục thiết bị và báo giá không còn chỉnh sửa tại đây.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),
          if (_lastPayment != null && !_isOwner)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã ghi nhận ${_lastPayment!.paymentStage}: ${_money(_lastPayment!.amount)} bởi ${_lastPayment!.signerFullName} (${_lastPayment!.status})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 10),
        if (_isOwner && q != null) ...[
          if (_okMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                _okMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _ownerDepositSection(q),
          _ownerFinalSection(q),
        ],
        if (_isTechnician && (q == null || q.status == 'SentToOwner'))
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _createQuotation,
              icon: const Icon(Icons.edit_document, size: 18),
              label: Text(
                q == null
                    ? 'Soạn báo giá & hợp đồng'
                    : 'Xem / sửa báo giá & hợp đồng',
              ),
            ),
          ),
        if (_isTechnician && signed)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _viewLocked,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Xem hợp đồng (đã khóa)'),
            ),
          ),
      ],
    );
  }

  Widget _metaRow(
    IconData icon,
    String label,
    String value, {
    bool selectable = false,
    bool bold = false,
  }) {
    final style = TextStyle(
      fontSize: 13.5,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
          ),
          Expanded(
            child: selectable
                ? SelectableText(value, style: style)
                : Text(value, style: style),
          ),
        ],
      ),
    );
  }

  /// Một dòng hạng mục: tên đậm + mã, "SL ĐVT × đơn giá" và thành tiền (đã gồm VAT) bên phải.
  Widget _itemRow(QuotationItem i) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${i.code} · ${i.quantity} ${i.unit} × ${_money(i.unitPrice)} · VAT ${i.vatPercent.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                ),
              ),
              if (i.notes?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    i.notes!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _money(i.totalAmount),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF065F46),
          ),
        ),
      ],
    ),
  );

  Widget _totalsBox(Quotation q) {
    Widget row(String l, String v, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              l,
              style: TextStyle(
                fontSize: strong ? 14 : 12.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            v,
            style: TextStyle(
              fontSize: strong ? 15 : 12.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    Widget pay(String l, double v, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l, style: TextStyle(fontSize: 12, color: c)),
            const SizedBox(height: 3),
            Text(
              _money(v),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          row('Tiền hàng trước thuế', _money(q.subtotal)),
          row('Thuế VAT', _money(q.vatAmount)),
          const Divider(height: 14),
          row('Tổng giá trị hợp đồng', _money(q.totalAmount), strong: true),
          const SizedBox(height: 8),
          Row(
            children: [
              pay('Cọc $_dep khi ký', q.deposit30, const Color(0xFFD97706)),
              const SizedBox(width: 8),
              pay(
                'Còn lại $_rem khi nghiệm thu',
                q.remaining70,
                const Color(0xFF0284C7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noteBox(String title, String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 3),
        Text(text, style: const TextStyle(fontSize: 13.5, height: 1.35)),
      ],
    ),
  );
}
