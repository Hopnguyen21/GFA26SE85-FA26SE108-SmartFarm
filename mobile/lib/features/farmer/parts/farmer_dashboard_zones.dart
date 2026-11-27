part of '../farmer_dashboard_screen.dart';

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0xFFE2E8F0)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

Widget _sectionBadge(String text) => Align(
  alignment: Alignment.centerLeft,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: _kGreen,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
  ),
);

extension _FarmerDashboardZones on _FarmerDashboardScreenState {
  Widget _buildZonesSection(
    FarmProvider provider,
    List<ZoneModel> zones,
    List<AlertModel> openAlerts,
  ) {
    final q = _zoneQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? zones
        : zones
              .where(
                (z) =>
                    z.name.toLowerCase().contains(q) ||
                    z.currentCrop.toLowerCase().contains(q),
              )
              .toList();
    return Container(
      key: _zonesKey,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionBadge('KHU VỰC ĐƯỢC GIAO'),
          const SizedBox(height: 6),
          Text(
            'Khu vực Nhà màng Phân công Kỹ thuật (${zones.length})',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Số đo vi khí hậu tự động thu thập từ các trạm cảm biến LoRa Gateway tại từng phân khu.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _zoneSearch,
            onChanged: (v) => _searchDebouncer.run(() => _rebuild(() => _zoneQuery = v)),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm khu vực...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Color(0xFF64748B),
              ),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kGreen, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Không tìm thấy khu vực nhà màng phù hợp.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            for (final z in filtered)
              _zoneCard(
                provider,
                z,
                zones,
                openAlerts.where((a) => a.zoneId == z.zoneId).length,
              ),
        ],
      ),
    );
  }

  Widget _zoneCard(
    FarmProvider provider,
    ZoneModel z,
    List<ZoneModel> allZones,
    int alertCount,
  ) {
    final crop = z.currentCrop.isNotEmpty ? z.currentCrop : 'Chưa gán cây';
    final stage = z.needsSeason
        ? 'Chưa có vụ đang canh tác'
        : (z.currentStage.isNotEmpty
              ? z.currentStage
              : 'Chưa xác định giai đoạn');
    // Chưa có bản ghi telemetry còn hiệu lực thì nói rõ, không hiện số 0 như thể đó là số đo.
    String metric(double v, String unit) =>
        z.telemetryIsFresh ? '${v.toStringAsFixed(1)} $unit' : 'Chưa có số đo';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alertCount > 0
              ? const Color(0xFFFDA4AF)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: alertCount > 0
                ? const Color(0xFFE11D48).withValues(alpha: 0.05)
                : const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      z.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🌱 $crop • $stage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    if (z.telemetryIsFresh)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Flexible(
                              child: Text(
                                'Cảm biến trực tiếp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              alertCount > 0
                  ? _chip(
                      '$alertCount cảnh báo',
                      const Color(0xFFFFE4E6),
                      const Color(0xFF9F1239),
                    )
                  // Không có cảnh báo nhưng cũng không có số đo còn hiệu lực thì KHÔNG khẳng định "An toàn" (chưa biết gì về Zone).
                  : (z.telemetryIsFresh
                        ? _chip(
                            '✓ An toàn',
                            const Color(0xFFD1FAE5),
                            const Color(0xFF065F46),
                          )
                        : _chip(
                            'Chưa có dữ liệu',
                            const Color(0xFFF1F5F9),
                            const Color(0xFF475569),
                          )),
            ],
          ),
          const SizedBox(height: 10),
          if (!z.telemetryIsFresh &&
              z.currentSoilMoisture == 0 &&
              z.currentTemp == 0 &&
              z.currentHumidity == 0 &&
              z.currentLux == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sensors_off_outlined,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Chưa có số đo cảm biến gửi về',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _metric(
                        'Độ ẩm đất',
                        metric(z.currentSoilMoisture, '%'),
                        Icons.water_drop_rounded,
                        const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      _metric(
                        'Nhiệt độ',
                        metric(z.currentTemp, '°C'),
                        Icons.thermostat_rounded,
                        const Color(0xFFEA580C),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _metric(
                        'Ẩm không khí',
                        metric(z.currentHumidity, '%'),
                        Icons.cloud_outlined,
                        const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 8),
                      _metric(
                        z.currentLux > 0 ? 'Ánh sáng' : 'pH / EC',
                        z.currentLux > 0
                            ? metric(z.currentLux, 'Lux')
                            : (z.telemetryIsFresh
                                  ? 'Bình thường'
                                  : 'Chưa có số đo'),
                        z.currentLux > 0
                            ? Icons.wb_sunny_outlined
                            : Icons.science_outlined,
                        z.currentLux > 0
                            ? const Color(0xFFB45309)
                            : const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ZoneDetailScreen(zone: z)),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: _kGreen),
                  foregroundColor: _kGreen,
                ),
                icon: const Icon(Icons.info_outline, size: 14),
                label: const Text(
                  'Chi tiết Zone ➔',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton(
                onPressed: () => _goTab(2),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  foregroundColor: const Color(0xFF334155),
                ),
                child: const Text(
                  'Bản đồ GIS ➔',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (provider.canControlZone(z.zoneId))
                FilledButton.icon(
                  onPressed: () =>
                      _openIrrigation(provider, allZones, zoneId: z.zoneId),
                  style: _btn(),
                  icon: const Icon(Icons.power_settings_new, size: 14),
                  label: const Text('Tưới thủ công'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon, Color iconColor) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
