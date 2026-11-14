import 'package:flutter/material.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/models/models.dart' show BusinessParameters;
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';

/// Kết quả soạn báo giá. [notes] và [terms] cùng là nội dung ô "Ghi chú điều khoản & phạm vi lắp đặt".
class QuotationDraft {
  final List<Map<String, dynamic>> items;
  final String notes;
  final String terms;
  const QuotationDraft(this.items, this.notes, this.terms);
}

/// 12500000 → "12.500.000 đ" (làm tròn đồng).
String formatMoney(double v) {
  final s = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b đ';
}

String formatContractDate(DateTime value) {
  final date = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
}

/// Bảng dự toán thiết bị & hợp đồng lắp đặt, theo bảng trên web: khung đầu hợp đồng, ô điều khoản bắt buộc, bảng dòng
/// (chọn, mã, tên và mô tả, ĐVT, đơn giá, VAT, số lượng, thành tiền), thêm từ kho / nhập ngoài / chọn tất cả,
/// tổng và hai đợt thanh toán (cọc 30%, nghiệm thu 70%).
/// [readOnly]: hợp đồng đã ký hoặc đã cọc, chỉ xem, không sửa.
class QuotationEditor extends StatefulWidget {
  final Quotation? initial;

  /// Dòng dựng sẵn từ "Thiết bị đề xuất & dự toán" Owner đã lưu (chỉ dùng khi chưa có báo giá). Kỹ thuật viên chỉnh theo khảo sát.
  final List<QuotationItem>? estimateItems;

  /// Tiêu đề hợp đồng (ví dụ "Hợp đồng lắp đặt IoT #339E17EB-…"), trang trại và phân khu, hiện ở khung đầu bảng.
  final String? contractTitle;
  final String? farmName;
  final String? zoneName;
  final bool readOnly;

  /// Lời giải thích nguồn dữ liệu khi dòng dựng sẵn là ước tính theo diện tích Zone (Owner chưa lưu dự toán); thay cho câu mặc định.
  final String? proposalNote;
  const QuotationEditor({
    super.key,
    this.initial,
    this.estimateItems,
    this.contractTitle,
    this.farmName,
    this.zoneName,
    this.readOnly = false,
    this.proposalNote,
  });

  @override
  State<QuotationEditor> createState() => _QuotationEditorState();
}

class _Line {
  final notes = TextEditingController();
  final code = TextEditingController();
  final name = TextEditingController();
  final unit = TextEditingController(text: 'Cái');
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final vat = TextEditingController(text: '8');
  String category = 'HARDWARE';
  bool selected = true; // dòng không chọn không đưa vào hợp đồng

  _Line([QuotationItem? item]) {
    if (item == null) return;
    code.text = item.code;
    notes.text = item.notes ?? '';
    name.text = item.name;
    unit.text = item.unit;
    quantity.text = '${item.quantity}';
    price.text = _num(item.unitPrice);
    vat.text = _num(item.vatPercent);
    category = item.category;
  }

  double get _qty => (int.tryParse(quantity.text.trim()) ?? 0).toDouble();
  double get _price => double.tryParse(price.text.trim()) ?? 0;
  double get _vatPct => double.tryParse(vat.text.trim()) ?? 0;

  /// Tiền hàng chưa thuế, thuế VAT và thành tiền của dòng.
  double get net => _qty * _price;
  double get vatAmount => net * _vatPct / 100;
  double get total => net + vatAmount;

  bool get isBlank =>
      code.text.trim().isEmpty &&
      name.text.trim().isEmpty &&
      price.text.trim().isEmpty;

  Map<String, dynamic> toJson() => {
    'notes': notes.text.trim(),
    'code': code.text.trim(),
    'name': name.text.trim(),
    'category': category,
    'unit': unit.text.trim(),
    'quantity': int.parse(quantity.text.trim()),
    'unitPrice': double.parse(price.text.trim()),
    'vatPercent': double.parse(vat.text.trim()),
  };

  void dispose() {
    for (final c in [code, name, unit, quantity, price, vat, notes]) {
      c.dispose();
    }
  }
}

const _categoryLabels = <String, String>{
  'HARDWARE': 'Thiết bị',
  'GATEWAY': 'Gateway',
  'SENSOR_NODE': 'Node cảm biến',
  'ACTUATOR_NODE': 'Node chấp hành',
  'ACCESSORY': 'Vật tư',
  'SERVICE': 'Dịch vụ lắp đặt',
  'LABOR': 'Công lắp đặt',
};

class _QuotationEditorState extends State<QuotationEditor> {
  final _form = GlobalKey<FormState>();
  late final List<_Line> _lines;
  final _removed = <_Line>[];
  late final TextEditingController _terms;
  bool _loadingStock = false;

  bool get _ro => widget.readOnly;

  @override
  void initState() {
    super.initState();
    _lines =
        widget.initial?.items.map((i) => _Line(i)).toList() ??
        [
          for (final i in widget.estimateItems ?? const <QuotationItem>[])
            _Line(i),
        ];
    if (_lines.isEmpty) _lines.add(_Line());
    final saved = widget.initial?.contractTerms?.trim() ?? '';
    _terms = TextEditingController(
      text: saved.isNotEmpty ? saved : widget.initial?.notes,
    );
  }

  @override
  void dispose() {
    for (final line in [..._lines, ..._removed]) {
      line.dispose();
    }
    _terms.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Vui lòng nhập thông tin' : null;

  String? _number(String? v, {bool quantity = false, bool vat = false}) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null ||
        !n.isFinite ||
        n < 0 ||
        (!vat && n == 0) ||
        (vat && n > 100) ||
        (quantity && int.tryParse(v!.trim()) == null)) {
      return quantity
          ? 'Nhập số nguyên dương'
          : vat
          ? 'Nhập VAT từ 0 đến 100'
          : 'Nhập đơn giá lớn hơn 0';
    }
    return null;
  }

  Iterable<_Line> get _chosen => _lines.where((l) => l.selected);

  double get _net => _ro && widget.initial != null
      ? widget.initial!.subtotal
      : _chosen.fold(0, (s, l) => s + l.net);
  double get _vat => _ro && widget.initial != null
      ? widget.initial!.vatAmount
      : _chosen.fold(0, (s, l) => s + l.vatAmount);
  double get _total =>
      _ro && widget.initial != null ? widget.initial!.totalAmount : _net + _vat;

  /// Ô nhập của một dòng; dòng không được chọn không bị kiểm tra bắt buộc, chế độ chỉ đọc khóa ô.
  Widget _field(
    _Line line,
    TextEditingController c,
    String label, {
    String? Function(String?)? validator,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: c,
      enabled: !_ro,
      decoration: InputDecoration(labelText: label, isDense: true),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      validator: (v) => line.selected ? (validator ?? _required)(v) : null,
      onChanged: (_) => setState(() {}),
    ),
  );

  /// Bộ chỉnh số lượng gọn: [−] số [+]; chế độ chỉ đọc hiện chữ "SL".
  Widget _quantityField(_Line line) {
    if (_ro) return Text('SL ${line.quantity.text}');
    void step(int d) {
      final n = (int.tryParse(line.quantity.text.trim()) ?? 0) + d;
      if (n < 1) return;
      setState(() => line.quantity.text = '$n');
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Giảm số lượng',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => step(-1),
        ),
        SizedBox(
          width: 92,
          child: _field(
            line,
            line.quantity,
            'SL',
            number: true,
            validator: (v) => _number(v, quantity: true),
          ),
        ),
        IconButton(
          tooltip: 'Tăng số lượng',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => step(1),
        ),
      ],
    );
  }

  /// Chọn thiết bị từ kho (hộp chọn có tìm kiếm, lọc chủng loại, tồn kho; chọn lại món đã có thì tăng số lượng).
  Future<void> _addFromStock() async {
    if (_loadingStock || _ro) return;
    setState(() => _loadingStock = true);
    List<Map<String, dynamic>> stock;
    try {
      stock = await DeploymentApi.getHardwareItems();
    } catch (e) {
      if (mounted) {
        setState(() => _loadingStock = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loadingStock = false);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _StockPicker(
          stock: stock,
          codesInTable: () => [
            for (final l in _lines) l.code.text.trim().toLowerCase(),
          ],
          tableCount: () => _lines.where((l) => !l.isBlank).length,
          onAdd: _addStockItem,
        ),
      ),
    );
  }

  /// Thêm một món từ kho: đã có cùng mã thì +1 số lượng và chọn lại; chưa có thì thêm dòng mới (đơn giá lấy từ kho,
  /// không có giá thì để trống để kỹ thuật viên nhập, không điền giá giả).
  void _addStockItem(Map<String, dynamic> item) {
    final code = '${item['code'] ?? ''}'.trim();
    setState(() {
      final existing = _lines
          .where(
            (l) =>
                code.isNotEmpty &&
                l.code.text.trim().toLowerCase() == code.toLowerCase(),
          )
          .firstOrNull;
      if (existing != null) {
        existing.quantity.text =
            '${(int.tryParse(existing.quantity.text.trim()) ?? 0) + 1}';
        existing.selected = true;
        return;
      }
      final category = '${item['category'] ?? ''}'.toUpperCase();
      final price = (item['unitPrice'] as num?)?.toDouble() ?? 0;
      final model = '${item['model'] ?? ''}'.trim();
      final maker = '${item['manufacturer'] ?? ''}'.trim();
      final line = _Line()
        ..code.text = code
        ..name.text = '${item['name'] ?? ''}'
        ..category = _categoryOf(category)
        ..unit.text = category.contains('GATEWAY')
            ? 'Trạm'
            : (category.contains('SENSOR') || category.contains('NODE'))
            ? 'Node'
            : 'Bộ'
        ..price.text = price > 0 ? _num(price) : ''
        ..notes.text = model.isEmpty
            ? 'Lấy từ kho vật tư nền tảng'
            : 'Model: $model${maker.isEmpty ? '' : ' ($maker)'}';
      if (_lines.length == 1 && _lines.first.isBlank) {
        _removed.add(_lines.removeAt(0));
      }
      _lines.add(line);
    });
  }

  /// Loại dòng báo giá theo danh mục của kho: gateway, node, vật tư; còn lại để Thiết bị.
  String _categoryOf(String stockCategory) {
    final c = stockCategory.toUpperCase();
    if (const {'GATEWAY', 'SENSOR_NODE', 'ACTUATOR_NODE'}.contains(c)) return c;
    if (c.contains('ACCESSORY') || c.contains('KIT') || c.contains('CABLE')) {
      return 'ACCESSORY';
    }
    return 'HARDWARE';
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_chosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chọn ít nhất một hạng mục đưa vào hợp đồng.'),
        ),
      );
      return;
    }
    final text = _terms.text.trim();
    Navigator.pop(
      context,
      QuotationDraft(_chosen.map((l) => l.toJson()).toList(), text, text),
    );
  }

  /// Một dòng thiết bị/vật tư: tên + mô tả + thành tiền ở đầu; chế độ chỉ đọc là một dòng tóm tắt (ĐVT · đơn giá · VAT · SL),
  /// chế độ sửa có ô Đơn giá / ĐVT / VAT và bộ chỉnh số lượng; mã/tên/loại/ghi chú nằm trong "Sửa chi tiết".
  Widget _lineCard(_Line line) {
    final index = _lines.indexOf(line) + 1;
    final name = line.name.text.trim();
    final desc = line.notes.text.trim();
    final code = line.code.text.trim();
    final total = line.total.isFinite ? formatMoney(line.total) : '—';
    Widget chip(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12.5)),
    );
    return Card(
      key: ObjectKey(line),
      color: line.selected ? null : AppColors.surfaceMuted,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: line.selected,
                  onChanged: _ro
                      ? null
                      : (v) => setState(() => line.selected = v ?? true),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.isEmpty ? 'Hạng mục $index' : code,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name.isEmpty ? 'Chưa nhập tên hạng mục' : name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            height: 1.25,
                          ),
                        ),
                        if (desc.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!_ro)
                  IconButton(
                    tooltip: 'Xóa hạng mục',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, color: AppColors.danger),
                    onPressed: _lines.length == 1
                        ? null
                        : () => setState(() {
                            _lines.remove(line);
                            _removed.add(line);
                          }),
                  ),
              ],
            ),
            if (_ro)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 0, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          chip(line.unit.text.trim()),
                          chip('Đơn giá ${formatMoney(line._price)}'),
                          chip('VAT ${line.vat.text.trim()}%'),
                          chip('SL ${line.quantity.text.trim()}'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      total,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _field(
                        line,
                        line.price,
                        'Đơn giá (đ)',
                        number: true,
                        validator: (v) => _number(v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 84, child: _field(line, line.unit, 'ĐVT')),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 84,
                      child: _field(
                        line,
                        line.vat,
                        'VAT %',
                        number: true,
                        validator: (v) => _number(v, vat: true),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    _quantityField(line),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            total,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey(line),
                  initiallyExpanded: line.isBlank,
                  maintainState: true,
                  tilePadding: const EdgeInsets.only(left: 8, right: 4),
                  dense: true,
                  title: const Text(
                    'Sửa chi tiết (mã, tên, loại, ghi chú)',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Column(
                        children: [
                          _field(line, line.code, 'Mã hạng mục'),
                          _field(
                            line,
                            line.name,
                            'Tên thiết bị / vật tư / công việc',
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: line.category,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Loại hạng mục',
                              isDense: true,
                            ),
                            items:
                                {
                                      ...['HARDWARE', 'ACCESSORY', 'LABOR'],
                                      line.category,
                                    }
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(_categoryLabels[v] ?? v),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) => setState(
                              () => line.category = v ?? line.category,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _field(
                            line,
                            line.notes,
                            'Mô tả / ghi chú hạng mục',
                            validator: (_) => null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moneyRow(String label, double value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.normal,
                  fontSize: strong ? 15 : 13,
                ),
              ),
            ),
            Text(
              formatMoney(value),
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                fontSize: strong ? 15 : 13,
              ),
            ),
          ],
        ),
      );

  Widget _payBox(String label, double value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(
            formatMoney(value),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    ),
  );

  Widget _banner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primaryDark,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (_ro)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.lock, color: Colors.amber, size: 16),
              ),
            Expanded(
              child: Text(
                widget.contractTitle ?? 'Hợp đồng lắp đặt IoT',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            if (widget.farmName != null)
              Text(
                'Trang trại: ${widget.farmName}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            if (widget.zoneName != null)
              Text(
                'Phân khu: ${widget.zoneName}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Khách hàng: Chủ trang trại',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen.length;
    final allSelected = chosen == _lines.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ro
              ? 'Hợp đồng triển khai IoT (đã khóa)'
              : 'Bảng dự toán thiết bị & hợp đồng lắp đặt',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _banner(),
            if (widget.initial case final q?) ...[
              SelectableText('Mã hợp đồng: ${q.id}'),
              if (q.createdAtUtc != null)
                Text('Ngày lập: ${formatContractDate(q.createdAtUtc!)}'),
              if (_ro &&
                  q.notes?.trim().isNotEmpty == true &&
                  q.notes?.trim() != q.contractTerms?.trim())
                Text('Ghi chú bổ sung: ${q.notes}'),
            ],
            if (_ro) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Text(
                  'Hợp đồng đã được chủ trang trại ký và thanh toán cọc. Kỹ thuật viên không được sửa danh mục thiết bị, số lượng, đơn giá và điều khoản; đang ở chế độ chỉ xem.',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                widget.proposalNote != null
                    ? widget.proposalNote!
                    : widget.initial == null &&
                          (widget.estimateItems?.isNotEmpty ?? false)
                    ? 'Đã dựng sẵn ${widget.estimateItems!.length} hạng mục từ phần "Thiết bị đề xuất & dự toán" mà Owner đã gửi cùng yêu cầu. '
                          'Chỉnh số lượng, đơn giá theo khảo sát thực địa; Owner sẽ xem và ký xác nhận báo giá này.'
                    : 'Điều chỉnh hạng mục theo khảo sát và trao đổi với Owner. '
                          'Owner sẽ xem và ký xác nhận báo giá này.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _terms,
              enabled: !_ro,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ghi chú điều khoản & phạm vi lắp đặt *',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            Text(
              'BẢNG BÁO GIÁ THIẾT BỊ & VẬT TƯ IOT ($chosen/${_lines.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            if (!_ro) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    onPressed: _loadingStock ? null : _addFromStock,
                    icon: const Icon(Icons.warehouse_outlined, size: 18),
                    label: const Text('Thêm thiết bị từ kho'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _lines.add(_Line())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nhập ngoài'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      for (final l in _lines) {
                        l.selected = !allSelected;
                      }
                    }),
                    child: Text(allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả'),
                  ),
                ],
              ),
            ],
            for (final line in _lines) _lineCard(line),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _moneyRow('Tiền hàng chưa thuế', _net),
                  _moneyRow('Thuế VAT', _vat),
                  const Divider(),
                  _moneyRow('TỔNG GIÁ TRỊ HỢP ĐỒNG', _total, strong: true),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _payBox(
                        'TẠM ỨNG ${(_ro && widget.initial != null ? widget.initial!.depositLabel : BusinessParameters.active.depositLabel)} KHI KÝ HĐ (OWNER CỌC)',
                        _ro && widget.initial != null
                            ? widget.initial!.deposit30
                            : _total *
                                  BusinessParameters.active.depositPercent /
                                  100,
                        AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _payBox(
                        'THANH TOÁN ${(_ro && widget.initial != null ? widget.initial!.remainingLabel : BusinessParameters.active.remainingLabel)} KHI NGHIỆM THU',
                        _ro && widget.initial != null
                            ? widget.initial!.remaining70
                            : _total *
                                  BusinessParameters.active.remainingPercent /
                                  100,
                        AppColors.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _ro
                  ? 'Hợp đồng đã có giá trị và đã nhận thanh toán cọc.'
                  : 'Sau khi gửi, Owner sẽ nhận được hợp đồng để ký và đặt cọc ${BusinessParameters.active.depositLabel}.',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_ro ? 'Đóng' : 'Hủy bỏ'),
                ),
                if (!_ro) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Xác nhận & gửi hợp đồng cho khách'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp chọn thiết bị từ kho: tìm theo mã/tên/model/loại, lọc chủng loại, hiện tồn kho và đơn giá.
/// Giữ mở để chọn nhiều món; món đã có trong bảng hiện "Thêm (+1)".
class _StockPicker extends StatefulWidget {
  final List<Map<String, dynamic>> stock;
  final List<String> Function() codesInTable;
  final int Function() tableCount;
  final void Function(Map<String, dynamic>) onAdd;
  const _StockPicker({
    required this.stock,
    required this.codesInTable,
    required this.tableCount,
    required this.onAdd,
  });

  @override
  State<_StockPicker> createState() => _StockPickerState();
}

class _StockPickerState extends State<_StockPicker> {
  static const _filters = <(String, String)>[
    ('ALL', 'Tất cả chủng loại'),
    ('GATEWAY', 'Gateway'),
    ('SENSOR', 'Cảm biến'),
    ('VALVE', 'Van'),
    ('PUMP', 'Bơm'),
  ];
  final _search = TextEditingController();
  String _filter = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.toLowerCase().trim();
    return [
      for (final s in widget.stock)
        if ((_filter == 'ALL' ||
                '${s['category'] ?? ''}'.toUpperCase().contains(_filter)) &&
            (q.isEmpty ||
                [
                  s['code'],
                  s['name'],
                  s['model'],
                  s['category'],
                ].any((v) => '${v ?? ''}'.toLowerCase().contains(q))))
          s,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final inTable = widget.codesInTable();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Chọn thiết bị & vật tư từ kho nền tảng',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm theo mã hàng, tên thiết bị, model...',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final (code, label) in _filters)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _filter == code,
                    onSelected: (_) => setState(() => _filter = code),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('Không tìm thấy thiết bị nào phù hợp trong kho.'),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final code = '${s['code'] ?? ''}';
                    final already = inTable.contains(code.toLowerCase());
                    final stock = s['quantityInStock'] as num?;
                    final price = (s['unitPrice'] as num?)?.toDouble() ?? 0;
                    final model = '${s['model'] ?? ''}'.trim();
                    return ListTile(
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              code,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s['category'] ?? 'THIẾT BỊ'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (stock != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Tồn kho: $stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: stock > 0
                                    ? AppColors.primaryDark
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '${s['name'] ?? ''}'
                        '${model.isEmpty ? '' : '\nModel: $model'}'
                        '\nĐơn giá: ${price > 0 ? formatMoney(price) : 'chưa có giá'}',
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () {
                          widget.onAdd(s);
                          setState(() {});
                        },
                        child: Text(already ? 'Thêm (+1)' : 'Chọn'),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Đã có ${widget.tableCount()} thiết bị trong bảng báo giá',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hoàn tất chọn'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Số không có phần thập phân thừa: 2150000.0 → 2150000, 8.5 giữ nguyên.
String _num(num v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();
