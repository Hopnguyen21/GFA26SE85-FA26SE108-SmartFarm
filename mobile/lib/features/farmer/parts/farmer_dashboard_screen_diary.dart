part of '../farmer_dashboard_screen.dart';

extension _FarmerDashboardScreenStateDiary on _FarmerDashboardScreenState {
  // ─── TAB 3A: DIARY (CAN_LOG_DIARY) ─────────────────────────────────────────
  Widget _buildDiaryTab(
    BuildContext context,
    FarmProvider provider,
    List<ZoneModel> zones,
    FarmerModel? farmer,
  ) {
    if (_selectedZoneForDiary.isEmpty && zones.isNotEmpty) {
      _selectedZoneForDiary = zones.first.name;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Diary Button
          if (!_showAddDiaryForm)
            GestureDetector(
              onTap: () => _rebuild(() => _showAddDiaryForm = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF065F46).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ghi Nhật Ký Canh Tác Hôm Nay',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildAddDiaryForm(context, zones),

          const Text(
            'NHẬT KÝ CANH TÁC GẦN ĐÂY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Lưu ý: nhật ký chỉ lưu tạm trên thiết bị này (máy chủ chưa có API nhật ký), sẽ mất khi đóng ứng dụng.',
              style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
            ),
          ),
          if (_diaryEntries.isEmpty)
            _buildEmptyState(
              'Chưa có nhật ký nào. Hãy ghi lại hoạt động hôm nay!',
              Icons.book_outlined,
            )
          else
            ..._diaryEntries.map((entry) => _buildDiaryCard(entry)),
        ],
      ),
    );
  }

  Widget _buildAddDiaryForm(BuildContext context, List<ZoneModel> zones) {
    final activities = [
      'Tưới nước',
      'Bón phân',
      'Phun thuốc',
      'Kiểm tra sâu bệnh',
      'Thu hoạch',
      'Làm đất',
      'Khác',
    ];

    return StatefulBuilder(
      builder: (context, setFormState) {
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6EE7B7), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Ghi Nhật Ký Mới',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Zone selector
              if (zones.isNotEmpty) ...[
                const Text(
                  'Khu vực:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedZoneForDiary.isEmpty
                      ? zones.first.name
                      : _selectedZoneForDiary,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF0FDF4),
                  ),
                  items: zones
                      .map(
                        (z) => DropdownMenuItem(
                          value: z.name,
                          child: Text(
                            z.name.split(' - ').first,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      _rebuild(() => _selectedZoneForDiary = v ?? ''),
                ),
                const SizedBox(height: 10),
              ],

              // Activity selector
              const Text(
                'Hoạt động:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: activities.map((a) {
                  final selected = _selectedActivity == a;
                  return GestureDetector(
                    onTap: () => _rebuild(() => _selectedActivity = a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF065F46)
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF065F46)
                              : const Color(0xFFD1FAE5),
                        ),
                      ),
                      child: Text(
                        a,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Note
              const Text(
                'Ghi chú:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _diaryNoteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Mô tả hoạt động, tình trạng cây trồng...',
                  hintStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD1FAE5)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  filled: true,
                  fillColor: const Color(0xFFF0FDF4),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rebuild(() {
                        _showAddDiaryForm = false;
                        _diaryNoteController.clear();
                      }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF065F46)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Color(0xFF065F46)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_diaryNoteController.text.isNotEmpty) {
                          _rebuild(() {
                            _diaryEntries.insert(
                              0,
                              _DiaryEntry(
                                id: 'd-${_diaryEntries.length + 1}',
                                date: DateTime.now(),
                                zone: _selectedZoneForDiary,
                                activity: _selectedActivity,
                                note: _diaryNoteController.text,
                                weather: 'Không rõ',
                                icon: _activityIcon(_selectedActivity),
                              ),
                            );
                            _showAddDiaryForm = false;
                            _diaryNoteController.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ℹ️ Đã lưu nhật ký vào phiên làm việc (lưu tạm trên máy, chưa đồng bộ lên máy chủ do chưa có API).',
                              ),
                              backgroundColor: Color(0xFF0F766E),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF065F46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Lưu Nhật Ký',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiaryCard(_DiaryEntry entry) {
    final diff = DateTime.now().difference(entry.date);
    final timeAgo = diff.inDays == 0
        ? 'Hôm nay'
        : diff.inDays == 1
        ? 'Hôm qua'
        : '${diff.inDays} ngày trước';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(entry.icon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.activity,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      entry.zone.split(' - ').first,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'Lưu tạm phiên (chưa đồng bộ server)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.date.day}/${entry.date.month}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.note,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TAB 3B: REPORTS VIEW (khi không có CAN_LOG_DIARY) ─────────────────────
  Widget _buildReportsViewTab(
    BuildContext context,
    FarmProvider provider,
    bool canViewReports,
  ) {
    if (!canViewReports) {
      return _buildAccessDenied(
        'Bạn không có quyền xem báo cáo. Liên hệ Owner để được cấp quyền.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BÁO CÁO TÓM TẮT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF065F46),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _summaryReportCard(),
        ],
      ),
    );
  }

  Widget _summaryReportCard() {
    // Chỉ số liệu có thật trong ứng dụng; lượng nước và giờ bơm chưa có nguồn nên không hiển thị.
    final tasks = context.read<FarmProvider>().tasks;
    final doneTasks = tasks.where((t) => t.isCompleted).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng quan công việc',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...[
            ('✅ Tác vụ đã hoàn thành', '$doneTasks/${tasks.length} tác vụ'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                    ),
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
