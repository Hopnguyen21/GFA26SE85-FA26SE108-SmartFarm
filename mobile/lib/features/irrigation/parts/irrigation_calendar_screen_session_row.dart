part of '../irrigation_calendar_screen.dart';

extension _IrrigationCalendarScreenStateSessionRow
    on _IrrigationCalendarScreenState {
  Widget _buildInteractiveSessionRow(DayIrrigationSession s) {
    final iconColor = s.session == 'MORNING'
        ? const Color(0xFFF59E0B)
        : s.session == 'NOON'
        ? const Color(0xFFEF4444)
        : const Color(0xFF6366F1);

    final iconData = s.session == 'MORNING'
        ? Icons.wb_sunny_outlined
        : s.session == 'NOON'
        ? Icons.cloud_outlined
        : Icons.nights_stay_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: s.enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: s.enabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: s.enabled ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              iconData,
              size: 18,
              color: s.enabled ? iconColor : Colors.grey,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: s.enabled
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        decoration: s.enabled
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      s.enabled ? '${s.durationMinutes} phút' : 'Đã tắt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: s.enabled
                            ? const Color(0xFF059669)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      s.startTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: s.enabled ? iconColor : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '• ${s.method} (${s.volumeMl}ml)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: s.enabled,
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            onChanged: (val) {
              final sessions = _getSessionsForDay(_selectedCalendarDay);
              final updated = sessions.map((item) {
                if (item.session == s.session) {
                  return item.copyWith(enabled: val);
                }
                return item;
              }).toList();
              _updateDaySessions(_selectedCalendarDay, updated);
            },
          ),
        ],
      ),
    );
  }
}
