import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../support/quotation_editor.dart' show formatMoney;
import 'bill_dialogs.dart';
import 'discount_codes_sheet.dart';
import 'payos_payment_sheet.dart';
import '../../core/utils/user_error.dart';

const _kGreen = Color(0xFF119653);

const _statusFilters = <(String, String)>[
  ('ALL', 'Tất cả'),
  ('Issued', 'Chờ thanh toán'),
  ('PartiallyPaid', 'Thanh toán 1 phần'),
  ('Paid', 'Đã thanh toán'),
  ('Overdue', 'Quá hạn'),
  ('Cancelled', 'Đã hủy'),
];

({String text, Color bg, Color fg}) billStatusStyle(String status) =>
    switch (status) {
      'Paid' => (
        text: 'Đã thanh toán',
        bg: const Color(0xFFD1FAE5),
        fg: const Color(0xFF065F46),
      ),
      'PartiallyPaid' => (
        text: 'Thanh toán 1 phần',
        bg: const Color(0xFFFEF3C7),
        fg: const Color(0xFF92400E),
      ),
      'Issued' => (
        text: 'Chờ thanh toán',
        bg: const Color(0xFFDBEAFE),
        fg: const Color(0xFF1E40AF),
      ),
      'Overdue' => (
        text: 'Quá hạn',
        bg: const Color(0xFFFFE4E6),
        fg: const Color(0xFF9F1239),
      ),
      'Cancelled' => (
        text: 'Đã hủy',
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF475569),
      ),
      _ => (
        text: 'Bản nháp',
        bg: const Color(0xFFF1F5F9),
        fg: const Color(0xFF334155),
      ),
    };

String billDate(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Hóa đơn & thu phí theo hợp đồng Zone (như web `BillsPage`).
/// Owner chỉ xem lịch sử; kỹ thuật viên tạo hóa đơn, thu tiền, hủy, sửa, xóa.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  List<BillModel> _bills = [];
  List<ZoneContractModel> _contracts = [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';
  String _contractId = 'ALL';
  final _search = TextEditingController();

  bool get _isManager =>
      context.read<FarmProvider>().currentRole == 'TECHNICIAN';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bills = await BillApi.getBills();
      List<ZoneContractModel> contracts = _contracts;
      try {
        contracts = await ContractApi.getZoneContracts();
      } catch (_) {
        // Danh sách hợp đồng chỉ phục vụ bộ lọc và tạo hóa đơn: không tải được thì vẫn xem được hóa đơn.
      }
      if (!mounted) return;
      setState(() {
        _bills = bills;
        _contracts = contracts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  List<BillModel> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final b in _bills)
        if ((q.isEmpty ||
                b.billCode.toLowerCase().contains(q) ||
                b.contractNumber.toLowerCase().contains(q) ||
                b.lesseeName.toLowerCase().contains(q)) &&
            (_status == 'ALL' || b.status == _status) &&
            (_contractId == 'ALL' || b.contractId == _contractId))
          b,
    ];
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFDC2626) : _kGreen,
      ),
    );
  }

  /// Chạy một thao tác ghi, rồi tải lại; lỗi hiện nguyên lý do từ backend.
  Future<bool> _act(Future<void> Function() call, String ok) async {
    try {
      await call();
      if (!mounted) return true;
      _toast(ok);
      await _load();
      return true;
    } catch (e) {
      if (mounted) {
        _toast(userFacingError(e), error: true);
      }
      return false;
    }
  }

  Future<void> _create() async {
    final r = await showCreateBillDialog(context, _contracts);
    if (r == null) return;
    await _act(
      () => BillApi.createFromContract(
        contractId: r.contractId,
        amount: r.amount,
        dueDate: r.dueDate,
        paymentMethod: r.method,
        notes: r.notes,
      ),
      'Đã tạo hóa đơn.',
    );
  }

  Future<bool> _collect(BillModel b) async {
    final r = await showPaymentDialog(context, b);
    if (r == null) return false;
    return _act(
      () => BillApi.recordPayment(
        b.id,
        paymentAmount: r.amount,
        paymentMethod: r.method,
        notes: r.notes,
      ),
      'Đã ghi nhận thanh toán ${formatMoney(r.amount)}.',
    );
  }

  Future<bool> _edit(BillModel b) async {
    final r = await showEditBillDialog(context, b);
    if (r == null) return false;
    return _act(
      () => BillApi.update(
        b.id,
        amount: r.amount,
        dueDate: r.dueDate,
        paymentMethod: r.method,
        notes: r.notes,
      ),
      'Đã cập nhật hóa đơn.',
    );
  }

  Future<bool> _cancel(BillModel b) async {
    final ok = await confirmDialog(
      context,
      title: 'Hủy hóa đơn?',
      message: 'Hóa đơn ${b.billCode} sẽ chuyển sang trạng thái Đã hủy.',
      action: 'Hủy hóa đơn',
    );
    if (!ok) return false;
    return _act(
      () => BillApi.updateStatus(
        b.id,
        'Cancelled',
        notes: 'Hủy bởi người quản lý',
      ),
      'Đã hủy hóa đơn.',
    );
  }

  Future<bool> _delete(BillModel b) async {
    final ok = await confirmDialog(
      context,
      title: 'Xóa vĩnh viễn hóa đơn?',
      message:
          'Hóa đơn ${b.billCode} sẽ bị xóa và không thể hoàn tác. Chỉ hóa đơn nháp hoặc đã hủy mới xóa được.',
      action: 'Xóa',
    );
    if (!ok) return false;
    return _act(() => BillApi.delete(b.id), 'Đã xóa hóa đơn.');
  }

  Future<void> _payWithPayOS(BillModel b) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: PayOSPaymentSheet(
          bill: b,
          onPaymentSuccess: _load,
        ),
      ),
    );
    if (result == true) {
      _load();
    }
  }

  Future<void> _openDetail(BillModel b) async {
    final manager = _isManager;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BillDetailSheet(
        bill: b,
        manager: manager,
        onPayWithPayOS: () {
          Navigator.pop(ctx);
          _payWithPayOS(b);
        },
        onCollect: () async {
          if (await _collect(b) && ctx.mounted) Navigator.pop(ctx);
        },
        onEdit: () async {
          if (await _edit(b) && ctx.mounted) Navigator.pop(ctx);
        },
        onCancel: () async {
          if (await _cancel(b) && ctx.mounted) Navigator.pop(ctx);
        },
        onDelete: () async {
          if (await _delete(b) && ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = _isManager;
    final list = _filtered;
    final total = list
        .where((b) => !b.isCancelled)
        .fold<double>(0, (s, b) => s + b.amount);
    final paid = list
        .where((b) => !b.isCancelled)
        .fold<double>(0, (s, b) => s + b.paidAmount);
    final remaining = list
        .where((b) => !b.isCancelled)
        .fold<double>(0, (s, b) => s + b.remainingAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: Text(
          manager ? 'Hóa đơn & Thu phí' : 'Giao dịch & Hóa đơn',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Mã giảm giá & Khuyến mãi',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: () {
              final unpaidTotal = list
                  .where((b) => b.status != 'Paid' && b.status != 'Cancelled')
                  .fold<double>(0, (sum, b) => sum + b.remainingAmount);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => FractionallySizedBox(
                  heightFactor: 0.85,
                  child: DiscountCodesSheet(
                    currentAmount: unpaidTotal > 0 ? unpaidTotal : 1000000.0,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: manager
          ? FloatingActionButton.extended(
              backgroundColor: _kGreen,
              foregroundColor: Colors.white,
              onPressed: _contracts.isEmpty ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text('Tạo hóa đơn từ hợp đồng'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
          children: [
            Text(
              manager
                  ? 'Hóa đơn liên kết hợp đồng Zone: theo dõi các đợt thanh toán, công nợ và lịch sử thu tiền.'
                  : 'Lịch sử các đợt phát hành hóa đơn, số tiền đã thanh toán và biên nhận theo hợp đồng canh tác.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm mã hóa đơn, mã hợp đồng, khách hàng...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            if (_contracts.isNotEmpty) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _contractId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Hợp đồng',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('-- Tất cả hợp đồng --'),
                  ),
                  for (final c in _contracts)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.contractNumber} (${c.lesseeName})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _contractId = v ?? 'ALL'),
              ),
            ],
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (key, label) in _statusFilters)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        selected: _status == key,
                        selectedColor: _kGreen,
                        labelStyle: TextStyle(
                          color: _status == key
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                        onSelected: (_) => setState(() => _status = key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!_loading && _error == null && list.isNotEmpty)
              _summary(total, paid, remaining),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDA4AF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Không tải được hóa đơn: $_error',
                      style: const TextStyle(color: Color(0xFF9F1239)),
                    ),
                    TextButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                ),
              )
            else if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 40,
                      color: Color(0xFFCBD5E1),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Không có hóa đơn nào phù hợp.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              for (final b in list) _billCard(b, manager),
          ],
        ),
      ),
    );
  }

  Widget _summary(double total, double paid, double remaining) {
    Widget cell(String label, double v, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(v),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          cell('Tổng', total, const Color(0xFF0F172A)),
          const SizedBox(width: 8),
          cell('Đã thu', paid, const Color(0xFF047857)),
          const SizedBox(width: 8),
          cell('Còn lại', remaining, const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _billCard(BillModel b, bool manager) {
    final st = billStatusStyle(b.status);
    final overdueSoon =
        b.canCollect &&
        b.dueDate != null &&
        b.dueDate!.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(b),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      b.billCode,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: st.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: st.fg.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      st.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: st.fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'HĐ ${b.contractNumber} · ${b.lesseeName}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _money('Tổng tiền', b.amount, const Color(0xFF0F172A)),
                  _money(
                    'Đã thanh toán',
                    b.paidAmount,
                    const Color(0xFF047857),
                  ),
                  _money('Còn lại', b.remainingAmount, const Color(0xFFD97706)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: overdueSoon
                        ? const Color(0xFFBE123C)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Hạn thanh toán: ${billDate(b.dueDate)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: overdueSoon
                            ? const Color(0xFFBE123C)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (b.remainingAmount > 0 && b.status != 'Cancelled' && b.status != 'Paid')
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: FilledButton.icon(
                        onPressed: () => _payWithPayOS(b),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 15),
                        label: const Text('PayOS QR', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (manager && b.canCollect)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => _collect(b),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 15),
                        label: const Text('Thu tiền', style: TextStyle(fontSize: 11.5)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _money(String label, double v, Color c) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        Text(
          formatMoney(v),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c),
        ),
      ],
    ),
  );
}

class _BillDetailSheet extends StatelessWidget {
  final BillModel bill;
  final bool manager;
  final VoidCallback onPayWithPayOS;
  final VoidCallback onCollect;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  const _BillDetailSheet({
    required this.bill,
    required this.manager,
    required this.onPayWithPayOS,
    required this.onCollect,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final st = billStatusStyle(bill.status);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hóa đơn ${bill.billCode}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: st.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    st.text,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: st.fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            row('Hợp đồng', bill.contractNumber),
            row('Khách hàng', bill.lesseeName),
            row('Tổng tiền', formatMoney(bill.amount)),
            row('Đã thanh toán', formatMoney(bill.paidAmount)),
            row('Còn lại', formatMoney(bill.remainingAmount)),
            row('Ngày phát hành', billDate(bill.issueDate)),
            row('Hạn thanh toán', billDate(bill.dueDate)),
            if (bill.paidDate != null)
              row('Ngày thanh toán', billDate(bill.paidDate)),
            if ((bill.paymentMethod ?? '').isNotEmpty)
              row('Phương thức', bill.paymentMethod!),
            if (bill.createdByName.isNotEmpty)
              row('Người lập', bill.createdByName),
            if ((bill.notes ?? '').isNotEmpty) row('Ghi chú', bill.notes!),
            if (bill.remainingAmount > 0 && bill.status != 'Cancelled' && bill.status != 'Paid') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPayWithPayOS,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text(
                    'Thanh toán PayOS (VietQR)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (manager) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (bill.canCollect)
                    FilledButton.icon(
                      onPressed: onCollect,
                      style: FilledButton.styleFrom(backgroundColor: _kGreen),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Thu tiền'),
                    ),
                  if (bill.canEdit)
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Sửa'),
                    ),
                  if (!bill.isCancelled && bill.status != 'Paid')
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Hủy hóa đơn'),
                    ),
                  if (bill.canDelete)
                    OutlinedButton.icon(
                      onPressed: onDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Xóa'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
