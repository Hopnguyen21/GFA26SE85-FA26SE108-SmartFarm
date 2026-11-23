import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/user_error.dart';
import '../support/quotation_editor.dart' show formatMoney;

/// Bảng thanh toán trực tuyến quét mã VietQR qua cổng PayOS (`/api/v1/payments/payos`).
class PayOSPaymentSheet extends StatefulWidget {
  final BillModel bill;
  final VoidCallback? onPaymentSuccess;

  const PayOSPaymentSheet({
    super.key,
    required this.bill,
    this.onPaymentSuccess,
  });

  @override
  State<PayOSPaymentSheet> createState() => _PayOSPaymentSheetState();
}

class _PayOSPaymentSheetState extends State<PayOSPaymentSheet> {
  late final TextEditingController _amountController;
  bool _loading = false;
  bool _checking = false;
  bool _manualConfirming = false;
  String? _error;
  PayOSPaymentLinkModel? _paymentData;
  bool _isSuccess = false;
  int _timeLeft = 900; // 15 phút đếm ngược
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    final defaultAmount = widget.bill.remainingAmount > 0
        ? widget.bill.remainingAmount
        : widget.bill.amount;
    _amountController = TextEditingController(
      text: defaultAmount.round().toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();

    _timeLeft = 900;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft <= 1) {
        timer.cancel();
        setState(() => _timeLeft = 0);
      } else {
        setState(() => _timeLeft--);
      }
    });

    // Tự động kiểm tra trạng thái mỗi 3.5 giây
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (!mounted || _paymentData == null || _isSuccess) return;
      try {
        final res = await PaymentApi.checkPayOSStatus(_paymentData!.orderCode);
        if (res.isSuccess && mounted) {
          _handleSuccess();
        }
      } catch (_) {
        // Bỏ qua lỗi mạng tạm thời trong vòng lặp thăm dò
      }
    });
  }

  void _handleSuccess() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    setState(() {
      _isSuccess = true;
      _error = null;
    });
    widget.onPaymentSuccess?.call();
  }

  Future<void> _createPaymentLink() async {
    final raw = double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (raw == null || raw <= 0) {
      setState(() => _error = 'Số tiền thanh toán phải lớn hơn 0 đ.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await PaymentApi.createBillPayment(
        widget.bill.id,
        amount: raw,
      );
      if (!mounted) return;
      setState(() {
        _paymentData = res;
        _loading = false;
      });
      _startTimers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _manualCheck() async {
    if (_paymentData == null) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final res = await PaymentApi.checkPayOSStatus(_paymentData!.orderCode);
      if (!mounted) return;
      if (res.isSuccess) {
        _handleSuccess();
      } else {
        setState(() {
          _checking = false;
          _error = 'Hệ thống chưa ghi nhận tiền về tài khoản. Vui lòng thử lại sau giây lát.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = userFacingError(e);
      });
    }
  }

  Future<void> _confirmManualPayment() async {
    if (_paymentData == null) return;
    setState(() {
      _manualConfirming = true;
      _error = null;
    });
    try {
      final res = await PaymentApi.confirmManualPayOS(_paymentData!.orderCode);
      if (!mounted) return;
      if (res.isSuccess) {
        _handleSuccess();
      } else {
        setState(() {
          _manualConfirming = false;
          _error = 'Hệ thống chưa thể xác nhận thanh toán tự động. Vui lòng thử lại.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualConfirming = false;
        _error = userFacingError(e);
      });
    }
  }

  Future<void> _openPayOSLink() async {
    final url = _paymentData?.checkoutUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF047857),
      ),
    );
  }

  String _formatSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 6,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 12),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF047857),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Thanh toán PayOS (VietQR)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Text(
                                'Tự động 24/7',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Hóa đơn #${widget.bill.billCode} · ${widget.bill.lesseeName}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),

              if (_isSuccess)
                _buildSuccessView()
              else if (_paymentData == null)
                _buildAmountFormView()
              else
                _buildQrPaymentView(),
            ],
          ),
        ),
      ),
    );
  }

  /// Bước 1: Xác nhận số tiền & Tạo liên kết thanh toán
  Widget _buildAmountFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _summaryRow('Tổng tiền hóa đơn:', formatMoney(widget.bill.amount)),
              const SizedBox(height: 6),
              _summaryRow('Đã thanh toán:', formatMoney(widget.bill.paidAmount), color: const Color(0xFF047857)),
              const Divider(height: 14),
              _summaryRow(
                'Còn lại cần thanh toán:',
                formatMoney(widget.bill.remainingAmount),
                color: const Color(0xFFD97706),
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        const Text(
          'Số tiền thanh toán qua PayOS (VNĐ):',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            suffixText: 'VNĐ',
            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _amountController.text = widget.bill.remainingAmount.round().toString();
              });
            },
            child: Text(
              'Thanh toán hết còn lại (${formatMoney(widget.bill.remainingAmount)})',
              style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Color(0xFFE11D48)),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)))),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hệ thống tạo mã VietQR theo chuẩn Napas247. Bạn có thể mở bất kỳ ứng dụng ngân hàng nào (Vietcombank, MB, Techcombank, VPBank, MoMo...) để quét mã thanh toán 24/7.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _loading ? null : _createPaymentLink,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.qr_code_rounded, size: 20),
            label: Text(
              _loading ? 'Đang tạo mã VietQR...' : 'Tạo mã QR thanh toán',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Bước 2: Hiển thị VietQR & Thông tin chuyển khoản
  Widget _buildQrPaymentView() {
    final data = _paymentData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Countdown Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFFB45309)),
                  SizedBox(width: 6),
                  Text(
                    'Đang chờ bạn chuyển khoản...',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ],
              ),
              Text(
                _formatSeconds(_timeLeft),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // QR Code Container
        Center(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    data.vietQrImageUrl,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 200,
                      height: 200,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(Icons.qr_code_2_rounded, size: 64, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Mở App Ngân Hàng để Quét Mã VietQR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const Text(
                  'Tự động điền đúng số tiền & nội dung thanh toán',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Transfer details
        _copyItem('Ngân hàng thụ hưởng', data.bankName ?? 'Ngân hàng Quân Đội (MBBank)', isHeader: true),
        const SizedBox(height: 6),
        _copyItem('Số tài khoản', data.bankAccountNumber ?? '—', copyText: data.bankAccountNumber),
        const SizedBox(height: 6),
        _copyItem('Chủ tài khoản', data.bankAccountName ?? 'SMARTFARM', copyText: data.bankAccountName),
        const SizedBox(height: 6),
        _copyItem('Số tiền', formatMoney(data.amount), copyText: data.amount.round().toString(), highlight: true),
        const SizedBox(height: 6),
        _copyItem('Nội dung chuyển khoản (bắt buộc)', data.description, copyText: data.description, isDesc: true),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Color(0xFFE11D48)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C), height: 1.3),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFFECDD3)),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bạn đã chuyển tiền qua ngân hàng rồi?',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9F1239),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _manualConfirming ? null : _confirmManualPayment,
                      icon: _manualConfirming
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 14),
                      label: Text(
                        _manualConfirming ? 'Đang xác nhận...' : 'Xác nhận ngay',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openPayOSLink,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Mở link PayOS', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _checking ? null : _manualCheck,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  _checking ? 'Đang kiểm tra...' : 'Kiểm tra ngay',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Bước 3: Thông báo thanh toán thành công
  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, size: 40, color: Color(0xFF047857)),
          ),
          const SizedBox(height: 14),
          const Text(
            'Thanh toán thành công qua PayOS!',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Đã ghi nhận số tiền ${formatMoney(_paymentData?.amount ?? widget.bill.amount)} vào Hóa đơn #${widget.bill.billCode}.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xong', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 12.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.bold,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _copyItem(
    String title,
    String content, {
    String? copyText,
    bool isHeader = false,
    bool highlight = false,
    bool isDesc = false,
  }) {
    final bgColor = isDesc
        ? const Color(0xFFFFFBEB)
        : highlight
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF8FAFC);
    final borderColor = isDesc
        ? const Color(0xFFFDE68A)
        : highlight
        ? const Color(0xFFA7F3D0)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDesc
                        ? const Color(0xFFB45309)
                        : highlight
                        ? const Color(0xFF047857)
                        : const Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: (copyText != null && !isHeader) ? 'monospace' : null,
                    fontWeight: FontWeight.bold,
                    color: highlight ? const Color(0xFF047857) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (copyText != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
              tooltip: 'Sao chép',
              onPressed: () => _copy(copyText, title),
            ),
        ],
      ),
    );
  }
}
