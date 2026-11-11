import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';

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
    String? result,
    String? failureReason,
    int? progressPercent,
    String? farmerId,
  }) async {
    setState(() => _busy = true);
    final error = await context.read<FarmProvider>().performTaskAction(
      widget.task.taskId,
      action,
      result: result,
      failureReason: failureReason,
      progressPercent: progressPercent,
      farmerId: farmerId,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)));
    }
  }

  Future<String?> _askText(String title, String hint) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Gửi')),
        ],
      ),
    );
    ctrl.dispose();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _askProgress(int current) async {
    double value = current.toDouble();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Tiến độ: ${value.round()}%', style: const TextStyle(fontSize: 15)),
          content: Slider(value: value, max: 100, divisions: 20, onChanged: (v) => setLocal(() => value = v)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, value.round()), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (picked != null) await _run('UpdateProgress', progressPercent: picked);
  }

  /// Task đã đóng (duyệt/hủy) thì không giao thêm người.
  bool _canManageAssignees(TaskModel task) => task.status != 'Approved' && task.status != 'Cancelled';

  /// Owner thêm/gỡ Farmer thực hiện (POST/DELETE .../assignees). Chỉ hiển thị theo dữ liệu backend trả về.
  Future<void> _manageAssignees() async {
    final provider = context.read<FarmProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AssigneesSheet(taskId: widget.task.taskId, provider: provider),
    );
  }

  Widget _button(String label, VoidCallback onPressed, {bool primary = false, bool danger = false}) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF059669);
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
            style: OutlinedButton.styleFrom(foregroundColor: color, visualDensity: VisualDensity.compact),
            child: Text(label, style: style),
          );
  }

  List<Widget> _farmerButtons(TaskAssignmentModel mine) {
    Future<void> decline() async {
      final reason = await _askText('Lý do từ chối', 'Vì sao bạn không nhận việc này?');
      if (reason != null) await _run('Decline', failureReason: reason);
    }

    switch (mine.status) {
      case 'Pending':
        return [_button('Nhận việc', () => _run('Accept'), primary: true), _button('Từ chối', decline, danger: true)];
      case 'Accepted':
        return [_button('Bắt đầu', () => _run('Start'), primary: true), _button('Từ chối', decline, danger: true)];
      case 'InProgress':
        return [
          _button('Báo hoàn thành', () async {
            final result = await _askText('Kết quả công việc', 'Bạn đã làm được gì?');
            if (result != null) await _run('Complete', result: result);
          }, primary: true),
          _button('Cập nhật %', () => _askProgress(mine.progressPercent)),
          _button('Báo thất bại', () async {
            final reason = await _askText('Lý do thất bại', 'Vì sao không hoàn thành được?');
            if (reason != null) await _run('Fail', failureReason: reason);
          }, danger: true),
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
    final shownStatus = widget.isOwner ? task.status : (mine?.status ?? task.status);
    final buttons = widget.isOwner
        ? [
            for (final a in task.assignments.where((a) => a.status == 'CompletedPendingReview'))
              _button('Duyệt ${a.farmerName}', () => _run('Approve', farmerId: a.farmerId), primary: true),
            if (_canManageAssignees(task)) _button('Người thực hiện', _manageAssignees),
          ]
        : (mine == null ? const <Widget>[] : _farmerButtons(mine));

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusLabels[shownStatus] ?? shownStatus,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
          ),
          if (!widget.isOwner && mine != null && mine.progressPercent > 0)
            Text('Tiến độ: ${mine.progressPercent}%', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          if (widget.isOwner)
            for (final a in task.assignments)
              Text(
                '${a.farmerName}: ${_statusLabels[a.status] ?? a.status}${a.result != null ? ' — ${a.result}' : ''}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
          if (buttons.isNotEmpty) ...[const SizedBox(height: 4), Wrap(spacing: 6, runSpacing: 4, children: buttons)],
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

  TaskModel? get _task => widget.provider.tasks.where((t) => t.taskId == widget.taskId).firstOrNull;

  void _show(String? error, String ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? ok),
        backgroundColor: error == null ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Gỡ')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final error = await widget.provider.removeTaskAssignee(widget.taskId, a.farmerId);
    if (mounted) setState(() => _busy = false);
    _show(error, 'Đã gỡ ${a.farmerName}.');
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    final n = _toAdd.length;
    final error = await widget.provider.addTaskAssignees(widget.taskId, _toAdd.toList());
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
        if (task == null) return const SizedBox(height: 120, child: Center(child: Text('Không tìm thấy công việc.')));
        final active = task.assignments.where((a) => !_reassignable.contains(a.status)).toList();
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const Text('Chưa có ai đang giữ việc.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                            icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFDC2626)),
                            onPressed: _busy ? null : () => _remove(a),
                          ),
                  ),
                const Divider(),
                const Text('Giao thêm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Không còn Farmer nào để giao.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
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
                              : (v) => setState(() => v == true ? _toAdd.add(f.farmerId) : _toAdd.remove(f.farmerId)),
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
                    child: Text(_toAdd.isEmpty ? 'Chọn Farmer để giao' : 'Giao cho ${_toAdd.length} người'),
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
