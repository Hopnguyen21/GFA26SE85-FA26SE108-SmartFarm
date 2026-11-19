part of '../home_screen.dart';

extension _HomeScreenClimateControl on HomeScreen {
  List<Widget> _climateSection(
    BuildContext context,
    FarmProvider farmProvider,
    ZoneModel zone,
  ) {
    return [
      // Outdoor Local Weather Card
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildOutdoorWeatherCard(farmProvider),
      ),

      const SizedBox(height: 16),

      // Telemetry Grid Section (CF2)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'VI KHÍ HẬU THỜI GIAN THỰC (CF2)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: zone.telemetryIsFresh
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: zone.telemetryIsFresh
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFCBD5E1),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: zone.telemetryIsFresh
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    zone.telemetryIsFresh ? 'LoRa 10s/lần' : 'Chờ gói tin',
                    style: TextStyle(
                      fontSize: 11,
                      color: zone.telemetryIsFresh
                          ? const Color(0xFF047857)
                          : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),

      // Temperature Safe Range Visual Card
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildTemperatureRangeCard(context, zone),
      ),

      const SizedBox(height: 12),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.14,
          children: [
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'SoilMoisture',
              title: 'Độ ẩm đất (Soil)',
              value: zone.telemetryIsFresh
                  ? '${zone.currentSoilMoisture}%'
                  : '—',
              target: thresholdCaption(zone, 'SoilMoisture', '%'),
              icon: Icons.water_drop,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
              isWarning: outOfRange(
                zone,
                'SoilMoisture',
                zone.currentSoilMoisture.toDouble(),
              ),
              unit: '%',
            ),
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'Temperature',
              title: 'Nhiệt độ không khí',
              value: zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—',
              target: thresholdCaption(zone, 'Temperature', '°C'),
              icon: Icons.thermostat,
              iconColor: const Color(0xFFEA580C),
              bgColor: const Color(0xFFFFF7ED),
              isWarning: outOfRange(
                zone,
                'Temperature',
                zone.currentTemp.toDouble(),
              ),
              unit: '°C',
            ),
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'AirHumidity',
              title: 'Độ ẩm không khí',
              value: zone.telemetryIsFresh ? '${zone.currentHumidity}%' : '—',
              target: thresholdCaption(zone, 'AirHumidity', '%'),
              icon: Icons.cloud,
              iconColor: const Color(0xFF047857),
              bgColor: const Color(0xFFF0FDF4),
              isWarning: outOfRange(
                zone,
                'AirHumidity',
                zone.currentHumidity.toDouble(),
              ),
              unit: '%',
            ),
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'LightIntensity',
              title: 'Ánh sáng (Lux)',
              value: zone.telemetryIsFresh
                  ? '${zone.currentLux.toInt()} lx'
                  : '—',
              target: thresholdCaption(zone, 'LightIntensity', 'lx'),
              icon: Icons.wb_sunny,
              iconColor: const Color(0xFFCA8A04),
              bgColor: const Color(0xFFFEFCE8),
              isWarning: outOfRange(
                zone,
                'LightIntensity',
                zone.currentLux.toDouble(),
              ),
              unit: 'lx',
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),
    ];
  }

  /// Lịch tưới của cây trong Zone đang chọn: một thẻ gọn mở lịch tưới theo vụ (điều khiển từng rơ-le nằm trong màn Zone).
  List<Widget> _quickControlSection(
    BuildContext context,
    FarmProvider farmProvider,
    ZoneModel zone,
  ) {
    final crop = zone.currentCrop.trim();
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'LỊCH TƯỚI CỦA CÂY',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (farmProvider.actuators.isNotEmpty && farmProvider.canEmergencyStop)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: EmergencyStopButton(),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('home_irrigation_calendar'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeasonIrrigationCalendarScreen(zone: zone),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month,
                      size: 22,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          crop.isEmpty
                              ? 'Lịch tưới · ${zone.name}'
                              : 'Lịch tưới · $crop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          '${zone.name} · xem và chỉnh ca tưới theo giai đoạn',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ];
  }
}
