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

/// Số Node đã chấm vị trí trên bản đồ Zone mà máy chủ trả về.
int placedNodes = 3;

/// Kế hoạch thiết bị của đợt triển khai trống (Owner chỉ gửi dự toán, kỹ thuật viên chưa lập kế hoạch).
bool emptyPlan = false;

Map<String, dynamic> _deployment(String status, {bool feasible = true}) => {
  'requestId': 'dep1',
  'farmId': 'f1',
  'zoneId': 'z1',
  'status': status,
  'requiredParameters': ['Temperature'],
  'planItems': emptyPlan
      ? []
      : [
          {
            'deviceModelId': 'm1',
            'modelName': 'Node cảm biến',
            'deviceType': 'SensorNode',
            'quantity': 2,
          },
        ],
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

/// Phiếu xuất kho của hợp đồng trả về cho GET /stock-outs (null = chưa có phiếu).
String? voucherStatus = 'Approved';
int voucherHttp = 200;

/// Mobile không còn nút "Gắn Node"; thay bằng chip chỉ dẫn sang Web khi backend cho phép gán Node (đã cọc).
const webNodeChip = 'Gán Node GIS thực hiện trên Web';

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
  var srDepositFlag = false; // cờ isDepositPaid trên phiếu dịch vụ

  Future<http.Response> handler(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (p.contains('/field-survey-reports')) {
      if (r.method == 'GET') return http.Response('', 404); // chưa có báo cáo
      if (r.method == 'POST') {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({
          ...b,
          'id': 'rep1',
          'farmName': 'Trang trại A',
          'createdByUserName': 'KTV',
        }, 201);
      }
    }
    if (r.method == 'GET' && p.endsWith('/service-requests/s1')) {
      return _json({
        'id': 's1',
        'failureCode': code,
        'description': 'Lắp đặt IoT',
        'status': srStatus,
        'isDepositPaid': srDepositFlag,
        'isContractSigned': srDepositFlag,
        'deploymentRequestId': 'dep1',
        'farmId': srFarm,
        'zoneId': 'z1',
        'history': <Object>[],
      });
    }
    if (r.method == 'POST' && p.endsWith('/stock-outs')) {
      return _json({
        'id': 'new1',
        'stockOutCode': 'PXK-N',
        'status': 'Draft',
        'notes': 'x',
        'details': <Object>[],
      }, 201);
    }
    if (r.method == 'PUT' &&
        p.contains('/stock-outs/') &&
        p.endsWith('/status')) {
      return _json({
        'id': 'new1',
        'stockOutCode': 'PXK-N',
        'status': 'Pending',
        'statusText': 'Chờ duyệt',
        'notes': 'x',
        'details': <Object>[],
      });
    }
    // Phiếu xuất kho của hợp đồng (báo giá q1 → HD-SR-Q1): mặc định đã được Admin duyệt.
    if (r.method == 'GET' && p.endsWith('/stock-outs')) {
      if (voucherHttp != 200) return _json({'detail': 'boom'}, voucherHttp);
      return _json(
        voucherStatus == null
            ? <Object>[]
            : [
                {
                  'id': 'so1',
                  'stockOutCode': 'PXK-T1',
                  'status': voucherStatus,
                  'statusText': voucherStatus,
                  'zoneId': '',
                  'notes': '[KTV tạo từ HĐ #HD-SR-Q1] test',
                  'createdAtUtc': '2026-11-12T00:00:00Z',
                  'details': <Object>[],
                },
              ],
      );
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
        for (final id in ['a', 'b', 'c'].take(placedNodes)) {'deviceId': id},
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
    voucherStatus = 'Approved';
    voucherHttp = 200;
    code = 'NEW_INSTALL';
    srStatus = 'InProgress';
    depStatus = 'Accepted';
    feasible = true;
    depHttp = 200;
    srFarm = 'f1';
    quote = 'SignedByOwner';
    quoteFail = false;
    srDepositFlag = false;
    estimate = [];
    hwItems = [];
    withContext = false;
    emptyPlan = false;
    placedNodes = 3;
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
    'khảo sát xong: có nút Soạn báo giá & hợp đồng; dự toán của Owner hiện ở khung đề xuất, KTV tự đưa vào HĐ',
    (tester) async {
      quote = null;
      depStatus = 'Surveyed';
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
      // Hợp đồng KHÔNG tự đổ dự toán: bảng trống, đề xuất của Owner nằm ở khung tham khảo.
      expect(
        find.text('1 hạng mục đề xuất (nhấn để xem chi tiết)'),
        findsOneWidget,
      );
      expect(find.text('Chưa có hạng mục nào trong hợp đồng.'), findsOneWidget);
      await _addProposals(tester);
      // Dòng dựng theo LOẠI + số lượng đề xuất; thiết bị cụ thể chọn từ kho bằng dropdown.
      expect(find.text('Gateway LoRa'), findsOneWidget);
      expect(find.text('Chưa chọn thiết bị'), findsOneWidget);
      // Tên Owner đề xuất chỉ hiện ở khung tham khảo, không thành tên dòng hợp đồng.
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
    'phiếu lắp đặt mới giao: KHÔNG có nút Nhận việc và không còn nút nhập khảo sát thực địa, không có Xác nhận kế hoạch',
    (tester) async {
      srStatus = 'Assigned';
      quote = null;
      depStatus = 'Accepted';
      await pump(tester);
      expect(find.text('Nhận việc'), findsNothing);
      expect(find.text('Ghi nhận khảo sát địa điểm'), findsNothing);
      expect(find.text('Xác nhận kế hoạch'), findsNothing);
      expect(find.text(webNodeChip), findsNothing);
      expect(posts(), isEmpty);
    },
  );

  testWidgets('hoàn tất hoặc hủy không cho chấm thêm Node dù đã cọc', (
    tester,
  ) async {
    for (final status in ['Completed', 'Cancelled', 'MaintenanceRequired']) {
      depStatus = status;
      await pump(tester);
      expect(find.text(webNodeChip), findsNothing);
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
    expect(find.text(webNodeChip), findsNothing);
    expect(posts(), isEmpty);
  });

  testWidgets('KTV thấy Farm/Thửa/Zone, cây trồng và thiết bị Owner đề xuất', (
    tester,
  ) async {
    depStatus = 'Accepted';
    withContext = true;
    emptyPlan = true; // Owner mới gửi dự toán, chưa có kế hoạch thiết bị
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
    'đã nhận yêu cầu (Accepted): phải điền khảo sát thực địa; chưa điền thì CHƯA có nút xem/xác nhận hợp đồng',
    (tester) async {
      quote = null;
      depStatus = 'Accepted';
      await pump(tester);
      expect(find.text('Lập báo cáo khảo sát thực địa'), findsOneWidget);
      expect(find.text('Soạn báo giá & hợp đồng'), findsNothing);
      expect(find.byKey(const ValueKey('survey-first')), findsOneWidget);
      expect(find.textContaining('Nộp xong mới hiện nút xem'), findsOneWidget);
    },
  );

  testWidgets(
    'lập báo cáo khảo sát: bắt buộc tiêu đề và kết luận khả thi; nộp thì lưu báo cáo rồi gửi khảo sát với kết luận KTV chọn',
    (tester) async {
      quote = null;
      depStatus = 'Accepted';
      await pump(tester);
      calls.clear();
      await http.runWithClient(() async {
        await tester.tap(find.text('Lập báo cáo khảo sát thực địa'));
        await tester.pumpAndSettle();
        expect(find.text('Lập báo cáo khảo sát thực địa'), findsWidgets);
        // chưa chọn kết luận: không gửi gì
        await tester.tap(find.byKey(const ValueKey('fs-submit')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chọn kết luận khảo sát'), findsOneWidget);
        expect(posts(), isEmpty);
        // nhập địa điểm + đánh giá, chọn Khả thi rồi nộp
        await tester.enterText(
          find.byKey(const ValueKey('fs-location')),
          'Thôn 3, Đà Lạt',
        );
        await tester.ensureVisible(find.byKey(const ValueKey('fs-feasible')));
        await tester.tap(find.byKey(const ValueKey('fs-feasible')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('fs-submit')));
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      final report = posts().where(
        (c) => c.url.path.endsWith('/field-survey-reports'),
      );
      expect(report, hasLength(1));
      final rb = jsonDecode(report.single.body) as Map;
      expect(rb['status'], 'Submitted');
      expect(rb['serviceRequestId'], 's1');
      expect(rb['location'], 'Thôn 3, Đà Lạt');
      expect(rb['title'], startsWith('Báo cáo khảo sát thực địa'));
      final survey = posts().where((c) => c.url.path.endsWith('/survey'));
      expect(survey, hasLength(1));
      final body = jsonDecode(survey.single.body) as Map;
      expect(body['isFeasible'], true);
      expect(body['siteConditions'], contains('Thôn 3, Đà Lạt'));
      expect((body['notes'] as String).isNotEmpty, isTrue);
    },
  );

  testWidgets(
    'khảo sát khả thi: không còn nút Xác nhận kế hoạch (tự xác nhận khi gửi hợp đồng); không khả thi: báo rõ',
    (tester) async {
      depStatus = 'Surveyed';
      quote = null;
      await pump(tester);
      // Kế hoạch tự được xác nhận khi KTV gửi hợp đồng nên không có nút riêng.
      expect(
        find.widgetWithText(FilledButton, 'Xác nhận kế hoạch'),
        findsNothing,
      );
      expect(find.text('Soạn báo giá & hợp đồng'), findsOneWidget);
      expect(posts(), isEmpty);

      calls.clear();
      feasible = false;
      await pump(tester);
      expect(
        find.widgetWithText(FilledButton, 'Xác nhận kế hoạch'),
        findsNothing,
      );
      expect(find.textContaining('KHÔNG khả thi'), findsWidgets);
      // không khả thi: khoá hợp đồng, cho khảo sát lại
      expect(find.text('Soạn báo giá & hợp đồng'), findsNothing);
      expect(find.byKey(const ValueKey('survey-first')), findsOneWidget);
      expect(find.text('Lập lại báo cáo khảo sát'), findsOneWidget);
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
        expect(find.text(webNodeChip), findsOneWidget);
        // Sau cọc không còn "Xác nhận kế hoạch" (đã tự xác nhận); Đã khảo sát / Đã xác nhận kế hoạch → "Bắt đầu lắp đặt".
        expect(find.text('Xác nhận kế hoạch'), findsNothing);
        // Nút "Bắt đầu lắp đặt" đã bỏ trên Mobile (chuyển sang quản lý trên Web).
        expect(find.text('Bắt đầu lắp đặt'), findsNothing);
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
    'soạn báo giá: đưa các dòng từ "Thiết bị đề xuất & dự toán" của Owner vào HĐ, tổng và cọc tính từ đó',
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
      expect(
        find.text('2 hạng mục đề xuất (nhấn để xem chi tiết)'),
        findsOneWidget,
      );
      await _addProposals(tester);
      expect(find.text('Gateway LoRa'), findsOneWidget);
      expect(find.text('Node cảm biến'), findsOneWidget);
      expect(find.text('Chưa chọn thiết bị'), findsNWidgets(2));
      expect(find.textContaining('(2/2)'), findsOneWidget);
      expect(find.text('6.804.000 đ'), findsOneWidget); // 6.300.000 + VAT 8%
      expect(find.text('2.041.200 đ'), findsOneWidget); // cọc 30%
      // Mỗi dòng thiết bị có dropdown chọn từ kho; không còn ô sửa tay mã/tên/giá.
      expect(find.text('GATEWAY'), findsNothing);
      expect(find.text('Sửa chi tiết (mã, tên, loại, ghi chú)'), findsNothing);
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
      // Bảng trống (không còn dòng trống/nhập ngoài): chỉ thêm thiết bị từ kho.
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Chưa có hạng mục nào'), findsOneWidget);
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
      expect(find.text(webNodeChip), findsOneWidget);
      expect(find.textContaining('Chờ Owner ký & cọc 30%'), findsNothing);
    },
  );

  testWidgets(
    'thao tác thực địa: chưa ký/cọc thì KHÔNG có nút Chấm Node, chỉ hiện khóa chờ cọc',
    (tester) async {
      quote = 'SentToOwner';
      await pump(tester);
      expect(find.byIcon(Icons.my_location), findsNothing);
      expect(find.text(webNodeChip), findsNothing);
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
      // Khối hợp đồng như web: tiêu đề, nhãn đã ký, tổng và số tiền tạm ứng đã thanh toán.
      expect(
        find.textContaining(
          '1. HỢP ĐỒNG BÁO GIÁ THIẾT BỊ & THANH TOÁN TẠM ỨNG 30%',
        ),
        findsOneWidget,
      );
      expect(find.text('✓ Đã Ký & Thanh toán 30%'), findsOneWidget);
      expect(find.textContaining('Tổng cộng (gồm VAT'), findsOneWidget);
      expect(find.text('13.500.000 đ'), findsWidgets);
      expect(find.text('SỐ TIỀN TẠM ỨNG 30% ĐÃ THANH TOÁN:'), findsOneWidget);
      expect(find.text('4.050.000 đ'), findsWidgets);
      expect(find.text('Soạn báo giá & hợp đồng'), findsNothing);
      await tester.tap(find.text('Xem hợp đồng (đã khóa)'));
      await tester.pumpAndSettle();
      expect(find.text('Hợp đồng triển khai IoT (đã khóa)'), findsOneWidget);
      expect(find.textContaining('Hợp đồng lắp đặt IoT'), findsWidgets);
      expect(find.textContaining('#S1'), findsNothing); // không hiện mã phiếu
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
      expect(find.text('Cần Owner Ký tên & Cọc 30%'), findsOneWidget);
      expect(find.text('Xem / sửa báo giá & hợp đồng'), findsOneWidget);
      expect(find.text('Xem hợp đồng (đã khóa)'), findsNothing);
    },
  );

  testWidgets(
    'đã khảo sát, kế hoạch trống: không có nút Xác nhận kế hoạch lẫn Lập kế hoạch thiết bị (backend tự dựng kế hoạch khi xác nhận)',
    (tester) async {
      depStatus = 'Surveyed';
      quote = null;
      emptyPlan = true;
      await pump(tester);
      expect(
        find.widgetWithText(FilledButton, 'Xác nhận kế hoạch'),
        findsNothing,
      );
      expect(
        find.widgetWithText(FilledButton, 'Lập kế hoạch thiết bị'),
        findsNothing,
      );
      expect(find.textContaining('Kế hoạch thiết bị đang trống'), findsNothing);
      expect(posts(), isEmpty);
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
    'Owner chưa lưu dự toán: bảng hợp đồng để trống, không có khung đề xuất, app KHÔNG tự tính thiết bị theo diện tích Zone',
    (tester) async {
      quote = null;
      depStatus = 'Surveyed';
      estimate = [];
      hwItems = [
        hw('11111111-1111-1111-1111-111111111111', 'GW', 'Gateway', 3800000),
        hw('44444444-4444-4444-4444-444444444444', 'KIT', 'InstallKit', 150000),
      ];
      await pumpWithZone(tester);
      await tester.tap(find.text('Soạn báo giá & hợp đồng'));
      await tester.pumpAndSettle();
      expect(
        find.text('Đề xuất thiết bị & Dự toán từ khách hàng'),
        findsNothing,
      );
      // Bảng trống (không còn dòng trống/nhập ngoài): chỉ thêm thiết bị từ kho.
      expect(find.byType(Checkbox), findsNothing);
      expect(find.textContaining('Chưa có hạng mục nào'), findsOneWidget);
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
        expect(find.text(webNodeChip), findsOneWidget);
        for (final obsolete in [
          'Nhận việc',
          'Tiếp nhận yêu cầu triển khai',
          'Ghi nhận khảo sát địa điểm',
        ]) {
          expect(find.text(obsolete), findsNothing, reason: obsolete);
        }
        // Mở màn không đẩy trạng thái nào của backend.
        expect(posts(), isEmpty);
      },
    );
  }

  testWidgets(
    'đã cọc + Đang lắp đặt: có nút Hoàn tất lắp đặt; bấm → xác nhận → gọi complete của backend',
    (tester) async {
      quote = 'SignedByOwner';
      depStatus = 'Installing';
      srStatus = 'InProgress';
      await pump(tester);
      final btn = find.text('Hoàn tất lắp đặt');
      expect(btn, findsOneWidget);
      calls.clear();
      await http.runWithClient(() async {
        await tester.tap(btn);
        await tester.pumpAndSettle();
        // KTV lập biên bản nghiệm thu rồi xác nhận hoàn tất
        expect(find.byKey(const ValueKey('acceptance-report')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('acceptance-confirm')));
        await tester.pumpAndSettle();
      }, () => MockClient(handler));
      expect(
        posts().where((c) => c.url.path.endsWith('/complete')),
        hasLength(1),
      );
    },
  );
  testWidgets('chưa cọc: không có nút Hoàn tất lắp đặt', (tester) async {
    quote = 'SentToOwner';
    depStatus = 'Installing';
    srStatus = 'InProgress';
    await pump(tester);
    expect(find.text('Hoàn tất lắp đặt'), findsNothing);
  });
  testWidgets(
    'chưa cọc: không có Nhận việc, không có Gắn Node, không có Xác nhận kế hoạch khi đã khảo sát',
    (tester) async {
      quote = 'SentToOwner';
      depStatus = 'Surveyed';
      srStatus = 'Assigned';
      await pump(tester);
      expect(find.byIcon(Icons.my_location), findsNothing);
      expect(find.text('Nhận việc'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'Xác nhận kế hoạch'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'đã cọc nhưng phiếu/triển khai/báo giá kết thúc: không có Gắn Node',
    (tester) async {
      Future<void> expectNoPlacement(String why) async {
        await pump(tester);
        expect(find.byIcon(Icons.my_location), findsNothing, reason: why);
        expect(find.text(webNodeChip), findsNothing, reason: why);
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
      expect(find.text(webNodeChip), findsOneWidget);
      quoteFail = true;
      await tester.tap(find.byTooltip('Làm mới'));
      await tester.pumpAndSettle();
      expect(find.text(webNodeChip), findsNothing);
      quoteFail = false;
      await tester.tap(find.byTooltip('Làm mới'));
      await tester.pumpAndSettle();
      expect(find.text(webNodeChip), findsOneWidget);
    },
  );

  testWidgets(
    'bấm Gắn Node khi backend vừa không xác nhận được cọc: không mở màn, báo lý do (không dùng quyền cũ)',
    (tester) async {
      quote = 'SignedByOwner';
      await pump(tester);
      expect(find.text(webNodeChip), findsOneWidget);
      quoteFail = true; // lúc bấm đọc lại báo giá bị lỗi
      await tester.tap(find.text(webNodeChip));
      await tester.pumpAndSettle();
      expect(find.text('Cập nhật vị trí'), findsNothing);
      expect(find.textContaining('Chưa xác nhận được hợp đồng'), findsWidgets);
      // Đọc lại lỗi cũng khoá luôn chip trên thẻ.
      expect(find.text(webNodeChip), findsNothing);
    },
  );

  testWidgets(
    'nút "Xem Node" chỉ hiện khi Zone đã có Node được chấm (lấy từ máy chủ); đã có thì xem được ở mọi giai đoạn',
    (tester) async {
      // Chưa chấm Node nào: không có nút.
      placedNodes = 0;
      quote = 'SentToOwner';
      await pump(tester);
      expect(find.textContaining('Xem Node'), findsNothing);

      // Đã chấm 3 Node: hiện kèm số lượng, kể cả khi chờ cọc.
      placedNodes = 3;
      await pump(tester);
      expect(find.text('Xem Node (3)'), findsOneWidget);
      expect(find.text(webNodeChip), findsNothing); // chưa cọc: chưa gán Node

      quote = 'SignedByOwner';
      depStatus = 'Installing';
      await pump(tester);
      expect(find.text('Xem Node (3)'), findsOneWidget);
      expect(find.text(webNodeChip), findsOneWidget);

      depStatus = 'Completed';
      await pump(tester);
      expect(find.text('Xem Node (3)'), findsOneWidget);
      expect(find.text(webNodeChip), findsNothing);
    },
  );
  testWidgets(
    'đã cọc + Đã khảo sát: Mobile không còn nút Bắt đầu lắp đặt và không gọi confirm/installation/start',
    (tester) async {
      quote = 'SignedByOwner';
      depStatus = 'Surveyed';
      srStatus = 'InProgress';
      await pump(tester);
      expect(find.text('Bắt đầu lắp đặt'), findsNothing);
      expect(find.text(webNodeChip), findsOneWidget);
      final paths = posts().map((c) => c.url.path).toList();
      expect(paths.where((p) => p.endsWith('/confirm')), isEmpty);
      expect(paths.where((p) => p.endsWith('/installation/start')), isEmpty);
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

/// Mở khung "Đề xuất thiết bị & Dự toán từ khách hàng" rồi bấm "Đưa vào HĐ" cho từng dòng đề xuất.
Future<void> _addProposals(WidgetTester tester) async {
  final title = find.text('Đề xuất thiết bị & Dự toán từ khách hàng');
  await tester.ensureVisible(title);
  await tester.tap(title);
  await tester.pumpAndSettle();
  final count = find.text('Đưa vào HĐ').evaluate().length;
  for (var i = 0; i < count; i++) {
    final btn = find.text('Đưa vào HĐ').at(i);
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    await tester.pumpAndSettle();
  }
  // Snackbar xác nhận tự ẩn sau 2 giây.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}
