part of '../farmer_dashboard_screen.dart';

extension _FarmerDashboardScreenStateZones on _FarmerDashboardScreenState {
  // ─── TAB 1: ZONES ──────────────────────────────────────────────────────────
  Widget _buildZonesTab(BuildContext context, FarmProvider provider, List<ZoneModel> zones, FarmerModel? farmer) {
    final assignedTasks = provider.tasks.where((t) {
      if (farmer == null) return true;
      if (t.assignedFarmerId == farmer.farmerId) return true;
      if (t.assignedFarmerName != null && t.assignedFarmerName!.contains(farmer.name)) {
        return true;
      }
      if (t.assignedFarmerId == null || t.assignedFarmerId!.isEmpty) {
        return zones.any((z) => t.zoneName.contains(z.name.split(' - ').first));
      }
      return false;
    }).toList();

    return RefreshIndicator(
      onRefresh: provider.fetchFromApi,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF065F46).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF6EE7B7), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _LiveClock(
                          weekdayLabel: _weekdayVi,
                          style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Khu vực phụ trách', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            Text(
                              '${zones.length} nhà màng',
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'LoRa Live',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Permission badges
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (farmer?.permissions ?? []).map((p) {
                      final info = _permissionInfo(p);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${info.$1} ${info.$2}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Nhiệm vụ phân công cho Farmer
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'NHIỆM VỤ ĐƯỢC GIAO HÔM NAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF065F46),
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${assignedTasks.where((t) => !t.isCompleted).length} việc cần làm',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (assignedTasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tất cả công việc đã hoàn thành hoặc chưa có việc mới!',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...assignedTasks.map((task) => _buildFarmerTaskCard(context, provider, task)),

            const SizedBox(height: 24),
            const Text(
              'NHÀ MÀNG ĐƯỢC PHÂN CÔNG',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),

            if (zones.isEmpty)
              _buildEmptyState(
                'Chưa có khu vực nào được phân công cho tài khoản này. Vui lòng liên hệ Chủ trang trại để được phân quyền.',
                Icons.home_work_outlined,
              )
            else
              ...zones.map((zone) => _buildZoneCard(context, zone, provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerTaskCard(BuildContext context, FarmProvider provider, TaskModel task) {
    final isHigh = task.priority == 'HIGH';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isCompleted
              ? const Color(0xFFE2E8F0)
              : (isHigh ? const Color(0xFFFECACA) : const Color(0xFFD1FAE5)),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? const Color(0xFFF1F5F9)
                            : (isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.isCompleted ? 'Xong' : (isHigh ? 'Khẩn cấp' : 'Bình thường'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: task.isCompleted
                              ? const Color(0xFF64748B)
                              : (isHigh ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        task.zoneName,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule, size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 3),
                    Text(task.dueDate, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                TaskActions(task: task, isOwner: false),
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, ZoneModel zone, FarmProvider provider) {
    final moisture = zone.currentSoilMoisture;
    final temp = zone.currentTemp;
    final humidity = zone.currentHumidity;

    Color moistureColor = !zone.telemetryIsFresh || !zone.cropContextIsDbBacked
        ? const Color(0xFFF59E0B)
        : moisture >= 60 && moisture <= 80
        ? const Color(0xFF059669)
        : moisture < 50 || moisture > 90
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ZoneDetailScreen(zone: zone)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD1FAE5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF065F46).withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_cropEmoji(zone.currentCrop), style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${zone.currentCrop} • ${zone.currentStage}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF10B981), size: 20),
                ],
              ),
            ),
            // Sensor data
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _sensorTile(
                        '💧',
                        'Ẩm đất',
                        zone.telemetryIsFresh ? '${moisture.toStringAsFixed(1)}%' : '—',
                        moistureColor,
                      ),
                      const SizedBox(width: 8),
                      _sensorTile(
                        '🌡️',
                        'Nhiệt độ',
                        zone.telemetryIsFresh ? '${temp.toStringAsFixed(1)}°C' : '—',
                        zone.telemetryIsFresh && zone.cropContextIsDbBacked && temp > 30
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 8),
                      _sensorTile(
                        '💨',
                        'Độ ẩm KK',
                        zone.telemetryIsFresh ? '${humidity.toStringAsFixed(0)}%' : '—',
                        const Color(0xFF0284C7),
                      ),
                    ],
                  ),
                  // Area indicator
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.straighten, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${zone.areaM2.toInt()} m²',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Moisture status indicator
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: moistureColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            !zone.telemetryIsFresh
                                ? 'Chưa có telemetry mới'
                                : !zone.cropContextIsDbBacked
                                ? 'Chưa có ngưỡng DB'
                                : moisture < 55
                                ? '⚠️ Cần tưới'
                                : moisture > 85
                                ? '💦 Đủ ẩm'
                                : '✅ Ổn định',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: moistureColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sensorTile(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
