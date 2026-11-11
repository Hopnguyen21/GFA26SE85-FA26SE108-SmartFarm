import 'package:flutter/material.dart';
import '../../core/models/iot_deployment.dart';

class QuotationDraft {
  final List<Map<String, dynamic>> items;
  final String notes;
  final String terms;
  const QuotationDraft(this.items, this.notes, this.terms);
}

/// Only opened by the technician while the quotation is unsigned.
class QuotationEditor extends StatefulWidget {
  final Quotation? initial;
  const QuotationEditor({super.key, this.initial});

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

  _Line([QuotationItem? item]) {
    if (item == null) return;
    code.text = item.code;
    notes.text = item.notes ?? '';
    name.text = item.name;
    unit.text = item.unit;
    quantity.text = '${item.quantity}';
    price.text = '${item.unitPrice}';
    vat.text = '${item.vatPercent}';
    category = item.category;
  }

  double get total =>
      (int.tryParse(quantity.text) ?? 0) *
      (double.tryParse(price.text) ?? 0) *
      (1 + (double.tryParse(vat.text) ?? 0) / 100);

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

class _QuotationEditorState extends State<QuotationEditor> {
  final _form = GlobalKey<FormState>();
  late final List<_Line> _lines;
  final _removed = <_Line>[];
  late final TextEditingController _notes;
  late final TextEditingController _terms;

  @override
  void initState() {
    super.initState();
    _lines = widget.initial?.items.map((i) => _Line(i)).toList() ?? [];
    if (_lines.isEmpty) _lines.add(_Line());
    _notes = TextEditingController(text: widget.initial?.notes);
    _terms = TextEditingController(text: widget.initial?.contractTerms);
  }

  @override
  void dispose() {
    for (final line in [..._lines, ..._removed]) {
      line.dispose();
    }
    _notes.dispose();
    _terms.dispose();
    super.dispose();
  }

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập thông tin' : null;

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

  Widget _field(TextEditingController c, String label, {String? Function(String?)? validator, bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: label),
          keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          validator: validator ?? _required,
          onChanged: (_) => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final total = _lines.fold<double>(0, (sum, line) => sum + line.total);
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết bị & hợp đồng lắp đặt')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Điều chỉnh hạng mục theo khảo sát và trao đổi với Owner. '
              'Bảng dự toán ban đầu chỉ để tham khảo. Owner sẽ xem và ký xác nhận báo giá này.',
            ),
            for (final line in _lines)
              Card(
                key: ObjectKey(line),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Hạng mục ${_lines.indexOf(line) + 1}')),
                          IconButton(
                            tooltip: 'Xóa hạng mục',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _lines.length == 1
                                ? null
                                : () => setState(() {
                                    _lines.remove(line);
                                    _removed.add(line);
                                  }),
                          ),
                        ],
                      ),
                      _field(line.code, 'Mã hạng mục'),
                      _field(line.name, 'Tên thiết bị / vật tư / công việc'),
                      DropdownButtonFormField<String>(
                        initialValue: line.category,
                        decoration: const InputDecoration(labelText: 'Loại hạng mục'),
                        items:
                            {
                                  ...['HARDWARE', 'ACCESSORY', 'LABOR'],
                                  line.category,
                                }
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(
                                      {'HARDWARE': 'Thiết bị', 'ACCESSORY': 'Vật tư', 'LABOR': 'Công lắp đặt'}[v] ?? v,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => line.category = v ?? line.category),
                      ),
                      _field(line.unit, 'Đơn vị'),
                      _field(line.notes, 'Ghi chú hạng mục', validator: (_) => null),
                      _field(line.quantity, 'Số lượng', number: true, validator: (v) => _number(v, quantity: true)),
                      _field(line.price, 'Đơn giá (đ)', number: true, validator: (v) => _number(v)),
                      _field(line.vat, 'VAT (%)', number: true, validator: (v) => _number(v, vat: true)),
                      Text('Thành tiền có VAT: ${line.total.isFinite ? line.total.toStringAsFixed(0) : "—"} đ'),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_Line())),
              icon: const Icon(Icons.add),
              label: const Text('Thêm hạng mục'),
            ),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Nội dung trao đổi / lý do bổ sung'),
            ),
            TextFormField(
              controller: _terms,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Điều khoản hợp đồng'),
            ),
            const SizedBox(height: 16),
            Text('Tổng gồm VAT: ${total.isFinite ? total.toStringAsFixed(0) : "—"} đ'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  QuotationDraft(_lines.map((l) => l.toJson()).toList(), _notes.text.trim(), _terms.text.trim()),
                );
              },
              child: const Text('Gửi báo giá để Owner xem và xác nhận'),
            ),
          ],
        ),
      ),
    );
  }
}
