import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../zone_sensor_thresholds.dart' show requirementFor;
import '../../../core/utils/user_error.dart';
import '../../zones/zone_climate_logic.dart'
    show currentStageOfZone, normalizeParameterCode;
import '../../zones/zone_crop_plan_logic.dart'
    show RequirementDraft, StageDraft;

/// Vùng nhiệt độ an toàn đo được theo giai đoạn hiện tại của vụ đang canh tác (hồ sơ canh tác của Zone).
typedef SafeTempRange = ({double min, double max});

/// Lấy dải nhiệt độ của giai đoạn hiện tại từ danh sách giai đoạn của hồ sơ (cùng nguồn với tab Vi khí hậu của Zone).
/// null khi Zone không có vụ đang chạy, không khớp giai đoạn hiện tại, hoặc giai đoạn không có ngưỡng nhiệt độ.
SafeTempRange? safeTempRangeOf({
  required List<StageDraft> stages,
  required String seasonStatus,
  required String currentStage,
}) {
  final stage = currentStageOfZone(
    profileStages: stages,
    seasonStatus: seasonStatus,
    currentStageName: currentStage,
  );
  final RequirementDraft? req = stage?.requirements
      .where((r) => normalizeParameterCode(r.code) == 'temperature')
      .firstOrNull;
  if (req == null || req.max <= req.min) return null;
  return (min: req.min, max: req.max);
}

/// Khoảng hiển thị của thanh đo: bao trọn vùng an toàn và số đo hiện tại, làm tròn ra 5°C.
({double min, double max}) gaugeScale(SafeTempRange safe, double current) {
  final lo = [safe.min - 8, current - 2].reduce((a, b) => a < b ? a : b);
  final hi = [safe.max + 12, current + 2].reduce((a, b) => a > b ? a : b);
  return (min: (lo / 5).floorToDouble() * 5, max: (hi / 5).ceilToDouble() * 5);
}

/// Tăng sau khi lưu ngưỡng điều khiển để các đồng hồ đang hiển thị tải lại ngưỡng quạt.
final ValueNotifier<int> thresholdsSavedSignal = ValueNotifier<int>(0);

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Thẻ "vùng nhiệt độ an toàn" của Home: ngưỡng lấy từ hồ sơ canh tác ở giai đoạn hiện tại (không còn 18–28°C cố định),
/// ngưỡng bật quạt lấy từ cấu hình điều khiển đã lưu của Zone.
class ZoneTemperatureGauge extends StatefulWidget {
  final ZoneModel zone;
  final VoidCallback onEditThresholds;
  const ZoneTemperatureGauge({
    super.key,
    required this.zone,
    required this.onEditThresholds,
  });

  @override
  State<ZoneTemperatureGauge> createState() => _ZoneTemperatureGaugeState();
}

class _ZoneTemperatureGaugeState extends State<ZoneTemperatureGauge> {
  bool _loading = true;
  String? _error;
  SafeTempRange? _safe;
  double? _fanMaxTemp;

  @override
  void initState() {
    super.initState();
    thresholdsSavedSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    thresholdsSavedSignal.removeListener(_load);
    super.dispose();
  }

  @override
  void didUpdateWidget(ZoneTemperatureGauge old) {
    super.didUpdateWidget(old);
    final a = old.zone, b = widget.zone;
    if (a.zoneId != b.zoneId ||
        a.growthProfileId != b.growthProfileId ||
        a.currentStage != b.currentStage ||
        a.seasonStatus != b.seasonStatus ||
        a.appliedRequirements.length != b.appliedRequirements.length) {
      _load();
    }
  }

  Future<void> _load() async {
    final z = widget.zone;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Nguồn chính: ngưỡng đã áp dụng cho vụ (ai/context); không có thì dò theo giai đoạn của hồ sơ.
      SafeTempRange? safe;
      final applied = requirementFor(z, 'temperature');
      if (applied != null && applied.max > applied.min) {
        safe = (min: applied.min, max: applied.max);
      }
      final profileId = z.growthProfileId;
      if (safe == null && profileId != null && z.seasonStatus == 'InProgress') {
        final raw = await CropApi.getGrowthStages(profileId);
        safe = safeTempRangeOf(
          stages: [for (final s in raw) StageDraft.fromJson(s)],
          seasonStatus: z.seasonStatus,
          currentStage: z.currentStage,
        );
      }
      double? fan;
      try {
        final cfg = await AutomationApi.getEnvironmentalConfig(z.zoneId);
        final v = (cfg?['maxTemperature'] as num?)?.toDouble();
        if (v != null && v > 0) fan = v;
      } catch (_) {
        // Không có quyền/không tải được cấu hình điều khiển: chỉ ẩn dòng ngưỡng quạt.
      }
      if (!mounted || widget.zone.zoneId != z.zoneId) return;
      setState(() {
        _safe = safe;
        _fanMaxTemp = fan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  Widget _box(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final z = widget.zone;
    if (!z.telemetryIsFresh) {
      return _box(
        const Text(
          'Chưa có telemetry nhiệt độ mới từ DB để đánh giá vùng an toàn.',
          style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
        ),
      );
    }
    if (_loading) return _box(const LinearProgressIndicator(minHeight: 2));
    if (_error != null) {
      return _box(
        Row(
          children: [
            Expanded(
              child: Text(
                'Không tải được ngưỡng nhiệt độ: $_error',
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            ),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final safe = _safe;
    if (safe == null) {
      return _box(
        const Text(
          'Chưa có ngưỡng nhiệt độ theo giai đoạn của vụ đang canh tác để đánh giá vùng an toàn.',
          key: Key('temp_gauge_no_threshold'),
          style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
        ),
      );
    }

    final t = z.currentTemp.toDouble();
    final scale = gaugeScale(safe, t);
    final span = scale.max - scale.min;
    final isOptimal = t >= safe.min && t <= safe.max;
    final isHot = t > safe.max;
    final color = isOptimal
        ? const Color(0xFF047857)
        : (isHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB));
    double frac(double v) => ((v - scale.min) / span).clamp(0.0, 1.0);

    return _box(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.thermostat, size: 18, color: Color(0xFFEA580C)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Nhiệt độ ${_fmt(t)}°C · giai đoạn ${z.currentStage}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                key: const Key('temp_gauge_verdict'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 0.8),
                ),
                child: Text(
                  isOptimal
                      ? '✓ Chuẩn'
                      : (isHot
                            ? '⚠️ > ${_fmt(safe.max)}°C'
                            : '⚠️ < ${_fmt(safe.min)}°C'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 4,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: w * frac(safe.min),
                      width: w * (frac(safe.max) - frac(safe.min)),
                      top: 4,
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF86EFAC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      left: (w * frac(t) - 5).clamp(0.0, w - 10),
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_fmt(scale.min)}°C',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              Text(
                'Chuẩn: ${_fmt(safe.min)}°C - ${_fmt(safe.max)}°C',
                key: const Key('temp_gauge_range'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
              Text(
                '${_fmt(scale.max)}°C',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: widget.onEditThresholds,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 13, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fanMaxTemp == null
                          ? 'Chưa cấu hình ngưỡng bật quạt • Bấm để chỉnh ngưỡng'
                          : 'Quạt bật khi > ${_fmt(_fanMaxTemp!)}°C • Bấm để chỉnh ngưỡng',
                      key: const Key('temp_gauge_fan'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 15,
                    color: Color(0xFF0284C7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
