part of '../deployment_screens.dart';

// ════════════════════════════════════════════════════════════════════════
//  Chi tiết yêu cầu (Owner và Technician dùng chung; hành động lọc theo role + trạng thái)
// ════════════════════════════════════════════════════════════════════════
class DeploymentRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final bool technician;
  const DeploymentRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.technician,
  });

  @override
  State<DeploymentRequestDetailScreen> createState() =>
      _DeploymentRequestDetailScreenState();
}

class _DeploymentRequestDetailScreenState
    extends State<DeploymentRequestDetailScreen> {
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
      final r = await DeploymentApi.getDeploymentRequest(
        widget.requestId,
        technician: widget.technician,
      );
      var devices = <IotDevice>[];
      var gateways = <IotGateway>[];
      if (widget.technician &&
          (r.status == 'Installing' ||
              r.status == 'Completed' ||
              r.status == 'MaintenanceRequired')) {
        gateways = (await DeploymentApi.getFarmGateways(
          r.farmId,
        )).where((g) => g.deploymentRequestId == r.requestId).toList();
        devices = (await DeploymentApi.getFarmDevices(
          r.farmId,
        )).where((d) => d.deploymentRequestId == r.requestId).toList();
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
  Future<void> _act(
    Future<void> Function() action, {
    String? confirmTitle,
    String? confirmBody,
  }) async {
    if (_busy) return;
    if (confirmTitle != null &&
        !await _confirm(context, confirmTitle, confirmBody ?? ''))
      return;
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

  /// Thông tin nơi lắp đặt: farm, thửa đất, Zone, cây và vụ mùa (để Owner và kỹ thuật viên biết yêu cầu thuộc về đâu).
  Widget _contextCard(DeploymentRequest r) {
    final c = r.context;
    if (c == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          'Chưa có thông tin Zone của yêu cầu này (máy chủ chưa trả kèm). Hãy cập nhật backend rồi tải lại.',
          style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
        ),
      );
    }
    Widget row(IconData icon, String label, String value) =>
        KeyValueRow(icon, label, value);
    final crop = [
      c.cropName,
      if (c.varietyName != null) c.varietyName,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
    return SectionCard(
      title: 'Nơi lắp đặt',
      icon: Icons.place_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            Icons.agriculture,
            'Trang trại',
            c.farmLocation == null || c.farmLocation!.isEmpty
                ? c.farmName
                : '${c.farmName}\n${c.farmLocation}',
          ),
          row(
            Icons.layers_outlined,
            'Thửa đất',
            '${c.fieldName}${c.soilType == null ? '' : ' · ${soilTypeLabels[c.soilType] ?? c.soilType}'}',
          ),
          row(
            Icons.home_work_outlined,
            'Zone',
            '${c.zoneName} · ${zoneTypeLabels[c.zoneType] ?? c.zoneType} · ${c.zoneAreaM2.toStringAsFixed(0)} m²',
          ),
          if (crop.isNotEmpty) row(Icons.eco_outlined, 'Cây trồng', crop),
          row(
            Icons.event_outlined,
            'Vụ mùa',
            '${c.seasonName} (${seasonStatusLabels[c.seasonStatus] ?? c.seasonStatus})\n${DeploymentContext.vnDate(c.seasonStart)} → ${DeploymentContext.vnDate(c.seasonExpectedEnd)}',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _req;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _appBar(
        r?.context == null
            ? 'Yêu cầu ${widget.requestId.substring(0, 8)}'
            : 'Yêu cầu · ${r!.context!.zoneName}',
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : r == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Không tải được yêu cầu: $_error'),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Flexible(child: _statusChip(r.status)),
                    const SizedBox(width: 8),
                    if (_busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _contextCard(r),
                if (r.ownerNotes != null && r.ownerNotes!.trim().isNotEmpty)
                  SectionCard(
                    title: 'Ghi chú của Owner',
                    icon: Icons.sticky_note_2_outlined,
                    child: Text(
                      r.ownerNotes!,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                SectionCard(
                  title: 'Thông số cần đo',
                  icon: Icons.sensors,
                  child: r.requiredParameters.isEmpty
                      ? const Text(
                          'Chưa có thông số.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final p in r.requiredParameters)
                              ParamPill(measurementLabel(p)),
                          ],
                        ),
                ),
                if (r.planItems.isNotEmpty)
                  SectionCard(
                    title: 'Kế hoạch thiết bị',
                    icon: Icons.devices_other_outlined,
                    child: Column(
                      children: [
                        for (final i in r.planItems)
                          LineItemRow(
                            qty: i.quantity,
                            title: i.modelName,
                            meta: i.installationNotes,
                          ),
                      ],
                    ),
                  ),
                if (r.estimateItems.isNotEmpty)
                  SectionCard(
                    title: 'Dự toán thiết bị (tham khảo)',
                    icon: Icons.calculate_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final e in r.estimateItems)
                          LineItemRow(
                            qty: e.quantity,
                            title:
                                '${e.name}${e.model == null ? '' : ' (${e.model})'}',
                            meta:
                                '${e.code} · ${formatVnd(e.unitPrice)}/đơn vị${e.notes == null ? '' : '\n${e.notes}'}',
                            amount: formatVnd(e.lineTotal),
                          ),
                        const SizedBox(height: 6),
                        TotalBar(
                          label: 'Tổng dự toán',
                          value: formatVnd(
                            r.estimateItems.fold<double>(
                              0,
                              (a, e) => a + e.lineTotal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Danh sách này do Owner dự toán, chưa phải báo giá hay hợp đồng. Kỹ thuật viên khảo sát rồi lập '
                          'báo giá/hợp đồng để Owner xem và xác nhận.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (r.failureCode != null) ...[
                  const Divider(height: 24),
                  Text(
                    'Thất bại: ${r.failureCode}',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (r.failureDescription != null) Text(r.failureDescription!),
                ],
                ..._actions(r),
                if (widget.technician) ..._hardware(r),
                if (r.surveys.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Khảo sát',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final s in r.surveys)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.isFeasible ? Icons.check_circle : Icons.cancel,
                        color: s.isFeasible
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                      title: Text(s.isFeasible ? 'Khả thi' : 'Không khả thi'),
                      subtitle: Text(
                        '${s.siteConditions}\n${s.notes}\n${s.surveyedAtUtc}',
                      ),
                    ),
                ],
                const Divider(height: 24),
                const Text(
                  'Lịch sử quyết định',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final h in r.history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${h.decisionType}: ${deploymentStatusLabels[h.fromStatus] ?? h.fromStatus} → ${deploymentStatusLabels[h.toStatus] ?? h.toStatus}',
                    ),
                    subtitle: Text(
                      '${h.decidedAtUtc}${h.notes == null ? '' : '\n${h.notes}'}',
                    ),
                  ),
              ],
            ),
    );
  }
}
