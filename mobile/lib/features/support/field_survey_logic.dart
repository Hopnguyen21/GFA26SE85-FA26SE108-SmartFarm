import '../../core/models/field_survey_report.dart';

/// Bối cảnh mở báo cáo từ một phiếu dịch vụ (điền sẵn trang trại/Zone như web).
class FieldSurveyTarget {
  final String? serviceRequestId;
  final String farmId;
  final String farmName;
  final String? zoneId;
  final String zoneName;

  /// 8 ký tự đầu mã phiếu (hiện trong tiêu đề mặc định).
  final String? requestCode;
  const FieldSurveyTarget({
    this.serviceRequestId,
    required this.farmId,
    this.farmName = '',
    this.zoneId,
    this.zoneName = '',
    this.requestCode,
  });
}

/// Kết quả khi KTV nộp báo cáo: báo cáo đã lưu và kết luận khả thi (null nếu màn không đòi kết luận).
class FieldSurveyOutcome {
  final FieldSurveyReport report;
  final bool? feasible;
  const FieldSurveyOutcome(this.report, this.feasible);
}

String fieldSurveyDate(DateTime? d) {
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

/// Tiêu đề mặc định của báo cáo mới (như web).
String defaultFieldSurveyTitle(FieldSurveyTarget? t) {
  final farm = (t?.farmName ?? '').trim().isEmpty
      ? 'Trang trại'
      : t!.farmName.trim();
  final code = t?.requestCode;
  return code == null || code.isEmpty
      ? 'Báo cáo khảo sát thực địa - $farm'
      : 'Báo cáo khảo sát thực địa [$code] - $farm';
}

String _cut(String s, int max) => s.length <= max ? s : s.substring(0, max);

/// Nội dung gửi cho API khảo sát của luồng lắp đặt (`SiteConditions` và `Notes` bắt buộc, tối đa 2000 ký tự) từ báo cáo vừa nộp:
/// điều kiện địa điểm lấy từ báo cáo (địa điểm, thiết bị/hạ tầng), ghi chú lấy từ đánh giá/khó khăn; không bịa nội dung khi trống.
({String siteConditions, String notes}) surveyDigest(
  FieldSurveyReport r, {
  required bool feasible,
}) {
  final parts = <String>[
    'Theo báo cáo khảo sát thực địa "${r.title}" ngày ${fieldSurveyDate(r.surveyDate)}'
        '${r.location.trim().isEmpty ? '' : ' tại ${r.location.trim()}'}.',
    if ((r.sections['equipmentAndDataCollection'] ?? '').trim().isNotEmpty)
      'Thiết bị & thu thập dữ liệu: ${r.sections['equipmentAndDataCollection']!.trim()}',
  ];
  final team = (r.sections['teamAssessment'] ?? '').trim();
  final hard = (r.sections['difficultiesAndNeeds'] ?? '').trim();
  final notes = team.isNotEmpty
      ? team
      : (hard.isNotEmpty
            ? hard
            : (feasible
                  ? 'Khả thi theo báo cáo khảo sát thực địa.'
                  : 'Không khả thi theo báo cáo khảo sát thực địa.'));
  return (
    siteConditions: _cut(parts.join(' '), 2000),
    notes: _cut(notes, 2000),
  );
}
