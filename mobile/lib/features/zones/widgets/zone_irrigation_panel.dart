import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/cron_utils.dart';
import '../profile_irrigation_logic.dart';
import '../zone_irrigation_logic.dart';
import '../crop_sync_logic.dart';
import '../actuator_labels.dart';
import 'profile_irrigation_view.dart';
import '../../irrigation/season_irrigation_calendar_screen.dart';
import '../../irrigation/season_irrigation_logic.dart' show syncSourceText;
import '../../../core/utils/user_error.dart';
import '../../../core/utils/haptics.dart';

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
  String?
  _stageId; // null = để máy chủ chọn (giai đoạn hiện tại của vụ cùng hồ sơ, hoặc giai đoạn đầu)
  bool _busy = false;
  String? _message;
  ({SyncProblemKind kind, String message, String hint})? _problem;

  String? get _profileId {
    final live = context
        .read<FarmProvider>()
        .allZones
        .where((z) => z.zoneId == widget.zone.zoneId)
        .firstOrNull;
    return (live ?? widget.zone).growthProfileId;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _err(Object e) => userFacingError(e);

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
        CropApi.getProfileIrrigation(
          profileId,
        ).then<Object?>((v) => v).catchError((Object e) => e)
      else
        Future<Object?>.value(null),
      AutomationApi.fetchZoneSchedules(
        zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
      FarmApi.fetchZoneActuators(
        zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
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
      if (_stageId != null &&
          !(_profileSchedule?.stages.any((s) => s.stageId == _stageId) ??
              false))
        _stageId = null;
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
        if (!usable.any((a) => a.actuatorId == _actuatorId))
          _actuatorId = usable.firstOrNull?.actuatorId;
      } else {
        _actuatorsError = _err(act!);
      }
      _loading = false;
    });
  }

  Future<void> _editStage(StageSchedule stage) async {
    final ps = _profileSchedule;
    if (ps == null) return;
    final edit = await showStageSessionsEditor(
      context,
      stage,
      canApplyAll: ps.stages.length > 1,
    );
    if (edit == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _problem = null;
    });
    try {
      final targets = edit.applyToAllStages ? ps.stages : [stage];
      await CropApi.updateProfileIrrigation(ps.profileId, [
        for (final t in targets)
          stageIrrigationPayload(t.stageId, edit.sessions),
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
      if (mounted)
        setState(
          () => _message = 'Không lưu được lịch tưới của hồ sơ: ${_err(e)}',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(ScheduleModel s, bool on) async {
    AppHaptics.selection();
    await _saveSchedule(
      s,
      isActive: on,
      success: on ? 'Đã bật lịch "${s.name}".' : 'Đã tắt lịch "${s.name}".',
    );
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

  Future<void> _triggerScheduleActuator(ScheduleModel s) async {
    final usable = irrigationActuators(_actuators);
    final actId = s.actuatorId.isNotEmpty
        ? s.actuatorId
        : usable.firstOrNull?.actuatorId;
    if (actId == null) {
      setState(() => _message = 'Lịch chưa gán thiết bị rơ-le bơm/van.');
      return;
    }
    final mins = (s.durationSeconds / 60).clamp(1, 15).round();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await AutomationApi.sendActuatorCommand(
        zoneId: widget.zone.zoneId,
        actuatorId: actId,
        action: 'TurnOn',
        durationSeconds: mins * 60,
      );
      if (!mounted) return;
      // HTTP 202 chỉ nghĩa là đã lưu/đã gửi: chỉ báo "đã bật" khi gateway ACK.
      setState(() {
        _message = result.failed
            ? 'Gateway không thực hiện được lệnh (${result.status})'
                  '${result.errorMessage?.isNotEmpty == true ? ': ${result.errorMessage}' : '.'}'
            : result.acknowledged
            ? 'Gateway đã xác nhận BẬT rơ-le cho lịch "${s.name}". Tự ngắt an toàn sau $mins phút (BR-SAFE-01).'
            : 'Đã gửi lệnh BẬT rơ-le cho lịch "${s.name}", đang chờ gateway xác nhận. Tự ngắt an toàn sau $mins phút (BR-SAFE-01).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Không kích hoạt được rơ-le: ${_err(e)}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(ScheduleModel s) async {
    final timeC = TextEditingController(
      text: cronToHhmm(s.cronExpression) ?? '',
    );
    final minC = TextEditingController(
      text: (s.durationSeconds / 60).toString().replaceAll(RegExp(r'\.0$'), ''),
    );
    final rainC = TextEditingController(
      text: s.rainThresholdPercent.toStringAsFixed(0),
    );
    var rainDelay = s.enableRainDelay;
    String? error;
    final ok = await showDialog<({int seconds, String cron})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            'Sửa lịch "${s.name}"',
            style: const TextStyle(fontSize: 15),
          ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng (phút)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Hoãn khi có mưa',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: rainDelay,
                  onChanged: (v) => setLocal(() => rainDelay = v),
                ),
                if (rainDelay)
                  TextField(
                    controller: rainC,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng xác suất mưa (%)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
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
    final rain =
        double.tryParse(rainC.text.trim().replaceAll(',', '.')) ??
        s.rainThresholdPercent;
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
        title: const Text(
          'Đồng bộ lịch từ hồ sơ?',
          style: TextStyle(fontSize: 15),
        ),
        content: Text(
          'Các lịch "[AutoSync]" cũ của thiết bị này sẽ được thay bằng lịch mới. Nguồn: nếu hôm nay của vụ đang chạy có lịch tùy chỉnh '
          'thì dùng lịch đó; nếu không thì dùng lịch theo giai đoạn của hồ sơ "${ps.profileName}". '
          'Lịch bạn tạo thủ công không bị đổi.\n\n'
          'Lưu ý: thiết bị chỉ nhận lịch LẶP MỖI NGÀY. Lịch của hôm nay sẽ lặp lại hằng ngày cho tới lần đồng bộ kế tiếp; '
          'khi sang ngày hoặc giai đoạn có lịch khác, bạn cần đồng bộ lại thủ công.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đồng bộ'),
          ),
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

  /// Như web "Đồng bộ từ Thư viện Cây": chọn một cây trong thư viện, xem trước 3 ca Sáng-Trưa-Chiều rồi áp vào Zone.
  Future<void> _syncFromCrop() async {
    final actuatorId = _actuatorId;
    if (actuatorId == null) {
      setState(
        () => _message =
            'Zone chưa có bơm/van tưới để gắn lịch. Thiết bị do kỹ thuật viên lắp và gán vào Zone.',
      );
      return;
    }
    List<Map<String, dynamic>> crops;
    try {
      crops = await CropApi.getCropsForProfiles();
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Không tải được Thư viện Cây: ${_err(e)}');
      }
      return;
    }
    if (!mounted) return;
    if (crops.isEmpty) {
      setState(() => _message = 'Thư viện Cây trồng đang trống.');
      return;
    }
    final cropId = await showDialog<String>(
      context: context,
      builder: (_) => _CropSyncDialog(crops: crops),
    );
    if (cropId == null || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _problem = null;
    });
    try {
      final created = await AutomationApi.syncScheduleFromCrop(
        widget.zone.zoneId,
        cropId: cropId,
        actuatorId: actuatorId,
      );
      final fresh = await AutomationApi.fetchZoneSchedules(widget.zone.zoneId);
      if (!mounted) return;
      setState(() {
        _schedules = fresh;
        _message =
            'Đã đồng bộ ${created.length} ca tưới Sáng-Trưa-Chiều & vi khí hậu từ Thư viện Cây sang Zone "${widget.zone.name}".';
      });
    } catch (e) {
      final msg = _err(e);
      if (mounted) {
        setState(
          () => _message =
              msg.contains('403') || msg.toLowerCase().contains('quyền')
              ? 'Quyền truy cập: Chỉ tài khoản có thẩm quyền (Chủ trang trại / Kỹ thuật viên) mới được đồng bộ lịch sang Zone.'
              : 'Không thể đồng bộ lịch tưới sang Zone lúc này: $msg',
        );
      }
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
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
          ProfileIrrigationView(
            schedule: ps,
            busy: _busy,
            onEdit: ps.isEditable ? _editStage : null,
          ),
        const SizedBox(height: 12),

        // 2. Lịch đang áp dụng cho Zone
        const Text(
          'Lịch đang áp dụng cho thiết bị của Zone (ControlSchedule)',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        if (_schedulesError != null)
          _error('Không tải được lịch của Zone: $_schedulesError')
        else if (_schedules.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Note('Zone chưa có lịch tưới nào đang áp dụng.'),
              if (usable.isNotEmpty)
                TextButton.icon(
                  key: const ValueKey('sync-crop-empty'),
                  onPressed: _busy ? null : _syncFromCrop,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text(
                    'Đồng bộ lịch Sáng-Trưa-Chiều từ Thư viện Cây',
                  ),
                ),
            ],
          )
        else
          for (final s in _schedules)
            Card(
              margin: const EdgeInsets.only(top: 6),
              child: ListTile(
                dense: true,
                leading: _sessionIcon(s),
                title: Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${[s.zoneName, s.actuatorName].where((x) => x.isNotEmpty).join(' • ')}\n${describeSchedule(s)}${s.nextRunFormatted == null ? '' : '\nLần chạy tới: ${s.nextRunFormatted}'}',
                  style: const TextStyle(fontSize: 11),
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Bật tưới ngay qua LoRa',
                      icon: const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 20,
                        color: Color(0xFF047857),
                      ),
                      onPressed: _busy
                          ? null
                          : () => _triggerScheduleActuator(s),
                    ),
                    IconButton(
                      tooltip: 'Sửa lịch',
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: _busy || cronToHhmm(s.cronExpression) == null
                          ? null
                          : () => _edit(s),
                    ),
                    Switch(
                      value: s.isActive,
                      onChanged: _busy ? null : (v) => _toggle(s, v),
                    ),
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
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SeasonIrrigationCalendarScreen(zone: widget.zone),
                    ),
                  ),
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
            decoration: const InputDecoration(
              labelText: 'Thiết bị tưới',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in usable)
                DropdownMenuItem(
                  value: a.actuatorId,
                  // Tên kênh trùng giữa các node ("… #1" của node 1 và node 2): thêm vị trí để phân biệt.
                  child: Text(
                    [a.name, ?actuatorPlaceLabel(a, usable)].join(' · '),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  child: Text(
                    'Tự chọn (giai đoạn hiện tại của vụ, hoặc giai đoạn đầu)',
                  ),
                ),
                for (final st in ps.stages)
                  DropdownMenuItem<String?>(
                    value: st.stageId,
                    child: Text('${st.order}. ${st.name}'),
                  ),
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, size: 18),
            label: const Text('Đồng bộ lịch của hồ sơ'),
          ),
        ],
        // Như web: đồng bộ từ Thư viện Cây không cần Zone đã gắn hồ sơ (chọn cây tùy ý).
        if (usable.isNotEmpty && _actuatorsError == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: OutlinedButton.icon(
              key: const ValueKey('sync-crop-button'),
              onPressed: _busy ? null : _syncFromCrop,
              icon: const Icon(Icons.local_florist_outlined, size: 18),
              label: const Text('Đồng bộ từ Thư viện Cây'),
            ),
          ),
        if (_message != null) _Note(_message!),
        if (_problem != null) ...[
          _error(_problem!.message),
          if (_problem!.hint.isNotEmpty) _Note(_problem!.hint),
        ],
        TextButton(
          onPressed: _busy ? null : _load,
          child: const Text('Tải lại'),
        ),
      ],
    );
  }

  Widget _error(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
    ),
  );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: _muted, height: 1.35),
    ),
  );
}

Widget _sessionIcon(ScheduleModel s) => switch (scheduleSessionKind(s)) {
  IrrigationSessionKind.morning => const Icon(
    Icons.wb_twilight,
    size: 20,
    color: Color(0xFFD97706),
  ),
  IrrigationSessionKind.noon => const Icon(
    Icons.wb_sunny_outlined,
    size: 20,
    color: Color(0xFFE11D48),
  ),
  IrrigationSessionKind.afternoon => const Icon(
    Icons.nights_stay_outlined,
    size: 20,
    color: Color(0xFF4F46E5),
  ),
  IrrigationSessionKind.other => const Icon(
    Icons.schedule,
    size: 20,
    color: _muted,
  ),
};

/// Hộp thoại "Đồng bộ lịch tưới Sáng-Trưa-Chiều từ Thư viện Cây trồng" (giống web): chọn cây + xem trước 3 ca.
class _CropSyncDialog extends StatefulWidget {
  final List<Map<String, dynamic>> crops;
  const _CropSyncDialog({required this.crops});

  @override
  State<_CropSyncDialog> createState() => _CropSyncDialogState();
}

class _CropSyncDialogState extends State<_CropSyncDialog> {
  static String _id(Map<String, dynamic> c) => '${c['cropId'] ?? c['id']}';

  late String _cropId = _id(widget.crops.first);

  Map<String, dynamic> get _crop => widget.crops.firstWhere(
    (c) => _id(c) == _cropId,
    orElse: () => widget.crops.first,
  );

  String _label(Map<String, dynamic> c) {
    final sci = '${c['scientificName'] ?? ''}'.trim();
    final cat = '${c['category'] ?? ''}'.trim();
    return '${c['name'] ?? 'Cây trồng'}${sci.isEmpty ? '' : ' ($sci)'} - ${cat.isEmpty ? 'VietGAP' : cat}';
  }

  @override
  Widget build(BuildContext context) {
    final sessions = parseCropPlanSessions(
      _crop['calendarIrrigationPlan'] ?? _crop['CalendarIrrigationPlan'],
    );
    Widget cell(String title, String key, Color color) {
      final x = planSessionOf(sessions, key);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                x?.label ?? 'Chưa có',
                style: const TextStyle(fontSize: 10.5, color: _muted),
              ),
            ],
          ),
        ),
      );
    }

    final cycle = (_crop['growthCycleDays'] as num?)?.toInt();
    return AlertDialog(
      key: const ValueKey('crop-sync-dialog'),
      title: const Text(
        'Đồng bộ lịch tưới Sáng-Trưa-Chiều từ Thư viện Cây trồng',
        style: TextStyle(fontSize: 15),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn loài cây mẫu từ thư viện để tải lịch tưới 3 ca (Sáng, Trưa, Chiều) và dải vi khí hậu tối ưu vào Zone hiện tại.',
              style: TextStyle(fontSize: 11.5, color: _muted, height: 1.35),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: const ValueKey('crop-sync-select'),
              initialValue: _cropId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn loại cây trồng',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final c in widget.crops)
                  DropdownMenuItem(
                    value: _id(c),
                    child: Text(_label(c), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _cropId = v ?? _cropId),
            ),
            const SizedBox(height: 10),
            Text(
              cycle == null ? 'Chưa có chu kỳ' : '$cycle ngày vụ',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                cell('🌅 Ca Sáng', 'MORNING', const Color(0xFFB45309)),
                const SizedBox(width: 6),
                cell('☀️ Ca Trưa', 'NOON', const Color(0xFFBE123C)),
                const SizedBox(width: 6),
                cell('🌇 Ca Chiều', 'AFTERNOON', const Color(0xFF4338CA)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const ValueKey('crop-sync-apply'),
          onPressed: () => Navigator.pop(context, _cropId),
          child: const Text('Áp dụng & đồng bộ sang Zone'),
        ),
      ],
    );
  }
}
