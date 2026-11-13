part of '../schedules_automation_screen.dart';

extension _SchedulesAutomationScreenStateCreateSchedule
    on _SchedulesAutomationScreenState {
  void _showCreateScheduleDialog(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    String selectedZone = provider.zones.isNotEmpty
        ? provider.zones.first.name
        : 'Nhà màng 01';
    String selectedActuator = 'Bơm Tưới Nhỏ Giọt';
    String name = 'Lịch tưới định kỳ hàng ngày';
    String startTime = '06:00';
    int duration = 15;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Tạo Lịch Tưới Định Kỳ (Cron)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(
                  labelText: 'Tên lịch',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: startTime,
                      decoration: const InputDecoration(
                        labelText: 'Giờ bắt đầu (HH:mm)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => startTime = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: duration.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Thời lượng (phút)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        final p = int.tryParse(v);
                        if (p != null) duration = p;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062326),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final zone = provider.zones
                    .where((z) => z.name == selectedZone)
                    .firstOrNull;
                final wanted = selectedActuator.contains('Quạt')
                    ? 'FAN'
                    : selectedActuator.contains('Đèn')
                    ? 'GROW_LIGHT'
                    : selectedActuator.contains('Van')
                    ? 'VALVE'
                    : 'PUMP';
                final actuator = provider.actuators
                    .where(
                      (a) =>
                          a.zoneId == zone?.zoneId && a.actuatorType == wanted,
                    )
                    .firstOrNull;
                if (zone == null || actuator == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Zone này chưa có thiết bị chấp hành phù hợp.',
                      ),
                    ),
                  );
                  return;
                }
                if (name.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên lịch.')),
                  );
                  return;
                }
                try {
                  await AutomationApi.createSchedule(
                    zoneId: zone.zoneId,
                    actuatorId: actuator.actuatorId,
                    name: name.trim(),
                    startTime: startTime.trim(),
                    durationMinutes: duration,
                  );
                  await provider.fetchSchedules(zoneId: zone.zoneId);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✅ Đã tạo lịch tưới trên máy chủ.'),
                    backgroundColor: Color(0xFF062326),
                  ),
                );
              },
              child: const Text('Lưu Lịch'),
            ),
          ],
        );
      },
    );
  }
}
