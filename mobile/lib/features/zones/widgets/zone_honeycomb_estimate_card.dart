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

  /// Gọi khi bảng dự toán thay đổi (null khi chưa tải được danh mục) để màn cha dùng lại số liệu hiển thị.
  final ValueChanged<HoneycombEstimate?>? onEstimate;
  const ZoneHoneycombEstimateCard({
    super.key,
    required this.areaM2,
    required this.cropName,
    this.measurementParameters = const [],
    this.measurementSource = 'Chưa xác định nhu cầu đo của Zone',
    this.zoneId,
    this.onEstimate,
  });

  @override
  State<ZoneHoneycombEstimateCard> createState() => _ZoneHoneycombEstimateCardState();
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
      if (zoneId != null) installed = ZoneInstalledDevices.fromJson(results[1] as List<Map<String, dynamic>>);
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
        );

  void _emit() => widget.onEstimate?.call(_compute());

  @override
  void didUpdateWidget(ZoneHoneycombEstimateCard old) {
    super.didUpdateWidget(old);
    if (old.areaM2 != widget.areaM2 ||
        old.cropName != widget.cropName ||
        !listEquals(old.measurementParameters, widget.measurementParameters)) {
      // Không gọi setState của màn cha trong lúc build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit();
      });
    }
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
    ),
  );

  /// Thẻ tóm tắt như bản web: số lượng cần, nhãn, và CHI PHÍ phần bổ sung của hạng mục (null = thiếu dữ liệu).
  Widget _chip(String n, String label, double? cost) => Container(
    constraints: const BoxConstraints(minWidth: 96),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          n,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const Divider(height: 10),
        Text(
          cost == null ? 'Chưa có dữ liệu' : (cost == 0 ? 'Không cần bổ sung' : formatVnd(cost)),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: cost == null ? const Color(0xFFB45309) : const Color(0xFF334155),
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value, {String? sub, bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
              if (sub != null) Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color ?? (bold ? const Color(0xFF047857) : null),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _lineRow(EstimateLine l) {
    final item = l.item;
    if (l.covered) {
      final detail = l.note ?? 'Cần ${l.neededTotal} · đã gắn ${l.installed} → không cần bổ sung';
      return _row(
        l.role.label,
        l.note == null ? 'Không cần bổ sung' : 'Chưa có thiết bị',
        sub: detail,
        color: l.note == null ? const Color(0xFF047857) : const Color(0xFFB45309),
      );
    }
    if (item == null) {
      return _row(
        l.role.label,
        'Chưa có dữ liệu',
        sub: 'Cần bổ sung ${l.requiredUnits} · ${l.resolution.detail}',
        color: const Color(0xFFB45309),
      );
    }
    final per = item.unitsPerItem > 1 ? ' (mỗi bản ghi phục vụ ${item.unitsPerItem})' : '';
    return _row(
      '${item.title} × ${l.quantity}',
      formatVnd(l.lineTotal!),
      sub:
          '${l.role.label}: cần ${l.neededTotal}, đã gắn ${l.installed} → bổ sung ${l.requiredUnits}$per · ${formatVnd(item.unitPrice)}/thiết bị',
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
        '• Node cảm biến: mỗi node phủ một ô lục giác bán kính $radius m (~${est.cellAreaM2.round()} m²), hệ số bù biên '
        '$honeycombBoundaryFactor, tối thiểu 2 → cần ${est.sensors} node. Mỗi node là một bộ hoàn chỉnh; chọn ít loại bộ '
        'nhất để đo đủ các thông số của giống cây.',
      );
    b.writeln(
      '• Điểm van/bơm: số node × tỉ lệ theo cây ($ratio) → ${est.actuators} điểm. Van và bơm là một hạng mục; một bộ '
      'điều khiển có thể phục vụ nhiều điểm.',
    );
    b.writeln('• Vật tư phụ kiện: mỗi vị trí lắp mới một bộ. Thi công, định vị GPS và cấu hình mạng: phí cố định.');
    if (widget.zoneId != null) {
      b.write('• Thiết bị đã gắn trong Zone được trừ đi; chỉ tính phần còn thiếu về số lượng và thông số đo.');
    }
    return b.toString().trimRight();
  }

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _frame(
        const Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Expanded(child: Text('Đang lấy thiết bị và đơn giá từ hệ thống…', style: TextStyle(fontSize: 12))),
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
          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, height: 1.4),
        ),
      );
    }
    final cap = est.capability;
    final blocked = est.totalBlockedReason;
    return _frame(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dự toán thiết bị (tham khảo)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(widget.measurementSource, style: const TextStyle(fontSize: 12)),
          if (widget.measurementParameters.isEmpty)
            const Text(
              'Chưa có thông số đo nên chưa xác nhận được thiết bị đáp ứng nhu cầu canh tác.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
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
                      label: Text(measurementLabel(p), style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Diện tích ${widget.areaM2.toStringAsFixed(0)} m² · bán kính ô ${honeycombFixedRadiusM.round()} m '
            '(mỗi node quản lý ~${est.cellAreaM2.round()} m²)',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _badge('Thiết bị & đơn giá: từ hệ thống', const Color(0xFF0284C7)),
              _badge('Số lượng: ước tính', const Color(0xFFB45309)),
              _badge('Thi công: cố định', const Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('${est.gateways}', 'Gateway cần', est.gatewayCost),
              _chip('${est.sensors}', 'Node cảm biến cần', est.sensorCost),
              _chip('${est.actuators}', 'Điểm van/bơm cần', est.actuatorCost),
            ],
          ),
          if (widget.zoneId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                est.installed.isEmpty
                    ? 'Zone chưa gắn thiết bị nào: dự toán lắp mới toàn bộ.'
                    : 'Đã gắn trong Zone: ${est.installed.gateways} gateway, ${est.installed.sensorNodes} node cảm biến, ${est.installed.actuatorNodes} node van/bơm. Dự toán chỉ tính phần bổ sung.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1), height: 1.4),
              ),
            ),
          const Divider(height: 20),
          for (final l in est.lines) _lineRow(l),
          _row(
            'Thi công, định vị GPS & cấu hình mạng mesh',
            formatVnd(est.installationCost),
            sub: 'Phí cài sẵn của ứng dụng, không lấy từ danh mục',
          ),
          const Divider(height: 20),
          if (est.total != null) ...[
            _row(est.nothingToAdd ? 'CHI PHÍ BỔ SUNG' : 'TỔNG DỰ TOÁN THAM KHẢO', formatVnd(est.total!), bold: true),
            if (est.nothingToAdd)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Zone đã đủ số lượng và đủ thông số đo nên không cần bổ sung thiết bị.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
                ),
              )
            else
              _row('Biên dao động (−12% / +18%)', '${formatVnd(est.minTotal!)} – ${formatVnd(est.maxTotal!)}'),
          ] else if (est.partialTotal != null) ...[
            _row(
              'TẠM TÍNH THEO THIẾT BỊ HIỆN CÓ',
              formatVnd(est.partialTotal!),
              bold: true,
              color: const Color(0xFFB45309),
            ),
            Text(
              'Chưa phải tổng đầy đủ. ${blocked ?? ''} Kỹ thuật viên sẽ bổ sung thiết bị còn thiếu khi khảo sát và lập báo giá.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
            ),
          ] else
            Text(
              'Chưa tính được tổng. ${blocked ?? ''} Kỹ thuật viên sẽ bổ sung khi khảo sát và lập báo giá.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.4),
            ),
          if (!cap.declared && widget.measurementParameters.isNotEmpty && est.sensorCost != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Danh mục chưa khai báo các thông số node cảm biến đo được, nên chưa xác nhận đáp ứng đủ nhu cầu đo (ví dụ pH, EC).',
                style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.4),
              ),
            ),
          const SizedBox(height: 4),
          Material(
            type: MaterialType.transparency,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Cách tính', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _howText(est),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Đây chỉ là dự toán để tham khảo, chưa phải báo giá hay hợp đồng. Sau khi bạn gửi yêu cầu, kỹ thuật viên sẽ khảo sát, '
            'trao đổi, bổ sung thiết bị và lập báo giá/hợp đồng để bạn xem và ký.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
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
