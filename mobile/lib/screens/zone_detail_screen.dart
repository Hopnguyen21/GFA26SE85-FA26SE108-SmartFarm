import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import '../widgets/mini_gis_map_picker.dart';
import 'ai_screen.dart';
import 'crop_profiles_screen.dart';
import 'inspection_requests_screen.dart';
import 'deployment_screens.dart';
import 'contracts_depreciation_screen.dart';
import '../widgets/honeycomb_topology_widget.dart';

class ZoneDetailScreen extends StatefulWidget {
  final ZoneModel zone;
  final int zoneIndex;

  const ZoneDetailScreen({
    super.key,
    required this.zone,
    required this.zoneIndex,
  });

  @override
  State<ZoneDetailScreen> createState() => _ZoneDetailScreenState();
}

class _ZoneDetailScreenState extends State<ZoneDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Custom simulation items edited by owner
  List<ZoneEquipmentItem>? _customSimulationItems;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Mini chart data per sensor
  final Map<String, List<double>> _sensorHistory = {
    'soil': [58, 60, 62, 59, 56, 54, 68, 72, 71, 69, 68.4, 68.0],
    'temp': [18.2, 17.5, 17.0, 18.5, 21.0, 24.5, 27.8, 28.5, 27.2, 25.0, 24.8, 24.6],
    'humidity': [85.0, 88.0, 90.0, 86.0, 78.0, 68.0, 62.0, 60.0, 65.0, 72.0, 71.5, 71.2],
    'lux': [100, 200, 350, 500, 650, 780, 820, 740, 600, 450, 300, 150],
  };

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final zone = provider.zones[widget.zoneIndex];
    final zoneActuators = provider.actuators.where((a) => a.zoneId == zone.zoneId).toList();
    final isOwner = provider.currentRole == 'OWNER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ─── Hero AppBar ───
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF062326),
            foregroundColor: Colors.white,
            title: Text(
              zone.name.split(' - ')[0],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF062326), Color(0xFF064E3B)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 52),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: const Center(child: Text('🌱', style: TextStyle(fontSize: 26))),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                zone.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      zone.currentStage,
                                      style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${zone.farmName} ➔ ${zone.fieldName} ➔ Zone Chi tiết',
                                      style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${zone.areaM2.toInt()} m² • Phụ trách: ${zone.assignedWorkerName}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.assignment_outlined),
                  tooltip: 'Hợp đồng & Khấu hao Zone',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ContractsDepreciationScreen(
                        initialZoneId: zone.zoneId,
                        initialFarmId: zone.farmId,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.psychology_outlined),
                  tooltip: 'Hỏi AI về Zone này',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId))),
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF10B981),
              indicatorWeight: 3,
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Vi khí hậu'),
                Tab(text: 'Thiết bị'),
                Tab(text: 'Canh tác'),
                Tab(text: 'Mô phỏng & Dự toán'),
              ],
            ),
          ),

          // ─── Tab Content ───
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildClimateTab(zone, provider),
                _buildDevicesTab(context, provider, zoneActuators),
                _buildCultivationTab(context, provider, zone),
                _buildSimulationTab(context, zone),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiAssistantScreen(initialZoneId: zone.zoneId))),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.psychology, size: 20),
              label: const Text('Hỏi AI Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ─── Tab 1: Vi khí hậu ───────────────────────────────────────
  Widget _buildClimateTab(ZoneModel zone, FarmProvider provider) {
    // Ngưỡng và giai đoạn chỉ có khi vụ đang canh tác cùng cây với Zone; không thay bằng hồ sơ cây mặc định.
    if (zone.seasonStatus != 'InProgress') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${zone.currentStage}.\nTạo hoặc cập nhật vụ mùa của Zone để xem giai đoạn và ngưỡng vi khí hậu.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    // Tìm crop profile tương ứng với Zone
    final cropProfile = provider.defaultCropProfiles.firstWhere(
      (p) => zone.currentCrop.toLowerCase().contains(p.name.toLowerCase()) ||
          p.name.toLowerCase().contains(zone.currentCrop.toLowerCase()),
      orElse: () => provider.defaultCropProfiles.first,
    );

    // Tìm stage tương ứng
    final currentStage = cropProfile.growthStages.firstWhere(
      (s) => s.name.toLowerCase() == zone.currentStage.toLowerCase(),
      orElse: () => cropProfile.growthStages.first,
    );

    final req = currentStage.requirements;
    final isSoilOk = zone.currentSoilMoisture >= req.soilMoistureMin && zone.currentSoilMoisture <= req.soilMoistureMax;
    final isTempOk = zone.currentTemp >= req.tempMin && zone.currentTemp <= req.tempMax;
    final isHumidityOk = zone.currentHumidity >= req.humidityMin && zone.currentHumidity <= req.humidityMax;
    final isLuxOk = zone.currentLux >= 400;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live status row
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  zone.telemetryIsFresh ? 'Telemetry mới nhất từ DB' : 'Không có telemetry mới từ DB',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 sensor cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _buildSensorDetailCard(
                title: 'Độ ẩm đất',
                value: zone.telemetryIsFresh ? '${zone.currentSoilMoisture}%' : '—',
                min: req.soilMoistureMin, max: req.soilMoistureMax,
                current: zone.currentSoilMoisture,
                isFresh: zone.telemetryIsFresh,
                hasDbThresholds: zone.cropContextIsDbBacked,
                icon: Icons.water_drop,
                color: const Color(0xFF0284C7),
                bgColor: const Color(0xFFF0F9FF),
                data: _sensorHistory['soil']!,
                unit: '%',
              ),
              _buildSensorDetailCard(
                title: 'Nhiệt độ',
                value: zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—',
                min: req.tempMin, max: req.tempMax,
                current: zone.currentTemp,
                isFresh: zone.telemetryIsFresh,
                hasDbThresholds: zone.cropContextIsDbBacked,
                icon: Icons.thermostat,
                color: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFF7ED),
                data: _sensorHistory['temp']!,
                unit: '°C',
              ),
              _buildSensorDetailCard(
                title: 'Độ ẩm không khí',
                value: zone.telemetryIsFresh ? '${zone.currentHumidity}%' : '—',
                min: req.humidityMin, max: req.humidityMax,
                current: zone.currentHumidity,
                isFresh: zone.telemetryIsFresh,
                hasDbThresholds: zone.cropContextIsDbBacked,
                icon: Icons.cloud,
                color: const Color(0xFF059669),
                bgColor: const Color(0xFFF0FDF4),
                data: _sensorHistory['humidity']!,
                unit: '%',
              ),
              _buildSensorDetailCard(
                title: 'Ánh sáng (Lux)',
                value: zone.telemetryIsFresh ? '${zone.currentLux.toInt()} lx' : '—',
                min: 400, max: 1200,
                current: zone.currentLux,
                isFresh: zone.telemetryIsFresh,
                hasDbThresholds: zone.cropContextIsDbBacked,
                icon: Icons.wb_sunny,
                color: const Color(0xFFCA8A04),
                bgColor: const Color(0xFFFEFCE8),
                data: _sensorHistory['lux']!,
                unit: 'lx',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // VietGAP compliance card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        zone.cropContextIsDbBacked
                            ? 'Đánh giá Tuân thủ VietGAP: ${cropProfile.emoji} ${cropProfile.name}'
                            : 'Chưa đồng bộ mùa vụ và quy chuẩn từ DB',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        zone.cropContextIsDbBacked ? currentStage.name.split(' ').first : 'Chưa đồng bộ',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!zone.telemetryIsFresh || !zone.cropContextIsDbBacked)
                  const Text('Chưa có đủ telemetry mới hoặc quy chuẩn mùa vụ từ DB để đánh giá tuân thủ.', style: TextStyle(fontSize: 12, color: Color(0xFFB45309)))
                else ...[
                  _complianceRow('Độ ẩm đất', isSoilOk, '${zone.currentSoilMoisture}% (Chuẩn: ${req.soilMoistureMin.toInt()}-${req.soilMoistureMax.toInt()}%)'),
                  _complianceRow('Nhiệt độ', isTempOk, '${zone.currentTemp}°C (Chuẩn: ${req.tempMin.toInt()}-${req.tempMax.toInt()}°C)'),
                  _complianceRow('Độ ẩm KK', isHumidityOk, '${zone.currentHumidity}% (Chuẩn: ${req.humidityMin.toInt()}-${req.humidityMax.toInt()}%)'),
                  _complianceRow('Ánh sáng', isLuxOk, '${zone.currentLux.toInt()} lx (Chuẩn: ≥400 lx)'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Vị trí GIS Map của Nhà màng này (Khớp chính xác FE FarmsPage) ───
          _buildZoneGisSection(zone),
        ],
      ),
    );
  }

  Widget _buildZoneGisSection(ZoneModel zone) {
    final polygon = zone.polygon ?? [
      const LatLng(11.9419, 108.4568),
      const LatLng(11.9419, 108.4582),
      const LatLng(11.9408, 108.4582),
      const LatLng(11.9408, 108.4568),
    ];
    final center = polygon.isNotEmpty ? polygon.first : const LatLng(11.9403, 108.4583);

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Color(0xFF062326)),
                        SizedBox(width: 6),
                        Text(
                          'Vị trí GIS Map của Nhà màng này',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text(
                            'PostgreSQL PostGIS (SRID 4326)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                        Text(
                          '• ${polygon.length} tọa độ đỉnh',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chế độ Tinh chỉnh ranh giới GIS đã sẵn sàng trên bản đồ.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF062326),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_location_alt, size: 13, color: Color(0xFF062326)),
                label: const Text(
                  'Sửa GIS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF062326)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // MiniGIS Map Picker embedded
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: MiniGISMapPicker(
              initialCenter: center,
              initialPolygon: polygon,
              level: 'ZONE',
              height: 240,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSensorDetailCard({
    required String title,
    required String value,
    required double min,
    required double max,
    required double current,
    required bool isFresh,
    required bool hasDbThresholds,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required List<double> data,
    required String unit,
  }) {
    final canEvaluate = isFresh && hasDbThresholds;
    final isOk = canEvaluate && current >= min && current <= max;
    final progress = canEvaluate ? ((current - min) / (max - min)).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: !canEvaluate ? const Color(0xFFE2E8F0) : isOk ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5), width: canEvaluate && !isOk ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, color: color, size: 15)),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: !canEvaluate ? const Color(0xFFFFFBEB) : isOk ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(!isFresh ? 'THIẾU DỮ LIỆU' : !hasDbThresholds ? 'THIẾU NGƯỠNG DB' : isOk ? 'TỐT' : 'CẢNH BÁO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: !canEvaluate ? const Color(0xFFB45309) : isOk ? const Color(0xFF059669) : const Color(0xFFDC2626))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: !canEvaluate ? const Color(0xFFB45309) : isOk ? const Color(0xFF0F172A) : const Color(0xFFDC2626))),
          const Spacer(),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              color: isOk ? color : const Color(0xFFEF4444),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(hasDbThresholds ? '$min – $max $unit' : 'Ngưỡng chưa đồng bộ từ DB', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _complianceRow(String label, bool isOk, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(isOk ? Icons.check_circle : Icons.warning_amber_rounded,
              size: 16, color: isOk ? const Color(0xFF059669) : const Color(0xFFD97706)),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF374151)))),
          Expanded(child: Text(detail, style: TextStyle(fontSize: 11, color: isOk ? const Color(0xFF047857) : const Color(0xFFB45309)))),
        ],
      ),
    );
  }

  // ─── Tab 2: Thiết bị ─────────────────────────────────────────
  Widget _buildDevicesTab(BuildContext context, FarmProvider provider, List<ActuatorModel> actuators) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node sensors header
          const Text('TRẠM SENSOR NODE LORA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.router, color: Color(0xFF0284C7), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.zone.zoneId == 'zone-01'
                            ? 'Sensor Node Đất & Khí - Zone 01'
                            : widget.zone.zoneId == 'zone-02'
                                ? 'Sensor Node Đất & Khí - Zone 02'
                                : 'Sensor Node Đất & Khí - Zone 03',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.zone.zoneId == 'zone-01'
                            ? 'SN-LORA-001 • ESP32-S3 + SX1278 (433MHz)'
                            : widget.zone.zoneId == 'zone-02'
                                ? 'SN-LORA-002 • ESP32-S3 + SX1278 (433MHz)'
                                : 'SN-LORA-003 • ESP32-S3 + SX1278 (433MHz)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _deviceChip(
                            widget.zone.zoneId == 'zone-01'
                                ? '🔋 Pin: 87%'
                                : widget.zone.zoneId == 'zone-02'
                                    ? '🔋 Pin: 54%'
                                    : '🔋 Pin: 79%',
                            const Color(0xFFECFDF5),
                            const Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          _deviceChip(
                            widget.zone.zoneId == 'zone-01'
                                ? '📶 RSSI: -72 dBm'
                                : widget.zone.zoneId == 'zone-02'
                                    ? '📶 RSSI: -85 dBm'
                                    : '📶 RSSI: -78 dBm',
                            const Color(0xFFF0F9FF),
                            const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          _deviceChip(
                            widget.zone.zoneId == 'zone-02' ? '⚠️ WARNING' : '● ONLINE',
                            widget.zone.zoneId == 'zone-02' ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                            widget.zone.zoneId == 'zone-02' ? const Color(0xFFD97706) : const Color(0xFF059669),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Actuators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('THIẾT BỊ CHẤP HÀNH (ACTUATORS)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
              Text(
                provider.currentRole == 'OWNER' ? 'Toàn quyền' : 'Xem thôi',
                style: TextStyle(
                  fontSize: 10,
                  color: provider.currentRole == 'OWNER' ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (actuators.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.device_unknown_outlined, size: 36, color: Color(0xFF94A3B8)),
                    SizedBox(height: 8),
                    Text('Chưa có thiết bị chấp hành nào được gán vào Zone này.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            ...actuators.map((act) => _buildActuatorCard(context, provider, act)),

          const SizedBox(height: 20),

          // Safety rule banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quy tắc An toàn BR-SAFE-01', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF92400E))),
                      SizedBox(height: 3),
                      Text('Giới hạn tưới tối đa 15 phút/lần. Tự động ngắt khi độ ẩm đất ≥ 80%. Hệ thống tự động bật lại sau khi điều kiện trở về ngưỡng an toàn.', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorCard(BuildContext context, FarmProvider provider, ActuatorModel act) {
    IconData icon;
    switch (act.actuatorType) {
      case 'PUMP': icon = Icons.water; break;
      case 'FAN': icon = Icons.wind_power; break;
      case 'VALVE': icon = Icons.tune; break;
      default: icon = Icons.lightbulb;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: act.isRunning ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: act.isRunning ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: act.isRunning ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: act.isRunning ? const Color(0xFF059669) : const Color(0xFF64748B), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(act.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  act.isRunning ? '🟢 Đang bật — còn ${act.remainingMinutes} phút' : '⚫ Đang tắt',
                  style: TextStyle(fontSize: 11, color: act.isRunning ? const Color(0xFF059669) : const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: act.isRunning,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (_) {
              final isOwner = provider.currentRole == 'OWNER';
              final isTech = provider.currentRole == 'TECHNICIAN';
              final currentFarmer = provider.farmersForCurrentFarm.isNotEmpty ? provider.farmersForCurrentFarm.first : null;
              final isFarmerWithControl = provider.currentRole == 'FARMER' && (currentFarmer?.permissions.contains('CAN_CONTROL_PUMP') ?? false);
              if (!isOwner && !isFarmerWithControl && !isTech) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('⚠️ Bạn chưa được cấp quyền điều khiển thiết bị chấp hành (CAN_CONTROL_PUMP)!'),
                  backgroundColor: Color(0xFFE11D48),
                ));
                return;
              }
              HapticFeedback.mediumImpact();
              provider.toggleActuator(act.actuatorId);
            },
          ),
        ],
      ),
    );
  }

  Widget _deviceChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  // ─── Tab 3: Canh tác ─────────────────────────────────────────
  Widget _buildCultivationTab(BuildContext context, FarmProvider provider, ZoneModel zone) {
    final stages = [
      {'name': 'Gieo mầm', 'days': '0–21', 'done': true},
      {'name': 'Cây non', 'days': '22–35', 'done': true},
      {'name': 'Sinh trưởng', 'days': '36–55', 'done': true},
      {'name': 'Ra hoa', 'days': '56–70', 'done': false, 'current': true},
      {'name': 'Nuôi trái', 'days': '71–85', 'done': false},
      {'name': 'Thu hoạch', 'days': '86–95', 'done': false},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(zone.currentCrop, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                          const SizedBox(height: 3),
                          Text(zone.currentStage, style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: const Text('95 ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                _infoRow('Trang trại (Farm)', zone.farmName, highlight: true),
                _infoRow('Phân khu Lô đất', zone.fieldName, highlight: true),
                _infoRow('Tiêu chuẩn', 'VietGAP TCVN 11892-1:2017'),
                _infoRow('Gieo trồng', '01/09/2026'),
                _infoRow('Dự kiến thu hoạch', '05/12/2026'),
                _infoRow('Diện tích canh tác', '${zone.areaM2.toInt()} m²'),
                _infoRow('Mật độ trồng', '3.5 cây/m²'),
                _infoRow('Tổng cây ước tính', '${(zone.areaM2 * 3.5).toInt()} cây'),
                if (zone.assignedWorkerName != null) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.person_pin_circle, size: 16, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      const Text('Người phụ trách', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0C4A6E))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(zone.assignedWorkerName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(zone.workerRole ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CropProfilesScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF062326),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF10B981)),
                        label: const Text('Thư Viện Cây', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _showChangeCropModal(context, provider, zone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF062326),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF10B981)),
                        label: const Text('Gán Cây Cho Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text('VÒNG ĐỜI CÂY TRỒNG (GIAI ĐOẠN)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
          const SizedBox(height: 12),

          // Progress stepper
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: stages.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final isDone = s['done'] as bool;
                final isCurrent = s['current'] == true;
                final isLast = i == stages.length - 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? const Color(0xFF059669) : isCurrent ? const Color(0xFF062326) : const Color(0xFFF1F5F9),
                            border: isCurrent ? Border.all(color: const Color(0xFF10B981), width: 2) : null,
                          ),
                          child: Icon(
                            isDone ? Icons.check : isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 14,
                            color: isDone || isCurrent ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (!isLast) Container(width: 2, height: 30, color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(s['name'] as String, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600, fontSize: 13, color: isCurrent ? const Color(0xFF062326) : const Color(0xFF374151))),
                                if (isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('HIỆN TẠI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                  ),
                                ],
                              ],
                            ),
                            Text('Ngày ${s['days']}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Irrigation plan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.water_drop, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 6),
                    Text('Lịch tưới tiêu khuyến nghị (VietGAP)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0C4A6E))),
                  ],
                ),
                const SizedBox(height: 10),
                _infoRow('Sáng sớm', '06:00 – 06:20 (Bơm nhỏ giọt 20 phút)', highlight: true),
                _infoRow('Chiều', '16:30 – 16:45 (Bơm 15 phút)'),
                _infoRow('Tần suất', 'Mỗi ngày trong giai đoạn Ra hoa'),
                _infoRow('Lượng nước', '~12 lít/cây/ngày'),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: highlight ? const Color(0xFF0284C7) : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeCropModal(BuildContext context, FarmProvider provider, ZoneModel zone) {
    String selectedCropId = provider.defaultCropProfiles.first.cropId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedCrop = provider.defaultCropProfiles.firstWhere((p) => p.cropId == selectedCropId);
          final firstStage = selectedCrop.growthStages.first;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(selectedCrop.emoji, style: const TextStyle(fontSize: 34)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gán Cây Trồng Cho ${zone.name.split(' - ').first}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Chu kỳ sinh trưởng VietGAP & cập nhật tự động hóa', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Chọn loại cây trồng từ thư viện VietGAP:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCropId,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF062326)),
                      items: provider.defaultCropProfiles.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.cropId,
                          child: Text(
                            '${p.emoji} ${p.name} (${p.variety.split(' / ').first}) – ${p.totalCycleDays} ngày',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCropId = val);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thiết lập cấu hình tự động cho zone:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                      const SizedBox(height: 6),
                      Text('• Giai đoạn ban đầu: ${firstStage.name} (Ngày ${firstStage.startDayFromPlanting} - ${firstStage.endDayFromPlanting})', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                      Text('• Ngưỡng độ ẩm đất VietGAP: ${firstStage.requirements.soilMoistureMin.toInt()}% – ${firstStage.requirements.soilMoistureMax.toInt()}%', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                      Text('• Nhiệt độ thích hợp: ${firstStage.requirements.tempMin.toInt()}°C – ${firstStage.requirements.tempMax.toInt()}°C', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                      Text('• AutoRule tưới: Tự động bật bơm ${firstStage.requirements.irrigationDurationMin} phút khi ẩm đất dưới ngưỡng', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Huỷ', style: TextStyle(color: Color(0xFF475569))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () {
                          provider.applyCropProfile(selectedCropId, targetZoneId: zone.zoneId);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🌱 Đã gán cây "${selectedCrop.name}" cho ${zone.name.split(' - ').first}!'),
                              backgroundColor: const Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Xác Nhận Áp Dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Tab 4: Mô phỏng Thiết bị & Dự toán Chi phí theo Diện tích ───
  Widget _buildSimulationTab(BuildContext context, ZoneModel zone) {
    final baseSim = ZoneCostSimulation.calculate(
      areaM2: zone.areaM2,
      cropName: zone.currentCrop,
    );

    // Dùng danh sách đã chỉnh sửa nếu có, ngược lại dùng baseSim
    final sim = _customSimulationItems != null
        ? baseSim.copyWithCustomItems(updatedItems: _customSimulationItems!)
        : baseSim;

    final isCustomized = _customSimulationItems != null;

    String formatMoney(double amount) {
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)} Tr đ';
      }
      return '${(amount / 1000).toStringAsFixed(0)}k đ';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Tóm tắt Dự toán
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062326), Color(0xFF0F4C47)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF062326).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Khuyến cáo giả định
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isCustomized
                              ? 'BẢNG DỰ TOÁN ĐÃ ĐƯỢC CHỦ TRẠI HIỆU CHỈNH THEO HIỆN TRƯỜNG THỰC TẾ (Số liệu mang tính tham khảo nội bộ).'
                              : 'LƯU Ý: Số liệu trên chỉ là GIẢ ĐỊNH MÔ PHỎNG mang tính chất tham khảo dự toán nội bộ, không có hiệu lực báo giá thương mại hay cam kết hợp đồng.',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFFDE68A), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calculate_outlined, color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mô Phỏng Vật Tư & Thiết Bị',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              isCustomized
                                  ? 'Đã tinh chỉnh theo thực địa (${zone.areaM2.toInt()} m²)'
                                  : 'Định mức tự động theo diện tích ${zone.areaM2.toInt()} m²',
                              style: TextStyle(
                                color: isCustomized ? const Color(0xFF67E8F9) : const Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCustomized ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isCustomized ? 'Đã tùy chỉnh' : '${sim.estimatedPlants} cây',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Đầu tư Thiết bị IoT', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            formatMoney(sim.totalEquipmentCostVND),
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 36, color: Colors.white24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vận hành/Tháng', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            formatMoney(sim.monthlyOperatingCostVND),
                            style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Khối Mô hình Mạng Tổ Ong (Lục giác) chuẩn FE ──
          HoneycombTopologyCard(
            simulation: sim.honeycomb,
            initialExpanded: true,
          ),

          const SizedBox(height: 20),

          // Header Khối 1: Danh sách Thiết bị phần cứng định mức theo m2 + Nút Chỉnh sửa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'THIẾT BỊ & VẬT TƯ ĐỊNH MỨC THEO DIỆN TÍCH',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                    ),
                    Text(
                      '${sim.equipmentItems.length} hạng mục • Chạm để chỉnh sửa theo thực địa',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (isCustomized) ...[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _customSimulationItems = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔄 Đã khôi phục bảng thiết bị về định mức tự động chuẩn VietGAP')),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 14, color: Color(0xFFEA580C)),
                  label: const Text('Khôi phục', style: TextStyle(fontSize: 11, color: Color(0xFFEA580C), fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                ),
              ],
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _showAddEquipmentModal(context, sim.equipmentItems),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Thêm thiết bị', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...List.generate(sim.equipmentItems.length, (idx) {
            final item = sim.equipmentItems[idx];
            IconData icon;
            Color catColor;
            switch (item.category) {
              case 'SENSOR':
                icon = Icons.sensors;
                catColor = const Color(0xFF0284C7);
                break;
              case 'ACTUATOR':
                icon = Icons.power;
                catColor = const Color(0xFFEA580C);
                break;
              case 'IRRIGATION':
                icon = Icons.water_drop;
                catColor = const Color(0xFF059669);
                break;
              default:
                icon = Icons.router;
                catColor = const Color(0xFF7C3AED);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: catColor, size: 20),
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
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item.quantity} ${item.unit}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: catColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Đơn giá: ${formatMoney(item.unitPriceVND)} / ${item.unit}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            ),
                            Text(
                              formatMoney(item.totalPriceVND),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 8, color: Color(0xFFF1F5F9)),
                        // Action row: Chỉnh sửa nhanh số lượng / đơn giá
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showEditItemModal(context, idx, item, sim.equipmentItems),
                              icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0284C7)),
                              label: const Text('Chỉnh sửa', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              onPressed: () {
                                final updated = List<ZoneEquipmentItem>.from(sim.equipmentItems);
                                updated.removeAt(idx);
                                setState(() {
                                  _customSimulationItems = updated;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('🗑️ Đã xóa ${item.name} khỏi danh mục')),
                                );
                              },
                              icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
                              label: const Text('Xóa', style: TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),

          // Khối 2: Dự toán Chi phí Tiêu Thụ Định Kỳ
          const Text(
            'CHI PHÍ VẬN HÀNH DỰ KIẾN (HÀNG THÁNG)',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _costRow(
                  icon: Icons.electric_bolt,
                  title: 'Điện năng (Bơm + Quạt)',
                  sub: '${sim.dailyElectricityKwh.toStringAsFixed(1)} kWh/ngày • Đơn giá 2,587 đ (BR-ELEC-01)',
                  amount: formatMoney(sim.monthlyElectricityCostVND),
                  color: const Color(0xFFD97706),
                ),
                const Divider(height: 18),
                _costRow(
                  icon: Icons.water_drop,
                  title: 'Nước tưới tiêu',
                  sub: '${(sim.dailyWaterLiters / 1000).toStringAsFixed(1)} m³/ngày (3.8L/m²) • 10,000 đ/m³',
                  amount: formatMoney(sim.monthlyWaterCostVND),
                  color: const Color(0xFF0284C7),
                ),
                const Divider(height: 18),
                _costRow(
                  icon: Icons.badge_outlined,
                  title: 'Nhân công vận hành',
                  sub: 'Định mức 1 người / 2,500m² nhà màng chuẩn VietGAP',
                  amount: formatMoney(sim.estimatedLaborCostMonthlyVND),
                  color: const Color(0xFF059669),
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng chi phí vận hành ước tính', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    Text(
                      formatMoney(sim.monthlyOperatingCostVND),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Hộp cảnh báo pháp lý & hiệu lực giả định chi tiết
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.gavel_outlined, size: 18, color: Color(0xFFB45309)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TUYÊN BỐ MIỄN TRỪ TRÁCH NHIỆM (DISCLAIMER)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF92400E)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1. Toàn bộ bảng tính chi phí, số lượng thiết bị phần cứng, tiền điện và nước nêu trên chỉ là GIẢ ĐỊNH MÔ PHỎNG (Simulation & Approximation) dựa trên diện tích hình học và định mức kỹ thuật tham khảo.\n'
                        '2. Bảng tính KHÔNG CÓ HIỆU LỰC BÁO GIÁ THƯƠNG MẠI hay cam kết mua bán của nhà cung cấp giải pháp.\n'
                        '3. Chi phí thực tế sẽ phụ thuộc vào khảo sát địa hình, thương hiệu thiết bị và biểu giá thị trường tại thời điểm triển khai thực tế.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF78350F), height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nút gửi yêu cầu Admin duyệt và điều kỹ thuật viên xuống kiểm tra thực địa
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              onPressed: () => _showRequestInspectionModal(context, zone, sim),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text(
                'Gửi Yêu Cầu Admin Duyệt & Điều Kỹ Thuật Viên',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Xem danh sách yêu cầu khảo sát đã gửi
          Builder(
            builder: (ctx) {
              final provider = Provider.of<FarmProvider>(ctx);
              final requests = provider.inspectionRequests.where((r) => r.zoneId == zone.zoneId).toList();
              if (requests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'LỊCH SỬ YÊU CẦU KHẢO SÁT CỦA ZONE NÀY',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  ...requests.map((r) => _buildInspectionRequestCard(ctx, provider, r)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _costRow({
    required IconData icon,
    required String title,
    required String sub,
    required String amount,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(sub, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
      ],
    );
  }

  // ─── Modal gửi yêu cầu Admin duyệt & điều KTV ───
  void _showRequestInspectionModal(BuildContext context, ZoneModel zone, ZoneCostSimulation sim) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    final contactNameCtrl = TextEditingController(
      text: provider.currentRole == 'OWNER' ? 'Lê Văn An (Chủ trại)' : 'Trần Văn Bình (Đại diện)',
    );
    final phoneCtrl = TextEditingController(text: '0908 123 456');
    final dateCtrl = TextEditingController(
      text: '${DateTime.now().add(const Duration(days: 2)).day}/${DateTime.now().month}/${DateTime.now().year} (Sáng 08:30)',
    );
    final noteCtrl = TextEditingController(
      text: 'Yêu cầu kiểm tra thực địa hạ tầng nhà màng ${zone.name.split(' - ').first} (${zone.areaM2.toInt()}m²), kiểm tra vị trí đặt trạm Gateway và đo áp lực nguồn nước.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.engineering_outlined, color: Color(0xFF0F766E), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Yêu Cầu Khảo Sát Thực Địa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Gửi Admin duyệt & cử Kỹ thuật viên IoT xuống tận nơi', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tóm tắt Zone & Dự toán
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Khu vực:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quy mô dự toán:', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        Text('${zone.areaM2.toInt()} m² • ${sim.estimatedPlants} cây', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text('Họ tên người liên hệ đón tiếp *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: contactNameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Số điện thoại *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thời gian hẹn *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: dateCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text('Ghi chú / Yêu cầu cụ thể *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Mô tả hiện trạng mặt bằng, nguồn điện, đường nước...',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DeploymentPlanningScreen()));
                      },
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Tạo Yêu Cầu Triển Khai', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Card hiển thị trạng thái yêu cầu kiểm tra thực địa ───
  Widget _buildInspectionRequestCard(BuildContext context, FarmProvider provider, FieldInspectionRequestModel req) {
    Color statusColor;
    String statusText;
    switch (req.status) {
      case 'PENDING':
        statusColor = const Color(0xFFD97706);
        statusText = '⏳ Chờ Admin duyệt';
        break;
      case 'APPROVED':
        statusColor = const Color(0xFF0284C7);
        statusText = '✅ Admin đã duyệt';
        break;
      case 'DISPATCHED':
        statusColor = const Color(0xFF059669);
        statusText = '🛵 Đã điều KTV xuống';
        break;
      case 'REJECTED':
        statusColor = const Color(0xFFDC2626);
        statusText = '⛔ Bị từ chối';
        break;
      default:
        statusColor = const Color(0xFF10B981);
        statusText = '🎯 Hoàn tất khảo sát';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                req.requestId,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lịch hẹn: ${req.preferredDate} • Liên hệ: ${req.contactName} (${req.contactPhone})',
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 4),
          Text(
            'Nội dung: ${req.note}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          if (req.assignedTechnicianName != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_pin, size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'KTV phụ trách: ${req.assignedTechnicianName} (${req.technicianPhone ?? ""})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (req.status == 'PENDING') ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InspectionRequestsScreen()),
                    );
                  },
                  child: const Text('Xem phiếu', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InspectionRequestsScreen()),
                  );
                },
                icon: const Icon(Icons.description_outlined, size: 14, color: Color(0xFF0284C7)),
                label: const Text('Chi tiết phiếu KTV', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Modal chỉnh sửa 1 thiết bị trong mô phỏng ───
  void _showEditItemModal(BuildContext context, int index, ZoneEquipmentItem item, List<ZoneEquipmentItem> currentList) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final priceCtrl = TextEditingController(text: item.unitPriceVND.toInt().toString());
    final descCtrl = TextEditingController(text: item.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.edit_note, color: Color(0xFF0F766E), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chỉnh Sửa Thiết Bị Thực Địa',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0284C7))),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Số lượng (${item.unit}) *', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đơn giá (VNĐ) *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('Ghi chú thực địa', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(10),
                hintText: 'Lý do tăng/giảm theo điều kiện mặt bằng...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final newQty = int.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
                      final newPrice = double.tryParse(priceCtrl.text.trim()) ?? item.unitPriceVND;
                      final newDesc = descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : item.description;

                      final updatedList = List<ZoneEquipmentItem>.from(currentList);
                      updatedList[index] = item.copyWith(
                        quantity: newQty,
                        unitPriceVND: newPrice,
                        description: newDesc,
                      );

                      setState(() {
                        _customSimulationItems = updatedList;
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ Đã cập nhật thiết bị: ${item.name}')),
                      );
                    },
                    child: const Text('Lưu Thay Đổi', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modal thêm mới 1 thiết bị thực địa vào mô phỏng ───
  void _showAddEquipmentModal(BuildContext context, List<ZoneEquipmentItem> currentList) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'Bộ');
    final priceCtrl = TextEditingController(text: '1500000');
    final descCtrl = TextEditingController(text: 'Bổ sung theo yêu cầu địa hình thực tế của zone');
    String selectedCat = 'ACTUATOR';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Color(0xFF0F766E), size: 22),
                      SizedBox(width: 8),
                      Text('Thêm Thiết Bị / Vật Tư Thực Địa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 14),

                  const Text('Tên thiết bị / vật tư *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'VD: Bồn chứa dinh dưỡng 1000L, Lọc đĩa đôi Azud...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nhóm thiết bị *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedCat,
                              isDense: true,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'SENSOR', child: Text('Cảm biến (Sensor)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'ACTUATOR', child: Text('Chấp hành (Bơm/Van)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'IRRIGATION', child: Text('Tưới tiêu & Ống', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'NETWORK', child: Text('Gateway / Tủ điều khiển', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => selectedCat = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đơn vị tính *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: unitCtrl,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số lượng *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Đơn giá (VNĐ) *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Mô tả tính năng', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty) return;
                            final newQty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                            final newPrice = double.tryParse(priceCtrl.text.trim()) ?? 0;

                            final newItem = ZoneEquipmentItem(
                              name: nameCtrl.text.trim(),
                              category: selectedCat,
                              quantity: newQty,
                              unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'Bộ',
                              unitPriceVND: newPrice,
                              description: descCtrl.text.trim(),
                            );

                            final updatedList = List<ZoneEquipmentItem>.from(currentList)..add(newItem);
                            setState(() {
                              _customSimulationItems = updatedList;
                            });

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ Đã thêm thiết bị mới: ${newItem.name}')),
                            );
                          },
                          child: const Text('Thêm Vào Danh Mục', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


