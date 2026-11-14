part of '../zone_contract_forms.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Tạo hợp đồng
// ═══════════════════════════════════════════════════════════════════════════
class ZoneContractCreateScreen extends StatefulWidget {
  final String farmId;
  final List<ZoneModel> zones;
  final List<ZoneContractModel> existingContracts;
  final String? initialZoneId;

  const ZoneContractCreateScreen({
    super.key,
    required this.farmId,
    required this.zones,
    required this.existingContracts,
    this.initialZoneId,
  });

  @override
  State<ZoneContractCreateScreen> createState() =>
      _ZoneContractCreateScreenState();
}

class _ZoneContractCreateScreenState extends State<ZoneContractCreateScreen> {
  late String _zoneId =
      widget.zones.any((z) => z.zoneId == widget.initialZoneId)
      ? widget.initialZoneId!
      : widget.zones.first.zoneId;
  String? _parentId;
  final _number = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _cccd = TextEditingController();
  final _address = TextEditingController();
  final _crop = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  final _discount = TextEditingController();
  final _terms = TextEditingController();
  final _notes = TextEditingController();
  DateTime _start = DateTime.now();
  int _months = 6; // 0 = tuỳ chọn ngày kết thúc
  DateTime? _customEnd;
  bool _busy = false;

  DateTime get _end => _months == 0
      ? (_customEnd ?? _addMonths(_start, 6))
      : _addMonths(_start, _months);

  @override
  void initState() {
    super.initState();
    BusinessParametersStore.refresh().then((_) {
      if (mounted) setState(() {});
    });
    for (final c in [_rent, _deposit, _discount]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _number,
      _name,
      _phone,
      _cccd,
      _address,
      _crop,
      _rent,
      _deposit,
      _discount,
      _terms,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Chọn HĐ cũ để tái ký: điền sẵn thông tin bên thuê và giá thuê.
  void _pickParent(String? id) {
    setState(() => _parentId = id);
    final p = widget.existingContracts.where((c) => c.id == id).firstOrNull;
    if (p == null) return;
    _name.text = p.lesseeName;
    _phone.text = p.lesseePhone ?? '';
    _cccd.text = p.lesseeIdentityNumber ?? '';
    _address.text = p.lesseeAddress ?? '';
    _crop.text = p.cropType ?? '';
    _rent.text = p.monthlyRentVnd.toStringAsFixed(0);
    if (widget.zones.any((z) => z.zoneId == p.zoneId)) _zoneId = p.zoneId;
  }

  String? _validate() {
    final isOwner = context.read<FarmProvider>().canManageFarmStructure;
    final zone = widget.zones.where((z) => z.zoneId == _zoneId).firstOrNull;
    return validateZoneContractInput(
      isOwner: isOwner,
      zoneInSelectedFarm:
          zone != null &&
          zoneBelongsToFarm(zoneFarmId: zone.farmId, farmId: widget.farmId),
      lesseeName: _name.text,
      lesseePhone: _phone.text,
      lesseeIdentity: _cccd.text,
      monthlyRent: _money(_rent),
      start: _start,
      end: _end,
      discountPercentText: _discount.text,
      depositText: _deposit.text,
      depositValue: _money(_deposit),
    );
  }

  Future<void> _submit() async {
    if (context.read<FarmProvider>().currentRole == 'OWNER') return;
    final err = _validate();
    if (err != null) return _snack(context, err, error: true);
    setState(() => _busy = true);
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final created = await ContractApi.createZoneContract(_zoneId, {
        'farmId': widget.farmId,
        'parentContractId': _parentId,
        'contractNumber': opt(_number),
        'cropType': opt(_crop),
        'monthlyRentVnd': _money(_rent),
        'depositVnd':
            _money(_deposit) ??
            0, // 0 → backend lấy theo tỷ lệ cọc đang cấu hình
        'totalContractValueVnd': 0, // 0 → backend tính theo số tháng
        'discountPercent': _discount.text.trim().isEmpty
            ? null
            : double.parse(_discount.text.trim().replaceAll(',', '.')),
        'startDate': _ymd.format(_start),
        'endDate': _ymd.format(_end),
        'lesseeName': _name.text.trim(),
        'lesseePhone': opt(_phone),
        'lesseeIdentityNumber': opt(_cccd),
        'lesseeAddress': opt(_address),
        'specialTerms': opt(_terms),
        'notes': opt(_notes),
      });
      if (!mounted) return;
      await _showSavedDialog(created);
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) _snack(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hiện giá trị CHÍNH THỨC do backend trả về (khác với ước tính trên form).
  Future<void> _showSavedDialog(ZoneContractModel c) {
    Widget row(String l, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
          'Đã lưu hợp đồng Zone',
          style: TextStyle(fontSize: 15),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row('Số hợp đồng', c.contractNumber, bold: true),
              row('Zone', '${c.farmName} → ${c.zoneName}'),
              row('Trạng thái', c.statusText),
              row(
                'Thời hạn',
                '${c.startDate} → ${c.endDate} (còn ${c.daysRemaining} ngày)',
              ),
              row('Giá trị / tháng', _vnd.format(c.monthlyRentVnd)),
              if (c.discountVnd > 0)
                row(
                  'Chiết khấu (${c.discountPercent}%)',
                  '-${_vnd.format(c.discountVnd)}',
                ),
              row('Tiền cọc', _vnd.format(c.depositVnd)),
              row(
                'Tổng giá trị',
                _vnd.format(c.totalContractValueVnd),
                bold: true,
              ),
              const SizedBox(height: 8),
              const Text(
                'Các số trên do máy chủ tính và là giá trị chính thức; số trên form chỉ là ước tính.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget _estimate() {
    final rent = _money(_rent) ?? 0;
    final months = contractMonths(_start, _end);
    final raw = rent * months;
    final discountText = _discount.text.trim();
    final pct = discountText.isEmpty
        ? null
        : double.tryParse(discountText.replaceAll(',', '.'));
    final discount = pct == null ? 0.0 : raw * pct / 100;
    final total = (raw - discount).clamp(0, double.infinity).toDouble();
    final deposit =
        _money(_deposit) ??
        (total * BusinessParametersStore.current.depositPercent / 100)
            .roundToDouble();
    Widget row(String l, String v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              l,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
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
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ƯỚC TÍNH (backend tính số chính thức)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 6),
          row(
            'Thời hạn',
            '$months tháng (${_dmy.format(_start)} → ${_dmy.format(_end)})',
          ),
          row('Thành tiền ($months × ${_vnd.format(rent)})', _vnd.format(raw)),
          row(
            'Chiết khấu',
            pct == null
                ? 'Tự động theo ưu đãi'
                : '-${_vnd.format(discount)} ($pct%)',
          ),
          row(
            'Tổng giá trị',
            pct == null ? '≤ ${_vnd.format(raw)}' : _vnd.format(total),
            bold: true,
          ),
          row(
            'Tạm ứng / cọc',
            _deposit.text.trim().isEmpty
                ? '${BusinessParametersStore.current.depositLabel} tổng (≈ ${_vnd.format(deposit)})'
                : _vnd.format(deposit),
          ),
          if (pct == null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Để trống chiết khấu: backend tự giảm ${BusinessParameters.fmt(BusinessParametersStore.current.repeatPurchaseDiscountPercent)}% nếu bên thuê ký lần 2 trong 60 ngày, ${BusinessParameters.fmt(BusinessParametersStore.current.renewalDiscountPercent)}% nếu tái ký từ HĐ cũ.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.existingContracts;
    if (context.watch<FarmProvider>().currentRole == 'OWNER' ||
        !context.watch<FarmProvider>().canManageFarmStructure) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tạo hợp đồng Zone',
            style: TextStyle(fontSize: 15),
          ),
        ),
        body: const AppEmptyState(
          icon: Icons.lock_outline,
          message:
              'Owner không tự lập hợp đồng. Hãy gửi yêu cầu hỗ trợ kỹ thuật; kỹ thuật viên lập báo giá và hợp đồng để Owner xem, ký xác nhận.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo hợp đồng Zone', style: TextStyle(fontSize: 15)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _zoneId,
            isExpanded: true,
            decoration: _dec('Zone của hợp đồng'),
            items: [
              for (final z in widget.zones)
                DropdownMenuItem(
                  value: z.zoneId,
                  child: Text('${z.name} · ${z.fieldName}'),
                ),
            ],
            onChanged: (v) => setState(() => _zoneId = v ?? _zoneId),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: _parentId,
            isExpanded: true,
            decoration: _dec('Tái ký từ hợp đồng cũ (không bắt buộc)'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('— Khách hàng mới —'),
              ),
              for (final c in parents)
                DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(
                    '${c.contractNumber} · ${c.lesseeName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _pickParent,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _number,
            decoration: _dec(
              'Số hợp đồng',
              helper: 'Để trống để hệ thống tự cấp số.',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'BÊN THUÊ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: _dec('Họ tên / tên tổ chức *'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: _dec('Số điện thoại'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _cccd,
                  decoration: _dec('Số CCCD'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _address,
            decoration: _dec('Địa chỉ thường trú'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _crop, decoration: _dec('Cây trồng dự kiến')),
          const SizedBox(height: 16),
          const Text(
            'THỜI HẠN & TÀI CHÍNH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 16),
                  label: Text('Bắt đầu ${_dmy.format(_start)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => _start = d);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final (m, label) in [
                (6, '6 tháng'),
                (12, '1 năm'),
                (36, '3 năm'),
                (0, 'Tuỳ chọn'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _months == m,
                  onSelected: (_) async {
                    if (m == 0) {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _customEnd ?? _addMonths(_start, 6),
                        firstDate: _start.add(const Duration(days: 1)),
                        lastDate: DateTime(2100),
                      );
                      if (d == null) return;
                      _customEnd = d;
                    }
                    setState(() => _months = m);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _rent,
                  keyboardType: TextInputType.number,
                  decoration: _dec('Giá trị / tháng (₫) *'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _dec('Chiết khấu (%)', hint: 'Tự động'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _deposit,
            keyboardType: TextInputType.number,
            decoration: _dec(
              'Tiền cọc (₫)',
              hint:
                  'Để trống = ${BusinessParametersStore.current.depositLabel} tổng',
            ),
          ),
          const SizedBox(height: 12),
          _estimate(),
          const SizedBox(height: 12),
          TextField(
            controller: _terms,
            maxLines: 3,
            decoration: _dec('Điều khoản đặc biệt'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: _dec('Ghi chú'),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
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
                : const Text('Ký & lưu hợp đồng'),
          ),
        ),
      ),
    );
  }
}
