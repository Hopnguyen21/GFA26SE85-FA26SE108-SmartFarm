import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/utils/paging.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/state_views.dart';
import 'notification_navigation.dart';

/// Thông báo của kỹ thuật viên: yêu cầu mới được giao, hợp đồng đã ký/cọc, nghiệm thu, phiếu xuất kho được duyệt.
/// (Tab Thông báo của màn Cảnh báo & Tác vụ dành cho chủ trại/nông dân nên KTV cần màn riêng.)
class TechnicianNotificationsScreen extends StatefulWidget {
  const TechnicianNotificationsScreen({super.key});

  @override
  State<TechnicianNotificationsScreen> createState() =>
      _TechnicianNotificationsScreenState();
}

class _TechnicianNotificationsScreenState
    extends State<TechnicianNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FarmProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final items = sortNewestFirst(
      provider.notifications,
      (n) => parseTime(n.createdAt),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Thông Báo Kỹ Thuật',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          if (items.any((n) => !n.isRead))
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF34D399),
              ),
              onPressed: provider.markAllNotificationsAsRead,
              child: const Text(
                'Đọc hết',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.fetchNotifications,
        child: items.isEmpty
            ? ListView(
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
              )
            : PagedList<AppNotificationModel>(
                items: items,
                itemGap: 10,
                itemBuilder: (context, n) {
                  return Container(
                    decoration: BoxDecoration(
                      color: n.isRead ? Colors.white : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: n.isRead
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF86EFAC),
                        width: n.isRead ? 1 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: ValueKey('tech_notif_${n.notificationId}'),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          provider.markNotificationAsRead(n.notificationId);
                          openNotificationTarget(
                            context,
                            type: n.type,
                            referenceId: n.referenceId,
                            role: provider.currentRole,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: n.isRead
                                      ? const Color(0xFFF1F5F9)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  n.isRead
                                      ? Icons.notifications_none_outlined
                                      : Icons.notifications_active,
                                  color: n.isRead
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF047857),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: n.isRead
                                            ? FontWeight.bold
                                            : FontWeight.w900,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n.message,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFCCFBF1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            notificationTypeLabel(n.type),
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F766E),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            notificationTimeLabel(n.createdAt),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
