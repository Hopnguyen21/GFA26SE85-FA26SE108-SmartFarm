part of '../zone_detail_screen.dart';

extension _ZoneDetailScreenStateClimate on _ZoneDetailScreenState {
  // ─── Tab 1: Vi khí hậu ───────────────────────────────────────
  Widget _buildClimateTab(ZoneModel zone, FarmProvider provider) {
    final isFarmer = provider.currentRole == 'FARMER';
    // Telemetry của CHÍNH Zone đang mở (theo zoneId) + ngưỡng của hồ sơ gắn cho Zone; GIS đặt ở cuối tab.
    return ZoneClimatePanel(
      key: ValueKey('climate_${zone.zoneId}'),
      zone: zone,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thẻ so sánh Vi khí hậu Zone & Thời tiết ngoài trời
          _buildZoneWeatherComparisonCard(zone, provider),
          const SizedBox(height: 12),
          // Thẻ khuyến nghị AI Nông học của Zone (chỉ FarmOwner quản lý & duyệt)
          if (!isFarmer) ...[
            ZoneAiAdviceCard(
              key: ValueKey('zone_ai_${zone.zoneId}'),
              zoneId: zone.zoneId,
            ),
            const SizedBox(height: 12),
          ],
          // Quy tắc cảnh báo an toàn + nhật ký cảnh báo của Zone (chỉ Owner/KTV quản lý, ẩn với Farmer).
          if (!isFarmer) ...[
            OutlinedButton.icon(
              key: const Key('open_alert_center'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: const Color(0xFF15803D),
                side: const BorderSide(color: Color(0xFF15803D), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: const Color(0xFFF0FDF4),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ZoneAlertCenterScreen(zone: zone),
                ),
              ),
              icon: const Icon(Icons.notifications_active_outlined, size: 19),
              label: const Text(
                'Cảnh báo & quy tắc của Zone',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildZoneGisSection(zone),
        ],
      ),
    );
  }

  /// Thẻ so sánh Vi khí hậu bên trong nhà màng với Thời tiết ngoài trời của Farm,
  /// tính toán độ chênh lệch nhiệt ẩm (ΔT, ΔH) và cảnh báo quy tắc hoãn tưới khi mưa (BR-AUTOMATION-01).
  Widget _buildZoneWeatherComparisonCard(
    ZoneModel zone,
    FarmProvider provider,
  ) {
    final weather = provider.weatherModel;
    final outTemp = weather?.temperature?.toDouble();
    final outHumidity = weather?.humidity?.toDouble();
    final inTemp = zone.currentTemp;
    final inHumidity = zone.currentHumidity;
    final hasOutdoorWeather = weather != null;
    final hasIndoorTelemetry = inTemp > 0 || inHumidity > 0;

    final deltaTemp =
        (hasOutdoorWeather &&
            outTemp != null &&
            hasIndoorTelemetry &&
            inTemp > 0)
        ? (inTemp - outTemp)
        : null;
    final deltaHumidity =
        (hasOutdoorWeather &&
            outHumidity != null &&
            hasIndoorTelemetry &&
            inHumidity > 0)
        ? (inHumidity - outHumidity)
        : null;

    final rainProb = weather?.precipitationProbability?.toInt() ?? 0;
    final isRainDelay = weather?.triggersRainDelay ?? (rainProb >= 70);

    return Container(
      key: const Key('zone_weather_comparison_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  weather?.icon ?? Icons.cloud_outlined,
                  size: 18,
                  color: weather?.iconColor ?? const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thời tiết & Vi khí hậu Zone',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      weather != null
                          ? '${weather.weatherDescription} · Ngoài trời ${weather.formattedTemp}'
                          : 'Đang tải dữ liệu thời tiết...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (weather?.isRainRisk == true || isRainDelay)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isRainDelay
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRainDelay
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRainDelay
                            ? Icons.thunderstorm_rounded
                            : Icons.water_drop,
                        size: 12,
                        color: isRainDelay
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRainDelay ? 'Hoãn tưới BR-01' : 'Mưa $rainProb%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isRainDelay
                              ? const Color(0xFFDC2626)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Bảng so sánh 2 cột: Trong nhà màng vs Ngoài trời
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Cột trong nhà màng
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.home_outlined,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Trong nhà màng',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${inTemp > 0 ? inTemp.toStringAsFixed(1) : '--'}°C',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Độ ẩm KK: ${inHumidity > 0 ? inHumidity.toInt() : '--'}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'Độ ẩm đất: ${zone.currentSoilMoisture > 0 ? zone.currentSoilMoisture.toInt() : '--'}%',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 60, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 12),
                // Cột ngoài trời
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.wb_cloudy_outlined,
                            size: 14,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Ngoài trời',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weather?.formattedTemp ?? '--°C',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Độ ẩm: ${weather?.formattedHumidity ?? '--'}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        'Mưa: ${weather?.formattedRain ?? '--'} · Gió: ${weather?.formattedWind ?? '--'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (deltaTemp != null || deltaHumidity != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (deltaTemp != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        deltaTemp >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 13,
                        color: deltaTemp >= 0
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'ΔT: ${deltaTemp >= 0 ? '+' : ''}${deltaTemp.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: deltaTemp >= 0
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                if (deltaHumidity != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        deltaHumidity >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 13,
                        color: deltaHumidity >= 0
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'ΔH: ${deltaHumidity >= 0 ? '+' : ''}${deltaHumidity.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: deltaHumidity >= 0
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (isRainDelay) ...[
            const SizedBox(height: 10),
            Container(
              key: const Key('zone_weather_rain_delay_banner'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BR-AUTOMATION-01: Xác suất mưa ngoài trời ($rainProb% ≥ 70%) sẽ kích hoạt hoãn các chu kỳ tưới tự động của Zone để tránh ngập úng.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Ô vuông nhỏ (~25 m) quanh [c] để Owner kéo các đỉnh khi vẽ ranh giới Zone lần đầu.
  List<LatLng> _defaultZoneBox(LatLng c) {
    const d = 0.00012;
    return [
      LatLng(c.latitude + d, c.longitude - d),
      LatLng(c.latitude + d, c.longitude + d),
      LatLng(c.latitude - d, c.longitude + d),
      LatLng(c.latitude - d, c.longitude - d),
    ];
  }

  Widget _buildZoneGisSection(ZoneModel zone) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    // Chỉ Owner được sửa ranh giới (backend: PUT /zones/{id} chỉ cho FarmOwner).
    final canEdit = provider.currentRole == 'OWNER';
    // Không bịa ranh giới: Zone chưa có polygon thì để trống cho tới khi Owner vẽ.
    final savedPolygon = zone.polygon ?? const <LatLng>[];
    final effectivePolygon = _editedPolygon ?? savedPolygon;
    final hasPolygon = effectivePolygon.length >= 3;
    // Vị trí thật của trang trại, dùng làm điểm bắt đầu khi vẽ ranh giới lần đầu.
    final farm = provider.farms
        .where((f) => f.farmId == zone.farmId)
        .firstOrNull;
    final farmLatLng =
        (farm == null || (farm.latitude == 0 && farm.longitude == 0))
        ? null
        : LatLng(farm.latitude, farm.longitude);
    final fieldPolygon = provider.fields
        .where((field) => field.fieldId == zone.fieldId)
        .firstOrNull
        ?.polygon;
    final center = savedPolygon.length >= 3
        ? LatLngBounds.fromPoints(savedPolygon).center
        : fieldPolygon != null && fieldPolygon.length >= 3
        ? LatLngBounds.fromPoints(fieldPolygon).center
        : farmLatLng;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header matching FE
          // Tiêu đề trên, nút thao tác dưới: không bị ép hẹp ở màn nhỏ/chữ lớn.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF062326),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vị trí GIS Map của Nhà màng này',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isEditingGis
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _isEditingGis
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isEditingGis
                                    ? Icons.edit_location_alt_rounded
                                    : Icons.lock_outline_rounded,
                                size: 10,
                                color: _isEditingGis
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF047857),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  _isEditingGis
                                      ? 'Đang sửa ranh giới'
                                      : 'Cố định (Chỉ xem)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isEditingGis
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          hasPolygon
                              ? '• ${effectivePolygon.length} tọa độ đỉnh'
                              : (zone.boundaryProblem != null
                                    ? '• Ranh giới lỗi: ${zone.boundaryProblem}'
                                    : '• Zone chưa có ranh giới GIS'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_isEditingGis)
                Wrap(
                  spacing: 4,
                  children: [
                    OutlinedButton(
                      onPressed: _isSavingGis
                          ? null
                          : () {
                              _rebuild(() {
                                _isEditingGis = false;
                                _editedPolygon = null;
                              });
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isSavingGis
                          ? null
                          : () async {
                              final pts = _editedPolygon;
                              final messenger = ScaffoldMessenger.of(context);
                              if (pts == null || pts.length < 3) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ranh giới cần ít nhất 3 đỉnh.',
                                    ),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                              // Chặn trước khi gọi API: nằm trọn trong Field mẹ và không đè Zone khác.
                              final boundaryErr =
                                  MiniGISMapPicker.validateBoundary(
                                    pts,
                                    parentPolygon: fieldPolygon,
                                    existingPolygons: [
                                      for (final other in provider.allZones)
                                        if (other.zoneId != zone.zoneId &&
                                            other.fieldId == zone.fieldId &&
                                            other.polygon != null)
                                          {
                                            'name': other.name,
                                            'polygon': other.polygon,
                                          },
                                    ],
                                  );
                              if (boundaryErr != null) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('⚠️ $boundaryErr'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                              _rebuild(() => _isSavingGis = true);
                              try {
                                // Chỉ cập nhật bản đồ khi máy chủ xác nhận đã lưu.
                                // Gửi kèm diện tích tính từ ranh giới mới (backend không tự tính lại): nếu không,
                                // Zone vẽ lại to/nhỏ hơn vẫn mang diện tích cũ (dùng cho dự toán thiết bị, AI…).
                                await FarmApi.updateZone(
                                  zone.zoneId,
                                  name: zone.name,
                                  notes: zone.notes,
                                  areaM2: polygonAreaM2(pts).roundToDouble(),
                                  polygonGeoJson: FarmApi.polygonGeoJson([
                                    for (final p in pts)
                                      [p.latitude, p.longitude],
                                  ]),
                                );
                                if (!mounted) return;
                                provider.updateZonePolygon(zone.zoneId, pts);
                                // Tải lại Zone từ máy chủ để hiển thị đúng dữ liệu đã lưu (cùng zoneId).
                                await provider.fetchFromApi();
                                if (!mounted) return;
                                _rebuild(() {
                                  _isSavingGis = false;
                                  _isEditingGis = false;
                                  _editedPolygon = null;
                                });
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã lưu ranh giới GIS của Zone.',
                                    ),
                                    backgroundColor: Color(0xFF047857),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } catch (e) {
                                if (mounted)
                                  _rebuild(() => _isSavingGis = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Không lưu được ranh giới: ${userFacingError(e)}',
                                    ),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                      icon: _isSavingGis
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 13),
                      label: const Text(
                        'Lưu GIS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                )
              else if (canEdit && center != null)
                OutlinedButton.icon(
                  onPressed: () {
                    // Bắt đầu tại vị trí thửa đất nếu Zone chưa có ranh giới.
                    final start = hasPolygon
                        ? List<LatLng>.from(effectivePolygon)
                        : _defaultZoneBox(center);
                    _rebuild(() {
                      _isEditingGis = true;
                      _editedPolygon = start;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã mở chế độ Sửa GIS: Chạm đỉnh để chọn, chạm vị trí mới để dời đỉnh hoặc xóa đỉnh.',
                        ),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFF062326),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.edit_location_alt,
                    size: 13,
                    color: Color(0xFF062326),
                  ),
                  label: Text(
                    hasPolygon ? 'Sửa GIS' : 'Vẽ ranh giới',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062326),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // MiniGIS Map Picker embedded (chỉ khi có dữ liệu thật để hiển thị)
          if (center == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Zone chưa có ranh giới GIS và trang trại chưa có toạ độ. Hãy cập nhật vị trí trang trại trước.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else if (!hasPolygon)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                canEdit
                    ? 'Zone chưa có ranh giới GIS. Bấm "Vẽ ranh giới" để bắt đầu từ vị trí trang trại.'
                    : 'Zone chưa có ranh giới GIS. Chủ trang trại có thể vẽ ranh giới cho Zone này.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MiniGISMapPicker(
                key: ValueKey(
                  'zone_gis_${zone.zoneId}_${_isEditingGis}_${_nodeMarkers.length}',
                ),
                initialCenter: center,
                initialPolygon: savedPolygon.length >= 3
                    ? savedPolygon
                    : _defaultZoneBox(center),
                parentPolygon: fieldPolygon,
                existingZones: [
                  for (final other in provider.allZones)
                    if (other.zoneId != zone.zoneId &&
                        other.fieldId == zone.fieldId &&
                        other.polygon != null)
                      {'name': other.name, 'polygon': other.polygon},
                ],
                fitBoundaryOnOpen: true,
                level: 'ZONE',
                height: 240,
                nodeMarkers: _nodeMarkers,
                isReadOnly: !_isEditingGis,
                onPolygonChanged: (newPts) {
                  _rebuild(() {
                    _editedPolygon = List<LatLng>.of(newPts);
                  });
                },
              ),
            ),
          if (_nodeMarkers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Builder(
                builder: (_) {
                  final outside = effectivePolygon.length >= 3
                      ? _nodeMarkers
                            .where(
                              (n) => !pointInPolygon(n.point, effectivePolygon),
                            )
                            .length
                      : 0;
                  return Text(
                    outside > 0
                        ? '${_nodeMarkers.length} node trên bản đồ · $outside node nằm NGOÀI ranh giới Zone (viền đỏ): kiểm tra lại toạ độ.'
                        : '${_nodeMarkers.length} node trên bản đồ (xanh dương: cảm biến, cam: van/bơm, xám: không online).',
                    key: const Key('gis_node_caption'),
                    style: TextStyle(
                      fontSize: 11,
                      color: outside > 0
                          ? const Color(0xFFB91C1C)
                          : const Color(0xFF64748B),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
