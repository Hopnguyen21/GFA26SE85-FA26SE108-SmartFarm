part of '../farmer_dashboard_screen.dart';

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: const Color(0xFFE2E8F0)),
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
            onChanged: (v) => _rebuild(() => _zoneQuery = v),
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm khu vực...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
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
                  : _chip(
                      '✓ An toàn',
                      const Color(0xFFD1FAE5),
                      const Color(0xFF065F46),
                    ),
            ],
          ),
          const SizedBox(height: 8),
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
                    _metric('Độ ẩm đất', metric(z.currentSoilMoisture, '%')),
                    _metric('Nhiệt độ', metric(z.currentTemp, '°C')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _metric('Ẩm không khí', metric(z.currentHumidity, '%')),
                    _metric('pH / EC', 'Chưa có số đo'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => _goTab(2),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                ),
                child: const Text(
                  'Bản đồ GIS ➔',
                  style: TextStyle(fontSize: 12),
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

  Widget _metric(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    ),
  );
}
