import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialZoneId;
  const AiAssistantScreen({super.key, this.initialZoneId});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false; // AI đang "gõ"
  Timer? _autoRefreshTimer;

  // Quick prompt chips
  static const List<String> _quickPrompts = [
    '🌱 Đất có đủ ẩm để tưới không?',
    '🌡️ Nhiệt độ hiện tại có tốt cho cây?',
    '💧 Khi nào nên tưới tiếp?',
    '🐛 Có dấu hiệu sâu bệnh không?',
    '📊 Tổng kết tình trạng zone hôm nay',
  ];

  bool _isLoadingHistory = false;
  bool _isLoadingContext = false;
  Map<String, dynamic>? _aiContext;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FarmProvider>(context, listen: false);
      if (widget.initialZoneId != null && widget.initialZoneId!.isNotEmpty) {
        final idx = provider.zones.indexWhere((z) => z.zoneId == widget.initialZoneId);
        if (idx != -1) {
          provider.selectZone(idx);
          _loadDataForZone(provider, widget.initialZoneId!);
          _startAutoRefresh();
          return;
        }
      }
      _loadDataForZone(provider, provider.currentZone.zoneId);
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isLoadingContext) return;
      final provider = Provider.of<FarmProvider>(context, listen: false);
      final zId = provider.currentZone.zoneId;
      if (zId.isNotEmpty) {
        _refreshContextSilently(zId);
      }
    });
  }

  Future<void> _refreshContextSilently(String zoneId) async {
    try {
      final ctx = await ApiService.getAiContext(zoneId);
      if (mounted && ctx != null) {
        setState(() => _aiContext = ctx);
      }
    } catch (_) {}
  }

  Future<void> _loadDataForZone(FarmProvider provider, String zoneId) async {
    if (zoneId.isEmpty) return;
    setState(() {
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
        ApiService.getAiContext(zoneId),
        ApiService.getAiHistory(zoneId),
      ]);

      if (!mounted) return;

      final ctx = results[0] as Map<String, dynamic>?;
      final history = results[1] as List<Map<String, dynamic>>? ?? [];

      if (history.isNotEmpty) {
        // Sort oldest first
        final sorted = [...history]..sort((a, b) {
          final tA = DateTime.tryParse(a['createdAtUtc']?.toString() ?? '') ?? DateTime(2000);
          final tB = DateTime.tryParse(b['createdAtUtc']?.toString() ?? '') ?? DateTime(2000);
          return tA.compareTo(tB);
        });

        final List<ChatMessageModel> restored = [defaultIntro];
        for (int i = 0; i < sorted.length; i++) {
          final h = sorted[i];
          final q = h['question']?.toString();
          final summary = h['summary']?.toString() ?? '';
          final details = h['details']?.toString();
          final aiText = details != null && details.isNotEmpty ? details : summary;
          final timeStr = h['createdAtUtc'] != null
              ? (DateTime.tryParse(h['createdAtUtc'].toString()) != null
                  ? _formatTime(DateTime.parse(h['createdAtUtc'].toString()).toLocal())
                  : 'Trước')
              : 'Trước';

          if (q != null && q.isNotEmpty) {
            restored.add(ChatMessageModel(
              id: 'hist-q-$i',
              text: q,
              isUser: true,
              time: timeStr,
            ));
          }

          final isActionable = h['isActionable'] == true;
          final proposedAction = h['proposedAction']?.toString();
          final recommendationStatus = h['status']?.toString().toUpperCase() ?? 'READY';
          final validUntil = DateTime.tryParse(h['validUntilUtc']?.toString() ?? '');
          final isExpired = validUntil != null && !validUntil.isAfter(DateTime.now().toUtc());
          final proposedDur = (h['proposedDurationSeconds'] as num?)?.toInt();
          String? actionSummary;
          if (isActionable && proposedAction != null) {
            final mins = proposedDur != null ? (proposedDur / 60).round() : 0;
            actionSummary = mins > 0 ? 'Bật tưới $mins phút' : 'Kích hoạt: $proposedAction';
          }

          final sourcesList = (h['sources'] as List<dynamic>?)
              ?.map((s) => s is Map ? (s['title']?.toString() ?? '') : s.toString())
              .where((t) => t.isNotEmpty)
              .toList();

          restored.add(ChatMessageModel(
            id: 'hist-a-$i',
            text: aiText,
            isUser: false,
            time: timeStr,
            actionProposal: actionSummary,
            recommendationId: h['recommendationId']?.toString() ?? h['id']?.toString(),
            recommendationStatus: recommendationStatus == 'READY' && isExpired ? 'EXPIRED' : recommendationStatus,
            sources: sourcesList,
          ));
        }

        provider.setChatMessages(restored);
      }

      setState(() {
        _aiContext = ctx;
        _isLoadingHistory = false;
        _isLoadingContext = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _isLoadingContext = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(FarmProvider provider, String text) async {
    if (text.trim().isEmpty) return;
    _controller.clear();

    final zone = provider.currentZone;
    if (zone.zoneId.isEmpty) {
      provider.addChatMessage(ChatMessageModel(
        id: 'ai-no-zone-${DateTime.now().millisecondsSinceEpoch}',
        text: 'Tài khoản chưa có Zone được phân quyền để tư vấn AI.',
        isUser: false,
        time: _formatTime(DateTime.now()),
      ));
      return;
    }
    // Add user message
    provider.addChatMessage(ChatMessageModel(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      isUser: true,
      time: _formatTime(DateTime.now()),
    ));
    _scrollToBottom();

    // Show typing indicator
    setState(() => _isTyping = true);

    // Call real API
    final rec = await ApiService.askAi(zoneId: zone.zoneId, prompt: text.trim());

    if (!mounted) return;
    setState(() => _isTyping = false);

    if (rec != null) {
      // Build AI message text
      final buf = StringBuffer(rec.rationale);
      if (rec.riskWarning != null && rec.riskWarning!.isNotEmpty) {
        buf.write('\n\n⚠️ ${rec.riskWarning}');
      }
      provider.addChatMessage(ChatMessageModel(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: buf.toString(),
        isUser: false,
        time: _formatTime(DateTime.now()),
        actionProposal: rec.suggestedActionSummary,
        recommendationId: rec.recommendationId,
        recommendationStatus: rec.status,
        sources: rec.sources,
      ));
    } else {
      // Offline fallback
      provider.addChatMessage(ChatMessageModel(
        id: 'ai-err-${DateTime.now().millisecondsSinceEpoch}',
        text:
            'Không thể kết nối AI lúc này. Kiểm tra kết nối mạng hoặc trạng thái máy chủ backend.',
        isUser: false,
        time: _formatTime(DateTime.now()),
      ));
    }
    _scrollToBottom();
  }

  Future<void> _applyRecommendation(
      FarmProvider provider, ChatMessageModel msg) async {
    if (msg.recommendationId == null || msg.recommendationId!.isEmpty) return;
    // Optimistically mark as loading
    msg.recommendationStatus = 'LOADING';
    provider.refreshChatState();

    final result = await ApiService.applyAiRecommendation(
      zoneId: provider.currentZone.zoneId,
      recommendationId: msg.recommendationId!,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final commandStatus = result['commandStatus']?.toString();
      msg.recommendationStatus = commandStatus?.toUpperCase() ?? 'ACCEPTED';
      final statusText = switch (commandStatus?.toLowerCase()) {
        'failed' => 'Lệnh đã được ghi nhận nhưng gửi tới thiết bị thất bại. Hãy kiểm tra kết nối thiết bị.',
        'pending' => 'Đã duyệt. Lệnh đang chờ gửi tới thiết bị.',
        'sent' => 'Đã gửi lệnh. Đang chờ thiết bị xác nhận thực thi.',
        'acknowledged' => 'Thiết bị đã xác nhận lệnh.',
        'timedout' => 'Thiết bị không xác nhận lệnh trước thời hạn.',
        'cancelled' => 'Lệnh đã bị hủy.',
        _ => 'Đã ghi nhận quyết định. Chưa có xác nhận thiết bị thực thi.',
      };
      provider.addChatMessage(ChatMessageModel(
        id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
        text: statusText,
        isUser: false,
        time: _formatTime(DateTime.now()),
      ));
      // Refresh AI context after action execution
      ApiService.getAiContext(provider.currentZone.zoneId).then((newCtx) {
        if (mounted && newCtx != null) {
          setState(() => _aiContext = newCtx);
        }
      });
      _scrollToBottom();
    } else if (result['blocked'] == true) {
      msg.recommendationStatus = 'REJECTED';
      final reason = result['message'] ?? 'Không đủ điều kiện an toàn';
      provider.addChatMessage(ChatMessageModel(
        id: 'sys-${DateTime.now().millisecondsSinceEpoch}',
        text:
            '🔒 Hệ thống từ chối phê duyệt:\n$reason\n\nVui lòng kiểm tra lịch tưới hoặc độ ẩm hiện tại.',
        isUser: false,
        time: _formatTime(DateTime.now()),
      ));
      _scrollToBottom();
    } else {
      msg.recommendationStatus = 'PROPOSED'; // Reset
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Áp dụng thất bại'),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
    provider.refreshChatState();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
            Text('Xóa lịch sử tư vấn?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Toàn bộ lịch sử trao đổi của Zone này sẽ được dọn dẹp khỏi màn hình.\n\nDữ liệu kiểm toán trên máy chủ vẫn được lưu trữ an toàn theo quy định.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await ApiService.clearAiHistory(zoneId);
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

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);
    final zone = farmProvider.currentZone;
    final isFarmer = farmProvider.currentRole == 'FARMER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFarmer ? 'Trợ lý AI Nông học (Thực địa)' : 'Trợ lý AI Nông học',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isFarmer
                        ? 'Dành cho Nông Dân · VietGAP · Cập nhật liên tục'
                        : 'Gemini · VietGAP · Dữ liệu thực tế',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Clear history button
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70, size: 20),
            tooltip: 'Xóa lịch sử trò chuyện',
            onPressed: () => _confirmClearHistory(farmProvider),
          ),
          // Zone selector button
          PopupMenuButton<int>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(
                      zone.name,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            tooltip: 'Chọn Zone',
            onSelected: (i) {
              farmProvider.selectZone(i);
              final newZone = farmProvider.zones[i];
              _loadDataForZone(farmProvider, newZone.zoneId);
            },
            itemBuilder: (_) => farmProvider.zones
                .asMap()
                .entries
                .map((e) => PopupMenuItem(
                      value: e.key,
                      child: Text(
                        e.value.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: e.key == farmProvider.selectedZoneIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: e.key == farmProvider.selectedZoneIndex
                              ? const Color(0xFF10B981)
                              : Colors.black87,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: zone.zoneId.isEmpty
          ? _buildNoPermissionView(farmProvider)
          : Column(
              children: [
                // Context banner
                _buildContextBanner(zone),

                if (_isLoadingHistory || _isLoadingContext)
                  const LinearProgressIndicator(
                    color: Color(0xFF10B981),
                    backgroundColor: Color(0xFFECFDF5),
                    minHeight: 2,
                  ),

                // Quick prompts
                if (farmProvider.chatMessages.length <= 1)
                  _buildQuickPrompts(farmProvider),

                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: farmProvider.chatMessages.length +
                        (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_isTyping &&
                          index == farmProvider.chatMessages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = farmProvider.chatMessages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildMessage(msg, farmProvider),
                      );
                    },
                  ),
                ),

                // Input bar
                _buildInputBar(farmProvider),
              ],
            ),
    );
  }

  Widget _buildNoPermissionView(FarmProvider farmProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa chọn hoặc không có quyền Khu vực',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn chưa được phân quyền phụ trách hoặc chưa chọn khu vực canh tác (Zone) nào. Trợ lý AI cần ngữ cảnh khu vực để tư vấn chính xác.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextBanner(ZoneModel zone) {
    final ctx = _aiContext;
    final cropName = ctx?['cropName']?.toString();
    final growthStage = ctx?['growthStageName']?.toString();
    final profileName = ctx?['growthProfileName']?.toString();
    final seasonDays = ctx?['seasonAgeDays'] ?? ctx?['daysSinceStart'];
    final telemetryList = (ctx?['telemetry'] as List<dynamic>?) ?? [];
    final requirementsList = (ctx?['requirements'] as List<dynamic>?) ?? [];
    final weather = ctx?['weather'] as Map<String, dynamic>?;

    final freshCount = telemetryList.where((x) => x['isFresh'] == true).length;
    final weatherOk = weather?['available'] == true;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Zone name, Crop & VietGAP Profile
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctx?['zoneName']?.toString() ?? zone.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (cropName != null && cropName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Text(
                              '🌿 $cropName${growthStage != null ? ' • $growthStage' : ''}${seasonDays != null ? ' (Ngày $seasonDays)' : ''}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                        if (profileName != null && profileName.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '📜 $profileName',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isLoadingContext
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isLoadingContext
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    _isLoadingContext
                        ? 'Đang tải...'
                        : '$freshCount realtime · ${weatherOk ? '🌤️ Thời tiết' : '⚠️ Thiếu TT'}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _isLoadingContext
                          ? const Color(0xFF64748B)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Row 2: Micro sensor chips & standard VietGAP ranges
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Row(
              children: [
                if (telemetryList.isNotEmpty) ...[
                  ...telemetryList.map((t) {
                    final code = t['parameterCode']?.toString() ?? '';
                    final val = t['value']?.toString() ?? '0';
                    final unit = t['unit']?.toString() ?? '';
                    final req = requirementsList.firstWhere(
                      (r) => r['parameterCode']?.toString() == code,
                      orElse: () => null,
                    );

                    final paramLabel = switch (code) {
                      'Temperature' => '🌡️ Nhiệt độ',
                      'AirHumidity' => '💧 Ẩm KK',
                      'SoilMoisture' => '🌱 Ẩm đất',
                      'Light' || 'LightIntensity' => '☀️ Ánh sáng',
                      'SoilPh' => '🧪 pH đất',
                      'SoilEc' => '⚡ EC đất',
                      _ => code,
                    };

                    String? reqText;
                    if (req != null) {
                      final minV = req['minValue'];
                      final maxV = req['maxValue'];
                      if (minV != null && maxV != null) {
                        reqText = '(chuẩn: $minV-$maxV)';
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$paramLabel: ',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                          Text(
                            '$val $unit',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (reqText != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              reqText,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  // Fallback to zone properties
                  _buildSensorChip('🌱 Ẩm đất', zone.telemetryIsFresh ? '${zone.currentSoilMoisture.toStringAsFixed(1)}%' : '—'),
                  _buildSensorChip('🌡️ Nhiệt độ', zone.telemetryIsFresh ? '${zone.currentTemp.toStringAsFixed(1)}°C' : '—'),
                  _buildSensorChip('💧 Ẩm KK', zone.telemetryIsFresh ? '${zone.currentHumidity.toStringAsFixed(0)}% RH' : '—'),
                ],

                if (weatherOk)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      '🌤️ Dự báo 6h: ${weather?['rainProbabilityNext6HoursMaxPercent'] ?? 0}% mưa',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorChip(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
      ),
    );
  }

  Widget _buildQuickPrompts(FarmProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: Colors.white,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _quickPrompts
            .map((p) => GestureDetector(
                  onTap: () => _sendMessage(provider, p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF6EE7B7), width: 1),
                    ),
                    child: Text(
                      p,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF065F46),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMessage(ChatMessageModel msg, FarmProvider provider) {
    return Row(
      mainAxisAlignment:
          msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!msg.isUser) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF062326),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.smart_toy,
                color: Color(0xFF10B981), size: 15),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: msg.isUser ? const Color(0xFF062326) : Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight:
                    msg.isUser ? Radius.zero : const Radius.circular(16),
                bottomLeft:
                    !msg.isUser ? Radius.zero : const Radius.circular(16),
              ),
              border: Border.all(
                color: msg.isUser
                    ? Colors.transparent
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: msg.isUser
                        ? Colors.white
                        : const Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
                // VietGAP Citations & Sources badge if present
                if (msg.sources != null && msg.sources!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book, size: 12, color: Color(0xFF059669)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'VietGAP: ${msg.sources!.join(", ")}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Recommendation action card
                if (msg.actionProposal != null &&
                    msg.recommendationStatus != null)
                  _buildActionCard(msg, provider),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    msg.time,
                    style: TextStyle(
                      fontSize: 9,
                      color: msg.isUser
                          ? Colors.white60
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(ChatMessageModel msg, FarmProvider provider) {
    final status = msg.recommendationStatus ?? 'PROPOSED';
    final isApplied = status == 'SENT' || status == 'PENDING' || status == 'FAILED' || status == 'ACCEPTED';
    final isRejected = status == 'REJECTED';
    final isTerminal = status == 'EXPIRED' || status == 'SUPERSEDED' || status == 'IGNORED' || status == 'LOWCONFIDENCE' || status == 'INSUFFICIENTDATA' || status == 'PROVIDERUNAVAILABLE' || status == 'INVALIDPROVIDEROUTPUT';
    final isLoading = status == 'LOADING';

    Color cardBg;
    Color borderColor;
    Color textColor;
    String statusText;
    IconData statusIcon;

    if (isApplied) {
      cardBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF86EFAC);
      textColor = const Color(0xFF166534);
      statusText = switch (status) {
        'FAILED' => 'Gửi lệnh thất bại',
        'PENDING' => 'Lệnh đang chờ gửi',
        'SENT' => 'Đã gửi lệnh, chờ thiết bị xác nhận',
        'ACKNOWLEDGED' => 'Thiết bị đã xác nhận lệnh',
        'TIMEDOUT' => 'Thiết bị không xác nhận trước thời hạn',
        'CANCELLED' => 'Lệnh đã bị hủy',
        _ => 'Đã duyệt; chưa tải trạng thái lệnh',
      };
      statusIcon = Icons.check_circle;
    } else if (isRejected) {
      cardBg = const Color(0xFFFFF1F2);
      borderColor = const Color(0xFFFECDD3);
      textColor = const Color(0xFF9F1239);
      statusText = 'Đã từ chối (an toàn)';
      statusIcon = Icons.block;
    } else if (isTerminal) {
      cardBg = const Color(0xFFF8FAFC);
      borderColor = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF64748B);
      statusText = status == 'EXPIRED' ? 'Khuyến nghị đã hết hạn' : 'Khuyến nghị không còn hiệu lực';
      statusIcon = Icons.info_outline;
    } else {
      cardBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF86EFAC);
      textColor = const Color(0xFF166534);
      statusText = msg.actionProposal!;
      statusIcon = Icons.verified;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 16, color: textColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (!isApplied && !isRejected && !isTerminal) () {
              final currentFarmer = provider.farmersForCurrentFarm.isNotEmpty ? provider.farmersForCurrentFarm.first : null;
              final canControl = provider.currentRole == 'OWNER' || (provider.currentRole == 'FARMER' && (currentFarmer?.permissions.contains('CAN_CONTROL_PUMP') ?? false));
              if (canControl) {
                return SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLoading
                        ? null
                        : () => _applyRecommendation(provider, msg),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Áp dụng',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                  ),
                );
              } else {
                return Tooltip(
                  message: 'Cần quyền Điều Khiển Thiết Bị để thực thi khuyến nghị',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: Color(0xFFB45309)),
                        SizedBox(width: 4),
                        Text(
                          'Cần Quyền Bơm',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF062326),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.smart_toy,
              color: Color(0xFF10B981), size: 15),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomLeft: Radius.zero,
            ),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDot(0),
              const SizedBox(width: 4),
              _buildDot(150),
              const SizedBox(width: 4),
              _buildDot(300),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: child,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildInputBar(FarmProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 13),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText:
                        'Hỏi về độ ẩm, bệnh lá, lịch tưới VietGAP...',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (v) => _sendMessage(provider, v),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF10B981),
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 17),
                  onPressed: () =>
                      _sendMessage(provider, _controller.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 10, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Bảo mật: Không gửi số điện thoại, thông tin liên hệ hoặc hợp đồng',
                  style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
