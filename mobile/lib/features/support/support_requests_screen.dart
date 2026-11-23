import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'payos_service_request_sheet.dart';
import 'quotation_editor.dart';
import 'acceptance_report.dart';
import 'acceptance_report_flow.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';
import '../../core/utils/paging.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/state_views.dart';
import 'service_board_logic.dart';
import '../../core/utils/user_error.dart';
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
      if (mounted) setState(() => _error = userFacingError(e));
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
    var isUploadingImage = false;
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
                    for (final (i, d)
                        in deployments.where((d) => d.zoneId == zoneId).indexed)
                      DropdownMenuItem<String?>(
                        value: d.requestId,
                        child: Text(
                          'Yêu cầu lắp đặt IoT ${i + 1} · ${deploymentStatusLabels[d.status] ?? d.status}',
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                    ),
                    onPressed: isUploadingImage
                        ? null
                        : () async {
                            final picked = await FilePicker.pickFile(
                              type: FileType.custom,
                              allowedExtensions: const [
                                'jpg',
                                'jpeg',
                                'png',
                                'webp',
                              ],
                            );
                            if (picked == null) return;
                            final bytes = await picked.readAsBytes();
                            if (bytes.isEmpty) return;
                            setLocal(() => isUploadingImage = true);
                            try {
                              final upload = await MediaApi.uploadFile(
                                bytes: bytes,
                                fileName: picked.name,
                                folder: 'service_requests',
                              );
                              if (upload.secureUrl.isNotEmpty) {
                                final current = description.text.trim();
                                description.text = current.isEmpty
                                    ? 'Ảnh hiện trường: ${upload.secureUrl}'
                                    : '$current\n\nẢnh hiện trường: ${upload.secureUrl}';
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tải ảnh thất bại: ${userFacingError(e)}',
                                    ),
                                  ),
                                );
                              }
                            } finally {
                              setLocal(() => isUploadingImage = false);
                            }
                          },
                    icon: isUploadingImage
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_photo_alternate_outlined, size: 16),
                    label: Text(
                      isUploadingImage
                          ? 'Đang tải ảnh...'
                          : 'Đính kèm ảnh hiện trường (Cloudinary)',
                      style: const TextStyle(fontSize: 12),
                    ),
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
    // Không dispose controller ở đây: hộp thoại đã pop nhưng hiệu ứng đóng vẫn dựng lại ô nhập; dispose sớm gây lỗi
    // "Assertion failed ... _dependents.isEmpty" (màn đỏ). Controller nhỏ, tự được thu gom.
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
      // Lắp đặt / bổ sung thiết bị mà KHÔNG liên kết một yêu cầu triển khai có sẵn: tạo YÊU CẦU TRIỂN KHAI MỚI cho Zone (đi đủ luồng
      // khảo sát → báo giá → ký cọc → gắn Node). Không tạo phiếu rời: backend sẽ gắn phiếu vào đợt cũ đã hoàn tất và đánh dấu thiết bị
      // đang chạy là cần bảo trì, rồi không gắn Node được vì đợt cũ không còn ở trạng thái đang lắp đặt.
      if (type == 'INSTALLATION' && deploymentId == null) {
        final running = deployments.where(
          (d) => d.zoneId == zoneId && deploymentRequestIsRunning(d.status),
        );
        if (running.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Zone này đang có một yêu cầu lắp đặt chưa hoàn tất. Chờ kỹ thuật viên hoàn tất lắp đặt rồi mới yêu cầu mua thêm thiết bị.',
              ),
            ),
          );
          return;
        }
        // Hợp đồng dịch vụ của Zone phải còn hạn (Zone chưa có hợp đồng nào thì là lần lắp đầu, không chặn).
        // Không tải được danh sách hợp đồng thì không chặn: backend vẫn là nơi quyết định yêu cầu có hợp lệ không.
        try {
          final contracts = await ContractApi.getZoneContracts(zoneId: zoneId);
          final blocked = zoneContractBlockReason(contracts, DateTime.now());
          if (blocked != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(blocked)));
            return;
          }
        } catch (_) {}
        await DeploymentApi.submitDeploymentRequestWithEstimate(
          zoneId,
          notes: text,
        );
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã gửi yêu cầu lắp đặt mới. Kỹ thuật viên sẽ khảo sát và lập báo giá.',
              ),
            ),
          );
        }
        return;
      }
      // Bảo trì chỉ nhận khi hợp đồng dịch vụ của Zone còn hạn (backend cũng kiểm tra; đây là báo sớm trước khi gửi).
      if (type == 'MAINTENANCE') {
        try {
          final contracts = await ContractApi.getZoneContracts(zoneId: zoneId);
          final blocked = zoneContractBlockReason(
            contracts,
            DateTime.now(),
            action: 'gửi yêu cầu bảo trì',
          );
          if (blocked != null) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(blocked)));
            return;
          }
        } catch (_) {}
      }
      final farmId = zones.firstWhere((z) => z.zoneId == zoneId).farmId;
      // Bảo trì: Zone có nhiều thiết bị thì phải chọn thiết bị cần bảo trì (backend không đoán thiết bị nữa).
      String? deviceId;
      if (type == 'MAINTENANCE') {
        List<Map<String, dynamic>> zoneDevices = const [];
        try {
          zoneDevices = await SupportApi.listZoneDevices(zoneId);
        } catch (_) {}
        if (zoneDevices.length > 1) {
          if (!mounted) return;
          deviceId = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Chọn thiết bị cần bảo trì'),
              children: [
                for (final d in zoneDevices)
                  SimpleDialogOption(
                    key: ValueKey('maint-device-${d['deviceId']}'),
                    onPressed: () => Navigator.pop(ctx, '${d['deviceId']}'),
                    child: Text(
                      '${d['hardwareAddress']} · ${d['deviceType']} · ${d['status']}',
                    ),
                  ),
              ],
            ),
          );
          if (deviceId == null) return;
        }
      }
      await SupportApi.createServiceRequest(
        farmId: farmId,
        zoneId: zoneId,
        failureCode: type == 'INSTALLATION' ? 'NEW_INSTALL' : code,
        description: text,
        deploymentRequestId: deploymentId,
        deviceId: deviceId,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tạo yêu cầu thất bại: ${userFacingError(e)}'),
          ),
        );
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
                    padding: const EdgeInsets.only(top: 48),
                    child: AppEmptyState(
                      icon: Icons.support_agent_outlined,
                      message: widget.zone == null
                          ? 'Chưa có yêu cầu hỗ trợ nào.\nGửi yêu cầu để kỹ thuật viên lắp đặt hoặc bảo trì thiết bị.'
                          : 'Zone này chưa có yêu cầu hỗ trợ nào.\nGửi yêu cầu để kỹ thuật viên lắp đặt hoặc bảo trì thiết bị.',
                      actionLabel: 'Gửi yêu cầu hỗ trợ',
                      onAction: _create,
                    ),
                  ),
                ],
              )
            : PagedList<Map<String, dynamic>>(
                padding: const EdgeInsets.all(12),
                items: sortNewestFirst(_requests, (r) {
                  final own = parseTime(r['createdAtUtc']);
                  if (own != null) return own;
                  final h = r['history'];
                  return h is List && h.isNotEmpty && h.first is Map
                      ? parseTime((h.first as Map)['createdAtUtc'])
                      : null;
                }),
                itemGap: 8,
                itemBuilder: (context, r) {
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
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          title: const Text(
            'Hợp đồng & thanh toán',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
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
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: color,
      ),
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
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
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
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(
                      install ? 'Lắp đặt thiết bị mới' : 'Bảo trì / sửa chữa',
                      install
                          ? const Color(0xFF0369A1)
                          : const Color(0xFFD97706),
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
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                if (desc.isNotEmpty && desc != title && desc != '$title.')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                if (q != null && _info.known)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Tổng HĐ: ${formatMoney(q.totalAmount)} · Cọc ${q.depositLabel}: ${formatMoney(q.deposit30)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
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
  AcceptanceReport?
  _report; // biên bản nghiệm thu KTV lập (Owner xem trước khi ký)
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

  /// Tiêu đề hợp đồng: kèm tên Zone/nông trại (không hiện mã nội bộ của phiếu).
  String get _contractTitle {
    final where = [
      if ((widget.zoneName ?? '').trim().isNotEmpty) widget.zoneName!.trim(),
      if ((widget.farmName ?? '').trim().isNotEmpty) widget.farmName!.trim(),
    ].join(' · ');
    return where.isEmpty
        ? 'Hợp đồng lắp đặt IoT'
        : 'Hợp đồng lắp đặt IoT · $where';
  }

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
      // Không chặn việc tải báo giá: nhãn tỷ lệ lấy từ chính báo giá, tham số chung chỉ là dự phòng (có khoảng nghỉ 1 phút).
      unawaited(BusinessParametersStore.refresh());
      final q = await SupportApi.getQuotation(widget.serviceRequestId);
      String? depStatus;
      String ktvNote = '';
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
            ktvNote =
                deployment.history
                    .where((h) => h.decisionType == 'DeploymentCompleted')
                    .map((h) => h.notes ?? '')
                    .lastOrNull ??
                '';
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
      AcceptanceReport? report;
      if (_isOwner && (depStatus == 'Completed' || q?.status == 'Completed')) {
        report = await _loadReport(ktvNote);
      }
      if (mounted) {
        setState(() {
          _report = report;
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
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Biên bản nghiệm thu cho Owner: Zone/farm/field + Node đã gắn (kèm vị trí, kết nối) + ghi chú KTV. Lỗi tải → null.
  Future<AcceptanceReport?> _loadReport(String note) async {
    try {
      final service = await SupportApi.getServiceRequest(
        widget.serviceRequestId,
      );
      return await loadAcceptanceReport(
        farmId: widget.zone?.farmId ?? '${service['farmId'] ?? ''}',
        zoneId: widget.zone?.zoneId ?? '${service['zoneId'] ?? ''}',
        zone: widget.zone,
        note: note,
      );
    } catch (_) {
      return null;
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

  /// Thanh toán trực tuyến VietQR qua cổng PayOS (tự động 24/7) hoặc Chuyển khoản / Tiền mặt.
  final _signer30 = TextEditingController(text: 'Chủ Trang Trại');
  final _signer70 = TextEditingController(text: 'Chủ Trang Trại');
  String _method30 = 'BANK_TRANSFER';
  String _method70 = 'BANK_TRANSFER';
  bool _agreed = false;

  /// Owner đã xem biên bản và BẤM XÁC NHẬN NGHIỆM THU (bước của app trước khi mở thanh toán phần còn lại; backend ký nghiệm thu và
  /// thanh toán trong một lệnh). Nhớ theo yêu cầu trong phiên làm việc.
  static final Set<String> _acceptanceConfirmedIds = {};
  bool get _acceptanceConfirmed =>
      _acceptanceConfirmedIds.contains(widget.serviceRequestId);
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

  /// Mở giao diện thanh toán thật PayOS (VietQR) cho Luồng 1.
  Future<void> _openPayOSPayment({required bool deposit}) async {
    if (!deposit && !_acceptanceConfirmed) {
      setState(
        () => _signError =
            'Hãy xem biên bản và bấm "Xác nhận nghiệm thu" trước khi thanh toán.',
      );
      return;
    }
    if (_quotation == null) return;

    final signer = (deposit ? _signer30 : _signer70).text.trim();
    final amount = deposit ? _quotation!.deposit30 : _quotation!.remaining70;
    final stage = deposit ? 'DEPOSIT_30' : 'FINAL_70';
    final stageTitle = deposit
        ? 'Tạm ứng cọc $_dep khi ký Hợp đồng'
        : 'Quyết toán $_rem khi Nghiệm thu';

    setState(() {
      _signError = null;
      _okMessage = null;
    });

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PayOSServiceRequestSheet(
        serviceRequestId: widget.serviceRequestId,
        stage: stage,
        stageTitle: stageTitle,
        amount: amount,
        initialSignerName:
            signer.isEmpty ? (_ownerName ?? 'Chủ Trang Trại') : signer,
        onPaymentSuccess: (ref, method, signerName) async {
          final payment = deposit
              ? await SupportApi.signContractAndPayDeposit(
                  widget.serviceRequestId,
                  signerFullName: signerName,
                  paymentMethod: method,
                  transactionReference: ref,
                  expectedDepositAmount: _quotation?.deposit30,
                )
              : await SupportApi.signAcceptanceAndPayFinal(
                  widget.serviceRequestId,
                  signerFullName: signerName,
                  paymentMethod: method,
                  transactionReference: ref,
                );
          _lastPayment = payment;
          if (deposit) {
            _receipt30 = payment;
          } else {
            _receipt70 = payment;
          }
          _okMessage = deposit
              ? 'Đã thanh toán cọc $_dep thành công qua PayOS (VietQR). Kỹ thuật viên có thể vào thực địa lắp đặt.'
              : 'Đã thanh toán $_rem thành công qua PayOS (VietQR). Hợp đồng hoàn tất 100%.';
          await _load();
          widget.onChanged?.call();
        },
      ),
    );
    if (result == true && _lastPayment != null && mounted) {
      await _showReceipt(_lastPayment!);
    }
  }

  Future<void> _sign({required bool deposit}) async {
    if (!deposit && !_acceptanceConfirmed) {
      setState(
        () => _signError =
            'Hãy xem biên bản và bấm "Xác nhận nghiệm thu" trước khi thanh toán.',
      );
      return;
    }
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
              expectedDepositAmount: _quotation?.deposit30,
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
      if (mounted)
        setState(
          () => _signError = 'Không ghi nhận được: ${userFacingError(e)}',
        );
      // Có thể do Admin vừa đổi tỷ lệ cọc (409): tải lại báo giá để Owner thấy số tiền mới trước khi ký lại.
      if (mounted && deposit) await _load();
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
                    : (p.paymentMethod.toUpperCase().contains('PAYOS') ||
                            p.paymentMethod.toUpperCase().contains('VIETQR'))
                    ? 'PayOS (VietQR Napas 24/7)'
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Color(0xFF047857),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thanh toán đã được xác thực thành công qua cổng thanh toán.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
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
          ButtonSegment(
            value: 'PAYOS',
            label: Text('VietQR (PayOS)'),
            icon: Icon(Icons.qr_code_2_rounded, size: 16),
          ),
          ButtonSegment(value: 'BANK_TRANSFER', label: Text('Chuyển khoản')),
          ButtonSegment(value: 'CASH', label: Text('Tiền mặt')),
        ],
        selected: {method},
        onSelectionChanged: (s) => setState(() => onMethod(s.first)),
      ),
      if (method == 'PAYOS')
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cổng thanh toán tự động VietQR Napas 24/7 (PayOS). Quét mã chuyển khoản tức thì qua mọi App ngân hàng, hệ thống xác thực tự động.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF065F46),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        )
      else if (method == 'BANK_TRANSFER')
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Text(
            'Thanh toán bằng chuyển khoản (VietQR) ngân hàng trực tiếp tới tài khoản SmartFarm.',
            style: TextStyle(fontSize: 13, height: 1.4),
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
    const green = Color(0xFF047857);
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
        : (receipt.paymentMethod.toUpperCase().contains('PAYOS') ||
                receipt.paymentMethod.toUpperCase().contains('VIETQR'))
            ? 'VietQR Napas 24/7 (PayOS)'
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
            _sectionHeader(title, 'Đã ký & cọc $_dep', const Color(0xFF047857)),
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
                  'Hợp đồng & cọc đã hoàn tất. Kỹ thuật viên sẽ thực hiện Gán Node vào Zone trên Web Dashboard (thao tác bản đồ GIS được xử lý trên máy tính để đảm bảo độ chính xác).',
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
      if (_method30 == 'PAYOS')
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed:
                _busy || !_agreed ? null : () => _openPayOSPayment(deposit: true),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: Text(
              'THANH TOÁN CỌC $_dep QUA PAYOS (${_money(q.deposit30)})',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        )
      else
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

  /// Mục 2 như web: nghiệm thu + thanh toán 70% còn lại.
  Widget _ownerFinalSection(Quotation q) {
    // Chỉ hiện khi kỹ thuật viên đã bấm "Hoàn tất lắp đặt" (backend: triển khai Completed) hoặc đã nghiệm thu xong.
    if (q.status != 'Completed' && _deploymentStatus != 'Completed') {
      return const SizedBox.shrink();
    }
    final title =
        '2. Biên bản Nghiệm thu Công trình & Thanh toán $_rem còn lại';
    const green = Color(0xFF047857);
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
            if (_report != null) ...[
              AcceptanceReportView(report: _report!),
              const SizedBox(height: 8),
            ],
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
      if (signed && _report != null) ...[
        AcceptanceReportView(report: _report!),
        const SizedBox(height: 8),
      ],
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

  /// Bước "Xác nhận nghiệm thu": Owner xem biên bản KTV lập (Node, vị trí, kết nối, ghi chú) rồi xác nhận; sau đó mới mở thanh toán phần còn lại.
  Widget _acceptanceConfirmCard() => Container(
    key: const ValueKey('acceptance-confirm-card'),
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFA7F3D0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'XÁC NHẬN NGHIỆM THU',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          'Kỹ thuật viên đã hoàn tất lắp đặt. Hãy xem Biên bản nghiệm thu phía trên (Node, vị trí, kết nối, ghi chú) rồi xác nhận nghiệm thu. Sau khi xác nhận mới mở bước thanh toán $_rem còn lại.',
          style: const TextStyle(fontSize: 12.5, height: 1.4),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('confirm-acceptance'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
            ),
            onPressed: _busy
                ? null
                : () => setState(() {
                    _acceptanceConfirmedIds.add(widget.serviceRequestId);
                    _signError = null;
                  }),
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('XÁC NHẬN NGHIỆM THU'),
          ),
        ),
      ],
    ),
  );

  /// Form nghiệm thu khi đã cọc: tiến độ chấm node, số tiền 70%, người ký, phương thức, cảnh báo triển khai, nút ký.
  List<Widget> _finalForm(Quotation q) {
    final ready = _deploymentStatus == 'Completed';
    const green = Color(0xFF047857);
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
                    '${_nodeCount ?? 'Chưa tải'} Nodes đã chấm trên GIS Map (thực hiện trên Web)',
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
            if (ready && !_acceptanceConfirmed) _acceptanceConfirmCard(),
            if (!ready || _acceptanceConfirmed)
              _paymentForm(
                signer: _signer70,
                method: _method70,
                onMethod: (m) => _method70 = m,
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
            if (!ready || _acceptanceConfirmed)
              if (_method70 == 'PAYOS')
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                    ),
                    onPressed:
                        _busy || !ready ? null : () => _openPayOSPayment(deposit: false),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: Text(
                      'THANH TOÁN $_rem QUA PAYOS (${_money(q.remaining70)})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      disabledBackgroundColor: const Color(0xFFCBD5E1),
                    ),
                    onPressed:
                        _busy || !ready ? null : () => _sign(deposit: false),
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
          _snack(
            'Không lấy được dự toán của Owner, bạn có thể nhập tay: ${userFacingError(e)}',
          );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
      if (fromEstimate.isEmpty && !draftFailed) {
        _snack(
          'Owner chưa lưu dự toán thiết bị cho yêu cầu này nên bảng hợp đồng để trống (app không tự tính thay). Thêm thiết bị từ kho.',
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
      // Gửi hợp đồng cũng là xác nhận kế hoạch: tự đưa triển khai gắn với phiếu tới "Đã xác nhận kế hoạch".
      final depId = widget.deploymentRequestId;
      if (_isTechnician && depId != null && depId.isNotEmpty) {
        try {
          await DeploymentApi.autoConfirmPlan(depId);
        } catch (e) {
          if (mounted) {
            _snack(
              'Đã gửi hợp đồng nhưng chưa tự xác nhận được kế hoạch: ${userFacingError(e)}',
            );
          }
        }
      }
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) _snack('Không lập được báo giá: ${userFacingError(e)}');
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
        if (q == null) ...[
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 20,
                color: Color(0xFF047857),
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
        ],
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
        if (q != null) ...[
          _contractPanel(q),
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
                    color: Color(0xFF047857),
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

  /// Khối hợp đồng báo giá cùng bố cục web (SupportPage): tiêu đề + nhãn, bảng hạng mục, tổng và số tiền tạm ứng.
  Widget _contractPanel(Quotation q) {
    final signed = q.status != 'SentToOwner';
    // Owner đã có tiêu đề "1. …" và số tiền cọc ở khối ký bên dưới nên không lặp lại.
    final ownerUnsigned = _isOwner && !signed;
    final vatPct = q.subtotal > 0
        ? (q.vatAmount / q.subtotal * 100).round()
        : (q.items.isNotEmpty ? q.items.first.vatPercent.round() : 0);
    const head = Color(0xFF451A03);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isOwner) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Color(0xFFB45309),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '1. HỢP ĐỒNG BÁO GIÁ THIẾT BỊ & THANH TOÁN TẠM ỨNG $_dep',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: head,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: signed
                    ? const Color(0xFF047857)
                    : const Color(0xFFFDE68A),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                signed
                    ? '✓ Đã Ký & Thanh toán $_dep'
                    : 'Cần Owner Ký tên & Cọc $_dep',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: signed ? Colors.white : head,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          SelectableText(
            '${q.createdAtUtc != null ? 'Ngày lập: ${formatContractDate(q.createdAtUtc!)} • ' : ''}'
            'Trạng thái: ${_statusText[q.status] ?? q.status}',
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _contractTable(q),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tổng cộng (gồm VAT $vatPct%):',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Text(
                      _money(q.totalAmount),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (!ownerUnsigned) ...[
                  const Divider(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'SỐ TIỀN TẠM ỨNG $_dep ${signed ? 'ĐÃ THANH TOÁN' : 'CẦN THANH TOÁN TẠI ĐÂY'}:',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _money(q.deposit30),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ],
                if (q.remaining70 > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Còn lại $_rem khi nghiệm thu:',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      Text(
                        _money(q.remaining70),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bảng hạng mục của hợp đồng. Luôn vừa chiều ngang màn hình (không cuộn ngang): màn rộng đủ 7 cột như web,
  /// màn hẹp gộp "Mã hàng" thành dòng nhỏ dưới tên để các cột số còn đủ chỗ.
  Widget _contractTable(Quotation q) {
    const head = Color(0xFF451A03);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) return _compactItems(q);
        Widget cell(
          String t,
          int flex, {
          TextAlign align = TextAlign.left,
          FontWeight weight = FontWeight.w500,
          Color color = const Color(0xFF334155),
          String? top,
          String? sub,
        }) => Expanded(
          flex: flex,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: align == TextAlign.right
                  ? CrossAxisAlignment.end
                  : (align == TextAlign.center
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start),
              children: [
                if (top != null && top.isNotEmpty)
                  Text(
                    top,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                Text(
                  t,
                  textAlign: align,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: weight,
                    color: color,
                  ),
                ),
                if (sub != null && sub.isNotEmpty)
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        );

        // Tỉ lệ cột: [mã, tên, ĐVT, đơn giá, VAT, SL, thành tiền].
        const f = [14, 30, 8, 15, 7, 6, 17];
        Widget headRow() => Container(
          color: const Color(0xFFFEF3C7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell('Mã hàng', f[0], weight: FontWeight.w800, color: head),
              cell(
                'Tên sản phẩm / Thiết bị',
                f[1],
                weight: FontWeight.w800,
                color: head,
              ),
              cell(
                'ĐVT',
                f[2],
                align: TextAlign.center,
                weight: FontWeight.w800,
                color: head,
              ),
              cell(
                'Đơn giá (đ)',
                f[3],
                align: TextAlign.right,
                weight: FontWeight.w800,
                color: head,
              ),
              cell(
                'VAT',
                f[4],
                align: TextAlign.center,
                weight: FontWeight.w800,
                color: head,
              ),
              cell(
                'SL',
                f[5],
                align: TextAlign.center,
                weight: FontWeight.w800,
                color: head,
              ),
              cell(
                'Thành tiền (đ)',
                f[6],
                align: TextAlign.right,
                weight: FontWeight.w800,
                color: head,
              ),
            ],
          ),
        );
        Widget itemRow(QuotationItem i) => Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cell(
                i.code,
                f[0],
                weight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
              cell(
                i.name,
                f[1],
                weight: FontWeight.w600,
                color: const Color(0xFF1E293B),
                sub: i.notes,
              ),
              cell(
                i.unit,
                f[2],
                align: TextAlign.center,
                color: const Color(0xFF475569),
              ),
              cell(_money(i.unitPrice), f[3], align: TextAlign.right),
              cell(
                '${i.vatPercent.toStringAsFixed(0)}%',
                f[4],
                align: TextAlign.center,
                color: const Color(0xFF64748B),
              ),
              cell(
                '${i.quantity}',
                f[5],
                align: TextAlign.center,
                weight: FontWeight.w800,
              ),
              cell(
                _money(i.totalAmount),
                f[6],
                align: TextAlign.right,
                weight: FontWeight.w800,
                color: const Color(0xFF064E3B),
              ),
            ],
          ),
        );
        return Column(
          children: [headRow(), for (final i in q.items) itemRow(i)],
        );
      },
    );
  }

  /// Màn hẹp (điện thoại): mỗi hạng mục hai dòng, không chia cột nên số tiền không bị bẻ dòng.
  /// Dòng 1: tên + thành tiền; dòng 2: mã · ĐVT · SL × đơn giá · VAT; dòng 3: ghi chú.
  Widget _compactItems(Quotation q) {
    const head = Color(0xFF451A03);
    Widget headRow() => Container(
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Sản phẩm / Thiết bị',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: head,
              ),
            ),
          ),
          Text(
            'Thành tiền',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: head,
            ),
          ),
        ],
      ),
    );
    Widget itemRow(QuotationItem i) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  i.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _money(i.totalAmount),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF064E3B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${i.code} · ${i.quantity} ${i.unit} × ${_money(i.unitPrice)} · VAT ${i.vatPercent.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          if (i.notes?.isNotEmpty == true)
            Text(
              i.notes!,
              style: const TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );
    return Column(children: [headRow(), for (final i in q.items) itemRow(i)]);
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
