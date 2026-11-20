import 'package:flutter/material.dart';
import 'widgets/task_actions.dart';
import 'notification_navigation.dart';
import '../../core/models/models.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/utils/paging.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/state_views.dart';
import '../../core/providers/farm_provider.dart';
import '../contracts/contracts_depreciation_screen.dart';
import '../zones/zone_detail_screen.dart';
import '../../core/widgets/dispose_later.dart';
import '../../core/utils/due_label.dart';

part 'parts/alerts_tasks_screen_notifications_tab.dart';
part 'parts/alerts_tasks_screen_alerts_tab.dart';
part 'parts/alerts_tasks_screen_tasks_tab.dart';
part 'parts/alerts_tasks_screen_quick_assign.dart';

/// Danh sách Nhiệm vụ (giao việc nhanh, trạng thái, phân trang) dùng riêng, không kèm AppBar/TabBar của màn Thông báo.
class TasksTabView extends StatelessWidget {
  const TasksTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    return const AlertsTasksScreen()._tasksTab(context, provider).first;
  }
}

class AlertsTasksScreen extends StatelessWidget {
  /// 0 = Thông báo, 1 = Cảnh báo, 2 = Nhiệm vụ.
  final int initialTab;
  const AlertsTasksScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);

    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text(
            'Thông Báo, Cảnh Báo & Tác Vụ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: 'Đánh dấu đọc tất cả',
              onPressed: () => farmProvider.markAllNotificationsAsRead(),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_outlined,
                color: Colors.white70,
              ),
              tooltip: 'Xóa thông báo đã đọc',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text(
                      'Xác nhận dọn dẹp',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    content: const Text(
                      'Bạn có chắc muốn xóa tất cả thông báo đã đọc không?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Xóa',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await farmProvider.deleteAllReadNotifications();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã dọn dẹp các thông báo đã đọc'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: const Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: const Color(0xFF94A3B8),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: farmProvider.unreadNotificationCount > 0,
                  label: Text(
                    '${farmProvider.unreadNotificationCount}',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(Icons.notifications_outlined, size: 18),
                ),
                text: 'Thông Báo',
              ),
              const Tab(
                icon: Icon(Icons.warning_amber_rounded, size: 18),
                text: 'Cảnh Báo (CF2)',
              ),
              const Tab(
                icon: Icon(Icons.checklist, size: 18),
                text: 'Nhiệm Vụ',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ..._notificationsTab(context, farmProvider),
            ..._alertsTab(context, farmProvider),
            ..._tasksTab(context, farmProvider),
          ],
        ),
      ),
    );
  }
}
