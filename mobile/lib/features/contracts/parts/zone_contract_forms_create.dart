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
  final _voucherCode = TextEditingController();
  bool _validatingVoucher = false;
  Map<String, dynamic>? _appliedVoucher;
  String? _voucherMessage;
  bool _voucherSuccess = false;
  List<Map<String, dynamic>> _availableVouchers = [];
  bool _loadingVouchers = false;
  DateTime _start = DateTime.now();
  int _months = 6; // 0 = tuỳ chọn ngày kết thúc
  DateTime? _customEnd;
  bool _busy = false;

  bool _applyPackage = false;
  String? _selectedPackageId;
  List<Map<String, dynamic>> _packages = [];
  bool _loadingPackages = false;
  String? _packagesError;

  /// Đồng bộ thời hạn HĐ theo gói: 6/12/36 tháng dùng chip có sẵn, số khác (3, 9, 24…) chuyển sang
  /// "Tuỳ chọn" với ngày kết thúc = bắt đầu + số tháng của gói (backend cũng tính theo gói).
  void _syncMonthsToPackage(Map<String, dynamic>? pkg) {
    final m = (pkg?['durationMonths'] as num?)?.toInt() ?? 0;
    if (m <= 0) return;
    if (const [6, 12, 36].contains(m)) {
      _months = m;
    } else {
      _months = 0;
      _customEnd = _addMonths(_start, m);
    }
  }

  DateTime get _end => _months == 0
      ? (_customEnd ?? _addMonths(_start, 6))
      : _addMonths(_start, _months);

  Map<String, dynamic>? get _selectedPackage {
    if (!_applyPackage || _selectedPackageId == null) return null;
    return _packages
        .where((p) => p['id']?.toString() == _selectedPackageId)
        .firstOrNull;
  }

  double get _packagePrice {
    final pkg = _selectedPackage;
    if (pkg == null) return 0;
    return ((pkg['price'] as num?) ?? 0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    BusinessParametersStore.refresh().then((_) {
      if (mounted) setState(() {});
    });
    for (final c in [_rent, _deposit]) {
      c.addListener(() => setState(() {}));
    }
    _discount.addListener(() {
      if (_appliedVoucher != null) {
        final currentPct =
            double.tryParse(_discount.text.trim().replaceAll(',', '.'));
        final voucherPct =
            (_appliedVoucher!['discountPercent'] as num?)?.toDouble();
        if (currentPct != voucherPct) {
          setState(() {
            _appliedVoucher = null;
            _voucherCode.clear();
            _voucherMessage =
                'Đã hủy áp dụng mã vì phần trăm chiết khấu đã thay đổi thủ công.';
            _voucherSuccess = false;
          });
        }
      }
      setState(() {});
    });
    _loadPackages();
    _loadVouchers();
  }

  Future<void> _loadVouchers() async {
    setState(() => _loadingVouchers = true);
    try {
      final list = await ContractApi.getDiscountCodes(activeOnly: true);
      if (mounted) setState(() => _availableVouchers = list);
    } catch (_) {
      // Bỏ qua nếu server chưa sẵn sàng hoặc mạng yếu
    } finally {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  double _rawContractAmount() {
    final rent = _money(_rent) ?? 0;
    final months = contractMonths(_start, _end);
    return (rent * months) + _packagePrice;
  }

  Future<void> _applyVoucherCode(String codeToApply) async {
    final trimmed = codeToApply.trim().toUpperCase();
    if (trimmed.isEmpty) return;
    final raw = _rawContractAmount();
    if (raw <= 0) {
      setState(() {
        _voucherMessage =
            'Vui lòng nhập phí dịch vụ / tháng trước khi áp dụng mã giảm giá.';
        _voucherSuccess = false;
      });
      return;
    }
    setState(() {
      _validatingVoucher = true;
      _voucherMessage = null;
    });
    try {
      final res = await ContractApi.validateDiscountCode(
        code: trimmed,
        contractAmount: raw,
      );
      if (!mounted) return;
      if (res['isValid'] == true) {
        setState(() {
          _appliedVoucher = res;
          final pct = (res['discountPercent'] as num?)?.toDouble() ?? 0.0;
          _discount.text = pct > 0
              ? (pct == pct.roundToDouble()
                    ? pct.toInt().toString()
                    : pct.toString())
              : '';
          _voucherMessage =
              res['message']?.toString() ??
              'Áp dụng mã giảm giá [$trimmed] thành công!';
          _voucherSuccess = true;
          _voucherCode.text = trimmed;
        });
      } else {
        setState(() {
          _voucherMessage =
              res['message']?.toString() ??
              'Mã giảm giá không hợp lệ hoặc chưa đủ điều kiện.';
          _voucherSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _voucherMessage = 'Lỗi kiểm tra mã giảm giá: ${_err(e)}';
          _voucherSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _validatingVoucher = false);
    }
  }

  Future<void> _autoBestVoucher() async {
    final raw = _rawContractAmount();
    if (raw <= 0) {
      setState(() {
        _voucherMessage =
            'Vui lòng nhập phí dịch vụ / tháng trước khi tìm mã ưu đãi.';
        _voucherSuccess = false;
      });
      return;
    }
    setState(() {
      _validatingVoucher = true;
      _voucherMessage = null;
    });
    try {
      final res = await ContractApi.getBestDiscount(raw);
      if (!mounted) return;
      if (res != null && res['hasDiscount'] == true && res['code'] != null) {
        final code = res['code'].toString();
        _voucherCode.text = code;
        await _applyVoucherCode(code);
      } else {
        setState(() {
          _voucherMessage =
              'Hợp đồng hiện tại chưa đủ điều kiện áp dụng mã giảm giá nào.';
          _voucherSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _voucherMessage =
              'Không thể kiểm tra mã giảm giá tự động: ${_err(e)}';
          _voucherSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _validatingVoucher = false);
    }
  }

  void _removeVoucher() {
    setState(() {
      _appliedVoucher = null;
      _voucherCode.clear();
      _discount.clear();
      _voucherMessage = null;
      _voucherSuccess = false;
    });
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loadingPackages = true;
      _packagesError = null;
    });
    try {
      final list = await SupportApi.getContractPackages();
      if (mounted) {
        setState(() {
          _packages = list;
          if (_packages.isNotEmpty && _selectedPackageId == null) {
            _selectedPackageId = _packages.first['id']?.toString();
          }
          if (_applyPackage) _syncMonthsToPackage(_selectedPackage);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _packagesError = _err(e));
    } finally {
      if (mounted) setState(() => _loadingPackages = false);
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
      _voucherCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Chọn HĐ cũ để tái ký: điền sẵn thông tin khách hàng và phí dịch vụ/tháng.
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
    final baseErr = validateZoneContractInput(
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
    if (baseErr != null) return baseErr;
    if (_appliedVoucher != null) {
      final minVal =
          (_appliedVoucher!['minContractValue'] as num?)?.toDouble() ?? 0.0;
      final raw = _rawContractAmount();
      if (minVal > 0 && raw < minVal) {
        return 'Mã [${_appliedVoucher!['code']}] yêu cầu giá trị hợp đồng tối thiểu ${_vnd.format(minVal)} (hiện tại: ${_vnd.format(raw)}). Vui lòng chọn mã khác hoặc điều chỉnh lại giá trị hợp đồng.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (context.read<FarmProvider>().currentRole == 'OWNER') return;
    final err = _validate();
    if (err != null) return _snack(context, err, error: true);
    setState(() => _busy = true);
    String? opt(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    String? notesText = opt(_notes);
    double? discountAmount;
    if (_appliedVoucher != null) {
      final vCode = _appliedVoucher!['code'];
      final raw = _rawContractAmount();
      final pct = double.tryParse(_discount.text.trim().replaceAll(',', '.'));
      double calcAmt = (pct != null && pct > 0) ? (raw * pct / 100) : 0.0;
      final maxDisc =
          (_appliedVoucher!['maxDiscountAmount'] as num?)?.toDouble();
      if (maxDisc != null && maxDisc > 0 && calcAmt > maxDisc) {
        calcAmt = maxDisc;
      }
      final fixedDisc =
          (_appliedVoucher!['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final vAmt = calcAmt > 0 ? calcAmt : fixedDisc;
      if (vAmt > 0) discountAmount = vAmt;
      final vPrefix =
          '[Mã ưu đãi: $vCode - Giảm ${_vnd.format(vAmt)}]. ';
      notesText = vPrefix + (notesText ?? '');
    }
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
        'discountAmount': discountAmount,
        'startDate': _ymd.format(_start),
        'endDate': _ymd.format(_end),
        'lesseeName': _name.text.trim(),
        'lesseePhone': opt(_phone),
        'lesseeIdentityNumber': opt(_cccd),
        'lesseeAddress': opt(_address),
        'specialTerms': opt(_terms),
        'notes': notesText,
        'contractPackageId': _applyPackage ? _selectedPackageId : null,
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
    final rentSubtotal = rent * months;
    final pkgPrice = _packagePrice;
    final raw = rentSubtotal + pkgPrice;
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
          row(
            'Phí dịch vụ ($months × ${_vnd.format(rent)})',
            _vnd.format(rentSubtotal),
          ),
          if (_applyPackage && pkgPrice > 0)
            row(
              'Gói dịch vụ (${_selectedPackage?['packageName'] ?? 'Gói'})',
              '+${_vnd.format(pkgPrice)}',
              bold: true,
            ),
          row('Thành tiền trước CK', _vnd.format(raw)),
          if (_appliedVoucher != null)
            row(
              'Mã ưu đãi [${_appliedVoucher!['code']}] (${pct ?? 0}%)',
              '-${_vnd.format(discount)}',
              bold: true,
            )
          else
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
                'Để trống chiết khấu: backend tự giảm ${BusinessParameters.fmt(BusinessParametersStore.current.repeatPurchaseDiscountPercent)}% nếu khách hàng ký lần 2 trong 60 ngày, ${BusinessParameters.fmt(BusinessParametersStore.current.renewalDiscountPercent)}% nếu tái ký từ HĐ cũ.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _packageSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _applyPackage
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _applyPackage
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text(
                'Đăng ký kèm Gói Dịch Vụ Canh Tác (Contract Package)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const Text(
                'Tích để thêm gói IoT và bảo trì; tiền gói được cộng vào tổng hợp đồng.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              value: _applyPackage,
              onChanged: (v) {
                setState(() {
                  _applyPackage = v ?? false;
                  if (_applyPackage &&
                      _selectedPackageId == null &&
                      _packages.isNotEmpty) {
                    _selectedPackageId = _packages.first['id']?.toString();
                  }
                  if (_applyPackage) _syncMonthsToPackage(_selectedPackage);
                });
              },
            ),
          ),
          if (_applyPackage) ...[
            const Divider(height: 16),
            if (_loadingPackages)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_packagesError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Không tải được danh sách gói: $_packagesError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadPackages,
                    child: const Text('Thử lại'),
                  ),
                ],
              )
            else if (_packages.isEmpty)
              const Text(
                'Chưa có gói dịch vụ nào trong danh mục.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedPackageId,
                isExpanded: true,
                decoration: _dec('Gói dịch vụ áp dụng'),
                items: [
                  for (final p in _packages)
                    DropdownMenuItem(
                      value: p['id']?.toString(),
                      child: Text(
                        '${p['packageName']} (+${_vnd.format((p['price'] as num?) ?? 0)}) · ${p['durationMonths']} th',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                onChanged: (id) {
                  setState(() {
                    _selectedPackageId = id;
                    _syncMonthsToPackage(
                      _packages
                          .where((p) => p['id']?.toString() == id)
                          .firstOrNull,
                    );
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parents = widget.existingContracts;
    final role = context.watch<FarmProvider>().currentRole;
    if (role == 'OWNER' || role == 'FARMER') {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Tạo hợp đồng Zone',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Tạo hợp đồng Zone',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
            decoration: _dec('Khách hàng: họ tên / tên tổ chức *'),
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
                  decoration: _dec('Phí dịch vụ / tháng (₫) *'),
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
          _packageSection(),
          _voucherSection(),
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

  Widget _voucherSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _appliedVoucher != null
            ? const Color(0xFFF0FDF4)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _appliedVoucher != null
              ? const Color(0xFF10B981)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                size: 16,
                color: Color(0xFF047857),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'MÃ GIẢM GIÁ & ƯU ĐÃI',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (_appliedVoucher == null) ...[
                if (_loadingVouchers)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF047857),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _validatingVoucher ? null : _autoBestVoucher,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF047857),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 13),
                    label: const Text(
                      'Tìm mã tốt nhất',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (_appliedVoucher != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_appliedVoucher!['code']}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giảm ${_appliedVoucher!['discountPercent']}% (-${_vnd.format((_appliedVoucher!['discountAmount'] as num?)?.toDouble() ?? 0)})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        if (_voucherMessage != null)
                          Text(
                            _voucherMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF065F46),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: _removeVoucher,
                    tooltip: 'Hủy áp dụng mã',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ] else ...[
            if (_availableVouchers.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: null,
                    hint: Text(
                      '-- Chọn mã ưu đãi có sẵn (${_availableVouchers.length} mã) --',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF047857),
                    ),
                    items: [
                      for (final v in _availableVouchers)
                        DropdownMenuItem<String>(
                          value: '${v['code']}',
                          child: Text(
                            '[${v['code']}] ${v['description'] ?? ''} (-${v['discountValue']}${v['discountType'] == 0 || v['discountType'] == 'Percentage' ? '%' : '₫'})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (code) {
                      if (code != null) {
                        _voucherCode.text = code;
                        _applyVoucherCode(code);
                      }
                    },
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voucherCode,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: _dec(
                      'Mã giảm giá',
                      hint: 'VD: TET2026, TRIAN15',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _validatingVoucher
                      ? null
                      : () => _applyVoucherCode(_voucherCode.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _validatingVoucher
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Áp dụng',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
            if (_voucherMessage != null) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _voucherSuccess
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 14,
                    color: _voucherSuccess
                        ? const Color(0xFF047857)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _voucherMessage!,
                      style: TextStyle(
                        fontSize: 11,
                        color: _voucherSuccess
                            ? const Color(0xFF047857)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_availableVouchers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final v in _availableVouchers.take(4))
                    ActionChip(
                      avatar: const Icon(
                        Icons.discount_outlined,
                        size: 13,
                        color: Color(0xFF047857),
                      ),
                      label: Text(
                        '${v['code']} (-${v['discountValue']}${v['discountType'] == 0 || v['discountType'] == 'Percentage' ? '%' : '₫'})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF047857),
                        ),
                      ),
                      backgroundColor: const Color(0xFFF0FDF4),
                      side: const BorderSide(color: Color(0xFFBBF7D0)),
                      onPressed: () {
                        _voucherCode.text = '${v['code']}';
                        _applyVoucherCode('${v['code']}');
                      },
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
