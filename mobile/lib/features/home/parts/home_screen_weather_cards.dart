part of '../home_screen.dart';

/// Xác suất mưa (%) của ngày đầu tiên trong `dailyForecast`; null khi không có.
num? _todayForecastRain(Object? daily) {
  if (daily is! List || daily.isEmpty) return null;
  final first = daily.first;
  return first is Map ? first['precipitationProbability'] as num? : null;
}

extension _HomeScreenWeatherCards on HomeScreen {
  // Outdoor Local Weather Card
  Widget _buildOutdoorWeatherCard(FarmProvider farmProvider) {
    final farm = farmProvider.currentFarm;
    final weather = farmProvider.farmWeather;
    final isLoading = farmProvider.isLoadingWeather;

    final locationName = farm.province.isNotEmpty
        ? (farm.district.isNotEmpty
              ? '${farm.district}, ${farm.province}'
              : farm.province)
        : (farm.name.isNotEmpty ? farm.name : 'Vị trí trang trại');

    final hasWeatherData = weather != null && weather['temperature'] != null;
    final outdoorTemp = hasWeatherData
        ? '${(weather['temperature'] as num).toStringAsFixed(1)}°C'
        : (isLoading ? '--°C' : 'Chưa có DL');

    final weatherCondition = hasWeatherData
        ? (weather['weatherDescription']?.toString() ?? 'Khí hậu địa phương')
        : (isLoading
              ? 'Đang cập nhật thời tiết...'
              : 'Thời tiết không khả dụng');

    // Quan trắc hiện tại có thể không có xác suất mưa: dùng dự báo của hôm nay (cùng nguồn Open-Meteo).
    final rainNum = hasWeatherData
        ? (weather['precipitationProbability'] as num? ??
              _todayForecastRain(weather['dailyForecast']))
        : null;
    final rainProb = rainNum != null ? '${rainNum.toInt()}%' : '--';

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
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                child: const Icon(
                  Icons.wb_cloudy_rounded,
                  color: Colors.white,
                  size: 18,
                ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      locationName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weatherCondition,
                      maxLines: 2,
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCCFBF1),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
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
                Expanded(
                  child: Center(
                    child: _buildWeatherMiniItem(
                      Icons.water_drop_outlined,
                      'Mưa',
                      rainProb,
                    ),
                  ),
                ),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(
                  child: Center(
                    child: _buildWeatherMiniItem(
                      Icons.opacity,
                      'Độ ẩm',
                      outdoorHumidity,
                    ),
                  ),
                ),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(
                  child: Center(
                    child: _buildWeatherMiniItem(Icons.air, 'Gió', windSpeed),
                  ),
                ),
                Container(height: 16, width: 1, color: Colors.white24),
                Expanded(
                  child: Center(
                    child: _buildWeatherMiniItem(
                      Icons.wb_sunny_outlined,
                      'Trạm',
                      hasWeatherData ? 'OpenMeteo' : '--',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 11,
                color: Color(0xFF99F6E4),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  uvIndex,
                  style: const TextStyle(
                    color: Color(0xFF99F6E4),
                    fontSize: 11,
                  ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Vùng nhiệt độ an toàn: ngưỡng lấy từ hồ sơ canh tác ở giai đoạn hiện tại (xem ZoneTemperatureGauge).
  Widget _buildTemperatureRangeCard(BuildContext context, dynamic zone) =>
      ZoneTemperatureGauge(
        key: ValueKey('temp_gauge_${zone.zoneId}'),
        zone: zone as ZoneModel,
        onEditThresholds: () => _showThresholdSettingsModal(context, zone),
      );
}
