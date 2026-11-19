import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../support/quotation_editor.dart' show formatMoney;

const _methods = [
  'Chuyển khoản Ngân hàng',
  'Tiền mặt',
  'Ví điện tử (MoMo/ZaloPay)',
];

/// Đọc số tiền người dùng gõ (chấp nhận dấu chấm/phẩy ngăn cách hàng nghìn).
double? parseMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return double.tryParse(digits);
}

typedef BillForm = ({
  String contractId,
  double amount,
  DateTime dueDate,
  String? method,
  String? notes,
});

typedef PaymentForm = ({double amount, String? method, String? notes});

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13.5, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<BillForm?> showCreateBillDialog(
  BuildContext context,
  List<ZoneContractModel> contracts,
) => showDialog<BillForm>(
  context: context,
  builder: (_) => _BillFormDialog(contracts: contracts),
);

Future<BillForm?> showEditBillDialog(BuildContext context, BillModel bill) =>
    showDialog<BillForm>(
      context: context,
      builder: (_) => _BillFormDialog(contracts: const [], editing: bill),
    );

Future<PaymentForm?> showPaymentDialog(BuildContext context, BillModel bill) =>
    showDialog<PaymentForm>(
      context: context,
      builder: (_) => _PaymentDialog(bill: bill),
    );

class _BillFormDialog extends StatefulWidget {
  final List<ZoneContractModel> contracts;
  final BillModel? editing;
  const _BillFormDialog({required this.contracts, this.editing});

  @override
  State<_BillFormDialog> createState() => _BillFormDialogState();
}

class _BillFormDialogState extends State<_BillFormDialog> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  String? _contractId;
  String _method = _methods.first;
  late DateTime _due = DateTime.now().add(const Duration(days: 30));
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _contractId = e.contractId;
      _amount.text = e.amount.round().toString();
      _notes.text = e.notes ?? '';
      _due = e.dueDate ?? _due;
      if (_methods.contains(e.paymentMethod)) _method = e.paymentMethod!;
    } else if (widget.contracts.isNotEmpty) {
      _pickContract(widget.contracts.first.id);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _pickContract(String? id) {
    _contractId = id;
    final c = widget.contracts.where((x) => x.id == id).firstOrNull;
    if (c != null) _amount.text = c.totalContractValueVnd.round().toString();
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _due = picked);
  }

  void _submit() {
    final amount = parseMoney(_amount.text);
    if (_contractId == null) {
      setState(() => _error = 'Vui lòng chọn hợp đồng.');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Số tiền hóa đơn phải lớn hơn 0.');
      return;
    }
    Navigator.pop(context, (
      contractId: _contractId!,
      amount: amount,
      dueDate: _due,
      method: _method,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = _due;
    final dueText =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEdit
            ? 'Sửa hóa đơn ${widget.editing!.billCode}'
            : 'Tạo hóa đơn từ hợp đồng',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isEdit) ...[
              DropdownButtonFormField<String>(
                initialValue: _contractId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Hợp đồng *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  for (final c in widget.contracts)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.contractNumber} (${c.lesseeName})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _pickContract(v)),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số tiền (đ) *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickDue,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text('Hạn thanh toán: $dueText'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Phương thức',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                for (final m in _methods)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _submit,
          child: Text(_isEdit ? 'Lưu' : 'Tạo hóa đơn'),
        ),
      ],
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  final BillModel bill;
  const _PaymentDialog({required this.bill});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(
    text: widget.bill.remainingAmount.round().toString(),
  );
  final _notes = TextEditingController();
  String _method = _methods.first;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Số tiền thanh toán phải lớn hơn 0.');
      return;
    }
    if (amount > widget.bill.remainingAmount + 0.5) {
      setState(
        () => _error =
            'Không thu quá số còn lại (${formatMoney(widget.bill.remainingAmount)}).',
      );
      return;
    }
    Navigator.pop(context, (
      amount: amount,
      method: _method,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Thu tiền ${widget.bill.billCode}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Còn lại: ${formatMoney(widget.bill.remainingAmount)}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFD97706),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Số tiền thu (đ) *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _method,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Phương thức',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              items: [
                for (final m in _methods)
                  DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => _method = v ?? _method),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _submit,
          child: const Text('Ghi nhận thanh toán'),
        ),
      ],
    );
  }
}
