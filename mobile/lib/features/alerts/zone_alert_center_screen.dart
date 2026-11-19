import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/state_views.dart';
import '../ai/ai_screen.dart';
import 'alert_rules_logic.dart';
import '../../core/utils/user_error.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF119653);

String _err(Object e) => userFacingError(e);

/// Trung tâm cảnh báo của một Zone (như web): quy tắc cảnh báo an toàn (thêm/sửa/bật tắt/xóa) và nhật ký cảnh báo
/// (xác nhận, đóng kèm hành động đã làm, chẩn đoán AI). Dữ liệu thật từ backend; Farmer chỉ xem quy tắc.
class ZoneAlertCenterScreen extends StatefulWidget {
  final ZoneModel zone;
  const ZoneAlertCenterScreen({super.key, required this.zone});

  @override
  State<ZoneAlertCenterScreen> createState() => _ZoneAlertCenterScreenState();
}

class _ZoneAlertCenterScreenState extends State<ZoneAlertCenterScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _alerts = [];
  String?
  _rulesNote; // lý do chưa có quy tắc (vd. Zone chưa có vụ đang canh tác)
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final zoneId = widget.zone.zoneId;
      // Quy tắc theo giai đoạn của vụ đang canh tác: Zone chưa có vụ thì backend trả lỗi, vẫn xem được nhật ký.
      String? note;
      var rules = <Map<String, dynamic>>[];
      try {
        rules = await AlertApi.getRules(zoneId);
      } catch (e) {
        note = _err(e);
      }
      final alerts = await AlertApi.getZoneAlerts(zoneId);
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _alerts = alerts;
        _rulesNote = note;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  bool get _isOwner => context.read<FarmProvider>().currentRole == 'OWNER';

  /// Zone mới nhất từ FarmProvider (số đo/ngưỡng cập nhật liên tục); không có thì dùng bản được truyền vào.
  ZoneModel _zoneFrom(FarmProvider p) =>
      p.allZones.where((z) => z.zoneId == widget.zone.zoneId).firstOrNull ??
      widget.zone;

  Future<void> _guard(
    String key,
    Future<void> Function() job,
    String ok,
  ) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await job();
      if (mounted) showAppSnack(context, ok);
      await _load();
    } catch (e) {
      if (mounted) showAppSnack(context, _err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _toggle(Map<String, dynamic> r, bool value) => _guard(
    'rule-${r['ruleId']}',
    () => AlertApi.updateRule(
      widget.zone.zoneId,
      '${r['ruleId']}',
      parameterCode: '${r['parameterCode']}',
      minThreshold: (r['minThreshold'] as num).toDouble(),
      maxThreshold: (r['maxThreshold'] as num).toDouble(),
      severity: '${r['severity']}',
      cooldownMinutes: (r['cooldownMinutes'] as num).toInt(),
      isActive: value,
    ),
    value ? 'Đã bật quy tắc.' : 'Đã tắt quy tắc.',
  );

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa quy tắc?', style: TextStyle(fontSize: 16)),
        content: Text(
          'Quy tắc ${parameterLabel('${r['parameterCode']}')} (${severityLabel('${r['severity']}')}) sẽ không còn theo dõi Zone này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(
      'rule-${r['ruleId']}',
      () => AlertApi.archiveRule(widget.zone.zoneId, '${r['ruleId']}'),
      'Đã xóa quy tắc.',
    );
  }

  Future<void> _openEditor([Map<String, dynamic>? rule]) async {
    final zone = _zoneFrom(context.read<FarmProvider>());
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RuleEditor(zone: zone, rule: rule, existing: _rules),
    );
    if (saved == true) {
      if (mounted) {
        showAppSnack(
          context,
          rule == null ? 'Đã thêm quy tắc cảnh báo.' : 'Đã lưu quy tắc.',
        );
      }
      await _load();
    }
  }

  Future<void> _ack(Map<String, dynamic> a) => _guard(
    'alert-${a['alertId']}',
    () => AlertApi.acknowledge(
      '${a['alertId']}',
      notes: 'Đã xác nhận từ ứng dụng di động',
    ),
    'Đã xác nhận cảnh báo.',
  );

  Future<void> _resolve(Map<String, dynamic> a) async {
    final c = TextEditingController();
    String? err;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Đóng cảnh báo', style: TextStyle(fontSize: 16)),
          content: TextField(
            key: const Key('resolve_action'),
            controller: c,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Hành động đã thực hiện *',
              hintText: 'VD: Đã bật quạt thông gió và kiểm tra lại cảm biến',
              errorText: err,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final t = c.text.trim();
                if (t.isEmpty) {
                  setLocal(() => err = 'Bắt buộc ghi hành động đã làm.');
                  return;
                }
                Navigator.pop(ctx, t);
              },
              child: const Text('Đóng cảnh báo'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    await _guard(
      'alert-${a['alertId']}',
      () => AlertApi.resolve('${a['alertId']}', actionTaken: action),
      'Đã đóng cảnh báo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final zone = _zoneFrom(context.watch<FarmProvider>());
    final open = _alerts.where((a) => '${a['status']}' == 'Open').length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Cảnh báo & Quy tắc · ${zone.name}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Không tải được cảnh báo: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summary(open),
                  const SizedBox(height: 14),
                  _rulesCard(zone),
                  const SizedBox(height: 18),
                  Text(
                    'Nhật ký sự cố & cảnh báo (${_alerts.length})',
                    key: const Key('alert_log_title'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_alerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Zone chưa có cảnh báo nào.',
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                  for (final a in _alerts) _alertCard(a),
                ],
              ),
            ),
    );
  }

  Widget _summary(int open) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF119653), Color(0xFF0B6F3C)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.shield_outlined, color: Colors.white, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRUNG TÂM CẢNH BÁO NÔNG NGHIỆP',
                style: TextStyle(
                  color: Color(0xFFD1FAE5),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                open > 0
                    ? '$open cảnh báo đang mở cần xử lý'
                    : 'An toàn 100% · không có cảnh báo đang mở',
                key: const Key('alert_summary'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _rulesCard(ZoneModel zone) {
    final canEdit = _isOwner;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: _green,
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Cấu hình Quy tắc Cảnh báo An toàn Zone (${_rules.length} luật phù hợp)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (canEdit)
                  TextButton.icon(
                    key: const Key('add_rule'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _rulesNote != null ? null : () => _openEditor(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Thêm quy tắc mới',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (_rulesNote != null)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Chưa đọc được quy tắc: $_rulesNote (quy tắc gắn với giai đoạn của vụ đang canh tác).',
                key: const Key('rules_note'),
                style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            )
          else if (_rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                canEdit
                    ? 'Chưa có luật cảnh báo nào được cấu hình cho Zone (theo giai đoạn hiện tại). Bấm "Thêm quy tắc mới" để thiết lập ngưỡng an toàn!'
                    : 'Chưa có quy tắc nào cho giai đoạn hiện tại.',
                key: const Key('rules_empty'),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            )
          else
            for (final r in _rules) _ruleRow(r, zone, canEdit),
        ],
      ),
    );
  }

  Widget _ruleRow(Map<String, dynamic> r, ZoneModel zone, bool canEdit) {
    final code = '${r['parameterCode']}';
    final min = (r['minThreshold'] as num).toDouble();
    final max = (r['maxThreshold'] as num).toDouble();
    final active = r['isActive'] == true;
    final system = r['isSystemGenerated'] == true;
    final sev = '${r['severity']}';
    final current = currentValueOf(
      code,
      telemetryFresh: zone.telemetryIsFresh,
      temp: zone.currentTemp.toDouble(),
      soil: zone.currentSoilMoisture.toDouble(),
      humidity: zone.currentHumidity.toDouble(),
      lux: zone.currentLux.toDouble(),
    );
    final bad = isViolating(
      ruleActive: active,
      current: current,
      min: min,
      max: max,
    );
    final unit = parameterUnit(code);
    String n(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    final busy = _busy.contains('rule-${r['ruleId']}');
    return Container(
      key: Key('rule_${r['ruleId']}'),
      decoration: BoxDecoration(
        color: !active
            ? const Color(0xFFF8FAFC)
            : bad
            ? const Color(0xFFFFF1F2)
            : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      child: Opacity(
        opacity: active ? 1 : 0.55,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message: active ? 'Đang bật' : 'Đang tắt',
              child: Switch(
                value: active,
                onChanged: canEdit && !system && !busy
                    ? (v) => _toggle(r, v)
                    : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 8, top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: parameterColor(code).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: parameterColor(code).withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                parameterIcon(code),
                size: 16,
                color: parameterColor(code),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        parameterLabel(code),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _ink,
                        ),
                      ),
                      _badge(
                        severityCode(sev),
                        sev == 'Critical'
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                      ),
                      if (system) _badge('Hệ thống', _muted),
                      if (bad)
                        _badge(
                          '⚡ ĐANG VI PHẠM',
                          const Color(0xFFDC2626),
                          solid: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tham số: ${parameterLabel(code)}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  Text(
                    'Dải an toàn: [${n(min)} – ${n(max)}] $unit · chờ ${r['cooldownMinutes']} phút',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  if (current != null)
                    Text(
                      'Thực tế: ${n(current)} $unit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: bad
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF047857),
                      ),
                    ),
                ],
              ),
            ),
            if (canEdit && !system) ...[
              IconButton(
                tooltip: 'Sửa luật',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : () => _openEditor(r),
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
              IconButton(
                tooltip: 'Xóa luật',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : () => _delete(r),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String t, Color c, {bool solid = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
    decoration: BoxDecoration(
      color: solid ? c : c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: solid ? Colors.white : c,
      ),
    ),
  );

  Widget _alertCard(Map<String, dynamic> a) {
    final status = '${a['status']}';
    final sev = '${a['severity']}';
    final code = '${a['parameterCode']}';
    final unit = '${a['unit'] ?? parameterUnit(code)}';
    String n(Object? v) => v is num
        ? (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1))
        : '—';
    final created = DateTime.tryParse('${a['createdAtUtc']}')?.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final when = created == null
        ? '—'
        : '${two(created.day)}/${two(created.month)}/${created.year} ${two(created.hour)}:${two(created.minute)}';
    final id = '${a['alertId']}';
    final busy = _busy.contains('alert-$id');
    final statusColor = switch (status) {
      'Open' => const Color(0xFFDC2626),
      'Acknowledged' => const Color(0xFFD97706),
      _ => const Color(0xFF047857),
    };
    final history = (a['history'] as List?)?.cast<Map>() ?? const [];
    final lastAction = history
        .where((h) => '${h['eventType']}' == 'Resolved')
        .map((h) => '${h['actionTaken'] ?? ''}')
        .where((t) => t.isNotEmpty)
        .firstOrNull;
    return Container(
      key: Key('alert_$id'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _badge(alertStatusLabels[status] ?? status, statusColor),
              _badge(
                severityLabel(sev),
                sev == 'Critical'
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD97706),
              ),
              Text(when, style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${a['title'] ?? 'Cảnh báo ${parameterLabel(code)}'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Giá trị vi phạm: ${n(a['observedValue'])} $unit · ngưỡng ${n(a['minThreshold'])}–${n(a['maxThreshold'])} $unit',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          if (lastAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Đã xử lý: $lastAction',
                style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                ),
                icon: const Icon(
                  Icons.smart_toy_outlined,
                  size: 16,
                  color: _green,
                ),
                label: const Text(
                  'Chẩn đoán AI',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (status == 'Open')
                FilledButton.icon(
                  key: Key('ack_$id'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: busy ? null : () => _ack(a),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Xác nhận', style: TextStyle(fontSize: 12)),
                ),
              if (status != 'Resolved')
                FilledButton.tonalIcon(
                  key: Key('resolve_$id'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: busy ? null : () => _resolve(a),
                  icon: const Icon(Icons.task_alt, size: 16),
                  label: const Text(
                    'Đóng cảnh báo',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Biểu mẫu thêm/sửa quy tắc: tham số lấy từ ngưỡng của giai đoạn hiện tại (backend chỉ nhận tham số có trong giai đoạn).
class _RuleEditor extends StatefulWidget {
  final ZoneModel zone;
  final Map<String, dynamic>? rule;
  final List<Map<String, dynamic>> existing;
  const _RuleEditor({
    required this.zone,
    required this.rule,
    required this.existing,
  });

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late String? _param;
  late String _severity;
  late bool _active;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _cool;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.rule != null;

  /// Tham số có trong giai đoạn hiện tại và được backend hỗ trợ (kèm khoảng gợi ý min/max của giai đoạn).
  Map<String, ({double min, double max})> get _available {
    final out = <String, ({double min, double max})>{};
    for (final r in widget.zone.appliedRequirements) {
      final code = canonicalParameter('${r['parameterCode']}');
      final mn = (r['minValue'] as num?)?.toDouble();
      final mx = (r['maxValue'] as num?)?.toDouble();
      if (code != null && mn != null && mx != null)
        out[code] = (min: mn, max: mx);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _param = r == null
        ? _available.keys.firstOrNull
        : canonicalParameter('${r['parameterCode']}');
    _severity = r == null ? 'Warning' : '${r['severity']}';
    _active = r == null ? true : r['isActive'] == true;
    String f(Object? v) =>
        v is num ? (v == v.roundToDouble() ? '${v.toInt()}' : '$v') : '';
    final hint = _param == null ? null : _available[_param];
    _min = TextEditingController(
      text: r != null ? f(r['minThreshold']) : f(hint?.min),
    );
    _max = TextEditingController(
      text: r != null ? f(r['maxThreshold']) : f(hint?.max),
    );
    _cool = TextEditingController(
      text: r != null ? f(r['cooldownMinutes']) : '30',
    );
  }

  Future<void> _save() async {
    final min = double.tryParse(_min.text.trim().replaceAll(',', '.'));
    final max = double.tryParse(_max.text.trim().replaceAll(',', '.'));
    final cool = int.tryParse(_cool.text.trim());
    if (_param == null) {
      setState(() => _error = 'Chọn tham số cần theo dõi.');
      return;
    }
    final bad = validateRuleInput(min: min, max: max, cooldownMinutes: cool);
    if (bad != null) {
      setState(() => _error = bad);
      return;
    }
    // Backend không cho hai quy tắc cùng tham số + mức độ trong một giai đoạn: báo sớm, đỡ một vòng gọi API.
    final dup = widget.existing.any(
      (e) =>
          '${e['ruleId']}' != '${widget.rule?['ruleId']}' &&
          canonicalParameter('${e['parameterCode']}') == _param &&
          '${e['severity']}' == _severity,
    );
    if (dup) {
      setState(
        () => _error =
            'Đã có quy tắc ${parameterLabel(_param!)} mức ${severityLabel(_severity)} cho giai đoạn này. Hãy sửa quy tắc đó.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        await AlertApi.updateRule(
          widget.zone.zoneId,
          '${widget.rule!['ruleId']}',
          parameterCode: _param!,
          minThreshold: min!,
          maxThreshold: max!,
          severity: _severity,
          cooldownMinutes: cool!,
          isActive: _active,
        );
      } else {
        await AlertApi.createRule(
          widget.zone.zoneId,
          parameterCode: _param!,
          minThreshold: min!,
          maxThreshold: max!,
          severity: _severity,
          cooldownMinutes: cool!,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _err(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avail = _available;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editing
                  ? 'Chỉnh sửa Quy tắc Cảnh báo Zone'
                  : 'Thêm Quy tắc Cảnh báo Vi khí hậu Mới',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (!_editing && avail.isEmpty)
              const Text(
                'Zone chưa có ngưỡng của giai đoạn hiện tại (cần vụ đang canh tác) nên chưa thể tạo quy tắc.',
                key: Key('editor_no_params'),
                style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: const Key('rule_param'),
                isExpanded: true,
                initialValue: _param,
                decoration: const InputDecoration(
                  labelText: 'Tham số Cảm biến *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final code in {?_param, ...avail.keys})
                    DropdownMenuItem(
                      value: code,
                      child: Text(parameterLabel(code)),
                    ),
                ],
                onChanged: _editing
                    ? null
                    : (v) => setState(() {
                        _param = v;
                        final h = v == null ? null : avail[v];
                        if (h != null) {
                          _min.text = h.min == h.min.roundToDouble()
                              ? '${h.min.toInt()}'
                              : '${h.min}';
                          _max.text = h.max == h.max.roundToDouble()
                              ? '${h.max.toInt()}'
                              : '${h.max}';
                        }
                      }),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('rule_min'),
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Ngưỡng MIN (Dưới ngưỡng sẽ kích hoạt) ${_param == null ? '' : parameterUnit(_param!)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('rule_max'),
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Ngưỡng MAX (Vượt ngưỡng sẽ kích hoạt) ${_param == null ? '' : parameterUnit(_param!)}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const Key('rule_severity'),
                isExpanded: true,
                initialValue: _severity,
                decoration: const InputDecoration(
                  labelText: 'Mức độ Nghiêm trọng *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in alertSeverityFormLabels.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _severity = v ?? _severity),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('rule_cooldown'),
                controller: _cool,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText:
                      'Thời gian chờ giữa hai lần cảnh báo (phút, 1–1440)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_editing)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang bật', style: TextStyle(fontSize: 13)),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('rule_error'),
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('rule_save'),
                    onPressed: _saving || (!_editing && avail.isEmpty)
                        ? null
                        : _save,
                    child: Text(
                      _saving ? 'Đang lưu...' : 'Lưu Quy tắc Cảnh báo',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _cool.dispose();
    super.dispose();
  }
}

/// Biểu tượng và màu theo tham số (như các thẻ chỉ số của trang web).
IconData parameterIcon(String code) => switch (code) {
  'Temperature' => Icons.thermostat,
  'SoilMoisture' => Icons.water_drop_outlined,
  'AirHumidity' => Icons.air,
  'LightIntensity' => Icons.wb_sunny_outlined,
  'Ph' => Icons.science_outlined,
  'Ec' => Icons.bolt,
  _ => Icons.sensors,
};

Color parameterColor(String code) => switch (code) {
  'Temperature' => const Color(0xFFEA580C),
  'SoilMoisture' => const Color(0xFF0284C7),
  'AirHumidity' => const Color(0xFF0D9488),
  'LightIntensity' => const Color(0xFFCA8A04),
  'Ph' => const Color(0xFF7C3AED),
  'Ec' => const Color(0xFF047857),
  _ => const Color(0xFF64748B),
};
