import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';

class TaskProgressDialog extends StatefulWidget {
  final TaskModel task;
  final FarmProvider provider;
  const TaskProgressDialog({
    super.key,
    required this.task,
    required this.provider,
  });

  @override
  State<TaskProgressDialog> createState() => _TaskProgressDialogState();
}

class _TaskProgressDialogState extends State<TaskProgressDialog> {
  late int _progressPercent;
  late final TextEditingController _noteCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final mine = widget.task.assignments.isNotEmpty
        ? widget.task.assignments.first
        : null;
    _progressPercent = mine?.progressPercent ?? 0;
    _noteCtrl = TextEditingController(
      text: mine?.progressNote ?? '',
    );
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await widget.provider.performTaskAction(
      widget.task.taskId,
      'UpdateProgress',
      progressPercent: _progressPercent,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Cập Nhật Tiến Độ Thực Địa',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tiến độ thực hiện:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_progressPercent%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ],
            ),
            Slider(
              value: _progressPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_progressPercent%',
              activeColor: const Color(0xFF047857),
              onChanged: (v) => setState(() => _progressPercent = v.round()),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ghi chú tiến độ (không bắt buộc):',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Nhập ghi chú tiến độ thực địa...',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Đang cập nhật...' : 'Cập nhật'),
        ),
      ],
    );
  }
}
