import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/farm_provider.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)),
      );
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
          content: Slider(
            value: value,
            max: 100,
            divisions: 20,
            onChanged: (v) => setLocal(() => value = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, value.round()), child: const Text('Lưu')),
          ],
        ),
      ),
    );
    if (picked != null) await _run('UpdateProgress', progressPercent: picked);
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
          if (buttons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: buttons),
          ],
        ],
      ),
    );
  }
}
