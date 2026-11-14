part of '../farmer_dashboard_screen.dart';

/// Trạng thái phân công của chính Nông dân (backend chỉ trả phần việc của họ); thiếu thì dùng trạng thái công việc.
String _myStatus(TaskModel t) =>
    t.assignments.isNotEmpty ? t.assignments.first.status : t.status;

const _todoStatuses = {
  'Pending',
  'Accepted',
  'InProgress',
  'Overdue',
  'Failed',
};

bool _matches(_TaskFilter f, TaskModel t) {
  final s = _myStatus(t);
  switch (f) {
    case _TaskFilter.all:
      return true;
    case _TaskFilter.review:
      return s == 'CompletedPendingReview';
    case _TaskFilter.done:
      return s == 'Approved' || s == 'Declined' || s == 'Cancelled';
    case _TaskFilter.todo:
      return _todoStatuses.contains(s);
  }
}

/// Việc còn phải làm mà đã quá hạn (trạng thái Overdue hoặc hạn chót đã qua).
bool _isOverdue(TaskModel t) {
  final s = _myStatus(t);
  if (!_todoStatuses.contains(s) || s == 'Failed') return false;
  return s == 'Overdue' || dueLabel(t.dueAtUtc).tone == DueTone.late;
}

List<TaskModel> _sortedTasks(List<TaskModel> tasks) {
  final list = [...tasks];
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  list.sort((a, b) => (a.dueAtUtc ?? epoch).compareTo(b.dueAtUtc ?? epoch));
  return list;
}

const _statusChip = <String, (String, Color, Color)>{
  'Pending': ('Chờ nhận việc', Color(0xFFFEF3C7), Color(0xFF78350F)),
  'Accepted': ('Đã nhận việc', Color(0xFFE0F2FE), Color(0xFF0C4A6E)),
  'InProgress': ('Đang thực hiện', Color(0xFFD1FAE5), Color(0xFF064E3B)),
  'CompletedPendingReview': (
    'Chờ chủ duyệt',
    Color(0xFFEDE9FE),
    Color(0xFF4C1D95),
  ),
  'Approved': ('✓ Đã duyệt', Color(0xFFD1FAE5), Color(0xFF064E3B)),
  'Failed': ('Bạn báo không hoàn thành', Color(0xFFFFE4E6), Color(0xFF881337)),
  'Declined': ('Bạn đã từ chối', Color(0xFFFFE4E6), Color(0xFF881337)),
  'Cancelled': ('Đã gỡ khỏi công việc', Color(0xFFF1F5F9), Color(0xFF475569)),
};

extension _FarmerDashboardTasks on _FarmerDashboardScreenState {
  Widget _buildTaskManager(
    FarmProvider provider,
    List<TaskModel> all,
    int todoCount,
    int reviewCount,
    List<TaskModel> shown,
  ) {
    final doneCount = all.where((t) => _matches(_TaskFilter.done, t)).length;
    final counts = {
      _TaskFilter.todo: todoCount,
      _TaskFilter.review: reviewCount,
      _TaskFilter.done: doneCount,
      _TaskFilter.all: all.length,
    };
    const labels = {
      _TaskFilter.todo: 'Cần làm',
      _TaskFilter.review: 'Chờ duyệt',
      _TaskFilter.done: 'Đã duyệt',
      _TaskFilter.all: 'Tất cả',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionBadge('TASK WORKSPACE'),
          const SizedBox(height: 6),
          const Text(
            'Công việc Thực địa của Nông dân',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Bạn có thể nhận việc, cập nhật tiến độ và nộp kết quả trực tiếp cho chủ trang trại kiểm duyệt.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  for (final f in _TaskFilter.values)
                    GestureDetector(
                      onTap: () => _rebuild(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _filter == f ? Colors.white : null,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          '${labels[f]} (${counts[f]})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _filter == f
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 32,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Không có công việc nào trong mục này',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _filter == _TaskFilter.todo
                        ? 'Tuyệt vời! Bạn đã hoàn thành hết các công việc được giao.'
                        : 'Hãy chọn bộ lọc khác để xem danh sách công việc.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final t in shown) _taskCard(provider, t),
        ],
      ),
    );
  }

  Widget _taskCard(FarmProvider provider, TaskModel t) {
    final due = dueLabel(t.dueAtUtc);
    final status = _myStatus(t);
    final overdue = _isOverdue(t);
    final review = status == 'CompletedPendingReview';
    final chip = _statusChip[status];
    final (dueBg, dueFg) = switch (due.tone) {
      DueTone.late => (const Color(0xFFFFE4E6), const Color(0xFF9F1239)),
      DueTone.today => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      DueTone.soon => (const Color(0xFFE0F2FE), const Color(0xFF075985)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };
    final canComplete = status == 'InProgress' || status == 'Overdue';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue
            ? const Color(0xFFFFF1F2)
            : review
            ? const Color(0xFFFFFBEB)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue
              ? const Color(0xFFFDA4AF)
              : review
              ? const Color(0xFFFCD34D)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: dueBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  due.text,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: dueFg,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_outlined, size: 12, color: _kGreen),
                  const SizedBox(width: 2),
                  Text(
                    t.zoneName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              if (t.createdAtUtc != null)
                Text(
                  '${t.createdAtUtc!.toLocal().day.toString().padLeft(2, '0')}/'
                  '${t.createdAtUtc!.toLocal().month.toString().padLeft(2, '0')}/'
                  '${t.createdAtUtc!.toLocal().year}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          if ((t.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
          const Divider(height: 18),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (chip != null)
                _chip(chip.$1, chip.$2, chip.$3)
              else
                _chip(status, const Color(0xFFF1F5F9), const Color(0xFF475569)),
              if (overdue)
                _chip(
                  'Quá hạn',
                  const Color(0xFFFFE4E6),
                  const Color(0xFF881337),
                ),
              if (status == 'Pending')
                FilledButton.icon(
                  onPressed: () => _quickAction(provider, t, 'Accept'),
                  style: _btn(),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Nhận việc'),
                ),
              if (status == 'Accepted')
                FilledButton.icon(
                  onPressed: () => _quickAction(provider, t, 'Start'),
                  style: _btn(),
                  icon: const Icon(Icons.play_arrow, size: 15),
                  label: const Text('Bắt đầu làm'),
                ),
              if (canComplete)
                FilledButton.icon(
                  onPressed: () => _completeDialog(provider, t),
                  style: _btn(),
                  icon: const Icon(Icons.send, size: 13),
                  label: const Text('Nộp kết quả'),
                ),
              TextButton(
                onPressed: () => _openAlertsTasks(2),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                ),
                child: const Text('Chi tiết ➔', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _btn() => FilledButton.styleFrom(
    backgroundColor: _kGreen,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
  );

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
    ),
  );

  Future<void> _quickAction(
    FarmProvider provider,
    TaskModel t,
    String action,
  ) async {
    final error = await provider.performTaskAction(t.taskId, action);
    if (!mounted) return;
    _rebuild(
      () => _feedback = error == null
          ? (
              ok: true,
              message: action == 'Accept'
                  ? 'Đã nhận việc thành công!'
                  : 'Đã bắt đầu công việc!',
            )
          : (ok: false, message: error),
    );
  }

  /// Nộp kết quả: để trống thì dùng câu mặc định như web.
  Future<void> _completeDialog(FarmProvider provider, TaskModel t) async {
    final ctrl = TextEditingController();
    var submitting = false;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Nộp Kết Quả Công Việc Thực Địa',
            style: TextStyle(fontSize: 15),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        (t.description ?? '').isNotEmpty
                            ? t.description!
                            : 'Kiểm tra và thực hiện công việc được giao tại khu vực.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      Text(
                        t.zoneName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Mô tả kết quả đã làm & Ghi chú thực địa:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Ví dụ: Đã kiểm tra xong toàn bộ đầu vòi phun sương, phát hiện 1 vòi nghẹt đã vệ sinh sạch...',
                    hintStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Hủy bỏ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kGreen),
              onPressed: submitting
                  ? null
                  : () async {
                      setLocal(() => submitting = true);
                      final text = ctrl.text.trim().isEmpty
                          ? 'Hoàn thành công việc theo quy trình thực địa.'
                          : ctrl.text.trim();
                      final error = await provider.performTaskAction(
                        t.taskId,
                        'Complete',
                        result: text,
                      );
                      if (error == null) {
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } else {
                        setLocal(() => submitting = false);
                        if (mounted) {
                          _rebuild(
                            () => _feedback = (ok: false, message: error),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      }
                    },
              child: Text(submitting ? 'Đang gửi...' : 'Xác nhận Nộp Kết Quả'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (submitted == true && mounted) {
      _rebuild(
        () => _feedback = (
          ok: true,
          message:
              'Đã nộp kết quả công việc! Chờ chủ trang trại kiểm tra và phê duyệt.',
        ),
      );
    }
  }
}
