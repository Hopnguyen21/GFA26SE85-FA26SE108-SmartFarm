import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import 'profile_irrigation_logic.dart';
import 'zone_crop_plan_logic.dart';

/// Tải và giữ trạng thái chọn cây/giống/hồ sơ cho form Zone. Dữ liệu hoàn toàn từ API (không có cây/hồ sơ mẫu).
class ZoneCropPlanController extends ChangeNotifier {
  /// Tách hàm gọi API để test được mà không cần mạng.
  final Future<List<Map<String, dynamic>>> Function() fetchCrops;
  final Future<List<Map<String, dynamic>>> Function(String cropId) fetchVarieties;
  final Future<List<Map<String, dynamic>>> Function(String cropId) fetchProfiles;
  final Future<Map<String, dynamic>> Function(String profileId) fetchIrrigation;

  ZoneCropPlanController({
    Future<List<Map<String, dynamic>>> Function()? fetchCrops,
    Future<List<Map<String, dynamic>>> Function(String cropId)? fetchVarieties,
    Future<List<Map<String, dynamic>>> Function(String cropId)? fetchProfiles,
    Future<Map<String, dynamic>> Function(String profileId)? fetchIrrigation,
  }) : fetchCrops = fetchCrops ?? CropApi.getCropsForProfiles,
       fetchVarieties = fetchVarieties ?? ((id) => CropApi.getVarieties(cropId: id)),
       fetchProfiles = fetchProfiles ?? CropApi.getCropGrowthProfiles,
       fetchIrrigation = fetchIrrigation ?? CropApi.getProfileIrrigation;

  ZoneCropSelection selection = const ZoneCropSelection();
  bool _disposed = false;

  bool loadingCrops = false;
  String? cropsError;
  List<Map<String, dynamic>> crops = [];

  bool loadingDetail = false;
  String? detailError;
  List<Map<String, dynamic>> varieties = [];
  List<Map<String, dynamic>> allProfiles = [];

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> loadCrops() async {
    loadingCrops = true;
    cropsError = null;
    notifyListeners();
    try {
      crops = await fetchCrops();
    } catch (e) {
      cropsError = _err(e);
    } finally {
      loadingCrops = false;
      notifyListeners();
    }
  }

  Map<String, dynamic>? get currentCrop => crops.where((c) => '${c['cropId']}' == selection.cropId).firstOrNull;

  /// Hồ sơ dùng được cho cây + giống đang chọn, theo đúng quy tắc backend:
  ///  - hồ sơ CHUNG (varietyId == null) dùng được cho mọi giống của cây (và khi chưa chọn giống);
  ///  - hồ sơ RIÊNG giống chỉ dùng khi đúng giống đó được chọn.
  List<Map<String, dynamic>> get profiles {
    final v = selection.varietyId;
    return [
      for (final p in allProfiles)
        if (p['varietyId'] == null || (v != null && '${p['varietyId']}' == v)) p,
    ];
  }

  /// Hồ sơ đang chọn là hồ sơ chung trong khi người dùng đã chọn một giống cụ thể: Zone sẽ không gắn giống đó.
  bool get genericProfileDropsVariety =>
      selection.varietyId != null && currentProfile != null && currentProfile!['varietyId'] == null;

  Map<String, dynamic>? get currentProfile =>
      profiles.where((p) => '${p['profileId']}' == selection.profileId).firstOrNull;

  bool get currentProfileIsSystem => currentProfile?['isSystemDefined'] == true;

  /// Lịch tưới của hồ sơ đang chọn, đọc từ backend (theo giai đoạn; nguồn Profile/Crop/None).
  ProfileSchedule? irrigation;
  String? irrigationError;
  bool loadingIrrigation = false;

  Future<void> _loadIrrigation(String? profileId) async {
    irrigation = null;
    irrigationError = null;
    if (profileId == null) {
      loadingIrrigation = false;
      return;
    }
    loadingIrrigation = true;
    notifyListeners();
    try {
      final json = await fetchIrrigation(profileId);
      if (selection.profileId != profileId) return; // đã chọn hồ sơ khác
      irrigation = ProfileSchedule.fromJson(json);
    } catch (e) {
      if (selection.profileId == profileId) irrigationError = _err(e);
    } finally {
      if (selection.profileId == profileId) {
        loadingIrrigation = false;
        notifyListeners();
      }
    }
  }

  Future<void> chooseCrop(String? cropId) async {
    selection = ZoneCropSelection(
      cropId: cropId,
      mode: selection.mode == ZoneProfileMode.none ? ZoneProfileMode.system : selection.mode,
    );
    varieties = [];
    allProfiles = [];
    detailError = null;
    if (cropId == null) {
      notifyListeners();
      return;
    }
    loadingDetail = true;
    notifyListeners();
    try {
      final results = await Future.wait([fetchVarieties(cropId), fetchProfiles(cropId)]);
      if (selection.cropId != cropId) return; // người dùng đã đổi sang cây khác
      varieties = results[0];
      allProfiles = results[1];
      _autoPickProfile();
    } catch (e) {
      detailError = _err(e);
    } finally {
      loadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> chooseVariety(String? varietyId) async {
    final cropId = selection.cropId;
    selection = selection.copyWith(
      clearVariety: varietyId == null,
      varietyId: varietyId,
      clearProfile: true,
      stages: const [],
      originalStages: const [],
      mode: selection.mode == ZoneProfileMode.custom ? ZoneProfileMode.system : null,
    );
    irrigation = null;
    irrigationError = null;
    detailError = null;
    if (cropId == null) {
      notifyListeners();
      return;
    }
    loadingDetail = true;
    notifyListeners();
    try {
      final fresh = await fetchProfiles(cropId);
      if (selection.cropId != cropId || selection.varietyId != varietyId) return; // người dùng đã đổi lựa chọn
      allProfiles = fresh;
      _autoPickProfile();
    } catch (e) {
      detailError = _err(e);
    } finally {
      loadingDetail = false;
      notifyListeners();
    }
  }

  /// KHÔNG tự chọn hồ sơ nào: người dùng phải xem chi tiết rồi bấm "Áp dụng" ([chooseProfile]) mới có hồ sơ được chọn.
  void _autoPickProfile() {
    selection = selection.copyWith(clearProfile: true, stages: const [], originalStages: const []);
  }

  /// Giống đang chọn (null nếu không chọn giống).
  Map<String, dynamic>? get currentVariety =>
      varieties.where((v) => '${v['varietyId']}' == selection.varietyId).firstOrNull;

  /// Tên giống của một hồ sơ (null nếu hồ sơ dùng chung).
  String? varietyNameOf(Map<String, dynamic> p) {
    final id = p['varietyId'];
    if (id == null) return null;
    final v = varieties.where((x) => '${x['varietyId']}' == '$id').firstOrNull;
    return '${v?['name'] ?? p['varietyName'] ?? ''}'.trim().isEmpty ? null : '${v?['name'] ?? p['varietyName']}';
  }

  void chooseProfile(String? profileId, {bool notify = true}) {
    final p = profiles.where((x) => '${x['profileId']}' == profileId).firstOrNull;
    final stages = [
      for (final s in (p?['stages'] as List? ?? const []))
        if (s is Map) StageDraft.fromJson(Map<String, dynamic>.from(s)),
    ]..sort((a, b) => a.order.compareTo(b.order));
    selection = selection.copyWith(
      profileId: profileId,
      clearProfile: profileId == null,
      stages: stages,
      originalStages: stages,
      // Hồ sơ riêng của trang trại không sao chép tiếp được (backend chỉ cho sao chép hồ sơ hệ thống).
      mode: (selection.mode == ZoneProfileMode.custom && p?['isSystemDefined'] != true) ? ZoneProfileMode.system : null,
    );
    if (notify) notifyListeners();
    unawaited(_loadIrrigation(profileId));
  }

  void setMode(ZoneProfileMode mode) {
    if (mode == ZoneProfileMode.custom && !currentProfileIsSystem) return;
    selection = selection.copyWith(
      mode: mode,
      customName: mode == ZoneProfileMode.custom && selection.customName.isEmpty
          ? '${currentProfile?['name'] ?? 'Hồ sơ'} - bản của trang trại'
          : null,
    );
    if (mode == ZoneProfileMode.none) {
      selection = const ZoneCropSelection();
      varieties = [];
      allProfiles = [];
    } else if (selection.cropId == null) {
      // chưa chọn cây
    }
    notifyListeners();
  }

  void setCustomName(String v) {
    selection = selection.copyWith(customName: v);
  }

  void setCustomDescription(String v) {
    selection = selection.copyWith(customDescription: v);
  }

  void setStageDuration(int index, int days) {
    final list = [...selection.stages];
    list[index] = list[index].copyWith(durationDays: days);
    selection = selection.copyWith(stages: list);
    notifyListeners();
  }

  void setRequirement(int stageIndex, String code, {double? min, double? max, double? target}) {
    final list = [...selection.stages];
    final reqs = [
      for (final r in list[stageIndex].requirements)
        if (r.code == code) r.copyWith(min: min, max: max, target: target) else r,
    ];
    list[stageIndex] = list[stageIndex].copyWith(requirements: reqs);
    selection = selection.copyWith(stages: list);
    notifyListeners();
  }

  /// Kiểm tra toàn bộ trước khi lưu Zone.
  String? validate() {
    if (selection.mode != ZoneProfileMode.none &&
        selection.cropId != null &&
        selection.profileId == null &&
        profiles.isNotEmpty) {
      return 'Chưa chọn hồ sơ canh tác. Bấm "Xem chi tiết" ở một hồ sơ rồi "Áp dụng profile này cho Zone", hoặc chọn "Không áp dụng".';
    }
    return validateZoneCropSelection(selection);
  }
}
