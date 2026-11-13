part of '../farmer_dashboard_screen.dart';

extension _FarmerDashboardScreenStateControl on _FarmerDashboardScreenState {
  // ─── TAB 2A: PUMP CONTROL (CAN_CONTROL_PUMP) ───────────────────────────────
  Widget _buildControlTab(
    BuildContext context,
    FarmProvider provider,
    List<ZoneModel> zones,
  ) {
    final actuators = provider.actuators;
    // Lọc actuator theo zones được phân công
    final assignedActuators = actuators
        .where(
          (a) => zones.any(
            (z) => z.zoneId.toLowerCase() == a.zoneId.toLowerCase(),
          ),
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chỉ điều khiển thiết bị trong khu vực được phân công. Mọi hành động đều được ghi lại.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),

          const Text(
            'ĐIỀU KHIỂN MÁY BƠM & THIẾT BỊ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          if (assignedActuators.isNotEmpty) ...[
            const EmergencyStopButton(),
            const SizedBox(height: 12),
          ],

          if (assignedActuators.isEmpty)
            _buildEmptyState(
              'Không có thiết bị nào trong khu vực của bạn',
              Icons.device_unknown,
            )
          else
            ...assignedActuators.map((actuator) {
              final zone = zones.firstWhere(
                (z) => z.zoneId.toLowerCase() == actuator.zoneId.toLowerCase(),
                orElse: () => zones.first,
              );
              return _buildActuatorControlCard(
                context,
                actuator,
                zone,
                provider,
              );
            }),

          const SizedBox(height: 20),
          // Quick Actions
          const Text(
            'TƯỚI NHANH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _quickWaterButton(context, '10 phút', 10, provider, zones),
              const SizedBox(width: 8),
              _quickWaterButton(context, '20 phút', 20, provider, zones),
              const SizedBox(width: 8),
              _quickWaterButton(context, '30 phút', 30, provider, zones),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorControlCard(
    BuildContext context,
    ActuatorModel actuator,
    ZoneModel zone,
    FarmProvider provider,
  ) {
    final isRunning = actuator.isRunning;
    final color = isRunning ? const Color(0xFF059669) : const Color(0xFF64748B);
    final bgColor = isRunning
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFF8FAFC);

    String typeIcon = '💧';
    if (actuator.actuatorType == 'FAN') typeIcon = '🌬️';
    if (actuator.actuatorType == 'GROW_LIGHT') typeIcon = '💡';
    if (actuator.actuatorType == 'VALVE') typeIcon = '🔧';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRunning ? const Color(0xFF6EE7B7) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isRunning
                ? const Color(0xFF059669).withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(typeIcon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actuator.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  zone.name.split(' - ').first,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (isRunning)
                  Text(
                    '⏱ Còn ${actuator.remainingMinutes} phút',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: isRunning,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (_) => toggleActuatorWithFeedback(
              context,
              provider,
              actuator.actuatorId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickWaterButton(
    BuildContext context,
    String label,
    int minutes,
    FarmProvider provider,
    List<ZoneModel> zones,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          // Bật các bơm đang tắt trong Zone được phân công trong N phút; chỉ báo thành công khi backend xác nhận.
          final messenger = ScaffoldMessenger.of(context);
          var ok = 0;
          var failed = 0;
          String? firstError;
          for (final zone in zones) {
            if (!provider.canControlZone(zone.zoneId)) continue;
            final pumps = provider.actuators
                .where(
                  (a) =>
                      a.zoneId == zone.zoneId &&
                      a.actuatorType == 'PUMP' &&
                      !a.isRunning,
                )
                .toList();
            for (final a in pumps) {
              final error = await provider.toggleActuator(
                a.actuatorId,
                durationMinutes: minutes,
              );
              if (error == null) {
                ok++;
              } else {
                failed++;
                firstError ??= error;
              }
            }
          }
          final String message;
          if (ok == 0 && failed == 0) {
            message =
                'Không có bơm nào cần bật hoặc bạn chưa có quyền điều khiển.';
          } else if (failed == 0) {
            message = '✅ Đã bật tưới $label cho $ok bơm';
          } else {
            message = 'Bật được $ok bơm, thất bại $failed: $firstError';
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: failed == 0 && ok > 0
                  ? const Color(0xFF059669)
                  : const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF065F46),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('💧', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── TAB 2B: SCHEDULE VIEW (khi không có CAN_CONTROL_PUMP) ─────────────────
  Widget _buildScheduleViewTab(BuildContext context, FarmProvider provider) {
    final schedules = provider.schedules;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF93C5FD)),
            ),
            child: const Row(
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bạn không có quyền điều khiển thiết bị. Chỉ xem được lịch tưới.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'LỊCH TƯỚI HÔM NAY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...schedules.map((s) => _scheduleReadOnlyCard(s)),
        ],
      ),
    );
  }

  Widget _scheduleReadOnlyCard(ScheduleModel schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('🕐', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${schedule.zoneName} • ${schedule.startTime} • ${schedule.durationMinutes} phút',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  schedule.daysOfWeek.join(', '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: schedule.isActive
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              schedule.isActive ? 'Đang kích hoạt' : 'Tắt',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: schedule.isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
