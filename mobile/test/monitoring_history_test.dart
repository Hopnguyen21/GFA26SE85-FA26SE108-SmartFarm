import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/monitoring/monitoring_history_logic.dart';
import 'package:smartfarm_mobile/features/monitoring/monitoring_history_screen.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> pt(String startUtc, Object? avg) => {
  'bucketStartUtc': startUtc,
  'average': avg,
  'min': 1,
  'max': 2,
  'count': 3,
};

ZoneModel zone({List<Map<String, dynamic>> reqs = const []}) =>
    ZoneModel.fromJson(
      {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
      farmId: 'f1',
      fieldId: 'fl1',
    ).copyWith(appliedRequirements: reqs);

class _P extends FarmProvider {
  final ZoneModel z;
  _P(this.z);
  @override
  ZoneModel get currentZone => z;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('logic thuần', () {
    test(
      'nhãn theo khoảng: giờ cho 24h, ngày+giờ cho 7 ngày, chỉ ngày cho 30 ngày (giờ địa phương)',
      () {
        const iso = '2026-11-24T15:00:00Z';
        final d = DateTime.parse(iso).toLocal();
        String two(int n) => n.toString().padLeft(2, '0');
        expect(
          historyBucketLabel(iso, '24 Giờ'),
          '${two(d.hour)}:${two(d.minute)}',
        );
        expect(
          historyBucketLabel(iso, '7 Ngày'),
          '${two(d.day)}/${two(d.month)} ${two(d.hour)}h',
        );
        expect(
          historyBucketLabel(iso, '30 Ngày'),
          '${two(d.day)}/${two(d.month)}',
        );
        expect(historyBucketLabel(null, '24 Giờ'), '');
        expect(historyBucketLabel('khong-phai-ngay', '7 Ngày'), '');
      },
    );

    test(
      'mốc không có giá trị bị bỏ cả nhãn lẫn giá trị: nhãn luôn cùng chỉ số với điểm',
      () {
        final s = buildHistorySeries([
          pt('2026-11-24T01:00:00Z', 10.04),
          pt('2026-11-24T02:00:00Z', null), // thiếu giá trị
          pt('2026-11-24T03:00:00Z', 30),
        ], '24 Giờ');
        expect(s.values, [10.0, 30.0]);
        expect(s.labels.length, s.values.length);
        expect(
          s.labels[1],
          historyBucketLabel('2026-11-24T03:00:00Z', '24 Giờ'),
        );
      },
    );

    test('mã tham số theo khóa chỉ số', () {
      expect(monitoringParameterCode('SOIL_MOISTURE'), 'SoilMoisture');
      expect(monitoringParameterCode('TEMP'), 'Temperature');
      expect(monitoringParameterCode('PH'), 'Ph');
      expect(monitoringParameterCode('EC'), 'Ec');
    });
  });

  group('màn hình', () {
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
      ApiService.setTokens(
        accessToken: 't',
        refreshToken: 'r',
        email: 'o@b.c',
        role: 'FarmOwner',
      );
    });

    Future<void> pump(WidgetTester tester, ZoneModel z) async {
      tester.view.physicalSize = const Size(700, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = _P(z);
      // FarmProvider tự bật bộ đếm giờ cập nhật: phải hủy trước khi test kết thúc.
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: provider,
          child: const MaterialApp(home: MonitoringHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    String? interval(http.Request r) => r.url.queryParameters['interval'];

    testWidgets(
      'khoảng không có dữ liệu: vẫn đổi lại được khoảng khác (không bị kẹt)',
      (tester) async {
        handler = (r) async {
          if (r.url.path.endsWith('/telemetry/history')) {
            return interval(r) == '1h'
                ? json({
                    'data': [
                      pt('2026-11-24T01:00:00Z', 52.4),
                      pt('2026-11-24T02:00:00Z', 53.0),
                    ],
                  })
                : json({'data': []});
          }
          return json({}, 404);
        };
        await pump(tester, zone());
        expect(find.textContaining('Gần nhất: 53.0'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('range_30 Ngày')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa có dữ liệu lịch sử'), findsOneWidget);
        // Các chip khoảng thời gian vẫn còn → quay lại 24 giờ được.
        await tester.tap(find.byKey(const ValueKey('range_24 Giờ')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Gần nhất: 53.0'), findsOneWidget);
        expect(calls.where((c) => interval(c) == '1d'), hasLength(1));
      },
    );

    testWidgets(
      'đổi chỉ số: không vẽ số của chỉ số trước dưới tiêu đề của chỉ số mới',
      (tester) async {
        handler = (r) async {
          if (r.url.path.endsWith('/telemetry/history')) {
            return r.url.queryParameters['parameterCode'] == 'SoilMoisture'
                ? json({
                    'data': [pt('2026-11-24T01:00:00Z', 52.4)],
                  })
                : json({'data': []}); // pH chưa có dữ liệu
          }
          return json({}, 404);
        };
        await pump(tester, zone());
        expect(find.textContaining('Gần nhất: 52.4%'), findsOneWidget);

        await tester.ensureVisible(find.text('Độ pH')); // hàng chip cuộn ngang
        await tester.pumpAndSettle();
        await tester.tap(find.text('Độ pH'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Gần nhất: 52.4'), findsNothing);
        expect(
          find.textContaining('Chưa có dữ liệu lịch sử (Độ chua (pH))'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ngưỡng lấy từ yêu cầu của giai đoạn; không có thì nói rõ, không dùng số cố định',
      (tester) async {
        handler = (r) async => r.url.path.endsWith('/telemetry/history')
            ? json({
                'data': [pt('2026-11-24T01:00:00Z', 70)],
              })
            : json({}, 404);

        await pump(
          tester,
          zone(
            reqs: [
              {
                'parameterCode': 'SoilMoisture',
                'minValue': 71.0,
                'targetValue': 75.0,
                'maxValue': 79.0,
                'unit': '%',
              },
            ],
          ),
        );
        expect(find.textContaining('Ngưỡng Min (71.0%)'), findsOneWidget);
        expect(find.textContaining('Ngưỡng Max (79.0%)'), findsOneWidget);
        // 60/80 là số cố định cũ: không được xuất hiện.
        expect(find.textContaining('(60.0%)'), findsNothing);

        await pump(tester, zone());
        expect(find.textContaining('Ngưỡng Min'), findsNothing);
        expect(find.textContaining('Chưa có vụ đang canh tác'), findsWidgets);
      },
    );
  });
}
