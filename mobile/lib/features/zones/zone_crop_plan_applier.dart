import '../../core/services/api_service.dart';
import 'zone_crop_plan_logic.dart';

/// Kết quả chuẩn bị hồ sơ để gắn vào Zone. KHÔNG tạo vụ mùa: hồ sơ được gắn trực tiếp vào Zone qua API Zone.
class ZoneProfilePrepareResult {
  final String?
  profileId; // hồ sơ sẽ gắn vào Zone (hệ thống, hoặc bản sao vừa tạo)
  final bool cloned;
  final String?
  error; // lý do dừng giữa chừng; có thể kèm profileId của bản sao đã tạo dở để tiếp tục
  const ZoneProfilePrepareResult({
    this.profileId,
    this.cloned = false,
    this.error,
  });

  bool get ok => error == null && profileId != null;
}

String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

/// Chuẩn bị hồ sơ cho Zone theo lựa chọn:
///  - hồ sơ có sẵn: dùng thẳng mã hồ sơ, không gọi API nào;
///  - tùy chỉnh: sao chép hồ sơ hệ thống thành bản sao của trang trại (backend sao chép luôn lịch tưới), rồi sửa giai đoạn/ngưỡng
///    trên BẢN SAO. [reuseCloneId] là bản sao đã tạo ở lần thử trước (tránh tạo trùng khi người dùng thử lại).
/// Dừng ở bước lỗi đầu tiên và trả lý do kèm bản sao đã tạo dở, không gắn hồ sơ chỉnh dở vào Zone.
Future<ZoneProfilePrepareResult> prepareZoneProfile({
  required ZoneCropSelection selection,
  String? reuseCloneId,
}) async {
  if (!selection.active || selection.profileId == null)
    return const ZoneProfilePrepareResult();
  if (selection.mode != ZoneProfileMode.custom)
    return ZoneProfilePrepareResult(profileId: selection.profileId);

  var profileId = reuseCloneId;
  Map<String, dynamic>? created;
  if (profileId == null) {
    try {
      created = await CropApi.createGrowthProfile(
        buildCloneProfilePayload(selection),
      );
    } catch (e) {
      return ZoneProfilePrepareResult(
        error: 'Không tạo được hồ sơ riêng: ${_msg(e)}',
      );
    }
    profileId = '${created['profileId'] ?? ''}';
    if (profileId.isEmpty) {
      return const ZoneProfilePrepareResult(
        error:
            'Máy chủ không trả mã hồ sơ vừa tạo. Hãy kiểm tra danh sách hồ sơ rồi thử lại.',
      );
    }
  }

  // Bản sao có cùng thứ tự giai đoạn với hồ sơ nguồn; ghép theo thứ tự. Bản sao dùng lại thì đọc lại giai đoạn từ máy chủ.
  List<dynamic> cloneStagesRaw;
  if (created != null) {
    cloneStagesRaw = created['stages'] as List? ?? const [];
  } else {
    try {
      cloneStagesRaw = await CropApi.getGrowthStages(profileId);
    } catch (e) {
      return ZoneProfilePrepareResult(
        profileId: profileId,
        cloned: true,
        error: 'Không đọc được hồ sơ riêng đã tạo: ${_msg(e)}',
      );
    }
  }
  final cloneStages = <int, String>{
    for (final st in cloneStagesRaw)
      if (st is Map)
        (st['stageOrder'] as num?)?.toInt() ?? -1: '${st['stageId']}',
  };
  for (var i = 0; i < selection.stages.length; i++) {
    final edited = selection.stages[i];
    final original = i < selection.originalStages.length
        ? selection.originalStages[i]
        : null;
    final cloneStageId = cloneStages[edited.order];
    if (original == null || cloneStageId == null) continue;
    try {
      if (edited.durationDays != original.durationDays) {
        await CropApi.updateStageDuration(cloneStageId, edited.durationDays);
      }
      final changed = changedRequirements(
        original.requirements,
        edited.requirements,
      );
      if (changed.isNotEmpty) {
        await CropApi.updateStageRequirements(cloneStageId, [
          for (final r in changed) r.toJson(),
        ]);
      }
    } catch (e) {
      return ZoneProfilePrepareResult(
        profileId: profileId,
        cloned: true,
        error:
            'Đã tạo hồ sơ riêng nhưng chưa chỉnh được giai đoạn "${edited.name}": ${_msg(e)}',
      );
    }
  }
  return ZoneProfilePrepareResult(profileId: profileId, cloned: true);
}

/// Gắn / đổi hồ sơ của Zone ĐÃ tồn tại (PUT /zones/{id}), không tạo vụ mùa. Trả null nếu thành công, hoặc lý do.
Future<String?> attachProfileToZone({
  required String zoneId,
  required String zoneName,
  required String profileId,
  String? notes,
}) async {
  try {
    await FarmApi.updateZone(
      zoneId,
      name: zoneName,
      notes: notes,
      growthProfileId: profileId,
    );
    return null;
  } catch (e) {
    return _msg(e);
  }
}

/// Lưu chỉnh sửa trên hồ sơ RIÊNG của trang trại (backend từ chối sửa hồ sơ hệ thống): tên/mô tả, số ngày và ngưỡng từng giai đoạn.
/// Chỉ gọi API cho phần thật sự đổi. Trả null nếu thành công, hoặc lý do dừng (kèm phần đã lưu được).
Future<String?> applyOwnProfileEdits({
  required String profileId,
  required String originalName,
  required String? originalDescription,
  required String name,
  required String? description,
  required List<StageDraft> original,
  required List<StageDraft> edited,
}) async {
  if (name.trim().length < 2) return 'Tên hồ sơ cần ít nhất 2 ký tự.';
  for (final st in edited) {
    final e = st.validate();
    if (e != null) return e;
  }
  final done = <String>[];
  try {
    final desc = (description ?? '').trim();
    if (name.trim() != originalName ||
        desc != (originalDescription ?? '').trim()) {
      await CropApi.updateGrowthProfile(
        profileId,
        name: name.trim(),
        description: desc.isEmpty ? null : desc,
      );
      done.add('tên/mô tả');
    }
    for (final st in edited) {
      final o = original.where((x) => x.stageId == st.stageId).firstOrNull;
      if (o == null) continue;
      if (st.durationDays != o.durationDays) {
        await CropApi.updateStageDuration(st.stageId, st.durationDays);
        done.add('số ngày "${st.name}"');
      }
      final changed = changedRequirements(o.requirements, st.requirements);
      if (changed.isNotEmpty) {
        await CropApi.updateStageRequirements(st.stageId, [
          for (final r in changed) r.toJson(),
        ]);
        done.add('ngưỡng "${st.name}"');
      }
    }
    return null;
  } catch (e) {
    return '${_msg(e)}${done.isEmpty ? '' : ' (đã lưu: ${done.join(', ')})'}';
  }
}
