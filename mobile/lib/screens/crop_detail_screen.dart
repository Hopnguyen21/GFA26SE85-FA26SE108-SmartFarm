import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import 'farming_seasons_screen.dart';

class CropDetailScreen extends StatefulWidget {
  final DefaultCropProfile profile;

  const CropDetailScreen({super.key, required this.profile});

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedStageIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final selectedStage = profile.growthStages[_selectedStageIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: const Color(0xFF062326),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF062326), Color(0xFF0D4A35)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 56),
                    Text(profile.emoji, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 8),
                    Text(profile.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(profile.variety, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF10B981),
              indicatorWeight: 3,
              labelColor: const Color(0xFF10B981),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: 'Tổng quan'),
                Tab(text: 'Giai đoạn'),
                Tab(text: 'AutoRule'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Overview
            _buildOverviewTab(profile),
            // Tab 2: Growth Stages
            _buildStagesTab(profile, selectedStage),
            // Tab 3: AutoRule Preview
            _buildAutoRuleTab(profile),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${profile.emoji} ${profile.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Chuẩn ${profile.standardType} • ${profile.totalCycleDays} ngày',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Áp Dụng Cho Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showApplyToZoneModal(context, profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApplyToZoneModal(BuildContext context, DefaultCropProfile profile) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có khu vực (Zone) nào. Vui lòng tạo Zone trước!')),
      );
      return;
    }

    String selectedZoneId = provider.currentZone.zoneId;
    List<FarmingSeasonModel> seasons = [];
    String? selectedSeasonId;
    bool isLoadingSeasons = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            if (isLoadingSeasons) {
              ApiService.getFarmingSeasons().then((list) {
                if (modalCtx.mounted) {
                  setModalState(() {
                    seasons = list;
                    final activeSeason = list.cast<FarmingSeasonModel?>().firstWhere(
                      (s) => s?.status == 'ACTIVE',
                      orElse: () => list.isNotEmpty ? list.first : null,
                    );
                    selectedSeasonId = activeSeason?.id;
                    isLoadingSeasons = false;
                  });
                }
              }).catchError((_) {
                if (modalCtx.mounted) {
                  setModalState(() => isLoadingSeasons = false);
                }
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(profile.emoji, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Áp Dụng Cây ${profile.name}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Cập nhật cây trồng & tạo AutoRule vi khí hậu VietGAP',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Chọn khu vực (Zone) muốn áp dụng: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZoneId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: provider.zones.map((z) {
                        return DropdownMenuItem(
                          value: z.zoneId,
                          child: Text('${z.name} (Hiện tại: ${z.currentCrop})', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedZoneId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Khung Mùa Vụ Canh Tác (Farming Season):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmingSeasonsScreen()));
                          },
                          child: const Text('+ Quản lý mùa', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (isLoadingSeasons)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                      )
                    else
                      DropdownButtonFormField<String?>(
                        initialValue: selectedSeasonId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('🌾 Không gắn khung mùa vụ cố định', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          ),
                          ...seasons.map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Row(
                                  children: [
                                    Text(s.status == 'ACTIVE' ? '🟢 ' : s.status == 'PLANNED' ? '🟡 ' : '⚪ '),
                                    Expanded(
                                      child: Text(
                                        '${s.name} (${s.year} - ${s.code})',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (v) => setModalState(() => selectedSeasonId = v),
                      ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sau khi áp dụng:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                          const SizedBox(height: 4),
                          Text('• Giai đoạn khởi đầu: ${profile.growthStages.first.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                          Text('• Dải ẩm đất VietGAP: ${profile.growthStages.first.requirements.soilMoistureMin.toInt()}% – ${profile.growthStages.first.requirements.soilMoistureMax.toInt()}%', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                          Text('• Tự động tạo AutoRule tưới nhỏ giọt & quạt làm mát', style: const TextStyle(fontSize: 11, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Huỷ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Xác Nhận Áp Dụng', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              provider.applyCropProfile(profile.cropId, targetZoneId: selectedZoneId, farmingSeasonId: selectedSeasonId);
                              Navigator.pop(ctx);
                              final seasonName = seasons.where((s) => s.id == selectedSeasonId).firstOrNull?.name;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Đã áp dụng giống ${profile.name} vào khu vực${seasonName != null ? ' (Khung $seasonName)' : ''} thành công!'),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOverviewTab(DefaultCropProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Stats
          Row(
            children: [
              Expanded(child: _statCard('📅', 'Chu kỳ', '${profile.totalCycleDays} ngày', const Color(0xFF0284C7), const Color(0xFFF0F9FF))),
              const SizedBox(width: 10),
              Expanded(child: _statCard('🏆', 'Tiêu chuẩn', profile.standardType, const Color(0xFF059669), const Color(0xFFECFDF5))),
              const SizedBox(width: 10),
              Expanded(child: _statCard('🌱', 'Giai đoạn', '${profile.growthStages.length} kỳ', const Color(0xFF7C3AED), const Color(0xFFF5F3FF))),
            ],
          ),

          const SizedBox(height: 16),

          // Description
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('MÔ TẢ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Text(profile.description, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(child: Text(profile.origin, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.map, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(child: Text('Vùng phù hợp: ${profile.suitableRegion}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Cycle Timeline
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VÒNG ĐỜI CANH TÁC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 80,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, meta) {
                              final idx = v.toInt();
                              if (idx >= 0 && idx < profile.growthStages.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    profile.growthStages[idx].iconEmoji,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      barGroups: profile.growthStages.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.durationDays.toDouble(),
                              color: const Color(0xFF10B981).withValues(alpha: 0.6 + e.key * 0.1),
                              width: 28,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('Chiều cao = số ngày mỗi giai đoạn', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Compatible Devices & Common Pests
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _listCard(
                  title: 'THIẾT BỊ SỬ DỤNG',
                  icon: Icons.devices,
                  items: profile.compatibleActuators.map((a) {
                    final icons = {'PUMP': '💧', 'FAN': '🌀', 'GROW_LIGHT': '💡', 'VALVE': '🔧'};
                    final names = {'PUMP': 'Máy bơm', 'FAN': 'Quạt gió', 'GROW_LIGHT': 'Đèn LED', 'VALVE': 'Van solenoid'};
                    return '${icons[a] ?? ''} ${names[a] ?? a}';
                  }).toList(),
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _listCard(
                  title: 'SÂU BỆNH THƯỜNG GẶP',
                  icon: Icons.bug_report,
                  items: profile.commonPests,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStagesTab(DefaultCropProfile profile, GrowthStageProfile selectedStage) {
    return Column(
      children: [
        // Stage Selector
        Container(
          height: 60,
          color: Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: profile.growthStages.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final stage = profile.growthStages[i];
              final isSelected = i == _selectedStageIndex;
              return InkWell(
                onTap: () => setState(() => _selectedStageIndex = i),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF062326) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(stage.iconEmoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        stage.name.split(' ').first,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stage Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF062326), Color(0xFF0D4A35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(selectedStage.iconEmoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(selectedStage.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(selectedStage.nameEn, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Ngày ${selectedStage.startDayFromPlanting}–${selectedStage.endDayFromPlanting}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(selectedStage.description, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1), height: 1.4)),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Environmental Requirements - CropRangeBands đồng bộ FE
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'DẢI NGƯỠNG VI KHÍ HẬU VIETGAP',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.3),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Đồng bộ AutoRule', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Range Bands Trực Quan (Tương đương CropRangeBand trên FE)
                      _buildRangeBand(
                        label: 'Độ ẩm đất (Soil Moisture)',
                        min: selectedStage.requirements.soilMoistureMin,
                        max: selectedStage.requirements.soilMoistureMax,
                        target: (selectedStage.requirements.soilMoistureMin + selectedStage.requirements.soilMoistureMax) / 2,
                        current: (selectedStage.requirements.soilMoistureMin + selectedStage.requirements.soilMoistureMax) / 2 - 2,
                        unit: '%',
                        icon: Icons.water_drop,
                        accentColor: const Color(0xFF0284C7),
                      ),
                      const SizedBox(height: 12),

                      _buildRangeBand(
                        label: 'Nhiệt độ không khí (Air Temp)',
                        min: selectedStage.requirements.tempMin,
                        max: selectedStage.requirements.tempMax,
                        target: (selectedStage.requirements.tempMin + selectedStage.requirements.tempMax) / 2,
                        current: (selectedStage.requirements.tempMin + selectedStage.requirements.tempMax) / 2 + 0.5,
                        unit: '°C',
                        icon: Icons.thermostat,
                        accentColor: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 12),

                      _buildRangeBand(
                        label: 'Độ ẩm không khí (Air Humidity)',
                        min: selectedStage.requirements.humidityMin,
                        max: selectedStage.requirements.humidityMax,
                        target: (selectedStage.requirements.humidityMin + selectedStage.requirements.humidityMax) / 2,
                        current: (selectedStage.requirements.humidityMin + selectedStage.requirements.humidityMax) / 2 + 1,
                        unit: '%',
                        icon: Icons.air,
                        accentColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 14),

                      // Khối Chế độ tưới tự động
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alarm, size: 18, color: Color(0xFF7C3AED)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LỊCH TƯỚI TỰ ĐỘNG KHUYẾN NGHỊ',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${selectedStage.requirements.irrigationDurationMin} phút / lần • ${selectedStage.requirements.irrigationFrequencyPerDay} lần mỗi ngày',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: const Text('Bật Bơm Tự Động', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Key Activities
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CÔNG VIỆC CANH TÁC CHÍNH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                      const SizedBox(height: 10),
                      ...selectedStage.keyActivities.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoRuleTab(DefaultCropProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062326), Color(0xFF0D4A35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text('AutoRule Engine (CF3)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Khi áp dụng Profile này, hệ thống tự động tạo các quy tắc dưới đây. Bơm/quạt sẽ hoạt động KHÔNG CẦN xác nhận tay – chỉ gửi notify cho bạn.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Auto Rules for each stage
          ...profile.growthStages.asMap().entries.map((entry) {
            final stage = entry.value;
            final req = stage.requirements;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(stage.iconEmoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(stage.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const Spacer(),
                      Text('Ngày ${stage.startDayFromPlanting}–${stage.endDayFromPlanting}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ruleRow('💧 Tưới tự động', 'Độ ẩm đất < ${req.soilMoistureMin.toInt()}%', '→ Bật bơm ${req.irrigationDurationMin} phút × ${req.irrigationFrequencyPerDay}lần/ngày'),
                  const SizedBox(height: 6),
                  _ruleRow('🌡️ Làm mát', 'Nhiệt độ > ${req.tempMax.toInt()}°C', '→ Bật quạt thông gió (fail-safe 30 phút)'),
                  const SizedBox(height: 6),
                  _ruleRow('🌧️ Hoãn tưới', 'Dự báo mưa > 70%', '→ Tạm hoãn lịch tưới tiếp theo'),
                ],
              ),
            );
          }),

          // Note about Human-in-loop for AI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Advisory (CF4) – Human-in-the-loop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                      SizedBox(height: 4),
                      Text(
                        'Các tình huống phức tạp (bệnh lá, thời tiết bất thường, giai đoạn chuyển vụ) → AI đề xuất và BẠN phê duyệt trước khi thực thi. AutoRule xử lý các ngưỡng đơn giản hoàn toàn tự động.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.4),
                      ),
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

  Widget _statCard(String emoji, String label, String value, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _listCard({required String title, required IconData icon, required List<String> items, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $item', style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
          )),
        ],
      ),
    );
  }

  Widget _buildRangeBand({
    required String label,
    required double min,
    required double max,
    required double target,
    required double current,
    required String unit,
    required IconData icon,
    required Color accentColor,
  }) {
    final isHealthy = current >= min && current <= max;
    // Calculate percentage position along range
    final span = (max - min) > 0 ? (max - min) : 10.0;
    final extendedMin = min - span * 0.25;
    final extendedMax = max + span * 0.25;
    final totalRange = extendedMax - extendedMin;
    final pct = ((current - extendedMin) / totalRange).clamp(0.05, 0.95);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isHealthy ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isHealthy ? 'Tối ưu VietGAP' : 'Lệch ngưỡng',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isHealthy ? const Color(0xFF059669) : const Color(0xFFD97706),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${current.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isHealthy ? const Color(0xFF065F46) : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Track
          LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Full background track
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Optimal band segment
                  Positioned(
                    left: trackWidth * 0.2,
                    width: trackWidth * 0.6,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        border: Border.symmetric(
                          vertical: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.8), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // Current Marker
                  Positioned(
                    left: (trackWidth * pct) - 4,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isHealthy ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Min - Target - Max Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MIN: ${min.toInt()} $unit',
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
              Text(
                'MỤC TIÊU: ${target.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857), fontFamily: 'monospace'),
              ),
              Text(
                'MAX: ${max.toInt()} $unit',
                style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(String title, String condition, String action) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text('NẾU: $condition', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          Text('THÌ: $action', style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
