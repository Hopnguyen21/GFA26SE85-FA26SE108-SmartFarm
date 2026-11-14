part of '../zone_contract_forms.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Chi tiết hợp đồng (tải lại từ backend để có thiết bị, gia hạn, VAT/chiết khấu)
// ═══════════════════════════════════════════════════════════════════════════
class ZoneContractDetailScreen extends StatefulWidget {
  final ZoneContractModel contract;
  final bool canRenew;
  const ZoneContractDetailScreen({
    super.key,
    required this.contract,
    this.canRenew = false,
  });

  @override
  State<ZoneContractDetailScreen> createState() =>
      _ZoneContractDetailScreenState();
}

class _ZoneContractDetailScreenState extends State<ZoneContractDetailScreen> {
  late ZoneContractModel _c = widget.contract;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    BusinessParametersStore.refresh().then((_) {
      if (mounted) setState(() {});
    });
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fresh = await ContractApi.getZoneContractById(_c.id);
      if (mounted) setState(() => _c = fresh);
    } catch (e) {
      if (mounted) setState(() => _error = _err(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _row(String l, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            l,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  String _d(String raw) {
    final d = DateTime.tryParse(raw);
    return d == null ? raw : _dmy.format(d.toLocal());
  }

  static const _categoryLabel = <String, String>{
    'GATEWAY': 'Gateway',
    'SOIL_SENSOR': 'Cảm biến đất',
    'AIR_SENSOR': 'Cảm biến khí hậu',
    'SENSOR_NODE': 'Cảm biến',
    'ACTUATOR_NODE': 'Node điều khiển',
    'VALVE': 'Van điều khiển',
    'PUMP': 'Máy bơm',
    'ACCESSORY': 'Phụ kiện',
    'SERVICE': 'Dịch vụ',
  };

  /// Thẻ có tiêu đề như các khối của web (nền nhạt, viền, tiêu đề có đường kẻ).
  Widget _card(
    IconData icon,
    String title,
    List<Widget> children, {
    String? trailing,
    bool white = false,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: white ? Colors.white : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF059669)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
            if (trailing != null)
              Flexible(
                child: Text(
                  trailing,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ),
          ],
        ),
        const Divider(height: 14),
        ...children,
      ],
    ),
  );

  Widget _statusBanner(ZoneContractModel c) {
    final ended = c.status == 'Renewed' || c.status == 'Terminated';
    final expired = !ended && (c.daysRemaining < 0 || c.status == 'Expired');
    final soon = !ended && !expired && c.daysRemaining <= 30;
    final color = ended
        ? const Color(0xFF64748B)
        : expired
        ? const Color(0xFFE11D48)
        : soon
        ? const Color(0xFFD97706)
        : const Color(0xFF059669);
    final label = c.statusText.isNotEmpty
        ? c.statusText
        : expired
        ? 'Đã hết hạn'
        : soon
        ? 'Sắp hết hạn'
        : 'Còn hiệu lực';
    final message = ended
        ? (c.status == 'Renewed'
              ? 'Hợp đồng này đã được tái ký / gia hạn bằng hợp đồng khác, không còn là hợp đồng hiện hành.'
              : 'Hợp đồng này đã được thanh lý / chấm dứt.')
        : expired
        ? 'Hợp đồng này đã hết hạn hiệu lực. Cần gia hạn hoặc thanh lý/tái ký mới.'
        : soon
        ? 'Hợp đồng sắp hết hạn trong ${c.daysRemaining} ngày tới. Khuyến nghị gia hạn ngay!'
        : 'Hợp đồng đang có hiệu lực sử dụng, còn ${c.daysRemaining} ngày.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.description, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      c.contractNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlight(Color bg, Color border, Widget child) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border),
    ),
    child: child,
  );

  Widget _equipmentRow(ZoneContractEquipmentModel e) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              Text(
                _categoryLabel[e.category] ?? e.category,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${e.quantity} ${e.unit}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              _vnd.format(e.unitPrice),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final total = c.totalContractValueVnd;
    final bp = BusinessParametersStore.current;
    final deposit = c.depositVnd > 0
        ? c.depositVnd
        : total * bp.depositPercent / 100;
    final remaining = (total - deposit).clamp(0, double.infinity).toDouble();
    final totalDevices = c.equipment.fold<int>(0, (s, e) => s + e.quantity);
    // Tỷ lệ cọc và VAT của HỢP ĐỒNG NÀY lấy theo số đã chốt khi ký, không theo cấu hình Platform hiện hành (đổi cấu hình chỉ áp cho hợp đồng chưa cọc).
    final depPct = total > 0 && c.depositVnd > 0
        ? double.parse((c.depositVnd / total * 100).toStringAsFixed(2))
        : bp.depositPercent;
    final depLabel = '${BusinessParameters.fmt(depPct)}%';
    final remLabel =
        '${BusinessParameters.fmt(double.parse((100 - depPct).toStringAsFixed(2)))}%';
    final netBeforeVat = total - c.vatAmountVnd;
    final double? vatPercent = c.vatPercent > 0
        ? c.vatPercent
        : (c.vatAmountVnd > 0 && netBeforeVat > 0
              ? double.parse(
                  (c.vatAmountVnd / netBeforeVat * 100).toStringAsFixed(2),
                )
              : null);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Chi tiết hợp đồng #${c.contractNumber}',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _loading ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton:
            widget.canRenew &&
                (c.status == 'Active' ||
                    c.status == 'Expired' ||
                    c.isExpiringSoon)
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.autorenew),
                label: const Text('Gia hạn'),
                onPressed: () async {
                  final updated = await showRenewContractSheet(context, c);
                  if (updated == null || !mounted) return;
                  _changed = true;
                  setState(() => _c = updated);
                  _snack(
                    this.context,
                    'Đã gia hạn đến ${_d(updated.endDate)}.',
                  );
                },
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Không tải lại được chi tiết: $_error',
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 13,
                    ),
                  ),
                ),
              _statusBanner(c),
              _card(Icons.sell_outlined, 'Thông tin Vị trí & Cây trồng', [
                _row('Trang trại (Farm)', c.farmName),
                _row('Phân khu (Zone)', c.zoneName),
                if ((c.contractPackageName ?? '').isNotEmpty)
                  _row(
                    'Gói hợp đồng',
                    c.isCustomPackage
                        ? '${c.contractPackageName} · Riêng khách hàng'
                        : c.contractPackageName!,
                    color: const Color(0xFF047857),
                  ),
                _row(
                  'Cây trồng áp dụng',
                  (c.cropType ?? '').isEmpty ? 'Rau màu' : c.cropType!,
                  color: const Color(0xFF119653),
                ),
                _row('Ngày bắt đầu', _d(c.startDate)),
                _row('Ngày kết thúc', _d(c.endDate), bold: true),
                if (c.parentContractNumber != null)
                  _row(
                    'Tái ký từ HĐ trước',
                    c.parentContractNumber!,
                    color: const Color(0xFF4338CA),
                    bold: true,
                  ),
              ]),
              _card(Icons.person_outline, 'Thông tin Khách hàng / Bên thuê', [
                _row('Đại diện bên thuê', c.lesseeName, bold: true),
                _row('Số điện thoại', c.lesseePhone ?? '—'),
                _row('Số CCCD / MST', c.lesseeIdentityNumber ?? '—'),
                _row('Địa chỉ liên hệ', c.lesseeAddress ?? '—'),
                _row(
                  'Ngày ký kết',
                  c.signedAtUtc != null ? _d(c.signedAtUtc!) : _d(c.startDate),
                ),
              ]),
              _card(
                Icons.payments_outlined,
                'Bảng tính tiền & thanh toán',
                white: true,
                trailing: 'Đơn vị: VNĐ',
                [
                  _row(
                    '1. Đơn giá thuê tháng',
                    '${_vnd.format(c.monthlyRentVnd)}/tháng',
                  ),
                  _row(
                    '2. Tổng giá trị hợp đồng',
                    _vnd.format(total),
                    bold: true,
                  ),
                  if (c.discountVnd > 0)
                    _row(
                      'Chiết khấu (${c.discountPercent}%)',
                      '-${_vnd.format(c.discountVnd)}',
                      color: const Color(0xFF059669),
                    ),
                  _row(
                    vatPercent == null
                        ? '3. Thuế VAT'
                        : '3. Thuế VAT (${BusinessParameters.fmt(vatPercent)}%)',
                    c.vatAmountVnd > 0
                        ? _vnd.format(c.vatAmountVnd)
                        : 'Đã bao gồm trong tổng gói',
                  ),
                  _highlight(
                    const Color(0xFFFFFBEB),
                    const Color(0xFFFDE68A),
                    _row(
                      '4. Tạm ứng $depLabel khi ký',
                      _vnd.format(deposit),
                      bold: true,
                      color: const Color(0xFF78350F),
                    ),
                  ),
                  _highlight(
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    _row(
                      '5. Còn lại khi nghiệm thu ($remLabel)',
                      _vnd.format(remaining),
                      bold: true,
                    ),
                  ),
                ],
              ),
              _card(
                Icons.memory,
                'Thiết bị theo hợp đồng',
                white: true,
                trailing: c.equipment.isEmpty
                    ? null
                    : '${c.equipment.length} loại · tổng $totalDevices thiết bị',
                [
                  if (c.equipment.isEmpty)
                    const Text(
                      'Hợp đồng này chưa ghi nhận danh mục thiết bị.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  for (final e in c.equipment) _equipmentRow(e),
                ],
              ),
              if ((c.specialTerms ?? '').isNotEmpty ||
                  (c.notes ?? '').isNotEmpty)
                _card(Icons.gavel_outlined, 'Điều khoản đặc biệt & Ghi chú', [
                  if ((c.specialTerms ?? '').isNotEmpty)
                    Text(
                      c.specialTerms!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  if ((c.notes ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        c.notes!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
