part of '../irrigation_calendar_screen.dart';

extension _IrrigationCalendarScreenStateDayDetail on _IrrigationCalendarScreenState {
  void _showDayDetailDialog(
    BuildContext context,
    int day,
    GrowthStageProfile stage,
    List<DayIrrigationSession> sessions,
  ) {
    final activeCount = sessions.where((s) => s.enabled).length;
    final totalMinutes = sessions.where((s) => s.enabled).fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalWaterMl = sessions.where((s) => s.enabled).fold<int>(0, (sum, s) => sum + s.volumeMl);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text(stage.iconEmoji.isNotEmpty ? stage.iconEmoji : '🌱', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chi Tiết Ngày $day / ${widget.profile.totalCycleDays}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      stage.name,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInfoRow('Số ca tưới:', '$activeCount ca kích hoạt'),
                _dialogInfoRow('Tổng thời lượng:', '$totalMinutes phút/ngày'),
                _dialogInfoRow('Tổng lượng nước:', '${totalWaterMl}ml/gốc/ngày'),
                _dialogInfoRow(
                  'Độ ẩm đất yêu cầu:',
                  '${stage.requirements.soilMoistureMin.toInt()}% – ${stage.requirements.soilMoistureMax.toInt()}%',
                ),
                _dialogInfoRow(
                  'Nhiệt độ tối ưu:',
                  '${stage.requirements.tempMin.toInt()}°C – ${stage.requirements.tempMax.toInt()}°C',
                ),
                _dialogInfoRow(
                  'Độ ẩm không khí:',
                  '${stage.requirements.humidityMin.toInt()}% – ${stage.requirements.humidityMax.toInt()}%',
                ),
                const Divider(height: 16),
                const Text(
                  'Hoạt động chăm sóc khuyến nghị:',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                if (stage.keyActivities.isNotEmpty)
                  ...stage.keyActivities.map(
                    (act) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $act', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                    ),
                  )
                else
                  const Text(
                    '• Duy trì độ ẩm đất ổn định, theo dõi dự báo thời tiết trước các ca tưới.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showEditDayBottomSheet(context, day, stage);
              },
              child: const Text('Chỉnh Sửa Ca'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
