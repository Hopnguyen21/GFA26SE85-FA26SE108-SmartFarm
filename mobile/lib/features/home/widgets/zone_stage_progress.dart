import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';

/// Một giai đoạn trên thanh tiến độ.
typedef StageStep = ({String name, bool done, bool current});

/// Dựng các bước từ danh sách giai đoạn của hồ sơ (backend) và giai đoạn hiện tại của vụ đang canh tác.
/// Giai đoạn trước giai đoạn hiện tại là đã xong; không tìm thấy giai đoạn hiện tại thì không đánh dấu bước nào (không đoán).
List<StageStep> buildStageSteps(
  List<Map<String, dynamic>> stages, {
  String? currentStageId,
}) {
  final sorted = [...stages]
    ..sort(
      (a, b) => ((a['stageOrder'] as num?) ?? 0).compareTo(
        (b['stageOrder'] as num?) ?? 0,
      ),
    );
  final cur = (currentStageId ?? '').toLowerCase();
  final idx = cur.isEmpty
      ? -1
      : sorted.indexWhere(
          (s) => '${s['stageId'] ?? s['growthStageId']}'.toLowerCase() == cur,
        );
  return [
    for (var i = 0; i < sorted.length; i++)
      (
        name: '${sorted[i]['name'] ?? 'Giai đoạn ${i + 1}'}',
        done: idx >= 0 && i < idx,
        current: i == idx,
      ),
  ];
}

/// Tiến độ các giai đoạn canh tác của Zone, lấy từ hồ sơ + vụ đang canh tác thật (không còn 6 giai đoạn cố định).
class ZoneStageProgress extends StatefulWidget {
  final ZoneModel zone;
  const ZoneStageProgress({super.key, required this.zone});

  @override
  State<ZoneStageProgress> createState() => _ZoneStageProgressState();
}

class _ZoneStageProgressState extends State<ZoneStageProgress> {
  bool _loading = true;
  String? _error;
  List<StageStep> _steps = const [];
  bool _hasRunning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneStageProgress old) {
    super.didUpdateWidget(old);
    if (old.zone.zoneId != widget.zone.zoneId ||
        old.zone.currentStage != widget.zone.currentStage) {
      _load();
    }
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seasons = await CropApi.getPlantingSeasons(zoneId: zoneId);
      Map<String, dynamic>? running;
      for (final s in seasons) {
        if ('${s['status']}' == 'InProgress' &&
            '${s['zoneId'] ?? zoneId}'.toLowerCase() == zoneId.toLowerCase()) {
          running = s;
          break;
        }
      }
      var steps = <StageStep>[];
      final profileId = '${running?['growthProfileId'] ?? ''}'.trim();
      if (running != null && profileId.isNotEmpty && profileId != 'null') {
        final stages = await CropApi.getGrowthStages(profileId);
        steps = buildStageSteps(
          stages,
          currentStageId: '${running['currentGrowthStageId'] ?? ''}',
        );
      }
      if (!mounted || widget.zone.zoneId != zoneId) return;
      setState(() {
        _hasRunning = running != null;
        _steps = steps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  static const _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final title = _steps.isEmpty
        ? 'TIẾN ĐỘ GIAI ĐOẠN CANH TÁC'
        : 'TIẾN ĐỘ ${_steps.length} GIAI ĐOẠN CANH TÁC';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                key: const Key('stage_progress_title'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Chi tiết >',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF059669),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_error != null)
          Text(
            'Không tải được giai đoạn: $_error',
            style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
          )
        else if (_steps.isEmpty)
          Text(
            _hasRunning
                ? 'Hồ sơ của vụ chưa có giai đoạn.'
                : 'Chưa có vụ đang canh tác nên chưa có tiến độ giai đoạn.',
            key: const Key('stage_progress_empty'),
            style: const TextStyle(fontSize: 11, color: _muted),
          )
        else
          _bar(),
      ],
    );
  }

  Widget _bar() {
    // Nhiều giai đoạn thì cuộn ngang thay vì ép chật.
    final many = _steps.length > 6;
    final row = Row(
      mainAxisSize: many ? MainAxisSize.min : MainAxisSize.max,
      children: List.generate(_steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final done = _steps[index ~/ 2].done;
          final line = Container(
            height: 2,
            width: many ? 14 : null,
            color: done ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          );
          return many ? line : Expanded(child: line);
        }
        final i = index ~/ 2;
        final s = _steps[i];
        final dot = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.current
                    ? const Color(0xFF059669)
                    : s.done
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: s.current
                      ? const Color(0xFF059669)
                      : s.done
                      ? const Color(0xFF10B981)
                      : const Color(0xFFCBD5E1),
                  width: s.current ? 2 : 1,
                ),
              ),
              child: Center(
                child: s.done
                    ? const Icon(
                        Icons.check,
                        size: 10,
                        color: Color(0xFF059669),
                      )
                    : s.current
                    ? Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: many ? 56 : null,
              child: Text(
                s.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: s.current ? FontWeight.bold : FontWeight.w500,
                  color: s.current
                      ? const Color(0xFF059669)
                      : s.done
                      ? const Color(0xFF334155)
                      : const Color(0xFF94A3B8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
        return many ? dot : Expanded(flex: 3, child: dot);
      }),
    );
    return many
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
        : row;
  }
}
