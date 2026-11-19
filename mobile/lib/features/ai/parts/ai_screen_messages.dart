part of '../ai_screen.dart';

extension _AiAssistantScreenStateMessages on _AiAssistantScreenState {
  Widget _botAvatar({bool pulse = false}) => Container(
    width: 32,
    height: 32,
    decoration: const BoxDecoration(color: _kAiGreen, shape: BoxShape.circle),
    child: Icon(
      Icons.smart_toy,
      color: Colors.white.withValues(alpha: pulse ? 0.7 : 1),
      size: 18,
    ),
  );

  Widget _buildMessage(ChatMessageModel msg, FarmProvider provider) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: msg.isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!msg.isUser) ...[_botAvatar(), const SizedBox(width: 8)],
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width * 0.88),
            child: Container(
              padding: msg.isUser
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                  : const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: msg.isUser ? _kAiGreen : Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: msg.isUser ? const Radius.circular(4) : null,
                  bottomLeft: !msg.isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: msg.isUser
                      ? Colors.transparent
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanTechnicalIds(msg.text),
                    style: TextStyle(
                      fontSize: 14,
                      color: msg.isUser
                          ? Colors.white
                          : const Color(0xFF1E293B),
                      height: 1.45,
                    ),
                  ),
                  if (msg.recommendation != null)
                    _recCard(provider, msg.recommendation!),
                  if (!msg.isUser &&
                      msg.sources != null &&
                      msg.sources!.isNotEmpty)
                    _RagSourcesAccordion(sources: msg.sources!),
                  if (!msg.isUser && msg.contextSnapshotJson != null)
                    _AiPayloadLog(snapshotJson: msg.contextSnapshotJson!),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      msg.time,
                      style: TextStyle(
                        fontSize: 12,
                        color: msg.isUser
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Khối trạng thái thay cho nút duyệt khi khuyến nghị đã được quyết định, hết hạn hoặc không còn hiệu lực.
  Widget? _decisionStatus(AiRecCard rec) {
    Widget chip(IconData icon, String text, Color bg, Color fg, Color border) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        );

    if (rec.status == 'ACCEPTED') {
      final c = rec.commandStatus;
      // Chưa biết trạng thái lệnh (vd. khôi phục từ lịch sử) thì nói thật, không khẳng định thiết bị đã chạy.
      final label = c == null
          ? 'Đã duyệt; chưa tải trạng thái lệnh'
          : (aiCommandLabels[c] ?? c);
      return switch (c) {
        'Failed' || 'Cancelled' || 'TimedOut' => chip(
          Icons.cancel_outlined,
          label,
          const Color(0xFFFFF1F2),
          const Color(0xFFBE123C),
          const Color(0xFFFECDD3),
        ),
        'Pending' => chip(
          Icons.schedule,
          label,
          const Color(0xFFFFFBEB),
          const Color(0xFFB45309),
          const Color(0xFFFDE68A),
        ),
        'Sent' => chip(
          Icons.sync,
          label,
          const Color(0xFFF0F9FF),
          const Color(0xFF0369A1),
          const Color(0xFFBAE6FD),
        ),
        'Acknowledged' => chip(
          Icons.check_circle_outline,
          label,
          const Color(0xFFD1FAE5),
          const Color(0xFF065F46),
          const Color(0xFF6EE7B7),
        ),
        _ => chip(
          Icons.check_circle_outline,
          label,
          const Color(0xFFF1F5F9),
          const Color(0xFF475569),
          const Color(0xFFE2E8F0),
        ),
      };
    }
    if (rec.status == 'REJECTED') {
      return chip(
        Icons.cancel_outlined,
        'Đã từ chối khuyến nghị',
        const Color(0xFFFFF1F2),
        const Color(0xFFBE123C),
        const Color(0xFFFECDD3),
      );
    }
    if (rec.isExpired || rec.status == 'EXPIRED') {
      return chip(
        Icons.schedule,
        'Khuyến nghị đã hết hạn (15p)',
        const Color(0xFFF1F5F9),
        const Color(0xFF64748B),
        const Color(0xFFE2E8F0),
      );
    }
    if (rec.status != 'READY') {
      return chip(
        Icons.info_outline,
        'Khuyến nghị không còn hiệu lực',
        const Color(0xFFF1F5F9),
        const Color(0xFF64748B),
        const Color(0xFFE2E8F0),
      );
    }
    return null;
  }

  /// Nút Bỏ qua / Duyệt; Owner có quyền điều khiển Zone mới thấy, người khác thấy lý do bị khóa.
  Widget _decisionButtons(FarmProvider provider, AiRecCard rec) {
    final status = _decisionStatus(rec);
    if (status != null) return status;
    if (!provider.canControlZone(provider.currentZone.zoneId)) {
      return const Text(
        'Cần quyền Điều Khiển Thiết Bị để duyệt khuyến nghị này.',
        style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: rec.busy ? null : () => _reject(provider, rec),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF475569),
          ),
          icon: const Icon(Icons.cancel_outlined, size: 14),
          label: const Text('Bỏ qua', style: TextStyle(fontSize: 12)),
        ),
        FilledButton.icon(
          onPressed: rec.busy ? null : () => _approve(provider, rec),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
          ),
          icon: rec.busy
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 14),
          label: Text(
            rec.busy ? 'Đang gửi...' : rec.approveLabel,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Thẻ "Đề xuất giải pháp" nằm trong tin nhắn AI.
  Widget _recCard(FarmProvider provider, AiRecCard rec) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ĐỀ XUẤT GIẢI PHÁP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      rec.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '${rec.confidence}% Tin cậy',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF065F46),
                  ),
                ),
              ),
            ],
          ),
          if (rec.proposedAction != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6EE7B7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.memory, size: 16, color: Color(0xFF047857)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HÀNH ĐỘNG ĐỀ XUẤT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        Text(
                          rec.actionLabel,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        rec.durationSeconds != null
                            ? '⏱️ ${rec.minutes} phút (${rec.durationSeconds}s)'
                            : '⏱️ Theo chu kỳ',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (rec.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: Text(
                rec.text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
          if (rec.reasoning.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 12,
                        color: Color(0xFF047857),
                      ),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Căn cứ kỹ thuật & Lưu ý:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rec.reasoning,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Xác nhận để kích hoạt thiết bị',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          _decisionButtons(provider, rec),
        ],
      ),
    );
  }

  /// Thẻ gọn trong hàng đợi duyệt.
  Widget _queueCard(FarmProvider provider, AiRecCard rec) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    rec.type.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${rec.confidence}% Tin cậy',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            rec.title,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          ),
          if (rec.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                rec.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          if (rec.reasoning.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Căn cứ: ${rec.reasoning}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ),
          const SizedBox(height: 8),
          _decisionButtons(provider, rec),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _botAvatar(pulse: true),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                16,
              ).copyWith(bottomLeft: const Radius.circular(4)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'AI đang đối chiếu dữ liệu cảm biến & quy chuẩn VietGAP...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar(FarmProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isTyping,
                    style: const TextStyle(fontSize: 14),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Hỏi AI về vi khí hậu, nước tưới, sâu bệnh...',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                          color: _kAiGreen,
                          width: 1.5,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                    ),
                    onSubmitted: (v) => _sendMessage(provider, v),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  width: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kAiGreen,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _isTyping
                        ? null
                        : () => _sendMessage(provider, _controller.text),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.lock_outline,
                    size: 11,
                    color: Color(0xFF047857),
                  ),
                ),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Bảo mật dữ liệu: AI chỉ xử lý thông số kỹ thuật Zone & thời tiết vùng. Vui lòng không gửi số điện thoại, thông tin liên hệ hoặc hợp đồng.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
