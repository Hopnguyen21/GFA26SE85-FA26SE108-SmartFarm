import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/utils/haptics.dart';
import '../actuator_interlock.dart';

/// Hộp xác nhận lệnh rơ-le (LoRa downlink) giống web: thông tin thiết bị, cảnh báo khóa interlock bơm,
/// hẹn giờ tự ngắt 1–30 phút khi BẬT, mức ưu tiên thủ công. Trả về số phút (BẬT) hoặc 0 (TẮT); null nếu hủy.
Future<int?> showActuatorCommandDialog(
  BuildContext context, {
  required ActuatorModel actuator,
  required bool turnOn,
  required Iterable<ActuatorModel> zoneActuators,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _ActuatorCommandDialog(
      actuator: actuator,
      turnOn: turnOn,
      zoneActuators: zoneActuators,
    ),
  );
}

class _ActuatorCommandDialog extends StatefulWidget {
  final ActuatorModel actuator;
  final bool turnOn;
  final Iterable<ActuatorModel> zoneActuators;
  const _ActuatorCommandDialog({
    required this.actuator,
    required this.turnOn,
    required this.zoneActuators,
  });

  @override
  State<_ActuatorCommandDialog> createState() => _ActuatorCommandDialogState();
}

class _ActuatorCommandDialogState extends State<_ActuatorCommandDialog> {
  double _minutes = kFailsafeDefaultMinutes.toDouble();

  @override
  Widget build(BuildContext context) {
    final a = widget.actuator;
    final on = widget.turnOn;
    final interlock = actuatorInterlockError(a, on, widget.zoneActuators);
    return AlertDialog(
      key: const ValueKey('actuator-command-dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Xác nhận lệnh kích hoạt rơ-le (LoRa Downlink)',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    on ? Icons.power_settings_new : Icons.power_off_outlined,
                    color: on
                        ? const Color(0xFF119653)
                        : const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                        Text(
                          'Kênh relay ${a.relayChannel ?? 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (interlock != null)
              Container(
                key: const ValueKey('interlock-warning'),
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vi phạm luật an toàn Interlock: $interlock',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF881337),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (on) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Hẹn giờ tự ngắt an toàn (Failsafe)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ),
                        Text(
                          '${_minutes.round()} phút',
                          key: const ValueKey('failsafe-minutes'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      key: const ValueKey('failsafe-slider'),
                      min: kFailsafeMinMinutes.toDouble(),
                      max: kFailsafeMaxMinutes.toDouble(),
                      divisions: kFailsafeMaxMinutes - kFailsafeMinMinutes,
                      value: _minutes,
                      activeColor: const Color(0xFFD97706),
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                    const Text(
                      'Tối đa 30 phút mỗi lần kích hoạt. Rơ-le tự ngắt cứng ngay cả khi mất kết nối mạng.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF92400E),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Mức ưu tiên: 1 (Thủ công / Manual Override)\nGiao thức downlink: MQTT → LoRa Gateway',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy bỏ'),
        ),
        FilledButton(
          key: const ValueKey('actuator-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: on
                ? const Color(0xFF119653)
                : const Color(0xFFDC2626),
          ),
          onPressed: interlock != null
              ? null
              : () {
                  AppHaptics.selection();
                  Navigator.pop(context, on ? _minutes.round() : 0);
                },
          child: Text(on ? 'Xác nhận BẬT RƠ-LE' : 'Xác nhận TẮT RƠ-LE'),
        ),
      ],
    );
  }
}
