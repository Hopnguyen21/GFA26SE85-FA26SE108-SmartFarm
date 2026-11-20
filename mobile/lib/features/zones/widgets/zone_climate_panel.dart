import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/profile_name.dart';
import '../zone_climate_logic.dart';
import '../zone_crop_plan_logic.dart';
import 'stage_draft_tile.dart' show fmtNumber;
import '../../../core/utils/user_error.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF047857);
const _amber = Color(0xFFB45309);
const _red = Color(0xFFB91C1C);

class _MetricSpec {
  final String code;
  final String title;
  final IconData icon;
  final Color color;
  const _MetricSpec(this.code, this.title, this.icon, this.color);
}

const _knownMetricSpecs = <String, _MetricSpec>{
  'soilmoisture': _MetricSpec('soilmoisture', 'Độ ẩm đất', Icons.water_drop, Color(0xFF0284C7)),
  'temperature': _MetricSpec('temperature', 'Nhiệt độ', Icons.thermostat, Color(0xFFEA580C)),
  'airhumidity': _MetricSpec('airhumidity', 'Độ ẩm không khí', Icons.cloud, _green),
  'lightintensity': _MetricSpec('lightintensity', 'Ánh sáng', Icons.wb_sunny, Color(0xFFCA8A04)),
  'ph': _MetricSpec('ph', 'pH', Icons.science_outlined, Color(0xFF7C3AED)),
  'ec': _MetricSpec('ec', 'EC', Icons.bolt_outlined, Color(0xFF0E7490)),
};

const _preferredMetricOrder = [
  'soilmoisture',
  'temperature',
  'airhumidity',
  'lightintensity',
  'ph',
  'ec',
];

_MetricSpec _specForMetricCode(String rawCode) {
  final norm = normalizeParameterCode(rawCode);
  return _knownMetricSpecs[norm] ??
      _MetricSpec(
        norm,
        rawCode.toUpperCase(),
        Icons.sensors_rounded,
        const Color(0xFF0284C7),
      );
}

/// Chỉ lấy các thông số cảm biến THỰC SỰ có dữ liệu gửi về từ trạm cảm biến của Zone.
/// Thông số nào không có dữ liệu đo thì ẩn hoàn toàn, không hiển thị thẻ trống.
List<_MetricSpec> _getActiveSpecs(ZoneTelemetrySnapshot? snap) {
  if (snap == null || snap.isEmpty) return const [];
  final availableCodes = snap.metrics.keys.toSet();
  final result = <_MetricSpec>[];
  for (final code in _preferredMetricOrder) {
    if (availableCodes.remove(code)) {
      result.add(_specForMetricCode(code));
    }
  }
  for (final code in availableCodes) {
    result.add(_specForMetricCode(code));
  }
  return result;
}

/// Tab "Vi khí hậu" của Zone Detail: telemetry của CHÍNH Zone đang mở (theo zoneId, tự tải và làm mới) kèm ngưỡng của hồ sơ
/// canh tác gắn trực tiếp cho Zone. Telemetry luôn hiển thị nếu có (kể cả khi Zone chưa có vụ); chỉ phần ĐÁNH GIÁ ngưỡng
/// cần hồ sơ + giai đoạn hiện tại. Số đo cũ được gắn nhãn "cũ" và không dùng để đánh giá.
class ZoneClimatePanel extends StatefulWidget {
  final ZoneModel zone;

  /// Nội dung đặt dưới cùng (khu vực bản đồ GIS của Zone).
  final Widget? footer;

  /// Chu kỳ làm mới telemetry; null = chỉ tải một lần (dùng trong test).
  final Duration? refreshEvery;
  final DateTime Function()? clock;
  const ZoneClimatePanel({
    super.key,
    required this.zone,
    this.footer,
    this.refreshEvery = const Duration(seconds: 15),
    this.clock,
  });

  @override
  State<ZoneClimatePanel> createState() => _ZoneClimatePanelState();
}

class _ZoneClimatePanelState extends State<ZoneClimatePanel> {
  bool _telemetryLoading = true;
  String? _telemetryError;
  ZoneTelemetrySnapshot? _telemetry;

  bool _profileLoading = false;
  String? _profileError;
  List<StageDraft> _stages = [];
  String? _profileName;
  String? _loadedProfileId;
  Timer? _timer;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();
  String _err(Object e) => userFacingError(e);

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
    _loadProfile();
    final every = widget.refreshEvery;
    if (every != null)
      _timer = Timer.periodic(every, (_) => _loadTelemetry(silent: true));
  }

  @override
  void didUpdateWidget(ZoneClimatePanel old) {
    super.didUpdateWidget(old);
    if (old.zone.zoneId != widget.zone.zoneId) {
      _telemetry = null;
      _loadTelemetry();
    }
    if (old.zone.zoneId != widget.zone.zoneId ||
        old.zone.growthProfileId != widget.zone.growthProfileId) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTelemetry({bool silent = false}) async {
    final zoneId = widget.zone.zoneId;
    if (!silent) setState(() => _telemetryLoading = true);
    try {
      final json = await FarmApi.getZoneTelemetry(zoneId);
      if (!mounted || widget.zone.zoneId != zoneId) return;
      setState(() {
        _telemetry = ZoneTelemetrySnapshot.fromJson(json);
        _telemetryError = null;
        _telemetryLoading = false;
      });
    } catch (e) {
      if (!mounted || widget.zone.zoneId != zoneId) return;
      setState(() {
        // Giữ số đo đã có nhưng báo lỗi làm mới; không coi là "mới nhất".
        _telemetryError = _err(e);
        _telemetryLoading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final profileId = widget.zone.growthProfileId;
    if (profileId == null) {
      setState(() {
        _stages = [];
        _profileName = null;
        _profileError = null;
        _loadedProfileId = null;
        _profileLoading = false;
      });
      return;
    }
    setState(() {
      _profileLoading = true;
      _profileError = null;
    });
    try {
      final all = await CropApi.getGrowthProfiles();
      if (!mounted || widget.zone.growthProfileId != profileId) return;
      final p = all
          .where(
            (x) => '${x['profileId']}'.toLowerCase() == profileId.toLowerCase(),
          )
          .firstOrNull;
      setState(() {
        if (p == null) {
          _stages = [];
          _profileName = widget.zone.growthProfileName;
          _profileError =
              'Không đọc được hồ sơ canh tác của Zone (có thể không còn hiển thị với tài khoản này).';
        } else {
          _profileName = displayProfileName(
            '${p['name']}',
            zoneName: widget.zone.name,
          );
          _stages = [
            for (final s in jsonList(jsonField(p, 'stages')))
              if (s is Map) StageDraft.fromJson(Map<String, dynamic>.from(s)),
          ]..sort((a, b) => a.order.compareTo(b.order));
        }
        _loadedProfileId = profileId;
        _profileLoading = false;
      });
    } catch (e) {
      if (!mounted || widget.zone.growthProfileId != profileId) return;
      setState(() {
        _profileError = _err(e);
        _profileLoading = false;
      });
    }
  }

  String _fmtTime(DateTime utc) {
    final l = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)} ${two(l.day)}/${two(l.month)}';
  }

  Widget _banner(
    String text, {
    Color color = _muted,
    Color bg = const Color(0xFFF0FDF4),
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFBBF7D0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF062326).withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.eco_rounded,
            size: 16,
            color: Color(0xFF047857),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color == _muted ? const Color(0xFF14532D) : color,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );

  /// Dòng trạng thái vụ + hồ sơ (tách khỏi telemetry).
  Widget _contextBanner(StageDraft? stage) {
    final z = widget.zone;
    final season = switch (z.seasonStatus) {
      'InProgress' => 'Vụ đang canh tác · giai đoạn: ${z.currentStage}',
      'PlannedOnly' => 'Chỉ có vụ dự kiến, chưa có vụ đang canh tác',
      'Mismatch' => 'Vụ đang chạy thuộc cây khác với cây của Zone',
      _ => 'Zone chưa có vụ đang canh tác',
    };
    final profile = z.growthProfileId == null
        ? 'Chưa gắn hồ sơ canh tác (không có ngưỡng để đánh giá)'
        : 'Hồ sơ của Zone: ${_profileName ?? z.growthProfileName ?? '—'}';
    final stageNote =
        z.growthProfileId != null &&
            z.seasonStatus == 'InProgress' &&
            stage == null &&
            !_profileLoading
        ? '\nKhông xác định được giai đoạn "${z.currentStage}" trong hồ sơ của Zone nên chưa đánh giá ngưỡng.'
        : '';
    return _banner('$season\n$profile$stageNote');
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zone;
    final stage = currentStageOfZone(
      profileStages: _stages,
      seasonStatus: z.seasonStatus,
      currentStageName: z.currentStage,
    );
    final snap = _telemetry;
    final now = _now;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _contextBanner(stage),
          _telemetryStatus(snap, now),
          if (_profileError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _profileError!,
                      style: const TextStyle(fontSize: 12, color: _red),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadProfile,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          if (_telemetryLoading && snap == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            // Chỉ hiển thị các thẻ cảm biến có dữ liệu nhận về từ trạm đo của Zone (Option A).
            Builder(
              builder: (context) {
                final activeSpecs = _getActiveSpecs(snap);
                if (activeSpecs.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF3C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sensors_off_outlined,
                            size: 28,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có số đo cảm biến',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Khu vực này hiện chưa nhận được dữ liệu từ trạm cảm biến nào. Chỉ các thông số có cảm biến gửi dữ liệu mới được hiển thị.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, box) {
                    final isSingle = activeSpecs.length == 1;
                    final w = isSingle ? box.maxWidth : (box.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final spec in activeSpecs)
                          SizedBox(
                            width: w,
                            child: _metricCard(spec, snap, stage, now),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            _complianceCard(snap, stage),
          ],
          const SizedBox(height: 16),
          if (widget.footer != null) widget.footer!,
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _telemetryStatus(ZoneTelemetrySnapshot? snap, DateTime now) {
    if (_telemetryError != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                snap == null
                    ? 'Không tải được telemetry: $_telemetryError'
                    : 'Không làm mới được telemetry ($_telemetryError). Số liệu bên dưới có thể đã cũ.',
                style: const TextStyle(fontSize: 12, color: _red),
              ),
            ),
            TextButton(onPressed: _loadTelemetry, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (snap == null) return const SizedBox.shrink();
    final String text;
    final Color color;
    if (snap.isEmpty) {
      text =
          'Chưa có số đo telemetry nào cho Zone này (chưa gán node cảm biến hoặc node chưa gửi dữ liệu).';
      color = _amber;
    } else if (snap.hasFreshTelemetry) {
      final at = snap.latestReceivedAtUtc;
      text =
          'Telemetry mới${at == null ? '' : ' · nhận lúc ${_fmtTime(at)} (${ageText(at, now)})'}';
      color = _green;
    } else {
      final at = snap.latestReceivedAtUtc;
      text =
          'Telemetry đã cũ${at == null ? '' : ' · lần nhận cuối ${_fmtTime(at)} (${ageText(at, now)})'}. Kiểm tra node cảm biến và kết nối.';
      color = _amber;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  RequirementDraft? _req(StageDraft? stage, String code) => stage?.requirements
      .where((r) => normalizeParameterCode(r.code) == code)
      .firstOrNull;

  Widget _metricCard(
    _MetricSpec spec,
    ZoneTelemetrySnapshot? snap,
    StageDraft? stage,
    DateTime now,
  ) {
    final metric = snap?.metrics[spec.code];
    final req = _req(stage, spec.code);
    final verdict = evaluateMetric(metric, req);
    final unit = metric?.unit ?? '';
    final numStr = metric == null
        ? '—'
        : fmtNumber(double.parse(metric.value.toStringAsFixed(1)));
    final value = metric == null
        ? '—'
        : '$numStr${unit.isEmpty ? '' : ' $unit'}';
    final (label, labelColor, labelBg) = switch (verdict) {
      MetricVerdict.ok => ('Trong ngưỡng', _green, const Color(0xFFECFDF5)),
      MetricVerdict.below => ('Thấp hơn ngưỡng', _red, const Color(0xFFFEF2F2)),
      MetricVerdict.above => ('Cao hơn ngưỡng', _red, const Color(0xFFFEF2F2)),
      MetricVerdict.stale => ('Số đo cũ', _amber, const Color(0xFFFFFBEB)),
      MetricVerdict.noThreshold => (
        'Chưa có ngưỡng',
        _muted,
        const Color(0xFFF1F5F9),
      ),
      MetricVerdict.noData => (
        'Chưa có số đo',
        _muted,
        const Color(0xFFF1F5F9),
      ),
    };
    final threshold = req == null
        ? (stage == null ? 'Chưa có ngưỡng giai đoạn' : 'Hồ sơ chưa có ngưỡng')
        : 'Ngưỡng: ${fmtNumber(req.min)}–${fmtNumber(req.max)} ${req.unit}';

    final isWarning =
        verdict == MetricVerdict.below || verdict == MetricVerdict.above;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            isWarning
                ? const Color(0xFFFFF1F2)
                : spec.color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning
              ? const Color(0xFFFCA5A5)
              : (metric == null
                    ? const Color(0xFFE2E8F0)
                    : spec.color.withValues(alpha: 0.2)),
          width: isWarning ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: spec.color.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4.5),
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(spec.icon, size: 14, color: spec.color),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  spec.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: metric == null || !metric.isFresh
                  ? _muted
                  : (isWarning ? _red : _ink),
              letterSpacing: -0.5,
            ),
          ),
          if (metric != null && !metric.isFresh) ...[
            const SizedBox(height: 2),
            Text(
              'cũ · ${ageText(metric.capturedAtUtc, now) ?? 'không rõ thời điểm'}',
              style: const TextStyle(
                fontSize: 10.5,
                color: _amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            threshold,
            style: const TextStyle(fontSize: 11, color: _muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: labelBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: labelColor.withValues(alpha: 0.18),
                width: 0.6,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: labelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _complianceCard(ZoneTelemetrySnapshot? snap, StageDraft? stage) {
    final z = widget.zone;
    final reasons = <String>[
      if (z.growthProfileId == null) 'Zone chưa gắn hồ sơ canh tác.',
      if (z.growthProfileId != null && _profileLoading)
        'Đang tải hồ sơ canh tác…',
      if (z.growthProfileId != null &&
          !_profileLoading &&
          _loadedProfileId == z.growthProfileId &&
          stage == null)
        z.seasonStatus == 'InProgress'
            ? 'Không xác định được giai đoạn hiện tại trong hồ sơ của Zone.'
            : 'Zone chưa có vụ đang canh tác nên chưa biết đang ở giai đoạn nào.',
      if (snap == null || snap.isEmpty) 'Chưa có số đo telemetry.',
      if (snap != null && !snap.isEmpty && !snap.hasFreshTelemetry)
        'Telemetry đã cũ.',
    ];
    final rows = <Widget>[];
    if (stage != null && snap != null) {
      final activeSpecs = _getActiveSpecs(snap);
      for (final spec in activeSpecs) {
        final req = _req(stage, spec.code);
        final metric = snap.metrics[spec.code];
        if (req == null || metric == null) continue;
        final v = evaluateMetric(metric, req);
        if (v == MetricVerdict.stale || v == MetricVerdict.noData) continue;
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  v == MetricVerdict.ok
                      ? Icons.check_circle
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: v == MetricVerdict.ok ? _green : _red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${spec.title}: ${fmtNumber(double.parse(metric.value.toStringAsFixed(1)))} ${metric.unit} '
                    '(ngưỡng ${fmtNumber(req.min)}–${fmtNumber(req.max)} ${req.unit})',
                    style: const TextStyle(fontSize: 12, color: _ink),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stage == null
                ? 'Đánh giá theo ngưỡng giai đoạn'
                : 'Đánh giá theo ngưỡng giai đoạn "${stage.name}"',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              reasons.isEmpty
                  ? 'Hồ sơ chưa có ngưỡng khớp với các số đo hiện có.'
                  : 'Chưa đánh giá được: ${reasons.join(' ')}',
              style: const TextStyle(fontSize: 12, color: _amber, height: 1.4),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}
