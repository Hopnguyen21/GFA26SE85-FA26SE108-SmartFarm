import 'package:flutter/material.dart';
import '../widgets/task_actions.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import 'inspection_requests_screen.dart';
import 'equipment_orders_screen.dart';
import 'contracts_depreciation_screen.dart';

class AlertsTasksScreen extends StatelessWidget {
  const AlertsTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farmProvider = Provider.of<FarmProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          title: const Text('Thông Báo, Cảnh Báo & Tác Vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.white),
              tooltip: 'Đánh dấu đọc tất cả',
              onPressed: () => farmProvider.markAllNotificationsAsRead(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
              tooltip: 'Xóa thông báo đã đọc',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận dọn dẹp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    content: const Text('Bạn có chắc muốn xóa tất cả thông báo đã đọc không?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Xóa', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await farmProvider.deleteAllReadNotifications();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã dọn dẹp các thông báo đã đọc')),
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
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: farmProvider.unreadNotificationCount > 0,
                  label: Text('${farmProvider.unreadNotificationCount}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: const Color(0xFFEF4444),
                  child: const Icon(Icons.notifications_outlined, size: 18),
                ),
                text: 'Thông Báo',
              ),
              const Tab(icon: Icon(Icons.warning_amber_rounded, size: 18), text: 'Cảnh Báo (CF2)'),
              const Tab(icon: Icon(Icons.checklist, size: 18), text: 'Nhiệm Vụ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Notifications Tab
            farmProvider.notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text('Không có thông báo nào', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: farmProvider.notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = farmProvider.notifications[index];
                      final isCritical = notif.severity == 'Critical';
                      final isWarning = notif.severity == 'Warning';

                      Color badgeColor = const Color(0xFF10B981);
                      if (isCritical) {
                        badgeColor = const Color(0xFFEF4444);
                      } else if (isWarning) {
                        badgeColor = const Color(0xFFF59E0B);
                      }

                      return Dismissible(
                        key: ValueKey(notif.notificationId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.delete_outline, color: Colors.white, size: 24),
                              SizedBox(width: 6),
                              Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          farmProvider.deleteNotification(notif.notificationId);
                        },
                        child: InkWell(
                          onTap: () => farmProvider.markNotificationAsRead(notif.notificationId),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: notif.isRead ? Colors.white : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notif.isRead ? const Color(0xFFE2E8F0) : const Color(0xFF86EFAC),
                                width: notif.isRead ? 1 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCritical
                                        ? Icons.error_outline
                                        : (isWarning ? Icons.warning_amber_rounded : Icons.info_outline),
                                    color: badgeColor,
                                    size: 20,
                                  ),
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
                                              notif.title,
                                              style: TextStyle(
                                                fontWeight: notif.isRead ? FontWeight.bold : FontWeight.w900,
                                                fontSize: 13,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (!notif.isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF10B981),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.message,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            notif.type,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: badgeColor,
                                            ),
                                          ),
                                          Text(
                                            notif.createdAt,
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // Alerts Tab
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Banner Cảnh Báo Tài Sản & Hợp Đồng (Zone & Khấu Hao)
                if (farmProvider.currentRole == 'OWNER') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFD97706), size: 18),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'CẢNH BÁO HỢP ĐỒNG & KHẤU HAO THIẾT BỊ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hệ thống tự động theo dõi các hợp đồng thuê nhà màng sắp đến kỳ gia hạn (< 30 ngày) và thiết bị IoT chuẩn bị hết hạn trích khấu hao để lập kế hoạch thay thế.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF062326),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF10B981)),
                                label: const Text('Xem Cảnh Báo Hợp Đồng & Khấu Hao', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen(initialTabIndex: 2)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                ...farmProvider.alerts.map((alt) {
                  final isCritical = alt.severity == 'CRITICAL';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isCritical ? const Color(0xFFF87171) : const Color(0xFFFBBF24)),
                                  ),
                                  child: Text(
                                    isCritical ? 'NGUY CẤP' : 'CẢNH BÁO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                                if (alt.isBoundaryViolation) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF60A5FA)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_off, size: 10, color: Color(0xFF2563EB)),
                                        SizedBox(width: 3),
                                        Text(
                                          'RANH GIỚI GIS',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(alt.time, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(alt.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(alt.message, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (alt.isAcknowledged)
                              const Text('✓ Đã xác nhận xử lý', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold))
                            else
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF062326),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => farmProvider.acknowledgeAlert(alt.alertId),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Xác nhận đã xem', style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),

            // Tasks Tab
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick Assign Task Banner for OWNER
                if (farmProvider.currentRole == 'OWNER') ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF062326), Color(0xFF0F3B3F)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF062326).withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_task, color: Color(0xFF34D399), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Giao Việc Cho Nông Dân',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Phân công trực tiếp theo khu vực nhà màng & theo dõi tiến độ',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _showQuickAssignTaskDialog(context, farmProvider),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Giao việc', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                if (farmProvider.tasks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(Icons.checklist_rtl_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có nhiệm vụ nào cần thực hiện',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                else
                  ...farmProvider.tasks.map((task) {
                    final isInspection = task.taskId.startsWith('tsk-req') || task.title.contains('Khảo sát');
                    final isOrder = task.taskId.startsWith('tsk-ord') || task.title.contains('Cọc 30%') || task.title.contains('đơn hàng');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isOrder
                              ? const Color(0xFFD97706).withValues(alpha: 0.5)
                              : isInspection
                                  ? const Color(0xFF0284C7).withValues(alpha: 0.4)
                                  : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              color: task.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ),
                                        if (isOrder)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Cọc 30%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                          )
                                        else if (isInspection)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0F2FE),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('Thực địa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${task.zoneName} • Hạn: ${task.dueDate}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    if (task.assignedFarmerName != null && task.assignedFarmerName!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.person_pin_circle_outlined, size: 13, color: Color(0xFF0F766E)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Giao cho: ${task.assignedFarmerName}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F766E),
                                            ),
                                          ),
                                          if (task.priority.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: task.priority == 'HIGH'
                                                    ? const Color(0xFFFEE2E2)
                                                    : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                task.priority == 'HIGH' ? 'Ưu tiên cao' : 'Bình thường',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: task.priority == 'HIGH' ? const Color(0xFFB91C1C) : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                    TaskActions(task: task, isOwner: farmProvider.currentRole != 'FARMER'),
                                    if (task.description != null && task.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        task.description!,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isOrder) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const EquipmentOrdersScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.payment, size: 14),
                                  label: const Text('Xem đơn & Cọc 30%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (isInspection) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const InspectionRequestsScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.description_outlined, size: 14, color: Color(0xFF0284C7)),
                                  label: const Text('Xem phiếu phân công', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAssignTaskDialog(BuildContext context, FarmProvider farmProvider) {
    final farmers = farmProvider.farmersForCurrentFarm;
    if (farmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có danh sách Nông dân để giao việc')),
      );
      return;
    }

    String selectedFarmerId = farmers.first.farmerId;
    String selectedZoneId = farmProvider.zones.isNotEmpty ? farmProvider.zones.first.zoneId : 'zone-01';
    final titleCtrl = TextEditingController(text: 'Tưới nhỏ giọt & kiểm tra độ ẩm đất');
    final descCtrl = TextEditingController();
    String priority = 'HIGH';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    final presets = [
      'Tưới nhỏ giọt & kiểm tra độ ẩm đất',
      'Tỉa cành & bấm ngọn chồi nách',
      'Châm dung dịch dinh dưỡng NPK',
      'Phun chế phẩm sinh học phòng trừ sâu',
      'Thu hoạch và phân loại VietGAP',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (modalCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final targetZone = farmProvider.zones.firstWhere(
            (z) => z.zoneId == selectedZoneId,
            orElse: () => farmProvider.zones.first,
          );
          final targetFarmer = farmers.firstWhere(
            (f) => f.farmerId == selectedFarmerId,
            orElse: () => farmers.first,
          );

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
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_add, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giao Việc Cho Nông Dân',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Phân công công việc theo từng khu vực',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chọn Nông dân
                  const Text('Chọn Nông dân phụ trách: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFarmerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: farmers.map((f) => DropdownMenuItem(
                      value: f.farmerId,
                      child: Text('${f.name} (${f.role})', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedFarmerId = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Chọn Nhà màng
                  if (farmProvider.zones.isNotEmpty) ...[
                    const Text('Chọn Nhà màng / Khu vực thực hiện: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZoneId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: farmProvider.zones.map((z) => DropdownMenuItem(
                        value: z.zoneId,
                        child: Text('${z.name} (${z.currentCrop})', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedZoneId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Mẫu việc nhanh
                  const Text('Mẫu công việc phổ biến:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setModalState(() => titleCtrl.text = preset),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(preset, style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155))),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tiêu đề
                  const Text('Tiêu đề công việc: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung công việc...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mức ưu tiên & Hạn hoàn thành
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mức độ ưu tiên:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'LOW', child: Text('🟢 Bình thường', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'MEDIUM', child: Text('🟡 Trung bình', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'HIGH', child: Text('🔴 Khẩn cấp', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => priority = v);
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
                            const Text('Hạn hoàn thành:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: dueDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 90)),
                                );
                                if (picked != null) setModalState(() => dueDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontSize: 12)),
                                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ghi chú
                  const Text('Yêu cầu chi tiết / Ghi chú:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Mô tả chi tiết kỹ thuật...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          child: const Text('Hủy'),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Xác Nhận Giao Việc', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng nhập tiêu đề công việc!')),
                              );
                              return;
                            }
                            final dueStr = 'Ngày ${dueDate.day}/${dueDate.month}, 17:00';
                            final messenger = ScaffoldMessenger.of(context);
                            final error = await farmProvider.addTask(
                              title: titleCtrl.text.trim(),
                              zoneName: targetZone.name.split(' - ').first,
                              priority: priority,
                              dueDate: dueStr,
                              assignedFarmerId: targetFarmer.farmerId,
                              assignedFarmerName: targetFarmer.name,
                              description: descCtrl.text.trim(),
                              zoneId: selectedZoneId,
                              dueAt: DateTime(dueDate.year, dueDate.month, dueDate.day, 17),
                            );
                            if (error != null) {
                              messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)));
                              return;
                            }
                            if (modalCtx.mounted) Navigator.pop(modalCtx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('📋 Đã giao việc cho ${targetFarmer.name}!'),
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
      ),
    );
  }
}
