part of '../crop_profiles_screen.dart';

class _CropProfileCard extends StatelessWidget {
  final DefaultCropProfile profile;
  final VoidCallback onTap;

  const _CropProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstStage = profile.growthStages.first;
    final lastStage = profile.growthStages.last;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hàng 1: Icon lớn, Tên giống & Badge Chu kỳ ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Center(
                        child: Text(
                          profile.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF064E3B),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF064E3B,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.timelapse,
                                      size: 11,
                                      color: Color(0xFF6EE7B7),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${profile.totalCycleDays} ngày',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profile.nameEn} • Giống: ${profile.variety.split(' / ').first}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (profile.isApplied)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ĐANG TRỒNG',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 12,
                                      color: Color(0xFF047857),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tiêu chuẩn VietGAP',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (profile.difficulty.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: profile.difficulty == 'DỄ'
                                        ? const Color(0xFFECFDF5)
                                        : profile.difficulty == 'KHÓ'
                                        ? const Color(0xFFFEF2F2)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: profile.difficulty == 'DỄ'
                                          ? const Color(0xFFA7F3D0)
                                          : profile.difficulty == 'KHÓ'
                                          ? const Color(0xFFFECACA)
                                          : const Color(0xFFFDE68A),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    profile.difficulty,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: profile.difficulty == 'DỄ'
                                          ? const Color(0xFF047857)
                                          : profile.difficulty == 'KHÓ'
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFD97706),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${profile.growthStages.length} giai đoạn',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Text(
                  profile.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 14),

                // ── Hàng 2: Khối thông số vi khí hậu trực quan ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Độ ẩm đất
                      Expanded(
                        child: _metricColumn(
                          icon: Icons.water_drop,
                          iconColor: const Color(0xFF0284C7),
                          label: 'Độ ẩm đất',
                          value: firstStage.requirements.soilMoistureMax <= 0
                              ? '—'
                              : '${firstStage.requirements.soilMoistureMin.toInt()}%–${firstStage.requirements.soilMoistureMax.toInt()}%',
                          caption: firstStage.requirements.soilMoistureMax <= 0
                              ? 'Chưa có ngưỡng'
                              : 'Ngưỡng an toàn',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // Nhiệt độ
                      Expanded(
                        child: _metricColumn(
                          icon: Icons.thermostat,
                          iconColor: const Color(0xFFEA580C),
                          label: 'Nhiệt độ',
                          value: firstStage.requirements.tempMax <= 0
                              ? '—'
                              : '${firstStage.requirements.tempMin.toInt()}–${firstStage.requirements.tempMax.toInt()}°C',
                          caption: firstStage.requirements.tempMax <= 0
                              ? 'Chưa có ngưỡng'
                              : 'Tối ưu sinh trưởng',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // Lượng tưới
                      Expanded(
                        child: _metricColumn(
                          icon: Icons.alarm,
                          iconColor: const Color(0xFF047857),
                          label: 'Chế độ tưới',
                          value:
                              firstStage.requirements.irrigationDurationMin > 0
                              ? '${firstStage.requirements.irrigationDurationMin}p / lần'
                              : '—',
                          caption:
                              firstStage
                                      .requirements
                                      .irrigationFrequencyPerDay >
                                  0
                              ? '${firstStage.requirements.irrigationFrequencyPerDay} lần/ngày'
                              : 'xem lịch tưới',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Hàng 3: Timeline chu kỳ tóm tắt (Giai đoạn đầu -> thu hoạch) ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDCFCE7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        firstStage.iconEmoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${firstStage.name} → ${lastStage.name}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String caption,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          caption,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
