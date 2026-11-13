import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/state_views.dart';
import '../farms/farm_setup_logic.dart';
import '../zones/honeycomb_estimate.dart';
import '../zones/widgets/zone_honeycomb_estimate_card.dart';
import 'deployment_screens.dart';

/// Owner xem THÔNG TIN ZONE và NỘI DUNG YÊU CẦU (thông số cần đo, thiết bị đề xuất & dự toán, ghi chú) rồi bấm
/// "Xác nhận gửi yêu cầu". Gửi qua POST /zones/{id}/deployment-requests/submit: yêu cầu ở trạng thái Submitted ngay;
/// thông số cần đo do máy chủ lấy từ vụ đang canh tác, đơn giá dự toán do máy chủ lấy từ kho.
class DeploymentRequestSendScreen extends StatefulWidget {
  final String zoneId;
  const DeploymentRequestSendScreen({super.key, required this.zoneId});

  @override
  State<DeploymentRequestSendScreen> createState() =>
      _DeploymentRequestSendScreenState();
}

class _DeploymentRequestSendScreenState
    extends State<DeploymentRequestSendScreen> {
  static const _activeStatuses = {
    'Submitted',
    'Accepted',
    'Surveyed',
    'PlanConfirmed',
    'Installing',
  };

  final _notes = TextEditingController();
  IotRequirements? _req;
  List<DeploymentRequest> _zoneRequests = [];
  HoneycombEstimate? _estimate;
  bool _loading = true;
  bool _submitting = false;
  bool _needsSeason = false;
  String? _loadError;
  int _loadSeq = 0; // chỉ kết quả của lần tải mới nhất được áp dụng

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  ZoneModel? _zone(FarmProvider p) =>
      p.allZones.where((z) => z.zoneId == widget.zoneId).firstOrNull;

  DeploymentRequest? get _activeRequest => _zoneRequests
      .where((r) => _activeStatuses.contains(r.status))
      .firstOrNull;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final results = await Future.wait<Object?>([
      DeploymentApi.getIotRequirements(
        widget.zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
      DeploymentApi.getOwnerDeploymentRequests(
        zoneId: widget.zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
    ]);
    if (!mounted || seq != _loadSeq) return;
    final req = results[0];
    final requests = results[1];
    setState(() {
      _loading = false;
      _needsSeason = false;
      _req = null;
      if (requests is List<DeploymentRequest>) {
        _zoneRequests = requests;
      } else {
        _loadError = friendlyError(
          requests ?? 'Không tải được yêu cầu của Zone.',
        );
      }
      if (req is IotRequirements) {
        _req = req;
      } else if (req is Object) {
        final msg = req.toString().toLowerCase();
        if (msg.contains('no inprogress planting season') ||
            msg.contains('no in-progress planting season')) {
          _needsSeason = true;
        } else {
          _loadError ??= friendlyError(req);
        }
      }
    });
  }

  String _friendlySendError(Object e) {
    final m = friendlyError(e);
    if (m.toLowerCase().contains('non-terminal')) {
      return 'Zone này đã có một yêu cầu triển khai đang xử lý nên không gửi thêm được. Hãy mở yêu cầu đó để theo dõi.';
    }
    return m;
  }

  Future<void> _send(ZoneModel zone, WizardEstimateDraft draft) async {
    if (_submitting) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận gửi yêu cầu?'),
        content: Text(
          'Gửi yêu cầu triển khai IoT cho Zone "${zone.name}" (${zone.farmName}) tới kỹ thuật viên.\n\n'
          '• Thông số cần đo: ${(_req?.parameters ?? const []).map(measurementLabel).join(', ')}\n'
          '• ${draft.hasItems ? 'Dự toán đi kèm: ${draft.items.length} hạng mục' : 'Không kèm dự toán thiết bị'}\n\n'
          'Sau khi gửi, kỹ thuật viên sẽ khảo sát và lập kế hoạch/báo giá để bạn xem và xác nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Xem lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted || _submitting) return;
    setState(() => _submitting = true);
    try {
      final created = await DeploymentApi.submitDeploymentRequestWithEstimate(
        widget.zoneId,
        notes: _notes.text,
        estimateItems: draft.items,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DeploymentRequestDetailScreen(
            requestId: created.requestId,
            technician: false,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, _friendlySendError(e), error: true);
      // Có thể máy chủ đã tạo xong nhưng phản hồi bị mất: tải lại để thấy yêu cầu (nội dung đã nhập được giữ nguyên).
      await _load();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _section(String title, Widget child, {IconData? icon}) =>
      SectionCard(title: title, icon: icon, child: child);

  Widget _row(IconData icon, String label, String value) =>
      KeyValueRow(icon, label, value);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final zone = _zone(provider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Gửi yêu cầu triển khai IoT',
          style: TextStyle(fontSize: 15),
        ),
      ),
      body: zone == null
          ? const AppEmptyState(
              icon: Icons.location_off_outlined,
              message:
                  'Không tìm thấy Zone này. Hãy quay lại, kéo để làm mới danh sách Zone rồi thử lại.',
            )
          : _loading
          ? const AppLoading(message: 'Đang tải thông tin Zone và nhu cầu đo…')
          : _body(zone),
    );
  }

  Widget _body(ZoneModel zone) {
    final active = _activeRequest;
    final perimeter = zone.polygon == null
        ? null
        : convexHullPerimeterM([
            for (final p in zone.polygon!) (lat: p.latitude, lng: p.longitude),
          ]);
    final draft = buildWizardEstimateItems(_estimate);
    final params = _req?.parameters ?? const <String>[];
    final canSend =
        !_submitting &&
        active == null &&
        _req != null &&
        params.isNotEmpty &&
        _loadError == null;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  '1. Thông tin Zone',
                  Column(
                    children: [
                      _row(Icons.agriculture, 'Trang trại', zone.farmName),
                      _row(Icons.layers_outlined, 'Thửa đất', zone.fieldName),
                      _row(
                        Icons.home_work_outlined,
                        'Zone',
                        '${zone.name} · ${zone.areaM2.toStringAsFixed(0)} m²',
                      ),
                      if (zone.currentCrop.isNotEmpty)
                        _row(Icons.eco_outlined, 'Cây trồng', zone.currentCrop),
                      if (zone.growthProfileName != null)
                        _row(Icons.timeline, 'Hồ sơ', zone.growthProfileName!),
                      _row(
                        Icons.map_outlined,
                        'Ranh giới',
                        zone.polygon == null || zone.polygon!.length < 3
                            ? 'Chưa vẽ ranh giới GIS (dự toán dùng hình chữ nhật 1:2)'
                            : '${zone.polygon!.length} đỉnh · chu vi ~${(perimeter ?? 0).toStringAsFixed(0)} m',
                      ),
                    ],
                  ),
                ),
                if (_loadError != null)
                  _section(
                    'Không tải được dữ liệu',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                if (_needsSeason)
                  _section(
                    'Chưa thể gửi yêu cầu',
                    const Text(
                      'Zone này chưa có vụ trồng đang canh tác (InProgress) nên chưa xác định được nhu cầu đo. '
                      'Hãy tạo hoặc kích hoạt vụ trồng cho Zone rồi quay lại.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (active != null)
                  _section(
                    'Zone đã có yêu cầu đang xử lý',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trạng thái: ${deploymentStatusLabels[active.status] ?? active.status}. Mỗi Zone chỉ có một yêu cầu đang chạy.',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 6),
                        FilledButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeploymentRequestDetailScreen(
                                requestId: active.requestId,
                                technician: false,
                              ),
                            ),
                          ),
                          child: const Text('Mở yêu cầu đang xử lý'),
                        ),
                      ],
                    ),
                  ),
                if (_req != null) ...[
                  _section(
                    '2. Nội dung yêu cầu sẽ gửi',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông số cần đo (từ vụ đang canh tác, giai đoạn hiện tại)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (params.isEmpty)
                          const Text(
                            'Vụ trồng chưa có thông số môi trường áp dụng nên chưa gửi được yêu cầu.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final p in params)
                                ParamPill(measurementLabel(p)),
                            ],
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notes,
                          maxLength: 1000,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Ghi chú cho kỹ thuật viên (không bắt buộc)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ZoneHoneycombEstimateCard(
                    key: ValueKey('est-${widget.zoneId}'),
                    zoneId: widget.zoneId,
                    areaM2: zone.areaM2,
                    cropName: zone.currentCrop,
                    perimeterM: perimeter,
                    measurementParameters: params,
                    measurementSource:
                        'Thông số đo của vụ đang canh tác trong Zone',
                    onEstimate: (e) {
                      if (mounted) setState(() => _estimate = e);
                    },
                  ),
                  _section(
                    '3. Tóm tắt trước khi gửi',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(
                          Icons.sensors,
                          'Cần đo',
                          params.isEmpty
                              ? '—'
                              : params.map(measurementLabel).join(', '),
                        ),
                        _row(
                          Icons.calculate_outlined,
                          'Dự toán',
                          draft.hasItems
                              ? 'Lưu kèm yêu cầu: ${draft.items.length} hạng mục'
                              : (_estimate == null
                                    ? 'Đang tính hoặc chưa có dự toán'
                                    : 'Không kèm dự toán: ${draft.skippedReason ?? 'Zone không cần bổ sung thiết bị.'}'),
                        ),
                        _row(
                          Icons.edit_note,
                          'Ghi chú',
                          _notes.text.trim().isEmpty
                              ? '(không có)'
                              : _notes.text.trim(),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Đây chưa phải báo giá hay hợp đồng: kỹ thuật viên khảo sát, chỉnh sửa rồi lập báo giá/hợp đồng để bạn xem và xác nhận.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSend ? () => _send(zone, draft) : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Đang gửi…' : 'Xác nhận gửi yêu cầu'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
