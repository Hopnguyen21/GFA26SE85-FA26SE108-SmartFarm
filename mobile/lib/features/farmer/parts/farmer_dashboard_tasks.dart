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
  'Pending': ('Chờ bạn nhận việc', Color(0xFFFEF3C7), Color(0xFF78350F)),
  'Accepted': ('Đã nhận việc', Color(0xFFE0F2FE), Color(0xFF0C4A6E)),
  'InProgress': ('Đang thực hiện', Color(0xFFE0F2FE), Color(0xFF0C4A6E)),
  'CompletedPendingReview': (
    'Đã nộp, chờ chủ trang trại duyệt',
    Color(0xFFEDE9FE),
    Color(0xFF4C1D95),
  ),
  'Approved': ('Đã được duyệt', Color(0xFFD1FAE5), Color(0xFF064E3B)),
  'Failed': ('Bạn báo không hoàn thành', Color(0xFFFFE4E6), Color(0xFF881337)),
  'Overdue': ('Chưa hoàn thành', Color(0xFFFEF3C7), Color(0xFF78350F)),
  'Cancelled': ('Đã gỡ khỏi công việc', Color(0xFFF1F5F9), Color(0xFF475569)),
  'Declined': ('Bạn đã từ chối', Color(0xFFFFE4E6), Color(0xFF881337)),
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
          _sectionBadge('KHÔNG GIAN CÔNG VIỆC'),
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
            'Bạn có thể nhận việc và nộp kết quả trực tiếp cho chủ trang trại kiểm duyệt.',
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
                    Semantics(
                      button: true,
                      selected: _filter == f,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _rebuild(() => _filter = f),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _filter == f ? Colors.white : null,
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: _filter == f
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
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
    final mine = t.assignments.isNotEmpty ? t.assignments.first : null;
    final (dueBg, dueFg) = switch (due.tone) {
      DueTone.late => (const Color(0xFFFFE4E6), const Color(0xFF9F1239)),
      DueTone.today => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      DueTone.soon => (const Color(0xFFE0F2FE), const Color(0xFF075985)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    };
    final canComplete = status == 'InProgress' || status == 'Overdue';
    final showProgress = [
      'Accepted',
      'InProgress',
      'CompletedPendingReview',
      'Approved',
    ].contains(status);
    final pct = mine?.progressPercent ?? (status == 'Approved' ? 100 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
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
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
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
                  const Icon(Icons.place_outlined, size: 13, color: _kGreen),
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
          if ((t.requirements ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Yêu cầu: ${t.requirements!}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showProgress) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100.0,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF119653),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
          if ((mine?.progressNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Ghi chú tiến độ: ${mine!.progressNote!}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
          if ((mine?.result ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                'Kết quả đã nộp: ${mine!.result!}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ],
          if (mine != null && mine.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 14,
                  color: Color(0xFF047857),
                ),
                const SizedBox(width: 4),
                Text(
                  'Ảnh báo cáo thực địa (${mine.imageUrls.length} ảnh):',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mine.imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (ctx, idx) {
                  final url = mine.imageUrls[idx];
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(url, fit: BoxFit.contain),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 52,
                        height: 52,
                        cacheWidth: 104,
                        cacheHeight: 104,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 52,
                          height: 52,
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(
                            Icons.broken_image_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if ((mine?.failureReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                'Lý do: ${mine!.failureReason!}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBE123C),
                ),
              ),
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
              if (overdue && status != 'Overdue')
                _chip(
                  'Quá hạn',
                  const Color(0xFFFFE4E6),
                  const Color(0xFF881337),
                ),
              if (status == 'Pending') ...[
                FilledButton.icon(
                  onPressed: () => _quickAction(provider, t, 'Accept'),
                  style: _btn(bg: const Color(0xFF0284C7)),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Nhận việc'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _declineDialog(provider, t),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text(
                    'Từ chối',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if (status == 'Accepted') ...[
                FilledButton.icon(
                  onPressed: () => _quickAction(provider, t, 'Start'),
                  style: _btn(bg: _kGreen),
                  icon: const Icon(Icons.play_arrow, size: 15),
                  label: const Text('Bắt đầu làm'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _failDialog(provider, t),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.error_outline, size: 14),
                  label: const Text(
                    'Báo không hoàn thành',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              if (canComplete) ...[
                OutlinedButton.icon(
                  onPressed: () => _progressDialog(provider, t),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.sync_alt, size: 14),
                  label: const Text(
                    'Cập nhật tiến độ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _completeDialog(provider, t),
                  style: _btn(bg: const Color(0xFF047857)),
                  icon: const Icon(Icons.send, size: 13),
                  label: const Text('Nộp kết quả'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _failDialog(provider, t),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.error_outline, size: 14),
                  label: const Text(
                    'Báo không hoàn thành',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              TextButton(
                onPressed: () => _openAlertsTasks(2),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: const Color(0xFF475569),
                ),
                child: const Text(
                  'Chi tiết ➔',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ButtonStyle _btn({Color? bg}) => FilledButton.styleFrom(
    backgroundColor: bg ?? _kGreen,
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _declineDialog(FarmProvider provider, TaskModel t) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeclineTaskDialog(task: t, provider: provider),
    );
    if (submitted == true && mounted) {
      _rebuild(
        () => _feedback = (ok: true, message: 'Bạn đã từ chối công việc.'),
      );
    }
  }

  Future<void> _failDialog(FarmProvider provider, TaskModel t) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _FailTaskDialog(task: t, provider: provider),
    );
    if (submitted == true && mounted) {
      _rebuild(
        () => _feedback = (
          ok: true,
          message: 'Đã gửi báo cáo không hoàn thành tới chủ trang trại.',
        ),
      );
    }
  }

  /// Nộp kết quả: mô tả kết quả công việc đã hoàn thành như trên web.
  Future<void> _completeDialog(FarmProvider provider, TaskModel t) async {
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TaskResultDialog(task: t, provider: provider),
    );
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

  /// Cập nhật tiến độ: thay đổi % tiến độ và ghi chú thực địa.
  Future<void> _progressDialog(FarmProvider provider, TaskModel t) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => TaskProgressDialog(task: t, provider: provider),
    );
    if (submitted == true && mounted) {
      _rebuild(
        () => _feedback = (
          ok: true,
          message: 'Đã cập nhật tiến độ công việc!',
        ),
      );
    }
  }
}

class _DeclineTaskDialog extends StatefulWidget {
  final TaskModel task;
  final FarmProvider provider;
  const _DeclineTaskDialog({required this.task, required this.provider});

  @override
  State<_DeclineTaskDialog> createState() => _DeclineTaskDialogState();
}

class _DeclineTaskDialogState extends State<_DeclineTaskDialog> {
  late final TextEditingController _ctrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final reason = _ctrl.text.trim();
    final error = await widget.provider.performTaskAction(
      widget.task.taskId,
      'Decline',
      failureReason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Từ Chối Nhận Việc',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.task.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lý do từ chối (không bắt buộc):',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _ctrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Nhập lý do bạn không thể nhận công việc này...',
              hintStyle: TextStyle(fontSize: 12),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Đang gửi...' : 'Xác nhận từ chối'),
        ),
      ],
    );
  }
}

class _FailTaskDialog extends StatefulWidget {
  final TaskModel task;
  final FarmProvider provider;
  const _FailTaskDialog({required this.task, required this.provider});

  @override
  State<_FailTaskDialog> createState() => _FailTaskDialogState();
}

class _FailTaskDialogState extends State<_FailTaskDialog> {
  late final TextEditingController _ctrl;
  bool _submitting = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _localError = 'Vui lòng nhập lý do không thể hoàn thành.');
      return;
    }
    setState(() {
      _submitting = true;
      _localError = null;
    });
    final error = await widget.provider.performTaskAction(
      widget.task.taskId,
      'Fail',
      failureReason: reason,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _submitting = false);
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Báo Không Thể Hoàn Thành',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFFDC2626),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.task.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vì sao không thể hoàn thành? *',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _ctrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Mô tả trở ngại, sự cố thiết bị, thời tiết...',
              hintStyle: TextStyle(fontSize: 12),
              border: OutlineInputBorder(),
            ),
          ),
          if (_localError != null) ...[
            const SizedBox(height: 4),
            Text(
              _localError!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Đang gửi...' : 'Gửi báo cáo'),
        ),
      ],
    );
  }
}
