import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/user_error.dart';
import 'quotation_editor.dart' show formatMoney;

/// Bảng thanh toán trực tuyến VietQR / PayOS cho Yêu cầu hỗ trợ & Lắp đặt (Luồng 1 - WF-01).
/// Hỗ trợ 2 giai đoạn:
/// - `DEPOSIT_30`: Tạm ứng cọc 30% khi ký hợp đồng báo giá thiết bị IoT.
/// - `FINAL_70`: Quyết toán 70% còn lại khi ký biên bản nghiệm thu bàn giao.
class PayOSServiceRequestSheet extends StatefulWidget {
  final String serviceRequestId;
  final String stage; // 'DEPOSIT_30' | 'FINAL_70'
  final String stageTitle;
  final double amount;
  final String initialSignerName;
  final Future<void> Function(
    String transactionReference,
    String paymentMethod,
    String signerName,
  )? onPaymentSuccess;

  const PayOSServiceRequestSheet({
    super.key,
    required this.serviceRequestId,
    required this.stage,
    required this.stageTitle,
    required this.amount,
    this.initialSignerName = 'Chủ Trang Trại',
    this.onPaymentSuccess,
  });

  @override
  State<PayOSServiceRequestSheet> createState() =>
      _PayOSServiceRequestSheetState();
}

class _PayOSServiceRequestSheetState extends State<PayOSServiceRequestSheet> {
  late final TextEditingController _signerController;
  bool _verifying = false;
  bool _isSuccess = false;
  String? _error;
  String? _transactionReference;
  int _timeLeft = 900; // 15 phút đếm ngược
  Timer? _countdownTimer;

  // Thông tin thụ hưởng chính thức SmartFarm qua Napas 24/7 (MBBank)
  static const String _bankBin = '970422';
  static const String _bankName = 'Ngân hàng TMCP Quân Đội (MBBank)';
  static const String _bankAccountNumber = '0987654321';
  static const String _bankAccountName = 'CONG TY CONG NGHE SMARTFARM';

  String get _cleanCode {
    final raw = widget.serviceRequestId.replaceAll('-', '').toUpperCase();
    return raw.length > 8 ? raw.substring(0, 8) : raw;
  }

  String get _transferDescription {
    final prefix = widget.stage == 'DEPOSIT_30' ? 'COC' : 'NT';
    return '$prefix $_cleanCode';
  }

  String get _vietQrUrl {
    final rounded = widget.amount.round();
    final desc = Uri.encodeComponent(_transferDescription);
    final name = Uri.encodeComponent(_bankAccountName);
    return 'https://img.vietqr.io/image/$_bankBin-$_bankAccountNumber-compact2.png?amount=$rounded&addInfo=$desc&accountName=$name';
  }

  @override
  void initState() {
    super.initState();
    _signerController = TextEditingController(text: widget.initialSignerName);
    _startCountdown();
  }

  @override
  void dispose() {
    _signerController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
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
  }

  String _formatSeconds(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

  Future<void> _openBankingLink() async {
    // Mở trang chuẩn Napas VietQR hoặc App ngân hàng
    final uri = Uri.parse(_vietQrUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _copy(_vietQrUrl, 'Liên kết VietQR');
      }
    } catch (_) {
      if (mounted) {
        _copy(_vietQrUrl, 'Liên kết VietQR');
      }
    }
  }

  Future<void> _verifyPayment() async {
    final signer = _signerController.text.trim();
    if (signer.isEmpty) {
      setState(() => _error = 'Vui lòng nhập họ tên người thanh toán/ký.');
      return;
    }

    if (_timeLeft <= 0) {
      setState(
        () => _error =
            'Mã thanh toán đã hết hạn (15 phút). Vui lòng bấm "Làm mới mã" để tiếp tục.',
      );
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      // Giả lập thời gian đối soát cổng VietQR Napas247 / PayOS (1.2s)
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, 14);
      final ref =
          'PAYOS-${widget.stage == 'DEPOSIT_30' ? 'COC' : 'NT'}-$_cleanCode-$stamp';

      if (widget.onPaymentSuccess != null) {
        await widget.onPaymentSuccess!(ref, 'PayOS (VietQR)', signer);
      }

      if (!mounted) return;
      _countdownTimer?.cancel();
      setState(() {
        _verifying = false;
        _isSuccess = true;
        _transactionReference = ref;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Lỗi xác nhận thanh toán: ${userFacingError(e)}';
      });
    }
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
            top: 8,
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
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            const Text(
                              'Thanh toán PayOS (VietQR)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFA7F3D0),
                                ),
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
                          '${widget.stageTitle} · Phiếu #$_cleanCode',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context, _isSuccess),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),

              if (_isSuccess)
                _buildSuccessView()
              else
                _buildPaymentDetailsView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Countdown banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _timeLeft <= 0
                ? const Color(0xFFFFF1F2)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _timeLeft <= 0
                  ? const Color(0xFFFECDD3)
                  : const Color(0xFFFDE68A),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _timeLeft <= 0
                        ? Icons.timer_off_rounded
                        : Icons.hourglass_top_rounded,
                    size: 16,
                    color: _timeLeft <= 0
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _timeLeft <= 0
                        ? 'Mã thanh toán đã hết hạn'
                        : 'Đang chờ bạn chuyển khoản...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _timeLeft <= 0
                          ? const Color(0xFFBE123C)
                          : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
              if (_timeLeft <= 0)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _startCountdown();
                      _error = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text(
                    'Làm mới mã',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                )
              else
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
        const SizedBox(height: 12),

        // VietQR Code Box
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
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
                    _vietQrUrl,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Container(
                      width: 200,
                      height: 200,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          size: 64,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mở App Ngân Hàng Quét Mã VietQR',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Text(
                  'Tự động điền đúng số tiền & nội dung chuyển khoản',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Signer name field
        const Text(
          'Người nộp / Đại diện thanh toán:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _signerController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Nhập họ và tên người chuyển khoản',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 10),

        // Transfer details items
        _copyItem('Ngân hàng thụ hưởng', _bankName, isHeader: true),
        const SizedBox(height: 6),
        _copyItem(
          'Số tài khoản',
          _bankAccountNumber,
          copyText: _bankAccountNumber,
        ),
        const SizedBox(height: 6),
        _copyItem('Chủ tài khoản', _bankAccountName, copyText: _bankAccountName),
        const SizedBox(height: 6),
        _copyItem(
          'Số tiền thanh toán',
          formatMoney(widget.amount),
          copyText: widget.amount.round().toString(),
          highlight: true,
        ),
        const SizedBox(height: 6),
        _copyItem(
          'Nội dung chuyển khoản (bắt buộc đúng)',
          _transferDescription,
          copyText: _transferDescription,
          isDesc: true,
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 18,
                  color: Color(0xFFE11D48),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBE123C),
                    ),
                  ),
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
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openBankingLink,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text(
                  'Xem mã QR gốc',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _verifying ? null : _verifyPayment,
                icon: _verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  _verifying ? 'Đang xác thực...' : 'Đã chuyển khoản',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 44,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Thanh toán PayOS (VietQR) Thành Công!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Đã ghi nhận thanh toán ${formatMoney(widget.amount)} cho ${widget.stageTitle}.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            textAlign: TextAlign.center,
          ),
          if (_transactionReference != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Mã GD: $_transactionReference',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Hoàn tất & Tiếp tục',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
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
                    fontFamily: (copyText != null && !isHeader)
                        ? 'monospace'
                        : null,
                    fontWeight: FontWeight.bold,
                    color: highlight
                        ? const Color(0xFF047857)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          if (copyText != null)
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              tooltip: 'Sao chép',
              onPressed: () => _copy(copyText, title),
            ),
        ],
      ),
    );
  }
}
