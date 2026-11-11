part of '../irrigation_calendar_screen.dart';

extension _IrrigationCalendarScreenStateEditDay on _IrrigationCalendarScreenState {
  void _showEditDayBottomSheet(BuildContext context, int day, GrowthStageProfile stage) {
    if (!_canEditSchedule) {
      _toast(
        'Hồ sơ hệ thống chỉ để xem. Tạo bản sao riêng của trang trại (Đổi hồ sơ → Tùy chỉnh bản sao) để chỉnh lịch tưới.',
        error: true,
      );
      return;
    }
    final sessions = _getSessionsForDay(day).map((s) => s.copyWith()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chỉnh Sửa Ca Tưới - Ngày $day',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                stage.name,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),

                    ...sessions.map((s) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(s.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                Switch(
                                  value: s.enabled,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setModalState(() => s.enabled = val);
                                  },
                                ),
                              ],
                            ),
                            if (s.enabled) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final parts = s.startTime.split(':');
                                        final initialHour = int.tryParse(parts[0]) ?? 7;
                                        final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                                        final picked = await showTimePicker(
                                          context: modalCtx,
                                          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
                                        );
                                        if (picked != null) {
                                          final h = picked.hour.toString().padLeft(2, '0');
                                          final m = picked.minute.toString().padLeft(2, '0');
                                          setModalState(() => s.startTime = '$h:$m');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF0284C7)),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Giờ: ${s.startTime}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF059669)),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${s.durationMinutes} phút',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text('Thời lượng: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Expanded(
                                    child: Slider(
                                      value: s.durationMinutes.toDouble().clamp(5, 30),
                                      min: 5,
                                      max: 30,
                                      divisions: 25,
                                      activeColor: const Color(0xFF10B981),
                                      onChanged: (v) {
                                        setModalState(() {
                                          s.durationMinutes = v.toInt();
                                          s.volumeMl = s.durationMinutes * 25;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              // Lịch lưu theo GIAI ĐOẠN (mọi ngày của giai đoạn dùng chung); kết quả báo sau khi backend xác nhận.
                              _updateDaySessions(day, sessions);
                              Navigator.pop(modalCtx);
                            },
                            child: const Text(
                              'Lưu Giai Đoạn',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF064E3B),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              _applyToAllDaysWith(day, sessions);
                              Navigator.pop(modalCtx);
                            },
                            child: const Text(
                              'Lưu Mọi Giai Đoạn',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
