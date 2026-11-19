/// Báo cáo khảo sát thực địa (`/api/v1/field-survey-reports`): phiếu 10 mục do kỹ thuật viên lập sau khi khảo sát trang trại.
/// Owner/Farmer chỉ xem; kỹ thuật viên lập/sửa phiếu của mình. Giống `FieldSurveyReportModal` trên web.
class FieldSurveySection {
  final String key; // tên trường JSON
  final String title;
  final String hint;
  const FieldSurveySection(this.key, this.title, this.hint);
}

/// 9 mục nội dung (mục 1 là thông tin buổi khảo sát), thứ tự và tiêu đề như web.
const fieldSurveySections = <FieldSurveySection>[
  FieldSurveySection(
    'farmOverview',
    'Mục 2: Tổng quan trang trại',
    'Mô tả chi tiết: quy mô, vị trí, nhà màng/khu trồng, nguồn nước, điện…',
  ),
  FieldSurveySection(
    'cropAndSeasonStatus',
    'Mục 3: Hiện trạng cây trồng & mùa vụ',
    'Ghi chú hiện trạng cây trồng: loại cây, giống, giai đoạn, lịch mùa vụ…',
  ),
  FieldSurveySection(
    'cultivationProcess',
    'Mục 4: Quy trình canh tác thực tế',
    'Quy trình chăm sóc từng giai đoạn: tưới, bón phân, phòng trừ sâu bệnh…',
  ),
  FieldSurveySection(
    'environmentalMonitoring',
    'Mục 5: Hiện trạng theo dõi môi trường',
    'Các chỉ số đang theo dõi (nhiệt độ, độ ẩm, ánh sáng, pH…), cách đo hiện tại…',
  ),
  FieldSurveySection(
    'environmentalThresholdNeeds',
    'Mục 6: Nhu cầu thiết lập ngưỡng môi trường',
    'Ngưỡng mong muốn theo từng thông số và giai đoạn, mức cảnh báo…',
  ),
  FieldSurveySection(
    'equipmentAndDataCollection',
    'Mục 7: Hiện trạng thiết bị & thu thập dữ liệu',
    'Hạ tầng hiện có (đường ống, van, điện, mạng), thiết bị cần lắp, cách thu thập dữ liệu…',
  ),
  FieldSurveySection(
    'managementAndPermissions',
    'Mục 8: Cơ cấu quản lý & phân quyền trang trại',
    'Ban quản lý, nông dân/công nhân, ai được xem và điều khiển Zone nào…',
  ),
  FieldSurveySection(
    'difficultiesAndNeeds',
    'Mục 9: Khó khăn & nhu cầu thực tế',
    'Các khó khăn trang trại đang đối mặt và nhu cầu cần giải quyết…',
  ),
  FieldSurveySection(
    'teamAssessment',
    'Mục 10: Đánh giá & đề xuất của nhóm kỹ thuật SmartFarm',
    'Đề xuất giải pháp kỹ thuật, phạm vi triển khai, lưu ý…',
  ),
];

const fieldSurveyStatusLabels = <String, String>{
  'Draft': 'Bản nháp',
  'Submitted': 'Đã nộp',
  'Approved': 'Đã duyệt',
};

class FieldSurveyReport {
  final String id;
  final String farmId;
  final String farmName;
  final String? serviceRequestId;
  final String? serviceRequestTitle;
  final String? zoneId;
  final String? zoneName;
  final String title;
  final DateTime? surveyDate;
  final String location;
  final String surveyorName;
  final String representativeName;
  final Map<String, String> sections; // theo [fieldSurveySections].key
  final String status;
  final String createdByUserId;
  final String createdByUserName;
  final DateTime? createdAtUtc;
  final DateTime? updatedAtUtc;

  const FieldSurveyReport({
    required this.id,
    required this.farmId,
    this.farmName = '',
    this.serviceRequestId,
    this.serviceRequestTitle,
    this.zoneId,
    this.zoneName,
    required this.title,
    this.surveyDate,
    this.location = '',
    this.surveyorName = '',
    this.representativeName = '',
    this.sections = const {},
    this.status = 'Submitted',
    this.createdByUserId = '',
    this.createdByUserName = '',
    this.createdAtUtc,
    this.updatedAtUtc,
  });

  String get statusLabel => fieldSurveyStatusLabels[status] ?? status;

  factory FieldSurveyReport.fromJson(Map<String, dynamic> j) {
    String s(String k) => '${j[k] ?? ''}';
    String? n(String k) {
      final v = j[k];
      return v == null || '$v'.isEmpty ? null : '$v';
    }

    return FieldSurveyReport(
      id: s('id'),
      farmId: s('farmId'),
      farmName: s('farmName'),
      serviceRequestId: n('serviceRequestId'),
      serviceRequestTitle: n('serviceRequestTitle'),
      zoneId: n('zoneId'),
      zoneName: n('zoneName'),
      title: s('title'),
      surveyDate: DateTime.tryParse(s('surveyDate')),
      location: s('location'),
      surveyorName: s('surveyorName'),
      representativeName: s('representativeName'),
      sections: {for (final sec in fieldSurveySections) sec.key: s(sec.key)},
      status: j['status'] == null ? 'Submitted' : s('status'),
      createdByUserId: s('createdByUserId'),
      createdByUserName: s('createdByUserName'),
      createdAtUtc: DateTime.tryParse(s('createdAtUtc')),
      updatedAtUtc: DateTime.tryParse(s('updatedAtUtc')),
    );
  }
}

/// Dữ liệu form gửi lên (tạo hoặc sửa): chuẩn hoá khoảng trắng như web (`trim`).
Map<String, dynamic> fieldSurveyPayload({
  String? farmId,
  String? serviceRequestId,
  String? zoneId,
  required String title,
  required DateTime surveyDate,
  String location = '',
  String surveyorName = '',
  String representativeName = '',
  required Map<String, String> sections,
  required String status,
}) => {
  'farmId': ?farmId,
  'serviceRequestId': ?serviceRequestId,
  'zoneId': ?zoneId,
  'title': title.trim(),
  'surveyDate': DateTime.utc(
    surveyDate.year,
    surveyDate.month,
    surveyDate.day,
  ).toIso8601String(),
  'location': location.trim(),
  'surveyorName': surveyorName.trim(),
  'representativeName': representativeName.trim(),
  for (final sec in fieldSurveySections)
    sec.key: (sections[sec.key] ?? '').trim(),
  'status': status,
};
