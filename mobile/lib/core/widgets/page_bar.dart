import 'package:flutter/material.dart';

import '../utils/paging.dart';

/// Thanh chuyển trang: "‹  Trang 2/5 · 47 mục  ›". Ẩn khi chỉ có một trang.
class PageBar extends StatelessWidget {
  final int page;
  final int total;
  final int size;
  final ValueChanged<int> onPage;
  const PageBar({
    super.key,
    required this.page,
    required this.total,
    required this.onPage,
    this.size = kPageSize,
  });

  @override
  Widget build(BuildContext context) {
    final pages = pageCount(total, size);
    if (pages <= 1) return const SizedBox.shrink();
    final p = clampPage(page, total, size);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('page-prev'),
            tooltip: 'Trang trước',
            onPressed: p > 0 ? () => onPage(p - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Trang ${p + 1}/$pages · $total mục',
            key: const ValueKey('page-label'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          IconButton(
            key: const ValueKey('page-next'),
            tooltip: 'Trang sau',
            onPressed: p < pages - 1 ? () => onPage(p + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
