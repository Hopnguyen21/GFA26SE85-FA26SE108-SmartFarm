part of '../schedules_automation_screen.dart';

/// Tiêu đề nhóm Zone trong danh sách phẳng của màn Lịch & Luật.
class _ZoneHeader {
  final String name;
  final int count;
  const _ZoneHeader(this.name, this.count);
}

extension _SchedulesAutomationScreenStateHelpers
    on _SchedulesAutomationScreenState {
  Widget _buildSchedulesTab(BuildContext context, FarmProvider provider) {
    final list = sortedSchedules(provider.schedules);
    final conflicts = conflictingScheduleIds(list);
    final rows = _zoneRows<ScheduleModel>(list, (s) => s.zoneName);
    final bodyCount = rows.isEmpty ? 1 : rows.length;
    // Thẻ dẫn tới kế hoạch ca Sáng/Trưa/Chiều theo vụ (AI gợi ý) của Zone đang chọn.
    final hasPlan = provider.currentZone.zoneId.isNotEmpty;
    final offset = hasPlan ? 1 : 0;
    return RefreshIndicator(
      onRefresh: provider.refreshSchedulesAndRules,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: bodyCount + 1 + offset,
        itemBuilder: (context, i) {
          if (hasPlan && i == 0) return _seasonPlanCard(context, provider);
          i -= offset;
          if (i == bodyCount) return const SizedBox(height: 60);
          if (rows.isEmpty) {
            if (provider.schedulesLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _emptyCard(
              Icons.schedule,
              'Chưa có lịch tưới định kỳ nào',
              _canConfigSchedule(provider)
                  ? 'Bấm "Thêm Mới" để tạo lịch tưới theo giờ (ca sáng, trưa, chiều) cho từng Zone.'
                  : 'Chủ trang trại chưa thiết lập lịch tưới cho các Zone.',
            );
          }
          final row = rows[i];
          if (row is _ZoneHeader) return _zoneHeader(row);
          final sch = row as ScheduleModel;
          return _buildScheduleCard(
            context,
            provider,
            sch,
            conflict: conflicts.contains(sch.scheduleId),
          );
        },
      ),
    );
  }

  /// Ca tưới theo vụ (Sáng/Trưa/Chiều) do AI gợi ý và chủ trang trại duyệt nằm ở màn Lịch tưới theo vụ; thẻ này nối hai màn.
  Widget _seasonPlanCard(BuildContext context, FarmProvider provider) {
    final zone = provider.currentZone;
    return Container(
      key: const ValueKey('season-plan-card'),
      margin: const EdgeInsets.only(bottom: 14),
      // Material (không phải DecoratedBox có màu) để hiệu ứng chạm của ListTile hiển thị.
      child: Material(
        color: const Color(0xFFF0F9FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFBAE6FD)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.auto_awesome, color: Color(0xFF0369A1)),
          title: const Text(
            'Ca tưới theo vụ (AI gợi ý)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            'Xem và chỉnh kế hoạch ca Sáng – Trưa – Chiều theo giai đoạn của ${zone.name}.',
            style: const TextStyle(fontSize: 11.5),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SeasonIrrigationCalendarScreen(zone: zone),
            ),
          ),
        ),
      ),
    );
  }

  /// Danh sách phẳng gồm tiêu đề Zone xen kẽ các mục của Zone đó (để dựng bằng ListView.builder).
  List<Object> _zoneRows<T extends Object>(
    List<T> sorted,
    String Function(T) zoneOf,
  ) {
    final out = <Object>[];
    groupByZone<T>(sorted, zoneOf).forEach((zone, items) {
      out.add(_ZoneHeader(zone.isEmpty ? 'Chưa rõ Zone' : zone, items.length));
      out.addAll(items);
    });
    return out;
  }

  Widget _zoneHeader(_ZoneHeader h) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 8),
    child: Row(
      children: [
        const Icon(Icons.grid_view_rounded, size: 14, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            h.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${h.count}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    ),
  );

  Widget _emptyCard(IconData icon, String title, String hint) => Container(
    margin: const EdgeInsets.only(top: 24),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 32, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    ),
  );

  Widget _miniChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  /// Chip "Ca sáng/trưa/chiều/đêm" và cảnh báo trùng giờ dưới tên Zone của thẻ lịch.
  Widget _scheduleChips(ScheduleModel sch, bool conflict) {
    final shift = shiftOfTime(sch.startTime);
    if (shift == null && !conflict) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          if (shift != null) _miniChip(shift, const Color(0xFF0369A1)),
          if (conflict)
            _miniChip('Trùng giờ với lịch khác', const Color(0xFFB45309)),
        ],
      ),
    );
  }
}
