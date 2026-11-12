part of '../farm_provider.dart';

extension FarmProviderControl on FarmProvider {
  /// Bật/tắt thiết bị chấp hành. Trả về null khi backend xác nhận, hoặc thông báo lỗi để hiển thị.
  /// Không giả lập: chưa kết nối máy chủ thì không đổi trạng thái; lệnh bị từ chối thì khôi phục trạng thái cũ.
  Future<String?> toggleActuator(
    String actuatorId, {
    int? durationMinutes,
  }) async {
    final actIndex = _actuators.indexWhere((a) => a.actuatorId == actuatorId);
    if (actIndex == -1) return 'Không tìm thấy thiết bị chấp hành.';
    if (!_isApiConnected) {
      return 'Chưa kết nối máy chủ, không thể gửi lệnh điều khiển.';
    }
    final act = _actuators[actIndex];
    final prevRunning = act.isRunning;
    final prevRemaining = act.remainingMinutes;

    final targetRunning = !prevRunning;
    final targetRemaining = targetRunning ? (durationMinutes ?? 15) : 0;

    // Cập nhật tạm để công tắc phản hồi ngay; sẽ khôi phục nếu backend từ chối.
    act.isRunning = targetRunning;
    act.remainingMinutes = targetRemaining;
    _notify();

    final action = targetRunning ? 'TurnOn' : 'TurnOff';
    final duration = targetRunning ? (targetRemaining * 60) : 1;
    try {
      await AutomationApi.sendActuatorCommand(
        zoneId: act.zoneId,
        actuatorId: act.actuatorId,
        action: action,
        durationSeconds: duration,
      );
      await refreshCurrentZoneActuators();
      return null;
    } catch (e) {
      act.isRunning = prevRunning;
      act.remainingMinutes = prevRemaining;
      _notify();
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Dừng khẩn cấp mọi rơ-le (zoneId = null) hoặc chỉ trong một Zone.
  /// Không giả lập: chỉ báo thành công khi backend xác nhận, sau đó tải lại trạng thái thật từ server.
  Future<EmergencyStopResult> emergencyStop({String? zoneId}) async {
    if (!_isApiConnected) {
      throw Exception(
        'Chưa kết nối máy chủ, không thể phát lệnh dừng khẩn cấp.',
      );
    }
    if (_isEmergencyStopping) {
      throw Exception('Lệnh dừng khẩn cấp đang được xử lý.');
    }
    _isEmergencyStopping = true;
    _notify();
    try {
      final result = await AutomationApi.emergencyStop(zoneId: zoneId);
      await _refreshActuatorsForZones(
        zoneId != null ? [zoneId] : _zones.map((z) => z.zoneId).toList(),
      );
      return result;
    } finally {
      _isEmergencyStopping = false;
      _notify();
    }
  }

  Future<void> _refreshActuatorsForZones(List<String> zoneIds) async {
    for (final id in zoneIds) {
      try {
        final fresh = await FarmApi.fetchZoneActuators(id);
        final idLower = id.toLowerCase();
        _actuators.removeWhere((a) => a.zoneId.toLowerCase() == idLower);
        _actuators.addAll(fresh);
        _actuatorErrors.remove(idLower);
      } catch (e) {
        // Giữ trạng thái cũ của Zone này nếu không tải lại được, nhưng ghi nhận lỗi.
        _actuatorErrors[id.toLowerCase()] = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      }
    }
    _notify();
  }
}
