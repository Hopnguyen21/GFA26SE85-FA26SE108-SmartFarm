import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/irrigation/season_irrigation_calendar_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/season_irrigation_logic.dart';

Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sess(String title, String time, {bool enabled = true}) =>
    {
      'sessionId': 's-$title',
      'title': title,
      'startTime': time,
      'durationSeconds': 300,
      'enabled': enabled,
      'method': 'Nhỏ giọt',
      'waterPerPlantMl': 100,
    };

/// Vụ 6 ngày, hôm nay là ngày 2; ngày 1-3 thuộc "Cây con", 4-6 thuộc "Ra hoa". Ngày [overrideDays] là override.
Map<String, dynamic> _calendar({
  Set<int> overrideDays = const {3},
  bool editable = true,
  String status = 'Current',
  List<String> reasons = const [],
  List<Map<String, dynamic>> extraDays = const [],
}) => {
  'seasonId': 'se1',
  'zoneId': 'z1',
  'seasonName': 'Vụ đông 2026',
  'seasonStatus': 'InProgress',
  'growthProfileId': 'p1',
  'growthProfileName': 'VietGAP Dưa lưới',
  'startDate': '2026-11-09',
  'totalDays': 6,
  'todayDayNumber': 2,
  'timeZone': 'Asia/Ho_Chi_Minh',
  'repeatType': 'DAILY',
  'status': overrideDays.isEmpty ? 'NoOverrides' : status,
  'staleReasons': reasons,
  'hasOverrides': overrideDays.isNotEmpty,
  'overrideDayCount': overrideDays.length,
  'isEditable': editable,
  'updatedAtUtc': overrideDays.isEmpty ? null : '2026-11-11T08:00:00Z',
  'days': [
    for (var n = 1; n <= 6; n++)
      {
        'dayNumber': n,
        'date': '2026-11-${(8 + n).toString().padLeft(2, '0')}',
        'stageId': n <= 3 ? 'st1' : 'st2',
        'stageName': n <= 3 ? 'Cây con' : 'Ra hoa',
        'source': overrideDays.contains(n) ? 'Override' : 'Profile',
        'isOverride': overrideDays.contains(n),
        'outOfRange': false,
        'sessions': [
          overrideDays.contains(n)
              ? _sess('Riêng ngày $n', '11:20')
              : _sess('Mẫu', '06:00'),
        ],
      },
    ...extraDays,
  ],
};

final _zone = ZoneModel.fromJson(
  {'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100},
  farmId: 'f1',
  fieldId: 'fl1',
);

void _route({
  Map<String, dynamic>? calendar,
  List<Map<String, dynamic>>? seasons,
  http.Response Function(http.Request)? onDelete,
  http.Response Function(http.Request)? onPut,
}) {
  handler = (r) async {
    final p = r.url.path;
    if (p == '/api/v1/planting-seasons') {
      return utf8Json(
        seasons ??
            [
              {
                'seasonId': 'se1',
                'name': 'Vụ đông 2026',
                'status': 'InProgress',
              },
            ],
      );
    }
    if (p.endsWith('/irrigation-calendar') ||
        p.contains('/irrigation-calendar/')) {
      if (r.method == 'DELETE')
        return onDelete?.call(r) ?? utf8Json(_calendar(overrideDays: {}));
      if (r.method == 'PUT') return onPut?.call(r) ?? utf8Json(_calendar());
      return utf8Json(calendar ?? _calendar());
    }
    return utf8Json([]);
  };
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: SeasonIrrigationCalendarScreen(zone: _zone)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  group('đọc dữ liệu backend', () {
    test('parse lịch theo ngày: nguồn, giai đoạn, ca, trạng thái', () {
      final c = SeasonIrrigationCalendar.fromJson(
        _calendar(status: 'Stale', reasons: ['StartDateChanged']),
      );
      expect(c.totalDays, 6);
      expect(c.isStale, isTrue);
      expect(c.overrideDayCount, 1);
      expect(c.day(3)!.source, DaySource.override);
      expect(c.day(1)!.source, DaySource.profile);
      expect(c.day(3)!.sessions.single.startTime, '11:20');
      expect(c.stages.map((s) => s.name), ['Cây con', 'Ra hoa']);
      expect(c.today!.dayNumber, 2);
      expect(staleReasonText('StartDateChanged'), contains('Ngày bắt đầu'));
      expect(targetDays(c, c.day(1)!, wholeSeason: false), [1, 2, 3]);
      expect(targetDays(c, c.day(1)!, wholeSeason: true), [1, 2, 3, 4, 5, 6]);
    });

    test(
      'PascalCase và dữ liệu thiếu vẫn không làm hỏng, ngày ngoài vụ tách riêng',
      () {
        final c = SeasonIrrigationCalendar.fromJson({
          'SeasonId': 's',
          'TotalDays': 2,
          'Days': [
            {'DayNumber': 1, 'Source': 'None', 'Sessions': []},
            {
              'DayNumber': 9,
              'Source': 'Override',
              'OutOfRange': true,
              'Sessions': [],
            },
          ],
        });
        expect(c.totalDays, 2);
        expect(c.inRangeDays.single.source, DaySource.none);
        expect(c.outOfRangeDays.single.dayNumber, 9);
      },
    );

    test('nguồn đồng bộ thiết bị được mô tả đúng', () {
      expect(
        syncSourceText({'source': 'SeasonOverride', 'dayNumber': 6}),
        contains('ngày 6'),
      );
      expect(syncSourceText({'source': 'Profile'}), contains('hồ sơ'));
      expect(syncSourceText({'source': 'Crop'}), contains('lịch mẫu của cây'));
    });
  });

  group('màn hình', () {
    Finder dayCell(int n) => find.byKey(ValueKey('calendar_day_$n'));

    testWidgets(
      'tải từ backend theo Zone + vụ; hiển thị tiến trình, hôm nay, lịch tùy chỉnh và lịch mẫu',
      (tester) async {
        _route();
        await _pump(tester);

        expect(
          calls.any(
            (c) =>
                c.url.path ==
                '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar',
          ),
          isTrue,
        );
        expect(find.text('Vụ đông 2026'), findsWidgets);
        expect(find.textContaining('VietGAP Dưa lưới'), findsWidgets);
        expect(
          find.textContaining('Cuốn Lịch Tưới 3 Ca Vụ Mùa (6 Ngày)'),
          findsOneWidget,
        );
        expect(find.textContaining('Hôm nay: Ngày 2/6'), findsOneWidget);
        // Ngày hôm nay (2) đang chọn, chưa tùy chỉnh.
        expect(find.text('Chi tiết Lịch Tưới Ngày 2'), findsOneWidget);
        expect(find.text('HÔM NAY'), findsOneWidget);
        expect(find.text('ĐÃ TÙY BIẾN'), findsNothing);
        expect(
          find.textContaining('Hôm nay (ngày 2) dùng lịch chuẩn VietGAP'),
          findsOneWidget,
        );
        // Chọn ngày 3 (đã tùy chỉnh): có nhãn và giờ riêng 11:20.
        await tester.tap(dayCell(3));
        await tester.pumpAndSettle();
        expect(find.text('Chi tiết Lịch Tưới Ngày 3'), findsOneWidget);
        expect(find.text('ĐÃ TÙY BIẾN'), findsOneWidget);
        expect(find.text('Bỏ tùy biến'), findsOneWidget);
        expect(find.textContaining('11:20'), findsWidgets);
        expect(calls.where((c) => c.method != 'GET'), isEmpty);
      },
    );

    testWidgets('lọc theo giai đoạn và nhảy về hôm nay', (tester) async {
      _route();
      await _pump(tester);
      // 6 ngày: giai đoạn 4 (Nuôi trái & Thu hoạch) gồm ngày 5-6.
      await tester.tap(find.text('Nuôi trái & Thu hoạch'));
      await tester.pumpAndSettle();
      expect(dayCell(1), findsNothing);
      expect(dayCell(5), findsOneWidget);
      expect(find.textContaining('2 / 6 ngày'), findsOneWidget);
      await tester.tap(find.text('Hôm nay (Ngày 2)'));
      await tester.pumpAndSettle();
      expect(dayCell(1), findsOneWidget, reason: 'về lại Tất cả');
      expect(find.text('Chi tiết Lịch Tưới Ngày 2'), findsOneWidget);
    });

    testWidgets(
      'bỏ tùy biến một ngày: xác nhận → DELETE đúng ngày → hiển thị dữ liệu backend trả về',
      (tester) async {
        _route();
        await _pump(tester);
        await tester.tap(dayCell(3));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Bỏ tùy biến'));
        await tester.tap(find.text('Bỏ tùy biến'));
        await tester.pumpAndSettle();
        expect(find.text('Khôi phục Ngày 3 về chuẩn gốc?'), findsOneWidget);
        await tester.tap(find.text('Khôi phục ngày này'));
        await tester.pumpAndSettle();

        final del = calls.singleWhere((c) => c.method == 'DELETE');
        expect(
          del.url.path,
          '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar/days/3',
        );
        expect(
          find.textContaining('Đã khôi phục Ngày 3 về lịch mẫu chuẩn'),
          findsOneWidget,
        );
        expect(find.text('ĐÃ TÙY BIẾN'), findsNothing);
        expect(find.text('Bỏ tùy biến'), findsNothing);
      },
    );

    testWidgets(
      'khôi phục cả mùa vụ gọi DELETE gốc; backend lỗi thì báo lỗi, KHÔNG báo đã khôi phục',
      (tester) async {
        _route(
          onDelete: (_) => utf8Json({
            'message': 'Vụ đã kết thúc nên không thể sửa lịch tưới.',
          }, 409),
        );
        await _pump(tester);
        await tester.tap(find.byTooltip('Khôi phục chuẩn gốc'));
        await tester.pumpAndSettle();
        expect(
          find.text('Khôi phục toàn bộ mùa vụ về chuẩn gốc?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Khôi phục tất cả'));
        await tester.pumpAndSettle();

        final del = calls.singleWhere((c) => c.method == 'DELETE');
        expect(
          del.url.path,
          '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar',
        );
        expect(find.textContaining('Không lưu được'), findsOneWidget);
        expect(find.textContaining('Vụ đã kết thúc'), findsOneWidget);
        expect(find.textContaining('Đã khôi phục toàn bộ'), findsNothing);
      },
    );

    testWidgets(
      'áp dụng cho cả vụ: gửi mọi ngày trong vụ với ca của ngày đang chọn; thành công mới báo',
      (tester) async {
        _route(
          onPut: (_) => utf8Json(_calendar(overrideDays: {1, 2, 3, 4, 5, 6})),
        );
        await _pump(tester);
        await tester.tap(dayCell(3));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Áp dụng cả Vụ (6 ngày)'));
        await tester.tap(find.text('Áp dụng cả Vụ (6 ngày)'));
        await tester.pumpAndSettle();
        expect(find.text('Áp dụng cho cả vụ (6 ngày)?'), findsOneWidget);
        await tester.tap(find.text('Áp dụng cả vụ'));
        await tester.pumpAndSettle();

        final put = calls.singleWhere((c) => c.method == 'PUT');
        expect(
          put.url.path,
          '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar',
        );
        final days =
            (jsonDecode(put.body) as Map<String, dynamic>)['days'] as List;
        expect(days.map((d) => d['dayNumber']), [1, 2, 3, 4, 5, 6]);
        final sessions = (days.first['sessions'] as List)
            .cast<Map<String, dynamic>>();
        expect(sessions.map((x) => x['startTime']), contains('11:20'));
        expect(
          find.textContaining(
            'Đã áp dụng lịch tưới Ngày 3 cho tất cả 6 ngày của mùa vụ',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('lưu lỗi 400: báo lỗi backend, không báo thành công', (
      tester,
    ) async {
      _route(
        onPut: (_) =>
            utf8Json({'message': 'Hai ca tưới không được trùng giờ'}, 400),
      );
      await _pump(tester);
      await tester.tap(dayCell(3));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Áp dụng cả Giai đoạn này'));
      await tester.tap(find.text('Áp dụng cả Giai đoạn này'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng ngay'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Không lưu được: Hai ca tưới không được trùng giờ'),
        findsOneWidget,
      );
      expect(find.textContaining('Đã sao chép'), findsNothing);
    });

    testWidgets(
      'vụ đã đổi (Stale): hiển thị lý do và ngày ngoài vụ, dữ liệu không bị ẩn',
      (tester) async {
        _route(
          calendar: _calendar(
            status: 'Stale',
            reasons: ['StartDateChanged', 'DaysOutOfRange'],
            extraDays: [
              {
                'dayNumber': 60,
                'date': '2027-01-07',
                'stageId': null,
                'stageName': null,
                'source': 'Override',
                'isOverride': true,
                'outOfRange': true,
                'sessions': [_sess('Cũ', '08:00')],
              },
            ],
          ),
        );
        await _pump(tester);
        expect(find.text('Lưu ý thay đổi mùa vụ'), findsOneWidget);
        expect(
          find.textContaining('Ngày bắt đầu của vụ đã đổi'),
          findsOneWidget,
        );
        expect(find.textContaining('Ngày 60 (ngoài vụ): 1 ca'), findsOneWidget);
      },
    );

    testWidgets('không phải Owner: chỉ xem, không có nút sửa/khôi phục', (
      tester,
    ) async {
      _route(calendar: _calendar(editable: false));
      await _pump(tester);
      await tester.tap(dayCell(3));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn chỉ xem được'), findsOneWidget);
      expect(find.textContaining('LƯU CẤU HÌNH NGÀY'), findsNothing);
      expect(find.text('Bỏ tùy biến'), findsNothing);
      expect(find.text('Áp dụng cả Giai đoạn này'), findsNothing);
      expect(find.byTooltip('Khôi phục chuẩn gốc'), findsNothing);
    });

    testWidgets('Zone chưa có vụ: nói rõ, không bịa lịch', (tester) async {
      _route(seasons: []);
      await _pump(tester);
      expect(find.textContaining('chưa có vụ trồng'), findsOneWidget);
      expect(
        calls.where((c) => c.url.path.contains('irrigation-calendar')),
        isEmpty,
      );
    });

    testWidgets('lỗi tải: có nút thử lại', (tester) async {
      handler = (_) async => utf8Json({'message': 'Máy chủ bận'}, 500);
      await _pump(tester);
      expect(
        find.textContaining('Không tải được lịch tưới của vụ'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('không tràn ở 390px và 320px, chữ 1.3×', (tester) async {
      for (final width in [390.0, 320.0]) {
        _route();
        tester.view.physicalSize = Size(width, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: SeasonIrrigationCalendarScreen(zone: _zone),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'width $width');
      }
    });
  });

  group('đồng bộ xuống thiết bị', () {
    Map<String, dynamic> pump(String id) => {
      'actuatorId': id,
      'zoneId': 'z1',
      'name': 'Bơm $id',
      'actuatorType': 'PUMP',
      'status': 'OFF',
    };

    void routeSync({
      List<Map<String, dynamic>> actuators = const [],
      http.Response Function(http.Request)? onSync,
    }) {
      _route();
      final base = handler;
      handler = (r) async {
        if (r.url.path == '/api/v1/zones/z1/actuators') {
          return utf8Json(actuators);
        }
        if (r.url.path == '/api/v1/zones/z1/schedules/sync-from-profile') {
          return onSync?.call(r) ??
              utf8Json({
                'source': 'Profile',
                'schedules': [{}, {}],
              });
        }
        return base(r);
      };
    }

    Future<void> tapSync(WidgetTester tester) async {
      final btn = find.byKey(const ValueKey('sync_to_device'));
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await tester.pumpAndSettle();
    }

    testWidgets('xác nhận rồi POST sync-from-profile với bơm của Zone', (
      tester,
    ) async {
      routeSync(actuators: [pump('a1')]);
      await _pump(tester);
      await tapSync(tester);
      expect(find.text('Đồng bộ lịch xuống thiết bị?'), findsOneWidget);
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();

      final post = calls.singleWhere((c) => c.method == 'POST');
      expect(post.url.path, '/api/v1/zones/z1/schedules/sync-from-profile');
      expect(jsonDecode(post.body)['actuatorId'], 'a1');
      expect(find.textContaining('Đã đồng bộ 2 lịch'), findsOneWidget);
    });

    testWidgets('Zone chưa có bơm/van: báo lỗi, không gọi đồng bộ', (
      tester,
    ) async {
      routeSync(actuators: []);
      await _pump(tester);
      await tapSync(tester);
      expect(find.textContaining('chưa có bơm/van tưới'), findsOneWidget);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
    });

    testWidgets('backend lỗi 400: báo lỗi, không báo đã đồng bộ', (
      tester,
    ) async {
      routeSync(
        actuators: [pump('a1')],
        onSync: (_) =>
            utf8Json({'message': 'Zone chưa gắn hồ sơ canh tác.'}, 400),
      );
      await _pump(tester);
      await tapSync(tester);
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã đồng bộ'), findsNothing);
      expect(find.textContaining('chưa gắn hồ sơ'), findsOneWidget);
    });

    testWidgets('không phải Chủ trang trại (isEditable=false): ẩn nút', (
      tester,
    ) async {
      _route(calendar: _calendar(editable: false));
      await _pump(tester);
      expect(find.byKey(const ValueKey('sync_to_device')), findsNothing);
    });
  });
}
