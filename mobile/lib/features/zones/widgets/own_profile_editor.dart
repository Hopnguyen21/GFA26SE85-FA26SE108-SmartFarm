import 'package:flutter/material.dart';
import '../zone_crop_plan_applier.dart';
import '../zone_crop_plan_logic.dart';
import 'stage_draft_tile.dart';

/// Sửa hồ sơ RIÊNG của trang trại đã lưu (tên, mô tả, số ngày và ngưỡng từng giai đoạn). Trả true nếu đã lưu.
/// Hồ sơ hệ thống không mở được ở đây; backend cũng từ chối sửa trực tiếp.
Future<bool?> showOwnProfileEditor(
  BuildContext context, {
  required String profileId,
  required String name,
  required String? description,
  required List<StageDraft> stages,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _OwnProfileEditor(
      profileId: profileId,
      name: name,
      description: description,
      stages: stages,
    ),
  );
}

class _OwnProfileEditor extends StatefulWidget {
  final String profileId;
  final String name;
  final String? description;
  final List<StageDraft> stages;
  const _OwnProfileEditor({
    required this.profileId,
    required this.name,
    required this.description,
    required this.stages,
  });

  @override
  State<_OwnProfileEditor> createState() => _OwnProfileEditorState();
}

class _OwnProfileEditorState extends State<_OwnProfileEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _desc = TextEditingController(
    text: widget.description ?? '',
  );
  late final List<StageDraft> _stages = [...widget.stages];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await applyOwnProfileEdits(
      profileId: widget.profileId,
      originalName: widget.name,
      originalDescription: widget.description,
      name: _name.text,
      description: _desc.text,
      original: widget.stages,
      edited: _stages,
    );
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      // Giữ nguyên mọi thứ người dùng đã nhập để sửa tiếp.
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sửa hồ sơ riêng của trang trại',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chỉ sửa bản riêng của trang trại bạn; hồ sơ hệ thống không bị thay đổi. '
                'Vụ đang chạy giữ nguyên các giai đoạn của nó.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Tên hồ sơ *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _desc,
                maxLines: 2,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              for (var i = 0; i < _stages.length; i++)
                StageDraftTile(
                  stage: _stages[i],
                  editable: true,
                  onDuration: (n) => setState(
                    () => _stages[i] = _stages[i].copyWith(durationDays: n),
                  ),
                  onRequirement: (code, {min, max, target}) => setState(() {
                    _stages[i] = _stages[i].copyWith(
                      requirements: [
                        for (final r in _stages[i].requirements)
                          if (r.code == code)
                            r.copyWith(min: min, max: max, target: target)
                          else
                            r,
                      ],
                    );
                  }),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Đang lưu…' : 'Lưu hồ sơ'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
