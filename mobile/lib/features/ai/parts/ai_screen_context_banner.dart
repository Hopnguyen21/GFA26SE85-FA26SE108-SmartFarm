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
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Text(
                              '🌿 $cropName${growthStage != null ? ' • $growthStage' : ''}${seasonDays != null ? ' (Ngày $seasonDays)' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                        if (profileName != null && profileName.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              '📜 $profileName',
                              style: const TextStyle(
                                fontSize: 11,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
                      fontSize: 11,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '$val $unit',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (reqText != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              reqText,
                              style: const TextStyle(
                                fontSize: 11,
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
                  _buildSensorChip(
                    '🌱 Ẩm đất',
                    zone.telemetryIsFresh
                        ? '${zone.currentSoilMoisture.toStringAsFixed(1)}%'
                        : '—',
                  ),
                  _buildSensorChip(
                    '🌡️ Nhiệt độ',
                    zone.telemetryIsFresh
                        ? '${zone.currentTemp.toStringAsFixed(1)}°C'
                        : '—',
                  ),
                  _buildSensorChip(
                    '💧 Ẩm KK',
                    zone.telemetryIsFresh
                        ? '${zone.currentHumidity.toStringAsFixed(0)}% RH'
                        : '—',
                  ),
                ],

                if (weatherOk)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      '🌤️ Dự báo 6h: ${weather?['rainProbabilityNext6HoursMaxPercent'] ?? 0}% mưa',
                      style: const TextStyle(
                        fontSize: 11,
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
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
        children: _AiAssistantScreenState._quickPrompts
            .map(
              (p) => GestureDetector(
                onTap: () => _sendMessage(provider, p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6EE7B7),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    p,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
