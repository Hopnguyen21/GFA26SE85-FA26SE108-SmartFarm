import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/state_views.dart';

/// Loại cảm biến backend nhận: (mã, đơn vị, nhãn).
const sensorPresets = <(String, String, String)>[
  ('SoilMoisture', '%', 'Độ ẩm đất'),
  ('Temperature', '°C', 'Nhiệt độ'),
  ('AirHumidity', '%', 'Độ ẩm không khí'),
  ('LightIntensity', 'lux', 'Ánh sáng'),
  ('Ph', 'pH', 'pH'),
  ('Ec', 'mS/cm', 'EC'),
];

/// Loại cơ cấu chấp hành hệ thống đang dùng: (mã, nhãn).
const actuatorPresets = <(String, String)>[
  ('Pump', 'Bơm'),
  ('Valve', 'Van điện từ'),
  ('Fan', 'Quạt'),
  ('GROW_LIGHT', 'Đèn quang hợp'),
];

/// Hộp thoại cấu hình cảm biến của một node (PUT /devices/{id}/sensors, thay toàn bộ danh sách cảm biến).
/// [current] là các loại cảm biến đang cấu hình (để chọn sẵn); chu kỳ lấy mẫu máy chủ không trả về nên mặc định 60 giây.
/// Trả true nếu đã lưu thành công.
Future<bool> showSensorConfigDialog(
  BuildContext context, {
  required String deviceId,
  required String label,
  List<String> current = const [],
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _SensorDialog(
      deviceId: deviceId,
      label: label,
      current: [for (final c in current) c.toLowerCase()],
    ),
  );
  return saved == true;
}

class _SensorDialog extends StatefulWidget {
  final String deviceId;
  final String label;
  final List<String> current;
  const _SensorDialog({
    required this.deviceId,
    required this.label,
    required this.current,
  });

  @override
  State<_SensorDialog> createState() => _SensorDialogState();
}

class _SensorDialogState extends State<_SensorDialog> {
  late final Set<String> _chosen = {
    for (final (code, _, _) in sensorPresets)
      if (widget.current.contains(code.toLowerCase())) code,
  };
  final _interval = TextEditingController(text: '60');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final interval = int.tryParse(_interval.text.trim());
    if (_chosen.isEmpty ||
        interval == null ||
        interval < 10 ||
        interval > 3600) {
      setState(
        () => _error = 'Chọn ít nhất một cảm biến; chu kỳ từ 10 đến 3600 giây.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await DeploymentApi.configureDeviceSensors(widget.deviceId, [
        for (final (code, unit, _) in sensorPresets)
          if (_chosen.contains(code))
            {'sensorType': code, 'unit': unit, 'samplingIntervalSec': interval},
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Cảm biến · ${widget.label}',
        style: const TextStyle(fontSize: 15),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lưu sẽ thay toàn bộ danh sách cảm biến của node này.',
              style: TextStyle(fontSize: 12),
            ),
            for (final (code, unit, name) in sensorPresets)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _chosen.contains(code),
                onChanged: _saving
                    ? null
                    : (v) => setState(
                        () => v == true
                            ? _chosen.add(code)
                            : _chosen.remove(code),
                      ),
                title: Text('$name ($unit)'),
              ),
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Chu kỳ lấy mẫu (giây, 10–3600)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

/// Hộp thoại cấu hình cơ cấu chấp hành của node điều khiển (PUT /devices/{id}/actuators, thay toàn bộ danh sách).
/// Loại hiện có được tạo sẵn thành dòng nhưng kênh relay và thời gian chạy tối đa phải do kỹ thuật viên nhập lại,
/// vì máy chủ không trả các giá trị đó và không được đoán (ghi sai kênh có thể đóng/mở nhầm van, bơm).
/// Trả true nếu đã lưu thành công.
Future<bool> showActuatorConfigDialog(
  BuildContext context, {
  required String deviceId,
  required String label,
  List<String> current = const [],
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _ActuatorDialog(deviceId: deviceId, label: label, current: current),
  );
  return saved == true;
}

class _ActuatorRow {
  String type;
  final channel = TextEditingController();
  final minutes = TextEditingController();
  final power = TextEditingController();
  final flow = TextEditingController();
  _ActuatorRow(this.type);

  void dispose() {
    for (final c in [channel, minutes, power, flow]) {
      c.dispose();
    }
  }
}

class _ActuatorDialog extends StatefulWidget {
  final String deviceId;
  final String label;
  final List<String> current;
  const _ActuatorDialog({
    required this.deviceId,
    required this.label,
    required this.current,
  });

  @override
  State<_ActuatorDialog> createState() => _ActuatorDialogState();
}

class _ActuatorDialogState extends State<_ActuatorDialog> {
  late final List<_ActuatorRow> _rows;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    String normalize(String t) {
      for (final (code, _) in actuatorPresets) {
        if (code.toLowerCase() == t.toLowerCase()) return code;
      }
      if (t.toLowerCase().contains('pump')) return 'Pump';
      return actuatorPresets.first.$1;
    }

    _rows = [for (final t in widget.current) _ActuatorRow(normalize(t))];
    if (_rows.isEmpty) _rows.add(_ActuatorRow(actuatorPresets.first.$1));
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final out = <Map<String, dynamic>>[];
    final used = <int>{};
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final ch = int.tryParse(r.channel.text.trim());
      final min = int.tryParse(r.minutes.text.trim());
      final power = r.power.text.trim().isEmpty
          ? null
          : double.tryParse(r.power.text.trim().replaceAll(',', '.'));
      final flow = r.flow.text.trim().isEmpty
          ? null
          : double.tryParse(r.flow.text.trim().replaceAll(',', '.'));
      String? problem;
      if (ch == null || ch < 1 || ch > 8) {
        problem = 'kênh relay phải từ 1 đến 8';
      } else if (!used.add(ch)) {
        problem = 'kênh relay $ch bị trùng';
      } else if (min == null || min < 1 || min > 30) {
        problem = 'thời gian chạy tối đa phải từ 1 đến 30 phút';
      } else if (r.power.text.trim().isNotEmpty &&
          (power == null || power <= 0)) {
        problem = 'công suất phải lớn hơn 0';
      } else if (r.flow.text.trim().isNotEmpty && (flow == null || flow <= 0)) {
        problem = 'lưu lượng phải lớn hơn 0';
      }
      if (problem != null) {
        setState(() => _error = 'Cơ cấu ${i + 1}: $problem.');
        return;
      }
      out.add({
        'actuatorType': r.type,
        'relayChannel': ch,
        'maxDurationMinutes': min,
        'ratedPowerWatt': ?power,
        'flowRateLitersPerMinute': ?flow,
      });
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await DeploymentApi.configureDeviceActuators(widget.deviceId, out);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  Widget _numField(TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: TextField(
      controller: c,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Cơ cấu chấp hành · ${widget.label}',
        style: const TextStyle(fontSize: 15),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lưu sẽ thay toàn bộ cơ cấu của node. Nhập lại kênh relay và thời gian chạy tối đa cho từng cơ cấu.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              for (var i = 0; i < _rows.length; i++)
                Card(
                  key: ObjectKey(_rows[i]),
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cơ cấu ${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa cơ cấu',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: _saving || _rows.length == 1
                                  ? null
                                  : () => setState(() {
                                      _rows.removeAt(i).dispose();
                                    }),
                            ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: _rows[i].type,
                          decoration: const InputDecoration(
                            labelText: 'Loại',
                            isDense: true,
                          ),
                          items: [
                            for (final (code, name) in actuatorPresets)
                              DropdownMenuItem(value: code, child: Text(name)),
                          ],
                          onChanged: _saving
                              ? null
                              : (v) => setState(
                                  () => _rows[i].type = v ?? _rows[i].type,
                                ),
                        ),
                        _numField(_rows[i].channel, 'Kênh relay (1–8)'),
                        _numField(_rows[i].minutes, 'Chạy tối đa (phút, 1–30)'),
                        _numField(_rows[i].power, 'Công suất (W, tùy chọn)'),
                        _numField(
                          _rows[i].flow,
                          'Lưu lượng (L/phút, tùy chọn)',
                        ),
                      ],
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(
                        () => _rows.add(_ActuatorRow(actuatorPresets.first.$1)),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Thêm cơ cấu'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
