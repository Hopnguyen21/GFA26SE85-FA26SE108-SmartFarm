import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai/ai_screen.dart';

/// Khuyến nghị AI gần nhất của Zone đang chọn, lấy từ backend (GET /zones/{id}/ai/history).
/// Không có nội dung cố định: chưa có khuyến nghị thì mời hỏi AI; lỗi thì báo lỗi.
class ZoneAiAdviceCard extends StatefulWidget {
  final String zoneId;
  const ZoneAiAdviceCard({super.key, required this.zoneId});

  @override
  State<ZoneAiAdviceCard> createState() => _ZoneAiAdviceCardState();
}

class _ZoneAiAdviceCardState extends State<ZoneAiAdviceCard> {
  late Future<Map<String, dynamic>?> _future = _load();

  Future<Map<String, dynamic>?> _load() async {
    final history = await AiApi.getAiHistory(widget.zoneId);
    if (history.isEmpty) return null;
    DateTime when(Map<String, dynamic> h) => DateTime.tryParse('${h['createdAtUtc'] ?? ''}') ?? DateTime(2000);
    return ([...history]..sort((a, b) => when(b).compareTo(when(a)))).first;
  }

  @override
  void didUpdateWidget(ZoneAiAdviceCard old) {
    super.didUpdateWidget(old);
    if (old.zoneId != widget.zoneId) _future = _load();
  }

  String _ago(DateTime utc) {
    final d = DateTime.now().difference(utc.toLocal());
    if (d.inMinutes < 1) return 'vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          final h = snap.data;
          final created = h == null ? null : DateTime.tryParse('${h['createdAtUtc'] ?? ''}');
          final summary = '${h?['summary'] ?? ''}'.trim();
          final loading = snap.connectionState != ConnectionState.done;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_outlined, color: AppColors.ink, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Trợ lý AI Nông học',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                  ),
                  if (created != null)
                    Text(_ago(created.toUtc()), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (snap.hasError)
                const Text(
                  'Không tải được khuyến nghị gần nhất.',
                  style: TextStyle(fontSize: 13, color: AppColors.danger),
                )
              else if (summary.isEmpty)
                const Text(
                  'Chưa có khuyến nghị nào cho Zone này. Hỏi AI để nhận tư vấn theo số liệu cảm biến và tiêu chuẩn VietGAP.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
                )
              else
                Text(
                  summary,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
                ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: widget.zoneId)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: Text(summary.isEmpty ? 'Hỏi AI' : 'Xem & hỏi thêm'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
