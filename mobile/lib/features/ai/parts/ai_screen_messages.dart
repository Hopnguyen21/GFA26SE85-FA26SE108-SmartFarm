part of '../ai_screen.dart';

extension _AiAssistantScreenStateMessages on _AiAssistantScreenState {
  Widget _buildMessage(ChatMessageModel msg, FarmProvider provider) {
    return Row(
      mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!msg.isUser) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF062326), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.smart_toy, color: Color(0xFF10B981), size: 15),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: msg.isUser ? const Color(0xFF062326) : Colors.white,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: msg.isUser ? Radius.zero : const Radius.circular(16),
                bottomLeft: !msg.isUser ? Radius.zero : const Radius.circular(16),
              ),
              border: Border.all(color: msg.isUser ? Colors.transparent : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: msg.isUser ? Colors.white : const Color(0xFF1E293B),
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
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Recommendation action card
                if (msg.actionProposal != null && msg.recommendationStatus != null) _buildActionCard(msg, provider),
                const SizedBox(height: 3),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    msg.time,
                    style: TextStyle(fontSize: 11, color: msg.isUser ? Colors.white60 : const Color(0xFF94A3B8)),
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
    final isTerminal =
        status == 'EXPIRED' ||
        status == 'SUPERSEDED' ||
        status == 'IGNORED' ||
        status == 'LOWCONFIDENCE' ||
        status == 'INSUFFICIENTDATA' ||
        status == 'PROVIDERUNAVAILABLE' ||
        status == 'INVALIDPROVIDEROUTPUT';
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
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            if (!isApplied && !isRejected && !isTerminal)
              () {
                final canControl = provider.canControlZone(provider.currentZone.zoneId);
                if (canControl) {
                  return SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isLoading ? null : () => _applyRecommendation(provider, msg),
                      child: isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Áp dụng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
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
          decoration: BoxDecoration(color: const Color(0xFF062326), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.smart_toy, color: Color(0xFF10B981), size: 15),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
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
      builder: (_, val, child) => Opacity(opacity: val, child: child),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: const Color(0xFF10B981), shape: BoxShape.circle),
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
                    hintText: 'Hỏi về độ ẩm, bệnh lá, lịch tưới VietGAP...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (v) => _sendMessage(provider, v),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF10B981),
                radius: 22,
                child: IconButton(
                  tooltip: 'Gửi',
                  icon: const Icon(Icons.send, color: Colors.white, size: 17),
                  onPressed: () => _sendMessage(provider, _controller.text),
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
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
