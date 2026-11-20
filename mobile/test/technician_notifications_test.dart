import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart';
import 'package:smartfarm_mobile/features/tasks/notification_navigation.dart';
import 'package:smartfarm_mobile/features/tasks/technician_notifications_screen.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _n(
  String id,
  String title,
  String type,
  DateTime at, {
  bool read = false,
  String? ref,
}) => {
  'notificationId': id,
  'title': title,
  'message': 'Nội dung $title',
  'type': type,
  'severity': 'Info',
  'isRead': read,
  'referenceId': ref,
  'createdAtUtc': at.toUtc().toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient((r) async {
        calls.add(r);
        return handler(r);
      }),
    );
  });

  setUp(() {
    calls.clear();
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'ktv@b.c',
      role: 'PlatformTechnician',
    );
  });

  test('nhãn thời gian: vừa xong, phút, giờ, ngày giờ; chuỗi lạ giữ nguyên', () {
    final now = DateTime.utc(2026, 11, 18, 10, 0);
    String l(DateTime t) => notificationTimeLabel(
      t.toIso8601String(),
      now: now.toLocal(),
    );
    expect(l(now.subtract(const Duration(seconds: 20))), 'Vừa xong');
    expect(l(now.subtract(const Duration(minutes: 5))), '5 phút trước');
    expect(l(now.subtract(const Duration(hours: 3))), '3 giờ trước');
    expect(
      l(now.subtract(const Duration(days: 2))),
      matches(RegExp(r'^\d{2}/\d{2}/2026 \d{2}:\d{2}$')),
    );
    // Giờ trong tương lai (lệch đồng hồ máy) không âm: coi là vừa xong.
    expect(l(now.add(const Duration(minutes: 3))), 'Vừa xong');
    expect(notificationTimeLabel('Vừa xong'), 'Vừa xong');
  });

  testWidgets(
    'thông báo KTV: mới nhất lên đầu, có giờ, chưa đọc nổi bật; chạm đánh dấu đã đọc, "Đọc hết" đọc tất cả',
    (tester) async {
      final now = DateTime.now();
      handler = (r) async {
        if (r.url.path == '/api/v1/notifications' && r.method == 'GET') {
          return json([
            _n(
              'old',
              'Phiếu xuất kho đã duyệt',
              'StockOut',
              now.subtract(const Duration(days: 3)),
              read: true,
            ),
            _n(
              'new',
              'Bạn có yêu cầu mới',
              'Service',
              now.subtract(const Duration(minutes: 5)),
              ref: 'sr-1',
            ),
            _n(
              'mid',
              'Chủ trang trại đã ký hợp đồng và đóng cọc',
              'Service',
              now.subtract(const Duration(hours: 2)),
            ),
          ]);
        }
        return http.Response('{}', 200);
      };
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = FarmProvider();
      provider.switchRole('TECHNICIAN');
      await tester.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: provider,
          child: const MaterialApp(home: TechnicianNotificationsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Tải tối đa 100 thông báo gần nhất (không còn mặc định 20).
      final get = calls.lastWhere(
        (c) => c.url.path == '/api/v1/notifications' && c.method == 'GET',
      );
      expect(get.url.queryParameters['pageSize'], '100');

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(
        y('Bạn có yêu cầu mới') < y('Chủ trang trại đã ký hợp đồng và đóng cọc'),
        isTrue,
      );
      expect(
        y('Chủ trang trại đã ký hợp đồng và đóng cọc') <
            y('Phiếu xuất kho đã duyệt'),
        isTrue,
      );
      expect(find.text('5 phút trước'), findsOneWidget);
      expect(find.text('2 giờ trước'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^\d{2}/\d{2}/\d{4} \d{2}:\d{2}$')),
        findsOneWidget,
      );
      expect(find.text('Lắp đặt'), findsNWidgets(2));
      expect(find.text('Xuất kho'), findsOneWidget);
      expect(find.text('Đọc hết'), findsOneWidget);

      // Chạm thông báo chưa đọc loại Service có mã phiếu: đánh dấu đã đọc và mở chi tiết phiếu.
      await tester.tap(find.text('Chủ trang trại đã ký hợp đồng và đóng cọc'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        calls.any(
          (c) => c.method != 'GET' && c.url.path == '/api/v1/notifications/mid/read',
        ),
        isTrue,
      );

      // Đọc hết.
      await tester.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: provider,
          child: const MaterialApp(home: TechnicianNotificationsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Đọc hết'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        calls.any((c) => c.url.path == '/api/v1/notifications/read-all'),
        isTrue,
      );
      expect(find.text('Đọc hết'), findsNothing);
      expect(provider.notifications.every((n) => n.isRead), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      provider.dispose();
    },
  );

  test('chạm thông báo: KTV mở phiếu theo mã; hợp đồng sắp hết hạn chỉ dành cho Owner', () {
    expect(
      notificationDestination(
        type: 'Service',
        referenceId: 'sr-1',
        role: 'TECHNICIAN',
      ),
      NotificationDestination.serviceRequest,
    );
    expect(
      notificationDestination(
        type: 'Contract',
        referenceId: 'x',
        role: 'TECHNICIAN',
      ),
      NotificationDestination.none,
    );
    expect(ServiceRequestDetailScreen, isNotNull);
  });

  testWidgets('KTV: thông báo mới tự xuất hiện sau ~30 giây không cần mở lại màn', (
    tester,
  ) async {
    var served = false;
    handler = (r) async {
      if (r.url.path == '/api/v1/notifications' && r.method == 'GET') {
        return json(
          served
              ? [_n('n1', 'Bạn có yêu cầu mới', 'Service', DateTime.now(), ref: 'sr-9')]
              : <Object>[],
        );
      }
      return http.Response('[]', 200);
    };
    final provider = FarmProvider();
    provider.switchRole('TECHNICIAN');
    await tester.pump(const Duration(seconds: 1));
    expect(provider.notifications, isEmpty);
    served = true;
    final before = calls
        .where((c) => c.url.path == '/api/v1/notifications')
        .length;
    // 6 vòng × 5 giây của bộ đếm nền.
    for (var i = 0; i < 7; i++) {
      await tester.pump(const Duration(seconds: 5));
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      calls.where((c) => c.url.path == '/api/v1/notifications').length,
      greaterThan(before),
    );
    expect(provider.notifications.map((n) => n.title), ['Bạn có yêu cầu mới']);
    // KTV không bị gọi telemetry của farm (403): chỉ thông báo.
    expect(calls.any((c) => c.url.path.contains('telemetry')), isFalse);
    provider.dispose();
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('KTV: bộ lọc (chưa đọc, lắp đặt, xuất kho, tất cả) và xóa thông báo đã đọc', (
    tester,
  ) async {
    final now = DateTime.now();
    handler = (r) async {
      if (r.url.path == '/api/v1/notifications' && r.method == 'GET') {
        return json([
          _n(
            'n_read',
            'Phiếu xuất kho đã duyệt',
            'StockOut',
            now.subtract(const Duration(hours: 4)),
            read: true,
          ),
          _n(
            'n_service',
            'Bạn có yêu cầu mới',
            'Service',
            now.subtract(const Duration(minutes: 10)),
            ref: 'sr-1',
          ),
          _n(
            'n_service2',
            'Chủ trang trại đã ký nghiệm thu',
            'Service',
            now.subtract(const Duration(minutes: 30)),
            ref: 'sr-2',
          ),
        ]);
      }
      if (r.url.path == '/api/v1/notifications/read-all' && r.method == 'DELETE') {
        return json({'deletedCount': 1});
      }
      if (r.url.path.startsWith('/api/v1/notifications/') && r.method == 'DELETE') {
        return json({'success': true});
      }
      return http.Response('{}', 200);
    };

    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = FarmProvider();
    provider.switchRole('TECHNICIAN');
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: provider,
        child: const MaterialApp(home: TechnicianNotificationsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Hiển thị banner thống kê và các chip lọc
    expect(find.text('Bạn có 2 thông báo chưa đọc'), findsOneWidget);
    expect(find.text('Tất cả (3)'), findsOneWidget);
    expect(find.text('Chưa đọc (2)'), findsOneWidget);
    expect(find.text('Dịch vụ & Lắp đặt (2)'), findsOneWidget);
    expect(find.text('Phiếu xuất kho (1)'), findsOneWidget);

    // 1. Chuyển sang bộ lọc "Chưa đọc"
    await tester.tap(find.text('Chưa đọc (2)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bạn có yêu cầu mới'), findsOneWidget);
    expect(find.text('Chủ trang trại đã ký nghiệm thu'), findsOneWidget);
    expect(find.text('Phiếu xuất kho đã duyệt'), findsNothing);

    // 2. Chuyển sang bộ lọc "Phiếu xuất kho"
    await tester.tap(find.text('Phiếu xuất kho (1)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Phiếu xuất kho đã duyệt'), findsOneWidget);
    expect(find.text('Bạn có yêu cầu mới'), findsNothing);

    // 3. Chuyển sang "Dịch vụ & Lắp đặt"
    await tester.tap(find.text('Dịch vụ & Lắp đặt (2)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bạn có yêu cầu mới'), findsOneWidget);
    expect(find.text('Chủ trang trại đã ký nghiệm thu'), findsOneWidget);
    expect(find.text('Phiếu xuất kho đã duyệt'), findsNothing);

    // 4. Quay lại "Tất cả"
    await tester.tap(find.text('Tất cả (3)'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Phiếu xuất kho đã duyệt'), findsOneWidget);
    expect(find.text('Bạn có yêu cầu mới'), findsOneWidget);

    // 5. Thử popup menu "Xóa thông báo đã đọc"
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Xóa thông báo đã đọc'), findsOneWidget);
    await tester.tap(find.text('Xóa thông báo đã đọc'));
    await tester.pumpAndSettle();

    // Xuất hiện dialog xác nhận
    expect(find.text('Xóa tất cả'), findsOneWidget);
    await tester.tap(find.text('Xóa tất cả'));
    await tester.pumpAndSettle();

    expect(
      calls.any(
        (c) => c.url.path == '/api/v1/notifications/read-all' && c.method == 'DELETE',
      ),
      isTrue,
    );
    expect(provider.notifications.length, 2);

    // 6. Vuốt để xóa thông báo lẻ (Dismissible)
    final dismissItem = find.byKey(const ValueKey('dismiss_n_service2'));
    expect(dismissItem, findsOneWidget);
    await tester.drag(dismissItem, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(
      calls.any(
        (c) => c.url.path == '/api/v1/notifications/n_service2' && c.method == 'DELETE',
      ),
      isTrue,
    );
    expect(provider.notifications.length, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    provider.dispose();
  });
}
