import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/models/models.dart';
import '../../core/utils/ai_text.dart';
import 'ai_payload_sheet.dart';
import 'ai_payload_snapshot.dart';

part 'parts/ai_screen_actions.dart';
part 'parts/ai_screen_context_banner.dart';
part 'parts/ai_screen_messages.dart';
part 'parts/ai_screen_widgets.dart';

const Color _kAiGreen = Color(0xFF119653);

/// Trợ lý AI Nông học VietGAP của Owner: cùng bố cục và thao tác với web (`AIAssistantPage`).
class AiAssistantScreen extends StatefulWidget {
  final String? initialZoneId;
  const AiAssistantScreen({super.key, this.initialZoneId});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with WidgetsBindingObserver {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false; // AI đang đối chiếu dữ liệu
  Timer? _autoRefreshTimer;
  final List<Timer> _pollTimers = [];

  // Gợi ý nhanh: nhãn ngắn hiển thị, câu hỏi đầy đủ gửi cho AI (như web).
  static const List<(String, String)> _quickPrompts = [
    (
      '💧 Nhu cầu tưới',
      'Nhiệt độ và độ ẩm đất hiện tại thế nào, có cần kích hoạt tưới nhỏ giọt không?',
    ),
    (
      '🐛 Sâu bệnh hại',
      'Cây trồng ở giai đoạn hiện tại có nguy cơ mắc bệnh gì và cách phòng trừ IPM theo VietGAP?',
    ),
    (
      '🌤️ Thời tiết',
      'Thời tiết dự báo tiếp theo có thích hợp cho sự phát triển của cây không?',
    ),
    ('⏰ Lịch tưới', 'Có lịch tưới tự động nào sắp chạy trong hôm nay không?'),
    (
      '🌧️ Hoãn tưới khi mưa',
      'Với xác suất mưa ngoài trời hiện tại, quy tắc tự động hóa BR-AUTOMATION-01 có tạm dừng các ca tưới của Zone không?',
    ),
  ];

  bool _isLoadingHistory = false;
  bool _isLoadingContext = false;
  bool _showSensors = false;
  bool _showQueue = false;
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

  /// Làm mới bối cảnh cảm biến mỗi 10 giây như web để đồng bộ với bảng điều khiển.
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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
    for (final t in _pollTimers) {
      t.cancel();
    }
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
    final queue = _queueOf(farmProvider);
    // Bàn phím đang mở: ẩn gợi ý nhanh để vùng hội thoại còn đủ chỗ trên màn nhỏ.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

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
                color: _kAiGreen.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Color(0xFF34D399),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trợ lý AI Nông học',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Vi khí hậu & đề xuất tưới',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.white70,
              size: 20,
            ),
            tooltip: 'Xóa lịch sử',
            onPressed: () => _confirmClearHistory(farmProvider),
          ),
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
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            tooltip: 'Chọn Khu Vực (Zone)',
            onSelected: (i) {
              farmProvider.selectZone(i);
              final newZone = farmProvider.zones[i];
              _loadDataForZone(farmProvider, newZone.zoneId);
            },
            itemBuilder: (_) => [
              for (final e in farmProvider.zones.asMap().entries)
                PopupMenuItem(
                  value: e.key,
                  child: Text(
                    '${e.value.farmName.isNotEmpty ? '[${e.value.farmName}] ' : ''}${e.value.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: e.key == farmProvider.selectedZoneIndex
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: e.key == farmProvider.selectedZoneIndex
                          ? _kAiGreen
                          : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: zone.zoneId.isEmpty
          ? _buildNoPermissionView(farmProvider)
          : LayoutBuilder(
              builder: (context, box) => Column(
                children: [
                  // Banner + hàng đợi tối đa 40% chiều cao (cuộn được) để khung chat luôn còn chỗ ở cửa sổ thấp.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: box.maxHeight * 0.4),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildContextBanner(zone),
                          _buildQueueStrip(farmProvider, queue),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoadingHistory || _isLoadingContext)
                    const LinearProgressIndicator(
                      color: _kAiGreen,
                      backgroundColor: Color(0xFFECFDF5),
                      minHeight: 2,
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(14),
                      itemCount:
                          farmProvider.chatMessages.length +
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
                  // Chiều cao thấp (cửa sổ nhỏ/web): bỏ gợi ý nhanh để khung chat luôn còn chỗ, không tràn.
                  if (!keyboardOpen && box.maxHeight >= 630)
                    _buildQuickPrompts(farmProvider),
                  _buildInputBar(farmProvider),
                ],
              ),
            ),
    );
  }
}
