import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import '../services/export_utils.dart';

class MonitoringHistoryScreen extends StatefulWidget {
  const MonitoringHistoryScreen({super.key});

  @override
  State<MonitoringHistoryScreen> createState() => _MonitoringHistoryScreenState();
}

class _MonitoringHistoryScreenState extends State<MonitoringHistoryScreen> {
  // Selected metric: 'SOIL_MOISTURE', 'TEMP', 'HUMIDITY'
  String _selectedMetric = 'SOIL_MOISTURE';
  String _timeRange = '24 Giờ';
  bool _isLoadingLive = false;
  List<double>? _liveData;
  List<String>? _liveLabels;
  List<Map<String, dynamic>>? _livePoints;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FarmProvider>(context, listen: false);
      _fetchLiveHistory(provider.currentZone.zoneId);
    });
  }

  Future<void> _fetchLiveHistory(String zoneId) async {
    if (zoneId.isEmpty) return;
    setState(() => _isLoadingLive = true);
    try {
      final paramCode = switch (_selectedMetric) {
        'TEMP' => 'Temperature',
        'HUMIDITY' => 'AirHumidity',
        _ => 'SoilMoisture',
      };
      final now = DateTime.now().toUtc();
      final (from, interval) = switch (_timeRange) {
        '7 Ngày' => (now.subtract(const Duration(days: 7)), '6h'),
        '30 Ngày' => (now.subtract(const Duration(days: 30)), '1d'),
        _ => (now.subtract(const Duration(hours: 24)), '1h'),
      };
      final points = await ApiService.getTelemetryHistory(
        zoneId: zoneId,
        parameterCode: paramCode,
        fromUtc: from,
        toUtc: now,
        interval: interval,
      );
      if (!mounted) return;
      if (points.isNotEmpty) {
        final values = <double>[];
        final labels = <String>[];
        for (var p in points) {
          final avg = (p['average'] as num?)?.toDouble();
          if (avg != null) values.add(double.parse(avg.toStringAsFixed(1)));
          final start = p['bucketStartUtc']?.toString();
          if (start != null && start.length >= 16) {
            labels.add(start.substring(11, 16));
          } else {
            labels.add('');
          }
        }
        if (values.isNotEmpty) {
          setState(() {
            _liveData = values;
            _liveLabels = labels;
            _livePoints = points;
            _isLoadingLive = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _liveData = null;
        _liveLabels = null;
        _livePoints = null;
        _isLoadingLive = false;
      });
    }
  }

  /// Xuất CSV từ đúng dữ liệu lịch sử đã tải (zone, chỉ số, khoảng thời gian đang chọn).
  Future<void> _exportCsv(String zoneName) async {
    final points = _livePoints;
    if (points == null || points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dữ liệu lịch sử thật để xuất.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final csv = buildTelemetryCsv(zoneName: zoneName, metric: _selectedMetric, range: _timeRange, points: points);
      await saveAndShareFile(
        'lich-su-${_selectedMetric.toLowerCase()}-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        utf8.encode(csv),
        mimeType: 'text/csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xuất CSV thất bại: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final zoneId = provider.currentZone.zoneId;

    List<double> currentData;
    List<String> currentLabels;
    String unit;
    String metricTitle;
    Color chartColor;
    double minTarget;
    double maxTarget;

    switch (_selectedMetric) {
      case 'TEMP':
        currentData = _liveData ?? const <double>[];
        currentLabels = _liveLabels ?? const <String>[];
        unit = '°C';
        metricTitle = _liveData != null ? 'Nhiệt độ không khí' : 'Nhiệt độ không khí';
        chartColor = const Color(0xFFD97706);
        minTarget = 18.0;
        maxTarget = 28.0;
        break;
      case 'HUMIDITY':
        currentData = _liveData ?? const <double>[];
        currentLabels = _liveLabels ?? const <String>[];
        unit = '%';
        metricTitle = _liveData != null ? 'Độ ẩm không khí' : 'Độ ẩm không khí';
        chartColor = const Color(0xFF0284C7);
        minTarget = 65.0;
        maxTarget = 85.0;
        break;
      default:
        currentData = _liveData ?? const <double>[];
        currentLabels = _liveLabels ?? const <String>[];
        unit = '%';
        metricTitle = _liveData != null ? 'Độ ẩm đất' : 'Độ ẩm đất';
        chartColor = const Color(0xFF10B981);
        minTarget = 60.0;
        maxTarget = 80.0;
    }

    if (currentData.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Lịch Sử Vi Khí Hậu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        body: Center(
          child: _isLoadingLive
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Chưa có dữ liệu lịch sử cho khu vực và khoảng thời gian này.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => _fetchLiveHistory(zoneId), child: const Text('Tải lại')),
                  ]),
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch Sử Vi Khí Hậu',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Historical Analytics & Safe-Zone Bounds',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Xuất CSV/Excel',
            onPressed: _exporting ? null : () => _exportCsv(provider.currentZone.name),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Metric Chips
            Row(
              children: [
                _buildMetricChip('SOIL_MOISTURE', 'Độ ẩm đất', Icons.water_drop, const Color(0xFF10B981), zoneId),
                const SizedBox(width: 8),
                _buildMetricChip('TEMP', 'Nhiệt độ', Icons.thermostat, const Color(0xFFD97706), zoneId),
                const SizedBox(width: 8),
                _buildMetricChip('HUMIDITY', 'Độ ẩm KK', Icons.cloud, const Color(0xFF0284C7), zoneId),
              ],
            ),
            const SizedBox(height: 16),

            // Main Chart Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                metricTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              if (_isLoadingLive) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: chartColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Hiện tại: ${currentData.last}$unit',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: chartColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Time Filter
                      DropdownButton<String>(
                        value: _timeRange,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF062326)),
                        items: ['24 Giờ', '7 Ngày', '30 Ngày'].map((e) {
                          return DropdownMenuItem(value: e, child: Text(e));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _timeRange = val);
                            _fetchLiveHistory(zoneId);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Target Bounds Legend
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            Container(width: 12, height: 2, color: const Color(0xFFE11D48)),
                            const SizedBox(width: 6),
                            Text('Ngưỡng Min ($minTarget$unit)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                        Row(
                          children: [
                            Container(width: 12, height: 2, color: const Color(0xFFE11D48)),
                            const SizedBox(width: 6),
                            Text('Ngưỡng Max ($maxTarget$unit)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // FlChart
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 15,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: Color(0xFFF1F5F9),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 20,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: currentLabels.length > 8 ? (currentLabels.length / 5).ceil().toDouble() : 2,
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx >= 0 && idx < currentLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      currentLabels[idx],
                                      style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (currentData.length - 1).toDouble(),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              currentData.length,
                              (i) => FlSpot(i.toDouble(), currentData[i]),
                            ),
                            isCurved: true,
                            color: chartColor,
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: chartColor.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Summary Card
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
                  const Text('Tổng quan thống kê trong ngày', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Cao nhất', '${currentData.reduce((a, b) => a > b ? a : b)}$unit', Colors.red[600]!),
                      _buildStatItem('Thấp nhất', '${currentData.reduce((a, b) => a < b ? a : b)}$unit', Colors.blue[600]!),
                      _buildStatItem('Trung bình', '${(currentData.reduce((a, b) => a + b) / currentData.length).toStringAsFixed(1)}$unit', const Color(0xFF10B981)),
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

  Widget _buildMetricChip(String metricKey, String label, IconData icon, Color color, String zoneId) {
    final isSelected = _selectedMetric == metricKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedMetric = metricKey);
          _fetchLiveHistory(zoneId);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
