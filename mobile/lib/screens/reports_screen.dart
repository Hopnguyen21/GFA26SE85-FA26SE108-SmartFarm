import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';
import '../services/export_utils.dart';

/// Gom các bucket (theo zone/tháng) thành tổng theo zone.
Map<String, double> sumBucketsByZone(Map<String, dynamic>? report) {
  final out = <String, double>{};
  final buckets = (report?['buckets'] as List?) ?? const [];
  for (final b in buckets) {
    if (b is! Map) continue;
    final name = '${b['zoneName'] ?? ''}';
    out[name] = (out[name] ?? 0) + ((b['value'] as num?)?.toDouble() ?? 0);
  }
  return out;
}

/// Báo cáo tài nguyên lấy từ API báo cáo của backend; xuất Excel do backend tạo.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 30;
  bool _loading = true;
  bool _exporting = false;
  String? _error;
  Map<String, dynamic>? _overview;
  Map<String, dynamic>? _water;
  Map<String, dynamic>? _power;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  DateTime get _to => DateTime.now().toUtc();
  DateTime get _from => _to.subtract(Duration(days: _days));

  Future<void> _load() async {
    final farmId = Provider.of<FarmProvider>(context, listen: false).selectedFarmId;
    if (farmId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Chưa chọn trang trại.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        ApiService.getFarmReport(farmId, 'overview'),
        ApiService.getFarmReport(farmId, 'water-usage', from: _from, to: _to),
        ApiService.getFarmReport(farmId, 'electricity', from: _from, to: _to),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = r[0];
        _water = r[1];
        _power = r[2];
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting) return;
    final farmId = Provider.of<FarmProvider>(context, listen: false).selectedFarmId;
    setState(() => _exporting = true);
    try {
      final bytes = await ApiService.downloadFarmReportExcel(farmId, from: _from, to: _to);
      await saveAndShareFile(
        'bao-cao-tai-nguyen-${DateTime.now().toIso8601String().substring(0, 10)}.xlsx',
        bytes,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xuất Excel thất bại: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fmt(num? v, String unit) => v == null ? '—' : '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} $unit';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Báo Cáo Tài Nguyên', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.table_chart_outlined, color: Colors.white),
            tooltip: 'Xuất Excel (.xlsx) từ máy chủ',
            onPressed: _loading || _exporting || _error != null ? null : _exportExcel,
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'Làm mới', onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626))),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                ])))
              : _content(),
    );
  }

  Widget _content() {
    final waterByZone = sumBucketsByZone(_water);
    final totalWater = (_water?['total'] as num?)?.toDouble();
    final totalPower = (_power?['total'] as num?)?.toDouble();
    final o = _overview;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 ngày')),
              ButtonSegment(value: 30, label: Text('30 ngày')),
              ButtonSegment(value: 90, label: Text('90 ngày')),
            ],
            selected: {_days},
            onSelectionChanged: (s) {
              setState(() => _days = s.first);
              _load();
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _kpi('Nước tưới', _fmt(totalWater, '${_water?['unit'] ?? 'L'}'), Icons.water_drop, const Color(0xFF0284C7))),
            const SizedBox(width: 12),
            Expanded(child: _kpi('Điện năng', _fmt(totalPower, '${_power?['unit'] ?? 'kWh'}'), Icons.bolt, const Color(0xFFD97706))),
          ]),
          const SizedBox(height: 16),
          _card(
            'Nước tưới theo Zone',
            waterByZone.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Không có dữ liệu trong khoảng thời gian này.')))
                : SizedBox(height: 200, child: _zoneChart(waterByZone)),
          ),
          if (o != null) ...[
            const SizedBox(height: 16),
            _card(
              'Tổng quan trang trại',
              Column(children: [
                _row('Zone', '${o['zoneCount']}'),
                _row('Thiết bị online', '${o['onlineDeviceCount']}'),
                _row('Cảnh báo đang mở', '${o['openAlertCount']}'),
                _row('Công việc đang mở', '${o['openTaskCount']}'),
                _row('Vật tư sắp hết', '${o['lowStockItemCount']}'),
                _row('Yêu cầu bảo trì mở', '${o['openServiceRequestCount']}'),
                _row('Thu tháng này', '${o['revenueCurrentMonth']}'),
                _row('Chi tháng này', '${o['expenseCurrentMonth']}'),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Xuất PDF chưa được hỗ trợ (backend chỉ tạo Excel).', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _zoneChart(Map<String, double> data) {
    final entries = data.entries.toList();
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                final n = entries[i].key;
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(n.length > 8 ? '${n.substring(0, 8)}…' : n, style: const TextStyle(fontSize: 9)));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(x: i, barRods: [BarChartRodData(toY: entries[i].value, color: const Color(0xFF062326), width: 14)]),
        ],
      ),
    );
  }

  Widget _kpi(String title, String value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))), Icon(icon, size: 16, color: color)]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(l, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
          Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      );
}
