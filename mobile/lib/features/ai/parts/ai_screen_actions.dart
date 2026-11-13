part of '../ai_screen.dart';

extension _AiAssistantScreenStateActions on _AiAssistantScreenState {
  Future<void> _loadDataForZone(FarmProvider provider, String zoneId) async {
    if (zoneId.isEmpty) return;
    _rebuild(() {
      _isLoadingHistory = true;
      _isLoadingContext = true;
      _aiContext = null;
    });

    final defaultIntro = ChatMessageModel(
      id: 'msg-01',
      text:
          'Xin chào! Tôi là Trợ lý Nông học AI SmartFarm, được hỗ trợ bởi Gemini + dữ liệu cảm biến thực tế.\n\nHỏi tôi về độ ẩm, bệnh lá, lịch tưới, hoặc bất kỳ vấn đề nào về cây trồng theo chuẩn VietGAP!',
      isUser: false,
      time: _formatTime(DateTime.now()),
    );
    provider.setChatMessages([defaultIntro]);

    try {
      final results = await Future.wait([
        AiApi.getAiContext(zoneId),
        AiApi.getAiHistory(zoneId),
      ]);

      if (!mounted) return;

      final ctx = results[0] as Map<String, dynamic>?;
      final history = results[1] as List<Map<String, dynamic>>? ?? [];

      if (history.isNotEmpty) {
        // Sort oldest first
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

        final List<ChatMessageModel> restored = [defaultIntro];
        for (int i = 0; i < sorted.length; i++) {
          final h = sorted[i];
          final q = h['question']?.toString();
          final summary = h['summary']?.toString() ?? '';
          final details = h['details']?.toString();
          final aiText = details != null && details.isNotEmpty
              ? details
              : summary;
          final timeStr = h['createdAtUtc'] != null
              ? (DateTime.tryParse(h['createdAtUtc'].toString()) != null
                    ? _formatTime(
                        DateTime.parse(h['createdAtUtc'].toString()).toLocal(),
                      )
                    : 'Trước')
              : 'Trước';

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

          final isActionable = h['isActionable'] == true;
          final proposedAction = h['proposedAction']?.toString();
          final recommendationStatus =
              h['status']?.toString().toUpperCase() ?? 'READY';
          final validUntil = DateTime.tryParse(
            h['validUntilUtc']?.toString() ?? '',
          );
          final isExpired =
              validUntil != null && !validUntil.isAfter(DateTime.now().toUtc());
          final proposedDur = (h['proposedDurationSeconds'] as num?)?.toInt();
          String? actionSummary;
          if (isActionable && proposedAction != null) {
            final mins = proposedDur != null ? (proposedDur / 60).round() : 0;
            actionSummary = mins > 0
                ? 'Bật tưới $mins phút'
                : 'Kích hoạt: $proposedAction';
          }

          final sourcesList = (h['sources'] as List<dynamic>?)
              ?.map(
                (s) => s is Map ? (s['title']?.toString() ?? '') : s.toString(),
              )
              .where((t) => t.isNotEmpty)
              .toList();

          restored.add(
            ChatMessageModel(
              id: 'hist-a-$i',
              text: aiText,
              isUser: false,
              time: timeStr,
              actionProposal: actionSummary,
              recommendationId:
                  h['recommendationId']?.toString() ?? h['id']?.toString(),
              recommendationStatus: recommendationStatus == 'READY' && isExpired
                  ? 'EXPIRED'
                  : recommendationStatus,
              sources: sourcesList,
            ),
          );
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

  Future<void> _sendMessage(FarmProvider provider, String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    final zone = provider.currentZone;
    if (zone.zoneId.isEmpty) {
      provider.addChatMessage(
        ChatMessageModel(
          id: 'ai-no-zone-${DateTime.now().millisecondsSinceEpoch}',
          text: 'Tài khoản chưa có Zone được phân quyền để tư vấn AI.',
          isUser: false,
          time: _formatTime(DateTime.now()),
        ),
      );
      return;
    }
    // Add user message
    provider.addChatMessage(
      ChatMessageModel(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        text: text.trim(),
        isUser: true,
        time: _formatTime(DateTime.now()),
      ),
    );
    _scrollToBottom();

    // Show typing indicator
    _rebuild(() => _isTyping = true);

    // Call real API
    final rec = await AiApi.askAi(zoneId: zone.zoneId, prompt: text.trim());

    if (!mounted) return;
    _rebuild(() => _isTyping = false);

    if (rec != null) {
      // Build AI message text
      final buf = StringBuffer(rec.rationale);
      if (rec.riskWarning != null && rec.riskWarning!.isNotEmpty) {
        buf.write('\n\n⚠️ ${rec.riskWarning}');
      }
      provider.addChatMessage(
        ChatMessageModel(
          id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
          text: buf.toString(),
          isUser: false,
          time: _formatTime(DateTime.now()),
          actionProposal: rec.suggestedActionSummary,
          recommendationId: rec.recommendationId,
          recommendationStatus: rec.status,
          sources: rec.sources,
        ),
      );
    } else {
      // Offline fallback
      provider.addChatMessage(
        ChatMessageModel(
          id: 'ai-err-${DateTime.now().millisecondsSinceEpoch}',
          text:
              'Không thể kết nối AI lúc này. Kiểm tra kết nối mạng hoặc trạng thái máy chủ backend.',
          isUser: false,
          time: _formatTime(DateTime.now()),
        ),
      );
    }
    _scrollToBottom();
  }

  Future<void> _applyRecommendation(
    FarmProvider provider,
    ChatMessageModel msg,
  ) async {
    if (msg.recommendationId == null || msg.recommendationId!.isEmpty) return;
    // Optimistically mark as loading
    msg.recommendationStatus = 'LOADING';
    provider.refreshChatState();

    final result = await AiApi.applyAiRecommendation(
      zoneId: provider.currentZone.zoneId,
      recommendationId: msg.recommendationId!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final commandStatus = result['commandStatus']?.toString();
      msg.recommendationStatus = commandStatus?.toUpperCase() ?? 'ACCEPTED';
      final statusText = switch (commandStatus?.toLowerCase()) {
        'failed' =>
          'Lệnh đã được ghi nhận nhưng gửi tới thiết bị thất bại. Hãy kiểm tra kết nối thiết bị.',
        'pending' => 'Đã duyệt. Lệnh đang chờ gửi tới thiết bị.',
        'sent' => 'Đã gửi lệnh. Đang chờ thiết bị xác nhận thực thi.',
        'acknowledged' => 'Thiết bị đã xác nhận lệnh.',
        'timedout' => 'Thiết bị không xác nhận lệnh trước thời hạn.',
        'cancelled' => 'Lệnh đã bị hủy.',
        _ => 'Đã ghi nhận quyết định. Chưa có xác nhận thiết bị thực thi.',
      };
      provider.addChatMessage(
        ChatMessageModel(
          id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
          text: statusText,
          isUser: false,
          time: _formatTime(DateTime.now()),
        ),
      );
      // Refresh AI context after action execution
      AiApi.getAiContext(provider.currentZone.zoneId).then((newCtx) {
        if (mounted && newCtx != null) {
          _rebuild(() => _aiContext = newCtx);
        }
      });
      _scrollToBottom();
    } else if (result['blocked'] == true) {
      msg.recommendationStatus = 'REJECTED';
      final reason = result['message'] ?? 'Không đủ điều kiện an toàn';
      provider.addChatMessage(
        ChatMessageModel(
          id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
          text:
              '🔒 Hệ thống từ chối phê duyệt:\n$reason\n\nVui lòng kiểm tra lịch tưới hoặc độ ẩm hiện tại.',
          isUser: false,
          time: _formatTime(DateTime.now()),
        ),
      );
      _scrollToBottom();
    } else {
      msg.recommendationStatus = 'PROPOSED'; // Reset
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Áp dụng thất bại'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
    provider.refreshChatState();
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
            Text(
              'Xóa lịch sử tư vấn?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Toàn bộ lịch sử trao đổi của Zone này sẽ được dọn dẹp khỏi màn hình.\n\nDữ liệu kiểm toán trên máy chủ vẫn được lưu trữ an toàn theo quy định.',
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

    if (confirmed == true) {
      final ok = await AiApi.clearAiHistory(zoneId);
      if (ok && mounted) {
        final defaultIntro = ChatMessageModel(
          id: 'msg-01',
          text:
              'Xin chào! Tôi là Trợ lý Nông học AI SmartFarm, được hỗ trợ bởi Gemini + dữ liệu cảm biến thực tế.\n\nHỏi tôi về độ ẩm, bệnh lá, lịch tưới, hoặc bất kỳ vấn đề nào về cây trồng theo chuẩn VietGAP!',
          isUser: false,
          time: _formatTime(DateTime.now()),
        );
        provider.setChatMessages([defaultIntro]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã dọn dẹp lịch sử trò chuyện AI của Zone.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }
}
