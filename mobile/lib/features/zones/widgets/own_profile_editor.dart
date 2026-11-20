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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
        12,
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
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      size: 20,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sửa hồ sơ riêng của trang trại',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chỉ sửa bản riêng của trang trại bạn; hồ sơ hệ thống không bị thay đổi. '
                        'Vụ đang chạy giữ nguyên các giai đoạn của nó.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Tên hồ sơ *',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF047857),
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _desc,
                maxLines: 2,
                maxLength: 4000,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  prefixIcon: const Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF047857),
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    size: 16,
                    color: Color(0xFF047857),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Giai đoạn canh tác & ngưỡng',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_stages.length} giai đoạn',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
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
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        foregroundColor: const Color(0xFF475569),
                      ),
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _busy ? null : _save,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _busy ? 'Đang lưu…' : 'Lưu hồ sơ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
