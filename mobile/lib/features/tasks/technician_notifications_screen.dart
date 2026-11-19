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

enum _NotifFilter { all, unread, service, stockOut }

class _TechnicianNotificationsScreenState
    extends State<TechnicianNotificationsScreen> {
  _NotifFilter _selectedFilter = _NotifFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FarmProvider>().fetchNotifications();
    });
  }

  List<AppNotificationModel> _applyFilter(List<AppNotificationModel> items) {
    return switch (_selectedFilter) {
      _NotifFilter.all => items,
      _NotifFilter.unread => items.where((n) => !n.isRead).toList(),
      _NotifFilter.service => items.where((n) => n.type == 'Service').toList(),
      _NotifFilter.stockOut =>
        items.where((n) => n.type == 'StockOut').toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final items = sortNewestFirst(
      provider.notifications,
      (n) => parseTime(n.createdAt),
    );
    final filtered = _applyFilter(items);
    final hasUnread = items.any((n) => !n.isRead);
    final hasRead = items.any((n) => n.isRead);

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
          if (hasUnread)
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            tooltip: 'Tùy chọn',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (val) {
              if (val == 'read_all') {
                provider.markAllNotificationsAsRead();
              } else if (val == 'delete_read') {
                _confirmDeleteAllRead(context, provider);
              } else if (val == 'refresh') {
                provider.fetchNotifications();
              }
            },
            itemBuilder: (ctx) => [
              if (hasUnread)
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đọc tất cả',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasRead)
                const PopupMenuItem(
                  value: 'delete_read',
                  child: Row(
                    children: [
                      Icon(
                        Icons.cleaning_services_outlined,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Xóa thông báo đã đọc',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 18, color: Color(0xFF047857)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tải lại danh sách',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                key: ValueKey(_selectedFilter),
                items: filtered,
                itemGap: 10,
                header: [
                  _buildHeader(provider, items),
                  if (filtered.isEmpty) ...[
                    const SizedBox(height: 24),
                    _buildEmptyFilterState(),
                  ],
                ],
                itemBuilder: (context, n) => _buildNotificationCard(
                  context,
                  n,
                  provider,
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(
    FarmProvider provider,
    List<AppNotificationModel> allItems,
  ) {
    final unreadCount = allItems.where((n) => !n.isRead).length;
    final serviceCount = allItems.where((n) => n.type == 'Service').length;
    final stockCount = allItems.where((n) => n.type == 'StockOut').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner tóm tắt phong cách biophilic
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062326), Color(0xFF04403B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14062326),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: Color(0xFF34D399),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unreadCount > 0
                            ? 'Bạn có $unreadCount thông báo chưa đọc'
                            : 'Tất cả thông báo đã được đọc',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cập nhật tiến độ lắp đặt, duyệt vật tư & nghiệm thu',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Hàng chip bộ lọc tự xuống dòng, luôn thấy đủ
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(
                label: 'Tất cả (${allItems.length})',
                filter: _NotifFilter.all,
                active: _selectedFilter == _NotifFilter.all,
              ),
              _filterChip(
                label: 'Chưa đọc ($unreadCount)',
                filter: _NotifFilter.unread,
                active: _selectedFilter == _NotifFilter.unread,
                highlightBadge: unreadCount > 0,
              ),
              _filterChip(
                label: 'Dịch vụ & Lắp đặt ($serviceCount)',
                filter: _NotifFilter.service,
                active: _selectedFilter == _NotifFilter.service,
              ),
              _filterChip(
                label: 'Phiếu xuất kho ($stockCount)',
                filter: _NotifFilter.stockOut,
                active: _selectedFilter == _NotifFilter.stockOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required _NotifFilter filter,
    required bool active,
    bool highlightBadge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF062326)
                : (highlightBadge ? const Color(0xFFECFDF5) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? const Color(0xFF062326)
                  : (highlightBadge
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFCBD5E1)),
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x1A062326),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              color: active
                  ? Colors.white
                  : (highlightBadge
                        ? const Color(0xFF047857)
                        : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState() {
    final msg = switch (_selectedFilter) {
      _NotifFilter.unread => 'Tuyệt vời! Bạn không có thông báo chưa đọc nào.',
      _NotifFilter.service =>
        'Không có thông báo về dịch vụ hoặc lắp đặt nào.',
      _NotifFilter.stockOut => 'Không có thông báo về phiếu xuất kho nào.',
      _ => 'Không có thông báo nào phù hợp bộ lọc.',
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.filter_list_off_outlined,
            size: 42,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 15),
            label: const Text('Xem tất cả thông báo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF047857),
              side: const BorderSide(color: Color(0xFF10B981)),
            ),
            onPressed: () => setState(() => _selectedFilter = _NotifFilter.all),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotificationModel n,
    FarmProvider provider,
  ) {
    return Dismissible(
      key: ValueKey('dismiss_${n.notificationId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
            SizedBox(width: 6),
            Text(
              'Xóa',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        provider.deleteNotification(n.notificationId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead ? const Color(0xFFE2E8F0) : const Color(0xFF86EFAC),
            width: n.isRead ? 1 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
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
            onLongPress: () => _showNotificationDetails(context, n, provider),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeIcon(n),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: n.isRead
                                      ? FontWeight.bold
                                      : FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (n.severity == 'Critical') ...[
                              const SizedBox(width: 6),
                              _severityBadge(
                                'Khẩn cấp',
                                const Color(0xFFEF4444),
                                const Color(0xFFFEE2E2),
                              ),
                            ] else if (n.severity == 'Warning') ...[
                              const SizedBox(width: 6),
                              _severityBadge(
                                'Chú ý',
                                const Color(0xFFD97706),
                                const Color(0xFFFEF3C7),
                              ),
                            ],
                          ],
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
                                color: _typeColorSoft(n.type),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notificationTypeLabel(n.type),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: _typeColorDark(n.type),
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
                      margin: const EdgeInsets.only(top: 4, left: 4),
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
      ),
    );
  }

  Widget _buildTypeIcon(AppNotificationModel n) {
    final IconData icon = switch (n.type) {
      'Service' => Icons.handyman_outlined,
      'StockOut' => Icons.inventory_2_outlined,
      'IoT' => Icons.sensors_outlined,
      'Alert' => Icons.warning_amber_rounded,
      'Task' => Icons.assignment_outlined,
      'Contract' => Icons.description_outlined,
      _ => n.isRead
          ? Icons.notifications_none_outlined
          : Icons.notifications_active,
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: n.isRead ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: n.isRead ? const Color(0xFF64748B) : const Color(0xFF047857),
        size: 20,
      ),
    );
  }

  Widget _severityBadge(String label, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
    ),
  );

  Color _typeColorSoft(String type) => switch (type) {
    'Service' => const Color(0xFFCCFBF1),
    'StockOut' => const Color(0xFFFEF3C7),
    'Alert' => const Color(0xFFFEE2E2),
    'IoT' => const Color(0xFFE0E7FF),
    _ => const Color(0xFFF1F5F9),
  };

  Color _typeColorDark(String type) => switch (type) {
    'Service' => const Color(0xFF0F766E),
    'StockOut' => const Color(0xFFB45309),
    'Alert' => const Color(0xFFB91C1C),
    'IoT' => const Color(0xFF4338CA),
    _ => const Color(0xFF475569),
  };

  Future<void> _confirmDeleteAllRead(
    BuildContext context,
    FarmProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xóa thông báo đã đọc',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn xóa vĩnh viễn tất cả thông báo đã đọc khỏi danh sách?',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: Color(0xFF334155),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await provider.deleteAllReadNotifications();
    }
  }

  void _showNotificationDetails(
    BuildContext context,
    AppNotificationModel n,
    FarmProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
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
                _buildTypeIcon(n),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notificationTimeLabel(n.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              n.message,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Xóa',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    provider.deleteNotification(n.notificationId);
                  },
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF062326),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
