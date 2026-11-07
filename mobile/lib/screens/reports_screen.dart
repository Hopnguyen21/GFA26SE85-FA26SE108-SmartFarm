import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> weeklyWater = [
      {'day': 'T2', 'liters': 1200.0, 'kwh': 14.0},
      {'day': 'T3', 'liters': 950.0, 'kwh': 11.0},
      {'day': 'T4', 'liters': 1400.0, 'kwh': 16.0},
      {'day': 'T5', 'liters': 1100.0, 'kwh': 13.0},
      {'day': 'T6', 'liters': 1300.0, 'kwh': 15.0},
      {'day': 'T7', 'liters': 850.0, 'kwh': 10.0},
      {'day': 'CN', 'liters': 1500.0, 'kwh': 18.0},
    ];

    final double totalWater = weeklyWater.map((e) => e['liters'] as double).reduce((a, b) => a + b);
    final double totalKwh = weeklyWater.map((e) => e['kwh'] as double).reduce((a, b) => a + b);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Báo Cáo Tài Nguyên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Resource Consumption & Analytics', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined, color: Colors.white),
            tooltip: 'Xuất Báo cáo Excel (.xlsx)',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang tạo và tải file báo cáo tài nguyên Excel (.xlsx)...'),
                  backgroundColor: Color(0xFF107C41),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            tooltip: 'Xuất Báo cáo PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang tạo báo cáo tổng hợp PDF tuần...')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard(
                    'Nước tưới tiêu thụ',
                    '${totalWater.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} Lít',
                    Icons.water_drop,
                    const Color(0xFF0284C7),
                    '-8.4% so với tuần trước',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpiCard(
                    'Điện năng bơm',
                    '${totalKwh.toInt()} kWh',
                    Icons.bolt,
                    const Color(0xFFD97706),
                    '-5.1% nhờ AutoRule tối ưu',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bar Chart: Water Consumption
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tiêu thụ nước trong tuần (Lít)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF062326).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('7 Ngày qua', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF062326))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 190,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: 1800,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 500,
                              getTitlesWidget: (val, _) => Text(
                                '${val.toInt()}',
                                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, _) {
                                int i = val.toInt();
                                if (i >= 0 && i < weeklyWater.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      weeklyWater[i]['day'] as String,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(weeklyWater.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: weeklyWater[i]['liters'] as double,
                                color: const Color(0xFF062326),
                                width: 14,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // VietGAP Compliance Audit Card
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
                      const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Tuân Thủ Ngưỡng VietGAP TCVN 11892',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildComplianceRow('Độ ẩm đất trong dải chuẩn (60-80%)', '96.2%', const Color(0xFF10B981)),
                  _buildComplianceRow('Nhiệt độ an toàn dưới 30°C', '98.5%', const Color(0xFF10B981)),
                  _buildComplianceRow('Số lần AutoRule tự xử lý', '42 lần', const Color(0xFF062326)),
                  _buildComplianceRow('Số sự cố vượt ngưỡng cần can thiệp', '0 lần', const Color(0xFF10B981)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildComplianceRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
