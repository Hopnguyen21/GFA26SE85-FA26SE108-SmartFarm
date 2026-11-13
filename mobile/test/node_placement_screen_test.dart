import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/services/gps_service.dart';
import 'package:smartfarm_mobile/features/support/node_placement_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Gps implements GpsProvider {
  GpsFix? fix;
  GpsException? error;
  @override
  Future<GpsFix> current() async {
    if (error != null) throw error!;
    return fix!;
  }
}

ZoneModel _zone() => ZoneModel(
  zoneId: 'z1',
  farmId: 'f1',
  name: 'Zone 1',
  currentCrop: '',
  currentStage: '',
  areaM2: 1000,
  currentSoilMoisture: 0,
  currentTemp: 0,
  currentHumidity: 0,
  currentLux: 0,
  polygon: const [
    LatLng(10.0, 100.0),
    LatLng(10.0, 100.001),
    LatLng(10.001, 100.001),
    LatLng(10.001, 100.0),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];
  var quote = 'SignedByOwner';
  var zoneHttp = 200;
  var mqttOn = true;
  final sensorPuts = <http.Request>[];
  var provisionHttp = 200;
  final provisionPosts = <http.Request>[];
  var quoteHttp = 200; // 200 | 204 (chưa có báo giá) | 500
  var srStatus = 'InProgress';
  var srHttp = 200;
  var srFarm = 'f1';
  var srZone = 'z1';
  var srDep = 'dep1';
  var depFarm = 'f1';
  var depZone = 'z1';
  var depStatus = 'Installing';
  var devicesHttp = 200;
  var devices = <Map<String, dynamic>>[];
  var gateways = <Map<String, dynamic>>[];
  var locations = <Map<String, dynamic>>[];
  var persistSave = true; // máy chủ có thật sự lưu vị trí không
  Completer<void>? putGate;

  Map<String, dynamic> dev(String id, {bool? test}) => {
    'deviceId': id,
    'gatewayId': 'g1',
    'deploymentRequestId': 'dep1',
    'zoneId': 'z1',
    'hardwareAddress': 'HW-$id',
    'deviceType': 'SensorNode',
    'status': 'Assigned',
    'latestConnectionTest': ?(test == null
        ? null
        : {'succeeded': test, 'observedAtUtc': '2026-11-12T08:00:00Z'}),
  };

  Future<http.Response> handler(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (r.method == 'POST' && p.endsWith('/devices/provision')) {
      provisionPosts.add(r);
      if (provisionHttp != 200) {
        return _json({
          'detail': 'Deployment Request must be Installing.',
        }, provisionHttp);
      }
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      final n = (b['nodes'] as List).first as Map<String, dynamic>;
      final created = {
        ...dev('new'),
        'deviceId': 'new',
        'hardwareAddress': n['hardwareAddress'],
        'deviceType': n['deviceType'],
      };
      devices = [...devices, created];
      return _json({
        'totalProvisioned': 1,
        'devices': [created],
      });
    }
    if (r.method == 'GET' && p.endsWith('/gateways/g1/mqtt-status')) {
      return _json({'gatewayId': 'g1', 'mqttConnected': mqttOn});
    }
    if (r.method == 'GET' && p.endsWith('/spare-parts')) {
      return _json([
        {
          'code': 'SHT30',
          'name': 'Cảm biến SHT30',
          'category': 'SENSOR',
          'quantityInStock': 5,
        },
        {
          'code': 'CAP',
          'name': 'Dây cáp',
          'category': 'CABLE',
          'quantityInStock': 9,
        },
      ]);
    }
    if (r.method == 'PUT' && p.endsWith('/devices/a/sensors')) {
      sensorPuts.add(r);
      return http.Response('', 204);
    }
    if (r.method == 'GET' && p == '/api/v1/zones/z1') {
      if (zoneHttp != 200) return _json({'detail': 'boom'}, zoneHttp);
      return _json({
        'zoneId': 'z1',
        'farmId': 'f1',
        'fieldId': 'fl1',
        'name': 'Nhà màng 001',
        'areaM2': 930,
        'boundaryGeoJson': {
          'type': 'Polygon',
          'coordinates': [
            [
              [100.0, 10.0],
              [100.001, 10.0],
              [100.001, 10.001],
              [100.0, 10.001],
              [100.0, 10.0],
            ],
          ],
        },
      });
    }
    if (r.method == 'GET' && p.endsWith('/service-requests/s1')) {
      if (srHttp != 200) return _json({'detail': 'boom'}, srHttp);
      return _json({
        'id': 's1',
        'status': srStatus,
        'farmId': srFarm,
        'zoneId': srZone,
        'deploymentRequestId': srDep,
        'history': <Object>[],
      });
    }
    if (p.endsWith('/service-requests/s1/quotation')) {
      if (quoteHttp == 204) return http.Response('', 204);
      if (quoteHttp != 200) return _json({'detail': 'boom'}, quoteHttp);
      return _json({
        'id': 'q1',
        'status': quote,
        'totalAmount': 100,
        'deposit30Percent': 30,
        'remaining70Percent': 70,
        'items': [
          {
            'code': 'GW',
            'name': 'Gateway',
            'category': 'GATEWAY',
            'unit': 'Trạm',
            'quantity': 1,
            'unitPrice': 1,
            'vatPercent': 8,
            'totalAmount': 1,
          },
          {
            'code': 'S',
            'name': 'Cảm biến',
            'category': 'SENSOR',
            'unit': 'Cái',
            'quantity': 2,
            'unitPrice': 1,
            'vatPercent': 8,
            'totalAmount': 2,
          },
          {
            'code': 'CAB',
            'name': 'Dây cáp',
            'category': 'CABLE',
            'unit': 'm',
            'quantity': 50,
            'unitPrice': 1,
            'vatPercent': 8,
            'totalAmount': 50,
          },
        ],
      });
    }
    if (r.method == 'GET' && p.endsWith('/deployment-requests/dep1')) {
      return _json({
        'requestId': 'dep1',
        'farmId': depFarm,
        'zoneId': depZone,
        'status': depStatus,
        'requiredParameters': [],
        'planItems': [],
        'surveys': [],
        'decisionHistory': [],
      });
    }
    if (p.endsWith('/farms/f1/devices')) {
      return devicesHttp == 200
          ? _json(devices)
          : _json({'detail': 'boom'}, 500);
    }
    if (p.endsWith('/farms/f1/gateways')) return _json(gateways);
    if (r.method == 'GET' && p.endsWith('/devices/map-locations')) {
      return _json(locations);
    }
    if (r.method == 'PUT' && p.endsWith('/devices/bulk-locations')) {
      if (putGate != null) await putGate!.future;
      if (persistSave) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        for (final n in body['nodes'] as List) {
          locations = [
            ...locations.where((l) => l['deviceId'] != n['deviceId']),
            {
              'deviceId': n['deviceId'],
              'latitude': n['latitude'],
              'longitude': n['longitude'],
            },
          ];
        }
      }
      return http.Response('', 204);
    }
    if (r.method == 'POST' && p.endsWith('/connection-tests')) {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      devices = [
        for (final d in devices)
          if (d['deviceId'] == b['deviceId'])
            {
              ...d,
              'latestConnectionTest': {
                'succeeded': b['succeeded'],
                'observedAtUtc': b['observedAtUtc'],
              },
            }
          else
            d,
      ];
      return _json({
        'succeeded': b['succeeded'],
        'observedAtUtc': b['observedAtUtc'],
      });
    }
    if (r.method == 'POST' && p.endsWith('/dep1/complete')) {
      depStatus = 'Completed';
      return _json({
        'requestId': 'dep1',
        'farmId': 'f1',
        'zoneId': 'z1',
        'status': 'Completed',
        'requiredParameters': [],
        'planItems': [],
        'surveys': [],
        'decisionHistory': [],
      });
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
    quote = 'SignedByOwner';
    quoteHttp = 200;
    zoneHttp = 200;
    mqttOn = true;
    sensorPuts.clear();
    provisionHttp = 200;
    provisionPosts.clear();
    srStatus = 'InProgress';
    srHttp = 200;
    srFarm = 'f1';
    srZone = 'z1';
    srDep = 'dep1';
    depFarm = 'f1';
    depZone = 'z1';
    depStatus = 'Installing';
    devicesHttp = 200;
    devices = [dev('a'), dev('b')];
    gateways = [
      {
        'gatewayId': 'g1',
        'deploymentRequestId': 'dep1',
        'macAddress': 'AA',
        'gatewaySerial': 'GW-1',
        'status': 'Online',
      },
    ];
    locations = [];
    persistSave = true;
    putGate = null;
  });

  final gps = _Gps();

  Future<void> pump(
    WidgetTester tester, {
    bool noZone = false,
    double width = 400,
  }) async {
    await tester.pumpWidget(const SizedBox()); // bỏ State cũ để tải lại dữ liệu
    tester.view.physicalSize = Size(width, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: NodePlacementScreen(
            serviceRequestId: 's1',
            farmId: 'f1',
            zoneId: 'z1',
            deploymentRequestId: 'dep1',
            zone: noZone ? null : _zone(),
            gps: gps,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }, () => MockClient(handler));
  }

  /// Chạy phần tương tác trong cùng vùng client giả.
  Future<void> act(WidgetTester tester, Future<void> Function() body) =>
      http.runWithClient(body, () => MockClient(handler));

  List<http.Request> puts() => calls.where((c) => c.method == 'PUT').toList();
  testWidgets('chưa ký/cọc theo backend: chặn màn Gắn Node', (tester) async {
    quote = 'SentToOwner';
    await pump(tester);
    expect(
      find.textContaining('Chờ Owner ký hợp đồng và thanh toán cọc 30%'),
      findsOneWidget,
    );
    expect(find.text('Cập nhật vị trí'), findsNothing);
  });

  testWidgets(
    'lỗi tải thiết bị: báo lỗi + thử lại, không coi là danh sách trống',
    (tester) async {
      devicesHttp = 500;
      await pump(tester);
      expect(
        find.textContaining('Chưa có thiết bị nào được cấp phát'),
        findsNothing,
      );
      expect(find.text('Thử lại'), findsOneWidget);
      devicesHttp = 200;
      await act(tester, () async {
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Cập nhật vị trí'), findsOneWidget);
    },
  );

  testWidgets(
    'hiện thiết bị từ máy chủ; hợp đồng đối chiếu Gateway/Node, vật tư không thành Node',
    (tester) async {
      await pump(tester);
      expect(find.textContaining('HW-a'), findsWidgets);
      expect(find.textContaining('HW-b'), findsWidgets);
      expect(find.text('Gateway: hợp đồng 1, đã cấp phát 1'), findsOneWidget);
      expect(
        find.text('Node cảm biến: hợp đồng 2, đã cấp phát 2'),
        findsOneWidget,
      );
      // Vật tư không thành thiết bị chấm: chỉ hiện ở khối chỉ xem, không có thẻ Node/Cấp phát cho nó.
      expect(find.text('Node · Dây cáp'), findsNothing);
      expect(find.text('Cấp phát thiết bị & chấm'), findsNothing);
      // Gateway chỉ cần có (đã cấp phát) là chấm được Node; không chấm vị trí Gateway và không còn câu giải thích API.
      expect(find.textContaining('Đã cấp phát'), findsWidgets);
      expect(find.textContaining('chưa có API lưu vị trí'), findsNothing);
    },
  );

  testWidgets(
    'chưa cấp phát thiết bị: báo rõ giới hạn, không tạo thiết bị giả',
    (tester) async {
      devices = [];
      await pump(tester);
      expect(
        find.textContaining('Chưa có thiết bị nào được cấp phát'),
        findsWidgets,
      );
      expect(puts(), isEmpty);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
    },
  );

  testWidgets(
    'GPS: lấy vị trí trong Zone, lưu, rồi đọc lại từ máy chủ; chặn bấm lưu đôi',
    (tester) async {
      gps.error = null;
      gps.fix = const GpsFix(
        latitude: 10.0005,
        longitude: 100.0005,
        accuracyM: 5,
      );
      await pump(tester);
      await act(tester, () async {
        await tester.tap(find.text('Cập nhật vị trí'));
        await tester.pumpAndSettle();
      });
      expect(
        find.textContaining('Điểm mới (chưa lưu): 10.000500, 100.000500'),
        findsWidgets,
      );
      expect(find.textContaining('GPS ±5 m'), findsWidgets);

      putGate = Completer<void>();
      await act(tester, () async {
        await tester.tap(find.text('Lưu Sơ đồ GIS & Đồng bộ Backend'));
        await tester.pump();
        // đang lưu: nút bị khoá, bấm lại không gửi thêm
        await tester.tap(
          find.text('Đang lưu sơ đồ GIS...'),
          warnIfMissed: false,
        );
        await tester.pump();
        putGate!.complete();
        await tester.pumpAndSettle();
      });
      expect(puts(), hasLength(1));
      final body = jsonDecode(puts().single.body) as Map<String, dynamic>;
      expect(body['serviceRequestId'], 's1');
      expect(body['deploymentRequestId'], 'dep1');
      final n = (body['nodes'] as List).single as Map<String, dynamic>;
      expect(n['deviceId'], 'a');
      expect(n['locationSource'], 'MobileGPS');
      // đọc lại sau khi lưu
      final lastPut = calls.lastIndexWhere((c) => c.method == 'PUT');
      expect(
        calls
            .skip(lastPut + 1)
            .any((c) => c.url.path.endsWith('/map-locations')),
        isTrue,
      );
      expect(find.text('Máy chủ: 10.000500, 100.000500'), findsWidgets);
    },
  );

  testWidgets('máy chủ không lưu vị trí: báo chưa lưu, không báo thành công', (
    tester,
  ) async {
    persistSave = false;
    gps.error = null;
    gps.fix = const GpsFix(
      latitude: 10.0005,
      longitude: 100.0005,
      accuracyM: 5,
    );
    await pump(tester);
    await act(tester, () async {
      await tester.tap(find.text('Cập nhật vị trí'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu Sơ đồ GIS & Đồng bộ Backend'));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('chưa trả đúng vị trí'), findsOneWidget);
    expect(find.textContaining('Đã lưu và đọc lại'), findsNothing);
  });

  testWidgets('GPS ngoài ranh giới Zone: chặn', (tester) async {
    gps.error = null;
    gps.fix = const GpsFix(latitude: 10.5, longitude: 100.5, accuracyM: 5);
    await pump(tester);
    await act(tester, () async {
      await tester.tap(find.text('Cập nhật vị trí'));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('nằm ngoài ranh giới Zone'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\(\d+ điểm chưa lưu\)')), findsNothing);
  });

  testWidgets('GPS sai số quá lớn: chặn; sai số vừa: hỏi xác nhận', (
    tester,
  ) async {
    gps.error = null;
    gps.fix = const GpsFix(
      latitude: 10.0005,
      longitude: 100.0005,
      accuracyM: 90,
    );
    await pump(tester);
    await act(tester, () async {
      await tester.tap(find.text('Cập nhật vị trí'));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('GPS quá kém'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\(\d+ điểm chưa lưu\)')), findsNothing);

    gps.fix = const GpsFix(
      latitude: 10.0005,
      longitude: 100.0005,
      accuracyM: 30,
    );
    await act(tester, () async {
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('Cập nhật vị trí'));
      // hộp thoại mở khi nút đang quay (đang lấy GPS) nên không dùng pumpAndSettle
      await tester.pump(const Duration(milliseconds: 500));
    });
    expect(find.text('Độ chính xác GPS thấp'), findsOneWidget);
    await tester.tap(find.text('Đo lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'\(\d+ điểm chưa lưu\)')), findsNothing);
    await act(tester, () async {
      await tester.tap(find.text('Cập nhật vị trí'));
      await tester.pump(const Duration(milliseconds: 500));
    });
    await tester.tap(find.text('Vẫn dùng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('(1 điểm chưa lưu)'), findsOneWidget);
  });

  testWidgets(
    'thiếu quyền / tắt GPS: hiện đúng thông báo, không đặt điểm giả',
    (tester) async {
      gps.error = const GpsException(
        GpsFailure.deniedForever,
        'Quyền vị trí bị từ chối vĩnh viễn.',
      );
      await pump(tester);
      await act(tester, () async {
        await tester.tap(find.text('Cập nhật vị trí'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Quyền vị trí bị từ chối vĩnh viễn.'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\(\d+ điểm chưa lưu\)')),
        findsNothing,
      );
      gps.error = null;
    },
  );

  testWidgets('chạm bản đồ: trong Zone đặt được, ngoài Zone bị chặn', (
    tester,
  ) async {
    await pump(tester);
    final map = find.byType(FlutterMap);
    expect(map, findsOneWidget);
    final c = tester.getCenter(map);
    await act(tester, () async {
      await tester.tapAt(c);
      // flutter_map chờ hết thời gian nhận diện chạm đôi mới báo onTap
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('(1 điểm chưa lưu)'), findsOneWidget);

    await act(tester, () async {
      await tester.tapAt(
        c + const Offset(145, -80),
      ); // xa hơn ranh giới Zone (tránh nút zoom ở góc dưới phải)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    });
    expect(find.textContaining('nằm ngoài ranh giới Zone'), findsOneWidget);
    expect(
      find.textContaining('(1 điểm chưa lưu)'),
      findsOneWidget,
    ); // điểm cũ giữ nguyên
  });

  testWidgets(
    'hoàn tất bị chặn tới khi đủ vị trí và kiểm tra kết nối; rồi gọi complete',
    (tester) async {
      gps.error = null;
      await pump(tester);
      expect(
        find.textContaining('HW-a: chưa có vị trí trên máy chủ.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('HW-a: chưa ghi kiểm tra kết nối.'),
        findsOneWidget,
      );
      final complete = find.widgetWithText(FilledButton, 'Hoàn tất lắp đặt');
      expect(tester.widget<FilledButton>(complete).onPressed, isNull);

      // Lưu vị trí cho cả hai (qua máy chủ), rồi ghi kiểm tra kết nối từng thiết bị.
      locations = [
        {'deviceId': 'a', 'latitude': 10.0004, 'longitude': 100.0004},
        {'deviceId': 'b', 'latitude': 10.0006, 'longitude': 100.0006},
      ];
      await act(tester, () async {
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
      });
      expect(find.textContaining('chưa có vị trí trên máy chủ'), findsNothing);
      expect(
        tester.widget<FilledButton>(complete).onPressed,
        isNull,
      ); // còn thiếu kiểm tra

      for (var i = 0; i < 2; i++) {
        await act(tester, () async {
          await tester.tap(find.text('Ghi kiểm tra kết nối').at(i));
          await tester.pumpAndSettle();
          // phải chọn kết quả rõ ràng
          await tester.tap(find.text('Ghi nhận'));
          await tester.pumpAndSettle();
          expect(
            find.text('Hãy chọn kết quả: đạt hoặc không đạt.'),
            findsOneWidget,
          );
          await tester.tap(find.text('Đạt'));
          await tester.tap(find.text('Ghi nhận'));
          await tester.pumpAndSettle();
        });
        // Thiết bị đã có kết quả thì nhãn đổi; tải lại đã xảy ra.
        devices = [for (final d in devices) d];
      }
      expect(
        calls.where(
          (c) => c.method == 'POST' && c.url.path.endsWith('/connection-tests'),
        ),
        hasLength(2),
      );
      expect(find.textContaining('(KTV nhập thủ công): đạt'), findsNWidgets(2));
      expect(
        find.textContaining('Heartbeat thực tế: chưa nhận'),
        findsNWidgets(2),
      );
      expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);

      await act(tester, () async {
        await tester.tap(complete);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Hoàn tất').last);
        await tester.pumpAndSettle();
      });
      expect(
        calls.where(
          (c) => c.method == 'POST' && c.url.path.endsWith('/dep1/complete'),
        ),
        hasLength(1),
      );
      // Chỉ báo hoàn tất sau khi đọc lại trạng thái Completed từ backend.
      expect(
        find.textContaining('Đã hoàn tất lắp đặt. Owner thanh toán 70%'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Hoàn tất lắp đặt'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'chưa Installing: nói rõ cần bắt đầu lắp đặt/cấp phát, không cho hoàn tất',
    (tester) async {
      depStatus = 'PlanConfirmed';
      await pump(tester);
      expect(find.text('Cập nhật vị trí'), findsOneWidget);
      expect(find.textContaining('Hợp đồng đã cọc'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Hoàn tất lắp đặt'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  // ───────── Cổng Gắn Node: hợp đồng/cọc do backend xác nhận, độc lập với xác nhận kế hoạch/bắt đầu lắp đặt ─────────
  for (final dep in ['Submitted', 'Accepted', 'Surveyed', 'PlanConfirmed']) {
    testWidgets(
      'đã cọc + triển khai $dep: mở được Gắn Node, không cần xác nhận kế hoạch',
      (tester) async {
        depStatus = dep;
        await pump(tester);
        expect(find.text('Cập nhật vị trí'), findsOneWidget);
        expect(find.byType(FlutterMap), findsOneWidget);
        // Không tự đẩy trạng thái triển khai nào: không có POST nào khi mở màn.
        expect(calls.where((c) => c.method == 'POST'), isEmpty);
        // Hoàn tất vẫn khoá vì chưa Đang lắp đặt (backend kiểm tra).
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Hoàn tất lắp đặt'),
              )
              .onPressed,
          isNull,
        );
      },
    );
  }

  for (final s in ['SentToOwner', 'Draft']) {
    testWidgets('báo giá $s (chưa cọc): không mở được Gắn Node', (
      tester,
    ) async {
      quote = s;
      await pump(tester);
      expect(find.text('Cập nhật vị trí'), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);
    });
  }

  testWidgets('chưa có báo giá (204/404): không mở được', (tester) async {
    quoteHttp = 204;
    await pump(tester);
    expect(find.text('Cập nhật vị trí'), findsNothing);
    expect(find.textContaining('Chờ Owner ký hợp đồng'), findsOneWidget);
  });

  testWidgets('đọc báo giá lỗi (500): khoá, báo chưa xác nhận được', (
    tester,
  ) async {
    quoteHttp = 500;
    await pump(tester);
    expect(find.text('Cập nhật vị trí'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('đọc phiếu lỗi (500): khoá', (tester) async {
    srHttp = 500;
    await pump(tester);
    expect(find.text('Cập nhật vị trí'), findsNothing);
  });

  testWidgets(
    'đã cọc nhưng công việc kết thúc: vẫn khoá (phiếu đóng, báo giá nghiệm thu, triển khai hoàn tất/hủy/bảo trì)',
    (tester) async {
      Future<void> expectLocked(String why) async {
        await pump(tester);
        expect(find.text('Cập nhật vị trí'), findsNothing, reason: why);
        expect(find.byType(FlutterMap), findsNothing, reason: why);
      }

      srStatus = 'Closed';
      await expectLocked('phiếu đã đóng');
      srStatus = 'InProgress';
      quote = 'Completed';
      await expectLocked('báo giá đã nghiệm thu');
      quote = 'SignedByOwner';
      for (final d in ['Completed', 'Cancelled', 'MaintenanceRequired']) {
        depStatus = d;
        await expectLocked('triển khai $d');
      }
    },
  );

  testWidgets('liên kết sai Farm/Zone/mã triển khai: bị từ chối dù đã cọc', (
    tester,
  ) async {
    Future<void> expectLocked(String why) async {
      await pump(tester);
      expect(find.text('Cập nhật vị trí'), findsNothing, reason: why);
      expect(find.textContaining('sai Farm/Zone'), findsOneWidget, reason: why);
    }

    depZone = 'z-other';
    await expectLocked('triển khai khác Zone');
    depZone = 'z1';
    depFarm = 'f-other';
    await expectLocked('triển khai khác Farm');
    depFarm = 'f1';
    srDep = '00000000-0000-0000-0000-000000000000';
    await expectLocked('phiếu trỏ mã triển khai rỗng');
    srDep = 'dep1';
    srZone = 'z-other'; // phiếu thuộc Zone khác với Zone màn đang mở
    await expectLocked('phiếu khác Zone màn đang mở');
  });

  testWidgets(
    'dữ liệu cọc cũ không giữ lại: tải lại lỗi thì khoá, tải lại được thì mở lại',
    (tester) async {
      await pump(tester);
      expect(find.text('Cập nhật vị trí'), findsOneWidget);
      quoteHttp = 500; // backend/ mạng lỗi khi làm mới
      await act(tester, () async {
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
      });
      expect(find.text('Cập nhật vị trí'), findsNothing);
      expect(find.byType(FlutterMap), findsNothing);
      quoteHttp = 200;
      await act(tester, () async {
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle();
      });
      expect(find.text('Cập nhật vị trí'), findsOneWidget);
    },
  );

  testWidgets(
    'màn rộng: danh sách thiết bị bên trái, bản đồ có ranh giới Zone bên phải; không còn khối "Đối chiếu hợp đồng"',
    (tester) async {
      await pump(tester, width: 1200);
      final list = tester.getTopLeft(find.textContaining('HW-a').first);
      final map = tester.getTopLeft(find.byType(FlutterMap));
      expect(list.dx < map.dx, isTrue, reason: 'danh sách nằm bên trái bản đồ');
      expect(find.text('Đối chiếu hợp đồng'), findsNothing);
      expect(
        find.text('Mở chi tiết triển khai (bắt đầu lắp đặt, cấp phát)'),
        findsNothing,
      );
      expect(find.byType(PolygonLayer), findsOneWidget);
      expect(find.textContaining('Zone 1'), findsWidgets);
    },
  );

  testWidgets(
    'Zone không có trong danh sách của KTV: tự tải ranh giới Zone từ backend và vẽ lên bản đồ',
    (tester) async {
      await pump(tester, noZone: true, width: 1200);
      expect(
        calls.any((c) => c.method == 'GET' && c.url.path == '/api/v1/zones/z1'),
        isTrue,
      );
      expect(find.byType(PolygonLayer), findsOneWidget);
      expect(find.text('Nhà màng 001 · 930 m²'), findsOneWidget);
      expect(find.text('Gắn Node · Nhà màng 001'), findsOneWidget);
    },
  );

  testWidgets(
    'không tải được Zone: vẫn gắn Node được, bản đồ báo Zone chưa có ranh giới',
    (tester) async {
      zoneHttp = 500;
      await pump(tester, noZone: true, width: 1200);
      expect(find.text('Zone chưa có ranh giới GIS'), findsOneWidget);
      expect(find.byType(PolygonLayer), findsNothing);
      expect(find.text('Cập nhật vị trí'), findsOneWidget);
    },
  );

  testWidgets(
    'danh sách Node lấy từ hợp đồng: thiết bị đã cấp phát gắn vào đúng dòng, dòng thiếu hiện "Chưa cấp phát" và không chọn được',
    (tester) async {
      // Hợp đồng mock: 1 Gateway, 2 Node cảm biến (devices mock: a, b là cảm biến).
      devices = [dev('a')]; // chỉ cấp phát 1 trong 2 cảm biến của hợp đồng
      await pump(tester, width: 1200);
      expect(
        find.textContaining('Cảm biến (1/2)'),
        findsOneWidget,
      ); // gắn vào chỗ 1/2
      expect(find.textContaining('HW-a'), findsWidgets);
      expect(
        find.text('Node cảm biến · Cảm biến (2/2)'),
        findsOneWidget,
      ); // chỗ 2/2 chưa có thiết bị
      expect(
        find.text(
          'Chưa cấp phát thiết bị cho dòng hợp đồng này nên chưa chấm vị trí được.',
        ),
        findsOneWidget,
      );
      // Chỉ thiết bị thật mới có nút kiểm tra kết nối / chọn.
      expect(find.text('Ghi kiểm tra kết nối'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'\(\d+ điểm chưa lưu\)')),
        findsNothing,
      );
      // Gateway của hợp đồng hiển thị theo dòng hợp đồng.
      expect(find.textContaining('GW-1'), findsWidgets);
    },
  );

  testWidgets(
    'dòng hợp đồng chưa có thiết bị: cấp phát thiết bị thật rồi chọn để chấm (qua API cấp phát, không tạo giả)',
    (tester) async {
      devices = [dev('a')]; // hợp đồng 2 cảm biến, mới có 1
      await pump(tester, width: 1200);
      expect(find.text('Cấp phát thiết bị & chấm'), findsOneWidget);
      await act(tester, () async {
        await tester.tap(find.text('Cấp phát thiết bị & chấm'));
        await tester.pumpAndSettle();
        // địa chỉ phần cứng bắt buộc
        await tester.tap(find.text('Cấp phát'));
        await tester.pumpAndSettle();
        expect(find.textContaining('3–64 ký tự'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'sensor-real-02');
        await tester.tap(find.text('Cấp phát'));
        await tester.pumpAndSettle();
      });
      expect(provisionPosts, hasLength(1));
      final body =
          jsonDecode(provisionPosts.single.body) as Map<String, dynamic>;
      expect(body['deploymentRequestId'], 'dep1');
      expect(body['gatewayId'], 'g1');
      expect(body['farmId'], 'f1');
      final node = (body['nodes'] as List).single as Map<String, dynamic>;
      expect(node['hardwareAddress'], 'sensor-real-02');
      expect(node['deviceType'], 'SensorNode');
      // Sau khi cấp phát: không còn chỗ trống, thiết bị mới hiện ra để chấm.
      expect(find.text('Cấp phát thiết bị & chấm'), findsNothing);
      expect(find.textContaining('sensor-real-02'), findsWidgets);
      // Không tự đẩy trạng thái triển khai nào.
      expect(
        calls.where(
          (c) =>
              c.method == 'POST' && !c.url.path.endsWith('/devices/provision'),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'cấp phát bị backend từ chối: hiện đúng lỗi, danh sách giữ nguyên',
    (tester) async {
      devices = [dev('a')];
      provisionHttp = 409;
      await pump(tester, width: 1200);
      await act(tester, () async {
        await tester.tap(find.text('Cấp phát thiết bị & chấm'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'SENSOR-REAL-02');
        await tester.tap(find.text('Cấp phát'));
        await tester.pumpAndSettle();
      });
      expect(find.textContaining('Không cấp phát được'), findsOneWidget);
      expect(find.text('Cấp phát thiết bị & chấm'), findsOneWidget);
    },
  );

  testWidgets(
    'chưa có Gateway: không gọi cấp phát, báo cần cấp phát Gateway trước',
    (tester) async {
      devices = [dev('a')];
      gateways = [];
      await pump(tester, width: 1200);
      await act(tester, () async {
        await tester.tap(find.text('Cấp phát thiết bị & chấm'));
        await tester.pumpAndSettle();
      });
      expect(provisionPosts, isEmpty);
      expect(find.textContaining('Cần cấp phát Gateway trước'), findsOneWidget);
    },
  );

  testWidgets(
    'hiện đủ hạng mục hợp đồng: vật tư/thi công liệt kê để chỉ xem, không chấm được',
    (tester) async {
      await pump(tester, width: 1200);
      expect(find.text('Vật tư & thi công theo hợp đồng'), findsOneWidget);
      expect(find.text('Dây cáp'), findsOneWidget);
      expect(find.text('50 m'), findsOneWidget);
      expect(find.textContaining('không chấm vị trí'), findsOneWidget);
    },
  );

  testWidgets(
    'bản đồ căn đúng vị trí Zone: tâm camera trong ranh giới, toàn bộ ranh giới nằm trong khung nhìn',
    (tester) async {
      await pump(tester, width: 1200);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      final cam = map.mapController!.camera;
      // Ranh giới Zone mock: lat 10.0–10.001, lng 100.0–100.001.
      expect(cam.center.latitude, closeTo(10.0005, 0.0003));
      expect(cam.center.longitude, closeTo(100.0005, 0.0003));
      final b = cam.visibleBounds;
      for (final p in _zone().polygon!) {
        expect(
          b.contains(p),
          isTrue,
          reason: 'điểm ranh giới $p phải nằm trong khung nhìn',
        );
      }
      expect(cam.zoom, greaterThan(15));
    },
  );

  // ───────── Giao diện/thao tác theo trang chấm Node của web ─────────
  testWidgets(
    'tiêu đề, danh sách chờ chấm, Gateway ngoài Zone, khung hợp đồng và chân trang như web',
    (tester) async {
      await pump(tester, width: 1200);
      expect(find.text('LẮP ĐẶT MỚI & CHẤM VỊ TRÍ GIS'), findsOneWidget);
      expect(find.text('Request #s1'), findsOneWidget);
      expect(
        find.textContaining('Thực địa Chấm Node Phân khu (Zone): Zone 1'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          RegExp(r'thiết bị chờ chấm \(', caseSensitive: false),
        ),
        findsOneWidget,
      );
      expect(find.text('Gateway hạ tầng ngoài Zone'), findsOneWidget);
      expect(find.text('Thiết bị trong hợp đồng'), findsOneWidget);
      expect(find.text('Mô-đun nút (2)'), findsOneWidget);
      expect(find.text('Vị trí GIS Map của Zone này'), findsOneWidget);
      expect(find.text('Lưu Sơ đồ GIS & Đồng bộ Backend'), findsOneWidget);
      expect(
        find.textContaining('Tổng số Node định vị trong Phân khu'),
        findsOneWidget,
      );
      expect(find.text('Căn Zoom'), findsOneWidget);
      expect(find.text('Vệ tinh'), findsOneWidget);
    },
  );

  testWidgets(
    'Gateway ngoài Zone: hiện trạng thái MQTT thật từ backend; chưa online thì CHƯA KẾT NỐI',
    (tester) async {
      await pump(tester, width: 1200);
      expect(find.text('MQTT ONLINE'), findsOneWidget);
      mqttOn = false;
      await pump(tester, width: 1200);
      expect(find.text('CHƯA KẾT NỐI'), findsOneWidget);
      expect(find.text('Chọn Gateway & kết nối'), findsOneWidget);
    },
  );

  testWidgets('chọn loại bản đồ: đổi nguồn tile OSM / Đường phố / Vệ tinh', (
    tester,
  ) async {
    await pump(tester, width: 1200);
    final layer = find.byType(TileLayer);
    String url() => tester.widget<TileLayer>(layer).urlTemplate!;
    // Mặc định Vệ tinh (Google, chạy được trên máy không vào được openstreetmap.org).
    expect(url(), contains('lyrs=y'));
    await tester.tap(find.text('Đường phố'));
    await tester.pumpAndSettle();
    expect(url(), contains('lyrs=m'));
    await tester.tap(find.text('OSM'));
    await tester.pumpAndSettle();
    expect(url(), contains('openstreetmap'));
    // OSM có ảnh dự phòng khi không phân giải được tên miền.
    expect(
      tester.widget<TileLayer>(layer).fallbackUrl,
      contains('mt1.google.com'),
    );
  });

  testWidgets(
    'chấm xong thiết bị tự chọn thiết bị chờ chấm kế tiếp; Node chuyển sang "Node đã định vị"; Gỡ đưa về chờ chấm',
    (tester) async {
      await pump(tester, width: 1200);
      expect(
        find.textContaining(
          RegExp(r'node đã định vị \(0\)', caseSensitive: false),
        ),
        findsWidgets,
      );
      final c = tester.getCenter(find.byType(FlutterMap));
      await act(tester, () async {
        await tester.tapAt(c);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      });
      expect(
        find.textContaining(
          RegExp(r'node đã định vị \(1\)', caseSensitive: false),
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(
          RegExp(r'thiết bị chờ chấm \(', caseSensitive: false),
        ),
        findsOneWidget,
      );
      // Gỡ điểm chưa lưu
      await tester.tap(find.byTooltip('Gỡ Node này khỏi sơ đồ để chấm lại'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          RegExp(r'node đã định vị \(0\)', caseSensitive: false),
        ),
        findsWidgets,
      );
      expect(
        find.textContaining(RegExp(r'\(\d+ điểm chưa lưu\)')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'nhập tọa độ thủ công: trong Zone đặt được, ngoài Zone bị chặn, tọa độ sai bị từ chối',
    (tester) async {
      await pump(tester, width: 1200);
      Future<void> enter(String lat, String lng) async {
        await tester.tap(find.text('Nhập tọa độ thủ công'));
        await tester.pumpAndSettle();
        final f = find.byType(TextField);
        await tester.enterText(f.at(0), lat);
        await tester.enterText(f.at(1), lng);
        await tester.tap(find.text('Đặt Node tại tọa độ'));
        await tester.pumpAndSettle();
      }

      await enter('95', '100.0005'); // vĩ độ không hợp lệ
      expect(find.textContaining('vĩ độ từ -90 đến 90'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Hủy'),
        ),
      );
      await tester.pumpAndSettle();
      await enter('10.5', '100.5'); // ngoài Zone
      expect(find.textContaining('nằm ngoài ranh giới Zone'), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(r'node đã định vị \(0\)', caseSensitive: false),
        ),
        findsWidgets,
      );
      await tester.pump(const Duration(seconds: 5));
      await enter('10.0005', '100.0005'); // trong Zone
      expect(
        find.textContaining(
          RegExp(r'node đã định vị \(1\)', caseSensitive: false),
        ),
        findsWidgets,
      );
      expect(find.textContaining('(1 điểm chưa lưu)'), findsOneWidget);
    },
  );

  testWidgets(
    'Cấu hình cảm biến: chọn cảm biến từ kho Technician rồi gán cho Node qua API',
    (tester) async {
      locations = [
        {'deviceId': 'a', 'latitude': 10.0004, 'longitude': 100.0004},
      ];
      await pump(tester, width: 1200);
      await act(tester, () async {
        await tester.tap(find.text('Cấu hình').first);
        await tester.pumpAndSettle();
        expect(find.text('Cảm biến SHT30'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Dây cáp'),
          ),
          findsNothing,
        ); // chỉ cảm biến còn tồn kho
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Lưu cấu hình cảm biến'));
        await tester.pumpAndSettle();
      });
      expect(sensorPuts, hasLength(1));
      final body = jsonDecode(sensorPuts.single.body) as Map<String, dynamic>;
      final s = (body['sensors'] as List).single as Map<String, dynamic>;
      expect(s['sensorType'], 'SHT30');
      expect(s['samplingIntervalSec'], 60);
    },
  );
}
