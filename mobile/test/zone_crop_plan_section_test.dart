import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/zones/widgets/zone_crop_plan_section.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_controller.dart';
import 'package:smartfarm_mobile/features/zones/zone_crop_plan_logic.dart';

Map<String, dynamic> _stage(String id, int order, int days) => {
  'stageId': id,
  'name': 'GĐ $order',
  'stageOrder': order,
  'durationDays': days,
  'requirements': [
    {
      'parameterCode': 'SoilMoisture',
      'minValue': 60,
      'maxValue': 80,
      'targetValue': 70,
      'unit': '%',
    },
  ],
};

Map<String, dynamic> _profile(
  String id, {
  bool system = true,
  Object? variety,
  Object? plan,
  bool isDefault = true,
}) => {
  'profileId': id,
  'name': system ? 'VietGAP $id' : 'Bản riêng $id',
  'varietyId': variety,
  'isSystemDefined': system,
  'isDefault': isDefault,
  'irrigationPlan': plan,
  'stages': [_stage('s1-$id', 1, 20), _stage('s2-$id', 2, 40)],
};

Map<String, dynamic> _irrigation(
  String profileId, {
  String source = 'Crop',
  bool editable = false,
}) => {
  'profileId': profileId,
  'profileName': 'Hồ sơ $profileId',
  'isSystemDefined': !editable,
  'isEditable': editable,
  'repeatType': 'DAILY',
  'timeZone': 'Asia/Ho_Chi_Minh',
  'stages': [
    {
      'stageId': 's1-$profileId',
      'stageName': 'GĐ 1',
      'stageOrder': 1,
      'durationDays': 20,
      'source': source,
      'sessions': [
        {
          'sessionId': 'x',
          'title': 'Tưới sáng',
          'startTime': '06:00',
          'durationSeconds': 480,
          'enabled': true,
        },
      ],
    },
  ],
};

const _cropPlan =
    '{"repeatType":"DAILY","sessions":[{"title":"Tưới sáng","startTime":"06:00","durationMinutes":8,"enabled":true}]}';

ZoneCropPlanController _controller({
  List<Map<String, dynamic>>? crops,
  List<Map<String, dynamic>>? profiles,
  List<Map<String, dynamic>>? varieties,
  Object? cropsError,
}) => ZoneCropPlanController(
  fetchCrops: () async {
    if (cropsError != null) throw Exception('$cropsError');
    return crops ??
        [
          {
            'cropId': 'c1',
            'name': 'Dưa lưới',
            'calendarIrrigationPlan': _cropPlan,
          },
        ];
  },
  fetchVarieties: (_) async => varieties ?? [],
  fetchProfiles: (_) async => profiles ?? [_profile('p1')],
  fetchIrrigation: (id) async => _irrigation(id),
);

Future<void> _pump(
  WidgetTester tester,
  ZoneCropPlanController c, {
  String? locked,
}) async {
  tester.view.physicalSize = const Size(500, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ZoneCropPlanSection(controller: c, lockedReason: locked),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _viewAndApply(WidgetTester tester) async {
  await tester.tap(find.text('Xem chi tiết').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Áp dụng profile này cho Zone'));
  await tester.pumpAndSettle();
}

void main() {
  group('ZoneCropPlanController', () {
    test(
      'chọn cây → tải giống + hồ sơ nhưng KHÔNG tự chọn hồ sơ nào; chọn rồi mới nạp giai đoạn thật',
      () async {
        final c = _controller(
          profiles: [_profile('p2', isDefault: false), _profile('p1')],
        );
        await c.loadCrops();
        await c.chooseCrop('c1');
        expect(
          c.selection.profileId,
          isNull,
          reason: 'không tự áp dụng hồ sơ đầu tiên',
        );
        expect(c.validate(), contains('Chưa chọn hồ sơ'));
        c.chooseProfile('p1');
        expect(c.selection.stages, hasLength(2));
        expect(c.selection.totalDays, 60);
        expect(c.selection.mode, ZoneProfileMode.system);
        expect(c.validate(), isNull);
      },
    );

    test(
      'chọn giống: hiện hồ sơ riêng giống đó VÀ hồ sơ chung (varietyId null)',
      () async {
        final c = _controller(
          varieties: [
            {'varietyId': 'v1', 'name': 'Giống A'},
          ],
          profiles: [
            _profile('general'),
            _profile('forV1', variety: 'v1'),
            _profile('forV2', variety: 'v2'),
          ],
        );
        await c.chooseCrop('c1');
        expect(
          c.profiles.map((p) => p['profileId']),
          ['general'],
          reason: 'chưa chọn giống: chỉ hồ sơ chung',
        );
        await c.chooseVariety('v1');
        expect(
          c.profiles.map((p) => p['profileId']),
          ['general', 'forV1'],
          reason: 'không có hồ sơ của giống khác',
        );
        expect(c.selection.profileId, isNull);
        c.chooseProfile('forV1');
        c.chooseProfile('general');
        expect(c.selection.profileId, 'general');
        expect(c.genericProfileDropsVariety, isTrue);
      },
    );

    test(
      'đổi giống: bỏ hồ sơ đã chọn của giống cũ và tải lại danh sách',
      () async {
        var loads = 0;
        final c = ZoneCropPlanController(
          fetchCrops: () async => [],
          fetchVarieties: (_) async => [],
          fetchProfiles: (_) async {
            loads++;
            return [
              _profile('general', isDefault: false),
              _profile('forV1', variety: 'v1', isDefault: false),
              _profile('forV2', variety: 'v2', isDefault: false),
            ];
          },
          fetchIrrigation: (id) async => _irrigation(id),
        );
        await c.chooseCrop('c1');
        await c.chooseVariety('v1');
        c.chooseProfile('forV1');
        expect(c.selection.profileId, 'forV1');
        final before = loads;
        await c.chooseVariety('v2');
        expect(loads, before + 1);
        expect(
          c.selection.profileId,
          isNull,
          reason: 'hồ sơ của v1 bị bỏ, không tự chọn thay',
        );
        await c.chooseVariety(null);
        expect(c.selection.profileId, isNull);
        expect(c.profiles.map((p) => p['profileId']), ['general']);
      },
    );

    test(
      'cây chưa có hồ sơ → không có profileId và validate chặn bằng lý do rõ',
      () async {
        final c = _controller(profiles: []);
        await c.chooseCrop('c1');
        expect(c.selection.profileId, isNull);
        expect(c.validate(), contains('chưa có hồ sơ'));
      },
    );

    test(
      'lỗi tải giống/hồ sơ được giữ lại để hiển thị, không biến thành danh sách rỗng',
      () async {
        final c = ZoneCropPlanController(
          fetchCrops: () async => [
            {'cropId': 'c1', 'name': 'X'},
          ],
          fetchVarieties: (_) async =>
              throw Exception('503 Service Unavailable'),
          fetchProfiles: (_) async => [],
        );
        await c.chooseCrop('c1');
        expect(c.detailError, contains('503'));
      },
    );

    test(
      'chế độ tùy chỉnh chỉ cho hồ sơ hệ thống (backend chỉ sao chép hồ sơ hệ thống)',
      () async {
        final c = _controller(profiles: [_profile('own', system: false)]);
        await c.chooseCrop('c1');
        c.chooseProfile('own');
        c.setMode(ZoneProfileMode.custom);
        expect(c.selection.mode, isNot(ZoneProfileMode.custom));

        final sys = _controller();
        await sys.chooseCrop('c1');
        sys.chooseProfile('p1');
        sys.setMode(ZoneProfileMode.custom);
        expect(sys.selection.mode, ZoneProfileMode.custom);
        expect(sys.selection.customName, isNotEmpty);
      },
    );

    test(
      'sửa số ngày/ngưỡng chỉ đổi bản nháp và đánh dấu thay đổi; ngày dự kiến tính lại',
      () async {
        final c = _controller();
        await c.chooseCrop('c1');
        c.chooseProfile('p1');
        c.setMode(ZoneProfileMode.custom);
        c.setStageDuration(0, 30);
        c.setRequirement(1, 'SoilMoisture', target: 65);
        expect(c.selection.stagesChanged, isTrue);
        expect(
          c.selection.originalStages.first.durationDays,
          20,
          reason: 'bản gốc giữ nguyên để so sánh',
        );
        expect(c.selection.totalDays, 70);
        expect(c.selection.stages[1].requirements.single.target, 65);
      },
    );

    test(
      'lịch tưới của hồ sơ đang chọn được tải từ backend và đổi theo hồ sơ',
      () async {
        final c = _controller(
          profiles: [_profile('p1'), _profile('p2', isDefault: false)],
        );
        await c.chooseCrop('c1');
        c.chooseProfile('p1');
        await Future<void>.delayed(Duration.zero);
        expect(c.irrigation!.profileId, 'p1');
        expect(c.irrigation!.stages.single.sessions.single.startTime, '06:00');
        expect(c.irrigation!.stages.single.fromCrop, isTrue);
        c.chooseProfile('p2');
        await Future<void>.delayed(Duration.zero);
        expect(c.irrigation!.profileId, 'p2');
      },
    );

    test(
      'lỗi tải lịch tưới được giữ lại để hiển thị, không biến thành rỗng',
      () async {
        final c = ZoneCropPlanController(
          fetchCrops: () async => [],
          fetchVarieties: (_) async => [],
          fetchProfiles: (_) async => [_profile('p1')],
          fetchIrrigation: (_) async =>
              throw Exception('503 Service Unavailable'),
        );
        await c.chooseCrop('c1');
        c.chooseProfile('p1');
        await Future<void>.delayed(Duration.zero);
        expect(c.irrigation, isNull);
        expect(c.irrigationError, contains('503'));
      },
    );

    test('đổi hồ sơ xoá chỉnh sửa của lựa chọn cũ', () async {
      final c = _controller(
        profiles: [_profile('p1'), _profile('p2', isDefault: false)],
      );
      await c.chooseCrop('c1');
      c.chooseProfile('p1');
      c.setMode(ZoneProfileMode.custom);
      c.setStageDuration(0, 99);
      c.chooseProfile('p2');
      expect(c.selection.stages.first.durationDays, 20);
    });

    test(
      '"Không áp dụng" xoá lựa chọn và cho lưu Zone không cần cây',
      () async {
        final c = _controller();
        await c.chooseCrop('c1');
        c.setMode(ZoneProfileMode.none);
        expect(c.selection.active, isFalse);
        expect(c.validate(), isNull);
      },
    );

    test('response của cây cũ về muộn không ghi đè lựa chọn cây mới', () async {
      final slow = Completer<List<Map<String, dynamic>>>();
      final c = ZoneCropPlanController(
        fetchCrops: () async => [],
        fetchVarieties: (id) async => [],
        fetchProfiles: (id) =>
            id == 'old' ? slow.future : Future.value([_profile('newP')]),
      );
      final first = c.chooseCrop('old');
      await c.chooseCrop('new');
      slow.complete([_profile('oldP')]);
      await first;
      expect(c.selection.cropId, 'new');
      expect(c.selection.profileId, isNull);
      expect(c.profiles.single['profileId'], 'newP');
    });
  });

  group('ZoneCropPlanSection (giao diện)', () {
    testWidgets('mặc định là "Không áp dụng": không hiện ô chọn cây', (
      tester,
    ) async {
      final c = _controller();
      await _pump(tester, c);
      expect(find.text('Không áp dụng'), findsOneWidget);
      expect(find.text('Cây trồng *'), findsNothing);
      c.dispose();
    });

    testWidgets(
      'chọn "Dùng hồ sơ có sẵn": tải cây, hiện trạng thái lỗi và nút thử lại khi API lỗi',
      (tester) async {
        final c = _controller(cropsError: 'Không kết nối được máy chủ');
        await _pump(tester, c);
        await tester.tap(find.text('Dùng hồ sơ có sẵn'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Không tải được danh sách cây trồng'),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);
        c.dispose();
      },
    );

    testWidgets(
      'danh sách cây rỗng → thông báo rõ, vẫn tạo được Zone không áp dụng',
      (tester) async {
        final c = _controller(crops: []);
        await _pump(tester, c);
        await tester.tap(find.text('Dùng hồ sơ có sẵn'));
        await tester.pumpAndSettle();
        expect(find.textContaining('chưa có cây trồng nào'), findsOneWidget);
        c.dispose();
      },
    );

    testWidgets(
      'chọn cây hiện giai đoạn, ngưỡng và lịch tưới của hồ sơ (nguồn nêu rõ)',
      (tester) async {
        final c = _controller();
        await _pump(tester, c);
        await tester.tap(find.text('Dùng hồ sơ có sẵn'));
        await tester.pumpAndSettle();
        await c.chooseCrop('c1');
        await tester.pumpAndSettle();
        expect(find.textContaining('Chưa chọn hồ sơ nào'), findsOneWidget);
        expect(find.text('Xem chi tiết'), findsOneWidget);
        await _viewAndApply(tester);
        expect(
          find.textContaining('2 giai đoạn · tổng 60 ngày'),
          findsOneWidget,
        );
        expect(find.textContaining('1. GĐ 1'), findsWidgets);
        expect(find.textContaining('Độ ẩm đất: 60–80 %'), findsWidgets);
        expect(find.text('Lịch tưới của hồ sơ'), findsOneWidget);
        expect(
          find.textContaining('Tưới sáng · 06:00 · 8 phút'),
          findsOneWidget,
        );
        expect(
          find.text('Lịch mẫu của cây'),
          findsOneWidget,
          reason: 'hồ sơ hệ thống chưa có ca riêng: nói rõ là lịch mẫu của cây',
        );
        expect(
          find.textContaining('Sửa ca tưới'),
          findsNothing,
          reason: 'chọn hồ sơ có sẵn thì chỉ xem',
        );
        c.dispose();
      },
    );

    testWidgets(
      'chế độ tùy chỉnh: hiện ô sửa số ngày và ngưỡng (không có sửa lịch tưới)',
      (tester) async {
        final c = _controller();
        await _pump(tester, c);
        await tester.tap(find.text('Dùng hồ sơ có sẵn'));
        await tester.pumpAndSettle();
        await c.chooseCrop('c1');
        await tester.pumpAndSettle();
        await _viewAndApply(tester);
        await tester.tap(find.text('Tùy chỉnh bản sao'));
        await tester.pumpAndSettle();
        expect(find.text('Tên hồ sơ tùy chỉnh *'), findsOneWidget);
        expect(find.text('Sửa lịch'), findsNothing);
        expect(find.text('Thấp nhất'), findsWidgets);
        await tester.enterText(find.byKey(const ValueKey('dur_s1-p1')), '35');
        await tester.pump();
        expect(c.selection.stages.first.durationDays, 35);
        c.dispose();
      },
    );

    testWidgets(
      'Zone đang có vụ chạy: chỉ hiện lý do khoá, không cho đổi hồ sơ',
      (tester) async {
        final c = _controller();
        await _pump(tester, c, locked: 'Zone đang có vụ trồng chạy.');
        expect(find.text('Zone đang có vụ trồng chạy.'), findsOneWidget);
        expect(find.text('Dùng hồ sơ có sẵn'), findsNothing);
        c.dispose();
      },
    );
  });
}
