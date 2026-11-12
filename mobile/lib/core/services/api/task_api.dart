part of '../api_service.dart';

/// Cảnh báo, công việc, kho vật tư và thông báo.
abstract final class TaskApi {
  // ─── 8. Alerts ───────────────────────────────────────────────────────
  static Future<List<AlertModel>> getAlerts(String farmId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/alerts',
      );
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((item) => AlertModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── 9. Tasks ────────────────────────────────────────────────────────
  static Future<List<TaskModel>> getTasks(String farmId) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/tasks',
      );
      if (resp != null && resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((item) => TaskModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Giao việc cho các Farmer đã có quyền Zone; lỗi nghiệp vụ được báo nguyên văn từ backend.
  static Future<TaskModel> createTask(
    String farmId,
    Map<String, dynamic> data,
  ) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/tasks',
      data,
    );
    return TaskModel.fromJson(
      ApiService._decodeOrThrow(resp) as Map<String, dynamic>,
    );
  }

  /// Một thao tác trên công việc: Accept, Decline, Start, UpdateProgress, Complete, Fail, Approve.
  static Future<TaskModel> updateTaskAction(
    String farmId,
    String taskId,
    Map<String, dynamic> body,
  ) async {
    final resp = await ApiService._putWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/tasks/$taskId',
      body,
    );
    return TaskModel.fromJson(
      ApiService._decodeOrThrow(resp) as Map<String, dynamic>,
    );
  }

  // ─── Kho vật tư ──────────────────────────
  static Future<List<MaterialInventoryModel>> getInventory(
    String farmId,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/inventory',
      ),
    );
    return [
      for (final m in ApiService._asMapList(data))
        MaterialInventoryModel.fromJson(m),
    ];
  }

  static Future<void> createInventoryItem(
    String farmId,
    Map<String, dynamic> body,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/inventory',
        body,
      ),
    );
  }

  static Future<void> receiveInventory(
    String farmId,
    String itemId,
    double quantity,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/inventory/$itemId/receipts',
        {'quantity': quantity},
      ),
    );
  }

  static Future<void> issueInventory(
    String farmId,
    String itemId,
    double quantity,
    String zoneId,
  ) async {
    ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/inventory/issues',
        {'inventoryItemId': itemId, 'quantity': quantity, 'zoneId': zoneId},
      ),
    );
  }

  /// POST /farms/{f}/tasks/{t}/assignees (Owner): giao thêm Farmer cho task.
  static Future<TaskModel> addTaskAssignees(
    String farmId,
    String taskId,
    List<String> farmerIds, {
    DateTime? newDueAtUtc,
  }) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._postWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/tasks/$taskId/assignees',
        {
          'farmerIds': farmerIds,
          if (newDueAtUtc != null)
            'newDueAtUtc': newDueAtUtc.toUtc().toIso8601String(),
        },
      ),
    );
    return TaskModel.fromJson(data as Map<String, dynamic>);
  }

  /// DELETE /farms/{f}/tasks/{t}/assignees/{farmerId} (Owner): gỡ một Farmer khỏi task.
  static Future<TaskModel> removeTaskAssignee(
    String farmId,
    String taskId,
    String farmerId,
  ) async {
    final data = ApiService._decodeOrThrow(
      await ApiService._deleteWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/tasks/$taskId/assignees/$farmerId',
      ),
    );
    return TaskModel.fromJson(data as Map<String, dynamic>);
  }

  // ─── 11. Acknowledge Alert ─────────────────────────────────────────────
  static Future<bool> acknowledgeAlert(String alertId, {String? notes}) async {
    try {
      final resp = await ApiService._putWithAuth(
        '${ApiService.baseUrl}/api/v1/alerts/$alertId/acknowledge',
        {'notes': notes ?? 'Đã xác nhận từ ứng dụng di động'},
      );
      return resp != null && resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── 16. Notifications (Hệ thống Thông Báo) ────────────────────────────
  /// Lấy danh sách thông báo của tài khoản hiện tại
  static Future<List<AppNotificationModel>> getNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      String query = 'page=$page&pageSize=$pageSize';
      if (isRead != null) query += '&isRead=$isRead';
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/notifications?$query',
      );
      if (resp != null && resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = (decoded is Map && decoded.containsKey('value'))
            ? decoded['value']
            : decoded;
        if (list is List) {
          return list
              .map(
                (item) =>
                    AppNotificationModel.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Lấy số lượng thông báo chưa đọc
  static Future<int> getUnreadNotificationCount() async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/notifications/unread-count',
      );
      if (resp != null && resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map && decoded.containsKey('unreadCount')) {
          return (decoded['unreadCount'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Đánh dấu một thông báo đã đọc
  static Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final resp = await ApiService._client
          .put(
            Uri.parse(
              '${ApiService.baseUrl}/api/v1/notifications/$notificationId/read',
            ),
            headers: ApiService._headers,
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Đánh dấu tất cả thông báo đã đọc
  static Future<bool> markAllNotificationsAsRead() async {
    try {
      final resp = await ApiService._client
          .put(
            Uri.parse('${ApiService.baseUrl}/api/v1/notifications/read-all'),
            headers: ApiService._headers,
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Xóa một thông báo
  static Future<bool> deleteNotification(String notificationId) async {
    try {
      final resp = await ApiService._client
          .delete(
            Uri.parse(
              '${ApiService.baseUrl}/api/v1/notifications/$notificationId',
            ),
            headers: ApiService._headers,
          )
          .timeout(const Duration(seconds: 6));
      return resp.statusCode == 200 || resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Xóa tất cả thông báo đã đọc
  static Future<int> deleteAllReadNotifications() async {
    try {
      final resp = await ApiService._client
          .delete(
            Uri.parse('${ApiService.baseUrl}/api/v1/notifications/read-all'),
            headers: ApiService._headers,
          )
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['deletedCount'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
