import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/utils/due_label.dart';
import 'package:smartfarm_mobile/features/farmer/farmer_dashboard_screen.dart';

ZoneModel _zone(String id, String name, {bool fresh = true}) => ZoneModel(
  zoneId: id,
  farmId: 'f1',
  name: name,
  currentCrop: 'Cà chua',
  currentStage: 'Ra hoa',
  areaM2: 500,
  currentSoilMoisture: 61.5,
  currentTemp: 25,
  currentHumidity: 70,
  currentLux: 500,
  telemetryIsFresh: fresh,
);

TaskModel _task(String id, String status, {DateTime? due, String title = ''}) =>
    TaskModel(
      taskId: id,
      title: title.isEmpty ? 'Việc $id' : title,
      zoneName: 'Zone A',
      priority: 'Trung bình',
      dueDate: '',
      status: status,
      dueAtUtc: due,
      assignments: [
        TaskAssignmentModel(farmerId: 'u1', farmerName: 'F', status: status),
      ],
    );

FarmProvider _provider({bool canControl = true}) {
  final p = FarmProvider();
  p.switchRole('FARMER');
  p.setMeForTesting({
    'userId': 'u1',
    'fullName': 'Nông Dân Một',
    'role': 'Farmer',
    'zoneAccess': [
      {'zoneId': 'z1', 'canControl': canControl},
    ],
  });
  p.setZonesForTesting([_zone('z1', 'Nhà màng 1'), _zone('z2', 'Khác')]);
  return p;
}

Future<void> _pump(WidgetTester t, FarmProvider p) async {
  t.view.physicalSize = const Size(420, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    ChangeNotifierProvider<FarmProvider>.value(
      value: p,
      child: const MaterialApp(home: FarmerDashboardScreen()),
    ),
  );
  await t.pump();
}

void main() {
  zoneListInHeroTests();
  test('dueLabel khớp web', () {
    final now = DateTime(2026, 11, 14, 10);
    expect(dueLabel(null).tone, DueTone.none);
    expect(
      dueLabel(DateTime(2026, 11, 12, 9), now: now).text,
      startsWith('Quá hạn 2 ngày'),
    );
    expect(
      dueLabel(DateTime(2026, 11, 14, 15, 2), now: now).text,
      'Hôm nay (15:02)',
    );
    expect(dueLabel(DateTime(2026, 11, 15, 9), now: now).tone, DueTone.soon);
    expect(
      dueLabel(DateTime(2026, 11, 17, 9), now: now).text,
      startsWith('Còn 3 ngày'),
    );
  });

  testWidgets('hiện hero, 4 chỉ số, lối tắt và khu vực được phân công', (
    t,
  ) async {
    final p = _provider();
    p.tasks.addAll([
      _task('1', 'Pending'),
      _task('2', 'CompletedPendingReview'),
      _task('3', 'Approved'),
    ]);
    await _pump(t, p);

    expect(find.text('Xin chào, Nông Dân Một!'), findsOneWidget);
    expect(find.textContaining('phụ trách 1 khu vực'), findsOneWidget);
    expect(find.text('VIỆC CẦN LÀM'), findsOneWidget);
    expect(find.text('CHỜ CHỦ DUYỆT'), findsOneWidget);
    expect(find.text('Bật tưới nhanh'), findsOneWidget);
    expect(find.text('Bản đồ GIS & Node'), findsOneWidget);
    // Chỉ Zone được phân công; Zone khác không hiện.
    expect(find.text('Nhà màng 1'), findsOneWidget);
    expect(find.text('Khác'), findsNothing);
    expect(find.text('Tưới thủ công'), findsOneWidget);
    // Không có dữ liệu thời tiết thì nói rõ.
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    p.dispose();
  });

  testWidgets('bộ lọc công việc và nút theo trạng thái', (t) async {
    final p = _provider();
    p.tasks.addAll([
      _task('1', 'Pending', title: 'Chờ nhận'),
      _task('2', 'Accepted', title: 'Đã nhận'),
      _task('3', 'InProgress', title: 'Đang làm'),
      _task('4', 'CompletedPendingReview', title: 'Đã nộp'),
    ]);
    await _pump(t, p);

    expect(find.text('Cần làm (3)'), findsOneWidget);
    expect(find.text('Nhận việc'), findsOneWidget);
    expect(find.text('Bắt đầu làm'), findsOneWidget);
    expect(find.text('Nộp kết quả'), findsOneWidget);
    expect(find.text('Đã nộp'), findsNothing);

    await t.tap(find.text('Chờ duyệt (1)'));
    await t.pump();
    expect(find.text('Đã nộp'), findsOneWidget);
    expect(find.text('Nhận việc'), findsNothing);
    p.dispose();
  });

  testWidgets('không có quyền điều khiển thì ẩn Tưới thủ công', (t) async {
    final p = _provider(canControl: false);
    await _pump(t, p);
    expect(find.text('Tưới thủ công'), findsNothing);
    p.dispose();
  });

  testWidgets('tìm kiếm khu vực', (t) async {
    final p = _provider();
    await _pump(t, p);
    await t.enterText(find.byType(TextField), 'không có');
    await t.pump();
    expect(
      find.text('Không tìm thấy khu vực nhà màng phù hợp.'),
      findsOneWidget,
    );
    p.dispose();
  });

  testWidgets('hộp thoại tưới có 5 mức thời gian tối đa 15 phút', (t) async {
    final p = _provider();
    await _pump(t, p);
    await t.tap(find.text('Bật tưới nhanh'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('BR-SAFE-01'), findsWidgets);
    for (final m in ['1p', '3p', '5p', '10p', '15p']) {
      expect(find.text(m), findsOneWidget);
    }
    expect(find.text('Bật tưới ngay (5 phút)'), findsOneWidget);
    await t.tap(find.text('15p'));
    await t.pump();
    expect(find.text('Bật tưới ngay (15 phút)'), findsOneWidget);
    p.dispose();
  });
  testWidgets(
    'vùng chạm: nút thao tác cao tối thiểu 44dp, chữ không nhỏ hơn 11',
    (t) async {
      final p = _provider();
      p.tasks.addAll([_task('1', 'Pending'), _task('2', 'Accepted')]);
      await _pump(t, p);
      for (final label in ['Nhận việc', 'Bắt đầu làm', 'Tưới thủ công']) {
        final btn = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (w) => w is FilledButton || w is OutlinedButton,
          ),
        );
        expect(
          t.getSize(btn.first).height,
          greaterThanOrEqualTo(44),
          reason: label,
        );
      }
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        final size = w.style?.fontSize;
        if (size != null)
          expect(size, greaterThanOrEqualTo(11), reason: w.data);
      }
      p.dispose();
    },
  );

  testWidgets('cảnh báo mở: banner tra tên Zone từ zoneId và thẻ Zone đếm đúng', (
    t,
  ) async {
    final p = _provider();
    p.alerts.add(
      AlertModel.fromJson({
        'alertId': 'a1',
        'zoneId': 'z1',
        'severity': 'Warning',
        'status': 'Open',
        'parameterCode': 'Temperature',
        'observedValue': 31,
        'unit': '°C',
      }),
    );
    await _pump(t, p);
    expect(find.textContaining('Phát hiện 1 cảnh báo'), findsOneWidget);
    // Tên Zone xuất hiện ở banner (tra từ zoneId) và ở thẻ Zone; thẻ báo 1 cảnh báo.
    expect(find.text('Nhà màng 1'), findsNWidgets(2));
    expect(find.text('1 cảnh báo'), findsOneWidget);
    p.dispose();
  });
}

void zoneListInHeroTests() {
  testWidgets(
    'Zone không có số đo còn hiệu lực và không cảnh báo: hiện "Chưa có dữ liệu", không khẳng định "An toàn"; việc Overdue không hiện chữ tiếng Anh',
    (t) async {
      final p = _provider();
      p.setZonesForTesting([_zone('z1', 'Nhà màng 1', fresh: false)]);
      p.tasks.add(
        _task(
          '9',
          'Overdue',
          due: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );
      await _pump(t, p);
      expect(find.text('Chưa có dữ liệu'), findsWidgets);
      expect(find.text('✓ An toàn'), findsNothing);
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('Chưa hoàn thành'), findsOneWidget);
      p.dispose();
    },
  );

  testWidgets(
    'dropdown khu vực được phân công: thu gọn mặc định, bấm xổ ra chỉ khu vực của Farmer, chọn thì thu lại',
    (t) async {
      final p = _provider();
      await _pump(t, p);
      expect(find.text('Khu vực được phân công (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('hero-zone-z1')), findsNothing);
      await t.tap(find.byKey(const ValueKey('hero-zones-toggle')));
      await t.pump();
      expect(find.byKey(const ValueKey('hero-zone-z1')), findsOneWidget);
      expect(find.byKey(const ValueKey('hero-zone-z2')), findsNothing);
      await t.tap(find.byKey(const ValueKey('hero-zone-z1')));
      await t.pump();
      expect(find.byKey(const ValueKey('hero-zone-z1')), findsNothing);
      p.dispose();
    },
  );

  testWidgets('chưa được giao khu vực nào: báo rõ thay vì để trống', (t) async {
    final p = _provider();
    p.setMeForTesting({
      'userId': 'u1',
      'fullName': 'Nông Dân Một',
      'role': 'Farmer',
      'zoneAccess': [],
    });
    await _pump(t, p);
    expect(find.textContaining('chưa được giao khu vực nào'), findsOneWidget);
    expect(find.textContaining('Khu vực được phân công ('), findsNothing);
    p.dispose();
  });
}
