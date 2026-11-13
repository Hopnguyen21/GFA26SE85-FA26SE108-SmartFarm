part of '../farm_provider.dart';

extension FarmProviderAlertsTasks on FarmProvider {
  /// Xác nhận cảnh báo. Chỉ đánh dấu đã xem khi backend xác nhận; trả về false nếu thất bại.
  Future<bool> acknowledgeAlert(String alertId) async {
    final idx = _alerts.indexWhere((a) => a.alertId == alertId);
    if (idx == -1) return false;
    if (!_isApiConnected) return false;
    final ok = await TaskApi.acknowledgeAlert(alertId);
    if (!ok) return false;
    _alerts[idx].isAcknowledged = true;
    _notify();
    return true;
  }

  Future<void> fetchNotifications() async {
    try {
      final apiNotifs = await TaskApi.getNotifications();
      // Gán cả khi rỗng: thông báo đã xóa trên máy chủ không được giữ lại trên máy.
      _notifications
        ..clear()
        ..addAll(apiNotifs);
      _notify();
    } catch (_) {
      // Giữ danh sách hiện có khi không tải được.
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.notificationId == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _notify();
      await TaskApi.markNotificationAsRead(id);
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _notify();
    await TaskApi.markAllNotificationsAsRead();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n.notificationId == id);
    _notify();
    await TaskApi.deleteNotification(id);
  }

  Future<void> deleteAllReadNotifications() async {
    _notifications.removeWhere((n) => n.isRead);
    _notify();
    await TaskApi.deleteAllReadNotifications();
  }

  TaskModel _withZoneName(TaskModel t) {
    final zone = _zones.where((z) => z.zoneId == t.zoneId).firstOrNull;
    return zone == null
        ? t
        : TaskModel(
            taskId: t.taskId,
            title: t.title,
            zoneName: zone.name,
            priority: t.priority,
            dueDate: t.dueDate,
            assignedFarmerName: t.assignedFarmerName,
            assignedFarmerId: t.assignedFarmerId,
            description: t.description,
            isCompleted: t.isCompleted,
            status: t.status,
            zoneId: t.zoneId,
            assignments: t.assignments,
          );
  }

  /// Thao tác thật trên công việc. Trả về thông báo lỗi, hoặc null khi thành công.
  Future<String?> performTaskAction(
    String taskId,
    String action, {
    String? result,
    String? failureReason,
    int? progressPercent,
    String? farmerId,
  }) async {
    try {
      final updated = await TaskApi.updateTaskAction(_selectedFarmId, taskId, {
        'action': action,
        'result': ?result,
        'failureReason': ?failureReason,
        'progressPercent': ?progressPercent,
        'farmerId': ?farmerId,
      });
      final idx = _tasks.indexWhere((t) => t.taskId == taskId);
      if (idx != -1) _tasks[idx] = _withZoneName(updated);
      _notify();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _replaceTask(
    String taskId,
    Future<TaskModel> Function() call,
  ) async {
    try {
      final updated = await call();
      final idx = _tasks.indexWhere((t) => t.taskId == taskId);
      if (idx != -1) _tasks[idx] = _withZoneName(updated);
      _notify();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Giao việc qua API. Trả về thông báo lỗi, hoặc null khi thành công; không tạo công việc cục bộ.
  Future<String?> addTask({
    required String title,
    required String zoneName,
    required String priority,
    required String dueDate,
    String? assignedFarmerId,
    String? assignedFarmerName,
    String? description,
    String? zoneId,
    DateTime? dueAt,
  }) async {
    if (assignedFarmerId == null || zoneId == null)
      return 'Hãy chọn Zone và nhân công.';
    try {
      final created = await TaskApi.createTask(_selectedFarmId, {
        'zoneId': zoneId,
        'title': title,
        'description': description ?? '',
        'dueAtUtc': (dueAt ?? DateTime.now().add(const Duration(days: 1)))
            .toUtc()
            .toIso8601String(),
        'farmerIds': [assignedFarmerId],
      });
      _tasks.insert(0, _withZoneName(created));
      _notify();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
