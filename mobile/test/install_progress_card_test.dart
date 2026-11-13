import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

bool withContext = false;

Map<String, dynamic> _deployment(String status, {bool feasible = true}) => {
  'requestId': 'dep1',
  'farmId': 'f1',
  'zoneId': 'z1',
  'status': status,
  'requiredParameters': ['Temperature'],
  'planItems': [],
  if (withContext) ...{
    'estimateItems': [
      {
        'estimateItemId': 'e1',
        'name': 'Cảm biến nhiệt',
        'code': 'S1',
        'role': 'Sensor',
        'quantity': 2,
        'unitPrice': 100000,
      },
    ],
    'context': {
      'farmName': 'Trại A',
      'fieldName': 'Thửa 1',
      'zoneName': 'Zone 1',
      'zoneType': 'Greenhouse',
      'zoneAreaM2': 500,
      'cropName': 'Cà chua',
      'seasonName': 'Vụ 1',
      'seasonStatus': 'InProgress',
    },
  },
  'surveys': status == 'Surveyed'
      ? [
          {
            'isFeasible': feasible,
            'siteConditions': 'Cạnh nhà kho',
            'notes': 'Ổn',
            'surveyedAtUtc': '2026-11-12T08:00:00Z',
          },
        ]
      : [],
  'decisionHistory': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];
  var code = 'NEW_INSTALL';
  var srStatus = 'Assigned';
  var depStatus = 'Accepted';
  var feasible = true;
  var depHttp = 200;
  var estimate = <Map<String, dynamic>>[];
  var hwItems = <Map<String, dynamic>>[];
  var srFarm = 'f1';
  String? quote = 'SignedByOwner';
  var quoteFail = false; // báo giá trả lỗi 500

  Future<http.Response> handler(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (r.method == 'GET' && p.endsWith('/service-requests/s1')) {
      return _json({
        'id': 's1',
        'failureCode': code,
        'description': 'Lắp đặt IoT',
        'status': srStatus,
        'deploymentRequestId': 'dep1',
        'farmId': srFarm,
        'zoneId': 'z1',
        'history': <Object>[],
      });
    }
    if (p.endsWith('/service-requests/s1/quotation')) {
      if (quoteFail) return _json({'detail': 'boom'}, 500);
      if (quote == null) return http.Response('', 404);
      return _json({
        'id': 'q1',
        'status': quote,
        'subtotal': 12500000,
        'vatAmount': 1000000,
        'totalAmount': 13500000,
        'deposit30Percent': 4050000,
        'remaining70Percent': 9450000,
        'contractTerms': 'Bảo hành 24 tháng',
        'items': [
          {
            'code': 'GW',
            'name': 'Gateway LoRa',
            'category': 'GATEWAY',
            'unit': 'Trạm',
            'quantity': 1,
            'unitPrice': 12500000,
            'vatPercent': 8,
            'totalAmount': 13500000,
          },
        ],
      });
    }
    if (p.endsWith('/quotation/estimate-draft')) {
      return _json({'serviceRequestId': 's1', 'items': estimate});
    }
    if (p.endsWith('/platform/hardware-items')) return _json(hwItems);
    if (p.endsWith('/zones/z1/devices')) return _json([]);
    if (p.endsWith('/devices/map-locations')) {
      return _json([
        {'deviceId': 'a'},
        {'deviceId': 'b'},
        {'deviceId': 'c'},
      ]);
    }
    if (r.method == 'GET' && p.endsWith('/platform/deployment-requests/dep1')) {
      return depHttp == 200
          ? _json(_deployment(depStatus, feasible: feasible))
          : _json({
              'detail':
                  'Deployment Request is not assigned to this Technician.',
            }, 404);
    }
    if (r.method == 'POST' &&
        p.contains('/platform/deployment-requests/dep1/')) {
      return _json(_deployment(depStatus));
    }
    return _json([]);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 't@b.c',
      role: 'PlatformTechnician',
    );
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient(handler),
    );
  });

  setUp(() {
    calls.clear();
    code = 'NEW_INSTALL';
    srStatus = 'InProgress';
    depStatus = 'Accepted';
    feasible = true;
    depHttp = 200;
    srFarm = 'f1';
    quote = 'SignedByOwner';
    quoteFail = false;
    estimate = [];
    hwItems = [];
    withContext = false;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox()); // bỏ State cũ để tải lại dữ liệu
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: ServiceRequestDetailScreen(requestId: 's1')),
    );
    await tester.pumpAndSettle();
  }

  List<http.Request> posts() => calls.where((c) => c.method == 'POST').toList();

  testWidgets(
    'phiếu lắp đặt: hiện khối Tiến độ lắp đặt, không có nút bảo trì',
    (tester) async {
      srStatus = 'InProgress';
      await pump(tester);
      expect(find.text('Tiến độ lắp đặt'), findsOneWidget);
      expect(find.text('KTV đã tiếp nhận'), findsOneWidget);
      expect(find.text('Ghi chẩn đoán'), findsNothing);
      expect(find.text('Đóng yêu cầu'), findsNothing);
      expect(find.textContaining('ký nghiệm thu'), findsWidgets);
    },
  );

  testWidgets(
    'đầu trang giống web: loại, trạng thái dịch vụ, hợp đồng, tiêu đề dễ đọc, số node; không hiện mã lỗi thô',
    (tester) async {
      srStatus = 'InProgress';
      await pump(tester);
      expect(find.text('Chi tiết lắp đặt'), findsOneWidget);
      expect(find.text('Lắp đặt thiết bị mới'), findsOneWidget);
      expect(find.text('Dịch vụ: Đang xử lý'), findsOneWidget);
      expect(find.text('Hợp đồng: Đã thanh toán 30% cọc'), findsOneWidget);
      expect(find.text('Lắp đặt IoT'), findsOneWidget);
      expect(find.text('NEW_INSTALL'), findsNothing);
      expect(find.text('3 node đã chấm trên bản đồ'), findsOneWidget);
    },
  );

  testWidgets(
    'nút Soạn báo giá & hợp đồng luôn có (như web), kể cả khi triển khai mới ở bước Accepted; mở ra là có sẵn dự toán của Owner',
    (tester) async {
      quote = null;
      depStatus = 'Accepted';
      estimate = [
        {
          'code': 'GW-ESP32-DL01',
          'name': 'Trạm Central Gateway',
          'category': 'GATEWAY',
          'unit': 'Trạm',
          'quantity': 1,
          'unitPrice': 3800000,
          'vatPercent': 8,
          'notes': 'Từ dự toán của Owner',
        },
      ];
      await pump(tester);
      expect(find.textContaining('trước khi soạn báo giá'), findsNothing);
      await tester.tap(find.text('Soạn báo giá & hợp đồng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã dựng sẵn 1 hạng mục'), findsWidgets);
      expect(find.text('Trạm Central Gateway'), findsOneWidget);
      expect(find.text('4.104.000 đ'), findsWidgets);
    },
  );

  testWidgets(
    'triển khai khác farm so với phiếu: cảnh báo liên kết sai, không có nút thao tác',
    (tester) async {
      srFarm = 'f-other';
      await pump(tester);
      expect(
        find.textContaining('Liên kết triển khai sai farm/zone'),
        findsOneWidget,
      );
      expect(find.text('Ghi nhận khảo sát địa điểm'), findsNothing);
      expect(find.text('Mở chi tiết triển khai'), findsNothing);
    },
  );

  testWidgets(
    'phiếu bảo trì: không có khối Tiến độ lắp đặt, vẫn có nút bảo trì',
    (tester) async {
      code = 'SENSOR_OFFLINE';
      srStatus = 'InProgress';
      await pump(tester);
      expect(find.text('Tiến độ lắp đặt'), findsNothing);
      expect(find.text('Ghi chẩn đoán'), findsOneWidget);
      expect(
        calls.any((c) => c.url.path.contains('platform/deployment-requests')),
        isFalse,
      );
    },
  );

  testWidgets(
    'phiếu lắp đặt mới giao: KHÔNG có nút Nhận việc; vào thẳng bước triển khai (khảo sát), không có Xác nhận kế hoạch',
    (tester) async {
      srStatus = 'Assigned';
      quote = null;
      depStatus = 'Accepted';
      await pump(tester);
      expect(find.text('Nhận việc'), findsNothing);
      expect(find.text('Ghi nhận khảo sát địa điểm'), findsOneWidget);
      expect(find.text('Xác nhận kế hoạch'), findsNothing);
      expect(find.textContaining('Gắn Node ('), findsNothing);
      expect(posts(), isEmpty);
    },
  );

  testWidgets('hoàn tất hoặc hủy không cho chấm thêm Node dù đã cọc', (
    tester,
  ) async {
    for (final status in ['Completed', 'Cancelled', 'MaintenanceRequired']) {
      depStatus = status;
      await pump(tester);
      expect(find.textContaining('Gắn Node ('), findsNothing);
      expect(find.text('Bắt đầu lắp đặt'), findsNothing);
    }
  });

  testWidgets('chưa cọc không mở bắt đầu lắp đặt dù kế hoạch đã xác nhận', (
    tester,
  ) async {
    depStatus = 'PlanConfirmed';
    quote = 'SentToOwner';
    await pump(tester);
    expect(find.text('Bắt đầu lắp đặt'), findsNothing);
    expect(find.textContaining('Gắn Node ('), findsNothing);
    expect(posts(), isEmpty);
  });

  testWidgets('đã nhận triển khai: khảo sát bắt buộc nhập đủ rồi mới gửi', (
    tester,
  ) async {
    quote = null;
    await pump(tester);
    await tester.tap(find.text('Ghi nhận khảo sát địa điểm'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận'));
    await tester.pumpAndSettle();
    // Không mặc định "khả thi": phải chọn rõ.
    expect(find.text('Hãy chọn khả thi hoặc không khả thi.'), findsOneWidget);
    expect(find.text('Cần nhập điều kiện địa điểm.'), findsOneWidget);
    expect(find.text('Cần nhập ghi chú khảo sát.'), findsOneWidget);
    expect(posts(), isEmpty); // hộp thoại không đóng khi còn thiếu
    await tester.tap(find.text('Khả thi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Cạnh nhà kho');
    await tester.enterText(find.byType(TextField).at(1), 'Đủ chỗ đặt gateway');
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận'));
    await tester.pumpAndSettle();
    final post = posts().single;
    expect(
      post.url.path,
      endsWith('/platform/deployment-requests/dep1/survey'),
    );
    expect(jsonDecode(post.body), {
      'isFeasible': true,
      'siteConditions': 'Cạnh nhà kho',
      'notes': 'Đủ chỗ đặt gateway',
    });
  });

  testWidgets(
    'khảo sát không khả thi: bắt buộc ghi lý do, gửi isFeasible=false',
    (tester) async {
      quote = null;
      await pump(tester);
      await tester.tap(find.text('Ghi nhận khảo sát địa điểm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không khả thi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Đất ngập nước');
      await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Cần ghi rõ lý do không khả thi.'), findsOneWidget);
      expect(posts(), isEmpty);
      await tester.enterText(
        find.byType(TextField).at(1),
        'Không có nguồn điện',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận'));
      await tester.pumpAndSettle();
      expect(jsonDecode(posts().single.body), {
        'isFeasible': false,
        'siteConditions': 'Đất ngập nước',
        'notes': 'Không có nguồn điện',
      });
    },
  );

  testWidgets('KTV thấy Farm/Thửa/Zone, cây trồng và thiết bị Owner đề xuất', (
    tester,
  ) async {
    depStatus = 'Accepted';
    withContext = true;
    await pump(tester);
    expect(
      find.textContaining('Farm: Trại A · Thửa: Thửa 1 · Zone: Zone 1'),
      findsOneWidget,
    );
    expect(find.textContaining('Cây trồng: Cà chua'), findsOneWidget);
    expect(find.text('Thiết bị Owner đề xuất:'), findsOneWidget);
    expect(find.text('• 2 × Cảm biến nhiệt'), findsOneWidget);
  });

  testWidgets(
    'chưa có hợp đồng đã ký: không thể mở Chấm Node bằng đường tắt khác',
    (tester) async {
      quote = 'SentToOwner';
      depStatus = 'PlanConfirmed';
      await pump(tester);
      expect(find.byIcon(Icons.my_location), findsNothing);
      expect(find.text('Sửa biểu đồ GIS (3 node)'), findsNothing);
      expect(find.text('Vào thực địa chấm node'), findsNothing);
    },
  );

  testWidgets(
    'chưa ai nhận (Submitted): có nút tiếp nhận, xác nhận rồi gọi accept',
    (tester) async {
      quote = null;
      depStatus = 'Submitted';
      await pump(tester);
      await tester.tap(find.text('Tiếp nhận yêu cầu triển khai'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      expect(
        posts().single.url.path,
        endsWith('/platform/deployment-requests/dep1/accept'),
      );
    },
  );

  testWidgets(
    'khảo sát khả thi: không có nút xác nhận kế hoạch; không khả thi: chặn và báo rõ',
    (tester) async {
      depStatus = 'Surveyed';
      quote = null;
      await pump(tester);
      // Không còn nút Xác nhận kế hoạch trên thẻ: khảo sát khả thi thì bước tiếp theo là tạo/gửi hợp đồng.
      expect(find.text('Xác nhận kế hoạch'), findsNothing);
      expect(find.text('Soạn báo giá & hợp đồng'), findsOneWidget);
      expect(posts(), isEmpty);

      calls.clear();
      feasible = false;
      await pump(tester);
      expect(find.text('Xác nhận kế hoạch'), findsNothing);
      expect(find.textContaining('KHÔNG khả thi'), findsOneWidget);
      expect(find.text('Ghi nhận khảo sát khác'), findsNothing);
    },
  );

  testWidgets('đã cọc: mở Gắn Node không cần xác nhận hoặc bắt đầu lắp đặt', (
    tester,
  ) async {
    for (final contractStatus in ['SignedByOwner', 'DepositPaid']) {
      quote = contractStatus;
      srStatus = 'Assigned';
      for (final status in [
        'Accepted',
        'Surveyed',
        'PlanConfirmed',
        'Installing',
      ]) {
        depStatus = status;
        await pump(tester);
        expect(find.text('Gắn Node (3 đã có vị trí)'), findsOneWidget);
        expect(find.text('Bắt đầu lắp đặt'), findsNothing);
        expect(find.text('Xác nhận kế hoạch'), findsNothing);
        expect(find.text('Nhận việc'), findsNothing);
        expect(posts(), isEmpty);
      }
    }
  });

  testWidgets(
    'đang lắp đặt: không có nút chuyển bước, chỉ mở chi tiết triển khai',
    (tester) async {
      depStatus = 'Installing';
      await pump(tester);
      expect(find.text('Mở chi tiết triển khai'), findsNothing);
      expect(find.text('Bắt đầu lắp đặt'), findsNothing);
      expect(find.text('Xác nhận kế hoạch'), findsNothing);
      expect(posts(), isEmpty);
    },
  );

  testWidgets(
    'không đọc được triển khai (404): báo lỗi và cho thử lại, không có nút giả',
    (tester) async {
      depHttp = 404;
      await pump(tester);
      expect(
        find.textContaining('not assigned to this Technician'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Ghi nhận khảo sát địa điểm'), findsNothing);
    },
  );

  Map<String, dynamic> estLine(String code, String cat, int qty, num price) => {
    'code': code,
    'name': 'Thiết bị $code',
    'category': cat,
    'unit': 'Cái',
    'quantity': qty,
    'unitPrice': price,
    'vatPercent': 8,
    'totalAmount': qty * price * 1.08,
    'notes': 'Từ dự toán của Owner',
  };

  testWidgets(
    'soạn báo giá: dựng sẵn các dòng từ "Thiết bị đề xuất & dự toán" của Owner, tổng và cọc tính từ đó',
    (tester) async {
      quote = null;
      depStatus = 'Surveyed';
      estimate = [
        estLine('GW', 'GATEWAY', 1, 3800000),
        estLine('SN', 'SENSOR_NODE', 2, 1250000),
      ];
      await pump(tester);
      await tester.tap(find.text('Soạn báo giá & hợp đồng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã dựng sẵn 2 hạng mục'), findsWidgets);
      expect(find.text('Thiết bị GW'), findsOneWidget);
      expect(find.text('Thiết bị SN'), findsOneWidget);
      expect(find.textContaining('(2/2)'), findsOneWidget);
      expect(find.text('6.804.000 đ'), findsOneWidget); // 6.300.000 + VAT 8%
      expect(find.text('2.041.200 đ'), findsOneWidget); // cọc 30%
      // Loại hiển thị tiếng Việt (không phải mã thô GATEWAY/SENSOR_NODE) trong phần "Sửa chi tiết" của từng dòng.
      await tester.tap(
        find.text('Sửa chi tiết (mã, tên, loại, ghi chú)').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Gateway'), findsWidgets);
      expect(find.text('GATEWAY'), findsNothing);
    },
  );

  testWidgets(
    'Owner chưa lưu dự toán: báo rõ và để bảng trống để thêm từ kho',
    (tester) async {
      quote = null;
      depStatus = 'Surveyed';
      estimate = [];
      await pump(tester);
      await tester.tap(find.text('Soạn báo giá & hợp đồng'));
      await tester.pumpAndSettle();
      expect(
        find.byType(Checkbox),
        findsOneWidget,
      ); // chỉ một dòng trống mặc định
      expect(find.textContaining('Đã dựng sẵn'), findsNothing);
    },
  );

  testWidgets(
    'thanh quy trình 4 bước theo báo giá và triển khai (Owner đã cọc, đang lắp đặt)',
    (tester) async {
      srStatus = 'InProgress';
      depStatus = 'Installing';
      await pump(tester);
      expect(find.text('Quy trình lắp đặt'), findsOneWidget);
      for (final s in [
        'Báo giá & hợp đồng',
        'Owner ký & cọc 30%',
        'Thi công & chấm node',
        'Nghiệm thu 70%',
      ]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
    },
  );

  testWidgets(
    'thao tác thực địa: backend xác nhận Owner đã cọc thì có nút "Chấm Node"',
    (tester) async {
      quote = 'SignedByOwner';
      depStatus = 'Installing';
      await pump(tester);
      expect(find.text('THAO TÁC THỰC ĐỊA KỸ THUẬT'), findsOneWidget);
      expect(find.text('Mở chi tiết triển khai'), findsNothing);
      expect(find.text('Gắn Node (3 đã có vị trí)'), findsOneWidget);
      expect(find.textContaining('Chờ Owner ký & cọc 30%'), findsNothing);
    },
  );

  testWidgets(
    'thao tác thực địa: chưa ký/cọc thì KHÔNG có nút Chấm Node, chỉ hiện khóa chờ cọc',
    (tester) async {
      quote = 'SentToOwner';
      await pump(tester);
      expect(find.byIcon(Icons.my_location), findsNothing);
      expect(find.textContaining('Gắn Node'), findsNothing);
      expect(find.text('Chờ Owner ký & cọc 30% mới gắn Node'), findsOneWidget);
    },
  );

  testWidgets('chưa có báo giá (404): không hiện Chấm Node', (tester) async {
    quote = null;
    await pump(tester);
    expect(find.byIcon(Icons.my_location), findsNothing);
    expect(find.text('Chờ Owner ký & cọc 30% mới gắn Node'), findsOneWidget);
  });

  testWidgets(
    'banner hợp đồng: mã, số thiết bị, tổng, cọc 30%; đã ký thì khóa và chỉ xem được hợp đồng',
    (tester) async {
      quote = 'SignedByOwner';
      await pump(tester);
      expect(find.textContaining('(1 thiết bị)'), findsOneWidget);
      expect(
        find.text('Tổng HĐ: 13.500.000 đ • Cọc 30%: 4.050.000 đ'),
        findsOneWidget,
      );
      expect(find.text('Owner đã ký và cọc 30% (khóa sửa)'), findsOneWidget);
      expect(find.text('Soạn báo giá & hợp đồng'), findsNothing);
      await tester.tap(find.text('Xem hợp đồng (đã khóa)'));
      await tester.pumpAndSettle();
      expect(find.text('Hợp đồng triển khai IoT (đã khóa)'), findsOneWidget);
      expect(find.text('Hợp đồng lắp đặt IoT #S1'), findsOneWidget);
      expect(
        find.text('Bảo hành 24 tháng'),
        findsOneWidget,
      ); // điều khoản đã lưu
      expect(find.text('Xác nhận & gửi hợp đồng cho khách'), findsNothing);
    },
  );

  testWidgets(
    'hợp đồng đã gửi nhưng chưa ký: banner chờ Owner cọc, vẫn xem / sửa được',
    (tester) async {
      quote = 'SentToOwner';
      await pump(tester);
      expect(find.text('Chờ Owner ký và thanh toán 30%'), findsOneWidget);
      expect(find.text('Xem / sửa báo giá & hợp đồng'), findsOneWidget);
      expect(find.text('Xem hợp đồng (đã khóa)'), findsNothing);
    },
  );

  Map<String, dynamic> hw(
    String id,
    String code,
    String role,
    num price, {
    List<String> measured = const [],
  }) => {
    'id': id,
    'code': code,
    'name': 'Thiết bị $code',
    'category': 'X',
    'model': 'M-$code',
    'quantityInStock': 10,
    'unitPrice': price,
    'status': 'InStock',
    'estimateRole': role,
    'estimateUnits': 1,
    'measuredParameters': measured,
  };

  Future<void> pumpWithZone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>(
        create: (_) => _OneZone(),
        child: const MaterialApp(
          home: ServiceRequestDetailScreen(requestId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Owner chưa lưu dự toán: bảng hợp đồng để trống và báo rõ, app KHÔNG tự tính thiết bị theo diện tích Zone',
    (tester) async {
      quote = null;
      depStatus = 'Accepted';
      estimate = [];
      hwItems = [
        hw('11111111-1111-1111-1111-111111111111', 'GW', 'Gateway', 3800000),
        hw('44444444-4444-4444-4444-444444444444', 'KIT', 'InstallKit', 150000),
      ];
      await pumpWithZone(tester);
      await tester.tap(find.text('Soạn báo giá & hợp đồng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Owner chưa lưu dự toán'), findsOneWidget);
      expect(
        find.byType(Checkbox),
        findsOneWidget,
      ); // chỉ một dòng trống mặc định
      expect(find.text('Thiết bị GW'), findsNothing);
      expect(find.textContaining('theo diện tích Zone'), findsNothing);
      expect(find.textContaining('Thi công, định vị GPS'), findsNothing);
      // Không đọc kho/thiết bị Zone để tính thay dự toán.
      expect(
        calls.any((c) => c.url.path.endsWith('/zones/z1/devices')),
        isFalse,
      );
    },
  );
  // ───────── Gắn Node: cổng theo hợp đồng/cọc backend, độc lập với xác nhận kế hoạch/bắt đầu lắp đặt ─────────
  for (final dep in ['Accepted', 'Surveyed', 'PlanConfirmed']) {
    testWidgets(
      'đã cọc 30% + triển khai $dep: hiện "Gắn Node" ngay, không còn nhận việc/xác nhận kế hoạch',
      (tester) async {
        quote = 'SignedByOwner';
        depStatus = dep;
        srStatus = 'Assigned'; // chưa bấm Nhận việc cũng không bị bắt nhận lại
        await pump(tester);
        expect(find.text('Gắn Node (3 đã có vị trí)'), findsOneWidget);
        for (final obsolete in [
          'Nhận việc',
          'Tiếp nhận yêu cầu triển khai',
          'Ghi nhận khảo sát địa điểm',
          'Xác nhận kế hoạch',
          'Bắt đầu lắp đặt',
        ]) {
          expect(find.text(obsolete), findsNothing, reason: obsolete);
        }
        // Mở màn không đẩy trạng thái nào của backend.
        expect(posts(), isEmpty);
      },
    );
  }

  testWidgets(
    'chưa cọc: không có Nhận việc, không có Gắn Node và không có Xác nhận kế hoạch',
    (tester) async {
      quote = 'SentToOwner';
      depStatus = 'Surveyed';
      srStatus = 'Assigned';
      await pump(tester);
      expect(find.byIcon(Icons.my_location), findsNothing);
      expect(find.text('Nhận việc'), findsNothing);
      expect(find.text('Xác nhận kế hoạch'), findsNothing);
    },
  );

  testWidgets(
    'đã cọc nhưng phiếu/triển khai/báo giá kết thúc: không có Gắn Node',
    (tester) async {
      Future<void> expectNoPlacement(String why) async {
        await pump(tester);
        expect(find.byIcon(Icons.my_location), findsNothing, reason: why);
        expect(find.textContaining('Gắn Node'), findsNothing, reason: why);
      }

      quote = 'SignedByOwner';
      srStatus = 'Closed';
      depStatus = 'Installing';
      await expectNoPlacement('phiếu đã đóng');
      srStatus = 'InProgress';
      for (final d in ['Completed', 'Cancelled', 'MaintenanceRequired']) {
        depStatus = d;
        await expectNoPlacement('triển khai $d');
      }
      depStatus = 'Installing';
      quote = 'Completed';
      await expectNoPlacement('báo giá đã nghiệm thu');
    },
  );

  testWidgets('báo giá thiếu (404) hoặc lỗi (500): không mở khoá Gắn Node', (
    tester,
  ) async {
    quote = null;
    await pump(tester);
    expect(find.byIcon(Icons.my_location), findsNothing);
    quote = 'SignedByOwner';
    quoteFail = true;
    await pump(tester);
    expect(find.byIcon(Icons.my_location), findsNothing);
  });

  testWidgets('liên kết triển khai sai Farm: không có Gắn Node dù đã cọc', (
    tester,
  ) async {
    quote = 'SignedByOwner';
    srFarm = 'f-other';
    await pump(tester);
    expect(find.byIcon(Icons.my_location), findsNothing);
    expect(
      find.textContaining('Liên kết triển khai sai farm/zone'),
      findsOneWidget,
    );
  });

  testWidgets(
    'làm mới: dữ liệu cọc cũ không được giữ khi tải lại lỗi (khoá), tải lại được thì mở lại',
    (tester) async {
      quote = 'SignedByOwner';
      await pump(tester);
      expect(find.text('Gắn Node (3 đã có vị trí)'), findsOneWidget);
      quoteFail = true;
      await tester.tap(find.byTooltip('Làm mới'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.my_location), findsNothing);
      quoteFail = false;
      await tester.tap(find.byTooltip('Làm mới'));
      await tester.pumpAndSettle();
      expect(find.text('Gắn Node (3 đã có vị trí)'), findsOneWidget);
    },
  );

  testWidgets(
    'bấm Gắn Node khi backend vừa không xác nhận được cọc: không mở màn, báo lý do (không dùng quyền cũ)',
    (tester) async {
      quote = 'SignedByOwner';
      await pump(tester);
      expect(find.text('Gắn Node (3 đã có vị trí)'), findsOneWidget);
      quoteFail = true; // lúc bấm đọc lại báo giá bị lỗi
      await tester.tap(find.text('Gắn Node (3 đã có vị trí)'));
      await tester.pumpAndSettle();
      expect(find.text('Cập nhật vị trí'), findsNothing);
      expect(find.textContaining('Chưa xác nhận được hợp đồng'), findsWidgets);
      // Đọc lại lỗi cũng khoá luôn nút trên thẻ.
      expect(find.byIcon(Icons.my_location), findsNothing);
    },
  );

  testWidgets(
    'nút "Xem Node" luôn có ở khung thao tác: khi chờ cọc, khi đã cọc và cả khi công việc đã kết thúc',
    (tester) async {
      quote = 'SentToOwner';
      await pump(tester);
      expect(find.text('Xem Node'), findsOneWidget);
      expect(
        find.byIcon(Icons.my_location),
        findsNothing,
      ); // vẫn không có Gắn Node

      quote = 'SignedByOwner';
      depStatus = 'Installing';
      await pump(tester);
      expect(find.text('Xem Node'), findsOneWidget);
      expect(find.textContaining('Gắn Node ('), findsOneWidget);

      depStatus = 'Completed';
      await pump(tester);
      expect(
        find.text('Xem Node'),
        findsOneWidget,
      ); // đã hoàn tất vẫn xem được Node
      expect(find.textContaining('Gắn Node'), findsNothing);
    },
  );
}

class _OneZone extends FarmProvider {
  @override
  List<ZoneModel> get allZones => [
    ZoneModel.fromJson(
      {'zoneId': 'z1', 'name': 'Líp 00', 'areaM2': 2500},
      farmId: 'f1',
      fieldId: 'fl1',
      farmName: 'Nông trại demo',
      fieldName: 'Lô A',
    ),
  ];
}
