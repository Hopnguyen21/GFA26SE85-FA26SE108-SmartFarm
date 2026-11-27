import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ai_payload_snapshot.dart';

/// Bảng "Dữ liệu AI đã dùng": cho chủ trang trại thấy backend đã gửi gì cho AI (cảm biến, ngưỡng VietGAP, đoạn RAG, prompt),
/// để kiểm chứng khuyến nghị — tương đương khung "Log dữ liệu BE gửi cho AI" của web.
class AiPayloadSheet extends StatelessWidget {
  final AiPayloadSnapshot snapshot;
  const AiPayloadSheet({super.key, required this.snapshot});

  static Future<void> show(BuildContext context, AiPayloadSnapshot snapshot) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => AiPayloadSheet(snapshot: snapshot),
      );

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return DefaultTabController(
      length: 5,
      child: Builder(
        builder: (ctx) {
          final tab = DefaultTabController.of(ctx);
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.82,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.terminal,
                        size: 18,
                        color: Color(0xFF047857),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dữ liệu AI đã dùng',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              s.summary,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Sao chép',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          // Giống web: tab Prompt chép prompt, các tab khác chép JSON đầy đủ.
                          final text = tab.index == 3 && s.prompt.isNotEmpty
                              ? s.prompt
                              : s.prettyJson;
                          await Clipboard.setData(ClipboardData(text: text));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Đã sao chép')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: const Color(0xFF047857),
                  indicatorColor: const Color(0xFF10B981),
                  tabs: [
                    Tab(text: 'Cảm biến (${s.telemetry.length})'),
                    Tab(text: 'Ngưỡng VietGAP (${s.requirements.length})'),
                    Tab(text: 'RAG VietGAP (${s.passages.length})'),
                    const Tab(text: 'Prompt'),
                    const Tab(text: 'JSON thô'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _telemetry(),
                      _requirements(),
                      _passages(),
                      _prompt(),
                      _mono(s.prettyJson),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.all(20),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        color: Color(0xFF64748B),
        height: 1.4,
      ),
    ),
  );

  Widget _telemetry() {
    if (snapshot.telemetry.isEmpty) {
      return _empty('Không có số đo cảm biến nào được đính kèm vào prompt.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: snapshot.telemetry.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = snapshot.telemetry[i];
        final fresh = t.isFresh;
        final c = fresh == null
            ? const Color(0xFF64748B)
            : (fresh ? const Color(0xFF047857) : const Color(0xFFB45309));
        return _card(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.parameter,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (t.capturedAt != null)
                      Text(
                        '${t.capturedAt!.hour.toString().padLeft(2, '0')}:${t.capturedAt!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    t.valueText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (fresh != null)
                    Text(
                      fresh ? 'Tươi mới' : 'Cũ (stale)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _requirements() {
    if (snapshot.requirements.isEmpty) {
      return _empty(
        'Zone chưa gắn hồ sơ cây trồng nên chưa có ngưỡng quy chuẩn để so sánh.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: snapshot.requirements.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = snapshot.requirements[i];
        return _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.parameter,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Min ${r.min} · Mục tiêu ${r.target} · Max ${r.max} ${r.unit}'
                    .trim(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _passages() {
    if (snapshot.passages.isEmpty) {
      return _empty(
        'Không có đoạn trích nào từ kho tri thức RAG đủ độ tương đồng với câu hỏi này; AI dùng số đo cảm biến thời gian thực và ngưỡng của giai đoạn hiện tại.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: snapshot.passages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final p = snapshot.passages[i];
        return _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${i + 1} ${p.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (p.similarityPercent != null)
                    Text(
                      'Tương đồng ${p.similarityPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
              if (p.organization.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Đơn vị ban hành: ${p.organization}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              SelectableText(
                p.content,
                style: const TextStyle(fontSize: 12, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _prompt() {
    final s = snapshot;
    if (s.prompt.isEmpty && s.systemPrompt.isEmpty) {
      return _empty('Backend không gửi chuỗi prompt gốc; xem tab JSON thô.');
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (s.systemPrompt.isNotEmpty) ...[
          const Text(
            'Hướng dẫn hệ thống & quy tắc an toàn',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 4),
          _monoBox(s.systemPrompt),
          const SizedBox(height: 12),
        ],
        if (s.prompt.isNotEmpty) ...[
          const Text(
            'Prompt có cấu trúc (dữ liệu gửi AI)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0369A1),
            ),
          ),
          const SizedBox(height: 4),
          _monoBox(s.prompt),
        ],
      ],
    );
  }

  Widget _mono(String text) =>
      ListView(padding: const EdgeInsets.all(12), children: [_monoBox(text)]);

  Widget _monoBox(String text) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(10),
    ),
    child: SelectableText(
      text,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        height: 1.45,
        color: Color(0xFFD1FAE5),
      ),
    ),
  );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );
}
