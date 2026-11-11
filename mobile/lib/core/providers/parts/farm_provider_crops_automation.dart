part of '../farm_provider.dart';

extension FarmProviderCropsAutomation on FarmProvider {
  /// Gắn hồ sơ canh tác TRỰC TIẾP cho Zone (PUT /zones/{id}); KHÔNG tạo vụ trồng. Trả về lỗi (null nếu thành công).
  /// Tạo vụ là luồng riêng theo Zone (xem create_season_sheet.dart).
  Future<String?> applyCropProfile(String profileId, {String? targetZoneId}) async {
    final profile = defaultCropProfiles.where((p) => p.cropId == profileId).firstOrNull;
    if (profile == null) return 'Không tìm thấy hồ sơ cây trồng.';
    final zId = targetZoneId ?? (_zones.isEmpty ? '' : currentZone.zoneId);
    if (zId.isEmpty) return 'Chưa chọn Zone.';
    final zone = _zones.where((z) => z.zoneId == zId).firstOrNull;
    try {
      await FarmApi.updateZone(
        zId,
        name: zone?.name ?? currentZone.name,
        notes: zone?.notes,
        growthProfileId: profile.profileId,
      );
      _appliedCropId = profileId;
      await fetchFromApi();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<void> loadCropProfiles() async {
    try {
      final r = await Future.wait([CropApi.getGrowthProfiles(), CropApi.getCropsForProfiles()]);
      final cropsById = {for (final c in r[1]) '${c['cropId']}': c};
      final list = [
        for (final p in r[0]) defaultCropProfileFromApi(p, cropsById['${p['cropId']}']),
      ].where((p) => p.growthStages.isNotEmpty).toList();
      defaultCropProfiles
        ..clear()
        ..addAll(list);
      _notify();
    } catch (_) {
      // Giữ danh sách hiện có; lỗi mạng chung đã được báo qua syncError.
    }
  }

  /// Bật/tắt rule qua API. Trả về thông báo lỗi, hoặc null khi thành công.
  Future<String?> toggleAutomationRule(String ruleId) async {
    final rule = _automationRules.firstWhere((r) => r.ruleId == ruleId);
    final raw = rule.raw;
    if (raw == null || rule.zoneId == null) return 'Rule này chưa có trên hệ thống.';
    try {
      await AutomationApi.updateAutoRule(rule.zoneId!, ruleId, {...raw, 'isActive': !rule.isActive});
      rule.isActive = !rule.isActive;
      _notify();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> addAutomationRule(String zoneId, Map<String, dynamic> body) async {
    try {
      await AutomationApi.createAutoRule(zoneId, body);
      await _loadInventoryAndRules();
      _notify();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Cập nhật dải ngưỡng tự động cho Zone và tự động sinh / cập nhật AutoRule tương ứng
  Future<String?> updateZoneThresholds({
    required String zoneId,
    required double maxTemp,
    required double minSoil,
    required double maxSoil,
  }) async {
    try {
      await AutomationApi.updateEnvironmentalThresholds(zoneId, minSoil: minSoil, maxSoil: maxSoil, maxTemp: maxTemp);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
