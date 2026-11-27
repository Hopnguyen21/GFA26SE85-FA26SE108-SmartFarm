import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/irrigation/schedule_shift_logic.dart';
import 'package:smartfarm_mobile/features/irrigation/schedules_automation_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/season_irrigation_calendar_screen.dart';

ScheduleModel _sch(
  String id,
  String zone,
  String start, {
  int minutes = 15,
  String actuator = 'a1',
  List<String> days = const ['T2', 'T3'],
  bool active = true,
  String zoneId = 'z1',
}) => ScheduleModel(
  scheduleId: id,
  zoneId: zoneId,
  actuatorId: actuator,
  name: 'Lịch $id',
  zoneName: zone,
  actuatorName: 'Bơm $actuator',
  startTime: start,
  durationMinutes: minutes,
  daysOfWeek: days,
  isActive: active,
);

AutomationRuleModel _rule(String id, String zone, {bool active = true}) =>
    AutomationRuleModel(
      ruleId: id,
      name: 'Luật $id',
      zoneName: zone,
      parameterCode: 'SOIL_MOISTURE',
      operator: '<',
      thresholdValue: 50,
      actuatorName: 'Bơm 1',
      actionType: 'ON',
      actionDurationMinutes: 10,
      isActive: active,
    );

void main() {
  group('shiftOfTime', () {
    test('chia ca theo giờ bắt đầu', () {
      expect(shiftOfTime('06:30'), 'Ca sáng');
      expect(shiftOfTime('05:00'), 'Ca sáng');
      expect(shiftOfTime('10:59'), 'Ca sáng');
      expect(shiftOfTime('11:00'), 'Ca trưa');
      expect(shiftOfTime('14:59'), 'Ca trưa');
      expect(shiftOfTime('15:00'), 'Ca chiều');
      expect(shiftOfTime('19:59'), 'Ca chiều');
      expect(shiftOfTime('20:00'), 'Ca đêm');
      expect(shiftOfTime('02:15'), 'Ca đêm');
    });
    test(
      '3 ca mặc định của dự án (Sáng 06:10, Trưa 12:00, Chiều 16:30) rơi đúng ca',
      () {
        expect(shiftOfTime('06:10'), 'Ca sáng');
        expect(shiftOfTime('12:00'), 'Ca trưa');
        expect(shiftOfTime('16:30'), 'Ca chiều');
      },
    );
    test('giờ sai định dạng không đoán ca', () {
      expect(shiftOfTime(''), isNull);
      expect(shiftOfTime('abc'), isNull);
      expect(shiftOfTime('25:00'), isNull);
      expect(shiftOfTime('10:75'), isNull);
    });
  });

  group('sắp xếp và gộp', () {
    test('lịch sắp theo Zone rồi giờ; giờ sai xếp cuối', () {
      final out = sortedSchedules([
        _sch('c', 'Zone B', '07:00'),
        _sch('x', 'Zone A', 'sai'),
        _sch('b', 'Zone A', '15:00'),
        _sch('a', 'Zone A', '06:00'),
      ]);
      expect(out.map((e) => e.scheduleId), ['a', 'b', 'x', 'c']);
    });
    test('luật: đang bật lên trước', () {
      final out = sortedRules([
        _rule('2', 'Zone A', active: false),
        _rule('1', 'Zone B'),
      ]);
      expect(out.map((e) => e.ruleId), ['1', '2']);
    });
    test('groupByZone giữ thứ tự và đếm đúng', () {
      final g = groupByZone<ScheduleModel>([
        _sch('a', 'Zone A', '06:00'),
        _sch('b', 'Zone A', '07:00'),
        _sch('c', 'Zone B', '06:00'),
      ], (s) => s.zoneName);
      expect(g.keys.toList(), ['Zone A', 'Zone B']);
      expect(g['Zone A']!.length, 2);
    });
  });

  group('conflictingScheduleIds', () {
    test('cùng thiết bị, giờ giao nhau, chung ngày → trùng', () {
      final c = conflictingScheduleIds([
        _sch('a', 'Zone A', '06:00', minutes: 30),
        _sch('b', 'Zone A', '06:20'),
      ]);
      expect(c, {'a', 'b'});
    });
    test('liền kề (kết thúc đúng lúc bắt đầu) không trùng', () {
      final c = conflictingScheduleIds([
        _sch('a', 'Zone A', '06:00', minutes: 30),
        _sch('b', 'Zone A', '06:30'),
      ]);
      expect(c, isEmpty);
    });
    test('trùng theo Zone (như backend), kể cả khi khác thiết bị', () {
      final c = conflictingScheduleIds([
        _sch('a', 'Zone A', '06:00', minutes: 30),
        _sch('b', 'Zone A', '06:10', actuator: 'a2'),
      ]);
      expect(c, {'a', 'b'});
    });
    test('khác Zone, khác ngày hoặc lịch tắt không trùng', () {
      expect(
        conflictingScheduleIds([
          _sch('a', 'Zone A', '06:00', minutes: 30),
          _sch('b', 'Zone B', '06:10', zoneId: 'z2'),
        ]),
        isEmpty,
      );
      expect(
        conflictingScheduleIds([
          _sch('a', 'Zone A', '06:00', minutes: 30, days: const ['T2']),
          _sch('b', 'Zone A', '06:10', days: const ['T5']),
        ]),
        isEmpty,
      );
      expect(
        conflictingScheduleIds([
          _sch('a', 'Zone A', '06:00', minutes: 30),
          _sch('b', 'Zone A', '06:10', active: false),
        ]),
        isEmpty,
      );
    });
    test('3 ca mặc định của dự án (06:10, 12:00, 16:30) không trùng nhau', () {
      final c = conflictingScheduleIds([
        _sch('s', 'Zone A', '06:10', minutes: 7),
        _sch('t', 'Zone A', '12:00', minutes: 5),
        _sch('c', 'Zone A', '16:30', minutes: 8),
      ]);
      expect(c, isEmpty);
    });
  });

  group('SchedulesAutomationScreen', () {
    Future<FarmProvider> pump(
      WidgetTester tester, {
      List<ScheduleModel> schedules = const [],
      List<AutomationRuleModel> rules = const [],
    }) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = FarmProvider()..switchRole('OWNER');
      p.setSchedulesForTesting(schedules);
      p.setAutomationRulesForTesting(rules);
      await tester.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: p,
          child: const MaterialApp(home: SchedulesAutomationScreen()),
        ),
      );
      // Provider tự đồng bộ khi tạo (không có backend → lỗi) rồi mới xong; chờ xong để trạng thái ổn định.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      p.setSchedulesForTesting(schedules);
      p.setAutomationRulesForTesting(rules);
      await tester.pump();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
      return p;
    }

    testWidgets('chưa có luật: hiện trạng thái rỗng có hướng dẫn', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Chưa có luật tự động nào'), findsOneWidget);
    });

    testWidgets('tab lịch rỗng: hiện trạng thái rỗng, không vòng quay vô hạn', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(Tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Chưa có lịch tưới định kỳ nào'), findsOneWidget);
    });

    testWidgets('lịch nhóm theo Zone, có chip ca và cảnh báo trùng giờ', (
      tester,
    ) async {
      await pump(
        tester,
        schedules: [
          _sch('a', 'Zone A', '06:00', minutes: 30),
          _sch('b', 'Zone A', '06:20'),
          _sch('c', 'Zone B', '16:00', actuator: 'a9', zoneId: 'z2'),
        ],
      );
      await tester.tap(find.byType(Tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Zone A'), findsOneWidget); // tiêu đề nhóm
      expect(find.text('Zone B'), findsOneWidget);
      expect(find.text('Ca sáng'), findsNWidgets(2));
      expect(find.text('Ca chiều'), findsOneWidget);
      expect(find.text('Trùng giờ với lịch khác'), findsNWidgets(2));
    });

    testWidgets('luật nhóm theo Zone, luật đang bật đứng trước', (
      tester,
    ) async {
      await pump(
        tester,
        rules: [_rule('2', 'Zone A', active: false), _rule('1', 'Zone B')],
      );
      final first = tester.getTopLeft(find.text('Luật 1')).dy;
      final second = tester.getTopLeft(find.text('Luật 2')).dy;
      expect(first, lessThan(second));
    });

    testWidgets('không có Zone: không hiện thẻ kế hoạch ca theo vụ', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(Tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('season-plan-card')), findsNothing);
    });

    testWidgets(
      'có Zone: thẻ ca tưới theo vụ (AI gợi ý) mở màn lịch tưới theo vụ',
      (tester) async {
        final p = await pump(tester);
        p.setSelectedFarmIdForTesting('f1');
        p.setZonesForTesting([
          ZoneModel(
            zoneId: 'z1',
            farmId: 'f1',
            name: 'Zone A',
            currentCrop: 'Dưa leo',
            currentStage: 'Vegetative',
            areaM2: 100,
            currentSoilMoisture: 50,
            currentTemp: 25,
            currentHumidity: 60,
            currentLux: 800,
          ),
        ]);
        await tester.pump();
        await tester.tap(find.byType(Tab).last);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const ValueKey('season-plan-card')), findsOneWidget);
        expect(find.text('Ca tưới theo vụ (AI gợi ý)'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('season-plan-card')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(SeasonIrrigationCalendarScreen), findsOneWidget);
      },
    );
  });
}
