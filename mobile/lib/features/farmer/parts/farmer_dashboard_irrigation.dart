part of '../farmer_dashboard_screen.dart';

extension _FarmerDashboardIrrigation on _FarmerDashboardScreenState {
  /// Mở hộp thoại tưới thủ công (chỉ các Zone Nông dân được phép điều khiển).
  Future<void> _openIrrigation(
    FarmProvider provider,
    List<ZoneModel> zones, {
    String? zoneId,
  }) {
    final controllable = zones
        .where((z) => provider.canControlZone(z.zoneId))
        .toList();
    return showDialog<void>(
      context: context,
      builder: (_) => _IrrigationDialog(
        provider: provider,
        zones: controllable,
        initialZoneId: zoneId,
      ),
    );
  }
}

/// Tưới thủ công an toàn BR-SAFE-01: chọn Zone, thiết bị rơ-le/bơm, thời lượng tối đa 15 phút.
class _IrrigationDialog extends StatefulWidget {
  final FarmProvider provider;
  final List<ZoneModel> zones;
  final String? initialZoneId;
  const _IrrigationDialog({
    required this.provider,
    required this.zones,
    this.initialZoneId,
  });

  @override
  State<_IrrigationDialog> createState() => _IrrigationDialogState();
}

class _IrrigationDialogState extends State<_IrrigationDialog> {
  static const _durations = [1, 3, 5, 10, 15];

  String? _zoneId;
  String? _actuatorId;
  int _minutes = 5;
  bool _loading = false;
  bool _busy = false;
  String? _success;
  String? _error;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    if (widget.zones.isNotEmpty) {
      final want = widget.initialZoneId?.toLowerCase();
      _zoneId = widget.zones
          .firstWhere(
            (z) => z.zoneId.toLowerCase() == want,
            orElse: () => widget.zones.first,
          )
          .zoneId;
      _loadActuators();
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  /// Thiết bị bơm/van của Zone; không có loại phù hợp thì lấy toàn bộ như web.
  List<ActuatorModel> get _actuators {
    final id = _zoneId?.toLowerCase();
    final list = widget.provider.actuators
        .where((a) => a.zoneId.toLowerCase() == id)
        .toList();
    final pumps = list.where((a) {
      final n = a.name.toLowerCase();
      return a.actuatorType == 'PUMP' ||
          a.actuatorType == 'VALVE' ||
          n.contains('bơm') ||
          n.contains('tưới');
    }).toList();
    return pumps.isNotEmpty ? pumps : list;
  }

  Future<void> _loadActuators() async {
    setState(() {
      _loading = true;
      _actuatorId = null;
    });
    await widget.provider.refreshCurrentZoneActuators(zoneId: _zoneId);
    if (!mounted) return;
    final list = _actuators;
    setState(() {
      _loading = false;
      _actuatorId = list.isNotEmpty ? list.first.actuatorId : null;
    });
  }

  ActuatorModel? get _selected => _actuators
      .where((a) => a.actuatorId == _actuatorId)
      .cast<ActuatorModel?>()
      .firstOrNull;

  Future<void> _trigger() async {
    final act = _selected;
    if (act == null) return;
    // Khóa an toàn công suất như web: không bật 2 bơm lớn cùng lúc trong cùng hệ thống.
    final interlock = actuatorInterlockError(act, true, _actuators);
    if (interlock != null) {
      setState(() {
        _error = interlock;
        _success = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    final error = await widget.provider.toggleActuator(
      act.actuatorId,
      durationMinutes: _minutes,
      turnOn: true,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) {
        _success =
            '${widget.provider.lastActuatorNotice ?? 'Đã gửi lệnh bật thiết bị tưới.'} Tự ngắt sau $_minutes phút (BR-SAFE-01).';
      } else {
        _error = error;
      }
    });
    if (error == null) {
      // Như web: hiện xác nhận 2,5 giây rồi tự đóng.
      _closeTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final acts = _actuators;
    final selected = _selected;
    final running = selected?.isRunning ?? false;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Kích Hoạt Tưới Thủ Công An Toàn (BR-SAFE-01)',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 18,
                    color: Color(0xFFB45309),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cơ chế bảo vệ máy bơm & cây trồng: tối đa 15 phút cho mỗi lượt tưới thủ công. '
                      'Hệ thống IoT sẽ gửi lệnh ngắt tự động sau khi hết thời gian hẹn giờ.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78350F),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_success != null)
              _note(_success!, ok: true)
            else if (_error != null)
              _note(_error!, ok: false),
            if (widget.zones.isEmpty)
              const Text(
                'Bạn chưa được cấp quyền điều khiển khu vực nào.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              )
            else ...[
              const Text(
                'Chọn Khu vực Nhà màng:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _zoneId,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kGreen, width: 1.5),
                  ),
                ),
                items: [
                  for (final z in widget.zones)
                    DropdownMenuItem(
                      value: z.zoneId,
                      child: Text(
                        '${z.name} (${z.currentCrop.isNotEmpty ? z.currentCrop : 'Chưa gán cây'})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v == null || v == _zoneId) return;
                        setState(() => _zoneId = v);
                        _loadActuators();
                      },
              ),
              const SizedBox(height: 12),
              const Text(
                'Chọn Thiết bị Rơ-le / Bơm:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Text(
                  'Đang tìm thiết bị điều khiển trong khu vực này...',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B),
                  ),
                )
              else if (acts.isEmpty)
                const Text(
                  'Khu vực này chưa có thiết bị điều khiển.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _actuatorId,
                  isExpanded: true,
                  isDense: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kGreen, width: 1.5),
                    ),
                  ),
                  items: [
                    for (final a in acts)
                      DropdownMenuItem(
                        value: a.actuatorId,
                        child: Text(
                          '${a.name} [${a.actuatorType}]',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _actuatorId = v),
                ),
              if (running)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Thiết bị đang chạy (còn ${selected!.remainingMinutes} phút), '
                    'hãy đợi hệ thống tự ngắt hoặc tắt trong tab Điều khiển.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Thời gian tưới: $_minutes phút',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final m in _durations)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: _busy
                              ? null
                              : () => setState(() => _minutes = m),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _minutes == m ? _kGreen : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _minutes == m
                                    ? _kGreen
                                    : const Color(0xFFCBD5E1),
                                width: _minutes == m ? 1.5 : 1.0,
                              ),
                              boxShadow: _minutes == m
                                  ? [
                                      BoxShadow(
                                        color: _kGreen.withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              '${m}p',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _minutes == m
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Đóng'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _kGreen,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: (_busy || _selected == null || running || _success != null)
              ? null
              : _trigger,
          icon: const Icon(Icons.power_settings_new, size: 16),
          label: Text(
            _busy ? 'Đang kích hoạt...' : 'Bật tưới ngay ($_minutes phút)',
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  Widget _note(String text, {required bool ok}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ok ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: ok ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF),
      ),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: ok ? const Color(0xFF065F46) : const Color(0xFF9F1239),
      ),
    ),
  );
}
