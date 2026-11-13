import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import 'device_config_dialogs.dart';

/// Hỏi một đoạn chữ (lý do, số kênh…); trả về null nếu bấm Hủy. Hộp thoại tự giữ và tự hủy controller.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? body,
  required String label,
  required String confirmLabel,
  bool required = true,
  TextInputType? keyboardType,
  bool danger = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _PromptDialog(
    title: title,
    body: body,
    label: label,
    confirmLabel: confirmLabel,
    required: required,
    keyboardType: keyboardType,
    danger: danger,
  ),
);

class _PromptDialog extends StatefulWidget {
  final String title;
  final String? body;
  final String label;
  final String confirmLabel;
  final bool required;
  final TextInputType? keyboardType;
  final bool danger;
  const _PromptDialog({
    required this.title,
    required this.body,
    required this.label,
    required this.confirmLabel,
    required this.required,
    required this.keyboardType,
    required this.danger,
  });

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (widget.required && text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập ${widget.label.toLowerCase()}.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.body != null) ...[
              Text(
                widget.body!,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              keyboardType: widget.keyboardType,
              maxLength: 1000,
              maxLines: widget.keyboardType == null ? 3 : 1,
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: widget.danger
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Bảng thao tác kỹ thuật cho một node: kiểm tra kết nối, chẩn đoán từ xa, gỡ khỏi Zone, ngừng sử dụng.
/// Backend kiểm tra quyền và trạng thái; app chỉ hiện thao tác hợp lý với trạng thái đã biết.
/// [onChanged] chạy sau khi một thao tác làm đổi dữ liệu (để màn hình tải lại).
Future<void> showDeviceActionsSheet(
  BuildContext context,
  DeviceHealthModel device, {
  required VoidCallback onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _DeviceActions(device: device, onChanged: onChanged),
);

class _DeviceActions extends StatelessWidget {
  final DeviceHealthModel device;
  final VoidCallback onChanged;
  const _DeviceActions({required this.device, required this.onChanged});

  void _toast(BuildContext c, String m) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _guard(
    BuildContext context,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } catch (e) {
      if (context.mounted) _toast(context, friendlyError(e));
    }
  }

  Future<void> _ping(BuildContext context) async {
    final id = device.deviceId!;
    await _guard(context, () async {
      final t = await DeploymentApi.pingDevice(id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            t.succeeded ? 'Kết nối đạt' : 'Kết nối không đạt',
            style: TextStyle(
              color: t.succeeded ? AppColors.primaryDark : AppColors.danger,
            ),
          ),
          content: Text(
            [
              'Thời điểm: ${t.observedAtUtc}',
              if (t.rssi != null) 'RSSI: ${t.rssi!.toStringAsFixed(0)} dBm',
              if (t.snr != null) 'SNR: ${t.snr!.toStringAsFixed(1)} dB',
              if (t.latencyMs != null) 'Độ trễ: ${t.latencyMs} ms',
              if (t.errorCode != null) 'Mã lỗi: ${t.errorCode}',
              if (t.errorMessage != null) t.errorMessage!,
              'Đây là lần kiểm tra gần nhất đã được ghi nhận, không phải phép đo mới.',
            ].join('\n'),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    });
  }

  /// Sửa cấu hình node: đọc cấu hình hiện có từ máy chủ rồi mở hộp thoại theo loại node.
  Future<void> _configure(BuildContext context) async {
    final id = device.deviceId!;
    final sensor = device.type == 'SENSOR_NODE';
    Map<String, dynamic> detail;
    try {
      detail = await DeploymentApi.getDeviceDetail(id);
    } catch (e) {
      if (context.mounted) _toast(context, friendlyError(e));
      return;
    }
    if (!context.mounted) return;
    final current = [
      for (final s
          in (detail[sensor ? 'sensors' : 'actuators'] as List? ?? const []))
        '$s',
    ];
    final saved = sensor
        ? await showSensorConfigDialog(
            context,
            deviceId: id,
            label: device.nodeId,
            current: current,
          )
        : await showActuatorConfigDialog(
            context,
            deviceId: id,
            label: device.nodeId,
            current: current,
          );
    if (!saved || !context.mounted) return;
    _toast(context, 'Đã lưu cấu hình cho ${device.nodeId}.');
    Navigator.pop(context);
    onChanged();
  }

  Future<void> _diagnose(BuildContext context) async {
    final id = device.deviceId!;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Chẩn đoán từ xa'),
        children: [
          for (final e in DeploymentApi.diagnosticActions.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, e.key),
              child: Text(e.value),
            ),
        ],
      ),
    );
    if (action == null || !context.mounted) return;
    double? channel;
    if (action == 'CHANGE_CHANNEL' || action == 'REBOOT_AND_CHANGE_CHANNEL') {
      final text = await promptText(
        context,
        title: 'Kênh tần số mới',
        label: 'Kênh tần số (MHz hoặc số kênh)',
        confirmLabel: 'Gửi lệnh',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      );
      if (text == null || !context.mounted) return;
      channel = double.tryParse(text.replaceAll(',', '.'));
      if (channel == null) {
        _toast(context, 'Kênh tần số không hợp lệ.');
        return;
      }
    }
    if (action == 'FACTORY_RESET') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Khôi phục cài đặt gốc?'),
          content: const Text(
            'Thiết bị sẽ mất cấu hình hiện tại và cần cấu hình lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Khôi phục'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    await _guard(context, () async {
      await DeploymentApi.diagnoseDevice(
        id,
        action: action,
        newFrequencyChannel: channel,
      );
      if (context.mounted) {
        _toast(
          context,
          'Đã xếp lệnh "${DeploymentApi.diagnosticActions[action]}" vào hàng đợi. Chờ thiết bị phản hồi.',
        );
        Navigator.pop(context);
      }
    });
  }

  Future<void> _unassign(BuildContext context) async {
    final reason = await promptText(
      context,
      title: 'Gỡ thiết bị khỏi Zone?',
      body: 'Thiết bị về trạng thái chưa gán. Lý do được lưu vào lịch sử.',
      label: 'Lý do',
      confirmLabel: 'Gỡ khỏi Zone',
      danger: true,
    );
    if (reason == null || !context.mounted) return;
    await _guard(context, () async {
      await DeploymentApi.unassignDevice(
        device.zoneId!,
        device.deviceId!,
        reason: reason,
      );
      if (context.mounted) {
        _toast(context, 'Đã gỡ thiết bị khỏi Zone.');
        Navigator.pop(context);
      }
      onChanged();
    });
  }

  Future<void> _decommission(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ngừng sử dụng thiết bị?'),
        content: const Text(
          'Thiết bị sẽ bị loại khỏi danh sách và không dùng lại được.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ngừng sử dụng'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _guard(context, () async {
      await DeploymentApi.decommissionDevice(device.deviceId!);
      if (context.mounted) {
        _toast(context, 'Đã ngừng sử dụng thiết bị.');
        Navigator.pop(context);
      }
      onChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assigned = device.zoneId != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                device.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.network_check),
              title: const Text('Kiểm tra kết nối gần nhất'),
              subtitle: const Text('Xem kết quả kiểm tra đã ghi nhận'),
              onTap: () => _ping(context),
            ),
            if (device.type == 'SENSOR_NODE' || device.type == 'ACTUATOR_NODE')
              ListTile(
                leading: const Icon(Icons.tune),
                title: Text(
                  device.type == 'SENSOR_NODE'
                      ? 'Cấu hình cảm biến'
                      : 'Cấu hình cơ cấu chấp hành',
                ),
                subtitle: const Text('Sửa cấu hình của node này'),
                onTap: () => _configure(context),
              ),
            ListTile(
              leading: const Icon(Icons.build_circle_outlined),
              title: const Text('Chẩn đoán từ xa'),
              subtitle: const Text('Khởi động lại, đổi kênh, hiệu chuẩn…'),
              onTap: () => _diagnose(context),
            ),
            if (assigned)
              ListTile(
                leading: const Icon(Icons.link_off, color: AppColors.danger),
                title: const Text('Gỡ khỏi Zone'),
                onTap: () => _unassign(context),
              )
            else
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text('Ngừng sử dụng thiết bị'),
                subtitle: const Text('Chỉ áp dụng cho thiết bị chưa gán Zone'),
                onTap: () => _decommission(context),
              ),
          ],
        ),
      ),
    );
  }
}
