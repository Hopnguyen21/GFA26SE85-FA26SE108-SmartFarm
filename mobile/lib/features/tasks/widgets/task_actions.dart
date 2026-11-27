import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import 'task_result_dialog.dart';
import 'task_progress_dialog.dart';

const Map<String, String> _statusLabels = {
  'Pending': 'Chờ nhận việc',
  'Accepted': 'Đã nhận việc',
  'InProgress': 'Đang thực hiện',
  'CompletedPendingReview': 'Chờ duyệt',
  'Approved': 'Đã duyệt',
  'Failed': 'Thất bại',
  'Overdue': 'Quá hạn',
  'Declined': 'Đã từ chối',
  'Cancelled': 'Đã gỡ',
};

/// Trạng thái và thao tác thật của công việc. Farmer chỉ thao tác trên phần việc của mình;
/// Owner duyệt kết quả từng Farmer. Giao diện chỉ đổi theo dữ liệu backend trả về.
class TaskActions extends StatefulWidget {
  final TaskModel task;
  final bool isOwner;
  const TaskActions({super.key, required this.task, required this.isOwner});

  @override
  State<TaskActions> createState() => _TaskActionsState();
}

class _TaskActionsState extends State<TaskActions> {
  bool _busy = false;

  Future<void> _run(
    String action, {
    String? failureReason,
    String? farmerId,
    String? notes,
  }) async {
    setState(() => _busy = true);
    final error = await context.read<FarmProvider>().performTaskAction(
      widget.task.taskId,
      action,
      failureReason: failureReason,
      farmerId: farmerId,
      notes: notes,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<String?> _askText(String title, String hint) async {
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextInputDialog(title: title, hint: hint),
    );
    return value == null || value.isEmpty ? null : value;
  }

  /// Task đã đóng (duyệt/hủy) thì không giao thêm người.
  bool _canManageAssignees(TaskModel task) =>
      task.status != 'Approved' && task.status != 'Cancelled';

  /// Owner thêm/gỡ Farmer thực hiện (POST/DELETE .../assignees). Chỉ hiển thị theo dữ liệu backend trả về.
  Future<void> _manageAssignees() async {
    final provider = context.read<FarmProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _AssigneesSheet(taskId: widget.task.taskId, provider: provider),
    );
  }

  Widget _reportPhotos(List<String> urls) => Wrap(
    spacing: 8,
    children: [
      for (final (index, url) in urls.indexed)
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Ảnh minh chứng ${index + 1}'),
              content: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text('Không tải được ảnh.'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.image_outlined),
          label: Text('Ảnh ${index + 1}'),
        ),
    ],
  );

  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool primary = false,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF047857);
    final style = const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold);
    return primary
        ? ElevatedButton(
            onPressed: _busy ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label, style: style),
          )
        : OutlinedButton(
            onPressed: _busy ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label, style: style),
          );
  }

  List<Widget> _farmerButtons(TaskAssignmentModel mine) {
    Future<void> decline() async {
      final reason = await _askText(
        'Lý do từ chối',
        'Vì sao bạn không nhận việc này?',
      );
      if (reason != null) await _run('Decline', failureReason: reason);
    }

    Future<void> fail() async {
      final reason = await _askText(
        'Báo không thể hoàn thành',
        'Vì sao không hoàn thành được? *',
      );
      if (reason != null && reason.trim().isNotEmpty) {
        await _run('Fail', failureReason: reason.trim());
      }
    }

    switch (mine.status) {
      case 'Pending':
        return [
          _button('Nhận việc', () => _run('Accept'), primary: true),
          _button('Từ chối', decline, danger: true),
        ];
      case 'Accepted':
        return [
          _button('Bắt đầu', () => _run('Start'), primary: true),
          _button('Báo không hoàn thành', fail, danger: true),
        ];
      case 'InProgress':
        return [
          _button('Nộp kết quả', () {
            final provider = context.read<FarmProvider>();
            showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) =>
                  TaskResultDialog(task: widget.task, provider: provider),
            );
          }, primary: true),
          _button('Cập nhật %', () {
            final provider = context.read<FarmProvider>();
            showDialog<bool>(
              context: context,
              builder: (_) =>
                  TaskProgressDialog(task: widget.task, provider: provider),
            );
          }),
          _button('Báo không hoàn thành', fail, danger: true),
        ];
      case 'Overdue':
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 14,
                  color: Color(0xFFDC2626),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Công việc đã quá hạn. Cần Chủ trang trại gia hạn hoặc giao lại.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    if (task.status.isEmpty) return const SizedBox.shrink();
    final mine = task.assignments.isNotEmpty ? task.assignments.first : null;
    final shownStatus = widget.isOwner
        ? task.status
        : (mine?.status ?? task.status);
    final buttons = widget.isOwner
        ? const <Widget>[]
        : (mine == null ? const <Widget>[] : _farmerButtons(mine));
    final showFarmerProgress =
        !widget.isOwner &&
        mine != null &&
        [
          'Accepted',
          'InProgress',
          'CompletedPendingReview',
          'Approved',
        ].contains(mine.status);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _statusLabels[shownStatus] ?? shownStatus,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          if (showFarmerProgress) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: mine.progressPercent / 100.0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF047857),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${mine.progressPercent}%',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
          if (!widget.isOwner && (mine?.progressNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Ghi chú tiến độ: ${mine!.progressNote!}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
          if (!widget.isOwner && (mine?.result ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Text(
                'Kết quả đã nộp: ${mine!.result!}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ],
          if (!widget.isOwner && (mine?.failureReason ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                'Lý do: ${mine!.failureReason!}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBE123C),
                ),
              ),
            ),
          ],
          if (widget.isOwner) ...[
            const SizedBox(height: 4),
            for (final a in task.assignments)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a.farmerName,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: a.status == 'Approved'
                                ? const Color(0xFFD1FAE5)
                                : a.status == 'CompletedPendingReview'
                                ? const Color(0xFFEDE9FE)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _statusLabels[a.status] ?? a.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: a.status == 'Approved'
                                  ? const Color(0xFF064E3B)
                                  : a.status == 'CompletedPendingReview'
                                  ? const Color(0xFF4C1D95)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (a.status == 'CompletedPendingReview') ...[
                          const SizedBox(width: 6),
                          _button(
                            'Duyệt kết quả',
                            () => _run('Approve', farmerId: a.farmerId),
                            primary: true,
                          ),
                        ],
                      ],
                    ),
                    if (a.status != 'Cancelled' && a.status != 'Declined') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: a.progressPercent / 100.0,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF047857),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${a.progressPercent}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((a.progressNote ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Ghi chú: ${a.progressNote!}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if ((a.result ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Kết quả: ${a.result!}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                    if (a.imageUrls.isNotEmpty) _reportPhotos(a.imageUrls),
                    if ((a.failureReason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Lý do: ${a.failureReason!}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (_canManageAssignees(task)) ...[
              const SizedBox(height: 6),
              _button('Người thực hiện', _manageAssignees),
            ],
          ],
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: buttons),
          ],
        ],
      ),
    );
  }
}

class _AssigneesSheet extends StatefulWidget {
  final String taskId;
  final FarmProvider provider;
  const _AssigneesSheet({required this.taskId, required this.provider});

  @override
  State<_AssigneesSheet> createState() => _AssigneesSheetState();
}

class _AssigneesSheetState extends State<_AssigneesSheet> {
  final Set<String> _toAdd = {};
  bool _busy = false;

  /// Farmer đã gỡ/từ chối/thất bại/quá hạn vẫn được giao lại; các trạng thái còn lại coi như đang giữ việc.
  static const _reassignable = {'Cancelled', 'Declined', 'Failed', 'Overdue'};

  TaskModel? get _task =>
      widget.provider.tasks.where((t) => t.taskId == widget.taskId).firstOrNull;

  void _show(String? error, String ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? ok),
        backgroundColor: error == null
            ? const Color(0xFF047857)
            : const Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _remove(TaskAssignmentModel a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Gỡ người thực hiện?'),
        content: Text('Gỡ ${a.farmerName} khỏi công việc này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Gỡ'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final error = await widget.provider.removeTaskAssignee(
      widget.taskId,
      a.farmerId,
    );
    if (mounted) setState(() => _busy = false);
    _show(error, 'Đã gỡ ${a.farmerName}.');
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    final n = _toAdd.length;
    final error = await widget.provider.addTaskAssignees(
      widget.taskId,
      _toAdd.toList(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) _toAdd.clear();
    });
    _show(error, 'Đã giao thêm $n người.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        final task = _task;
        if (task == null)
          return const SizedBox(
            height: 120,
            child: Center(child: Text('Không tìm thấy công việc.')),
          );
        final active = task.assignments
            .where((a) => !_reassignable.contains(a.status))
            .toList();
        final activeIds = active.map((a) => a.farmerId.toLowerCase()).toSet();
        final candidates = widget.provider.farmersForCurrentFarm
            .where((f) => !activeIds.contains(f.farmerId.toLowerCase()))
            .toList();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Người thực hiện · ${task.title}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const Text(
                    'Chưa có ai đang giữ việc.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                for (final a in active)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(a.farmerName),
                    subtitle: Text(_statusLabels[a.status] ?? a.status),
                    trailing: a.status == 'Approved'
                        ? null
                        : IconButton(
                            tooltip: 'Gỡ',
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              color: Color(0xFFDC2626),
                            ),
                            onPressed: _busy ? null : () => _remove(a),
                          ),
                  ),
                const Divider(),
                const Text(
                  'Giao thêm',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Không còn Farmer nào để giao.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final f in candidates)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _toAdd.contains(f.farmerId),
                          onChanged: _busy
                              ? null
                              : (v) => setState(
                                  () => v == true
                                      ? _toAdd.add(f.farmerId)
                                      : _toAdd.remove(f.farmerId),
                                ),
                          title: Text(f.name),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy || _toAdd.isEmpty ? null : _add,
                    child: Text(
                      _toAdd.isEmpty
                          ? 'Chọn Farmer để giao'
                          : 'Giao cho ${_toAdd.length} người',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _TextInputDialog({required this.title, required this.hint});

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _ctrl;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 15)),
      content: TextField(
        controller: _ctrl,
        maxLines: 3,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('Gửi'),
        ),
      ],
    );
  }
}
