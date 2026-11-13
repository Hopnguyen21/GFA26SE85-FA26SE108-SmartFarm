import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/state_views.dart';
import '../honeycomb_estimate.dart';

/// Bảng dự toán lắp đặt IoT (thuật toán Tổ ong) để Owner THAM KHẢO.
/// - Thiết bị và đơn giá tự lấy từ backend (danh mục phần cứng), Owner không chọn thiết bị hay nhập giá.
/// - Thiếu dữ liệu thì chỉ báo thiếu đúng hạng mục, không có giá dự phòng và không có tổng giả.
/// - Đây không phải báo giá/hợp đồng: kỹ thuật viên khảo sát, trao đổi, lập báo giá rồi Owner xem và ký.
class ZoneHoneycombEstimateCard extends StatefulWidget {
  final double areaM2;
  final String cropName;
  final List<String> measurementParameters;
  final String measurementSource;

  /// Zone cần dự toán: có thì chỉ tính phần BỔ SUNG so với thiết bị đã gắn. Null (vd. wizard, Zone chưa tạo) = lắp mới toàn bộ.
  final String? zoneId;

  /// Chu vi bao lồi của ranh giới Zone (m) nếu có; không có thì giả định hình chữ nhật 1:2.
  final double? perimeterM;

  /// Gọi khi bảng dự toán thay đổi (null khi chưa tải được danh mục) để màn cha dùng lại số liệu hiển thị.
  final ValueChanged<HoneycombEstimate?>? onEstimate;
  const ZoneHoneycombEstimateCard({
    super.key,
    required this.areaM2,
    required this.cropName,
    this.measurementParameters = const [],
    this.measurementSource = 'Chưa xác định nhu cầu đo của Zone',
    this.zoneId,
    this.perimeterM,
    this.onEstimate,
  });

  @override
  State<ZoneHoneycombEstimateCard> createState() =>
      _ZoneHoneycombEstimateCardState();
}

class _ZoneHoneycombEstimateCardState extends State<ZoneHoneycombEstimateCard> {
  HoneycombCatalog? _catalog;
  ZoneInstalledDevices _installed = ZoneInstalledDevices.none;
  String? _error;
  bool _loading = true;
  int _loadSeq = 0; // chỉ phản hồi của lần tải mới nhất được áp dụng

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = null;
      _catalog = null; // không giữ giá cũ khi lần tải mới thất bại
    });
    HoneycombCatalog? catalog;
    var installed = ZoneInstalledDevices.none;
    String? error;
    try {
      final zoneId = widget.zoneId;
      // Thiết bị đã gắn phải tải được mới tính: không được coi lỗi tải là "chưa có thiết bị" vì sẽ dự toán thừa.
      final results = await Future.wait<Object>([
        DeploymentApi.getHardwareItems(),
        if (zoneId != null) DeploymentApi.getZoneDevices(zoneId),
      ]);
      final raw = results[0] as List<Map<String, dynamic>>;
      if (zoneId != null)
        installed = ZoneInstalledDevices.fromJson(
          results[1] as List<Map<String, dynamic>>,
        );
      catalog = HoneycombCatalog.fromHardwareItems(raw);
      if (kDebugMode) {
        debugPrint('[Dự toán IoT] ${raw.length} bản ghi danh mục:');
        for (final row in catalog.diagnose()) {
          debugPrint('[Dự toán IoT]   $row');
        }
      }
    } catch (e) {
      error = friendlyError(e);
    }
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _catalog = catalog;
      _installed = installed;
      _error = error;
      _loading = false;
    });
    _emit();
  }

  HoneycombEstimate? _compute() => _catalog == null
      ? null
      : computeHoneycombEstimate(
          areaM2: widget.areaM2,
          radiusM: honeycombFixedRadiusM,
          actuatorRatio: honeycombActuatorRatio(widget.cropName),
          catalog: _catalog!,
          requiredParameters: widget.measurementParameters,
          installed: _installed,
          perimeterM: widget.perimeterM,
        );

  void _emit() => widget.onEstimate?.call(_compute());

  @override
  void didUpdateWidget(ZoneHoneycombEstimateCard old) {
    super.didUpdateWidget(old);
    if (old.areaM2 != widget.areaM2 ||
        old.cropName != widget.cropName ||
        old.perimeterM != widget.perimeterM ||
        !listEquals(old.measurementParameters, widget.measurementParameters)) {
      // Không gọi setState của màn cha trong lúc build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit();
      });
    }
  }

  bool _expanded = true;

  static const _amber = Color(0xFFB45309);
  static const _muted = Color(0xFF64748B);

  /// Thẻ tóm tắt (như bản web): biểu tượng, số lượng cần, tên, mô tả và CHI PHÍ phần bổ sung (null = thiếu dữ liệu).
  Widget _kpi({
    required IconData icon,
    required Color accent,
    required Color soft,
    required Color border,
    required String n,
    required String title,
    required String sub,
    required double? cost,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: border),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 4),
          Text(
            n,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          Text(
            sub,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: _muted),
          ),
          const Divider(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              cost == null
                  ? 'Chưa có dữ liệu'
                  : (cost == 0 ? 'Không cần bổ sung' : formatVnd(cost)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cost == null ? _amber : accent,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  IconData _roleIcon(EstimateRole r) => switch (r) {
    EstimateRole.gateway => Icons.wifi,
    EstimateRole.sensorNode => Icons.sensors,
    EstimateRole.actuatorNode => Icons.bolt,
    EstimateRole.installKit => Icons.inventory_2_outlined,
  };

  Color _roleColor(EstimateRole r) => switch (r) {
    EstimateRole.gateway => const Color(0xFF0284C7),
    EstimateRole.sensorNode => const Color(0xFF059669),
    EstimateRole.actuatorNode => const Color(0xFFD97706),
    EstimateRole.installKit => _muted,
  };

  /// Một dòng của bảng báo giá dự toán: biểu tượng, tên (model) × số lượng, thành tiền và đơn giá.
  Widget _tableRow({
    required IconData icon,
    required Color color,
    required String title,
    String? model,
    String? sub,
    required String amount,
    String? unit,
    Color? amountColor,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (model != null)
                      TextSpan(
                        text: ' ($model)',
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                  ],
                ),
                style: const TextStyle(fontSize: 12),
              ),
              if (sub != null)
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _muted,
                    height: 1.3,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: amountColor ?? const Color(0xFF0F172A),
                ),
              ),
              if (unit != null)
                Text(
                  unit,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _lineRow(EstimateLine l) {
    final item = l.item;
    final color = _roleColor(l.role);
    final icon = _roleIcon(l.role);
    if (l.covered) {
      return _tableRow(
        icon: icon,
        color: color,
        title: l.role.label,
        sub:
            l.note ??
            'Cần ${l.neededTotal} · đã gắn ${l.installed} → không cần bổ sung',
        amount: l.note == null ? 'Không cần bổ sung' : 'Chưa có thiết bị',
        amountColor: l.note == null ? const Color(0xFF047857) : _amber,
      );
    }
    if (item == null) {
      return _tableRow(
        icon: icon,
        color: color,
        title: l.role.label,
        sub: 'Cần bổ sung ${l.requiredUnits} · ${l.resolution.detail}',
        amount: 'Chưa có dữ liệu',
        amountColor: _amber,
      );
    }
    final per = item.unitsPerItem > 1
        ? ' (mỗi thiết bị phục vụ ${item.unitsPerItem})'
        : '';
    return _tableRow(
      icon: icon,
      color: color,
      title: '${item.name} × ${l.quantity}',
      model: item.model,
      sub:
          'Cần ${l.neededTotal}, đã gắn ${l.installed} → bổ sung ${l.requiredUnits}$per',
      amount: formatVnd(l.lineTotal!),
      unit: '${formatVnd(item.unitPrice)}/thiết bị',
    );
  }

  /// Giải thích từng con số bằng số liệu thật của Zone (để Owner hiểu vì sao cần chừng đó thiết bị).
  String _howText(HoneycombEstimate est) {
    final ratio = honeycombActuatorRatio(widget.cropName);
    final cover = honeycombGatewayCoverM2.round();
    final radius = honeycombFixedRadiusM.round();
    final b = StringBuffer()
      ..writeln(
        '• Gateway: diện tích ${widget.areaM2.toStringAsFixed(0)} m² / $cover m² mỗi gateway → cần ${est.gateways}.',
      )
      ..writeln(
        '• Node cảm biến: mỗi node phủ một ô lục giác bán kính $radius m (~${est.cellAreaM2.round()} m²). Số node = '
        'diện tích / ô × $honeycombNodeAreaFactor + phần biên theo chu vi Zone × $honeycombNodePerimeterFactor, làm tròn '
        'lên → cần ${est.sensors} node (${widget.perimeterM == null ? 'chu vi ước tính theo hình chữ nhật 1:2' : 'chu vi lấy từ ranh giới Zone'}). '
        'Mỗi node là một bộ hoàn chỉnh; chọn ít loại bộ nhất để đo đủ các thông số của giống cây.',
      );
    b.writeln(
      '• Điểm van/bơm: số node × tỉ lệ theo cây ($ratio) → ${est.actuators} điểm. Van và bơm là một hạng mục; một bộ '
      'điều khiển có thể phục vụ nhiều điểm.',
    );
    b.writeln(
      '• Vật tư phụ kiện: mỗi vị trí lắp mới một bộ. Thi công, định vị GPS và cấu hình mạng: phí cố định.',
    );
    if (widget.zoneId != null) {
      b.write(
        '• Thiết bị đã gắn trong Zone được trừ đi; chỉ tính phần còn thiếu về số lượng và thông số đo.',
      );
    }
    return b.toString().trimRight();
  }

  void _showHow(HoneycombEstimate est) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cơ sở tính toán', style: TextStyle(fontSize: 15)),
      content: SingleChildScrollView(
        child: Text(
          _howText(est),
          style: const TextStyle(fontSize: 12, height: 1.5),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đã hiểu'),
        ),
      ],
    ),
  );

  Widget _frame(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );

  Widget _banner(HoneycombEstimate est) => InkWell(
    onTap: () => setState(() => _expanded = !_expanded),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF119653), Color(0xFF059669), Color(0xFF10B981)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(Icons.memory, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Thiết bị đề xuất & dự toán lắp đặt IoT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'Thuật toán Mạng Tổ ong (Hexagonal WSN)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _showHow(est),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Cơ sở toán học',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mô hình mật độ thưa chuẩn hóa (${honeycombFixedRadiusM.round()} m/node) • Diện tích: '
            '${widget.areaM2.toStringAsFixed(0)} m²',
            style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 11),
          ),
        ],
      ),
    ),
  );

  Widget _totalBlock(HoneycombEstimate est, String? blocked) {
    final full = est.total != null;
    final partial = est.partialTotal != null;
    final color = full ? const Color(0xFF047857) : _amber;
    final bg = full ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final label = full
        ? (est.nothingToAdd ? 'CHI PHÍ BỔ SUNG' : 'TỔNG CHI PHÍ ƯỚC TÍNH')
        : (partial ? 'TẠM TÍNH THEO THIẾT BỊ HIỆN CÓ' : 'CHƯA TÍNH ĐƯỢC TỔNG');
    final amount = full ? est.total : est.partialTotal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.trending_up, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ),
              if (amount != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatVnd(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (full && !est.nothingToAdd)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Biên độ dao động (−12% / +18%): ${formatVnd(est.minTotal!)} – ${formatVnd(est.maxTotal!)}',
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ),
          if (full && est.nothingToAdd)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text(
                'Zone đã đủ số lượng và đủ thông số đo nên không cần bổ sung thiết bị.',
                style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
              ),
            ),
          if (full && !est.nothingToAdd)
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Đã bao gồm vật tư & công lắp đặt',
                style: TextStyle(fontSize: 10, color: Color(0xFF047857)),
              ),
            ),
          if (!full)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                partial
                    ? 'Chưa phải tổng đầy đủ. ${blocked ?? ''} Kỹ thuật viên sẽ bổ sung thiết bị còn thiếu khi khảo sát và lập báo giá.'
                    : 'Chưa tính được tổng. ${blocked ?? ''} Kỹ thuật viên sẽ bổ sung khi khảo sát và lập báo giá.',
                style: const TextStyle(
                  fontSize: 11,
                  color: _amber,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _frame(
        const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đang lấy thiết bị và đơn giá từ hệ thống…',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    final est = _compute();
    if (_error != null || est == null) {
      return _frame(
        Text(
          'Không lấy được danh mục thiết bị để dự toán: ${_error ?? 'không có dữ liệu'}. '
          'Kéo xuống để làm mới trang, hoặc liên hệ kỹ thuật viên để được báo giá.',
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      );
    }
    final cap = est.capability;
    final blocked = est.totalBlockedReason;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(est),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.measurementSource,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  if (widget.measurementParameters.isEmpty)
                    const Text(
                      'Chưa có thông số đo nên chưa xác nhận được thiết bị đáp ứng nhu cầu canh tác.',
                      style: TextStyle(fontSize: 11, color: _amber),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final p in widget.measurementParameters.toSet())
                            Chip(
                              label: Text(
                                measurementLabel(p),
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _kpi(
                          icon: Icons.wifi,
                          accent: const Color(0xFF075985),
                          soft: const Color(0xFFE0F2FE),
                          border: const Color(0xFFBAE6FD),
                          n: '${est.gateways}',
                          title: 'Trạm LoRa Gateway',
                          sub:
                              'Mỗi trạm phủ ~${honeycombGatewayCoverM2.round()} m²',
                          cost: est.gatewayCost,
                        ),
                        const SizedBox(width: 6),
                        _kpi(
                          icon: Icons.sensors,
                          accent: const Color(0xFF065F46),
                          soft: const Color(0xFFD1FAE5),
                          border: const Color(0xFFA7F3D0),
                          n: '${est.sensors}',
                          title: 'Sensor Node Tổ ong',
                          sub: 'Mỗi node quản lý ~${est.cellAreaM2.round()} m²',
                          cost: est.sensorCost,
                        ),
                        const SizedBox(width: 6),
                        _kpi(
                          icon: Icons.bolt,
                          accent: const Color(0xFF92400E),
                          soft: const Color(0xFFFEF3C7),
                          border: const Color(0xFFFDE68A),
                          n: '${est.actuators}',
                          title: 'Actuator Van/Bơm',
                          sub: 'Điều khiển tưới theo cụm ô',
                          cost: est.actuatorCost,
                        ),
                      ],
                    ),
                  ),
                  if (widget.zoneId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        est.installed.isEmpty
                            ? 'Zone chưa gắn thiết bị nào: dự toán lắp mới toàn bộ.'
                            : 'Đã gắn trong Zone: ${est.installed.gateways} gateway, ${est.installed.sensorNodes} node cảm biến, ${est.installed.actuatorNodes} node van/bơm. Dự toán chỉ tính phần bổ sung.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0369A1),
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          color: const Color(0xFFF1F5F9),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: Color(0xFF047857),
                                  ),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Bảng dự toán lắp đặt hệ thống',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.storage,
                                      size: 10,
                                      color: Color(0xFF047857),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Giá từ hệ thống',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final l in est.lines) _lineRow(l),
                        _tableRow(
                          icon: Icons.build_outlined,
                          color: _muted,
                          title:
                              'Thi công, định vị GPS & cấu hình mạng mesh (cố định)',
                          amount: formatVnd(est.installationCost),
                        ),
                        _totalBlock(est, blocked),
                      ],
                    ),
                  ),
                  if (!cap.declared &&
                      widget.measurementParameters.isNotEmpty &&
                      est.sensorCost != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Danh mục chưa khai báo các thông số node cảm biến đo được, nên chưa xác nhận đáp ứng đủ nhu cầu đo (ví dụ pH, EC).',
                        style: TextStyle(
                          fontSize: 11,
                          color: _amber,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: _amber,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Đây chỉ là dự toán để tham khảo, chưa phải báo giá hay hợp đồng. Sau khi bạn gửi yêu cầu, kỹ thuật viên '
                          'sẽ khảo sát, trao đổi, bổ sung thiết bị và lập báo giá/hợp đồng để bạn xem và ký.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String measurementLabel(String code) =>
    const {
      'soilmoisture': 'Độ ẩm đất',
      'temperature': 'Nhiệt độ',
      'airhumidity': 'Độ ẩm không khí',
      'lightintensity': 'Ánh sáng',
      'ph': 'pH',
      'ec': 'EC',
      'co2': 'CO₂',
    }[code.toLowerCase()] ??
    code;
