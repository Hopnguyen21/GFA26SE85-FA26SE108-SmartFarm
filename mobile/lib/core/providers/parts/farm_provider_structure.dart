part of '../farm_provider.dart';

extension FarmProviderStructure on FarmProvider {
  Future<void> fetchWeatherForCurrentFarm() async {
    if (_selectedFarmId.isEmpty) return;
    _isLoadingWeather = true;
    _notify();
    try {
      _farmWeather = await FarmApi.getFarmWeather(_selectedFarmId);
    } catch (_) {
      _farmWeather = null;
    } finally {
      _isLoadingWeather = false;
      _notify();
    }
  }

  void selectFarm(String farmId) {
    if (_selectedFarmId != farmId) {
      _selectedFarmId = farmId;
      _selectedFieldId = null; // reset field filter when changing farm
      _selectedZoneIndex = 0;
      _notify();
      if (_isApiConnected) {
        fetchFromApi();
      }
    }
  }

  void selectField(String? fieldId) {
    _selectedFieldId = fieldId;
    _selectedZoneIndex = 0;
    _notify();
  }

  void selectZone(int index) {
    if (index >= 0 && index < _zones.length) {
      _selectedZoneIndex = index;
      _notify();
      refreshCurrentZoneActuators();
    }
  }

  /// Tải lại thiết bị chấp hành của một Zone: [zoneId] nếu có (vd. Zone Detail đang mở), mặc định là Zone đang chọn.
  Future<void> refreshCurrentZoneActuators({String? zoneId}) async {
    if (!_isApiConnected || _zones.isEmpty) return;
    try {
      final curZ = zoneId == null
          ? currentZone
          : _zones.firstWhere(
              (z) => z.zoneId.toLowerCase() == zoneId.toLowerCase(),
              orElse: () => currentZone,
            );
      final zIdLower = curZ.zoneId.toLowerCase();
      try {
        final zoneActs = await FarmApi.fetchZoneActuators(curZ.zoneId);
        _actuators.removeWhere((a) => a.zoneId.toLowerCase() == zIdLower);
        _actuators.addAll(zoneActs);
        _actuatorErrors.remove(zIdLower);
      } catch (e) {
        // Giữ danh sách cũ và ghi nhận lỗi để giao diện báo "không tải được" thay vì "chưa có thiết bị".
        _actuatorErrors[zIdLower] = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      }
      _notify();
    } catch (_) {}
  }

  /// Tạo trang trại thật qua API rồi đồng bộ lại; trả về thông báo lỗi (null nếu thành công).
  /// Giữ cho nơi gọi cũ; luồng mới dùng [createFarm] để phân biệt "đã tạo" với "tải lại lỗi".
  Future<String?> addFarm({
    required String name,
    required String address,
    required double totalAreaM2,
    double? latitude,
    double? longitude,
  }) async {
    final r = await createFarm(
      name: name,
      address: address,
      totalAreaM2: totalAreaM2,
      latitude: latitude,
      longitude: longitude,
    );
    return r.error;
  }

  /// Tạo Farm trên server. Thành công chỉ khi server trả mã Farm hợp lệ. Sau khi tạo, chọn đúng Farm mới rồi tải lại;
  /// nếu tải lại lỗi thì Farm vẫn là "đã tạo" ([FarmCreateResult.refreshFailed]) và giữ mã Farm vừa tạo.
  Future<FarmCreateResult> createFarm({
    required String name,
    required String address,
    required double totalAreaM2,
    double? latitude,
    double? longitude,
  }) async {
    if (_creatingFarm)
      return const FarmCreateResult(
        error: 'Đang tạo trang trại, vui lòng chờ.',
      );
    final addr = address.trim();
    if (addr.isEmpty)
      return const FarmCreateResult(
        error: 'Cần có địa chỉ thực địa của trang trại.',
      );
    _creatingFarm = true;
    try {
      Map<String, dynamic> created;
      try {
        created = await FarmApi.createFarm(
          name: name,
          locationText: addr,
          latitude: latitude,
          longitude: longitude,
          totalAreaM2: totalAreaM2,
        );
      } catch (e) {
        return FarmCreateResult(
          error: e.toString().replaceFirst('Exception: ', ''),
        );
      }
      final id = parseCreatedFarmId(created);
      if (id == null) {
        return const FarmCreateResult(
          error:
              'Máy chủ không trả mã trang trại hợp lệ. Hãy tải lại danh sách để kiểm tra trước khi tạo lại, tránh tạo trùng.',
        );
      }
      _selectedFarmId = id;
      _selectedFieldId = null;
      _selectedZoneIndex = 0;
      await fetchFromApi(); // fetchFromApi không ném lỗi: kết quả nằm ở syncError
      String? refreshError = _syncError;
      if (refreshError == null &&
          !_farms.any((f) => f.farmId.toLowerCase() == id.toLowerCase())) {
        refreshError = 'Trang trại vừa tạo chưa xuất hiện trong danh sách.';
      }
      if (refreshError == null)
        _selectedFarmId = _farms
            .firstWhere((f) => f.farmId.toLowerCase() == id.toLowerCase())
            .farmId;
      return FarmCreateResult(farmId: id, refreshError: refreshError);
    } finally {
      _creatingFarm = false;
    }
  }

  /// Tạo thửa đất thật qua API (bắt buộc có ranh giới); trả về thông báo lỗi (null nếu thành công).
  Future<String?> addField({
    required String farmId,
    required String name,
    required String description,
    required double areaM2,
    List<LatLng>? polygon,
  }) async {
    if (polygon == null || polygon.length < 3)
      return 'Cần vẽ ranh giới thửa đất trên bản đồ (tối thiểu 3 điểm).';
    try {
      final targetFarm =
          _farms.where((f) => f.farmId == farmId).firstOrNull ??
          (farmId == currentFarm.farmId ? currentFarm : null);
      final currentAllocated = _fields
          .where((f) => f.farmId == farmId)
          .fold<double>(0.0, (sum, f) => sum + f.areaM2);
      final requiredTotal = currentAllocated + areaM2;

      // Tự động mở rộng diện tích nông trại nếu tổng diện tích thửa đất vượt quá
      if (targetFarm != null && targetFarm.totalAreaM2 < requiredTotal) {
        final newFarmArea = (requiredTotal * 1.5).clamp(10000.0, 1000000.0);
        try {
          await FarmApi.updateFarm(
            farmId,
            name: targetFarm.name,
            locationText: targetFarm.address.isEmpty
                ? null
                : targetFarm.address,
            latitude: targetFarm.latitude != 0 ? targetFarm.latitude : null,
            longitude: targetFarm.longitude != 0 ? targetFarm.longitude : null,
            totalAreaM2: newFarmArea,
          );
        } catch (_) {}
      }

      Map<String, dynamic> created;
      try {
        created = await FarmApi.createField(
          farmId: farmId,
          name: name,
          areaM2: areaM2,
          boundaryGeoJson: FarmApi.polygonGeoJson([
            for (final p in polygon) [p.latitude, p.longitude],
          ]),
        );
      } catch (e) {
        if (e.toString().contains('exceeds the Farm area') &&
            targetFarm != null) {
          final fallbackArea = (requiredTotal + 50000.0).clamp(
            50000.0,
            1000000.0,
          );
          await FarmApi.updateFarm(
            farmId,
            name: targetFarm.name,
            locationText: targetFarm.address.isEmpty
                ? null
                : targetFarm.address,
            latitude: targetFarm.latitude != 0 ? targetFarm.latitude : null,
            longitude: targetFarm.longitude != 0 ? targetFarm.longitude : null,
            totalAreaM2: fallbackArea,
          );
          created = await FarmApi.createField(
            farmId: farmId,
            name: name,
            areaM2: areaM2,
            boundaryGeoJson: FarmApi.polygonGeoJson([
              for (final p in polygon) [p.latitude, p.longitude],
            ]),
          );
        } else {
          rethrow;
        }
      }

      final id = '${created['fieldId'] ?? created['id'] ?? ''}';
      if (id.isNotEmpty) _selectedFieldId = id;
      await fetchFromApi();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Tạo Zone thật qua API (bắt buộc có thửa đất và ranh giới); trả về thông báo lỗi (null nếu thành công).
  /// Cây trồng không gắn khi tạo Zone: backend gán cây thông qua Vụ mùa (Farming Season).
  /// Tạo Zone trên máy chủ. Nếu chọn nhân công thì cấp quyền xem/nhận việc Zone mới cho họ (PUT /users/{id}/zone-access,
  /// giữ nguyên các Zone họ đã có). Trả về error khi tạo thất bại, warning khi Zone đã tạo nhưng chưa gán được nhân công.
  Future<({String? error, String? warning, String? zoneId})> addNewZone({
    required String name,
    required double areaM2,
    String? assignFarmerId,
    String? customFieldId,
    List<LatLng>? polygon,
    String? growthProfileId,
  }) async {
    final fieldId =
        customFieldId ??
        _selectedFieldId ??
        fieldsForCurrentFarm.firstOrNull?.fieldId;
    if (fieldId == null || fieldId.isEmpty) {
      return (
        error: 'Chưa có thửa đất để tạo Zone.',
        warning: null,
        zoneId: null,
      );
    }
    if (polygon == null || polygon.length < 3) {
      return (
        error: 'Cần vẽ ranh giới Zone trên bản đồ (tối thiểu 3 điểm).',
        warning: null,
        zoneId: null,
      );
    }
    final String? zoneId;
    try {
      final created = await FarmApi.createZone(
        fieldId: fieldId,
        name: name,
        areaM2: areaM2,
        polygonGeoJson: FarmApi.polygonGeoJson([
          for (final p in polygon) [p.latitude, p.longitude],
        ]),
        growthProfileId: growthProfileId,
      );
      zoneId = created['zoneId']?.toString();
    } catch (e) {
      return (
        error: e.toString().replaceFirst('Exception: ', ''),
        warning: null,
        zoneId: null,
      );
    }

    String? warning;
    if (assignFarmerId != null && zoneId != null) {
      final farmer = _farmers
          .where((f) => f.farmerId == assignFarmerId)
          .firstOrNull;
      try {
        await AccountApi.updateFarmerZoneAccess(assignFarmerId, [
          for (final z in farmer?.zoneAccess ?? const <ZoneAccessItem>[])
            {'zoneId': z.zoneId, 'canControl': z.canControl},
          {'zoneId': zoneId, 'canControl': false},
        ]);
      } catch (e) {
        warning =
            'Chưa gán được nhân công: ${e.toString().replaceFirst('Exception: ', '')}';
      }
    }
    await fetchFromApi();
    return (error: null, warning: warning, zoneId: zoneId);
  }
}

/// Kết quả tạo Farm. `error != null` = chưa tạo được. `refreshError != null` = ĐÃ tạo nhưng tải lại danh sách lỗi.
class FarmCreateResult {
  final String? farmId;
  final String? error;
  final String? refreshError;
  const FarmCreateResult({this.farmId, this.error, this.refreshError});

  bool get created => error == null && farmId != null;
  bool get refreshFailed => created && refreshError != null;
}

/// Lấy mã Farm từ phản hồi tạo Farm; null nếu thiếu, rỗng hoặc là GUID rỗng.
String? parseCreatedFarmId(Map<String, dynamic> created) {
  final raw =
      (created['farmId'] ?? created['FarmId'] ?? created['id'] ?? created['Id'])
          ?.toString()
          .trim();
  if (raw == null ||
      raw.isEmpty ||
      raw == 'null' ||
      raw == '00000000-0000-0000-0000-000000000000')
    return null;
  return raw;
}
