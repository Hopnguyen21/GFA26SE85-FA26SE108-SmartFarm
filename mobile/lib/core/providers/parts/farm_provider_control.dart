part of '../farm_provider.dart';

extension FarmProviderControl on FarmProvider {
  /// Bật/tắt thiết bị chấp hành. Trả về null khi backend nhận lệnh, hoặc thông báo lỗi để hiển thị.
  /// Giống web: KHÔNG tự đổi sang "đang chạy" trước khi có phản hồi; chỉ báo chạy khi gateway ACK (HTTP 202 chỉ nghĩa là
  /// đã lưu/đã gửi), phần còn lại do bộ hỏi trạng thái thật (2 giây/lần) cập nhật. `lastActuatorNotice` giữ câu thông báo.
  Future<String?> toggleActuator(
    String actuatorId, {
    int? durationMinutes,
    bool? turnOn,
    bool overrideActiveSchedules = false,
  }) async {
    lastActuatorNotice = null;
    final actIndex = _actuators.indexWhere((a) => a.actuatorId == actuatorId);
    if (actIndex == -1) return 'Không tìm thấy thiết bị chấp hành.';
    if (!_isApiConnected) {
      return 'Chưa kết nối máy chủ, không thể gửi lệnh điều khiển.';
    }
    final act = _actuators[actIndex];
    final targetRunning = turnOn ?? !act.isRunning;
    final minutes = (durationMinutes ?? 15).clamp(1, 30);
    final action = targetRunning ? 'TurnOn' : 'TurnOff';
    try {
      final result = await AutomationApi.sendActuatorCommand(
        zoneId: act.zoneId,
        actuatorId: act.actuatorId,
        action: action,
        durationSeconds: targetRunning ? minutes * 60 : 1,
        overrideActiveSchedules: overrideActiveSchedules,
      );
      if (result.failed) {
        return result.errorMessage?.isNotEmpty == true
            ? result.errorMessage
            : 'Gateway không thực hiện được lệnh (${result.status}).';
      }
      final verb = targetRunning ? 'BẬT' : 'TẮT';
      if (result.acknowledged) {
        act.isRunning = targetRunning;
        act.remainingMinutes = targetRunning ? minutes : 0;
        lastActuatorNotice =
            'Đã phát lệnh $verb thiết bị [${act.name}] qua LoRa Gateway và được xác nhận.';
        _notify();
      } else {
        act.awaitingAck = true;
        lastActuatorNotice =
            'Đã gửi lệnh $verb thiết bị [${act.name}], đang chờ gateway xác nhận.';
        _notify();
      }
      _watchActuator(act, targetRunning);
      return null;
    } catch (e) {
      return _friendlyCommandError(userFacingError(e));
    }
  }

  /// Việt hóa các lý do từ chối phổ biến của backend (tiếng Anh) để người dùng biết cần làm gì.
  String _friendlyCommandError(String raw) {
    final low = raw.toLowerCase();
    if (low.contains('automated command is active')) {
      return 'Đang có lệnh tự động (lịch/luật) chạy trên thiết bị này. Hãy chờ lệnh đó kết thúc hoặc tắt nó rồi thử lại.';
    }
    if (low.contains('manual command is already active')) {
      return 'Đang có một lệnh thủ công chạy trong Zone này. Hãy tắt lệnh đó trước.';
    }
    return raw;
  }

  /// Hỏi lại trạng thái thật của rơ-le mỗi 2 giây (tối đa ~30 giây) tới khi khớp với lệnh vừa gửi.
  void _watchActuator(ActuatorModel act, bool expectRunning) {
    _actuatorWatchers[act.actuatorId]?.cancel();
    var ticks = 0;
    _actuatorWatchers[act.actuatorId] = Timer.periodic(
      const Duration(seconds: 2),
      (t) async {
        ticks++;
        if (_isDisposed || ticks > 15) {
          t.cancel();
          _actuatorWatchers.remove(act.actuatorId);
          return;
        }
        try {
          final live = await AutomationApi.getActuatorStatus(
            act.zoneId,
            act.actuatorId,
          );
          if (_isDisposed || live == null) return;
          if (live.state == 'PENDINGFEEDBACK' && !act.awaitingAck) {
            act.awaitingAck = true;
            _notify();
          }
          if (live.isOn || live.isOff) {
            act.awaitingAck = false;
            final changed =
                act.isRunning != live.isOn ||
                (live.isOn &&
                    act.remainingMinutes !=
                        (live.remainingSeconds / 60).ceil());
            act.isRunning = live.isOn;
            act.remainingMinutes = live.isOn
                ? (live.remainingSeconds / 60).ceil()
                : 0;
            if (changed) _notify();
            if (live.isOn == expectRunning) {
              t.cancel();
              _actuatorWatchers.remove(act.actuatorId);
            }
          }
        } catch (_) {}
      },
    );
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
