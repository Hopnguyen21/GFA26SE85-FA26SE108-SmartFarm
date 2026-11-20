part of '../alerts_tasks_screen.dart';

extension _AlertsTasksScreenNotificationsTab on AlertsTasksScreen {
  List<Widget> _notificationsTab(
    BuildContext context,
    FarmProvider farmProvider,
  ) {
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
                    child: AppEmptyState(
                      icon: Icons.notifications_off_outlined,
                      message: 'Không có thông báo nào',
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: farmProvider.fetchNotifications,
              child: PagedList<AppNotificationModel>(
                items: sortNewestFirst(
                  farmProvider.notifications,
                  (n) => parseTime(n.createdAt),
                ),
                itemGap: 10,
                itemBuilder: (context, notif) {
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
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Xóa',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) {
                      farmProvider.deleteNotification(notif.notificationId);
                    },
                    child: InkWell(
                      onTap: () {
                        farmProvider.markNotificationAsRead(
                          notif.notificationId,
                        );
                        final targetZone = resolveZoneForNotification(
                          notif: notif,
                          provider: farmProvider,
                        );
                        openNotificationTarget(
                          context,
                          type: notif.type,
                          referenceId: notif.referenceId,
                          role: farmProvider.currentRole,
                          zone: targetZone,
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: notif.isRead
                              ? Colors.white
                              : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: notif.isRead
                                ? const Color(0xFFE2E8F0)
                                : const Color(0xFF86EFAC),
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
                                    : (isWarning
                                          ? Icons.warning_amber_rounded
                                          : Icons.info_outline),
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
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif.title,
                                          style: TextStyle(
                                            fontWeight: notif.isRead
                                                ? FontWeight.bold
                                                : FontWeight.w900,
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
                                    cleanTrailingZeros(notif.message),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569),
                                      height: 1.35,
                                    ),
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final targetZone =
                                          resolveZoneForNotification(
                                            notif: notif,
                                            provider: farmProvider,
                                          );
                                      if (targetZone == null &&
                                          notif.type != 'Alert') {
                                        return const SizedBox.shrink();
                                      }
                                      final zoneName =
                                          targetZone?.name.isNotEmpty == true
                                          ? targetZone!.name
                                          : 'Khu vực cảnh báo';
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          bottom: 2,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFF047857,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFFA7F3D0),
                                              ),
                                              backgroundColor: const Color(
                                                0xFFECFDF5,
                                              ),
                                              minimumSize: const Size(0, 32),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.place_outlined,
                                              size: 13,
                                            ),
                                            label: Text(
                                              'Tới khu vực: $zoneName',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            onPressed: () {
                                              farmProvider
                                                  .markNotificationAsRead(
                                                    notif.notificationId,
                                                  );
                                              final z =
                                                  targetZone ??
                                                  (farmProvider
                                                          .allZones
                                                          .isNotEmpty
                                                      ? farmProvider
                                                            .allZones
                                                            .first
                                                      : null);
                                              if (z != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ZoneDetailScreen(
                                                          zone: z,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          border: Border.all(
                                            color: badgeColor.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          notificationTypeLabel(notif.type),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        notificationTimeLabel(notif.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
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
