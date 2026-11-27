import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/tasks/notification_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Service: KTV mở chi tiết yêu cầu, Owner mở danh sách yêu cầu', () {
    expect(
      notificationDestination(
        type: 'Service',
        referenceId: 'sr1',
        role: 'TECHNICIAN',
      ),
      NotificationDestination.serviceRequest,
    );
    expect(
      notificationDestination(
        type: 'Service',
        referenceId: '',
        role: 'TECHNICIAN',
      ),
      NotificationDestination.none,
    );
    expect(
      notificationDestination(
        type: 'Service',
        referenceId: 'sr1',
        role: 'OWNER',
      ),
      NotificationDestination.ownerRequests,
    );
    expect(
      notificationDestination(
        type: 'Service',
        referenceId: 'sr1',
        role: 'FARMER',
      ),
      NotificationDestination.none,
    );
  });

  test(
    'Contract (sắp hết hạn): Owner mở màn Hợp đồng, vai trò khác chỉ đánh dấu đã đọc',
    () {
      expect(
        notificationDestination(
          type: 'Contract',
          referenceId: 'c',
          role: 'OWNER',
        ),
        NotificationDestination.contracts,
      );
      expect(
        notificationDestination(
          type: 'Contract',
          referenceId: 'c',
          role: 'FARMER',
        ),
        NotificationDestination.none,
      );
      expect(notificationTypeLabel('Contract'), 'Hợp đồng');
    },
  );

  test(
    'StockOut mở màn xuất kho cho KTV; Alert mở ZoneDetail; loại khác chỉ đánh dấu đã đọc',
    () {
      expect(
        notificationDestination(
          type: 'StockOut',
          referenceId: 'v1',
          role: 'TECHNICIAN',
        ),
        NotificationDestination.stockOut,
      );
      expect(
        notificationDestination(
          type: 'Alert',
          referenceId: 'a1',
          role: 'OWNER',
        ),
        NotificationDestination.zoneDetail,
      );
      expect(
        notificationDestination(
          type: 'Alert',
          referenceId: 'a1',
          role: 'FARMER',
        ),
        NotificationDestination.zoneDetail,
      );
      expect(notificationTypeLabel('Service'), 'Lắp đặt');
      expect(notificationTypeLabel('IoT'), 'IoT');
    },
  );

  test(
    'resolveZoneForAlert & resolveZoneForNotification: tìm theo zoneId, theo tên, hoặc nội dung thông báo',
    () {
      final p = FarmProvider();
      final z1 = ZoneModel(
        zoneId: 'z_tomato',
        farmId: 'f1',
        name: 'Nhà Cà Chua',
        currentCrop: 'Cà chua',
        currentStage: 'Ra hoa',
        areaM2: 500,
        currentSoilMoisture: 60,
        currentTemp: 25,
        currentHumidity: 70,
        currentLux: 500,
        telemetryIsFresh: true,
      );
      final z2 = ZoneModel(
        zoneId: 'z_lettuce',
        farmId: 'f1',
        name: 'Nhà Xà Lách',
        currentCrop: 'Xà lách',
        currentStage: 'Cây con',
        areaM2: 300,
        currentSoilMoisture: 50,
        currentTemp: 22,
        currentHumidity: 65,
        currentLux: 400,
        telemetryIsFresh: true,
      );
      p.setZonesForTesting([z1, z2]);

      // 1. Khớp theo zoneId
      final altById = AlertModel(
        alertId: 'a1',
        title: 'Cảnh báo nhiệt độ',
        message: 'Nhiệt độ cao',
        severity: 'WARNING',
        time: '12:00',
        zoneId: 'z_tomato',
      );
      expect(
        resolveZoneForAlert(alt: altById, provider: p)?.zoneId,
        'z_tomato',
      );

      // 2. Khớp theo tên zone trong title / message khi zoneId rỗng (giống hình user gửi)
      final altByTitle = AlertModel(
        alertId: 'a2',
        title:
            '[CẢNH BÁO MÔI TRƯỜNG] Độ ẩm không khí bất thường tại Nhà Cà Chua',
        message:
            'Độ ẩm không khí ghi nhận mức 65.1% (vượt ngưỡng cho phép 70 - 80%).',
        severity: 'WARNING',
        time: '12:00',
        zoneId: '',
      );
      expect(
        resolveZoneForAlert(alt: altByTitle, provider: p)?.name,
        'Nhà Cà Chua',
      );

      // 3. Khớp theo zoneName
      final altByName = AlertModel(
        alertId: 'a3',
        title: 'Cảnh báo',
        message: 'Độ ẩm thấp',
        severity: 'WARNING',
        time: '12:00',
        zoneName: 'Nhà Xà Lách',
      );
      expect(
        resolveZoneForAlert(alt: altByName, provider: p)?.zoneId,
        'z_lettuce',
      );

      // 4. resolveZoneForNotification tương tự
      final notif = AppNotificationModel(
        notificationId: 'n1',
        title: '[CẢNH BÁO] Độ ẩm bất thường tại Nhà Cà Chua',
        message: 'Kiểm tra hệ thống tưới',
        type: 'Alert',
        createdAt: '2026-11-19T10:00:00Z',
      );
      expect(
        resolveZoneForNotification(notif: notif, provider: p)?.name,
        'Nhà Cà Chua',
      );
    },
  );
}
