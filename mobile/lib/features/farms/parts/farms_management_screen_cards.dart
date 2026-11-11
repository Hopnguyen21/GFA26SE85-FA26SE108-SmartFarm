part of '../farms_management_screen.dart';

extension _FarmsManagementScreenCards on FarmsManagementScreen {
  Widget _buildFarmCard(BuildContext context, FarmModel farm, FarmProvider provider) {
    final isCurrent = farm.farmId == provider.selectedFarmId;

    return InkWell(
      onTap: () {
        provider.selectFarm(farm.farmId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chọn: ${farm.name}'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.agriculture, color: isCurrent ? const Color(0xFF059669) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          farm.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCurrent ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Đang chọn',
                            style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(farm.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(
                    'Diện tích: ${(farm.totalAreaM2 / 10000).toStringAsFixed(1)} ha (${farm.totalAreaM2.toInt()} m²)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldItem(String name, String sub, String count, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.layers_outlined, color: isSelected ? Colors.white : const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, ZoneModel zone, bool isSelected, int zoneIndex, VoidCallback onSelect) {
    return GestureDetector(
      onTap: () {
        onSelect();
        Navigator.push(context, MaterialPageRoute(builder: (_) => ZoneDetailScreen(zone: zone)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF062326) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          zone.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18)
                      else
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (zone.needsSeason)
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chưa có vụ đang canh tác.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                          onPressed: () async {
                            final created = await showCreateSeasonSheet(context, zone);
                            if (created == true && context.mounted) await context.read<FarmProvider>().fetchFromApi();
                          },
                          child: const Text(
                            '+ Tạo vụ trồng',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  Text(
                    'Cây trồng: ${zone.currentCrop} • ${zone.currentStage}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildZoneMiniMetric(
                        Icons.water_drop,
                        zone.telemetryIsFresh ? '${zone.currentSoilMoisture}%' : '—',
                        const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      _buildZoneMiniMetric(
                        Icons.thermostat,
                        zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—',
                        const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 10),
                      _buildZoneMiniMetric(Icons.crop_square, '${zone.areaM2.toInt()} m²', const Color(0xFF64748B)),
                    ],
                  ),
                  // Assignee info (if available)
                  if (zone.assignedWorkerName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin_circle_outlined, size: 12, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            '${zone.assignedWorkerName} • ${zone.workerRole ?? ''}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneMiniMetric(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
