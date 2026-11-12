import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../zones/profile_irrigation_logic.dart';

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
  int _selectedMonthBlock = 1; // 1 = Ngày 1-30, 2 = Ngày 31-60, 3 = Ngày 61+
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
        appBar: AppBar(title: const Text('Lịch tưới')),
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
        appBar: AppBar(title: const Text('Lịch tưới')),
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
    final totalMonths = (totalDays / 30).ceil();
    final startDay = (_selectedMonthBlock - 1) * 30 + 1;
    final endDay = (_selectedMonthBlock * 30).clamp(1, totalDays);
    final daysInCurrentBlock = (endDay - startDay + 1);

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
                            Text(
                              profile.emoji.isNotEmpty ? profile.emoji : '🌱',
                              style: const TextStyle(fontSize: 22),
                            ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tổng $totalDays ngày',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kế hoạch tưới nước chuẩn VietGAP cho "${profile.name}". Bấm vào từng ngày để xem và chỉnh sửa giờ bắt đầu, thời lượng hoặc bật/tắt từng ca tưới.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE2E8F0),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bộ chọn tháng canh tác (nếu chu kỳ > 30 ngày)
            if (totalMonths > 1) ...[
              const Text(
                'CHỌN THÁNG CANH TÁC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
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
                            fontWeight: isCurrentBlock
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isCurrentBlock
                                ? Colors.white
                                : const Color(0xFF334155),
                          ),
                        ),
                        selected: isCurrentBlock,
                        selectedColor: const Color(0xFF10B981),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isCurrentBlock
                                ? const Color(0xFF10B981)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedMonthBlock = blockNum;
                              if (_selectedCalendarDay < bStart ||
                                  _selectedCalendarDay > bEnd) {
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Nhấn để xem & sửa',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
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
                  final dCustomized = _isStageSavedInProfile(dayNum);

                  return InkWell(
                    onTap: () => setState(() => _selectedCalendarDay = dayNum),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF064E3B) : dBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : dColor.withValues(alpha: 0.3),
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
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Icon(
                                  Icons.water_drop,
                                  size: 13,
                                  color: isSelected
                                      ? const Color(0xFF34D399)
                                      : dColor,
                                ),
                                Text(
                                  '$dActiveCount ca',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFFE2E8F0)
                                        : dColor,
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
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'LỊCH TƯỚI NGÀY $_selectedCalendarDay',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCustomized) ...[
                                        const SizedBox(width: 6),
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
                                            'Lưu trong hồ sơ',
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
                        Text(
                          'Tổng: $totalDailyMinutes phút (${totalDailyWaterMl}ml)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
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
                                : 'Quy chuẩn VietGAP: Hệ thống tự động hoãn ca tưới nếu xác suất mưa ≥ 70% hoặc độ ẩm đất đo được vượt ngưỡng an toàn.',
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
