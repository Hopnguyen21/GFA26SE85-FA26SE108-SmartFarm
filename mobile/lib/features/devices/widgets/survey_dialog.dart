import 'package:flutter/material.dart';
import '../../../core/models/iot_deployment.dart';

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

/// Các loại thông số/cảm biến của nền tảng (khớp `EnvironmentalParameterCode` của backend, trừ EC đã bỏ).
const surveyParameters = <(String, String)>[
  ('Temperature', 'Nhiệt độ'),
  ('AirHumidity', 'Độ ẩm không khí'),
  ('SoilMoisture', 'Độ ẩm đất'),
  ('LightIntensity', 'Ánh sáng'),
  ('Ph', 'pH đất'),
];

/// Ghép kết quả các ô tích thành văn bản "điều kiện địa điểm" gửi backend; khả thi khi có ít nhất một loại phù hợp.
SurveyInput buildSurveyInput(Set<String> suitable, String notes) {
  final ok = [
    for (final p in surveyParameters)
      if (suitable.contains(p.$1)) p.$2,
  ];
  final no = [
    for (final p in surveyParameters)
      if (!suitable.contains(p.$1)) p.$2,
  ];
  return SurveyInput(
    feasible: ok.isNotEmpty,
    siteConditions:
        'Phù hợp lắp cảm biến: ${ok.isEmpty ? 'không có' : ok.join(', ')}.'
        '${no.isEmpty ? '' : ' Chưa phù hợp: ${no.join(', ')}.'}',
    notes: notes,
  );
}

/// Hộp thoại khảo sát địa điểm dùng chung (màn triển khai và khối "Tiến độ lắp đặt" của phiếu dịch vụ).
/// Kiểm tra bắt buộc ngay trong hộp thoại nên không đóng khi còn thiếu; trả null nếu bấm Hủy.
/// [site] (nếu có) hiện ở đầu hộp thoại để KTV thấy đang khảo sát farm/thửa/Zone nào.
Future<SurveyInput?> askSurvey(
  BuildContext context, {
  DeploymentContext? site,
}) => showDialog<SurveyInput>(
  context: context,
  builder: (_) => _SurveyDialog(site: site),
);

class _SurveyDialog extends StatefulWidget {
  final DeploymentContext? site;
  const _SurveyDialog({this.site});

  @override
  State<_SurveyDialog> createState() => _SurveyDialogState();
}

class _SurveyDialogState extends State<_SurveyDialog> {
  final _notes = TextEditingController();
  final Set<String> _suitable = {};
  String? _notesError;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final notes = _notes.text.trim();
    setState(() {
      _notesError = notes.isEmpty
          ? (_suitable.isEmpty
                ? 'Cần ghi rõ lý do không phù hợp.'
                : 'Cần nhập ghi chú khảo sát.')
          : null;
    });
    if (notes.isEmpty) return;
    Navigator.pop(context, buildSurveyInput(_suitable, notes));
  }

  Widget _siteInfo(DeploymentContext c) {
    final rows = <(String, String)>[
      ('Nông trại', c.farmName),
      if ((c.farmLocation ?? '').isNotEmpty) ('Vị trí', c.farmLocation!),
      ('Thửa đất', c.fieldName),
      ('Zone', c.zoneName),
      if (c.zoneAreaM2 > 0) ('Diện tích Zone', '${c.zoneAreaM2} m²'),
      if ((c.cropName ?? '').isNotEmpty)
        (
          'Cây trồng',
          [
            c.cropName,
            c.varietyName,
          ].where((e) => (e ?? '').isNotEmpty).join(' · '),
        ),
    ];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${r.$1}: ',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    TextSpan(
                      text: r.$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Khảo sát địa điểm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.site != null) _siteInfo(widget.site!),
            const Text(
              'Tích loại cảm biến phù hợp lắp tại địa điểm này',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            for (final p in surveyParameters)
              CheckboxListTile(
                key: ValueKey('survey-${p.$1}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(p.$2),
                value: _suitable.contains(p.$1),
                onChanged: (v) => setState(() {
                  v == true ? _suitable.add(p.$1) : _suitable.remove(p.$1);
                }),
              ),
            const SizedBox(height: 6),
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
