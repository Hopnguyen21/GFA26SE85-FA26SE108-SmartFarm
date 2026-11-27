import 'package:flutter/material.dart';
import '../../../core/models/iot_deployment.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../deployment_board_logic.dart';
import 'deployment_progress_bar.dart';
import '../../support/field_survey_logic.dart';
import '../../support/field_survey_report_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/farm_provider.dart';

/// Khối "Tiến độ lắp đặt" trong chi tiết phiếu dịch vụ loại lắp đặt: cho kỹ thuật viên nhận, khảo sát, xác nhận kế hoạch
/// và bắt đầu lắp đặt ngay trên phiếu. Các bước sau (cấp phát thiết bị, kiểm tra kết nối, hoàn tất, thất bại) và
/// chỉnh kế hoạch thiết bị nằm ở chi tiết triển khai, mở bằng [onOpenDetail]. Backend vẫn là nơi kiểm tra điều kiện.
class InstallProgressCard extends StatefulWidget {
  final String deploymentRequestId;
  final Future<void> Function() onOpenDetail;

  /// Farm/Zone của phiếu dịch vụ: triển khai gắn kèm phải cùng Farm/Zone, nếu không là liên kết sai (giống cảnh báo trên web).
  final String? farmId;
  final String? zoneId;

  /// Phiếu dịch vụ chứa khối này: báo cáo khảo sát thực địa gắn với phiếu (mỗi phiếu một báo cáo).
  final String? serviceRequestId;

  /// Báo trạng thái triển khai đọc được (null nếu không đọc được hoặc liên kết sai) để màn chi tiết vẽ thanh quy trình.
  final void Function(String? status)? onStatus;

  /// Báo khảo sát thực địa đã có kết quả KHẢ THI chưa (màn chứa dùng để mở/khoá phần xem và gửi hợp đồng).
  final void Function(bool feasibleDone)? onSurvey;

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
    this.serviceRequestId,
    this.onStatus,
    this.onSurvey,
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
      if (mounted) {
        widget.onSurvey?.call(d.surveys.isNotEmpty && d.latestSurveyFeasible);
      }
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

  Future<void> _guarded(
    String title,
    String body,
    Future<Object?> Function() action,
  ) async {
    if (!await _confirm(title, body) || !mounted) return;
    await _run(action);
  }

  String? _currentUserName() {
    try {
      return context.read<FarmProvider>().me?['fullName']?.toString();
    } catch (_) {
      return null; // không có FarmProvider (kiểm thử): màn báo cáo dùng tên mặc định
    }
  }

  /// Bước khảo sát = lập BÁO CÁO KHẢO SÁT THỰC ĐỊA (phiếu 10 mục như web). KTV phải chọn kết luận khả thi/không khả thi khi nộp;
  /// sau khi báo cáo lưu được, app mới gọi API khảo sát của luồng lắp đặt với kết luận đó (nội dung tóm lược từ báo cáo), rồi tải lại.
  Future<void> _doSurvey(DeploymentRequest d) async {
    final sr = widget.serviceRequestId;
    final target = FieldSurveyTarget(
      serviceRequestId: sr,
      farmId: d.farmId,
      farmName: d.context?.farmName ?? '',
      zoneId: d.zoneId,
      zoneName: d.context?.zoneName ?? '',
      requestCode: sr == null || sr.length < 8 ? sr : sr.substring(0, 8),
    );
    final outcome = await Navigator.push<FieldSurveyOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => FieldSurveyReportScreen(
          target: target,
          requireFeasibility: true,
          currentUserName: _currentUserName(),
        ),
      ),
    );
    final feasible = outcome?.feasible;
    if (outcome == null || feasible == null || !mounted) return;
    final digest = surveyDigest(outcome.report, feasible: feasible);
    await _run(
      () => DeploymentApi.surveyDeploymentRequest(
        d.requestId,
        isFeasible: feasible,
        siteConditions: digest.siteConditions,
        notes: digest.notes,
      ),
    );
  }

  /// Khảo sát nhanh: xác nhận hiện trường đủ điều kiện kỹ thuật và chuyển bước ngay (tương tự Web Dashboard).
  Future<void> _quickSurvey(DeploymentRequest d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Khảo sát hiện trường'),
        content: const Text(
          'Xác nhận hiện trường đủ điều kiện kỹ thuật (nguồn điện, sóng LoRa/Wifi, hạ tầng phân khu) để tiếp tục quy trình lắp đặt?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
            ),
            child: const Text('Xác nhận Đủ điều kiện (Khả thi)'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => DeploymentApi.surveyDeploymentRequest(
        d.requestId,
        isFeasible: true,
        siteConditions:
            'Hiện trường đủ điều kiện kỹ thuật theo khảo sát thực tế.',
        notes: 'Kỹ thuật viên xác nhận khả thi để triển khai lắp đặt.',
      ),
    );
  }

  /// Mở lại báo cáo khảo sát đã lập của phiếu (xem; KTV tạo ra báo cáo thì sửa và nộp lại được, không đổi kết luận đã gửi).
  Future<void> _viewReport(DeploymentRequest d) async {
    final sr = widget.serviceRequestId;
    if (sr == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldSurveyReportScreen(
          target: FieldSurveyTarget(
            serviceRequestId: sr,
            farmId: d.farmId,
            farmName: d.context?.farmName ?? '',
            zoneId: d.zoneId,
            zoneName: d.context?.zoneName ?? '',
            requestCode: sr.length < 8 ? sr : sr.substring(0, 8),
          ),
          currentUserName: _currentUserName(),
        ),
      ),
    );
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
        // Sau khi nhận yêu cầu: KTV có thể khảo sát nhanh để chuyển bước, hoặc lập biên bản khảo sát 10 mục chi tiết.
        return [
          primary('Khảo sát nhanh & chuyển bước', () => _quickSurvey(d)),
          OutlinedButton(
            onPressed: _busy ? null : () => _doSurvey(d),
            child: const Text('Lập báo cáo khảo sát thực địa'),
          ),
        ];
      case 'Surveyed':
        return [
          if (!d.latestSurveyFeasible)
            primary('Lập lại báo cáo khảo sát', () => _doSurvey(d)),
          // Kế hoạch tự được xác nhận khi KTV gửi hợp đồng: không còn nút "Xác nhận kế hoạch".
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
    'Submitted' => null, // nút đã tự mô tả bước
    'Accepted' =>
      'Lập báo cáo khảo sát thực địa trước; kết luận khả thi mới xem và gửi được hợp đồng.',
    'PlanConfirmed' =>
      'Cần chủ trang trại đã ký hợp đồng và đóng cọc trước khi bắt đầu lắp đặt.',
    'Surveyed' =>
      d.surveys.isEmpty
          ? 'Gửi hợp đồng cho Owner: kế hoạch sẽ tự được xác nhận.'
          : 'Báo cáo khảo sát thực địa: ${d.surveys.last.isFeasible ? 'khả thi' : 'KHÔNG khả thi'} · ${d.surveys.last.siteConditions} · ${d.surveys.last.notes}. ${d.latestSurveyFeasible ? 'Gửi hợp đồng cho Owner: kế hoạch sẽ tự được xác nhận.' : ''}',
    'Installing' =>
      'Cấp phát thiết bị, kiểm tra kết nối rồi hoàn tất trong chi tiết triển khai.',
    'Completed' =>
      'Đã hoàn tất triển khai. Phiếu sẽ đóng khi chủ trang trại ký nghiệm thu.',
    'MaintenanceRequired' =>
      'Lắp đặt thất bại, đã chuyển sang bảo trì. Theo dõi ở phiếu bảo trì mới.',
    'Cancelled' => 'Chủ trang trại đã hủy yêu cầu triển khai.',
    _ => deploymentNextStepHint(d.status),
  };

  /// Khung "Thao tác thực địa kỹ thuật": Thiết kế sáng, trang nhã, chuẩn UI/UX Pro Max,
  /// độ tương phản cao đạt chuẩn WCAG AA/AAA trên nền thẻ.
  Widget _actionPanel(DeploymentRequest d) {
    final buttons = <Widget>[
      for (final b in _buttons(d))
        if (b is FilledButton)
          FilledButton(
            onPressed: b.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: b.child,
          )
        else if (b is OutlinedButton)
          OutlinedButton(
            onPressed: b.onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF047857),
              side: const BorderSide(color: Color(0xFF059669), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: b.child ?? const SizedBox(),
          )
        else
          b,
      // Xem/sửa báo cáo khảo sát đã lập (sau bước khảo sát) của phiếu này.
      if (widget.serviceRequestId != null &&
          const {
            'Surveyed',
            'PlanConfirmed',
            'Installing',
            'Completed',
          }.contains(d.status))
        OutlinedButton.icon(
          key: const ValueKey('view-survey-report'),
          onPressed: () => _viewReport(d),
          icon: const Icon(
            Icons.description_outlined,
            size: 16,
            color: Color(0xFF047857),
          ),
          label: const Text('Báo cáo khảo sát thực địa'),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF047857),
            side: const BorderSide(color: Color(0xFF059669), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ...widget.extraActions,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Emerald 50
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFA7F3D0), // Emerald 200
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF065F46).withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  size: 15,
                  color: Color(0xFF047857),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'THAO TÁC THỰC ĐỊA KỸ THUẬT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          if (widget.headline != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                widget.headline!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
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
    final lines = <({IconData icon, Color color, String text})>[
      if (c != null) ...[
        (
          icon: Icons.location_on_outlined,
          color: const Color(0xFF0284C7),
          text:
              'Farm: ${c.farmName} · Thửa: ${c.fieldName} · Zone: ${c.zoneName}'
              '${c.zoneAreaM2 > 0 ? ' (${c.zoneAreaM2.round()} m²)' : ''}',
        ),
        if ((c.cropName ?? '').isNotEmpty)
          (
            icon: Icons.spa_outlined,
            color: const Color(0xFF059669),
            text:
                'Cây trồng: ${c.cropName}${(c.varietyName ?? '').isEmpty ? '' : ' · ${c.varietyName}'}'
                '${c.seasonName.isEmpty ? '' : ' · Vụ ${c.seasonName}'}',
          ),
      ],
      if (d.requiredParameters.isNotEmpty)
        (
          icon: Icons.sensors_outlined,
          color: const Color(0xFF7C3AED),
          text: 'Chỉ số cần theo dõi: ${d.requiredParameters.join(', ')}',
        ),
    ];
    final proposed = d.planItems.isNotEmpty
        ? [for (final p in d.planItems) '${p.quantity} × ${p.modelName}']
        : [for (final e in d.estimateItems) '${e.quantity} × ${e.name}'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(item.icon, size: 14, color: item.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 14, color: Color(0xFFE2E8F0)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.planItems.isNotEmpty
                      ? 'Kế hoạch thiết bị:'
                      : 'Thiết bị Owner đề xuất:',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (proposed.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 26),
              child: Text(
                'Chưa có thiết bị đề xuất.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            )
          else
            for (final p in proposed)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 26),
                child: Text(
                  '• $p',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.home_repair_service_rounded,
                    size: 18,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tiến độ lắp đặt',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                if (d != null && !_linkInvalid(d))
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: deploymentStatusColor(
                            d.status,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: deploymentStatusColor(
                              d.status,
                            ).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          deploymentStatusLabels[d.status] ?? d.status,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: deploymentStatusColor(d.status),
                          ),
                        ),
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
