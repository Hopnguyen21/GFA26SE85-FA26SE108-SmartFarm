import 'package:flutter/material.dart';
import '../../../core/models/iot_deployment.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../deployment_board_logic.dart';
import 'deployment_progress_bar.dart';
import 'survey_dialog.dart';

/// Khối "Tiến độ lắp đặt" trong chi tiết phiếu dịch vụ loại lắp đặt: cho kỹ thuật viên nhận, khảo sát, xác nhận kế hoạch
/// và bắt đầu lắp đặt ngay trên phiếu. Các bước sau (cấp phát thiết bị, kiểm tra kết nối, hoàn tất, thất bại) và
/// chỉnh kế hoạch thiết bị nằm ở chi tiết triển khai, mở bằng [onOpenDetail]. Backend vẫn là nơi kiểm tra điều kiện.
class InstallProgressCard extends StatefulWidget {
  final String deploymentRequestId;
  final Future<void> Function() onOpenDetail;

  /// Farm/Zone của phiếu dịch vụ: triển khai gắn kèm phải cùng Farm/Zone, nếu không là liên kết sai (giống cảnh báo trên web).
  final String? farmId;
  final String? zoneId;

  /// Báo trạng thái triển khai đọc được (null nếu không đọc được hoặc liên kết sai) để màn chi tiết vẽ thanh quy trình.
  final void Function(String? status)? onStatus;

  /// Dòng tiêu đề của khung thao tác (việc tiếp theo) và các nút thêm của màn chứa (Chấm Node, khoá chờ cọc…).
  final String? headline;
  final List<Widget> extraActions;
  final bool depositPaid;
  const InstallProgressCard({
    super.key,
    this.headline,
    this.extraActions = const [],
    this.depositPaid = false,
    required this.deploymentRequestId,
    required this.onOpenDetail,
    this.farmId,
    this.zoneId,
    this.onStatus,
  });

  @override
  State<InstallProgressCard> createState() => _InstallProgressCardState();
}

class _InstallProgressCardState extends State<InstallProgressCard> {
  DeploymentRequest? _d;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool _linkInvalid(DeploymentRequest d) {
    final f = widget.farmId ?? '', z = widget.zoneId ?? '';
    return (f.isNotEmpty && d.farmId != f) || (z.isNotEmpty && d.zoneId != z);
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
      final d = await DeploymentApi.getDeploymentRequest(
        widget.deploymentRequestId,
        technician: true,
      );
      if (mounted) setState(() => _d = d);
      if (mounted) widget.onStatus?.call(_linkInvalid(d) ? null : d.status);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _survey(DeploymentRequest d) async {
    final input = await askSurvey(context);
    if (input == null || !mounted) return;
    await _run(
      () => DeploymentApi.surveyDeploymentRequest(
        d.requestId,
        isFeasible: input.feasible,
        siteConditions: input.siteConditions,
        notes: input.notes,
      ),
    );
  }

  Future<void> _guarded(
    String title,
    String body,
    Future<Object?> Function() action,
  ) async {
    if (!await _confirm(title, body) || !mounted) return;
    await _run(action);
  }

  List<Widget> _buttons(DeploymentRequest d) {
    if (widget.depositPaid) return const [];
    Widget primary(String label, VoidCallback onTap) =>
        FilledButton(onPressed: _busy ? null : onTap, child: Text(label));
    switch (d.status) {
      case 'Submitted':
        return [
          primary(
            'Tiếp nhận yêu cầu triển khai',
            () => _guarded(
              'Tiếp nhận',
              'Bạn sẽ chịu trách nhiệm khảo sát và lắp đặt yêu cầu này.',
              () => DeploymentApi.acceptDeploymentRequest(d.requestId),
            ),
          ),
        ];
      case 'Accepted':
        return [primary('Ghi nhận khảo sát địa điểm', () => _survey(d))];
      case 'Surveyed':
        return [
          // Theo cam kết (BM04, WF-01): KTV khảo sát → xác nhận kế hoạch → lập báo giá, rồi Owner mới cọc.
          if (d.latestSurveyFeasible)
            primary(
              'Xác nhận kế hoạch',
              () => _guarded(
                'Xác nhận kế hoạch',
                'Xác nhận kế hoạch thiết bị đã khảo sát. Bước tiếp theo là lập và gửi báo giá / hợp đồng cho Owner.',
                () => DeploymentApi.confirmDeploymentPlan(d.requestId),
              ),
            ),
          if (!d.latestSurveyFeasible)
            const Text(
              'Khảo sát ghi nhận KHÔNG khả thi (lý do đã lưu). Không thể xác nhận kế hoạch hay tạo hợp đồng. '
              'Backend hiện chưa có API cho kỹ thuật viên kết thúc yêu cầu ở bước này nên chưa tự báo Owner được; cần Admin xử lý, hoặc khảo sát lại nếu điều kiện thay đổi.',
              style: TextStyle(fontSize: 13, color: AppColors.danger),
            ),
        ];
      default:
        return const [];
    }
  }

  String? _info(DeploymentRequest d) => switch (d.status) {
    'Submitted' || 'Accepted' => null, // nút đã tự mô tả bước
    'PlanConfirmed' =>
      'Cần chủ trang trại đã ký hợp đồng và đóng cọc trước khi bắt đầu lắp đặt.',
    'Surveyed' =>
      'Chỉnh số lượng thiết bị trong kế hoạch ở chi tiết triển khai trước khi xác nhận.',
    'Installing' =>
      'Cấp phát thiết bị, kiểm tra kết nối rồi hoàn tất trong chi tiết triển khai.',
    'Completed' =>
      'Đã hoàn tất triển khai. Phiếu sẽ đóng khi chủ trang trại ký nghiệm thu.',
    'MaintenanceRequired' =>
      'Lắp đặt thất bại, đã chuyển sang bảo trì. Theo dõi ở phiếu bảo trì mới.',
    'Cancelled' => 'Chủ trang trại đã hủy yêu cầu triển khai.',
    _ => deploymentNextStepHint(d.status),
  };

  /// Khung "Thao tác thực địa kỹ thuật" như trang Lắp đặt trên web: nền tối, nút theo tiến độ
  /// (tiếp nhận, khảo sát, xác nhận kế hoạch, bắt đầu lắp đặt, Chấm Node…), nút bị khoá hiện dạng chip.
  Widget _actionPanel(DeploymentRequest d) {
    final buttons = <Widget>[
      for (final b in _buttons(d))
        if (b is FilledButton)
          FilledButton(
            onPressed: b.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            child: b.child,
          )
        else if (b is OutlinedButton)
          OutlinedButton(
            onPressed: b.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF64748B)),
            ),
            child: b.child ?? const SizedBox(),
          )
        else
          b,
      ...widget.extraActions,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: Color(0xFF34D399),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'THAO TÁC THỰC ĐỊA KỸ THUẬT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          if (widget.headline != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.headline!,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: buttons),
        ],
      ),
    );
  }

  /// Thông tin KTV cần khi nhận việc: Farm / Thửa / Zone, cây trồng và danh sách thiết bị Owner đề xuất (hoặc kế hoạch sau khảo sát).
  Widget _site(DeploymentRequest d) {
    final c = d.context;
    final lines = <String>[
      if (c != null) ...[
        'Farm: ${c.farmName} · Thửa: ${c.fieldName} · Zone: ${c.zoneName}'
            '${c.zoneAreaM2 > 0 ? ' (${c.zoneAreaM2.round()} m²)' : ''}',
        if ((c.cropName ?? '').isNotEmpty)
          'Cây trồng: ${c.cropName}${(c.varietyName ?? '').isEmpty ? '' : ' · ${c.varietyName}'}'
              '${c.seasonName.isEmpty ? '' : ' · Vụ ${c.seasonName}'}',
      ],
      if (d.requiredParameters.isNotEmpty)
        'Chỉ số cần theo dõi: ${d.requiredParameters.join(', ')}',
    ];
    final proposed = d.planItems.isNotEmpty
        ? [for (final p in d.planItems) '${p.quantity} × ${p.modelName}']
        : [for (final e in d.estimateItems) '${e.quantity} × ${e.name}'];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Text(l, style: const TextStyle(fontSize: 13, height: 1.4)),
          Text(
            d.planItems.isNotEmpty
                ? 'Kế hoạch thiết bị:'
                : 'Thiết bị Owner đề xuất:',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (proposed.isEmpty)
            const Text(
              'Chưa có thiết bị đề xuất.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            for (final p in proposed)
              Text('• $p', style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.home_repair_service_outlined, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Tiến độ lắp đặt',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                if (d != null && !_linkInvalid(d))
                  Expanded(
                    child: Text(
                      deploymentStatusLabels[d.status] ?? d.status,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: deploymentStatusColor(d.status),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && d == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (d == null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error ?? 'Không tải được tiến độ triển khai.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.danger,
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              )
            else if (_linkInvalid(d))
              const Text(
                'Liên kết triển khai sai farm/zone — cần kiểm tra. Không thao tác được tiến độ lắp đặt từ phiếu này.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.danger,
                  height: 1.4,
                ),
              )
            else ...[
              DeploymentProgressBar(status: d.status),
              _site(d),
              if (_info(d) != null && !widget.depositPaid)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _info(d)!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 10),
              _actionPanel(d),
            ],
          ],
        ),
      ),
    );
  }
}
