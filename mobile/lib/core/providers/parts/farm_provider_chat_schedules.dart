part of '../farm_provider.dart';

extension FarmProviderChatSchedules on FarmProvider {
  /// Đặt lại toàn bộ danh sách tin nhắn (khôi phục từ API)
  void setChatMessages(List<ChatMessageModel> msgs) {
    _chatMessages.clear();
    _chatMessages.addAll(msgs);
    _notify();
  }

  /// Thêm tin nhắn vào chat (dùng bởi AiAssistantScreen sau khi gọi API thực)
  void addChatMessage(ChatMessageModel msg) {
    _chatMessages.add(msg);
    _notify();
  }

  void refreshChatState() {
    _notify();
  }

  Future<void> fetchSchedules({String? zoneId, String? farmId}) async {
    _schedulesLoading = true;
    _notify();
    try {
      // Lịch tưới lấy theo từng Zone (backend không có API theo Farm); không chỉ định Zone thì gộp các Zone của Farm.
      final targetFarm = farmId ?? _selectedFarmId;
      final zoneIds = zoneId != null
          ? [zoneId]
          : _zones
                .where((z) => z.farmId == targetFarm)
                .map((z) => z.zoneId)
                .toList();
      final lists = await Future.wait(
        zoneIds.map((id) => AutomationApi.getSchedules(zoneId: id)),
      );
      final list = lists.expand((x) => x).toList();
      _schedules = list; // gán cả khi rỗng để phản ánh việc đã xóa hết lịch
      BusinessParametersStore.refresh(); // lấy ngưỡng mưa/tỷ lệ cọc Admin vừa đổi
    } catch (_) {
      // Giữ danh sách hiện có khi không tải được.
    }
    _schedulesLoading = false;
    _notify();
  }

  Future<bool> toggleScheduleEnabled(String scheduleId, bool enable) async {
    final idx = _schedules.indexWhere((s) => s.scheduleId == scheduleId);
    final sch = idx != -1 ? _schedules[idx] : null;
    final targetZoneId = sch?.zoneId.isNotEmpty == true
        ? sch!.zoneId
        : currentZone.zoneId;
    final ok = await AutomationApi.toggleSchedule(
      scheduleId,
      enable,
      zoneId: targetZoneId,
      name: sch?.name,
      cronExpression: sch?.cronExpression,
      durationSeconds: sch != null && sch.durationSeconds > 0
          ? sch.durationSeconds
          : 900,
      enableRainDelay: sch?.enableRainDelay ?? true,
      rainThresholdPercent:
          sch?.rainThresholdPercent ??
          BusinessParametersStore.current.rainGuardThresholdPercent,
    );
    if (ok) {
      if (idx != -1) {
        final s = _schedules[idx];
        s.isActive = enable;
        _notify();
      }
    }
    return ok;
  }
}
