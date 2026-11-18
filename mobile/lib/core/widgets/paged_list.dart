import 'package:flutter/material.dart';

import '../utils/paging.dart';
import 'page_bar.dart';

/// Danh sách cuộn có phân trang (10 dòng/trang): [header] luôn hiện ở đầu, [items] đã được sắp xếp sẵn.
/// Giữ số trang khi dữ liệu làm mới, tự lùi về trang cuối nếu danh sách co lại, cuộn lên đầu khi đổi trang.
class PagedList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final List<Widget> header;
  final EdgeInsetsGeometry padding;
  final double itemGap;
  const PagedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.header = const [],
    this.padding = const EdgeInsets.all(16),
    this.itemGap = 0,
  });

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final _scroll = ScrollController();
  int _page = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final page = clampPage(_page, widget.items.length);
    final shown = pageSlice(widget.items, page);
    return ListView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: widget.padding,
      children: [
        ...widget.header,
        for (final e in shown) ...[
          widget.itemBuilder(context, e),
          if (widget.itemGap > 0) SizedBox(height: widget.itemGap),
        ],
        PageBar(page: page, total: widget.items.length, onPage: _go),
      ],
    );
  }
}
