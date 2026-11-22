import 'package:flutter/material.dart';
import '../../core/models/discount_code_model.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/user_error.dart';
import '../support/quotation_editor.dart' show formatMoney;

/// Hộp thoại/Bảng tra cứu và áp dụng Mã giảm giá (`/api/v1/discount-codes`).
class DiscountCodesSheet extends StatefulWidget {
  final double currentAmount;
  final ValueChanged<ValidateDiscountResult>? onApply;

  const DiscountCodesSheet({
    super.key,
    required this.currentAmount,
    this.onApply,
  });

  @override
  State<DiscountCodesSheet> createState() => _DiscountCodesSheetState();
}

class _DiscountCodesSheetState extends State<DiscountCodesSheet> {
  List<DiscountCodeModel> _codes = [];
  bool _loading = true;
  String? _error;
  final _inputController = TextEditingController();
  bool _validating = false;
  ValidateDiscountResult? _validatedResult;
  String? _validateError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await DiscountApi.getDiscountCodes(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _codes = list;
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

  Future<void> _checkCode(String code) async {
    final c = code.trim();
    if (c.isEmpty) return;
    setState(() {
      _validating = true;
      _validateError = null;
      _validatedResult = null;
    });
    try {
      final result = await DiscountApi.validateDiscountCode(
        code: c,
        contractAmount: widget.currentAmount,
      );
      if (!mounted) return;
      setState(() {
        _validatedResult = result;
        _validating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validateError = userFacingError(e);
        _validating = false;
      });
    }
  }

  Future<void> _autoFindBest() async {
    setState(() {
      _validating = true;
      _validateError = null;
      _validatedResult = null;
    });
    try {
      final best = await DiscountApi.getBestDiscount(
        contractAmount: widget.currentAmount,
      );
      if (!mounted) return;
      if (best.hasDiscount && best.discountCode != null) {
        _inputController.text = best.discountCode!.code;
        await _checkCode(best.discountCode!.code);
      } else {
        setState(() {
          _validating = false;
          _validateError = best.message ?? 'Không tìm thấy mã giảm giá phù hợp với giá trị đơn hàng.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validating = false;
        _validateError = userFacingError(e);
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
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_offer_rounded,
                      color: Color(0xFF7C3AED),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mã Giảm Giá & Ưu Đãi',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Áp dụng cho đơn hàng: ${formatMoney(widget.currentAmount)}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Làm mới',
                    onPressed: _load,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Input Form
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (val) => _checkCode(val),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Nhập mã ưu đãi (VD: SMARTFARM)',
                        hintStyle: const TextStyle(fontSize: 12.5),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: _inputController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                tooltip: 'Xóa mã',
                                onPressed: () {
                                  setState(() {
                                    _inputController.clear();
                                    _validateError = null;
                                    _validatedResult = null;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      minimumSize: const Size(88, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _validating ? null : () => _checkCode(_inputController.text),
                    child: _validating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kiểm tra', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Button auto-find
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size(44, 40)),
                  icon: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
                  label: const Text(
                    'Tự động chọn mã tốt nhất',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.bold),
                  ),
                  onPressed: _validating ? null : _autoFindBest,
                ),
              ),

          // Validated Feedback Card
          if (_validateError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                  Expanded(
                    child: Text(_validateError!, style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C))),
                  ),
                ],
              ),
            ),

          if (_validatedResult != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _validatedResult!.isValid ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _validatedResult!.isValid ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _validatedResult!.isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                        size: 18,
                        color: _validatedResult!.isValid ? const Color(0xFF047857) : const Color(0xFFBE123C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _validatedResult!.isValid
                              ? 'Mã hợp lệ: Giảm ${formatMoney(_validatedResult!.discountAmount)}'
                              : (_validatedResult!.message ?? 'Mã không áp dụng được'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _validatedResult!.isValid ? const Color(0xFF065F46) : const Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_validatedResult!.isValid) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Tổng sau giảm: ${formatMoney(_validatedResult!.finalAmount)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          minimumSize: const Size(120, 44),
                        ),
                        onPressed: () {
                          if (widget.onApply != null) {
                            widget.onApply!(_validatedResult!);
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('Áp dụng mã này', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const Divider(),
          const Text(
            'Mã giảm giá đang phát hành:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          // List of codes
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
                : _error != null
                ? Center(child: Text('Lỗi: $_error', style: const TextStyle(fontSize: 12, color: Colors.red)))
                : _codes.isEmpty
                ? const Center(
                    child: Text('Hiện không có mã giảm giá nào.', style: TextStyle(color: Color(0xFF64748B))),
                  )
                : ListView.separated(
                    itemCount: _codes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = _codes[i];
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            _inputController.text = c.code;
                            _checkCode(c.code);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3E8FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.code,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF7C3AED),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            c.discountType == 0 ? '-${c.discountValue}%' : '-${formatMoney(c.discountValue)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF047857),
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (c.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(c.description, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                      ],
                                      if (c.minContractValue > 0)
                                        Text(
                                          'Đơn tối thiểu: ${formatMoney(c.minContractValue)}',
                                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                                        ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: const Size(60, 44),
                                    side: const BorderSide(color: Color(0xFF7C3AED)),
                                    foregroundColor: const Color(0xFF7C3AED),
                                  ),
                                  onPressed: () {
                                    _inputController.text = c.code;
                                    _checkCode(c.code);
                                  },
                                  child: const Text('Chọn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
