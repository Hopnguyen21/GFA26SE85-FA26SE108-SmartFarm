part of '../models.dart';

class ChatMessageModel {
  final String id;
  final String text;
  final bool isUser;
  final String time;
  final String? actionProposal;
  // For AI recommendation cards
  final String? recommendationId;
  String? recommendationStatus; // PROPOSED, APPLIED, REJECTED
  final List<String>? sources;

  ChatMessageModel({
    required this.id,
    required this.text,
    required this.isUser,
    required this.time,
    this.actionProposal,
    this.recommendationId,
    this.recommendationStatus,
    this.sources,
  });
}

// ─────────────────────────────────────────
// AI Recommendation Model
// ─────────────────────────────────────────
class AiRecommendationModel {
  final String recommendationId;
  final String rationale;
  final String? riskWarning;
  final String? suggestedActionSummary;
  final String status; // PROPOSED, APPLIED, REJECTED, EXPIRED
  final String? actuatorId;
  final int? durationSeconds;
  final List<String>? sources;

  AiRecommendationModel({
    required this.recommendationId,
    required this.rationale,
    this.riskWarning,
    this.suggestedActionSummary,
    required this.status,
    this.actuatorId,
    this.durationSeconds,
    this.sources,
  });

  factory AiRecommendationModel.fromJson(Map<String, dynamic> json) {
    // 1. Support Backend AiRecommendationView (summary, details, proposedAction, proposedDurationSeconds)
    final summary = json['summary']?.toString() ?? json['rationale']?.toString() ?? '';
    final details = json['details']?.toString();
    final rationaleText = details != null && details.isNotEmpty ? details : summary;

    final proposedAction = json['proposedAction']?.toString();
    final isActionable = json['isActionable'] == true;
    final proposedDur = (json['proposedDurationSeconds'] as num?)?.toInt();
    final proposedActId = json['proposedActuatorId']?.toString();

    String? actionSummary;
    String? actuatorId = proposedActId;
    int? durationSeconds = proposedDur;

    if (isActionable && proposedAction != null) {
      if (proposedDur != null && proposedDur > 0) {
        final mins = (proposedDur / 60).round();
        actionSummary = mins > 0 ? 'Bật tưới $mins phút' : 'Bật tưới $proposedDur giây';
      } else {
        actionSummary = 'Kích hoạt: $proposedAction';
      }
    }

    // 2. Fallback to legacy suggestedAction object if present
    final action = json['suggestedAction'] as Map<String, dynamic>?;
    if (action != null) {
      final type = action['actionType']?.toString() ?? '';
      final dur = (action['durationSeconds'] as num?)?.toInt();
      if (type == 'IrrigateZone' && dur != null) {
        final mins = (dur / 60).round();
        actionSummary = 'Tưới $mins phút';
        durationSeconds = dur;
      } else if (type == 'NoAction') {
        actionSummary = null;
      } else {
        actionSummary = type;
      }
      actuatorId = action['actuatorId']?.toString() ?? actuatorId;
    }

    final sourcesList = (json['sources'] as List<dynamic>?)
        ?.map((s) => s is Map ? (s['title']?.toString() ?? '') : s.toString())
        .where((t) => t.isNotEmpty)
        .toList();

    return AiRecommendationModel(
      recommendationId: json['recommendationId']?.toString() ?? json['id']?.toString() ?? '',
      rationale: rationaleText,
      riskWarning:
          json['riskWarning']?.toString() ??
          (json['limitations'] is List ? (json['limitations'] as List).join('; ') : null),
      suggestedActionSummary: actionSummary,
      status: json['status']?.toString() ?? 'PROPOSED',
      actuatorId: actuatorId,
      durationSeconds: durationSeconds,
      sources: sourcesList,
    );
  }
}
