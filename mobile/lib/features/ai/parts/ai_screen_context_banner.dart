part of '../ai_screen.dart';

extension _AiAssistantScreenStateContextBanner on _AiAssistantScreenState {
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
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAiGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
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

  /// Dòng đầu: bối cảnh AI (Zone, cây, giai đoạn, ngày) + nút bật/tắt chi tiết cảm biến; chi tiết chỉ mở khi bấm (như web).
  Widget _buildContextBanner(ZoneModel zone) {
    final ctx = _aiContext;
    final cropName = ctx?['cropName']?.toString();
    final stage = ctx?['growthStageName']?.toString();
    final days = ctx?['seasonAgeDays'] ?? ctx?['daysSinceStart'];
    final telemetry = (ctx?['telemetry'] as List<dynamic>?) ?? const [];
    final requirements = (ctx?['requirements'] as List<dynamic>?) ?? const [];
    final weather = ctx?['weather'] as Map<String, dynamic>?;
    final weatherOk = weather?['available'] == true;
    final nodes = (ctx?['deviceNodes'] as List<dynamic>?)
        ?.where((n) => n is Map && n['deviceType'] == 'SensorNode')
        .length;
    final zoneName = ctx?['zoneName']?.toString();
    final title =
        zoneName ??
        (_isLoadingContext ? 'Đang tải bối cảnh Zone...' : zone.name);
    final summary = _isLoadingContext
        ? 'Đang cập nhật...'
        : (ctx != null
              ? '${(nodes == null || nodes == 0) ? 1 : nodes} trạm đo · ${telemetry.length} thông số vi khí hậu${weatherOk ? ' · 🌤️ Thời tiết' : ''}'
              : 'Chưa tải được dữ liệu');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: ctx != null
                      ? const Color(0xFF10B981)
                      : const Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: 'Bối cảnh AI: ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                        children: [
                          TextSpan(
                            text: title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (cropName != null && cropName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                        ),
                        child: Text(
                          '🌿 $cropName${stage != null && stage.isNotEmpty ? ' • $stage' : ''}${days != null ? ' (Ngày $days)' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF064E3B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _rebuild(() => _showSensors = !_showSensors),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: _showSensors ? _kAiGreen : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showSensors
                      ? const Color(0xFF047857)
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width - 64,
                      ),
                      child: Text(
                        summary,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _showSensors
                              ? Colors.white
                              : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showSensors ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: _showSensors
                        ? Colors.white
                        : const Color(0xFF047857),
                  ),
                ],
              ),
            ),
          ),
          if (_showSensors && (telemetry.isNotEmpty || weatherOk)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _sortedTelemetry(telemetry))
                  _sensorChip(t, requirements),
                if (weatherOk) ...[
                  if (weather?['temperatureCelsius'] != null ||
                      weather?['summary'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wb_sunny_outlined,
                            size: 13,
                            color: Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Ngoài trời: ${weather?['temperatureCelsius'] != null ? '${weather!['temperatureCelsius']}°C' : ''}${weather?['summary'] != null ? ' · ${weather!['summary']}' : ''}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (weather?['rainProbabilityNext6HoursMaxPercent'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            ((weather!['rainProbabilityNext6HoursMaxPercent']
                                        as num?) ??
                                    0) >=
                                70
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              ((weather['rainProbabilityNext6HoursMaxPercent']
                                          as num?) ??
                                      0) >=
                                  70
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFBBF7D0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ((weather['rainProbabilityNext6HoursMaxPercent']
                                            as num?) ??
                                        0) >=
                                    70
                                ? Icons.thunderstorm_outlined
                                : Icons.water_drop_outlined,
                            size: 13,
                            color:
                                ((weather['rainProbabilityNext6HoursMaxPercent']
                                            as num?) ??
                                        0) >=
                                    70
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Dự báo 6h: ${weather['rainProbabilityNext6HoursMaxPercent']}% mưa${((weather['rainProbabilityNext6HoursMaxPercent'] as num?) ?? 0) >= 70 ? ' (Hoãn tưới BR-01)' : ''}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    ((weather['rainProbabilityNext6HoursMaxPercent']
                                                as num?) ??
                                            0) >=
                                        70
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<dynamic> _sortedTelemetry(List<dynamic> list) {
    const order = [
      'temperature',
      'soilmoisture',
      'airhumidity',
      'light',
      'lightintensity',
      'ph',
      'ec',
    ];
    int rank(dynamic t) {
      final i = order.indexOf(
        (t['parameterCode'] ?? '').toString().toLowerCase(),
      );
      return i == -1 ? 99 : i;
    }

    return [...list]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  Widget _sensorChip(dynamic t, List<dynamic> requirements) {
    final code = t['parameterCode']?.toString() ?? '';
    final req = requirements
        .where((r) => r['parameterCode']?.toString() == code)
        .firstOrNull;
    String fmt(dynamic v) {
      final n = v is num ? v : num.tryParse('$v');
      if (n == null) return '$v';
      return n == n.roundToDouble() ? '${n.round()}' : '$n';
    }

    final label = switch (code) {
      'Temperature' => '🌡️ Nhiệt độ',
      'SoilMoisture' => '🌱 Ẩm đất',
      'AirHumidity' => '💧 Ẩm KK',
      'Light' || 'LightIntensity' => '☀️ Ánh sáng',
      'Ph' || 'SoilPh' => '🧪 Độ pH',
      'Ec' || 'SoilEc' => '⚡ Dinh dưỡng EC',
      _ => code,
    };
    final minV = req?['minValue'];
    final maxV = req?['maxValue'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text.rich(
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          children: [
            TextSpan(
              text: '${fmt(t['value'])} ${t['unit'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            if (minV != null && maxV != null)
              TextSpan(
                text: '  (chuẩn: ${fmt(minV)}-${fmt(maxV)})',
                style: const TextStyle(
                  color: Color(0xFF047857),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Hàng đợi duyệt khuyến nghị (cột phải trên web): thanh tóm tắt, bấm để mở danh sách thẻ.
  Widget _buildQueueStrip(FarmProvider provider, List<AiRecCard> queue) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _rebuild(() => _showQueue = !_showQueue),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFF047857),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Hàng đợi Duyệt Khuyến nghị',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (queue.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${queue.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  Icon(
                    _showQueue ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_showQueue)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: queue.isEmpty
                  ? Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      // min: Column mặc định giãn hết chiều cao tối đa (40% màn hình) nên thẻ rỗng bị kéo cao, chiếm chỗ khung chat.
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: 26,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Chưa có khuyến nghị mới cần duyệt',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          Text(
                            'Các đề xuất tưới tiêu hoặc vi khí hậu từ AI sẽ xuất hiện tại đây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      children: [
                        for (final r in queue) _queueCard(provider, r),
                      ],
                    ),
            ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
        ],
      ),
    );
  }

  /// Hàng "Gợi ý nhanh" luôn hiện phía trên ô nhập, cuộn ngang (như web).
  Widget _buildQuickPrompts(FarmProvider provider) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Gợi ý nhanh:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            for (final (label, question)
                in _AiAssistantScreenState._quickPrompts)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: _isTyping
                      ? null
                      : () => _sendMessage(provider, question),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
