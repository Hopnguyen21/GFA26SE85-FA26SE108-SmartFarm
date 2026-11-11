part of '../crop_detail_screen.dart';

extension _CropDetailScreenStateStages on _CropDetailScreenState {
  Widget _buildStagesTab(DefaultCropProfile profile, GrowthStageProfile selectedStage) {
    return Column(
      children: [
        // Stage Selector
        Container(
          height: 60,
          color: Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: profile.growthStages.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final stage = profile.growthStages[i];
              final isSelected = i == _selectedStageIndex;
              return InkWell(
                onTap: () => _rebuild(() => _selectedStageIndex = i),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF062326) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(stage.iconEmoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        stage.name.split(' ').first,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stage Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF062326), Color(0xFF0D4A35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(selectedStage.iconEmoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedStage.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  selectedStage.nameEn,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Ngày ${selectedStage.startDayFromPlanting}–${selectedStage.endDayFromPlanting}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        selectedStage.description,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Environmental Requirements - CropRangeBands đồng bộ FE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'DẢI NGƯỠNG VI KHÍ HẬU VIETGAP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Đồng bộ AutoRule',
                              style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Range Bands Trực Quan (Tương đương CropRangeBand trên FE)
                      _buildRangeBand(
                        label: 'Độ ẩm đất (Soil Moisture)',
                        min: selectedStage.requirements.soilMoistureMin,
                        max: selectedStage.requirements.soilMoistureMax,
                        target:
                            (selectedStage.requirements.soilMoistureMin + selectedStage.requirements.soilMoistureMax) /
                            2,
                        current:
                            (selectedStage.requirements.soilMoistureMin + selectedStage.requirements.soilMoistureMax) /
                                2 -
                            2,
                        unit: '%',
                        icon: Icons.water_drop,
                        accentColor: const Color(0xFF0284C7),
                      ),
                      const SizedBox(height: 12),

                      _buildRangeBand(
                        label: 'Nhiệt độ không khí (Air Temp)',
                        min: selectedStage.requirements.tempMin,
                        max: selectedStage.requirements.tempMax,
                        target: (selectedStage.requirements.tempMin + selectedStage.requirements.tempMax) / 2,
                        current: (selectedStage.requirements.tempMin + selectedStage.requirements.tempMax) / 2 + 0.5,
                        unit: '°C',
                        icon: Icons.thermostat,
                        accentColor: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 12),

                      _buildRangeBand(
                        label: 'Độ ẩm không khí (Air Humidity)',
                        min: selectedStage.requirements.humidityMin,
                        max: selectedStage.requirements.humidityMax,
                        target: (selectedStage.requirements.humidityMin + selectedStage.requirements.humidityMax) / 2,
                        current:
                            (selectedStage.requirements.humidityMin + selectedStage.requirements.humidityMax) / 2 + 1,
                        unit: '%',
                        icon: Icons.air,
                        accentColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 14),

                      // Khối Chế độ tưới tự động
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alarm, size: 18, color: Color(0xFF7C3AED)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LỊCH TƯỚI TỰ ĐỘNG KHUYẾN NGHỊ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedStage.requirements.irrigationDurationMin > 0
                                        ? '${selectedStage.requirements.irrigationDurationMin} phút / lần • ${selectedStage.requirements.irrigationFrequencyPerDay} lần mỗi ngày'
                                        : 'Xem lịch tưới của hồ sơ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Text(
                                'Bật Bơm Tự Động',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Key Activities
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CÔNG VIỆC CANH TÁC CHÍNH',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...selectedStage.keyActivities.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeBand({
    required String label,
    required double min,
    required double max,
    required double target,
    required double current,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    final isHealthy = current >= min && current <= max;
    // Calculate percentage position along range
    final span = (max - min) > 0 ? (max - min) : 10.0;
    final extendedMin = min - span * 0.25;
    final extendedMax = max + span * 0.25;
    final totalRange = extendedMax - extendedMin;
    final pct = ((current - extendedMin) / totalRange).clamp(0.05, 0.95);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isHealthy ? 'Tối ưu VietGAP' : 'Lệch ngưỡng',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${current.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isHealthy ? const Color(0xFF065F46) : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Track
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Full background track
                  Container(
                    height: 10,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(5)),
                  ),
                  // Optimal band segment
                  Positioned(
                    left: trackWidth * 0.2,
                    width: trackWidth * 0.6,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        border: Border.symmetric(
                          vertical: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.8), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Current Marker
                  Positioned(
                    left: (trackWidth * pct) - 4,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Min - Target - Max Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MIN: ${min.toInt()} $unit',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
              Text(
                'MỤC TIÊU: ${target.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'MAX: ${max.toInt()} $unit',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
