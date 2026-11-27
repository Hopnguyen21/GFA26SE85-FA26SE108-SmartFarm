import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/reports/parts/reports_farm_overview_tab.dart';
import 'package:smartfarm_mobile/features/reports/reports_overview_logic.dart';

Map<String, dynamic> bucket(String zoneId, String name, num value) => {
  'zoneId': zoneId,
  'zoneName': name,
  'year': 2026,
  'month': 11,
  'value': value,
};

void main() {
  group('sumBucketsByZone', () {
    test('cộng các tháng của cùng một Zone', () {
      final r = sumBucketsByZone({
        'buckets': [
          bucket('z1', 'Nhà màng 1', 10),
          bucket('z1', 'Nhà màng 1', 5.5),
        ],
      });
      expect(r, {'Nhà màng 1': 15.5});
    });

    test('hai Zone khác nhau trùng tên không bị cộng chung', () {
      final r = sumBucketsByZone({
        'buckets': [
          bucket('z1', 'Zone A', 10),
          bucket('z2', 'Zone A', 7),
          bucket('z1', 'Zone A', 1),
        ],
      });
      expect(r, {'Zone A': 11.0, 'Zone A (2)': 7.0});
    });

    test('dữ liệu thiếu/sai dạng không làm hỏng', () {
      expect(sumBucketsByZone(null), isEmpty);
      expect(sumBucketsByZone({'buckets': 'x'}), isEmpty);
      expect(
        sumBucketsByZone({
          'buckets': [
            'rác',
            {'zoneName': '  ', 'value': 3},
            {'zoneName': 'Z', 'value': 'không phải số'},
          ],
        }),
        {'Z': 0.0},
      );
    });

    test('bucket cũ không có zoneId thì gộp theo tên', () {
      final r = sumBucketsByZone({
        'buckets': [
          {'zoneName': 'Z', 'value': 1},
          {'zoneName': 'Z', 'value': 2},
        ],
      });
      expect(r, {'Z': 3.0});
    });
  });

  test('unmeasuredCommands cộng nước + điện, thiếu thì là 0', () {
    expect(unmeasuredCommands(null, null), 0);
    expect(
      unmeasuredCommands(
        {'unmeasuredCommandCount': 2},
        {'unmeasuredCommandCount': 3},
      ),
      5,
    );
    expect(unmeasuredCommands({'unmeasuredCommandCount': 2}, {}), 2);
  });

  group('tab tổng quan', () {
    Future<void> pump(
      WidgetTester tester, {
      required Map<String, dynamic> water,
      required Map<String, dynamic> power,
    }) async {
      tester.view.physicalSize = const Size(700, 4200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = FarmProvider();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportsFarmOverviewTab(
              farmProvider: provider,
              overview: const {
                'farmName': 'Trại',
                'fieldCount': 1,
                'zoneCount': 1,
              },
              water: water,
              power: power,
              tasks: const {
                'total': 0,
                'approved': 0,
                'overdue': 0,
                'byAssignee': [],
              },
              days: 30,
              onDaysChanged: (_) {},
              onFarmSelected: (_) {},
              onRefresh: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('có lệnh chưa đo: báo rõ tổng có thể thấp hơn thực tế', (
      tester,
    ) async {
      await pump(
        tester,
        water: {
          'total': 100,
          'unit': 'L',
          'unmeasuredCommandCount': 2,
          'buckets': [],
        },
        power: {
          'total': 1,
          'unit': 'kWh',
          'unmeasuredCommandCount': 1,
          'buckets': [],
        },
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('unmeasured_notice')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('3 lệnh chưa được tính vào tổng'),
        findsOneWidget,
      );
    });

    testWidgets('đo đủ: không hiện cảnh báo', (tester) async {
      await pump(
        tester,
        water: {
          'total': 100,
          'unit': 'L',
          'unmeasuredCommandCount': 0,
          'buckets': [],
        },
        power: {
          'total': 1,
          'unit': 'kWh',
          'unmeasuredCommandCount': 0,
          'buckets': [],
        },
      );
      expect(find.byKey(const ValueKey('unmeasured_notice')), findsNothing);
    });
  });
}
