import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/models/models.dart';

part 'parts/ai_screen_actions.dart';
part 'parts/ai_screen_context_banner.dart';
part 'parts/ai_screen_messages.dart';

class AiAssistantScreen extends StatefulWidget {
  final String? initialZoneId;
  const AiAssistantScreen({super.key, this.initialZoneId});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

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
        final idx = provider.zones.indexWhere(
          (z) => z.zoneId == widget.initialZoneId,
        );
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
      final ctx = await AiApi.getAiContext(zoneId);
      if (mounted && ctx != null) {
        setState(() => _aiContext = ctx);
      }
    } catch (_) {}
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

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
              child: const Icon(
                Icons.psychology,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFarmer
                        ? 'Trợ lý AI Nông học (Thực địa)'
                        : 'Trợ lý AI Nông học',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isFarmer
                        ? 'Dành cho Nông Dân · VietGAP · Cập nhật liên tục'
                        : 'Gemini · VietGAP · Dữ liệu thực tế',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
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
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.white70,
              size: 20,
            ),
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
                .map(
                  (e) => PopupMenuItem(
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
                  ),
                )
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
                    itemCount:
                        farmProvider.chatMessages.length + (_isTyping ? 1 : 0),
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
}
