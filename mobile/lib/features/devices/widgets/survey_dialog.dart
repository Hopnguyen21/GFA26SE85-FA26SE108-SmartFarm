import 'package:flutter/material.dart';

/// Kết quả khảo sát địa điểm do kỹ thuật viên nhập (backend bắt buộc điều kiện địa điểm và ghi chú).
class SurveyInput {
  final bool feasible;
  final String siteConditions;
  final String notes;
  const SurveyInput({
    required this.feasible,
    required this.siteConditions,
    required this.notes,
  });
}

/// Hộp thoại khảo sát địa điểm dùng chung (màn triển khai và khối "Tiến độ lắp đặt" của phiếu dịch vụ).
/// Kiểm tra bắt buộc ngay trong hộp thoại nên không đóng khi còn thiếu; trả null nếu bấm Hủy.
Future<SurveyInput?> askSurvey(BuildContext context) => showDialog<SurveyInput>(
  context: context,
  builder: (_) => const _SurveyDialog(),
);

class _SurveyDialog extends StatefulWidget {
  const _SurveyDialog();

  @override
  State<_SurveyDialog> createState() => _SurveyDialogState();
}

class _SurveyDialogState extends State<_SurveyDialog> {
  final _site = TextEditingController();
  final _notes = TextEditingController();
  bool? _feasible; // bắt buộc chọn, không mặc định thành công
  String? _feasibleError;
  String? _siteError;
  String? _notesError;

  @override
  void dispose() {
    _site.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final site = _site.text.trim();
    final notes = _notes.text.trim();
    setState(() {
      _feasibleError = _feasible == null
          ? 'Hãy chọn khả thi hoặc không khả thi.'
          : null;
      _siteError = site.isEmpty ? 'Cần nhập điều kiện địa điểm.' : null;
      _notesError = notes.isEmpty
          ? (_feasible == false
                ? 'Cần ghi rõ lý do không khả thi.'
                : 'Cần nhập ghi chú khảo sát.')
          : null;
    });
    if (_feasible == null || site.isEmpty || notes.isEmpty) return;
    Navigator.pop(
      context,
      SurveyInput(feasible: _feasible!, siteConditions: site, notes: notes),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khảo sát địa điểm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: true, label: Text('Khả thi')),
                ButtonSegment(value: false, label: Text('Không khả thi')),
              ],
              selected: {?_feasible},
              onSelectionChanged: (s) => setState(() {
                _feasible = s.isEmpty ? null : s.first;
                _feasibleError = null;
              }),
            ),
            if (_feasibleError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _feasibleError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            TextField(
              controller: _site,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Điều kiện địa điểm',
                errorText: _siteError,
              ),
            ),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Ghi chú khảo sát',
                errorText: _notesError,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Ghi nhận')),
      ],
    );
  }
}
