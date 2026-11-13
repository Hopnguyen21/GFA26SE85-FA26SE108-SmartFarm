import 'package:flutter/material.dart';

/// Hỏi người dùng một số dương (vd. diện tích). Trả về null nếu huỷ hoặc không hợp lệ.
Future<double?> askPositiveNumber(BuildContext context, String label) async {
  final ctrl = TextEditingController();
  String? err;
  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(errorText: err),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              if (v == null || v <= 0) {
                setLocal(() => err = 'Nhập số lớn hơn 0');
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ),
  );
  Future.delayed(const Duration(milliseconds: 600), ctrl.dispose);
  return result;
}
