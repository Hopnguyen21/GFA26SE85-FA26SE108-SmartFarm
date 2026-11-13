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
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );

  String _d(String raw) {
    final d = DateTime.tryParse(raw);
    return d == null ? raw : _dmy.format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final subtotal = c.subtotalVnd > 0
        ? c.subtotalVnd
        : c.totalContractValueVnd - c.vatAmountVnd + c.discountVnd;
    final equipmentTotal = c.equipment.fold<double>(
      0,
      (s, e) => s + e.lineTotal,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'HĐ ${c.contractNumber}',
            style: const TextStyle(fontSize: 15),
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
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(
                '${c.farmName} → ${c.zoneName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${c.statusText} · còn ${c.daysRemaining} ngày',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              if (c.parentContractNumber != null)
                Text(
                  'Tái ký từ HĐ ${c.parentContractNumber}',
                  style: const TextStyle(fontSize: 12),
                ),
              _section('BÊN THUÊ', [
                _row('Họ tên', c.lesseeName),
                _row('Điện thoại', c.lesseePhone ?? '—'),
                _row('CCCD', c.lesseeIdentityNumber ?? '—'),
                _row('Địa chỉ', c.lesseeAddress ?? '—'),
                if (c.cropType != null) _row('Cây trồng', c.cropType!),
              ]),
              _section('THỜI HẠN', [
                _row('Bắt đầu', _d(c.startDate)),
                _row('Kết thúc', _d(c.endDate)),
                if (c.signedAtUtc != null) _row('Ký lúc', _d(c.signedAtUtc!)),
              ]),
              _section('TÀI CHÍNH', [
                _row('Giá trị / tháng', _vnd.format(c.monthlyRentVnd)),
                _row('Thành tiền', _vnd.format(subtotal)),
                if (c.discountVnd > 0)
                  _row(
                    'Chiết khấu (${c.discountPercent}%)',
                    '-${_vnd.format(c.discountVnd)}',
                    color: const Color(0xFF059669),
                  ),
                if (c.vatAmountVnd > 0)
                  _row('VAT (${c.vatPercent}%)', _vnd.format(c.vatAmountVnd)),
                _row(
                  'Tổng giá trị hợp đồng',
                  _vnd.format(c.totalContractValueVnd),
                  bold: true,
                ),
                _row('Đã tạm ứng / cọc', _vnd.format(c.depositVnd)),
                _row(
                  'Còn lại',
                  _vnd.format(
                    (c.totalContractValueVnd - c.depositVnd).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                ),
              ]),
              _section('THIẾT BỊ KÈM THEO (${c.equipment.length})', [
                if (c.equipment.isEmpty)
                  const Text(
                    'Hợp đồng không kèm thiết bị.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                for (final e in c.equipment)
                  _row(
                    '${e.name} (${e.code}) × ${e.quantity} ${e.unit}',
                    _vnd.format(e.lineTotal),
                  ),
                if (c.equipment.isNotEmpty)
                  _row(
                    'Cộng thiết bị',
                    _vnd.format(equipmentTotal),
                    bold: true,
                  ),
              ]),
              if ((c.specialTerms ?? '').isNotEmpty)
                _section('ĐIỀU KHOẢN ĐẶC BIỆT', [
                  Text(c.specialTerms!, style: const TextStyle(fontSize: 12)),
                ]),
              if ((c.notes ?? '').isNotEmpty)
                _section('GHI CHÚ', [
                  Text(c.notes!, style: const TextStyle(fontSize: 12)),
                ]),
              _section('LỊCH SỬ GIA HẠN (${c.renewals.length})', [
                if (c.renewals.isEmpty)
                  const Text(
                    'Chưa gia hạn lần nào.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                for (final (i, r) in c.renewals.indexed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row(
                          'Lần ${c.renewals.length - i}: đến ${_d(r.newEndDate)}',
                          _vnd.format(r.renewalValueVnd),
                          bold: true,
                        ),
                        if (r.newMonthlyRentVnd != null)
                          _row('Giá trị mới', _vnd.format(r.newMonthlyRentVnd)),
                        if ((r.notes ?? '').isNotEmpty)
                          Text(
                            r.notes!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                            ),
                          ),
                        Text(
                          'Tạo lúc ${_d(r.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
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
