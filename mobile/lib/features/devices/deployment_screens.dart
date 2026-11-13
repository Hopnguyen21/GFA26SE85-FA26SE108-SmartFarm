import 'package:flutter/material.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_tile.dart';
import '../zones/honeycomb_estimate.dart';
import 'deployment_board_logic.dart';
import 'widgets/cancel_deployment_dialog.dart';
import 'widgets/survey_dialog.dart';
import 'widgets/deployment_progress_bar.dart';
import '../zones/widgets/zone_honeycomb_estimate_card.dart'
    show measurementLabel;
part 'parts/deployment_screens_owner_list.dart';
part 'parts/deployment_screens_technician_list.dart';
part 'parts/deployment_screens_detail.dart';
part 'parts/deployment_screens_detail_actions.dart';
part 'parts/deployment_screens_detail_hardware.dart';

// Luồng triển khai thiết bị IoT cho Zone (IOT-V1). Mọi trạng thái và lịch sử lấy từ backend;
// app không tự suy ra thiết bị online hay kết nối thành công.

Color _statusColor(String s) => deploymentStatusColor(s);

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xác nhận'),
          ),
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
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: _statusColor(status),
    ),
  ),
);

PreferredSizeWidget _appBar(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: const Color(0xFF062326),
  foregroundColor: Colors.white,
  title: Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
  actions: actions,
);
