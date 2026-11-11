import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
part 'parts/deployment_screens_planning.dart';
part 'parts/deployment_screens_technician_list.dart';
part 'parts/deployment_screens_detail.dart';
part 'parts/deployment_screens_detail_actions.dart';
part 'parts/deployment_screens_detail_hardware.dart';

// Luồng triển khai thiết bị IoT cho Zone (IOT-V1). Mọi trạng thái và lịch sử lấy từ backend;
// app không tự suy ra thiết bị online hay kết nối thành công.

Color _statusColor(String s) => switch (s) {
  'Completed' => const Color(0xFF059669),
  'MaintenanceRequired' => const Color(0xFFDC2626),
  'Draft' => const Color(0xFF64748B),
  _ => const Color(0xFF0284C7),
};

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xác nhận')),
        ],
      ),
    ) ??
    false;

Widget _statusChip(String status) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: _statusColor(status).withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    deploymentStatusLabels[status] ?? status,
    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status)),
  ),
);

PreferredSizeWidget _appBar(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: const Color(0xFF062326),
  foregroundColor: Colors.white,
  title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  actions: actions,
);
