import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Thẻ nhóm thông tin dùng chung: nền trắng, viền nhạt, tiêu đề có biểu tượng.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: const Color(0xFF0F766E)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// Nhãn nhỏ dạng viên thuốc (thay `Chip` mặc định vì màu chữ theo theme có thể mất).
class ParamPill extends StatelessWidget {
  final String label;
  const ParamPill(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDFA),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF99F6E4)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF0F766E),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Hàng "biểu tượng · nhãn · giá trị": nhãn co theo chữ (tối đa 38% bề rộng) nên không bị cắt khi chữ phóng to.
class KeyValueRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const KeyValueRow(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: LayoutBuilder(
      builder: (context, box) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryDark),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 64,
              maxWidth: box.maxWidth * 0.38,
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Một dòng hạng mục: ô số lượng, tên + mô tả, thành tiền (nếu có).
class LineItemRow extends StatelessWidget {
  final int qty;
  final String title;
  final String? meta;
  final String? amount;
  const LineItemRow({
    super.key,
    required this.qty,
    required this.title,
    this.meta,
    this.amount,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$qty×',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (meta != null && meta!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    meta!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (amount != null) ...[
          const SizedBox(width: 8),
          Text(
            amount!,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    ),
  );
}

/// Khung tổng tiền nổi bật.
class TotalBar extends StatelessWidget {
  final String label;
  final String value;
  const TotalBar({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF047857),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
