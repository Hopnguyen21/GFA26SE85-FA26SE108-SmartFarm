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

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _sess(String title, String time, {bool enabled = true}) => {
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
        'sessions': [overrideDays.contains(n) ? _sess('Riêng ngày $n', '11:20') : _sess('Mẫu', '06:00')],
      },
    ...extraDays,
  ],
};

final _zone = ZoneModel.fromJson({'zoneId': 'z1', 'name': 'Nhà màng 1', 'areaM2': 100}, farmId: 'f1', fieldId: 'fl1');

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
              {'seasonId': 'se1', 'name': 'Vụ đông 2026', 'status': 'InProgress'},
            ],
      );
    }
    if (p.endsWith('/irrigation-calendar') || p.contains('/irrigation-calendar/')) {
      if (r.method == 'DELETE') return onDelete?.call(r) ?? utf8Json(_calendar(overrideDays: {}));
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
  await tester.pumpWidget(MaterialApp(home: SeasonIrrigationCalendarScreen(zone: _zone)));
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
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('đọc dữ liệu backend', () {
    test('parse lịch theo ngày: nguồn, giai đoạn, ca, trạng thái', () {
      final c = SeasonIrrigationCalendar.fromJson(_calendar(status: 'Stale', reasons: ['StartDateChanged']));
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

    test('PascalCase và dữ liệu thiếu vẫn không làm hỏng, ngày ngoài vụ tách riêng', () {
      final c = SeasonIrrigationCalendar.fromJson({
        'SeasonId': 's',
        'TotalDays': 2,
        'Days': [
          {'DayNumber': 1, 'Source': 'None', 'Sessions': []},
          {'DayNumber': 9, 'Source': 'Override', 'OutOfRange': true, 'Sessions': []},
        ],
      });
      expect(c.totalDays, 2);
      expect(c.inRangeDays.single.source, DaySource.none);
      expect(c.outOfRangeDays.single.dayNumber, 9);
    });

    test('nguồn đồng bộ thiết bị được mô tả đúng', () {
      expect(syncSourceText({'source': 'SeasonOverride', 'dayNumber': 6}), contains('ngày 6'));
      expect(syncSourceText({'source': 'Profile'}), contains('hồ sơ'));
      expect(syncSourceText({'source': 'Crop'}), contains('lịch mẫu của cây'));
    });
  });

  group('màn hình', () {
    testWidgets('tải từ backend theo Zone + vụ; phân biệt lịch mẫu và lịch tùy chỉnh; chọn hôm nay', (tester) async {
      _route();
      await _pump(tester);

      expect(calls.any((c) => c.url.path == '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar'), isTrue);
      expect(find.text('Vụ đông 2026'), findsOneWidget);
      expect(find.textContaining('Hồ sơ: VietGAP Dưa lưới'), findsOneWidget);
      expect(find.textContaining('hôm nay là ngày 2'), findsOneWidget);
      expect(find.textContaining('Ba loại lịch khác nhau'), findsOneWidget);
      // Ngày hôm nay (2) đang chọn: nguồn lịch mẫu của hồ sơ.
      expect(find.textContaining('Nguồn: Lịch mẫu của hồ sơ'), findsOneWidget);
      expect(find.textContaining('Mẫu · 06:00'), findsOneWidget);
      // Chọn ngày 3 (override).
      await tester.tap(find.byKey(const ValueKey('day_3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nguồn: Tùy chỉnh của vụ'), findsOneWidget);
      expect(find.textContaining('Riêng ngày 3 · 11:20'), findsOneWidget);
      expect(find.text('Khôi phục ngày'), findsOneWidget);
      expect(
        find.textContaining('dùng lịch theo giai đoạn của hồ sơ'),
        findsOneWidget,
        reason: 'hôm nay chưa override',
      );
      expect(calls.where((c) => c.method != 'GET'), isEmpty);
    });

    testWidgets('lọc theo giai đoạn và nhảy về hôm nay', (tester) async {
      _route();
      await _pump(tester);
      await tester.tap(find.text('Ra hoa').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day_1')), findsNothing);
      expect(find.byKey(const ValueKey('day_5')), findsOneWidget);
      await tester.tap(find.text('Hôm nay'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day_1')), findsOneWidget, reason: 'về lại Tất cả và chọn ngày 2');
      expect(find.textContaining('Ngày 2 ·'), findsOneWidget);
    });

    testWidgets('khôi phục một ngày: xác nhận → DELETE đúng ngày → hiển thị dữ liệu backend trả về', (tester) async {
      _route();
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('day_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khôi phục ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Khôi phục ngày 3?'), findsOneWidget);
      await tester.tap(find.text('Khôi phục'));
      await tester.pumpAndSettle();

      final del = calls.singleWhere((c) => c.method == 'DELETE');
      expect(del.url.path, '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar/days/3');
      expect(find.textContaining('Đã khôi phục ngày 3 về lịch mẫu'), findsOneWidget);
      expect(find.textContaining('Nguồn: Lịch mẫu của hồ sơ'), findsOneWidget);
      expect(find.text('Khôi phục ngày'), findsNothing);
    });

    testWidgets('khôi phục cả mùa vụ gọi DELETE gốc; backend lỗi thì báo lỗi, KHÔNG báo đã khôi phục', (tester) async {
      _route(onDelete: (_) => utf8Json({'message': 'Vụ đã kết thúc nên không thể sửa lịch tưới.'}, 409));
      await _pump(tester);
      await tester.ensureVisible(find.text('Khôi phục toàn bộ mùa vụ về lịch mẫu'));
      await tester.tap(find.text('Khôi phục toàn bộ mùa vụ về lịch mẫu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Khôi phục tất cả'));
      await tester.pumpAndSettle();

      final del = calls.singleWhere((c) => c.method == 'DELETE');
      expect(del.url.path, '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar');
      expect(find.textContaining('Không lưu được'), findsOneWidget);
      expect(find.textContaining('Vụ đã kết thúc'), findsOneWidget);
      expect(find.textContaining('Đã khôi phục toàn bộ'), findsNothing);
    });

    testWidgets('áp dụng cho cả vụ: gửi mọi ngày trong vụ với ca của ngày đang chọn; thành công mới báo', (
      tester,
    ) async {
      _route(onPut: (_) => utf8Json(_calendar(overrideDays: {1, 2, 3, 4, 5, 6})));
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('day_3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Áp dụng cả vụ'));
      await tester.tap(find.text('Áp dụng cả vụ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      final put = calls.singleWhere((c) => c.method == 'PUT');
      expect(put.url.path, '/api/v1/zones/z1/planting-seasons/se1/irrigation-calendar');
      final days = (jsonDecode(put.body) as Map<String, dynamic>)['days'] as List;
      expect(days.map((d) => d['dayNumber']), [1, 2, 3, 4, 5, 6]);
      final first = (days.first['sessions'] as List).single as Map<String, dynamic>;
      expect(first['title'], 'Riêng ngày 3');
      expect(first['startTime'], '11:20');
      expect(find.textContaining('Đã áp dụng ca tưới của ngày 3 cho 6 ngày'), findsOneWidget);
    });

    testWidgets('lưu lỗi 400: báo lỗi backend, không báo thành công', (tester) async {
      _route(onPut: (_) => utf8Json({'message': 'Hai ca tưới không được trùng giờ'}, 400));
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('day_3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Áp dụng cả giai đoạn'));
      await tester.tap(find.text('Áp dụng cả giai đoạn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Không lưu được: Hai ca tưới không được trùng giờ'), findsOneWidget);
      expect(find.textContaining('Đã áp dụng'), findsNothing);
    });

    testWidgets('vụ đã đổi (Stale): hiển thị lý do và ngày ngoài vụ, dữ liệu không bị ẩn', (tester) async {
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
      expect(find.text('Vụ đã thay đổi sau lần lưu lịch cuối'), findsOneWidget);
      expect(find.textContaining('Ngày bắt đầu của vụ đã đổi'), findsOneWidget);
      expect(find.textContaining('Ngày 60 (ngoài vụ): 1 ca'), findsOneWidget);
    });

    testWidgets('không phải Owner: chỉ xem, không có nút sửa/khôi phục', (tester) async {
      _route(calendar: _calendar(editable: false));
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('day_3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('chỉ xem'), findsOneWidget);
      expect(find.text('Sửa ngày này'), findsNothing);
      expect(find.text('Khôi phục ngày'), findsNothing);
      expect(find.text('Khôi phục toàn bộ mùa vụ về lịch mẫu'), findsNothing);
    });

    testWidgets('Zone chưa có vụ: nói rõ, không bịa lịch', (tester) async {
      _route(seasons: []);
      await _pump(tester);
      expect(find.textContaining('chưa có vụ trồng'), findsOneWidget);
      expect(calls.where((c) => c.url.path.contains('irrigation-calendar')), isEmpty);
    });

    testWidgets('lỗi tải: có nút thử lại', (tester) async {
      handler = (_) async => utf8Json({'message': 'Máy chủ bận'}, 500);
      await _pump(tester);
      expect(find.textContaining('Không tải được lịch tưới của vụ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
