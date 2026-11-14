part of '../models.dart';

/// Thẻ khuyến nghị của AI (khuyến nghị có thể duyệt để bật/tắt thiết bị), khớp `toRecommendationCard` trên web.
/// Trạng thái là chữ HOA từ backend: READY, ACCEPTED, REJECTED, EXPIRED, SUPERSEDED...
class AiRecCard {
  final String id;
  final String title;
  final String text;
  final String reasoning;
  final int confidence;
  final String type;
  final String? proposedAction;
  final int? durationSeconds;
  final DateTime? validUntilUtc;
  String status;

  /// Trạng thái lệnh điều khiển sau khi duyệt (Pending/Sent/Acknowledged/Failed/TimedOut/Cancelled); null = chưa biết.
  String? commandStatus;
  String? commandId;

  /// Đang gửi quyết định lên máy chủ.
  bool busy = false;

  AiRecCard({
    required this.id,
    required this.title,
    required this.text,
    required this.reasoning,
    required this.confidence,
    required this.type,
    required this.status,
    this.proposedAction,
    this.durationSeconds,
    this.validUntilUtc,
    this.commandStatus,
    this.commandId,
  });

  factory AiRecCard.fromJson(Map<String, dynamic> raw) {
    final conf = raw['confidence'] is num
        ? (raw['confidence'] as num) * 100
        : (raw['confidenceScore'] is num
              ? ((raw['confidenceScore'] as num) > 1
                    ? (raw['confidenceScore'] as num)
                    : (raw['confidenceScore'] as num) * 100)
              : 85);
    final limitations = raw['limitations'];
    final reasoning = limitations is List
        ? limitations.join('; ')
        : (raw['reasoning']?.toString() ??
              'Dựa trên bối cảnh cảm biến và quy chuẩn VietGAP');
    return AiRecCard(
      id: raw['recommendationId']?.toString() ?? raw['id']?.toString() ?? '',
      title: cleanTechnicalIds(
        raw['summary']?.toString() ??
            raw['title']?.toString() ??
            'Khuyến nghị Vi khí hậu',
      ),
      text: cleanTechnicalIds(
        raw['details']?.toString() ??
            raw['summary']?.toString() ??
            raw['recommendationText']?.toString() ??
            '',
      ),
      reasoning: cleanTechnicalIds(reasoning),
      confidence: conf.round(),
      type: raw['recommendationType']?.toString() ?? 'NÔNG HỌC VIETGAP',
      status: (raw['status']?.toString() ?? 'READY').toUpperCase(),
      proposedAction: raw['proposedAction']?.toString(),
      durationSeconds: (raw['proposedDurationSeconds'] as num?)?.toInt(),
      validUntilUtc: DateTime.tryParse(raw['validUntilUtc']?.toString() ?? ''),
      commandStatus: raw['commandStatus']?.toString(),
    );
  }

  bool get isExpired =>
      validUntilUtc != null && !validUntilUtc!.isAfter(DateTime.now().toUtc());

  /// Còn chờ Owner duyệt (hiện nút Bỏ qua / Duyệt, nằm trong hàng đợi).
  bool get isPending => status == 'READY' && !isExpired;

  int get minutes =>
      durationSeconds != null ? (durationSeconds! / 60).round() : 0;

  String get actionLabel => switch (proposedAction) {
    'TurnOn' => 'Bật máy bơm tưới nước',
    'TurnOff' => 'Tắt máy bơm tưới',
    final a? => a,
    null => 'Điều khiển thiết bị',
  };

  String get approveLabel => switch (proposedAction) {
    'TurnOn' => 'Duyệt bật bơm (${durationSeconds != null ? minutes : 10}p)',
    'TurnOff' => 'Duyệt tắt bơm',
    _ => 'Duyệt $actionLabel',
  };
}

class ChatMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final String time;

  /// Khuyến nghị có thể duyệt gắn kèm câu trả lời (null nếu chỉ là tư vấn).
  final AiRecCard? recommendation;

  /// Tài liệu VietGAP được trích dẫn (mỗi phần tử là Map từ backend hoặc chuỗi tiêu đề).
  final List<dynamic>? sources;

  /// Dữ liệu backend đã gửi cho AI (prompt, cảm biến, ngưỡng, đoạn RAG) dạng JSON.
  final String? contextSnapshotJson;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.time,
    this.recommendation,
    this.sources,
    this.contextSnapshotJson,
  });
}
