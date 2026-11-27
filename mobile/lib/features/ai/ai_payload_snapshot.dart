import 'dart:convert';

/// "Dữ liệu backend đã gửi cho AI" (contextSnapshotJson) — bản mobile của khung "Log dữ liệu BE gửi cho AI" ở web:
/// cảm biến kèm độ tươi, ngưỡng VietGAP theo giai đoạn, đoạn trích RAG, prompt và JSON thô.
/// Backend dùng khoá PascalCase hoặc camelCase tuỳ nơi sinh nên mọi truy cập đều thử cả hai; JSON hỏng trả về null.

dynamic _pick(Map m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null) return m[k];
  }
  return null;
}

String _text(Map m, List<String> keys) =>
    _pick(m, keys)?.toString().trim() ?? '';

double? _num(Map m, List<String> keys) {
  final v = _pick(m, keys);
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}');
}

String _fmt(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Một số đo cảm biến được đính kèm vào prompt.
class AiTelemetryItem {
  final String parameter;
  final String valueText; // ví dụ "52.4 %"
  final bool? isFresh; // null: backend không báo
  final DateTime? capturedAt;
  const AiTelemetryItem(
    this.parameter,
    this.valueText,
    this.isFresh,
    this.capturedAt,
  );
}

/// Ngưỡng quy chuẩn (min / mục tiêu / max) của một thông số ở giai đoạn hiện tại.
class AiRequirementItem {
  final String parameter;
  final String min;
  final String target;
  final String max;
  final String unit;
  const AiRequirementItem(
    this.parameter,
    this.min,
    this.target,
    this.max,
    this.unit,
  );
}

/// Đoạn trích tài liệu VietGAP mà RAG nạp vào prompt.
class AiPassageItem {
  final String title;
  final String organization;
  final int? similarityPercent;
  final String content;
  const AiPassageItem(
    this.title,
    this.organization,
    this.similarityPercent,
    this.content,
  );
}

class AiPayloadSnapshot {
  final String prompt;
  final String systemPrompt;
  final List<AiTelemetryItem> telemetry;
  final List<AiRequirementItem> requirements;
  final List<AiPassageItem> passages;

  /// JSON đã định dạng đẹp để xem/sao chép.
  final String prettyJson;

  const AiPayloadSnapshot({
    required this.prompt,
    required this.systemPrompt,
    required this.telemetry,
    required this.requirements,
    required this.passages,
    required this.prettyJson,
  });

  bool get isEmpty =>
      prompt.isEmpty &&
      systemPrompt.isEmpty &&
      telemetry.isEmpty &&
      requirements.isEmpty &&
      passages.isEmpty;

  /// "3 cảm biến · 4 ngưỡng VietGAP · 2 tài liệu RAG"
  String get summary =>
      '${telemetry.length} cảm biến · ${requirements.length} ngưỡng VietGAP · ${passages.length} tài liệu RAG';

  static final Map<String, AiPayloadSnapshot?> _cache = {};

  /// Phân tích có nhớ đệm (danh sách tin nhắn dựng lại nhiều lần khi cuộn). null khi rỗng hoặc JSON hỏng.
  static AiPayloadSnapshot? tryParse(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    if (_cache.containsKey(json)) return _cache[json];
    if (_cache.length > 60) _cache.clear();
    return _cache[json] = _parse(json);
  }

  static AiPayloadSnapshot? _parse(String json) {
    final dynamic root;
    try {
      root = jsonDecode(json);
    } catch (_) {
      return null;
    }
    if (root is! Map) return null;
    final context = _pick(root, ['Context', 'context']);
    final ctx = context is Map ? context : const {};
    List<Map> maps(dynamic v) => v is List
        ? [
            for (final e in v)
              if (e is Map) e,
          ]
        : const [];

    final telemetry = [
      for (final t in maps(_pick(ctx, ['Telemetry', 'telemetry'])))
        AiTelemetryItem(
          _text(t, ['ParameterCode', 'parameterCode']),
          '${_fmt(_num(t, ['Value', 'value']))} ${_text(t, ['Unit', 'unit'])}'
              .trim(),
          _pick(t, ['IsFresh', 'isFresh']) is bool
              ? _pick(t, ['IsFresh', 'isFresh']) as bool
              : null,
          DateTime.tryParse(
            _text(t, ['CapturedAtUtc', 'capturedAtUtc']),
          )?.toLocal(),
        ),
    ];
    final requirements = [
      for (final r in maps(_pick(ctx, ['Requirements', 'requirements'])))
        AiRequirementItem(
          _text(r, ['ParameterCode', 'parameterCode']),
          _fmt(_num(r, ['MinValue', 'minValue'])),
          _fmt(_num(r, ['TargetValue', 'targetValue'])),
          _fmt(_num(r, ['MaxValue', 'maxValue'])),
          _text(r, ['Unit', 'unit']),
        ),
    ];
    final passages = [
      for (final p in maps(_pick(root, ['Passages', 'passages'])))
        AiPassageItem(
          _text(p, [
                'DocumentTitle',
                'documentTitle',
                'Category',
                'category',
              ]).isEmpty
              ? 'Tài liệu VietGAP'
              : _text(p, [
                  'DocumentTitle',
                  'documentTitle',
                  'Category',
                  'category',
                ]),
          _text(p, ['AuthorOrganization', 'authorOrganization']),
          _num(p, ['SimilarityScore', 'similarityScore']) == null
              ? null
              : (_num(p, ['SimilarityScore', 'similarityScore'])! * 100)
                    .round(),
          _text(p, ['Content', 'content']),
        ),
    ];
    return AiPayloadSnapshot(
      prompt: _text(root, ['Prompt', 'prompt']),
      systemPrompt: _text(root, ['SystemPrompt', 'systemPrompt']),
      telemetry: telemetry,
      requirements: requirements,
      passages: passages,
      prettyJson: const JsonEncoder.withIndent('  ').convert(root),
    );
  }
}
