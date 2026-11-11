// Logic thuần (không UI) cho chọn cây trồng + hồ sơ canh tác khi tạo/sửa Zone. Khớp mô hình backend:
//  - Hồ sơ được gắn TRỰC TIẾP với Zone (Zone.GrowthProfileId); chọn/đổi/gỡ hồ sơ không tạo hay đổi PlantingSeason
//    nên form này không có ngày bắt đầu/kết thúc (các ngày đó chỉ thuộc luồng tạo vụ mùa thật).
//  - Chủ trang trại không sửa profile hệ thống: sao chép (POST /growth-profiles + sourceProfileId) rồi sửa bản sao.
//  - Lịch tưới thuộc hồ sơ theo giai đoạn (xem profile_irrigation_logic.dart), không đọc/ghi Crop.CalendarIrrigationPlan.

import '../../core/utils/json_utils.dart';

/// Một ngưỡng môi trường của giai đoạn (Min/Max/Target + đơn vị) đúng như API.
class RequirementDraft {
  final String code;
  final double min;
  final double max;
  final double target;
  final String unit;
  const RequirementDraft({
    required this.code,
    required this.min,
    required this.max,
    required this.target,
    required this.unit,
  });

  RequirementDraft copyWith({double? min, double? max, double? target}) => RequirementDraft(
    code: code,
    min: min ?? this.min,
    max: max ?? this.max,
    target: target ?? this.target,
    unit: unit,
  );

  Map<String, dynamic> toJson() => {
    'parameterCode': code,
    'minValue': min,
    'maxValue': max,
    'targetValue': target,
    'unit': unit,
  };

  /// Đọc một ngưỡng từ JSON backend (`parameterCode/minValue/maxValue/targetValue/unit`, camelCase; vẫn chấp nhận PascalCase
  /// và `code/min/max/target`). Trả null khi thiếu mã tham số hoặc một trong 3 giá trị không phải số: KHÔNG tự điền số mặc định.
  static RequirementDraft? fromJson(Map<String, dynamic> j) {
    final code = jsonField(j, 'parameterCode') ?? jsonField(j, 'code');
    final min = jsonNumber(jsonField(j, 'minValue') ?? jsonField(j, 'min'));
    final max = jsonNumber(jsonField(j, 'maxValue') ?? jsonField(j, 'max'));
    final target = jsonNumber(jsonField(j, 'targetValue') ?? jsonField(j, 'target'));
    if (code == null || '$code'.trim().isEmpty || min == null || max == null || target == null) return null;
    return RequirementDraft(
      code: '$code'.trim(),
      min: min,
      max: max,
      target: target,
      unit: '${jsonField(j, 'unit') ?? ''}'.trim(),
    );
  }

  /// min ≤ target ≤ max.
  String? validate() {
    if (min > max) return 'Ngưỡng thấp nhất lớn hơn ngưỡng cao nhất.';
    if (target < min || target > max) return 'Giá trị mục tiêu phải nằm giữa ngưỡng thấp nhất và cao nhất.';
    return null;
  }
}

class StageDraft {
  final String stageId;
  final String name;
  final int order;
  final int durationDays;
  final List<RequirementDraft> requirements;

  /// Số ngưỡng backend trả về nhưng không đọc được (thiếu mã tham số hoặc giá trị không phải số).
  final int unreadableRequirements;
  const StageDraft({
    required this.stageId,
    required this.name,
    required this.order,
    required this.durationDays,
    required this.requirements,
    this.unreadableRequirements = 0,
  });

  StageDraft copyWith({int? durationDays, List<RequirementDraft>? requirements}) => StageDraft(
    stageId: stageId,
    name: name,
    order: order,
    durationDays: durationDays ?? this.durationDays,
    requirements: requirements ?? this.requirements,
    unreadableRequirements: unreadableRequirements,
  );

  static StageDraft fromJson(Map<String, dynamic> j) {
    final parsed = <RequirementDraft>[];
    var unreadable = 0;
    for (final r in jsonList(jsonField(j, 'requirements'))) {
      final d = r is Map ? RequirementDraft.fromJson(Map<String, dynamic>.from(r)) : null;
      if (d == null) {
        unreadable++;
      } else {
        parsed.add(d);
      }
    }
    return StageDraft(
      stageId: '${jsonField(j, 'stageId') ?? jsonField(j, 'id') ?? ''}',
      name: '${jsonField(j, 'name') ?? ''}',
      order: jsonNumber(jsonField(j, 'stageOrder') ?? jsonField(j, 'order'))?.toInt() ?? 0,
      durationDays: jsonNumber(jsonField(j, 'durationDays'))?.toInt() ?? 0,
      requirements: parsed,
      unreadableRequirements: unreadable,
    );
  }

  String? validate() {
    if (durationDays < 1 || durationDays > 365) return 'Giai đoạn "$name": số ngày phải từ 1 đến 365.';
    for (final r in requirements) {
      final e = r.validate();
      if (e != null) return 'Giai đoạn "$name" – ${r.code}: $e';
    }
    return null;
  }
}

/// Các ngưỡng đã bị sửa so với bản gốc (so từng mã tham số). Chỉ gửi phần này lên API để không ghi đè ngưỡng không chỉnh
/// (backend cập nhật theo từng mã tham số, ngưỡng không gửi giữ nguyên).
List<RequirementDraft> changedRequirements(List<RequirementDraft> original, List<RequirementDraft> edited) => [
  for (final r in edited)
    if (original.where((o) => o.code == r.code).firstOrNull case final o?
        when o.min != r.min || o.max != r.max || o.target != r.target)
      r,
];

enum ZoneProfileMode { system, custom, none }

/// Lựa chọn cây + hồ sơ của người dùng khi tạo/sửa Zone.
class ZoneCropSelection {
  final String? cropId;
  final String? varietyId;
  final String? profileId; // hồ sơ nguồn (hệ thống) hoặc hồ sơ đang dùng
  final ZoneProfileMode mode;
  final String customName;
  final String customDescription;
  final List<StageDraft> stages; // trạng thái hiện tại (đã gồm chỉnh sửa)
  final List<StageDraft> originalStages; // để chỉ gửi phần thật sự thay đổi

  const ZoneCropSelection({
    this.cropId,
    this.varietyId,
    this.profileId,
    this.mode = ZoneProfileMode.none,
    this.customName = '',
    this.customDescription = '',
    this.stages = const [],
    this.originalStages = const [],
  });

  bool get active => mode != ZoneProfileMode.none && cropId != null;

  int get totalDays => stages.fold(0, (a, s) => a + s.durationDays);

  bool get stagesChanged {
    if (stages.length != originalStages.length) return true;
    for (var i = 0; i < stages.length; i++) {
      final a = stages[i];
      final b = originalStages[i];
      if (a.durationDays != b.durationDays) return true;
      if (_reqChanged(a.requirements, b.requirements)) return true;
    }
    return false;
  }

  ZoneCropSelection copyWith({
    String? cropId,
    String? varietyId,
    String? profileId,
    ZoneProfileMode? mode,
    String? customName,
    String? customDescription,
    List<StageDraft>? stages,
    List<StageDraft>? originalStages,
    bool clearVariety = false,
    bool clearProfile = false,
  }) => ZoneCropSelection(
    cropId: cropId ?? this.cropId,
    varietyId: clearVariety ? null : (varietyId ?? this.varietyId),
    profileId: clearProfile ? null : (profileId ?? this.profileId),
    mode: mode ?? this.mode,
    customName: customName ?? this.customName,
    customDescription: customDescription ?? this.customDescription,
    stages: stages ?? this.stages,
    originalStages: originalStages ?? this.originalStages,
  );
}

bool _reqChanged(List<RequirementDraft> a, List<RequirementDraft> b) {
  if (a.length != b.length) return true;
  for (final x in a) {
    final y = b.where((r) => r.code == x.code).firstOrNull;
    if (y == null || y.min != x.min || y.max != x.max || y.target != x.target) return true;
  }
  return false;
}

/// Kiểm tra trước khi lưu. Trả null nếu hợp lệ (hoặc không áp dụng hồ sơ).
String? validateZoneCropSelection(ZoneCropSelection s) {
  if (s.mode == ZoneProfileMode.none) return null;
  if (s.cropId == null) return 'Chọn cây trồng, hoặc chọn "Không áp dụng hồ sơ".';
  if (s.profileId == null) {
    return 'Cây này chưa có hồ sơ canh tác nào trên hệ thống nên chưa thể áp dụng. Hãy chọn cây khác hoặc không áp dụng hồ sơ.';
  }
  if (s.stages.isEmpty) return 'Hồ sơ đã chọn chưa có giai đoạn nào nên chưa thể áp dụng cho Zone.';
  if (s.mode == ZoneProfileMode.custom) {
    if (s.customName.trim().length < 2) return 'Nhập tên hồ sơ tùy chỉnh (ít nhất 2 ký tự).';
    for (final st in s.stages) {
      final e = st.validate();
      if (e != null) return e;
    }
  }
  return null;
}

/// Payload POST /growth-profiles khi sao chép profile hệ thống sang bản của trang trại.
Map<String, dynamic> buildCloneProfilePayload(ZoneCropSelection s) => {
  'cropId': s.cropId,
  'varietyId': s.varietyId,
  'name': s.customName.trim(),
  if (s.customDescription.trim().isNotEmpty) 'description': s.customDescription.trim(),
  'sourceProfileId': s.profileId,
  'isDefault': false,
};
