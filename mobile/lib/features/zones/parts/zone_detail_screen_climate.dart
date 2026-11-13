part of '../zone_detail_screen.dart';

extension _ZoneDetailScreenStateClimate on _ZoneDetailScreenState {
  // ─── Tab 1: Vi khí hậu ───────────────────────────────────────
  Widget _buildClimateTab(ZoneModel zone, FarmProvider provider) {
    // Telemetry của CHÍNH Zone đang mở (theo zoneId) + ngưỡng của hồ sơ gắn cho Zone; GIS đặt ở cuối tab.
    return ZoneClimatePanel(
      key: ValueKey('climate_${zone.zoneId}'),
      zone: zone,
      footer: _buildZoneGisSection(zone),
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
    final effectivePolygon = _editedPolygon ?? zone.polygon ?? const <LatLng>[];
    final hasPolygon = effectivePolygon.isNotEmpty;
    // Vị trí thật của trang trại, dùng làm điểm bắt đầu khi vẽ ranh giới lần đầu.
    final farm = provider.farms
        .where((f) => f.farmId == zone.farmId)
        .firstOrNull;
    final farmLatLng =
        (farm == null || (farm.latitude == 0 && farm.longitude == 0))
        ? null
        : LatLng(farm.latitude, farm.longitude);
    final center = hasPolygon ? effectivePolygon.first : farmLatLng;

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
                              _rebuild(() => _isSavingGis = true);
                              try {
                                final geoJsonCoords = [
                                  pts
                                      .map((p) => [p.longitude, p.latitude])
                                      .toList()
                                    ..add([
                                      pts.first.longitude,
                                      pts.first.latitude,
                                    ]),
                                ];
                                // Chỉ cập nhật bản đồ khi máy chủ xác nhận đã lưu.
                                await FarmApi.updateZone(
                                  zone.zoneId,
                                  name: zone.name,
                                  notes: zone.notes,
                                  polygonGeoJson: {
                                    'type': 'Polygon',
                                    'coordinates': geoJsonCoords,
                                  },
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
                                    backgroundColor: Color(0xFF059669),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } catch (e) {
                                if (mounted)
                                  _rebuild(() => _isSavingGis = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Không lưu được ranh giới: ${e.toString().replaceFirst('Exception: ', '')}',
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
                        backgroundColor: const Color(0xFF059669),
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
              else if (canEdit && (hasPolygon || farmLatLng != null))
                OutlinedButton.icon(
                  onPressed: () {
                    // Zone chưa có ranh giới: bắt đầu bằng một ô vuông nhỏ (~25 m) quanh vị trí thật của trang trại.
                    final start = hasPolygon
                        ? List<LatLng>.from(effectivePolygon)
                        : _defaultZoneBox(farmLatLng!);
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
                  'zone_gis_${zone.zoneId}_${_isEditingGis}_${effectivePolygon.length}',
                ),
                initialCenter: center,
                initialPolygon: effectivePolygon,
                level: 'ZONE',
                height: 240,
                isReadOnly: !_isEditingGis,
                onPolygonChanged: (newPts) {
                  _rebuild(() {
                    _editedPolygon = newPts;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}
