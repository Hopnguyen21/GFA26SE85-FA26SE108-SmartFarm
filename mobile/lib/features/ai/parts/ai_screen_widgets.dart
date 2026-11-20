part of '../ai_screen.dart';

/// "Tài liệu VietGAP tham chiếu (n)": danh sách mở rộng, mỗi nguồn là một thẻ có trích đoạn (khớp web).
class _RagSourcesAccordion extends StatefulWidget {
  final List<dynamic> sources;
  const _RagSourcesAccordion({required this.sources});

  @override
  State<_RagSourcesAccordion> createState() => _RagSourcesAccordionState();
}

class _RagSourcesAccordionState extends State<_RagSourcesAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book,
                    size: 14,
                    color: Color(0xFF047857),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tài liệu VietGAP tham chiếu (${widget.sources.length}):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF022C22),
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: const Color(0xFF047857),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: [
                  for (var i = 0; i < widget.sources.length; i++)
                    _RagSourceCard(source: widget.sources[i], index: i),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RagSourceCard extends StatefulWidget {
  final dynamic source;
  final int index;
  const _RagSourceCard({required this.source, required this.index});

  @override
  State<_RagSourceCard> createState() => _RagSourceCardState();
}

class _RagSourceCardState extends State<_RagSourceCard> {
  bool _open = false;

  String? _s(Map m, List<String> keys) {
    for (final k in keys) {
      final v = m[k]?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Widget _tag(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: fg.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final src = widget.source;
    final m = src is Map ? src : const {};
    final title = src is String
        ? src
        : (_s(m, ['title', 'name']) ?? 'Tài liệu VietGAP');
    final org = _s(m, ['organization', 'authorOrganization']);
    final category = _s(m, ['category']);
    final version = _s(m, ['version', 'Version']);
    final code = _s(m, ['standardCode', 'StandardCode']);
    final snippet = _s(m, ['contentSnippet', 'content']);
    final sim = m['similarity'] is num
        ? ((m['similarity'] as num) * 100).round()
        : null;
    final location = [
      if (m['pageNumber'] != null) 'Trang ${m['pageNumber']}',
      if (_s(m, ['sectionTitle']) != null) 'Mục: ${_s(m, ['sectionTitle'])}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _tag(
                        '#${widget.index + 1}',
                        const Color(0xFFECFDF5),
                        const Color(0xFF047857),
                      ),
                      if (code != null)
                        _tag(
                          code,
                          const Color(0xFFEFF6FF),
                          const Color(0xFF1E40AF),
                        ),
                      if (version != null)
                        _tag(
                          version,
                          const Color(0xFFECFEFF),
                          const Color(0xFF155E75),
                        ),
                      if (sim != null)
                        _tag(
                          '$sim% khớp',
                          const Color(0xFFD1FAE5),
                          const Color(0xFF065F46),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (location.isNotEmpty)
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  Text(
                    org != null
                        ? 'Tác giả / Nguồn: $org'
                        : 'Nguồn: Cơ sở tri thức VietGAP SmartFarm',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF475569),
                      fontStyle: org == null ? FontStyle.italic : null,
                    ),
                  ),
                  if (category != null)
                    Text(
                      'DM: $category',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _open ? 'Thu gọn' : 'Xem trích đoạn tri thức',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              width: double.infinity,
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trích đoạn tri thức VietGAP:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Text(
                        snippet ??
                            'Quy trình tưới nhỏ giọt và dinh dưỡng VietGAP được quản trị viên đồng bộ trong kho tri thức hệ thống.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: const Color(0xFFE2E8F0),
                          fontStyle: snippet == null ? FontStyle.italic : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Trạng thái tài liệu: Đã được quản trị viên duyệt',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
