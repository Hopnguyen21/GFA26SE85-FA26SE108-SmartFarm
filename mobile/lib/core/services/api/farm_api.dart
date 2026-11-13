part of '../api_service.dart';

/// Trang trại, thửa đất, Zone, cảm biến, bản đồ GIS, thời tiết, wizard thiết lập.
abstract final class FarmApi {
  // ─── 2. Farms ────────────────────────────────────────────────────────
  static Future<List<FarmModel>> getFarms() async {
    // Ném lỗi khi mạng/máy chủ lỗi để phân biệt với "tài khoản chưa có trang trại" (danh sách rỗng thật).
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/farms',
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
    return list.map((item) => FarmModel.fromJson(item)).toList();
  }

  // ─── 3. Farm Structure ───────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getFarmStructure(String farmId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/structure',
      );
      if (resp != null && resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
    } catch (_) {}
    return null;
  }

  // ─── 4. Fields ───────────────────────────────────────────────────────
  /// GET /farms/{id}/fields. NÉM lỗi khi không tải được (mạng, 401/403/5xx, JSON hỏng) để UI báo lỗi tải,
  /// thay vì trả danh sách rỗng khiến bản đồ tưởng "chưa có thửa đất".
  static Future<List<FieldModel>> getFields(String farmId) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/fields',
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! List)
      throw Exception('Máy chủ trả dữ liệu thửa đất sai định dạng.');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((i) => FieldModel.fromJson(i, defaultFarmId: farmId))
        .toList();
  }

  // ─── 5. Zones ────────────────────────────────────────────────────────
  static Future<List<ZoneModel>> getZones(
    String fieldId, {
    String farmId = '',
    String farmName = '',
    String fieldName = '',
  }) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/fields/$fieldId/zones',
    );
    if (resp == null || resp.statusCode != 200)
      throw Exception(ApiService._apiErrorMessage(resp));
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is! List)
      throw Exception('Máy chủ trả dữ liệu Zone sai định dạng.');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (i) => ZoneModel.fromJson(
            i,
            farmId: farmId,
            fieldId: fieldId,
            farmName: farmName,
            fieldName: fieldName,
          ),
        )
        .toList();
  }

  // ─── 6. Latest Telemetry ─────────────────────────────────────────────
  static Future<Map<String, double>?> getLatestTelemetry(String zoneId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/telemetry/latest',
      );
      if (resp != null && resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final metrics = data['metrics'] as List<dynamic>?;
        if (metrics != null) {
          final result = <String, double>{
            '__hasFreshTelemetry': data['hasFreshTelemetry'] == true
                ? 1.0
                : 0.0,
          };
          for (var m in metrics) {
            if (m['isFresh'] != true || m['value'] is! num) continue;
            final rawCode = m['parameterCode']?.toString() ?? '';
            final code = rawCode.replaceAll('_', '').toLowerCase();
            final key = switch (code) {
              'temperature' => 'TEMPERATURE',
              'soilmoisture' => 'SOILMOISTURE',
              'airhumidity' => 'AIRHUMIDITY',
              'light' || 'lightintensity' => 'LIGHTINTENSITY',
              'ph' || 'soilph' => 'PH',
              'ec' || 'soilec' => 'EC',
              _ => rawCode.toUpperCase(),
            };
            result[key] = (m['value'] as num).toDouble();
          }
          return result;
        }
      }
    } catch (_) {}
    return null;
  }

  /// GET /zones/{id}/telemetry/latest dạng thô (có capturedAtUtc/isFresh từng số đo). NÉM lỗi (kể cả 401/403) thay vì trả null,
  /// để màn hình phân biệt "chưa có số đo" với "không tải được".
  static Future<Map<String, dynamic>> getZoneTelemetry(String zoneId) async {
    final data = ApiService._decodeUtf8OrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/telemetry/latest',
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ─── 6.5. Zone Actuators ──────────────────────────────────────────────
  static Future<List<ActuatorModel>> getZoneActuators(String zoneId) =>
      fetchZoneActuators(zoneId);

  static Future<List<ActuatorModel>> fetchZoneActuators(String zoneId) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/actuators',
      ),
    );
    return ApiService._asMapList(
      data,
    ).map((m) => ActuatorModel.fromJson(m, defaultZoneId: zoneId)).toList();
  }

  // ─── 6.6. Telemetry History (Database backed) ────────────────────────
  static Future<List<Map<String, dynamic>>> getTelemetryHistory({
    required String zoneId,
    required String parameterCode,
    DateTime? fromUtc,
    DateTime? toUtc,
    String interval = '1h',
  }) async {
    final from =
        (fromUtc ?? DateTime.now().toUtc().subtract(const Duration(hours: 24)))
            .toIso8601String();
    final to = (toUtc ?? DateTime.now().toUtc()).toIso8601String();
    final uri =
        Uri.parse(
          '${ApiService.baseUrl}/api/v1/zones/$zoneId/telemetry/history',
        ).replace(
          queryParameters: {
            'parameterCode': parameterCode,
            'fromUtc': from,
            'toUtc': to,
            'interval': interval,
          },
        );
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(uri.toString()),
    );
    final list = data is Map ? data['data'] : null;
    if (list is! List)
      throw const FormatException('Dữ liệu lịch sử đo không hợp lệ.');
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── 7. Farmers (Users) ──────────────────────────────────────────────
  static Future<List<FarmerModel>> getFarmers() async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/users?role=Farmer',
      );
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((item) => FarmerModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// PUT /zones/{id} (Owner): đổi tên, diện tích, loại, ghi chú, trạng thái, ranh giới GIS.
  static Future<Map<String, dynamic>> updateZone(
    String zoneId, {
    required String name,
    double? areaM2,
    Map<String, dynamic>? polygonGeoJson,
    String? zoneType,
    String? notes,
    String? status,
    String? growthProfileId,
    bool clearGrowthProfile = false,
  }) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId',
        {
          'name': name,
          'areaM2': ?areaM2,
          'polygonGeoJson': ?polygonGeoJson,
          if (zoneType != null && zoneType.isNotEmpty) 'zoneType': zoneType,
          'notes': ?notes,
          'status': ?status,
          'growthProfileId': ?growthProfileId,
          if (clearGrowthProfile) 'clearGrowthProfile': true,
        },
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// DELETE /zones/{id} (Owner): lưu trữ Zone (backend chặn nếu còn vụ đang chạy/thiết bị).
  static Future<void> archiveZone(String zoneId) async {
    ApiService._decodeOrThrow(
      await ApiService._deleteWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId',
      ),
      ok: const {200, 204},
    );
  }

  /// GET /zones/{id}/telemetry/latest-by-device: số đo mới nhất theo từng node.
  static Future<List<Map<String, dynamic>>> getLatestTelemetryByDevice(
    String zoneId,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/telemetry/latest-by-device',
      ),
    );
    if (data is Map && data['devices'] is List)
      return ApiService._asMapList(data['devices']);
    return ApiService._listOf(data);
  }

  /// GET /zones/{id}: thông tin một Zone kèm ranh giới (kỹ thuật viên được giao đọc được dù Zone không nằm trong danh sách trang trại của mình).
  static Future<ZoneModel> getZone(String zoneId) async {
    final data =
        ApiService._decodeOrThrow(
              await ApiService._getWithAuth(
                '${ApiService.baseUrl}/api/v1/zones/$zoneId',
              ),
            )
            as Map<String, dynamic>;
    return ZoneModel.fromJson(
      data,
      farmId: '${data['farmId'] ?? ''}',
      fieldId: '${data['fieldId'] ?? ''}',
    );
  }

  /// GET /zones/{id}/devices/map-locations: toạ độ GIS của từng node.
  static Future<List<Map<String, dynamic>>> getDeviceMapLocations(
    String zoneId,
  ) async => ApiService._listOf(
    ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices/map-locations',
      ),
    ),
  );

  /// PUT /zones/{id}/devices/bulk-locations (Technician/Owner): lưu toạ độ nhiều node một lần.
  static Future<void> updateDeviceLocations(
    String zoneId,
    List<Map<String, dynamic>> nodes, {
    String? serviceRequestId,
    String? deploymentRequestId,
  }) async {
    ApiService._decodeOrThrow(
      await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/zones/$zoneId/devices/bulk-locations',
        {
          'serviceRequestId': serviceRequestId,
          'deploymentRequestId': deploymentRequestId,
          'nodes': nodes,
        },
      ),
      ok: const {200, 204},
    );
  }

  /// POST /farms/wizard-setup (Owner): tạo Farm → Lô → Zone → Vụ trồng → Yêu cầu lắp IoT trong một lần.
  /// Trả về {farmId, fieldId, zoneId, seasonId, deploymentRequestId}.
  static Future<Map<String, dynamic>> farmWizardSetup(
    Map<String, dynamic> payload,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/wizard-setup',
        payload,
        timeout: const Duration(seconds: 30),
      ),
    );
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ─── 22. GIS Geocoding Proxy (Bảo mật định vị & ẩn danh khách hàng) ───────
  /// Reverse geocoding qua backend proxy bằng POST (bảo vệ tọa độ không bị ghi vào reverse proxy access logs)
  static Future<Map<String, dynamic>?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final r = await reverseGeocodeDetailed(latitude, longitude);
    return r.ok ? {'displayName': r.displayName, 'district': r.region} : null;
  }

  /// Như [reverseGeocode] nhưng trả lý do thất bại (mạng/timeout/401/403/404/429/5xx/JSON sai) thay vì nuốt lỗi.
  /// Chỉ gọi qua backend proxy; log chỉ ghi endpoint, trạng thái và loại lỗi (không ghi token hay toạ độ).
  static Future<GeocodeResult> reverseGeocodeDetailed(
    double latitude,
    double longitude,
  ) async {
    const path = '/api/v1/gis/reverse-geocode';
    GeocodeResult result;
    try {
      final resp = await ApiService._postWithAuth(
        '${ApiService.baseUrl}$path',
        {'latitude': latitude, 'longitude': longitude},
      );
      result = resp == null
          ? GeocodeResult.failed(GeocodeFailureKind.network)
          : GeocodeResult.fromHttp(resp.statusCode, resp.bodyBytes);
    } on TimeoutException {
      result = GeocodeResult.failed(GeocodeFailureKind.timeout);
    } on SecurityException {
      result = GeocodeResult.failed(GeocodeFailureKind.network);
    } catch (_) {
      result = GeocodeResult.failed(GeocodeFailureKind.network);
    }
    if (!kReleaseMode && !result.ok) {
      debugPrint(
        '[Geocode] POST ${ApiService.baseUrl}$path → status=${result.statusCode ?? '-'} lỗi=${result.failure?.name}',
      );
    }
    return result;
  }

  /// Tìm kiếm địa danh qua backend proxy bằng POST (bảo vệ query không bị ghi vào reverse proxy access logs)
  /// POST /gis/search-location: tìm địa điểm theo chuỗi. Ném Exception khi backend lỗi (không trả rỗng giả).
  static Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    final data = ApiService._decodeUtf8OrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/gis/search-location',
        {'query': query.trim()},
      ),
    );
    return data is List
        ? data.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
  }

  // ─── 23. Farm Weather (Thời tiết theo vị trí hiệu lực Farm/Field/Zone) ────
  /// Lấy dữ liệu thời tiết trạm địa phương từ backend theo vị trí hiệu lực
  static Future<Map<String, dynamic>?> getFarmWeather(String farmId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/weather',
        timeout: const Duration(seconds: 12),
      );
      if (resp != null && resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─── Tạo Trang trại / Thửa đất / Zone (lưu vào DB qua backend) ─────────
  static Map<String, dynamic> polygonGeoJson(List<List<double>> latLngPoints) {
    final ring = [
      for (final p in latLngPoints) [p[1], p[0]],
    ]; // GeoJSON: [lng, lat]
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(List.of(ring.first));
    }
    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }

  static Future<Map<String, dynamic>> createFarm({
    required String name,
    String? locationText,
    double? latitude,
    double? longitude,
    required double totalAreaM2,
  }) async {
    final resp =
        await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/farms', {
          'name': name,
          'locationText': ?locationText,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'totalAreaM2': totalAreaM2,
          'timeZone': 'Asia/Ho_Chi_Minh',
        });
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateFarm(
    String farmId, {
    required String name,
    String? locationText,
    double? latitude,
    double? longitude,
    required double totalAreaM2,
    String timeZone = 'Asia/Ho_Chi_Minh',
  }) async {
    final resp = await ApiService._putWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId',
      {
        'name': name,
        'locationText': ?locationText,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'totalAreaM2': totalAreaM2,
        'timeZone': timeZone,
      },
    );
    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createField({
    required String farmId,
    required String name,
    required double areaM2,
    required Map<String, dynamic> boundaryGeoJson,
    double? latitude,
    double? longitude,
  }) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/fields',
      {
        'name': name,
        'areaM2': areaM2,
        'boundaryGeoJson': boundaryGeoJson,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createZone({
    required String fieldId,
    required String name,
    required double areaM2,
    required Map<String, dynamic> polygonGeoJson,
    String zoneType = 'Greenhouse',
    String? notes,
    String? growthProfileId,
  }) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/fields/$fieldId/zones',
      {
        'name': name,
        'areaM2': areaM2,
        'polygonGeoJson': polygonGeoJson,
        'zoneType': zoneType,
        'notes': ?notes,
        // Hồ sơ gắn trực tiếp với Zone ngay khi tạo (không tạo vụ mùa).
        'growthProfileId': ?growthProfileId,
      },
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }
}
