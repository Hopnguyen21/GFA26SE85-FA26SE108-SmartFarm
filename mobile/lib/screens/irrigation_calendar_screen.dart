import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Đại diện cho một ca tưới trong ngày
class DayIrrigationSession {
  final String session; // MORNING, NOON, AFTERNOON
  String title;
  String startTime; // HH:mm
  int durationMinutes; // 1 to 30
  bool enabled;
  String method; // Drip, Mist, Sprinkler
  int volumeMl; // Lượng nước dự kiến ml/gốc

  DayIrrigationSession({
    required this.session,
    required this.title,
    required this.startTime,
    required this.durationMinutes,
    this.enabled = true,
    this.method = 'Tưới nhỏ giọt bù áp',
    this.volumeMl = 500,
  });

  Map<String, dynamic> toJson() => {
    'session': session,
    'title': title,
    'startTime': startTime,
    'durationMinutes': durationMinutes,
    'enabled': enabled,
    'method': method,
    'volumeMl': volumeMl,
  };

  factory DayIrrigationSession.fromJson(Map<String, dynamic> json) => DayIrrigationSession(
    session: json['session']?.toString() ?? 'MORNING',
    title: json['title']?.toString() ?? '',
    startTime: json['startTime']?.toString() ?? '06:30',
    durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 15,
    enabled: json['enabled'] as bool? ?? true,
    method: json['method']?.toString() ?? 'Tưới nhỏ giọt bù áp',
    volumeMl: (json['volumeMl'] as num?)?.toInt() ?? 500,
  );

  DayIrrigationSession copyWith({
    String? title,
    String? startTime,
    int? durationMinutes,
    bool? enabled,
    String? method,
    int? volumeMl,
  }) {
    return DayIrrigationSession(
      session: session,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      enabled: enabled ?? this.enabled,
      method: method ?? this.method,
      volumeMl: volumeMl ?? this.volumeMl,
    );
  }
}

/// Màn hình Cuốn lịch tưới cả tháng & toàn bộ vụ mùa theo chuẩn VietGAP.
/// Hỗ trợ:
/// 1. Xem lịch tưới dạng lưới cuốn lịch 30 ngày / cả vụ mùa
/// 2. Xem chi tiết từng ca tưới, thông số vi khí hậu và lưu lượng nước theo ngày
/// 3. Chỉnh sửa ca tưới theo ngày hoặc áp dụng hàng loạt cho cả giai đoạn / cả vụ
class IrrigationCalendarScreen extends StatefulWidget {
  final DefaultCropProfile profile;
  final String? zoneName;

  const IrrigationCalendarScreen({
    super.key,
    required this.profile,
    this.zoneName,
  });

  @override
  State<IrrigationCalendarScreen> createState() => _IrrigationCalendarScreenState();
}

class _IrrigationCalendarScreenState extends State<IrrigationCalendarScreen> {
  int _selectedCalendarDay = 1;
  int _selectedMonthBlock = 1; // 1 = Ngày 1-30, 2 = Ngày 31-60, 3 = Ngày 61+
  final Map<int, List<DayIrrigationSession>> _dayOverrides = {};
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedOverrides();
  }

  String get _storageKey => 'smartfarm_calendar_overrides_${widget.profile.cropId}_${widget.profile.profileId}';

  Future<void> _loadSavedOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          final dayNum = int.tryParse(key);
          if (dayNum != null && val is List) {
            _dayOverrides[dayNum] = val
                .whereType<Map<String, dynamic>>()
                .map((e) => DayIrrigationSession.fromJson(e))
                .toList();
          }
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoaded = true);
    }
  }

  Future<void> _saveOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> payload = {};
      _dayOverrides.forEach((k, v) {
        payload[k.toString()] = v.map((e) => e.toJson()).toList();
      });
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }

  int _getStageIndexForDay(DefaultCropProfile profile, int day) {
    if (profile.growthStages.isEmpty) return 0;
    var accumulated = 0;
    for (int i = 0; i < profile.growthStages.length; i++) {
      final s = profile.growthStages[i];
      final start = accumulated + 1;
      final end = accumulated + s.durationDays;
      accumulated = end;
      if (day >= start && day <= end) {
        return i;
      }
    }
    return profile.growthStages.length - 1;
  }

  GrowthStageProfile _getStageForDay(DefaultCropProfile profile, int day) {
    if (profile.growthStages.isEmpty) {
      return const GrowthStageProfile(
        stageId: '',
        name: 'Mặc định',
        nameEn: 'Default',
        startDayFromPlanting: 1,
        endDayFromPlanting: 30,
        description: '',
        iconEmoji: '🌱',
        requirements: EnvironmentalRange(
          tempMin: 20,
          tempMax: 30,
          soilMoistureMin: 60,
          soilMoistureMax: 75,
          humidityMin: 60,
          humidityMax: 80,
          irrigationDurationMin: 15,
          irrigationFrequencyPerDay: 2,
        ),
        keyActivities: [],
      );
    }
    final idx = _getStageIndexForDay(profile, day);
    return profile.growthStages[idx];
  }

  Color _getStageColor(int stageIndex) {
    switch (stageIndex % 4) {
      case 0:
        return const Color(0xFF10B981); // Emerald (Cây con)
      case 1:
        return const Color(0xFF0284C7); // Sky (Thân lá)
      case 2:
        return const Color(0xFFF59E0B); // Amber (Hoa/Trái)
      case 3:
      default:
        return const Color(0xFF8B5CF6); // Purple (Thu hoạch)
    }
  }

  Color _getStageBgColor(int stageIndex) {
    switch (stageIndex % 4) {
      case 0:
        return const Color(0xFFECFDF5);
      case 1:
        return const Color(0xFFF0F9FF);
      case 2:
        return const Color(0xFFFFFBEB);
      case 3:
      default:
        return const Color(0xFFF5F3FF);
    }
  }

  List<DayIrrigationSession> _getSessionsForDay(int day) {
    if (_dayOverrides.containsKey(day)) {
      return _dayOverrides[day]!;
    }
    final stage = _getStageForDay(widget.profile, day);
    final duration = stage.requirements.irrigationDurationMin > 0
        ? stage.requirements.irrigationDurationMin
        : 15;
    final freq = stage.requirements.irrigationFrequencyPerDay > 0
        ? stage.requirements.irrigationFrequencyPerDay
        : 2;

    return [
      DayIrrigationSession(
        session: 'MORNING',
        title: 'Ca 1: Tưới gốc buổi sáng',
        startTime: '06:30',
        durationMinutes: duration,
        enabled: true,
        method: 'Tưới nhỏ giọt bù áp',
        volumeMl: duration * 25,
      ),
      DayIrrigationSession(
        session: 'NOON',
        title: 'Ca 2: Phun sương hạ nhiệt trưa',
        startTime: '11:30',
        durationMinutes: 10,
        enabled: freq >= 3,
        method: 'Phun sương hạ nhiệt',
        volumeMl: 250,
      ),
      DayIrrigationSession(
        session: 'AFTERNOON',
        title: 'Ca 3: Tưới bổ sung chiều mát',
        startTime: '16:30',
        durationMinutes: duration,
        enabled: true,
        method: 'Tưới nhỏ giọt bù áp',
        volumeMl: duration * 25,
      ),
    ];
  }

  void _updateDaySessions(int day, List<DayIrrigationSession> sessions) {
    setState(() {
      _dayOverrides[day] = sessions;
    });
    _saveOverrides();
  }

  void _resetDay(int day) {
    setState(() {
      _dayOverrides.remove(day);
    });
    _saveOverrides();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã khôi phục Ngày $day về lịch chuẩn VietGAP!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyToCurrentStage(int day) {
    final stageIdx = _getStageIndexForDay(widget.profile, day);
    final targetStage = widget.profile.growthStages[stageIdx];
    final currentSessions = _getSessionsForDay(day);

    var accumulated = 0;
    for (int i = 0; i < widget.profile.growthStages.length; i++) {
      final s = widget.profile.growthStages[i];
      final start = accumulated + 1;
      final end = accumulated + s.durationDays;
      accumulated = end;

      if (i == stageIdx) {
        for (int d = start; d <= end; d++) {
          _dayOverrides[d] = currentSessions.map((s) => s.copyWith()).toList();
        }
        break;
      }
    }
    setState(() {});
    _saveOverrides();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép lịch tưới Ngày $day cho toàn bộ "${targetStage.name}"!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _applyToAllDays(int day) {
    final totalDays = widget.profile.totalCycleDays > 0 ? widget.profile.totalCycleDays : 30;
    final currentSessions = _getSessionsForDay(day);
    for (int d = 1; d <= totalDays; d++) {
      _dayOverrides[d] = currentSessions.map((s) => s.copyWith()).toList();
    }
    setState(() {});
    _saveOverrides();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã áp dụng lịch tưới Ngày $day cho tất cả $totalDays ngày của vụ mùa!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
      );
    }

    final profile = widget.profile;
    final totalDays = profile.totalCycleDays > 0 ? profile.totalCycleDays : 30;
    final totalMonths = (totalDays / 30).ceil();
    final startDay = (_selectedMonthBlock - 1) * 30 + 1;
    final endDay = (_selectedMonthBlock * 30).clamp(1, totalDays);
    final daysInCurrentBlock = (endDay - startDay + 1);

    final selectedStage = _getStageForDay(profile, _selectedCalendarDay);
    final stageIdx = _getStageIndexForDay(profile, _selectedCalendarDay);
    final stageColor = _getStageColor(stageIdx);
    final stageBgColor = _getStageBgColor(stageIdx);

    final currentSessions = _getSessionsForDay(_selectedCalendarDay);
    final isCustomized = _dayOverrides.containsKey(_selectedCalendarDay);
    final activeSessionsCount = currentSessions.where((s) => s.enabled).length;
    final totalDailyMinutes = currentSessions.where((s) => s.enabled).fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalDailyWaterMl = currentSessions.where((s) => s.enabled).fold<int>(0, (sum, s) => sum + s.volumeMl);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuốn Lịch Tưới VietGAP',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              '${profile.name} (${profile.variety}) • $totalDays ngày',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            tooltip: 'Xem đầy đủ thông số ngày này',
            onPressed: () => _showDayDetailDialog(context, _selectedCalendarDay, selectedStage, currentSessions),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner tóm tắt vụ mùa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF047857).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(profile.emoji.isNotEmpty ? profile.emoji : '🌱', style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'LỊCH TƯỚI CẢ THÁNG & VỤ MÙA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tổng $totalDays ngày',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kế hoạch tưới nước chuẩn VietGAP cho "${profile.name}". Bấm vào từng ngày để xem và chỉnh sửa giờ bắt đầu, thời lượng hoặc bật/tắt từng ca tưới.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFE2E8F0), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statBadge(Icons.water_drop, '$activeSessionsCount ca hoạt động/ngày'),
                      _statBadge(Icons.timer, '$totalDailyMinutes phút tưới/ngày'),
                      _statBadge(Icons.opacity, '${totalDailyWaterMl}ml/gốc/ngày'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bộ chọn tháng canh tác (nếu chu kỳ > 30 ngày)
            if (totalMonths > 1) ...[
              const Text(
                'CHỌN THÁNG CANH TÁC',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(totalMonths, (mIdx) {
                    final blockNum = mIdx + 1;
                    final isCurrentBlock = _selectedMonthBlock == blockNum;
                    final bStart = (blockNum - 1) * 30 + 1;
                    final bEnd = (blockNum * 30).clamp(1, totalDays);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          'Tháng $blockNum (Ngày $bStart – $bEnd)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isCurrentBlock ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentBlock ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        selected: isCurrentBlock,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isCurrentBlock ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedMonthBlock = blockNum;
                              if (_selectedCalendarDay < bStart || _selectedCalendarDay > bEnd) {
                                _selectedCalendarDay = bStart;
                              }
                            });
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Lưới ngày trong tháng (Calendar Grid)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'LƯỚI NGÀY TRONG THÁNG (NGÀY $startDay – $endDay)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Nhấn để xem & sửa',
                  style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: daysInCurrentBlock,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 0.85,
                ),
                itemBuilder: (context, idx) {
                  final dayNum = startDay + idx;
                  final isSelected = dayNum == _selectedCalendarDay;
                  final dStageIdx = _getStageIndexForDay(profile, dayNum);
                  final dColor = _getStageColor(dStageIdx);
                  final dBg = _getStageBgColor(dStageIdx);
                  final dSessions = _getSessionsForDay(dayNum);
                  final dActiveCount = dSessions.where((s) => s.enabled).length;
                  final dCustomized = _dayOverrides.containsKey(dayNum);

                  return InkWell(
                    onTap: () => setState(() => _selectedCalendarDay = dayNum),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF064E3B) : dBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF10B981) : dColor.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'N$dayNum',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Icon(
                                  Icons.water_drop,
                                  size: 13,
                                  color: isSelected ? const Color(0xFF34D399) : dColor,
                                ),
                                Text(
                                  '$dActiveCount ca',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? const Color(0xFFE2E8F0) : dColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (dCustomized)
                            Positioned(
                              top: 3,
                              right: 3,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Card chi tiết và chỉnh sửa ngày được chọn
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: stageColor.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: stageColor.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: stageBgColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                selectedStage.iconEmoji.isNotEmpty ? selectedStage.iconEmoji : '🌱',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'LỊCH TƯỚI NGÀY $_selectedCalendarDay',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCustomized) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                                          ),
                                          child: const Text('Đã tùy chỉnh', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    selectedStage.name,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stageColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, color: Color(0xFF0284C7), size: 20),
                        tooltip: 'Chỉnh sửa ca tưới',
                        onPressed: () => _showEditDayBottomSheet(context, _selectedCalendarDay, selectedStage),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Thanh tóm tắt thông số ngày
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Độ ẩm đất mục tiêu: ${selectedStage.requirements.soilMoistureMin.toInt()}% – ${selectedStage.requirements.soilMoistureMax.toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tổng: $totalDailyMinutes phút (${totalDailyWaterMl}ml)',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CÁC CA TƯỚI TRONG NGÀY',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.edit, size: 13, color: Color(0xFF0284C7)),
                        label: const Text('Sửa lịch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        onPressed: () => _showEditDayBottomSheet(context, _selectedCalendarDay, selectedStage),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Danh sách từng ca tưới
                  ...currentSessions.map((s) => _buildInteractiveSessionRow(s)),

                  const SizedBox(height: 14),

                  // Các nút tác vụ nhanh
                  Row(
                    children: [
                      if (isCustomized) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.restore, size: 14),
                            label: const Text('Khôi phục chuẩn', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _resetDay(_selectedCalendarDay),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_all, size: 14),
                          label: const Text('Áp dụng cả giai đoạn', style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _applyToCurrentStage(_selectedCalendarDay),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Ghi chú nông học VietGAP
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, size: 15, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedStage.description.isNotEmpty
                                ? 'Quy chuẩn VietGAP: ${selectedStage.description}'
                                : 'Quy chuẩn VietGAP: Hệ thống tự động hoãn ca tưới nếu xác suất mưa ≥ 70% hoặc độ ẩm đất đo được vượt ngưỡng an toàn.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF166534), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveSessionRow(DayIrrigationSession s) {
    final iconColor = s.session == 'MORNING'
        ? const Color(0xFFF59E0B)
        : s.session == 'NOON'
            ? const Color(0xFFEF4444)
            : const Color(0xFF6366F1);

    final iconData = s.session == 'MORNING'
        ? Icons.wb_sunny_outlined
        : s.session == 'NOON'
            ? Icons.cloud_outlined
            : Icons.nights_stay_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: s.enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.enabled ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: s.enabled ? 0.12 : 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(iconData, size: 18, color: s.enabled ? iconColor : Colors.grey),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: s.enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        decoration: s.enabled ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      s.enabled ? '${s.durationMinutes} phút' : 'Đã tắt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: s.enabled ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      s.startTime,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: s.enabled ? iconColor : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '• ${s.method} (${s.volumeMl}ml)',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Switch(
            value: s.enabled,
            activeThumbColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            onChanged: (val) {
              final sessions = _getSessionsForDay(_selectedCalendarDay);
              final updated = sessions.map((item) {
                if (item.session == s.session) {
                  return item.copyWith(enabled: val);
                }
                return item;
              }).toList();
              _updateDaySessions(_selectedCalendarDay, updated);
            },
          ),
        ],
      ),
    );
  }

  void _showEditDayBottomSheet(BuildContext context, int day, GrowthStageProfile stage) {
    final sessions = _getSessionsForDay(day).map((s) => s.copyWith()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chỉnh Sửa Ca Tưới - Ngày $day',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                stage.name,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),

                    ...sessions.map((s) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  s.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                                Switch(
                                  value: s.enabled,
                                  activeThumbColor: const Color(0xFF10B981),
                                  onChanged: (val) {
                                    setModalState(() => s.enabled = val);
                                  },
                                ),
                              ],
                            ),
                            if (s.enabled) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final parts = s.startTime.split(':');
                                        final initialHour = int.tryParse(parts[0]) ?? 7;
                                        final initialMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                                        final picked = await showTimePicker(
                                          context: modalCtx,
                                          initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
                                        );
                                        if (picked != null) {
                                          final h = picked.hour.toString().padLeft(2, '0');
                                          final m = picked.minute.toString().padLeft(2, '0');
                                          setModalState(() => s.startTime = '$h:$m');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 16, color: Color(0xFF0284C7)),
                                            const SizedBox(width: 6),
                                            Text('Giờ: ${s.startTime}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF059669)),
                                          const SizedBox(width: 6),
                                          Text('${s.durationMinutes} phút', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Text('Thời lượng: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  Expanded(
                                    child: Slider(
                                      value: s.durationMinutes.toDouble().clamp(5, 30),
                                      min: 5,
                                      max: 30,
                                      divisions: 25,
                                      activeColor: const Color(0xFF10B981),
                                      onChanged: (v) {
                                        setModalState(() {
                                          s.durationMinutes = v.toInt();
                                          s.volumeMl = s.durationMinutes * 25;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              _updateDaySessions(day, sessions);
                              Navigator.pop(modalCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã lưu cấu hình ca tưới cho Ngày $day!'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: const Text('Lưu Ngày Này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              _updateDaySessions(day, sessions);
                              _applyToCurrentStage(day);
                              Navigator.pop(modalCtx);
                            },
                            child: const Text('Lưu Giai Đoạn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF064E3B),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              _updateDaySessions(day, sessions);
                              _applyToAllDays(day);
                              Navigator.pop(modalCtx);
                            },
                            child: const Text('Lưu Cả Vụ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDayDetailDialog(BuildContext context, int day, GrowthStageProfile stage, List<DayIrrigationSession> sessions) {
    final activeCount = sessions.where((s) => s.enabled).length;
    final totalMinutes = sessions.where((s) => s.enabled).fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalWaterMl = sessions.where((s) => s.enabled).fold<int>(0, (sum, s) => sum + s.volumeMl);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Text(stage.iconEmoji.isNotEmpty ? stage.iconEmoji : '🌱', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi Tiết Ngày $day / ${widget.profile.totalCycleDays}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(stage.name, style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogInfoRow('Số ca tưới:', '$activeCount ca kích hoạt'),
                _dialogInfoRow('Tổng thời lượng:', '$totalMinutes phút/ngày'),
                _dialogInfoRow('Tổng lượng nước:', '${totalWaterMl}ml/gốc/ngày'),
                _dialogInfoRow('Độ ẩm đất yêu cầu:', '${stage.requirements.soilMoistureMin.toInt()}% – ${stage.requirements.soilMoistureMax.toInt()}%'),
                _dialogInfoRow('Nhiệt độ tối ưu:', '${stage.requirements.tempMin.toInt()}°C – ${stage.requirements.tempMax.toInt()}°C'),
                _dialogInfoRow('Độ ẩm không khí:', '${stage.requirements.humidityMin.toInt()}% – ${stage.requirements.humidityMax.toInt()}%'),
                const Divider(height: 16),
                const Text('Hoạt động chăm sóc khuyến nghị:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                if (stage.keyActivities.isNotEmpty)
                  ...stage.keyActivities.map((act) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $act', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  ))
                else
                  const Text('• Duy trì độ ẩm đất ổn định, theo dõi dự báo thời tiết trước các ca tưới.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _showEditDayBottomSheet(context, day, stage);
              },
              child: const Text('Chỉnh Sửa Ca'),
            ),
          ],
        );
      },
    );
  }

  Widget _dialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
