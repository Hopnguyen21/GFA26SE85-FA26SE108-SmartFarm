import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';

const _muted = Color(0xFF64748B);
const _green = Color(0xFF059669);

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Hộp thoại chuyển giai đoạn sinh trưởng của một vụ ĐANG CANH TÁC (Owner). Trả về true nếu đã chuyển.
/// Giai đoạn lấy từ hồ sơ của vụ; backend từ chối giai đoạn không thuộc hồ sơ hoặc trùng giai đoạn hiện tại.
Future<bool?> showChangeStageDialog(
  BuildContext context,
  String zoneId,
  Map<String, dynamic> season,
) => showDialog<bool>(
  context: context,
  builder: (_) => _ChangeStageDialog(zoneId: zoneId, season: season),
);

class _ChangeStageDialog extends StatefulWidget {
  final String zoneId;
  final Map<String, dynamic> season;
  const _ChangeStageDialog({required this.zoneId, required this.season});

  @override
  State<_ChangeStageDialog> createState() => _ChangeStageDialogState();
}

class _ChangeStageDialogState extends State<_ChangeStageDialog> {
  final _notes = TextEditingController();
  List<Map<String, dynamic>>? _stages;
  String? _loadError;
  String? _saveError;
  String? _selected;
  bool _saving = false;

  String get _currentId =>
      '${widget.season['currentGrowthStageId'] ?? ''}'.toLowerCase();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _stages = null;
    });
    try {
      final stages = await CropApi.getGrowthStages(
        '${widget.season['growthProfileId']}',
      );
      stages.sort(
        (a, b) => ((a['stageOrder'] as num?) ?? 0).compareTo(
          (b['stageOrder'] as num?) ?? 0,
        ),
      );
      if (!mounted) return;
      // Gợi ý sẵn giai đoạn kế tiếp giai đoạn hiện tại (nếu có).
      final i = stages.indexWhere(
        (s) => '${s['stageId']}'.toLowerCase() == _currentId,
      );
      setState(() {
        _stages = stages;
        _selected = i >= 0 && i + 1 < stages.length
            ? '${stages[i + 1]['stageId']}'
            : null;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = _clean(e));
    }
  }

  Future<void> _save() async {
    final stageId = _selected;
    if (stageId == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await CropApi.transitionSeasonStage(
        widget.zoneId,
        '${widget.season['seasonId'] ?? widget.season['plantingSeasonId']}',
        growthStageId: stageId,
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _clean(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages;
    return AlertDialog(
      title: Text(
        'Chuyển giai đoạn · ${widget.season['name'] ?? ''}',
        style: const TextStyle(fontSize: 16),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loadError != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Không tải được giai đoạn: $_loadError',
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              )
            : stages == null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : stages.isEmpty
            ? const Text('Hồ sơ của vụ chưa có giai đoạn nào.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ngưỡng cảnh báo của vụ sẽ đổi theo giai đoạn mới.',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    for (final st in stages) _stageTile(st),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notes,
                      maxLength: 1000,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (không bắt buộc)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_saveError != null)
                      Text(
                        _saveError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving || _selected == null ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Chuyển giai đoạn'),
        ),
      ],
    );
  }

  Widget _stageTile(Map<String, dynamic> st) {
    final id = '${st['stageId']}';
    final isCurrent = id.toLowerCase() == _currentId;
    final selected = _selected == id;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      enabled: !isCurrent && !_saving,
      onTap: () => setState(() => _selected = id),
      leading: Icon(
        isCurrent
            ? Icons.check_circle
            : selected
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked,
        color: isCurrent || selected ? _green : _muted,
        size: 20,
      ),
      title: Text(
        '${st['stageOrder']}. ${st['name']}${isCurrent ? ' (hiện tại)' : ''}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${st['durationDays']} ngày',
        style: const TextStyle(fontSize: 11.5),
      ),
    );
  }
}
