part of '../home_screen.dart';

extension _HomeScreenClimateControl on HomeScreen {
  List<Widget> _climateSection(BuildContext context, FarmProvider farmProvider, ZoneModel zone) {
    return [
      // Outdoor Local Weather Card
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildOutdoorWeatherCard(farmProvider)),

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                const Text(
                  '10s/lần',
                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),

      // Temperature Safe Range Visual Card
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildTemperatureRangeCard(context, zone)),

      const SizedBox(height: 12),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.20,
          children: [
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'SoilMoisture',
              title: 'Độ ẩm đất (Soil)',
              value: zone.telemetryIsFresh ? '${zone.currentSoilMoisture}%' : '—',
              target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
              icon: Icons.water_drop,
              iconColor: const Color(0xFF0284C7),
              bgColor: const Color(0xFFF0F9FF),
              isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : zone.currentSoilMoisture < 60,
              unit: '%',
            ),
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'Temperature',
              title: 'Nhiệt độ không khí',
              value: zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—',
              target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
              icon: Icons.thermostat,
              iconColor: const Color(0xFFEA580C),
              bgColor: const Color(0xFFFFF7ED),
              isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked
                  ? null
                  : zone.currentTemp > 28 || zone.currentTemp < 18,
              unit: '°C',
            ),
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'AirHumidity',
              title: 'Độ ẩm không khí',
              value: zone.telemetryIsFresh ? '${zone.currentHumidity}%' : '—',
              target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
              icon: Icons.cloud,
              iconColor: const Color(0xFF059669),
              bgColor: const Color(0xFFF0FDF4),
              isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : false,
              unit: '%',
            ),
            _buildSensorCard(
              context: context,
              zoneId: zone.zoneId,
              parameterCode: 'LightIntensity',
              title: 'Ánh sáng (Lux)',
              value: zone.telemetryIsFresh ? '${zone.currentLux.toInt()} lx' : '—',
              target: zone.cropContextIsDbBacked ? 'Ngưỡng theo mùa vụ DB' : 'Ngưỡng chưa đồng bộ từ DB',
              icon: Icons.wb_sunny,
              iconColor: const Color(0xFFCA8A04),
              bgColor: const Color(0xFFFEFCE8),
              isWarning: !zone.telemetryIsFresh || !zone.cropContextIsDbBacked ? null : false,
              unit: 'lx',
            ),
          ],
        ),
      ),

      const SizedBox(height: 24),
    ];
  }

  List<Widget> _quickControlSection(BuildContext context, FarmProvider farmProvider, ZoneModel zone) {
    return [
      // Quick Control Section (CF3)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'ĐIỀU KHIỂN RƠ-LE BƠM/QUẠT',
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: farmProvider.currentZoneActuators.isNotEmpty ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${farmProvider.currentZoneActuators.length} thiết bị',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: farmProvider.currentZoneActuators.isNotEmpty
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),

      if (farmProvider.actuators.isNotEmpty && farmProvider.canEmergencyStop)
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 10), child: EmergencyStopButton()),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: farmProvider.currentZoneActuators.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
                      child: const Icon(Icons.devices_other, size: 28, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Khu vực "${farmProvider.currentZone.name}" chưa có thiết bị rơ-le',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Không có thiết bị bơm/van/quạt nào được gán cho khu vực này trong cơ sở dữ liệu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: farmProvider.currentZoneActuators.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final act = farmProvider.currentZoneActuators[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: act.isRunning ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                        width: act.isRunning ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: act.isRunning ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            act.actuatorType == 'PUMP'
                                ? Icons.water
                                : act.actuatorType == 'FAN'
                                ? Icons.wind_power
                                : act.actuatorType == 'VALVE'
                                ? Icons.tune
                                : Icons.lightbulb,
                            color: act.isRunning ? const Color(0xFF059669) : const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act.isRunning ? 'Đang bật (${act.remainingMinutes} phút còn lại)' : 'Đang tắt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: act.isRunning ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                  fontWeight: act.isRunning ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: act.isRunning,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (_) {
                            if (!farmProvider.canControlZone(act.zoneId)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Bạn chưa được cấp quyền điều khiển thiết bị tại khu vực này!'),
                                  backgroundColor: Color(0xFFE11D48),
                                ),
                              );
                              return;
                            }
                            toggleActuatorWithFeedback(context, farmProvider, act.actuatorId);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),

      const SizedBox(height: 24),
    ];
  }
}
