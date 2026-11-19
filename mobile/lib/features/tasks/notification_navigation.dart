import 'package:flutter/material.dart';

import '../contracts/contracts_depreciation_screen.dart';
import '../../core/utils/paging.dart' show parseTime;
import '../inventory/stock_out_screen.dart';
import '../support/support_requests_screen.dart';
import '../support/technician_maintenance_screen.dart';
import '../zones/zone_detail_screen.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';

/// Màn đích khi chạm vào một thông báo.
enum NotificationDestination {
  none,
  serviceRequest,
  ownerRequests,
  stockOut,
  contracts,
  zoneDetail,
}

/// Chọn màn theo loại thông báo + vai trò (hàm thuần để test).
/// Service: KTV mở chi tiết yêu cầu theo mã; Owner mở danh sách yêu cầu (có hợp đồng/nghiệm thu).
/// StockOut: màn Xuất kho. Contract (hợp đồng sắp/đã hết hạn): Owner mở màn Hợp đồng.
/// Alert (cảnh báo vi khí hậu/môi trường): mở màn chi tiết Zone tương ứng cho cả Owner và Farmer.
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
    case 'Alert':
      return NotificationDestination.zoneDetail;
    default:
      return NotificationDestination.none;
  }
}

/// Tìm Zone phù hợp nhất từ thông báo để chuyển hướng.
ZoneModel? resolveZoneForNotification({
  required AppNotificationModel notif,
  required FarmProvider provider,
}) {
  // 1. Tìm qua referenceId (alertId của AlertModel)
  if (notif.referenceId != null && notif.referenceId!.isNotEmpty) {
    final alert = provider.alerts
        .where(
          (a) => a.alertId.toLowerCase() == notif.referenceId!.toLowerCase(),
        )
        .firstOrNull;
    if (alert != null && alert.zoneId.isNotEmpty) {
      final z = provider.allZones
          .where((x) => x.zoneId.toLowerCase() == alert.zoneId.toLowerCase())
          .firstOrNull;
      if (z != null) return z;
      return ZoneModel(
        zoneId: alert.zoneId,
        farmId: provider.selectedFarmId,
        name: alert.zoneName.isNotEmpty ? alert.zoneName : 'Khu vực cảnh báo',
        currentCrop: '',
        currentStage: '',
        areaM2: 0,
        currentSoilMoisture: 0,
        currentTemp: 0,
        currentHumidity: 0,
        currentLux: 0,
        telemetryIsFresh: false,
      );
    }
  }

  // 2. Tìm theo tên Zone xuất hiện trong tiêu đề hoặc nội dung thông báo
  for (final z in provider.allZones) {
    if (z.name.isNotEmpty &&
        (notif.title.contains(z.name) || notif.message.contains(z.name))) {
      return z;
    }
  }

  // 3. Fallback: Nếu là Alert và danh sách Zone có phần tử
  if (provider.allZones.isNotEmpty && notif.type == 'Alert') {
    return provider.allZones.first;
  }
  return null;
}

/// Tìm Zone phù hợp nhất từ AlertModel để chuyển hướng.
ZoneModel? resolveZoneForAlert({
  required AlertModel alt,
  required FarmProvider provider,
}) {
  // 1. Tìm theo zoneId
  if (alt.zoneId.isNotEmpty) {
    final z = provider.allZones
        .where((x) => x.zoneId.toLowerCase() == alt.zoneId.toLowerCase())
        .firstOrNull;
    if (z != null) return z;
  }

  // 2. Tìm theo zoneName
  if (alt.zoneName.isNotEmpty) {
    final z = provider.allZones
        .where((x) => x.name.toLowerCase() == alt.zoneName.toLowerCase())
        .firstOrNull;
    if (z != null) return z;
  }

  // 3. Tìm theo tên Zone xuất hiện trong title hoặc message
  for (final z in provider.allZones) {
    if (z.name.isNotEmpty &&
        (alt.title.contains(z.name) || alt.message.contains(z.name))) {
      return z;
    }
  }

  // 4. Nếu có zoneId hoặc zoneName nhưng chưa có trong allZones
  if (alt.zoneId.isNotEmpty || alt.zoneName.isNotEmpty) {
    return ZoneModel(
      zoneId: alt.zoneId.isNotEmpty ? alt.zoneId : 'unknown_zone',
      farmId: provider.selectedFarmId,
      name: alt.zoneName.isNotEmpty ? alt.zoneName : 'Khu vực cảnh báo',
      currentCrop: '',
      currentStage: '',
      areaM2: 0,
      currentSoilMoisture: 0,
      currentTemp: 0,
      currentHumidity: 0,
      currentLux: 0,
      telemetryIsFresh: false,
    );
  }

  // 5. Fallback nếu có Zone nào trong Farm
  if (provider.allZones.isNotEmpty) {
    return provider.allZones.first;
  }

  return null;
}

/// Mở màn tương ứng; trả false nếu thông báo không có màn đích.
bool openNotificationTarget(
  BuildContext context, {
  required String type,
  required String? referenceId,
  required String role,
  ZoneModel? zone,
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
    NotificationDestination.zoneDetail =>
      zone != null ? ZoneDetailScreen(zone: zone) : null,
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
