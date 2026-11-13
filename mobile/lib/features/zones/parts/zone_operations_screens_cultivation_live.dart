part of '../zone_operations_screens.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 6. Tab Canh tác: giai đoạn của vụ đang chạy + lịch tưới thật của Zone
// ═══════════════════════════════════════════════════════════════════════════
class ZoneCultivationLive extends StatefulWidget {
  final String zoneId;
  const ZoneCultivationLive({super.key, required this.zoneId});

  @override
  State<ZoneCultivationLive> createState() => _ZoneCultivationLiveState();
}

class _ZoneCultivationLiveState extends State<ZoneCultivationLive> {
  late final Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)>
  _season = _loadSeason();
  late final Future<List<ScheduleModel>> _schedules =
      AutomationApi.getSchedules(zoneId: widget.zoneId);

  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)>
  _loadSeason() async {
    final seasons = await CropApi.getPlantingSeasons(zoneId: widget.zoneId);
    final active =
        seasons.where((s) => '${s['status']}' == 'InProgress').firstOrNull ??
        seasons.where((s) => '${s['status']}' == 'Planned').firstOrNull;
    if (active == null) return (null, <Map<String, dynamic>>[]);
    final stages = await CropApi.getGrowthStages(
      '${active['growthProfileId']}',
    );
    stages.sort(
      (a, b) => ((a['stageOrder'] as num?) ?? 0).compareTo(
        (b['stageOrder'] as num?) ?? 0,
      ),
    );
    return (active, stages);
  }

  Widget _box(
    Widget child, {
    Color color = Colors.white,
    Color border = const Color(0xFFE2E8F0),
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    ),
    child: child,
  );

  Widget _stageRow(
    Map<String, dynamic> s,
    String range, {
    required bool done,
    required bool current,
    required bool last,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? _green
                    : current
                    ? const Color(0xFF062326)
                    : const Color(0xFFF1F5F9),
              ),
              child: Icon(
                done
                    ? Icons.check
                    : current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 14,
                color: done || current ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            if (!last)
              Container(
                width: 2,
                height: 26,
                color: done ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s['name']}${current ? '  · HIỆN TẠI' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: current ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
                Text(
                  'Ngày $range',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _seasonSection() =>
      FutureBuilder<(Map<String, dynamic>?, List<Map<String, dynamic>>)>(
        future: _season,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _box(
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (snap.hasError) {
            return _box(
              Text(
                'Không tải được vụ trồng: ${_err(snap.error!)}',
                style: const TextStyle(color: _muted),
              ),
            );
          }
          final (season, stages) = snap.data!;
          if (season == null) {
            return _box(
              const Text(
                'Zone chưa có vụ trồng đang chạy hoặc dự kiến.',
                style: TextStyle(color: _muted),
              ),
            );
          }
          final currentId = '${season['currentGrowthStageId']}'.toLowerCase();
          final currentIdx = stages.indexWhere(
            (s) => '${s['stageId']}'.toLowerCase() == currentId,
          );
          final rows = <Widget>[];
          var dayFrom = 0;
          for (var i = 0; i < stages.length; i++) {
            final days = (stages[i]['durationDays'] as num?)?.toInt() ?? 0;
            rows.add(
              _stageRow(
                stages[i],
                '${dayFrom + 1}–${dayFrom + days}',
                done: currentIdx >= 0 && i < currentIdx,
                current: i == currentIdx,
                last: i == stages.length - 1,
              ),
            );
            dayFrom += days;
          }
          return _box(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${season['name']} · ${season['cropName'] ?? ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _ink,
                  ),
                ),
                Text(
                  'Bắt đầu ${season['startDate']} · dự kiến ${season['expectedEndDate']}',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  const Text(
                    'Hồ sơ sinh trưởng chưa có giai đoạn.',
                    style: TextStyle(color: _muted),
                  ),
                ...rows,
              ],
            ),
          );
        },
      );

  Widget _scheduleSection() => FutureBuilder<List<ScheduleModel>>(
    future: _schedules,
    builder: (context, snap) {
      Widget body;
      if (snap.connectionState != ConnectionState.done) {
        body = const LinearProgressIndicator(minHeight: 2);
      } else if (snap.hasError) {
        body = Text(
          'Không tải được lịch tưới: ${_err(snap.error!)}',
          style: const TextStyle(fontSize: 12, color: _muted),
        );
      } else if (snap.data!.isEmpty) {
        body = const Text(
          'Chưa có lịch tưới. Owner có thể đồng bộ từ hồ sơ cây ở tab Thiết bị.',
          style: TextStyle(fontSize: 12, color: _muted),
        );
      } else {
        body = Column(
          children: [
            for (final s in snap.data!)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      s.isEnabled ? Icons.schedule : Icons.pause_circle_outline,
                      size: 16,
                      color: s.isEnabled ? const Color(0xFF0284C7) : _muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.name} · ${s.startTime} · ${s.durationMinutes} phút'
                        '${s.actuatorName.isNotEmpty ? ' · ${s.actuatorName}' : ''}',
                        style: const TextStyle(fontSize: 12, color: _ink),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }
      return _box(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop, color: Color(0xFF0284C7), size: 18),
                SizedBox(width: 6),
                Text(
                  'Lịch tưới của Zone',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0C4A6E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
        color: const Color(0xFFF0F9FF),
        border: const Color(0xFFBAE6FD),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VÒNG ĐỜI CÂY TRỒNG (GIAI ĐOẠN)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: _muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        _seasonSection(),
        const SizedBox(height: 20),
        _scheduleSection(),
      ],
    );
  }
}
