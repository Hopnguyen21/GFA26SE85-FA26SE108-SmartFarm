part of '../alerts_tasks_screen.dart';

extension _AlertsTasksScreenNotificationsTab on AlertsTasksScreen {
  List<Widget> _notificationsTab(BuildContext context, FarmProvider farmProvider) {
    return [
      // Notifications Tab
      farmProvider.notifications.isEmpty
          ? RefreshIndicator(
              onRefresh: farmProvider.fetchNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 360,
                    child: AppEmptyState(icon: Icons.notifications_off_outlined, message: 'Không có thông báo nào'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: farmProvider.fetchNotifications,
              child: ListView.separated(
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
                          Text(
                            'Xóa',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
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
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
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
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                                      ),
                                      Text(
                                        notif.createdAt,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
            ),
    ];
  }
}
