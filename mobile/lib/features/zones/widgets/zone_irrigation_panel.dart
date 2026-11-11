import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/cron_utils.dart';
import '../profile_irrigation_logic.dart';
import '../zone_irrigation_logic.dart';
import 'profile_irrigation_view.dart';
import '../../irrigation/season_irrigation_calendar_screen.dart';
import '../../irrigation/season_irrigation_logic.dart' show syncSourceText;

const _muted = Color(0xFF64748B);

/// Lịch tưới của Zone, tách rõ HAI loại dữ liệu thật trong backend:
///  1. Lịch KHUYẾN NGHỊ của hồ sơ đang gắn trên Zone (theo giai đoạn) – hồ sơ riêng của trang trại sửa được và lưu trên backend.
///  2. Lịch ĐANG ÁP DỤNG cho thiết bị của Zone (ControlSchedule) – bật/tắt, sửa giờ/thời lượng/hoãn mưa.
/// Đồng bộ lấy lịch từ HỒ SƠ ĐANG GẮN trên Zone (không chọn cây tùy ý) và báo đúng kết quả/lỗi của backend.
/// Chỉ dành cho chủ trang trại (backend vẫn kiểm tra quyền).
class ZoneIrrigationPanel extends StatefulWidget {
  final ZoneModel zone;
  const ZoneIrrigationPanel({super.key, required this.zone});

  @override
  State<ZoneIrrigationPanel> createState() => _ZoneIrrigationPanelState();
}

class _ZoneIrrigationPanelState extends State<ZoneIrrigationPanel> {
  bool _loading = true;
  String? _loadedProfileId;
  ProfileSchedule? _profileSchedule;
  String? _profileError;
  List<ScheduleModel> _schedules = [];
  List<ActuatorModel> _actuators = [];
  String? _schedulesError;
  String? _actuatorsError;
  String? _actuatorId;
  String? _stageId; // null = để máy chủ chọn (giai đoạn hiện tại của vụ cùng hồ sơ, hoặc giai đoạn đầu)
  bool _busy = false;
  String? _message;
  ({SyncProblemKind kind, String message, String hint})? _problem;

  String? get _profileId {
    final live = context.read<FarmProvider>().allZones.where((z) => z.zoneId == widget.zone.zoneId).firstOrNull;
    return (live ?? widget.zone).growthProfileId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    final profileId = _profileId;
    setState(() {
      _loading = true;
      _profileError = _schedulesError = _actuatorsError = null;
    });
    final zoneId = widget.zone.zoneId;
    // Mỗi nguồn tải độc lập: một nguồn lỗi không làm mất các nguồn còn lại, và lỗi không bị biến thành "rỗng".
    final results = await Future.wait<Object?>([
      if (profileId != null)
        CropApi.getProfileIrrigation(profileId).then<Object?>((v) => v).catchError((Object e) => e)
      else
        Future<Object?>.value(null),
      AutomationApi.fetchZoneSchedules(zoneId).then<Object?>((v) => v).catchError((Object e) => e),
      FarmApi.fetchZoneActuators(zoneId).then<Object?>((v) => v).catchError((Object e) => e),
    ]);
    if (!mounted) return;
    setState(() {
      _loadedProfileId = profileId;
      final p = results[0];
      if (p is Map<String, dynamic>) {
        _profileSchedule = ProfileSchedule.fromJson(p);
      } else {
        _profileSchedule = null;
        if (p != null) _profileError = _err(p);
      }
      if (_stageId != null && !(_profileSchedule?.stages.any((s) => s.stageId == _stageId) ?? false)) _stageId = null;
      final sch = results[1];
      if (sch is List<ScheduleModel>) {
        _schedules = sch;
      } else {
        _schedulesError = _err(sch!);
      }
      final act = results[2];
      if (act is List<ActuatorModel>) {
        _actuators = act;
        final usable = irrigationActuators(act);
        if (!usable.any((a) => a.actuatorId == _actuatorId)) _actuatorId = usable.firstOrNull?.actuatorId;
      } else {
        _actuatorsError = _err(act!);
      }
      _loading = false;
    });
  }

  Future<void> _editStage(StageSchedule stage) async {
    final ps = _profileSchedule;
    if (ps == null) return;
    final edit = await showStageSessionsEditor(context, stage, canApplyAll: ps.stages.length > 1);
    if (edit == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _problem = null;
    });
    try {
      final targets = edit.applyToAllStages ? ps.stages : [stage];
      await CropApi.updateProfileIrrigation(ps.profileId, [
        for (final t in targets) stageIrrigationPayload(t.stageId, edit.sessions),
      ]);
      // Tải lại từ backend: thứ người dùng thấy là thứ đã được lưu.
      final fresh = await CropApi.getProfileIrrigation(ps.profileId);
      if (!mounted) return;
      setState(() {
        _profileSchedule = ProfileSchedule.fromJson(fresh);
        _message =
            'Đã lưu ca tưới ${edit.applyToAllStages ? 'cho mọi giai đoạn' : 'của giai đoạn "${stage.name}"'} vào hồ sơ. '
            'Lịch điều khiển của thiết bị chưa đổi cho tới khi bạn đồng bộ.';
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Không lưu được lịch tưới của hồ sơ: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(ScheduleModel s, bool on) async {
    await _saveSchedule(s, isActive: on, success: on ? 'Đã bật lịch "${s.name}".' : 'Đã tắt lịch "${s.name}".');
  }

  Future<void> _saveSchedule(
    ScheduleModel s, {
    String? cron,
    int? seconds,
    bool? rainDelay,
    double? rainThreshold,
    bool? isActive,
    required String success,
  }) async {
    setState(() {
      _busy = true;
      _message = null;
      _problem = null;
    });
    try {
      await AutomationApi.updateSchedule(
        widget.zone.zoneId,
        s.scheduleId,
        name: s.name,
        cronExpression: cron ?? s.cronExpression,
        durationSeconds: seconds ?? s.durationSeconds,
        enableRainDelay: rainDelay ?? s.enableRainDelay,
        rainThresholdPercent: rainThreshold ?? s.rainThresholdPercent,
        isActive: isActive ?? s.isActive,
      );
      final fresh = await AutomationApi.fetchZoneSchedules(widget.zone.zoneId);
      if (!mounted) return;
      setState(() {
        _schedules = fresh;
        _message = success;
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Không lưu được lịch: ${_err(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ScheduleModel s) async {
    final timeC = TextEditingController(text: cronToHhmm(s.cronExpression) ?? '');
    final minC = TextEditingController(text: (s.durationSeconds / 60).toString().replaceAll(RegExp(r'\.0$'), ''));
    final rainC = TextEditingController(text: s.rainThresholdPercent.toStringAsFixed(0));
    var rainDelay = s.enableRainDelay;
    String? error;
    final ok = await showDialog<({int seconds, String cron})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Sửa lịch "${s.name}"', style: const TextStyle(fontSize: 15)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Lặp hằng ngày vào một giờ cố định. Tối đa 30 phút mỗi lần.',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: timeC,
                  decoration: const InputDecoration(
                    labelText: 'Giờ (HH:mm)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: minC,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (phút)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hoãn khi có mưa', style: TextStyle(fontSize: 13)),
                  value: rainDelay,
                  onChanged: (v) => setLocal(() => rainDelay = v),
                ),
                if (rainDelay)
                  TextField(
                    controller: rainC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng xác suất mưa (%)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final v = validateScheduleEdit(
                  time: timeC.text,
                  minutesText: minC.text,
                  rainThresholdText: rainDelay ? rainC.text : '0',
                );
                if (v.error != null) {
                  setLocal(() => error = v.error);
                  return;
                }
                Navigator.pop(ctx, (seconds: v.seconds, cron: v.cron));
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    final rain = double.tryParse(rainC.text.trim().replaceAll(',', '.')) ?? s.rainThresholdPercent;
    Future.delayed(const Duration(milliseconds: 600), () {
      timeC.dispose();
      minC.dispose();
      rainC.dispose();
    });
    if (ok == null || !mounted) return;
    await _saveSchedule(
      s,
      cron: ok.cron,
      seconds: ok.seconds,
      rainDelay: rainDelay,
      rainThreshold: rainDelay ? rain : s.rainThresholdPercent,
      success: 'Đã lưu lịch "${s.name}".',
    );
  }

  Future<void> _sync() async {
    final actuatorId = _actuatorId;
    final ps = _profileSchedule;
    if (actuatorId == null || ps == null) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đồng bộ lịch từ hồ sơ?', style: TextStyle(fontSize: 15)),
        content: Text(
          'Các lịch "[AutoSync]" cũ của thiết bị này sẽ được thay bằng lịch mới. Nguồn: nếu hôm nay của vụ đang chạy có lịch tùy chỉnh '
          'thì dùng lịch đó; nếu không thì dùng lịch theo giai đoạn của hồ sơ "${ps.profileName}". '
          'Lịch bạn tạo thủ công không bị đổi.\n\n'
          'Lưu ý: thiết bị chỉ nhận lịch LẶP MỖI NGÀY. Lịch của hôm nay sẽ lặp lại hằng ngày cho tới lần đồng bộ kế tiếp; '
          'khi sang ngày hoặc giai đoạn có lịch khác, bạn cần đồng bộ lại thủ công.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng bộ')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _problem = null;
    });
    try {
      final r = await AutomationApi.syncScheduleFromProfile(
        widget.zone.zoneId,
        actuatorId: actuatorId,
        stageId: _stageId,
      );
      final created = (r['schedules'] as List?)?.length ?? 0;
      final fresh = await AutomationApi.fetchZoneSchedules(widget.zone.zoneId);
      if (!mounted) return;
      setState(() {
        _schedules = fresh;
        _message =
            'Đã đồng bộ $created lịch từ giai đoạn "${r['stageName']}" của hồ sơ "${r['profileName']}" '
            '(nguồn: ${syncSourceText(r)}). Thiết bị lặp lịch này hằng ngày; hãy đồng bộ lại khi sang ngày/giai đoạn có lịch khác.';
      });
    } catch (e) {
      if (mounted) setState(() => _problem = classifySyncError(_err(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hồ sơ của Zone đổi (ở phần hồ sơ phía trên) thì tải lại lịch của hồ sơ mới.
    final liveProfileId =
        context
            .watch<FarmProvider>()
            .allZones
            .where((z) => z.zoneId == widget.zone.zoneId)
            .firstOrNull
            ?.growthProfileId ??
        widget.zone.growthProfileId;
    if (!_loading && liveProfileId != _loadedProfileId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && liveProfileId != _loadedProfileId) _load();
      });
    }
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator(minHeight: 2));
    }
    final usable = irrigationActuators(_actuators);
    final ps = _profileSchedule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Lịch khuyến nghị của hồ sơ đang gắn trên Zone
        const Text(
          'Lịch khuyến nghị của hồ sơ (gắn trên Zone)',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        if (_loadedProfileId == null)
          const _Note(
            'Zone chưa gắn hồ sơ canh tác nên chưa có lịch khuyến nhị. Gắn hồ sơ ở mục "Cây trồng & hồ sơ canh tác" phía trên.',
          )
        else if (_profileError != null)
          _error('Không tải được lịch của hồ sơ: $_profileError')
        else if (ps != null)
          ProfileIrrigationView(schedule: ps, busy: _busy, onEdit: ps.isEditable ? _editStage : null),
        const SizedBox(height: 12),

        // 2. Lịch đang áp dụng cho Zone
        const Text(
          'Lịch đang áp dụng cho thiết bị của Zone (ControlSchedule)',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        if (_schedulesError != null)
          _error('Không tải được lịch của Zone: $_schedulesError')
        else if (_schedules.isEmpty)
          const _Note('Zone chưa có lịch tưới nào đang áp dụng.')
        else
          for (final s in _schedules)
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: ListTile(
                dense: true,
                title: Text(s.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${describeSchedule(s)}${s.nextRunFormatted == null ? '' : '\nLần chạy tới: ${s.nextRunFormatted}'}',
                  style: const TextStyle(fontSize: 11),
                ),
                isThreeLine: s.nextRunFormatted != null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Sửa lịch',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: _busy || cronToHhmm(s.cronExpression) == null ? null : () => _edit(s),
                    ),
                    Switch(value: s.isActive, onChanged: _busy ? null : (v) => _toggle(s, v)),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 12),

        // 2b. Lịch tùy chỉnh theo ngày của vụ (lưu trên máy chủ, dùng chung với web)
        const Text(
          'Lịch tưới tùy chỉnh theo ngày của vụ',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        const _Note(
          'Sửa lịch riêng cho từng ngày của vụ trồng (lưu trên máy chủ, mở được cả trên web). Không làm đổi lịch mẫu của hồ sơ.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => SeasonIrrigationCalendarScreen(zone: widget.zone))),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Mở lịch tưới theo ngày'),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Đồng bộ
        const Text(
          'Đồng bộ lịch của hồ sơ vào thiết bị',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        if (_loadedProfileId == null)
          const _Note('Cần gắn hồ sơ cho Zone trước khi đồng bộ.')
        else if (_actuatorsError != null)
          _error('Không tải được thiết bị của Zone: $_actuatorsError')
        else if (usable.isEmpty)
          const _Note(
            'Zone chưa có bơm/van tưới, nên chưa đồng bộ được. Thiết bị do kỹ thuật viên lắp và gán vào Zone.',
          )
        else ...[
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _actuatorId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Thiết bị tưới', isDense: true, border: OutlineInputBorder()),
            items: [
              for (final a in usable)
                DropdownMenuItem(
                  value: a.actuatorId,
                  child: Text(a.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _actuatorId = v),
          ),
          if (ps != null && ps.stages.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _stageId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Giai đoạn lấy lịch',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Tự chọn (giai đoạn hiện tại của vụ, hoặc giai đoạn đầu)'),
                ),
                for (final st in ps.stages)
                  DropdownMenuItem<String?>(value: st.stageId, child: Text('${st.order}. ${st.name}')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _stageId = v),
            ),
          ],
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _busy || ps == null ? null : _sync,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text('Đồng bộ lịch của hồ sơ'),
          ),
        ],
        if (_message != null) _Note(_message!),
        if (_problem != null) ...[_error(_problem!.message), if (_problem!.hint.isNotEmpty) _Note(_problem!.hint)],
        TextButton(onPressed: _busy ? null : _load, child: const Text('Tải lại')),
      ],
    );
  }

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
  );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: const TextStyle(fontSize: 11, color: _muted, height: 1.35)),
  );
}
