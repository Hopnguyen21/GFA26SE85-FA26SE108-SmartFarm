part of '../home_screen.dart';

extension _HomeScreenSensorCards on HomeScreen {
  Widget _buildSensorCard({
    required BuildContext context,
    required String zoneId,
    required String parameterCode,
    required String title,
    required String value,
    required String target,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool? isWarning,
    required String unit,
  }) {
    final isNoData = value == '—';
    String numStr = value;
    String unitStr = '';
    if (!isNoData) {
      if (value.endsWith('°C')) {
        numStr = value.substring(0, value.length - 2).trim();
        unitStr = '°C';
      } else if (value.endsWith('%')) {
        numStr = value.substring(0, value.length - 1).trim();
        unitStr = '%';
      } else if (value.endsWith(' lx')) {
        numStr = value.substring(0, value.length - 3).trim();
        unitStr = 'lx';
      } else if (unit.isNotEmpty && value.endsWith(unit)) {
        numStr = value.substring(0, value.length - unit.length).trim();
        unitStr = unit;
      }
    }

    final String statusLabel;
    final Color statusTextColor;
    final Color statusBgColor;

    if (isNoData) {
      statusLabel = 'Chờ đo';
      statusTextColor = const Color(0xFFB45309);
      statusBgColor = const Color(0xFFFFFBEB);
    } else if (isWarning == null) {
      statusLabel = 'Chưa đặt ngưỡng';
      statusTextColor = const Color(0xFF64748B);
      statusBgColor = const Color(0xFFF1F5F9);
    } else if (isWarning == true) {
      statusLabel = 'Cảnh báo';
      statusTextColor = const Color(0xFFDC2626);
      statusBgColor = const Color(0xFFFEF2F2);
    } else {
      statusLabel = 'Ổn định';
      statusTextColor = const Color(0xFF047857);
      statusBgColor = const Color(0xFFECFDF5);
    }

    return InkWell(
      onTap: zoneId.isNotEmpty
          ? () => _showSensorHistoryModal(
              context,
              zoneId,
              parameterCode,
              title,
              value,
              unit,
              icon,
              iconColor,
            )
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              isWarning == true
                  ? const Color(0xFFFFF1F2)
                  : bgColor.withValues(alpha: 0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isWarning == true
                ? const Color(0xFFFCA5A5)
                : (isNoData
                      ? const Color(0xFFE2E8F0)
                      : iconColor.withValues(alpha: 0.22)),
            width: isWarning == true ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isWarning == true
                  ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                  : iconColor.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.15),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 15),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: numStr,
                            style: TextStyle(
                              fontSize: isNoData ? 22 : 23,
                              fontWeight: FontWeight.w800,
                              color: isWarning == true
                                  ? const Color(0xFFDC2626)
                                  : (isNoData
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF0F172A)),
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (unitStr.isNotEmpty) ...[
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: unitStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isWarning == true
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: statusTextColor.withValues(alpha: 0.15),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: statusTextColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3.5),
                        Flexible(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    target,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.show_chart,
                  size: 13,
                  color: iconColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSensorHistoryModal(
    BuildContext context,
    String zoneId,
    String parameterCode,
    String title,
    String currentValue,
    String unit,
    IconData icon,
    Color iconColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Giá trị tức thời: $currentValue',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '24 giờ qua',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'BIỂU ĐỒ DIỄN BIẾN THEO THỜI GIAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: FarmApi.getTelemetryHistory(
                  zoneId: zoneId,
                  parameterCode: parameterCode,
                  fromUtc: DateTime.now().toUtc().subtract(
                    const Duration(hours: 24),
                  ),
                  toUtc: DateTime.now().toUtc(),
                  interval: '1h',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF10B981),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          'Không tải được lịch sử đo. Vui lòng thử lại sau.',
                        ),
                      ),
                    );
                  }
                  final points = snapshot.data ?? const [];
                  final history = points
                      .map((p) => (p['average'] as num?)?.toDouble())
                      .whereType<double>()
                      .toList();

                  if (history.isEmpty) {
                    return Container(
                      height: 180,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 40,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chưa có dữ liệu lịch sử',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final spots = history
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value))
                      .toList();
                  final rawMin = history.reduce((a, b) => a < b ? a : b);
                  final rawMax = history.reduce((a, b) => a > b ? a : b);
                  var minY = (rawMin * 0.9).floorToDouble();
                  var maxY = (rawMax * 1.1).ceilToDouble();
                  if (maxY <= minY) maxY = minY + 1;

                  return SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (maxY - minY) > 0
                              ? (maxY - minY) / 4
                              : 1,
                          getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (v, meta) => Text(
                                '${v.toInt()}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx >= 0 && idx < points.length) {
                                  final start = points[idx]['bucketStartUtc']
                                      ?.toString();
                                  if (start != null && start.length >= 16) {
                                    return Text(
                                      start.substring(11, 16),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (history.length - 1).toDouble(),
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: iconColor,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: iconColor.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dữ liệu vi khí hậu được tự động thu thập từ Sensor Node ESP32 mỗi 10 giây qua MQTT Broker.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
