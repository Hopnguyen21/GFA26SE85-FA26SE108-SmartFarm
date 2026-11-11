import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/theme/app_theme.dart';
import 'package:smartfarm_mobile/core/utils/json_utils.dart';
import 'package:smartfarm_mobile/features/zones/widgets/stage_draft_tile.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_logic.dart';

// Hình dạng đúng như backend trả (GrowthStageView/RequirementView): camelCase, enum dạng chuỗi, decimal là số JSON.
Map<String, dynamic> _stageJson() => {
  'stageId': '0b6f2c1e-0000-4000-8000-000000000001',
  'name': 'Cây con',
  'stageOrder': 1,
  'durationDays': 20,
  'description': null,
  'fertilizerAction': null,
  'ipmAction': null,
  'requirements': [
    {'parameterCode': 'Temperature', 'minValue': 22.5, 'maxValue': 30.0, 'targetValue': 26.0, 'unit': '°C'},
    {'parameterCode': 'SoilMoisture', 'minValue': 60, 'maxValue': 80, 'targetValue': 70, 'unit': '%'},
  ],
};

Future<void> _pumpTile(WidgetTester tester, StageDraft st, {bool editable = false}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StageDraftTile(stage: st, editable: editable, onRequirement: (c, {min, max, target}) {}),
        ),
      ),
    ),
  );
}

/// Mọi chữ hiển thị phải có màu đủ tối để đọc trên nền sáng (tránh chữ trắng/nhạt trên nền trắng).
void _expectAllTextReadable(WidgetTester tester) {
  final paragraphs = tester.widgetList<RichText>(find.byType(RichText));
  expect(paragraphs, isNotEmpty);
  for (final p in paragraphs) {
    final text = p.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final color = p.text.style?.color;
    expect(color, isNotNull, reason: 'chữ "$text" không có màu');
    expect(color!.computeLuminance(), lessThan(0.45), reason: 'chữ "$text" quá nhạt trên nền sáng');
  }
}

void main() {
  group('đọc JSON Growth Profile thật của backend', () {
    test('schema thật (camelCase, số thực/số nguyên, đơn vị) được đọc đủ, không điền số mặc định', () {
      final st = StageDraft.fromJson(_stageJson());
      expect(st.name, 'Cây con');
      expect(st.order, 1);
      expect(st.durationDays, 20);
      expect(st.unreadableRequirements, 0);
      expect(st.requirements.map((r) => r.code), ['Temperature', 'SoilMoisture']);
      final t = st.requirements.first;
      expect((t.min, t.max, t.target, t.unit), (22.5, 30.0, 26.0, '°C'));
      expect(describeRequirementDraft(t), 'Nhiệt độ: 22.5–30 °C (mục tiêu 26)');
    });

    test('PascalCase, khóa ngắn, số dạng chuỗi và danh sách bị bọc đều đọc được', () {
      final pascal = StageDraft.fromJson({
        'StageId': 's1',
        'Name': 'Ra hoa',
        'StageOrder': '2',
        'DurationDays': '35',
        'Requirements': {
          'value': [
            {'ParameterCode': 'Ph', 'MinValue': '5,5', 'MaxValue': '6.5', 'TargetValue': 6, 'Unit': 'pH'},
            {'code': 'Ec', 'min': 1, 'max': 2, 'target': 1.5, 'unit': 'mS/cm'},
          ],
        },
      });
      expect(pascal.name, 'Ra hoa');
      expect(pascal.order, 2);
      expect(pascal.durationDays, 35);
      expect(pascal.requirements.map((r) => r.code), ['Ph', 'Ec']);
      expect(pascal.requirements.first.min, 5.5);
      expect(
        jsonList({
          r'$values': [1, 2],
        }),
        hasLength(2),
      );
      expect(
        jsonList({
          'items': [1],
        }),
        hasLength(1),
      );
      expect(jsonList('x'), isEmpty);
    });

    test('ngưỡng thiếu/sai bị đếm là "không đọc được", không biến thành 0', () {
      final st = StageDraft.fromJson({
        'stageId': 's1',
        'name': 'GĐ',
        'stageOrder': 1,
        'durationDays': 10,
        'requirements': [
          {'parameterCode': 'Ph', 'minValue': null, 'maxValue': 6.5, 'targetValue': 6, 'unit': 'pH'},
          {'parameterCode': 'Ec', 'minValue': 'abc', 'maxValue': 2, 'targetValue': 1.5, 'unit': ''},
          {'minValue': 1, 'maxValue': 2, 'targetValue': 1.5},
          'rác',
        ],
      });
      expect(st.requirements, isEmpty);
      expect(st.unreadableRequirements, 4);
      expect(thresholdNotice(st), contains('Không đọc được 4 ngưỡng'));
    });

    test('giai đoạn không có ngưỡng → "Chưa có dữ liệu ngưỡng"', () {
      final st = StageDraft.fromJson({'stageId': 's', 'name': 'GĐ', 'stageOrder': 1, 'durationDays': 5});
      expect(thresholdNotice(st), 'Chưa có dữ liệu ngưỡng.');
    });

    test('DefaultCropProfile (màn Cây trồng) đọc cùng schema, kể cả PascalCase và danh sách bọc', () {
      final p = defaultCropProfileFromApi({
        'profileId': 'p1',
        'cropId': 'c1',
        'cropName': 'Dưa lưới',
        'name': 'VietGAP',
        'stages': {
          'value': [
            {
              'StageId': 's1',
              'Name': 'Cây con',
              'StageOrder': 1,
              'DurationDays': 20,
              'Requirements': [
                {'ParameterCode': 'SoilMoisture', 'MinValue': 60, 'MaxValue': 80, 'TargetValue': 70, 'Unit': '%'},
              ],
            },
          ],
        },
      }, null);
      expect(p.growthStages, hasLength(1));
      expect(p.growthStages.first.requirements.soilMoistureMin, 60);
      expect(p.growthStages.first.requirements.soilMoistureMax, 80);
    });

    test('changedRequirements chỉ trả các ngưỡng đã sửa', () {
      final orig = StageDraft.fromJson(_stageJson()).requirements;
      final edited = [orig[0], orig[1].copyWith(target: 72)];
      final changed = changedRequirements(orig, edited);
      expect(changed.map((r) => r.code), ['SoilMoisture']);
      expect(changedRequirements(orig, orig), isEmpty);
    });
  });

  group('hiển thị ngưỡng trên nền sáng', () {
    testWidgets('chế độ xem: tên, giá trị, đơn vị đều hiện và đọc được', (tester) async {
      await _pumpTile(tester, StageDraft.fromJson(_stageJson()));
      expect(find.textContaining('1. Cây con'), findsOneWidget);
      expect(find.text('20 ngày'), findsOneWidget);
      expect(find.text('Nhiệt độ: 22.5–30 °C (mục tiêu 26)'), findsOneWidget);
      expect(find.text('Độ ẩm đất: 60–80 % (mục tiêu 70)'), findsOneWidget);
      _expectAllTextReadable(tester);
    });

    testWidgets('chế độ sửa: có nhãn Thấp nhất/Mục tiêu/Cao nhất, giá trị ban đầu đúng API, chữ đọc được', (
      tester,
    ) async {
      await _pumpTile(tester, StageDraft.fromJson(_stageJson()), editable: true);
      expect(find.text('Thấp nhất'), findsNWidgets(2));
      expect(find.text('Mục tiêu'), findsNWidgets(2));
      expect(find.text('Cao nhất'), findsNWidgets(2));
      final values = tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text).toList();
      expect(values, containsAll(['22.5', '30', '26', '60', '80', '70']));
      _expectAllTextReadable(tester);
    });

    testWidgets('thiếu ngưỡng: hiện thông báo rõ ràng thay vì ô trắng', (tester) async {
      await _pumpTile(tester, StageDraft.fromJson({'stageId': 's', 'name': 'GĐ', 'stageOrder': 1, 'durationDays': 5}));
      expect(find.text('Chưa có dữ liệu ngưỡng.'), findsOneWidget);
      _expectAllTextReadable(tester);
    });
  });
}
