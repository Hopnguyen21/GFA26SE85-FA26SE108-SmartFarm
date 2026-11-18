import 'package:flutter/material.dart';

import '../contracts/contracts_depreciation_screen.dart';
import '../../core/utils/paging.dart' show parseTime;
import '../inventory/stock_out_screen.dart';
import '../support/support_requests_screen.dart';
import '../support/technician_maintenance_screen.dart';

/// Màn đích khi chạm vào một thông báo.
enum NotificationDestination {
  none,
  serviceRequest,
  ownerRequests,
  stockOut,
  contracts,
}

/// Chọn màn theo loại thông báo + vai trò (hàm thuần để test).
/// Service: KTV mở chi tiết yêu cầu theo mã; Owner mở danh sách yêu cầu (có hợp đồng/nghiệm thu).
/// StockOut: màn Xuất kho. Contract (hợp đồng sắp/đã hết hạn): Owner mở màn Hợp đồng. Loại khác (cảnh báo, IoT...) chỉ đánh dấu đã đọc như trước.
NotificationDestination notificationDestination({
  required String type,
  required String? referenceId,
  required String role,
}) {
  switch (type) {
    case 'Service':
      if (role == 'TECHNICIAN') {
        return referenceId == null || referenceId.isEmpty
            ? NotificationDestination.none
            : NotificationDestination.serviceRequest;
      }
      return role == 'OWNER'
          ? NotificationDestination.ownerRequests
          : NotificationDestination.none;
    case 'StockOut':
      return role == 'TECHNICIAN'
          ? NotificationDestination.stockOut
          : NotificationDestination.none;
    case 'Contract':
      return role == 'OWNER'
          ? NotificationDestination.contracts
          : NotificationDestination.none;
    default:
      return NotificationDestination.none;
  }
}

/// Mở màn tương ứng; trả false nếu thông báo không có màn đích.
bool openNotificationTarget(
  BuildContext context, {
  required String type,
  required String? referenceId,
  required String role,
}) {
  final dest = notificationDestination(
    type: type,
    referenceId: referenceId,
    role: role,
  );
  final Widget? screen = switch (dest) {
    NotificationDestination.serviceRequest => ServiceRequestDetailScreen(
      requestId: referenceId!,
    ),
    NotificationDestination.ownerRequests => const SupportRequestsScreen(),
    NotificationDestination.stockOut => const StockOutScreen(),
    NotificationDestination.contracts => const ContractsDepreciationScreen(),
    NotificationDestination.none => null,
  };
  if (screen == null) return false;
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  return true;
}

/// Thời điểm thông báo cho người dùng: "Vừa xong", "N phút trước", "N giờ trước", từ 24 giờ trở đi là "dd/MM/yyyy HH:mm" (giờ máy).
/// Chuỗi không đọc được (ví dụ "Vừa xong" mặc định khi thiếu dữ liệu) giữ nguyên.
String notificationTimeLabel(String raw, {DateTime? now}) {
  final t = parseTime(raw)?.toLocal();
  if (t == null) return raw;
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'Vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

/// Nhãn loại thông báo hiển thị cho người dùng.
String notificationTypeLabel(String type) => switch (type) {
  'Service' => 'Lắp đặt',
  'StockOut' => 'Xuất kho',
  'Contract' => 'Hợp đồng',
  'Alert' => 'Cảnh báo',
  'Task' => 'Công việc',
  'Inventory' => 'Kho',
  'Advice' => 'Tư vấn',
  _ => type,
};
