part of '../crop_detail_screen.dart';

extension _CropDetailScreenStateOverview on _CropDetailScreenState {
  Widget _buildOverviewTab(DefaultCropProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Stats
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '📅',
                  'Chu kỳ',
                  '${profile.totalCycleDays} ngày',
                  const Color(0xFF0284C7),
                  const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  '🏆',
                  'Tiêu chuẩn',
                  profile.standardType,
                  const Color(0xFF059669),
                  const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statCard(
                  '🌱',
                  'Giai đoạn',
                  '${profile.growthStages.length} kỳ',
                  const Color(0xFF7C3AED),
                  const Color(0xFFF5F3FF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Banner truy cập nhanh Lịch tưới cả tháng
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => IrrigationCalendarScreen(profile: profile)));
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF0D4A35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month, color: Color(0xFF34D399), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xem Cuốn Lịch Tưới Chi Tiết Cả Tháng',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Lưới 30 ngày • 3 ca tưới/ngày • Tự do chỉnh sửa & lưu',
                          style: TextStyle(fontSize: 11, color: Color(0xFFA7F3D0)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                ],
              ),
            ),
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
                const Text(
                  'MÔ TẢ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(profile.description, style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.5)),
                const SizedBox(height: 10),
                if (profile.origin.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(profile.origin, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                if (profile.suitableRegion.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.map, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Vùng phù hợp: ${profile.suitableRegion}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
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
                const Text(
                  'VÒNG ĐỜI CANH TÁC',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
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
                  child: Text(
                    'Chiều cao = số ngày mỗi giai đoạn',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Lịch tưới & Chế độ nước (VietGAP)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.water_drop, color: Color(0xFF0284C7), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'LỊCH TƯỚI KHUYẾN NGHỊ (VIETGAP)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF0369A1),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                      child: const Text(
                        'Theo hồ sơ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _overviewIrrigationRow(
                  'Lịch tưới',
                  'Theo từng giai đoạn của hồ sơ (dữ liệu từ máy chủ) — mở "Cuốn lịch tưới" để xem',
                ),
                _overviewIrrigationRow(
                  'Ngưỡng ẩm an toàn',
                  profile.growthStages.isNotEmpty
                      ? '${profile.growthStages.first.requirements.soilMoistureMin.toInt()}% – ${profile.growthStages.first.requirements.soilMoistureMax.toInt()}% (Độ ẩm đất)'
                      : '—',
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => IrrigationCalendarScreen(profile: profile)),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.calendar_month, size: 16, color: Color(0xFF0284C7)),
                        SizedBox(width: 8),
                        Text(
                          'Xem cuốn lịch tưới chi tiết cả tháng ➜',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
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
                    final names = {
                      'PUMP': 'Máy bơm',
                      'FAN': 'Quạt gió',
                      'GROW_LIGHT': 'Đèn LED',
                      'VALVE': 'Van solenoid',
                    };
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

  Widget _overviewIrrigationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _listCard({
    required String title,
    required IconData icon,
    required List<String> items,
    required Color color,
    required Color bgColor,
  }) {
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $item', style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
            ),
          ),
        ],
      ),
    );
  }
}
