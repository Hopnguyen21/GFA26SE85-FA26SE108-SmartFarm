import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../zone_auto_season.dart' show seasonCropLabel;
import 'record_yield_dialog.dart';

/// Kiểm tra xem một vụ mùa (hoặc giai đoạn hiện tại) đã đến giai đoạn thu hoạch chưa.
bool isHarvestStageSeason(
  Map<String, dynamic> season, {
  ZoneModel? zone,
  List<Map<String, dynamic>>? profileStages,
}) {
  final status = '${season['status']}';
  if (status == 'Completed') return true;
  if (status != 'InProgress') return false;

  // 1. Kiểm tra theo tên giai đoạn từ season hoặc zone
  final stageName =
      (season['currentGrowthStageName'] ??
              season['currentStageName'] ??
              zone?.currentStage)
          ?.toString()
          .trim()
          .toLowerCase();

  if (stageName != null && stageName.isNotEmpty) {
    if (stageName.contains('thu hoạch') ||
        stageName.contains('thu hoach') ||
        stageName.contains('harvest')) {
      return true;
    }
  }

  // 2. Kiểm tra theo hồ sơ sinh trưởng (nếu có danh sách stages)
  if (profileStages != null && profileStages.isNotEmpty) {
    final sorted = [...profileStages]
      ..sort(
        (a, b) => ((a['stageOrder'] as num?) ?? 0).compareTo(
          (b['stageOrder'] as num?) ?? 0,
        ),
      );
    final lastStage = sorted.last;
    final curId = '${season['currentGrowthStageId'] ?? ''}'
        .trim()
        .toLowerCase();

    final lastId =
        '${lastStage['stageId'] ?? lastStage['growthStageId'] ?? lastStage['id'] ?? ''}'
            .trim()
            .toLowerCase();
    final lastStageName = '${lastStage['name'] ?? ''}'.toLowerCase();
    final isLastStageHarvest =
        lastStageName.contains('thu hoạch') ||
        lastStageName.contains('thu hoach') ||
        lastStageName.contains('harvest');

    if (curId.isNotEmpty && curId == lastId && isLastStageHarvest) {
      return true;
    }

    if (curId.isNotEmpty) {
      final curObj = sorted
          .where(
            (s) =>
                '${s['stageId'] ?? s['growthStageId'] ?? s['id'] ?? ''}'
                    .toLowerCase() ==
                curId,
          )
          .firstOrNull;
      if (curObj != null) {
        final curName = '${curObj['name'] ?? ''}'.toLowerCase();
        if (curName.contains('thu hoạch') ||
            curName.contains('thu hoach') ||
            curName.contains('harvest')) {
          return true;
        }
      }
    }
  }

  return false;
}

/// Chọn vụ để theo dõi sản lượng:
/// - Nếu có vụ đang canh tác (InProgress): CHỈ chọn khi vụ này đã đến giai đoạn thu hoạch.
/// - Nếu vụ đang canh tác chưa đến giai đoạn thu hoạch: không chọn (trả về null để ẩn thẻ).
/// - Nếu không có vụ đang canh tác: chọn vụ đã thu hoạch gần nhất (Completed).
Map<String, dynamic>? pickHarvestSeason(
  Iterable<Map<String, dynamic>> seasons, {
  ZoneModel? zone,
  List<Map<String, dynamic>>? profileStages,
}) {
  Map<String, dynamic>? running;
  Map<String, dynamic>? lastDone;
  for (final s in seasons) {
    final st = '${s['status']}';
    if (st == 'InProgress') {
      running ??= s;
    } else if (st == 'Completed') {
      if (lastDone == null ||
          '${s['startDate']}'.compareTo('${lastDone['startDate']}') > 0) {
        lastDone = s;
      }
    }
  }

  if (running != null) {
    final isHarvest = isHarvestStageSeason(
      running,
      zone: zone,
      profileStages: profileStages,
    );
    return isHarvest ? running : null;
  }

  return lastDone;
}

/// Thẻ "Sản lượng canh tác & thu hoạch" của Zone (giống web): sản lượng thực tế, tấn, năng suất kg/m²,
/// ngày ghi nhận, phân loại, ghi chú và nút nhập/cập nhật. Chỉ dùng số liệu từ backend, không có giá trị mẫu.
class ZoneYieldCard extends StatefulWidget {
  final ZoneModel zone;

  /// Tăng để tải lại từ bên ngoài.
  final int version;

  /// Gọi sau khi ghi sản lượng để màn cha tải lại.
  final Future<void> Function()? onChanged;
  const ZoneYieldCard({
    super.key,
    required this.zone,
    this.version = 0,
    this.onChanged,
  });

  @override
  State<ZoneYieldCard> createState() => _ZoneYieldCardState();
}

class _ZoneYieldCardState extends State<ZoneYieldCard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _season;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneYieldCard old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version ||
        old.zone.zoneId != widget.zone.zoneId) {
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
      final all = await CropApi.getPlantingSeasons(zoneId: zoneId);
      if (!mounted || widget.zone.zoneId != zoneId) return;

      final mySeasons = [
        for (final s in all)
          if ('${s['zoneId'] ?? zoneId}'.toLowerCase() == zoneId.toLowerCase())
            s,
      ];

      final running = mySeasons
          .where((s) => '${s['status']}' == 'InProgress')
          .firstOrNull;

      List<Map<String, dynamic>>? stages;
      final profileId =
          '${running?['growthProfileId'] ?? widget.zone.growthProfileId ?? ''}'
              .trim();
      if (profileId.isNotEmpty && profileId != 'null') {
        try {
          stages = await CropApi.getGrowthStages(profileId);
        } catch (_) {}
      }

      if (!mounted || widget.zone.zoneId != zoneId) return;
      setState(() {
        _season = pickHarvestSeason(
          mySeasons,
          zone: widget.zone,
          profileStages: stages,
        );
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

  Future<void> _record(Map<String, dynamic> season) async {
    final ok = await showHarvestYieldDialog(
      context,
      zoneId: widget.zone.zoneId,
      zoneName: widget.zone.name,
      areaM2: widget.zone.areaM2,
      cropLabel: seasonCropLabel(season, widget.zone.currentCrop),
      season: season,
    );
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu sản lượng vụ mùa.')));
    await widget.onChanged?.call();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Chỉ hiển thị thẻ khi vụ mùa đã đến giai đoạn thu hoạch (hoặc đã thu hoạch)
    if (_loading || _error != null || _season == null) {
      return const SizedBox.shrink();
    }

    final role = context.read<FarmProvider>().currentRole;
    final canRecord = role == 'OWNER' || role == 'FARMER';
    final s = _season!;
    final done = '${s['status']}' == 'Completed';
    final yieldKg = s['actualYieldKg'] as num?;
    final kg = (yieldKg ?? 0).toDouble();
    final area = widget.zone.areaM2;
    final id = harvestSeasonId(s);
    final cached = id == null ? null : harvestNoteCache[id];

    return Container(
      key: const Key('zone_yield_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF119653), Color(0xFF0B6F3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.scale_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sản lượng canh tác & thu hoạch',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    done ? 'Đã thu hoạch' : 'Vụ đang canh tác',
                    key: const Key('yield_status'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Theo dõi và ghi nhận sản lượng nông sản cho Zone này',
              style: TextStyle(fontSize: 11, color: Color(0xFFD1FAE5)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    'Sản lượng thực tế',
                    yieldKg == null ? '—' : fmtKg(kg),
                    yieldKg == null ? '' : 'kg',
                    yieldKg == null
                        ? 'Chưa ghi nhận'
                        : '≈ ${(kg / 1000).toStringAsFixed(2)} tấn',
                    valueKey: const Key('yield_value'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _metric(
                    'Năng suất bình quân',
                    yieldKg == null
                        ? '—'
                        : yieldPerM2(kg, area).toStringAsFixed(2),
                    yieldKg == null ? '' : 'kg/m²',
                    'Trên ${fmtKg(area)} m²',
                    valueKey: const Key('yield_density'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _line('Vụ', '${s['name'] ?? '—'}'),
                  _line(
                    'Cây trồng',
                    seasonCropLabel(s, widget.zone.currentCrop),
                  ),
                  _line(
                    'Phân loại chất lượng',
                    cached?.quality ?? 'Chưa ghi nhận',
                  ),
                  _line(
                    done ? 'Ngày thu hoạch' : 'Dự kiến kết thúc',
                    harvestDayLabel(
                      done ? s['actualEndDate'] : s['expectedEndDate'],
                    ),
                  ),
                  if ((cached?.notes ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ghi chú: ${cached!.notes}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD1FAE5),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (canRecord) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('yield_open'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF119653),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Nhập / Cập nhật sản lượng thu hoạch (kg)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: id == null ? null : () => _record(s),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(
    String label,
    String value,
    String unit,
    String sub, {
    Key? valueKey,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: Color(0xFFD1FAE5)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD1FAE5),
                    ),
                  ),
              ],
            ),
            key: valueKey,
          ),
        ),
        Text(
          sub,
          style: const TextStyle(fontSize: 10, color: Color(0xFFD1FAE5)),
        ),
      ],
    ),
  );

  Widget _line(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Color(0xFFD1FAE5))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
