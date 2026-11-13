import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/farm_provider.dart';

/// Nút Dừng khẩn cấp (E-Stop, BR-CANCEL-01): tắt toàn bộ rơ-le bơm/quạt/van/đèn.
/// [zoneId] = null → toàn bộ trang trại trong tenant; có giá trị → chỉ Zone đó.
/// Tự ẩn với vai trò không được phép (Technician).
class EmergencyStopButton extends StatelessWidget {
  final String? zoneId;
  final String? zoneName;

  const EmergencyStopButton({super.key, this.zoneId, this.zoneName});

  static const _red = Color(0xFFDC2626);

  String get _scopeLabel => zoneId == null
      ? 'TẤT CẢ thiết bị chấp hành bạn có quyền điều khiển'
      : 'tất cả thiết bị chấp hành trong Zone ${zoneName ?? ''}'.trim();

  Future<void> _confirmAndStop(
    BuildContext context,
    FarmProvider provider,
  ) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: _red, size: 40),
        title: const Text(
          'Dừng khẩn cấp?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Lệnh sẽ TẮT NGAY $_scopeLabel, hủy các lệnh đang chờ và được ghi vào nhật ký audit.\n\n'
          'Lịch tưới và luật tự động có thể bật lại thiết bị ở chu kỳ sau.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.power_settings_new, size: 18),
            label: const Text('Dừng ngay'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await provider.emergencyStop(zoneId: zoneId);
      messenger.showSnackBar(
        SnackBar(content: Text('🛑 ${result.message}'), backgroundColor: _red),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Dừng khẩn cấp thất bại: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: const Color(0xFF92400E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    // Backend: dừng khẩn cấp cho FarmOwner/Farmer; Farmer chỉ khi được cấp quyền điều khiển CHÍNH Zone này.
    if (!provider.canEmergencyStop ||
        (zoneId != null && !provider.canControlZone(zoneId!)))
      return const SizedBox.shrink();
    final busy = provider.isEmergencyStopping;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: busy ? null : () => _confirmAndStop(context, provider),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.power_settings_new, size: 20),
        label: Text(
          zoneId == null
              ? 'DỪNG KHẨN CẤP TẤT CẢ (E-STOP)'
              : 'DỪNG KHẨN CẤP ZONE NÀY',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
