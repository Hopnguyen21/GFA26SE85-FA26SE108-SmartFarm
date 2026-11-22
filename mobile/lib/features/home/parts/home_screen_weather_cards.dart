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
    return OutdoorWeatherCard(farmProvider: farmProvider);
  }

  // Vùng nhiệt độ an toàn: ngưỡng lấy từ hồ sơ canh tác ở giai đoạn hiện tại (xem ZoneTemperatureGauge).
  Widget _buildTemperatureRangeCard(BuildContext context, dynamic zone) =>
      ZoneTemperatureGauge(
        key: ValueKey('temp_gauge_${zone.zoneId}'),
        zone: zone as ZoneModel,
        onEditThresholds: () => _showThresholdSettingsModal(context, zone),
      );
}

/// Thẻ hiển thị thời tiết trạm địa phương OpenMeteo theo vị trí hiệu lực Farm/Field/Zone,
/// hỗ trợ hiển thị thời gian thực, cảnh báo rủi ro mưa và mở rộng xem dự báo 7 ngày.
class OutdoorWeatherCard extends StatefulWidget {
  final FarmProvider farmProvider;

  const OutdoorWeatherCard({super.key, required this.farmProvider});

  @override
  State<OutdoorWeatherCard> createState() => _OutdoorWeatherCardState();
}

class _OutdoorWeatherCardState extends State<OutdoorWeatherCard> {
  bool _isForecastExpanded = true;

  @override
  Widget build(BuildContext context) {
    final farmProvider = widget.farmProvider;
    final farm = farmProvider.currentFarm;
    final weather = farmProvider.farmWeather;
    final model = farmProvider.weatherModel;
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

    // Xác suất mưa hôm nay: lấy trực tiếp hoặc từ ngày đầu tiên trong dailyForecast
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

    final weatherIcon = model?.icon ??
        WeatherModel.mapWeatherIcon(weatherCondition);
    final iconColor = model?.iconColor ??
        WeatherModel.mapWeatherColor(weatherCondition);
    final forecastList = model?.dailyForecast ?? const <DailyForecastModel>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rainNum != null && rainNum >= 70
              ? const [Color(0xFF1E293B), Color(0xFF0F766E)]
              : const [Color(0xFF0F766E), Color(0xFF0D9488)],
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
          // ── Header: Trạm địa phương & Nút làm mới ─────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  weatherIcon,
                  color: iconColor,
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
                              fontSize: 10,
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
              const SizedBox(width: 6),
              // Nút làm mới thời tiết
              InkWell(
                key: const Key('btn_refresh_weather'),
                borderRadius: BorderRadius.circular(6),
                onTap: isLoading
                    ? null
                    : () => farmProvider.fetchWeatherForCurrentFarm(),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                ),
              ),
              const SizedBox(width: 4),
              // Nhiệt độ hiện tại & Tình trạng
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

          // ── Khung 4 chỉ số vi khí hậu ngoài trời ───────────────
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

          // ── Cảnh báo rủi ro mưa cao (BR-AUTOMATION-01) ───────────
          if (rainNum != null && rainNum >= 70) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x6667E8F9)),
              ),
              child: Row(
                children: [
                  const Text('🌧️ ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      'Khả năng mưa cao ($rainProb) - Kích hoạt quy tắc tự động hoãn tưới (BR-AUTOMATION-01)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE0F2FE),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Mục Dự báo 7 ngày tới (Collapsible Forecast) ────────
          if (forecastList.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              key: const Key('btn_toggle_weather_forecast'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _isForecastExpanded = !_isForecastExpanded;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 14,
                      color: Color(0xFF99F6E4),
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Dự báo 7 ngày tới',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${forecastList.length} ngày',
                        style: const TextStyle(
                          color: Color(0xFF99F6E4),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isForecastExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            if (_isForecastExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < forecastList.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 10,
                          thickness: 0.6,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      _buildForecastDayRow(forecastList[i]),
                    ],
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 6),

          // ── Thông tin nguồn dữ liệu ───────────────────────────
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
                  hasWeatherData
                      ? 'Dữ liệu trạm Open-Meteo theo vị trí hiệu lực'
                      : 'Chưa có dữ liệu thời tiết thực tế cho tọa độ này',
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

  Widget _buildForecastDayRow(DailyForecastModel day) {
    final rain = day.precipitationProbability != null
        ? '${day.precipitationProbability!.toInt()}%'
        : '--';
    final minT = day.minTemperature != null
        ? '${day.minTemperature!.toStringAsFixed(0)}°'
        : '--';
    final maxT = day.maxTemperature != null
        ? '${day.maxTemperature!.toStringAsFixed(0)}°'
        : '--';
    final isRainRisk = day.hasHighRainRisk;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          // Thứ & Ngày (e.g. "Hôm nay", "Ngày mai", "T2")
          SizedBox(
            width: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.dayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  day.formattedDate,
                  style: const TextStyle(
                    color: Color(0xFF99F6E4),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Icon & Mô tả thời tiết
          Icon(day.icon, size: 14, color: day.iconColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              day.description.isNotEmpty
                  ? day.description
                  : 'Khí hậu địa phương',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Khả năng mưa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: isRainRisk ? const Color(0x3338BDF8) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  size: 10,
                  color: isRainRisk
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF99F6E4),
                ),
                const SizedBox(width: 2),
                Text(
                  rain,
                  style: TextStyle(
                    color: isRainRisk ? const Color(0xFF38BDF8) : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Dải nhiệt độ Min - Max
          SizedBox(
            width: 58,
            child: Text(
              '$minT - $maxT',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
