part of '../zone_contract_forms.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Gia hạn hợp đồng
// ═══════════════════════════════════════════════════════════════════════════
/// Trả về hợp đồng sau gia hạn, hoặc null nếu huỷ.
Future<ZoneContractModel?> showRenewContractSheet(
  BuildContext context,
  ZoneContractModel contract,
) async {
  if (context.read<FarmProvider>().currentRole == 'OWNER' ||
      !context.read<FarmProvider>().canManageFarmStructure) {
    showAppSnack(
      context,
      'Hãy gửi yêu cầu hỗ trợ để thống nhất gia hạn hợp đồng với kỹ thuật viên.',
      error: true,
    );
    return null;
  }
  return showModalBottomSheet<ZoneContractModel>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RenewSheet(contract: contract),
  );
}

class _RenewSheet extends StatefulWidget {
  final ZoneContractModel contract;
  const _RenewSheet({required this.contract});
  @override
  State<_RenewSheet> createState() => _RenewSheetState();
}

class _RenewSheetState extends State<_RenewSheet> {
  String _preset = '1_YEAR';
  DateTime? _customEnd;
  late final _rent = TextEditingController(
    text: widget.contract.monthlyRentVnd.toStringAsFixed(0),
  );
  final _discount = TextEditingController();
  String _discountType = 'AUTO'; // AUTO | PERCENT | AMOUNT
  final _notes = TextEditingController();
  bool _busy = false;

  DateTime get _baseEnd =>
      DateTime.tryParse(widget.contract.endDate) ?? DateTime.now();

  DateTime get _newEnd => switch (_preset) {
    '6_MONTHS' => _addMonths(_baseEnd, 6),
    '1_YEAR' => _addMonths(_baseEnd, 12),
    '3_YEARS' => _addMonths(_baseEnd, 36),
    _ => _customEnd ?? _addMonths(_baseEnd, 6),
  };

  @override
  void initState() {
    super.initState();
    _rent.addListener(() => setState(() {}));
    _discount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _rent.dispose();
    _discount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rent = _money(_rent);
    if (rent == null || rent <= 0)
      return _snack(context, 'Giá trị phải > 0.', error: true);
    if (_preset == 'CUSTOM' &&
        (_customEnd == null || !_customEnd!.isAfter(_baseEnd))) {
      return _snack(
        context,
        'Chọn ngày kết thúc mới sau ${_dmy.format(_baseEnd)}.',
        error: true,
      );
    }
    double? pct, amount;
    if (_discountType == 'PERCENT') {
      pct = double.tryParse(_discount.text.trim().replaceAll(',', '.'));
      if (pct == null || pct < 0 || pct > 50)
        return _snack(context, 'Chiết khấu từ 0 đến 50%.', error: true);
    } else if (_discountType == 'AMOUNT') {
      amount = _money(_discount);
      if (amount == null || amount < 0)
        return _snack(context, 'Số tiền chiết khấu không hợp lệ.', error: true);
    }
    setState(() => _busy = true);
    try {
      final updated = await ContractApi.renewZoneContract(widget.contract.id, {
        'durationPreset': _preset,
        'customEndDate': _preset == 'CUSTOM' ? _ymd.format(_customEnd!) : null,
        'newMonthlyRentVnd': rent == widget.contract.monthlyRentVnd
            ? null
            : rent,
        'discountPercent': pct,
        'discountAmount': amount,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(context, _err(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rent = _money(_rent) ?? widget.contract.monthlyRentVnd;
    final months = contractMonths(_baseEnd, _newEnd);
    final raw = rent * months;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gia hạn HĐ ${widget.contract.contractNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Hết hạn hiện tại: ${_dmy.format(_baseEnd)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                for (final (p, label) in [
                  ('6_MONTHS', '6 tháng'),
                  ('1_YEAR', '1 năm'),
                  ('3_YEARS', '3 năm'),
                  ('CUSTOM', 'Tuỳ chọn'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _preset == p,
                    onSelected: (_) async {
                      if (p == 'CUSTOM') {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _customEnd ?? _addMonths(_baseEnd, 6),
                          firstDate: _baseEnd.add(const Duration(days: 1)),
                          lastDate: DateTime(2100),
                        );
                        if (d == null) return;
                        _customEnd = d;
                      }
                      setState(() => _preset = p);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _rent,
              keyboardType: TextInputType.number,
              decoration: _dec('Giá trị / tháng (₫)'),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'AUTO', label: Text('Ưu đãi tự động')),
                ButtonSegment(value: 'PERCENT', label: Text('%')),
                ButtonSegment(value: 'AMOUNT', label: Text('Số tiền')),
              ],
              selected: {_discountType},
              onSelectionChanged: (s) => setState(() {
                _discountType = s.first;
                _discount.clear();
              }),
            ),
            if (_discountType != 'AUTO') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _dec(
                  _discountType == 'PERCENT'
                      ? 'Chiết khấu (%) 0–50'
                      : 'Chiết khấu (₫)',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Gia hạn $months tháng đến ${_dmy.format(_newEnd)} · thành tiền trước chiết khấu ${_vnd.format(raw)}.'
              '${_discountType == 'AUTO' ? ' Backend tự giảm 15% (ký lại trong 60 ngày) hoặc 10%.' : ''}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: _dec('Ghi chú gia hạn'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Xác nhận gia hạn'),
            ),
          ],
        ),
      ),
    );
  }
}
