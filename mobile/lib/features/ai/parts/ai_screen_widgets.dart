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

/// "Log dữ liệu BE gửi cho AI": prompt, cảm biến, ngưỡng VietGAP, đoạn RAG và JSON gốc (khớp `AiPayloadLogViewer` trên web).
class _AiPayloadLog extends StatefulWidget {
  final String snapshotJson;
  const _AiPayloadLog({required this.snapshotJson});

  @override
  State<_AiPayloadLog> createState() => _AiPayloadLogState();
}

class _AiPayloadLogState extends State<_AiPayloadLog> {
  bool _open = false;
  bool _copied = false;
  int _tab = 0;

  dynamic _pick(Map m, String a, String b) => m[a] ?? m[b];

  // Giải mã một lần: snapshot thật dài vài KB và màn hình dựng lại mỗi 10 giây khi làm mới bối cảnh.
  late final dynamic _data = () {
    try {
      return jsonDecode(widget.snapshotJson);
    } catch (_) {
      return null;
    }
  }();
  String? _rawCache;

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data is! Map) return const SizedBox.shrink();
    final prompt = _pick(data, 'Prompt', 'prompt')?.toString() ?? '';
    final system =
        _pick(data, 'SystemPrompt', 'systemPrompt')?.toString() ?? '';
    final ctxRaw = _pick(data, 'Context', 'context');
    final ctx = ctxRaw is Map ? ctxRaw : const {};
    final passages = (_pick(data, 'Passages', 'passages') as List?) ?? const [];
    final telemetry =
        (_pick(ctx, 'Telemetry', 'telemetry') as List?) ?? const [];
    final reqs =
        (_pick(ctx, 'Requirements', 'requirements') as List?) ?? const [];
    // Chuỗi JSON định dạng chỉ dựng khi cần (mở tab Raw JSON hoặc sao chép).
    String rawJson() =>
        _rawCache ??= const JsonEncoder.withIndent('  ').convert(data);

    const tabs = [
      'XML Prompt',
      'Cảm biến',
      'Ngưỡng VietGAP',
      'RAG VietGAP',
      'Raw JSON',
    ];
    final counts = [
      '',
      ' (${telemetry.length})',
      ' (${reqs.length})',
      ' (${passages.length})',
      '',
    ];

    String body() {
      switch (_tab) {
        case 0:
          return [
            if (system.isNotEmpty)
              'System Instructions & Safety Rules:\n$system',
            'Structured Prompt (XML Data Payload gửi AI):\n${prompt.isEmpty ? 'Không có raw prompt string, xem tab Raw JSON.' : prompt}',
          ].join('\n\n');
        case 1:
          return telemetry.isEmpty
              ? 'Không có số đo cảm biến nào được đính kèm.'
              : telemetry
                    .map((t) {
                      final fresh = (_pick(t, 'IsFresh', 'isFresh')) == true;
                      return '${_pick(t, 'ParameterCode', 'parameterCode')}: ${t['Value'] ?? t['value']} ${t['Unit'] ?? t['unit'] ?? ''}  [${fresh ? 'Tươi mới' : 'Cũ'}]';
                    })
                    .join('\n');
        case 2:
          return reqs.isEmpty
              ? 'Không có ngưỡng VietGAP nào được đính kèm.'
              : reqs
                    .map(
                      (r) =>
                          '${_pick(r, 'ParameterCode', 'parameterCode')}: min ${r['MinValue'] ?? r['minValue']} · mục tiêu ${r['TargetValue'] ?? r['targetValue']} · max ${r['MaxValue'] ?? r['maxValue']} (${r['Unit'] ?? r['unit'] ?? ''})',
                    )
                    .join('\n');
        case 3:
          return passages.isEmpty
              ? 'Không có trích đoạn nào từ kho tri thức RAG khớp với ngưỡng tương đồng cho câu hỏi này. AI dùng dữ liệu cảm biến thời gian thực và tiêu chuẩn vi khí hậu đã cấu hình trong hồ sơ mùa vụ.'
              : [
                  for (var i = 0; i < passages.length; i++)
                    '#${i + 1} ${passages[i]['DocumentTitle'] ?? passages[i]['documentTitle'] ?? passages[i]['Category'] ?? passages[i]['category'] ?? ''}'
                        ' · tương đồng ${(((passages[i]['SimilarityScore'] ?? passages[i]['similarityScore'] ?? 0.8) as num) * 100).round()}%\n'
                        '${passages[i]['Content'] ?? passages[i]['content'] ?? ''}',
                ].join('\n\n');
        default:
          return rawJson();
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.terminal,
                    size: 13,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 5),
                  const Flexible(
                    child: Text(
                      'Log dữ liệu BE gửi cho AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: const Color(0xFF047857),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 4),
            Text(
              '${telemetry.length} cảm biến • ${reqs.length} ngưỡng VietGAP • ${passages.length} tài liệu RAG',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: const Color(0xFF020617),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < tabs.length; i++)
                                  GestureDetector(
                                    onTap: () => setState(() => _tab = i),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _tab == i
                                            ? const Color(0xFF047857)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        '${tabs[i]}${counts[i]}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _tab == i
                                              ? Colors.white
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(
                                text: _tab == 0 && prompt.isNotEmpty
                                    ? prompt
                                    : rawJson(),
                              ),
                            );
                            if (!mounted) return;
                            setState(() => _copied = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _copied = false);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied ? Icons.check : Icons.copy,
                                  size: 12,
                                  color: _copied
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFFCBD5E1),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _copied ? 'Đã chép' : 'Sao chép',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFCBD5E1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: SelectableText(
                        body(),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          fontFamily: 'monospace',
                          color: Color(0xFFA7F3D0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
