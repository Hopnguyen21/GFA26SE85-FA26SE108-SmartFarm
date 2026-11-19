import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../zones/profile_irrigation_logic.dart';
import '../../core/utils/user_error.dart';

part 'parts/irrigation_calendar_screen_logic.dart';
part 'parts/irrigation_calendar_screen_session_row.dart';
part 'parts/irrigation_calendar_screen_edit_day.dart';
part 'parts/irrigation_calendar_screen_day_detail.dart';

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

  factory DayIrrigationSession.fromJson(Map<String, dynamic> json) =>
      DayIrrigationSession(
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
  State<IrrigationCalendarScreen> createState() =>
      _IrrigationCalendarScreenState();
}

class _IrrigationCalendarScreenState extends State<IrrigationCalendarScreen> {
  /// Cho phép code trong các file part (extension) cập nhật state.
  void _rebuild(VoidCallback fn) => setState(fn);

  int _selectedCalendarDay = 1;
  String _stageFilter =
      'ALL'; // 'ALL' hoặc chỉ số giai đoạn của hồ sơ (như bộ lọc giai đoạn của web)
  // Lịch tưới lấy từ backend theo giai đoạn của hồ sơ (không lưu cục bộ).
  ProfileSchedule? _schedule;
  String? _loadError;
  bool _isLoaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  static const _sessionDotColors = [
    Color(0xFFF59E0B),
    Color(0xFFF43F5E),
    Color(0xFF6366F1),
    Color(0xFF14B8A6),
    Color(0xFF8B5CF6),
  ];

  /// Ô một ngày trong lưới (như web): số ngày, dấu "đã lưu trong hồ sơ", chấm theo ca đang bật và tên giai đoạn.
  Widget _profileDayCell(DefaultCropProfile profile, int dayNum) {
    final selected = dayNum == _selectedCalendarDay;
    final stageIdx = _getStageIndexForDay(profile, dayNum);
    final color = _getStageColor(stageIdx);
    final sessions = _getSessionsForDay(dayNum);
    final saved = _isStageSavedInProfile(dayNum);
    final stageName = profile.growthStages[stageIdx].name;
    return InkWell(
      key: ValueKey('profile_day_$dayNum'),
      onTap: () => setState(() => _selectedCalendarDay = dayNum),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 68,
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'N$dayNum',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? const Color(0xFF065F46)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (saved)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (var i = 0; i < sessions.length && i < 5; i++)
                  if (sessions[i].enabled)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _sessionDotColors[i % _sessionDotColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              stageName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          title: const Text(
            'Lịch tưới',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Không tải được lịch tưới của hồ sơ: $_loadError',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadSchedule,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (widget.profile.growthStages.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          title: const Text(
            'Lịch tưới',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Hồ sơ này chưa có giai đoạn nào nên chưa có lịch tưới.',
            ),
          ),
        ),
      );
    }
    final profile = widget.profile;
    final totalDays = profile.totalCycleDays > 0 ? profile.totalCycleDays : 30;
    final visibleDays = <int>[
      for (var d = 1; d <= totalDays; d++)
        if (_stageFilter == 'ALL' ||
            _getStageIndexForDay(profile, d).toString() == _stageFilter)
          d,
    ];

    final selectedStage = _getStageForDay(profile, _selectedCalendarDay)!;
    final stageIdx = _getStageIndexForDay(profile, _selectedCalendarDay);
    final stageColor = _getStageColor(stageIdx);
    final stageBgColor = _getStageBgColor(stageIdx);

    final currentSessions = _getSessionsForDay(_selectedCalendarDay);
    final isCustomized = _isStageSavedInProfile(_selectedCalendarDay);
    final activeSessionsCount = currentSessions.where((s) => s.enabled).length;
    final totalDailyMinutes = currentSessions
        .where((s) => s.enabled)
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
    final totalDailyWaterMl = currentSessions
        .where((s) => s.enabled)
        .fold<int>(0, (sum, s) => sum + s.volumeMl);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        bottom: _saving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cuốn Lịch Tưới VietGAP',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
            onPressed: () => _showDayDetailDialog(
              context,
              _selectedCalendarDay,
              selectedStage,
              currentSessions,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thẻ tiêu đề như web: tên lịch, hồ sơ cây, tiến trình và chế độ sửa
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFF0FDFA), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cuốn Lịch Tưới 3 Ca ($totalDays Ngày Canh Tác)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${profile.name}${profile.variety.isNotEmpty ? ' (${profile.variety})' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hiển thị tiến trình Ngày 1 đến Ngày $totalDays theo các giai đoạn của hồ sơ. Các ngày cùng giai đoạn dùng chung ca tưới; chạm một ngày để xem và chỉnh giờ bắt đầu, thời lượng hoặc bật/tắt từng ca.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _statBadge(
                        Icons.water_drop,
                        '$activeSessionsCount ca hoạt động/ngày',
                      ),
                      _statBadge(
                        Icons.timer,
                        '$totalDailyMinutes phút tưới/ngày',
                      ),
                      _statBadge(
                        Icons.opacity,
                        '${totalDailyWaterMl}ml/gốc/ngày',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _canEditSchedule
                              ? Icons.verified_user
                              : Icons.lock_outline,
                          size: 13,
                          color: const Color(0xFF047857),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _canEditSchedule
                                ? 'Hồ sơ riêng của trang trại • chỉnh được, không đổi thư viện gốc'
                                : 'Hồ sơ hệ thống • chỉ xem',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tổng quan các giai đoạn của hồ sơ (chạm để lọc lưới ngày, như web)
            const Text(
              'GIAI ĐOẠN SINH TRƯỞNG',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: profile.growthStages.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.0,
              ),
              itemBuilder: (context, i) {
                final st = profile.growthStages[i];
                final from = profile.growthStages
                    .take(i)
                    .fold<int>(1, (sum, x) => sum + x.durationDays);
                final to = from + st.durationDays - 1;
                final color = _getStageColor(i);
                final selected = _stageFilter == '$i';
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () =>
                      setState(() => _stageFilter = selected ? 'ALL' : '$i'),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _getStageBgColor(i),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? color : color.withValues(alpha: 0.35),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Giai đoạn ${i + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Ngày $from - $to',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: color.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          st.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Bộ lọc và chú thích
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text(
                    'Tất cả ($totalDays ngày)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _stageFilter == 'ALL'
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  selected: _stageFilter == 'ALL',
                  selectedColor: const Color(0xFF0F172A),
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _stageFilter = 'ALL'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (var i = 0; i < 3; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _sessionDotColors[i],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ca ${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Đã lưu trong hồ sơ',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Lưới các ngày của cả chu kỳ (lọc theo giai đoạn)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF047857), Color(0xFF0D9488)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(17),
                        topRight: Radius.circular(17),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'LƯỚI LỊCH TƯỚI $totalDays NGÀY',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${visibleDays.length} / $totalDays ngày',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final dayNum in visibleDays)
                          _profileDayCell(profile, dayNum),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card chi tiết và chỉnh sửa ngày được chọn
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: stageColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
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
                                selectedStage.iconEmoji.isNotEmpty
                                    ? selectedStage.iconEmoji
                                    : '🌱',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 2,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Chi tiết Lịch Tưới Ngày $_selectedCalendarDay',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isCustomized) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: const Text(
                                            'ĐÃ LƯU TRONG HỒ SƠ',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    selectedStage.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: stageColor,
                                    ),
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
                        icon: const Icon(
                          Icons.tune,
                          color: Color(0xFF0284C7),
                          size: 20,
                        ),
                        tooltip: 'Chỉnh sửa ca tưới',
                        onPressed: () => _showEditDayBottomSheet(
                          context,
                          _selectedCalendarDay,
                          selectedStage,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Thanh tóm tắt thông số ngày
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tổng: $totalDailyMinutes phút (${totalDailyWaterMl}ml)',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'CÁC CA TƯỚI TRONG NGÀY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(
                          Icons.edit,
                          size: 13,
                          color: Color(0xFF0284C7),
                        ),
                        label: const Text(
                          'Sửa lịch',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        onPressed: () => _showEditDayBottomSheet(
                          context,
                          _selectedCalendarDay,
                          selectedStage,
                        ),
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
                      ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text(
                              'Tải lại từ máy chủ',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFCA5A5)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _loadSchedule,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_all, size: 14),
                          label: const Text(
                            'Áp dụng cả giai đoạn',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFFBAE6FD)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () =>
                              _applyToCurrentStage(_selectedCalendarDay),
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
                        const Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedStage.description.isNotEmpty
                                ? 'Quy chuẩn VietGAP: ${selectedStage.description}'
                                : 'Quy chuẩn VietGAP: Hệ thống tự động hoãn ca tưới nếu xác suất mưa ≥ ${BusinessParameters.fmt(BusinessParametersStore.current.rainGuardThresholdPercent)}% hoặc độ ẩm đất đo được vượt ngưỡng an toàn.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF166534),
                              height: 1.3,
                            ),
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
}
