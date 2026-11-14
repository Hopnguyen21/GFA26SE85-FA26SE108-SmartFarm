part of '../ai_screen.dart';

const String _kAiIntro =
    'Xin chào! Tôi là Trợ lý AI Nông học VietGAP. Tôi có thể hỗ trợ bạn theo dõi vi khí hậu, tưới tiêu và phát hiện sâu bệnh.';

extension _AiAssistantScreenStateActions on _AiAssistantScreenState {
  ChatMessageModel _intro() => ChatMessageModel(
    id: 'msg-01',
    text: _kAiIntro,
    isUser: false,
    time: 'Hôm nay',
  );

  /// Hàng đợi duyệt: các khuyến nghị còn hiệu lực và chưa được quyết định, mới nhất trước (như cột phải trên web).
  List<AiRecCard> _queueOf(FarmProvider provider) => [
    for (final m in provider.chatMessages.reversed)
      if (m.recommendation != null && m.recommendation!.isPending)
        m.recommendation!,
  ];

  /// Dựng tin nhắn AI từ phản hồi backend (hỏi mới hoặc lịch sử). Thẻ duyệt chỉ có khi khuyến nghị thực sự có hành động.
  ChatMessageModel _aiMessage(
    String id,
    Map<String, dynamic> h,
    String time, {
    bool requireRecommendationId = false,
  }) {
    final text = cleanTechnicalIds(
      h['details']?.toString() ??
          h['summary']?.toString() ??
          h['text']?.toString() ??
          h['answer']?.toString() ??
          'Mô hình AI Nông học đã ghi nhận yêu cầu.',
    );
    final recId = h['recommendationId']?.toString() ?? h['id']?.toString();
    final hasAction =
        h['isActionable'] == true &&
        h['proposedAction'] != null &&
        (!requireRecommendationId || (recId != null && recId.isNotEmpty));
    final sources = h['sources'] is List && (h['sources'] as List).isNotEmpty
        ? h['sources'] as List
        : null;
    return ChatMessageModel(
      id: id,
      text: text,
      isUser: false,
      time: time,
      recommendation: hasAction ? AiRecCard.fromJson(h) : null,
      sources: sources,
      contextSnapshotJson: h['contextSnapshotJson']?.toString(),
    );
  }

  Future<void> _loadDataForZone(FarmProvider provider, String zoneId) async {
    if (zoneId.isEmpty) return;
    for (final t in _pollTimers) {
      t.cancel();
    }
    _pollTimers.clear();
    _rebuild(() {
      _isLoadingHistory = true;
      _isLoadingContext = true;
      _aiContext = null;
      _showQueue = false;
    });
    // Đổi Zone là bỏ ngay hội thoại và khuyến nghị của Zone cũ.
    provider.setChatMessages([_intro()]);

    try {
      final results = await Future.wait([
        AiApi.getAiContext(zoneId),
        AiApi.getAiHistory(zoneId),
      ]);
      if (!mounted || provider.currentZone.zoneId != zoneId) return;

      final ctx = results[0] as Map<String, dynamic>?;
      final history = results[1] as List<Map<String, dynamic>>? ?? [];

      if (history.isNotEmpty) {
        final sorted = [...history]
          ..sort((a, b) {
            final tA =
                DateTime.tryParse(a['createdAtUtc']?.toString() ?? '') ??
                DateTime(2000);
            final tB =
                DateTime.tryParse(b['createdAtUtc']?.toString() ?? '') ??
                DateTime(2000);
            return tA.compareTo(tB);
          });
        final restored = <ChatMessageModel>[_intro()];
        for (var i = 0; i < sorted.length; i++) {
          final h = sorted[i];
          final created = DateTime.tryParse(
            h['createdAtUtc']?.toString() ?? '',
          );
          final timeStr = created != null
              ? _formatTime(created.toLocal())
              : 'Trước';
          final q = h['question']?.toString();
          if (q != null && q.isNotEmpty) {
            restored.add(
              ChatMessageModel(
                id: 'hist-q-$i',
                text: q,
                isUser: true,
                time: timeStr,
              ),
            );
          }
          restored.add(_aiMessage('hist-a-$i', h, timeStr));
        }
        provider.setChatMessages(restored);
      }

      _rebuild(() {
        _aiContext = ctx;
        _isLoadingHistory = false;
        _isLoadingContext = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        _rebuild(() {
          _isLoadingHistory = false;
          _isLoadingContext = false;
        });
      }
    }
  }

  void _say(FarmProvider provider, String text, {String idPrefix = 'ai'}) {
    provider.addChatMessage(
      ChatMessageModel(
        id: '$idPrefix-${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: false,
        time: _formatTime(DateTime.now()),
      ),
    );
    _scrollToBottom();
  }

  Future<void> _sendMessage(FarmProvider provider, String text) async {
    final question = text.trim();
    if (question.isEmpty || _isTyping) return;
    _controller.clear();

    final zone = provider.currentZone;
    if (zone.zoneId.isEmpty) {
      _say(
        provider,
        'Tài khoản chưa có Zone được phân quyền để tư vấn AI.',
        idPrefix: 'ai-no-zone',
      );
      return;
    }
    provider.addChatMessage(
      ChatMessageModel(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        text: question,
        isUser: true,
        time: _formatTime(DateTime.now()),
      ),
    );
    _scrollToBottom();
    _rebuild(() => _isTyping = true);

    final res = await AiApi.askAi(zoneId: zone.zoneId, prompt: question);
    if (!mounted) return;
    _rebuild(() => _isTyping = false);
    // Đã đổi Zone trong lúc chờ: bỏ câu trả lời của Zone cũ.
    if (provider.currentZone.zoneId != zone.zoneId) return;

    final data = res.data;
    if (data != null) {
      provider.addChatMessage(
        _aiMessage(
          'ai-${DateTime.now().millisecondsSinceEpoch}',
          data,
          _formatTime(DateTime.now()),
          requireRecommendationId: true,
        ),
      );
    } else {
      _say(
        provider,
        res.error ??
            'Không thể lấy tư vấn AI từ dữ liệu hiện tại. Vui lòng kiểm tra kết nối và thử lại.',
        idPrefix: 'ai-err',
      );
    }
    _scrollToBottom();
  }

  /// Duyệt khuyến nghị: backend kiểm tra an toàn rồi mới tạo lệnh; trạng thái lệnh lấy từ phản hồi và nhật ký thiết bị.
  Future<void> _approve(FarmProvider provider, AiRecCard rec) async {
    if (rec.busy) return;
    final zoneId = provider.currentZone.zoneId;
    rec.busy = true;
    provider.refreshChatState();

    final result = await AiApi.applyAiRecommendation(
      zoneId: zoneId,
      recommendationId: rec.id,
    );
    if (!mounted) return;
    rec.busy = false;

    if (result['success'] == true) {
      rec.status = 'ACCEPTED';
      rec.commandStatus = result['commandStatus']?.toString() ?? 'Pending';
      rec.commandId = result['commandId']?.toString();
      provider.refreshChatState();
      _schedulePollCommand(provider, zoneId, rec);
      // Làm mới bối cảnh sau khi duyệt.
      _refreshContextSilently(zoneId);
    } else {
      provider.refreshChatState();
      final reason = result['blocked'] == true
          ? 'Hệ thống từ chối: ${result['message'] ?? 'kiểm tra an toàn không đạt'}'
          : (result['message']?.toString() ?? 'Áp dụng thất bại');
      _say(
        provider,
        '⚠️ Chưa thể duyệt khuyến nghị: $reason',
        idPrefix: 'ai-warn',
      );
      // 409 có thể là đã được xử lý từ trước hoặc bị chặn an toàn: lấy trạng thái thật từ lịch sử thay vì đoán.
      if (result['blocked'] == true)
        _syncStatusFromHistory(provider, zoneId, rec);
    }
  }

  Future<void> _reject(FarmProvider provider, AiRecCard rec) async {
    if (rec.busy) return;
    rec.busy = true;
    provider.refreshChatState();
    final result = await AiApi.applyAiRecommendation(
      zoneId: provider.currentZone.zoneId,
      recommendationId: rec.id,
      decision: 'Rejected',
      reason: 'Từ chối bởi chủ trang trại',
    );
    if (!mounted) return;
    rec.busy = false;
    if (result['success'] == true) {
      rec.status = 'REJECTED';
    } else {
      _say(
        provider,
        result['message']?.toString() ?? 'Không thể lưu quyết định từ chối.',
        idPrefix: 'ai-warn',
      );
    }
    provider.refreshChatState();
  }

  Future<void> _syncStatusFromHistory(
    FarmProvider provider,
    String zoneId,
    AiRecCard rec,
  ) async {
    final history = await AiApi.getAiHistory(zoneId);
    if (!mounted || provider.currentZone.zoneId != zoneId) return;
    final match = history
        .where((h) => (h['recommendationId'] ?? h['id'])?.toString() == rec.id)
        .firstOrNull;
    final status = match?['status']?.toString().toUpperCase();
    if (status != null && status.isNotEmpty && status != rec.status) {
      rec.status = status;
      provider.refreshChatState();
    }
  }

  /// Hỏi lại nhật ký lệnh sau 2,5 giây và 5,5 giây để thấy trạng thái thật từ thiết bị (như web).
  void _schedulePollCommand(
    FarmProvider provider,
    String zoneId,
    AiRecCard rec,
  ) {
    final id = rec.commandId;
    if (id == null || id.isEmpty) return;
    Future<void> poll() async {
      try {
        final logs = await AutomationApi.getActuatorHistory(zoneId);
        final cmd = logs
            .where((c) => (c['commandId'] ?? c['id'])?.toString() == id)
            .firstOrNull;
        final real = cmd?['status']?.toString();
        if (mounted && real != null && aiCommandLabels.containsKey(real)) {
          rec.commandStatus = real;
          provider.refreshChatState();
        }
      } catch (_) {}
    }

    _pollTimers
      ..add(Timer(const Duration(milliseconds: 2500), poll))
      ..add(Timer(const Duration(milliseconds: 5500), poll));
  }

  Future<void> _confirmClearHistory(FarmProvider provider) async {
    final zoneId = provider.currentZone.zoneId;
    if (zoneId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xóa lịch sử tư vấn?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa toàn bộ lịch sử trò chuyện và khuyến nghị AI của khu vực này?\n\nDữ liệu kiểm toán trên máy chủ vẫn được lưu trữ theo quy định.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await AiApi.clearAiHistory(zoneId);
    if (!mounted) return;
    if (ok) {
      provider.setChatMessages([
        ChatMessageModel(
          id: 'm-reset-${DateTime.now().millisecondsSinceEpoch}',
          text:
              'Lịch sử tư vấn đã được làm mới. Tôi sẵn sàng phân tích vi khí hậu và trả lời các câu hỏi mới của bạn!',
          isUser: false,
          time: _formatTime(DateTime.now()),
        ),
      ]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể xóa lịch sử tư vấn AI lúc này. Vui lòng thử lại sau.',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }
}
