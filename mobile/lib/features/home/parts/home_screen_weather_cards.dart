part of '../home_screen.dart';

extension _HomeScreenWeatherCards on HomeScreen {
  // Outdoor Local Weather Card
  Widget _buildOutdoorWeatherCard(FarmProvider farmProvider) {
    final farm = farmProvider.currentFarm;
    final weather = farmProvider.farmWeather;
    final isLoading = farmProvider.isLoadingWeather;

    final locationName = farm.province.isNotEmpty
        ? (farm.district.isNotEmpty ? '${farm.district}, ${farm.province}' : farm.province)
        : (farm.name.isNotEmpty ? farm.name : 'Vị trí trang trại');

    final hasWeatherData = weather != null && weather['temperature'] != null;
    final outdoorTemp = hasWeatherData
        ? '${(weather['temperature'] as num).toStringAsFixed(1)}°C'
        : (isLoading ? '--°C' : 'Chưa có DL');

    final weatherCondition = hasWeatherData
        ? (weather['weatherDescription']?.toString() ?? 'Khí hậu địa phương')
        : (isLoading ? 'Đang cập nhật thời tiết...' : 'Thời tiết không khả dụng');

    final rainProb = hasWeatherData && weather['precipitationProbability'] != null
        ? '${(weather['precipitationProbability'] as num).toInt()}%'
        : '--';

    final outdoorHumidity = hasWeatherData && weather['humidity'] != null
        ? '${(weather['humidity'] as num).toInt()}%'
        : '--';

    final windSpeed = hasWeatherData && weather['windSpeed'] != null
        ? '${(weather['windSpeed'] as num).toStringAsFixed(1)} km/h'
        : '--';

    final uvIndex = hasWeatherData
        ? 'Dữ liệu trạm Open-Meteo theo vị trí hiệu lực'
        : 'Chưa có dữ liệu thời tiết thực tế cho tọa độ này';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F766E).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Location & Weather Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_cloudy_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'THỜI TIẾT NGOÀI TRỜI (TRẠM ĐỊA PHƯƠNG)',
                            style: TextStyle(
                              color: Color(0xFF99F6E4),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                          child: const Text(
                            'Live',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      locationName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Big Temp
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      outdoorTemp,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weatherCondition,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.water_drop_outlined, 'Mưa', rainProb))),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.opacity, 'Độ ẩm', outdoorHumidity))),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(child: Center(child: _buildWeatherMiniItem(Icons.air, 'Gió', windSpeed))),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(
                  child: Center(
                    child: _buildWeatherMiniItem(Icons.wb_sunny_outlined, 'Trạm', hasWeatherData ? 'OpenMeteo' : '--'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 11, color: Color(0xFF99F6E4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  uvIndex,
                  style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherMiniItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF99F6E4), size: 12),
        const SizedBox(width: 3),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Visual Temperature Safe-Zone Range Card
  Widget _buildTemperatureRangeCard(BuildContext context, dynamic zone) {
    if (!zone.telemetryIsFresh || !zone.cropContextIsDbBacked) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          !zone.telemetryIsFresh
              ? 'Chưa có telemetry nhiệt độ mới từ DB để đánh giá vùng an toàn.'
              : 'Chưa có ngưỡng nhiệt độ theo mùa vụ từ DB để đánh giá vùng an toàn.',
          style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
        ),
      );
    }
    final double currentT = (zone.currentTemp as num).toDouble();
    const double minSafe = 18.0;
    const double maxSafe = 28.0;
    const double scaleMin = 10.0;
    const double scaleMax = 40.0;

    final isOptimal = currentT >= minSafe && currentT <= maxSafe;
    final isTooHot = currentT > maxSafe;

    // Calculate clamped fraction for marker on scale [10, 40]
    final double markerPercent = ((currentT - scaleMin) / (scaleMax - scaleMin)).clamp(0.05, 0.95);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOptimal ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
          width: isOptimal ? 1 : 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isOptimal
                            ? const Color(0xFFECFDF5)
                            : (isTooHot ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune,
                        size: 14,
                        color: isOptimal
                            ? const Color(0xFF059669)
                            : (isTooHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'DẢI NHIỆT ĐỘ AN TOÀN VIETGAP',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showThresholdSettingsModal(context, zone),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOptimal
                        ? const Color(0xFFECFDF5)
                        : (isTooHot ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOptimal
                          ? const Color(0xFF10B981)
                          : (isTooHot ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOptimal ? '✓ Chuẩn' : (isTooHot ? '⚠️ > 28°C' : '⚠️ < 18°C'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isOptimal
                              ? const Color(0xFF059669)
                              : (isTooHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_note,
                        size: 13,
                        color: isOptimal ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Visual Gauge Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Safe zone is from (18 - 10) / (40 - 10) = 8/30 ≈ 26.7% to (28 - 10) / (40 - 10) = 18/30 = 60%
              const leftPercent = (minSafe - scaleMin) / (scaleMax - scaleMin);
              const rightPercent = (maxSafe - scaleMin) / (scaleMax - scaleMin);

              return Column(
                children: [
                  // Range Track
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Full track
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Danger low zone
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: width * leftPercent,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFBFDBFE),
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                          ),
                        ),
                      ),
                      // Optimal Safe Zone (VietGAP)
                      Positioned(
                        left: width * leftPercent,
                        top: 0,
                        bottom: 0,
                        width: width * (rightPercent - leftPercent),
                        child: Container(
                          decoration: const BoxDecoration(color: Color(0xFF86EFAC)),
                          child: const Center(
                            child: Text(
                              'DẢI TỐI ƯU',
                              style: TextStyle(
                                fontSize: 7.5,
                                color: Color(0xFF14532D),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Danger high zone
                      Positioned(
                        left: width * rightPercent,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFFECACA),
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                          ),
                        ),
                      ),
                      // Current Value Indicator Pin
                      Positioned(
                        left: (width * markerPercent) - 6,
                        top: -3,
                        child: Container(
                          width: 12,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          '10°C (Lạnh)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                        ),
                        child: const Text(
                          'Chuẩn: 18°C - 28°C',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ),
                      const Flexible(
                        child: Text(
                          '40°C (Nóng)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),
          // Explanation line & Quick action
          InkWell(
            onTap: () => _showThresholdSettingsModal(context, zone),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 13, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hiện tại: $currentT°C • Quạt bật khi > 28°C • Bấm để chỉnh ngưỡng',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 14, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
