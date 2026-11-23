import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/due_label.dart';
import '../../core/utils/user_error.dart';
import '../tasks/alerts_tasks_screen.dart';
import '../zones/zone_detail_screen.dart';

part 'parts/farmer_dashboard_widgets.dart';
part 'parts/farmer_dashboard_tasks.dart';
part 'parts/farmer_dashboard_zones.dart';
part 'parts/farmer_dashboard_irrigation.dart';

/// Trang chủ Nông dân: cùng bố cục và thao tác với web (`FarmerHome`):
/// hero + thời tiết + 4 chỉ số, lối tắt, cảnh báo, công việc, khu vực phụ trách, tưới thủ công BR-SAFE-01.
class FarmerDashboardScreen extends StatefulWidget {
  /// Chuyển tab của thanh điều hướng chính (1 = Cây trồng, 2 = Bản đồ GIS, 3 = Cảnh báo & Tác vụ).
  final ValueChanged<int>? onSelectTab;
  const FarmerDashboardScreen({super.key, this.onSelectTab});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

enum _TaskFilter { todo, review, done, all }

const Color _kGreen = Color(0xFF119653);

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  void _rebuild(VoidCallback fn) => setState(fn);

  _TaskFilter _filter = _TaskFilter.todo;
  final _zonesKey = GlobalKey();
  final _zoneSearch = TextEditingController();
  String _zoneQuery = '';
  bool _heroZonesOpen = false;
  ({bool ok, String message})? _feedback;

  @override
  void dispose() {
    _zoneSearch.dispose();
    super.dispose();
  }

  Future<void> _sync(FarmProvider provider) async {
    await provider.fetchFromApi();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          provider.isApiConnected
              ? 'Đã đồng bộ dữ liệu mới nhất từ SmartFarm API'
              : 'Không kết nối được máy chủ, đang dùng dữ liệu lưu tạm',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goTab(int index) {
    final cb = widget.onSelectTab;
    if (cb != null) {
      cb(index);
    } else {
      _openAlertsTasks(index == 3 ? 1 : 0);
    }
  }

  void _openAlertsTasks(int tab) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => AlertsTasksScreen(initialTab: tab)),
  );

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final zones = provider.assignedZonesForCurrentFarmer;
    final tasks = _sortedTasks(provider.tasks);
    final todo = tasks.where((t) => _matches(_TaskFilter.todo, t)).toList();
    final review = tasks.where((t) => _matches(_TaskFilter.review, t)).toList();
    final overdue = todo.where(_isOverdue).length;
    final openAlerts = provider.alerts.where((a) => !a.isAcknowledged).toList();
    final shown = tasks.where((t) => _matches(_filter, t)).toList();
    final pendingTasks = tasks.where((t) {
      final s = t.status.toLowerCase();
      return s == 'pending' || s == 'assigned';
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchFromApi(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            14,
            MediaQuery.of(context).padding.top + 12,
            14,
            24,
          ),
          children: [
            _buildHero(
              provider,
              zones,
              zones.length,
              todo.length,
              overdue,
              review.length,
              openAlerts.length,
            ),
            const SizedBox(height: 14),
            _buildQuickActions(provider, zones, todo.length, openAlerts.length),
            if (openAlerts.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildAlertBanner(openAlerts, {
                for (final z in zones) z.zoneId: z.name,
              }),
            ],
            if (pendingTasks.isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildNewTaskAlertBanner(provider, pendingTasks),
            ],
            if (_feedback != null) ...[
              const SizedBox(height: 14),
              _buildFeedback(),
            ],
            const SizedBox(height: 14),
            _buildTaskManager(
              provider,
              tasks,
              todo.length,
              review.length,
              shown,
            ),
            const SizedBox(height: 14),
            _buildZonesSection(provider, zones, openAlerts),
          ],
        ),
      ),
    );
  }
}
