import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/export_utils.dart';
import '../../core/utils/user_error.dart';
import '../home/zone_sensor_thresholds.dart';
import 'monitoring_history_logic.dart';

class MonitoringHistoryScreen extends StatefulWidget {
  const MonitoringHistoryScreen({super.key});

  @override
  State<MonitoringHistoryScreen> createState() =>
      _MonitoringHistoryScreenState();
}

class _MonitoringHistoryScreenState extends State<MonitoringHistoryScreen> {
  // Selected metric: 'SOIL_MOISTURE', 'TEMP', 'HUMIDITY', 'LIGHT', 'PH', 'EC'
  String _selectedMetric = 'SOIL_MOISTURE';
  String _timeRange = '24 Giờ';
  String? _selectedDeviceId;
  List<Map<String, dynamic>> _zoneDevices = [];
  String? _lastLoadedZoneId;
  bool _isLoadingLive = false;
  String? _historyError;
  int _historySeq = 0;
  List<double>? _liveData;
  List<String>? _liveLabels;
  List<Map<String, dynamic>>? _livePoints;
  String?
  _loadedKey; // lựa chọn (Zone|chỉ số|khoảng|thiết bị) mà dữ liệu đang hiển thị thuộc về
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
    if (_lastLoadedZoneId != zoneId) {
      _lastLoadedZoneId = zoneId;
      _selectedDeviceId = null;
      try {
        final devs = await FarmApi.getDeviceMapLocations(zoneId);
        if (mounted) setState(() => _zoneDevices = devs);
      } catch (_) {}
    }
    final seq = ++_historySeq;
    final key = historyKey(
      zoneId,
      _selectedMetric,
      _timeRange,
      _selectedDeviceId,
    );
    setState(() {
      _isLoadingLive = true;
      _historyError = null;
      // Đổi chỉ số/khoảng: bỏ dữ liệu của lựa chọn cũ, nếu không biểu đồ vẽ số của chỉ số trước dưới tiêu đề, đơn vị và trục của chỉ số mới.
      if (_loadedKey != key) {
        _liveData = null;
        _liveLabels = null;
        _livePoints = null;
      }
    });
    try {
      final paramCode = monitoringParameterCode(_selectedMetric);
      final now = DateTime.now().toUtc();
      final (from, interval) = switch (_timeRange) {
        '7 Ngày' => (now.subtract(const Duration(days: 7)), '6h'),
        '30 Ngày' => (now.subtract(const Duration(days: 30)), '1d'),
        _ => (now.subtract(const Duration(hours: 24)), '1h'),
      };
      final points = await FarmApi.getTelemetryHistory(
        zoneId: zoneId,
        parameterCode: paramCode,
        deviceId: _selectedDeviceId,
        fromUtc: from,
        toUtc: now,
        interval: interval,
      );
      if (!mounted || seq != _historySeq) return;
      if (points.isNotEmpty) {
        final series = buildHistorySeries(points, _timeRange);
        if (series.values.isNotEmpty) {
          setState(() {
            _liveData = series.values;
            _liveLabels = series.labels;
            _livePoints = points;
            _loadedKey = key;
            _isLoadingLive = false;
          });
          return;
        }
      }
    } catch (e) {
      if (!mounted || seq != _historySeq) return;
      _historyError = 'Không tải được lịch sử đo: ${userFacingError(e)}';
    }
    if (mounted && seq == _historySeq) {
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
      final csv = buildTelemetryCsv(
        zoneName: zoneName,
        metric: _selectedMetric,
        range: _timeRange,
        points: points,
      );
      await saveAndShareFile(
        'lich-su-${_selectedMetric.toLowerCase()}-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
        utf8.encode(csv),
        mimeType: 'text/csv',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xuất CSV thất bại: ${userFacingError(e)}')),
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

    final currentData = _liveData ?? const <double>[];
    final currentLabels = _liveLabels ?? const <String>[];
    final hasData = currentData.isNotEmpty;

    final String unit;
    final String metricTitle;
    final Color chartColor;

    switch (_selectedMetric) {
      case 'TEMP':
        unit = '°C';
        metricTitle = 'Nhiệt độ không khí';
        chartColor = const Color(0xFFD97706);
        break;
      case 'HUMIDITY':
        unit = '%';
        metricTitle = 'Độ ẩm không khí';
        chartColor = const Color(0xFF0284C7);
        break;
      case 'LIGHT':
        unit = ' lux';
        metricTitle = 'Cường độ ánh sáng';
        chartColor = const Color(0xFFCA8A04);
        break;
      case 'PH':
        unit = ' pH';
        metricTitle = 'Độ chua (pH)';
        chartColor = const Color(0xFF7C3AED);
        break;
      case 'EC':
        unit = ' mS/cm';
        metricTitle = 'Độ dẫn điện (EC)';
        chartColor = const Color(0xFF0891B2);
        break;
      default:
        unit = '%';
        metricTitle = 'Độ ẩm đất';
        chartColor = const Color(0xFF10B981);
    }

    // Ngưỡng THẬT của giai đoạn đang canh tác (zone.appliedRequirements); không có thì không vẽ ngưỡng, không dùng số cố định.
    final zone = provider.currentZone;
    final requirement = requirementFor(
      zone,
      monitoringParameterCode(_selectedMetric),
    );
    final double? minTarget = requirement?.min;
    final double? maxTarget = requirement?.max;
    final double minY = 0.0;
    final double maxY = switch (_selectedMetric) {
      'PH' => 14.0,
      'EC' => 5.0,
      'LIGHT' => math.max(
        60000.0,
        ((hasData ? currentData.reduce(math.max) : 0.0) * 1.15),
      ),
      'TEMP' => 50.0,
      _ => 100.0,
    };
    final double yInterval = switch (_selectedMetric) {
      'PH' => 2.0,
      'EC' => 1.0,
      'LIGHT' => (maxY / 5).roundToDouble(),
      'TEMP' => 10.0,
      _ => 20.0,
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lịch Sử Vi Khí Hậu & Đất',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '6 thông số vi khí hậu & ngưỡng an toàn cây trồng',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            tooltip: 'Xuất CSV/Excel',
            onPressed: (_exporting || !hasData)
                ? null
                : () => _exportCsv(provider.currentZone.name),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Metric Chips (Scrollable horizontal row)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildMetricChip(
                    'SOIL_MOISTURE',
                    'Độ ẩm đất',
                    Icons.water_drop,
                    const Color(0xFF10B981),
                    zoneId,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'TEMP',
                    'Nhiệt độ',
                    Icons.thermostat,
                    const Color(0xFFD97706),
                    zoneId,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'HUMIDITY',
                    'Độ ẩm KK',
                    Icons.cloud,
                    const Color(0xFF0284C7),
                    zoneId,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'LIGHT',
                    'Ánh sáng',
                    Icons.wb_sunny_outlined,
                    const Color(0xFFCA8A04),
                    zoneId,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'PH',
                    'Độ pH',
                    Icons.science_outlined,
                    const Color(0xFF7C3AED),
                    zoneId,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricChip(
                    'EC',
                    'Dinh dưỡng EC',
                    Icons.bolt,
                    const Color(0xFF0891B2),
                    zoneId,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_zoneDevices.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sensors,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Thiết bị: ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedDeviceId,
                          isDense: true,
                          isExpanded: true,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF1E293B),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tất cả thiết bị trong Zone'),
                            ),
                            for (final d in _zoneDevices)
                              DropdownMenuItem(
                                value: '${d['deviceId']}',
                                child: Text(
                                  '${d['name'] ?? d['serialNumber'] ?? d['deviceId']} (${d['deviceType'] ?? 'Node'})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedDeviceId = v);
                            _fetchLiveHistory(zoneId);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Khoảng thời gian luôn hiển thị (kể cả khi khoảng đang chọn không có dữ liệu) để người dùng đổi lại được.
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Khoảng thời gian:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                for (final r in monitoringRanges)
                  ChoiceChip(
                    key: ValueKey('range_$r'),
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    selected: _timeRange == r,
                    onSelected: (_) {
                      if (_timeRange == r) return;
                      setState(() => _timeRange = r);
                      _fetchLiveHistory(zoneId);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (!hasData)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 48,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingLive)
                      const CircularProgressIndicator()
                    else ...[
                      Icon(
                        Icons.query_stats_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _historyError ??
                            'Chưa có dữ liệu lịch sử ($metricTitle) cho khoảng thời gian này.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(100, 44),
                        ),
                        onPressed: () => _fetchLiveHistory(zoneId),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ],
                ),
              )
            else ...[
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (_isLoadingLive) ...[
                                  const SizedBox(width: 8),
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF10B981),
                                    ),
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
                                  decoration: BoxDecoration(
                                    color: chartColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  // Là trung bình của mốc gần nhất trong khoảng đã chọn, không phải số đo tức thời.
                                  'Gần nhất: ${currentData.last}$unit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: chartColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Khoảng thời gian chọn ở thanh lọc phía trên (luôn hiển thị), ở đây chỉ nhắc lại đang xem khoảng nào.
                        Text(
                          _timeRange,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062326),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Target Bounds Legend
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: (minTarget == null || maxTarget == null)
                          // Không có ngưỡng của giai đoạn hiện tại: nói rõ lý do, không dùng số cố định.
                          ? Text(
                              thresholdCaption(
                                zone,
                                monitoringParameterCode(_selectedMetric),
                                unit,
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 2,
                                      color: const Color(0xFFE11D48),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ngưỡng Min ($minTarget$unit)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 2,
                                      color: const Color(0xFFE11D48),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Ngưỡng Max ($maxTarget$unit)',
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
                    const SizedBox(height: 20),

                    // FlChart
                    SizedBox(
                      height: 220,
                      child: RepaintBoundary(
                        child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            enabled: true,
                            handleBuiltInTouches: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => const Color(0xFF0F172A),
                              tooltipBorderRadius: BorderRadius.circular(8),
                              tooltipPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final idx = spot.spotIndex;
                                  final timeStr =
                                      (idx >= 0 && idx < currentLabels.length)
                                      ? currentLabels[idx]
                                      : '';
                                  return LineTooltipItem(
                                    '${timeStr.isNotEmpty ? '$timeStr\n' : ''}${spot.y}$unit',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: yInterval,
                            getDrawingHorizontalLine: (value) {
                              return const FlLine(
                                color: Color(0xFFF1F5F9),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              if (minTarget != null && maxTarget != null) ...[
                                HorizontalLine(
                                  y: minTarget,
                                  color: const Color(
                                    0xFFE11D48,
                                  ).withValues(alpha: 0.5),
                                  strokeWidth: 1,
                                  dashArray: [4, 4],
                                ),
                                HorizontalLine(
                                  y: maxTarget,
                                  color: const Color(
                                    0xFFE11D48,
                                  ).withValues(alpha: 0.5),
                                  strokeWidth: 1,
                                  dashArray: [4, 4],
                                ),
                              ],
                            ],
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: _selectedMetric == 'LIGHT'
                                    ? 44
                                    : 32,
                                interval: yInterval,
                                getTitlesWidget: (value, meta) {
                                  if (value > maxY || value < minY) {
                                    return const SizedBox();
                                  }
                                  final label =
                                      (_selectedMetric == 'PH' ||
                                          _selectedMetric == 'EC')
                                      ? value.toStringAsFixed(1)
                                      : value.toInt().toString();
                                  return Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: currentLabels.length > 8
                                    ? (currentLabels.length / 5)
                                          .ceil()
                                          .toDouble()
                                    : 2,
                                getTitlesWidget: (value, meta) {
                                  int idx = value.toInt();
                                  if (idx >= 0 && idx < currentLabels.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        currentLabels[idx],
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
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
                          minY: minY,
                          maxY: maxY,
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
                    const Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          size: 16,
                          color: Color(0xFF047857),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tổng quan thống kê trong khoảng thời gian',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Cao nhất',
                          '${currentData.reduce((a, b) => a > b ? a : b)}$unit',
                          const Color(0xFFDC2626),
                          Icons.arrow_upward,
                        ),
                        _buildStatItem(
                          'Thấp nhất',
                          '${currentData.reduce((a, b) => a < b ? a : b)}$unit',
                          const Color(0xFF2563EB),
                          Icons.arrow_downward,
                        ),
                        _buildStatItem(
                          'Trung bình',
                          '${(currentData.reduce((a, b) => a + b) / currentData.length).toStringAsFixed(1)}$unit',
                          const Color(0xFF047857),
                          Icons.functions,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(
    String metricKey,
    String label,
    IconData icon,
    Color color,
    String zoneId,
  ) {
    final isSelected = _selectedMetric == metricKey;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label, ${isSelected ? "đang chọn" : ""}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (_selectedMetric != metricKey) {
              setState(() => _selectedMetric = metricKey);
              _fetchLiveHistory(zoneId);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFE2E8F0),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: isSelected ? Colors.white : color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
