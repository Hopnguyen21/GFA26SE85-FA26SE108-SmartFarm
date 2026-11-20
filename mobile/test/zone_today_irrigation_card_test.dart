import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/theme/app_theme.dart';
import 'package:smartfarm_mobile/features/home/widgets/zone_today_irrigation_card.dart';

void main() {
  final testZone = ZoneModel(
    zoneId: 'test-zone-001',
    farmId: 'test-farm-001',
    name: 'Khu A - Dưa lưới',
    currentCrop: 'Dưa lưới Nhật',
    currentStage: 'Phát triển thân lá',
    areaM2: 1200,
    currentSoilMoisture: 65,
    currentTemp: 28,
    currentHumidity: 75,
    currentLux: 45000,
  );

  final testZoneNoCrop = ZoneModel(
    zoneId: 'test-zone-002',
    farmId: 'test-farm-001',
    name: 'Khu B - Trống',
    currentCrop: '',
    currentStage: '',
    seasonStatus: 'None',
    areaM2: 800,
    currentSoilMoisture: 50,
    currentTemp: 25,
    currentHumidity: 70,
    currentLux: 30000,
  );

  testWidgets('ZoneTodayIrrigationCard renders header, empty state & action keys', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZoneTodayIrrigationCard(zone: testZone),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Header & Keys
    expect(find.text('LỊCH TƯỚI HÔM NAY'), findsOneWidget);
    expect(find.byKey(const Key('home_irrigation_calendar')), findsOneWidget);
    expect(find.byKey(const Key('home_automation_schedules')), findsOneWidget);

    // Verify action buttons
    expect(find.text('Lịch vụ mùa'), findsOneWidget);
    expect(find.text('Cấu hình IoT'), findsOneWidget);
  });

  testWidgets('ZoneTodayIrrigationCard renders empty state with zone without crop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ZoneTodayIrrigationCard(zone: testZoneNoCrop),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LỊCH TƯỚI HÔM NAY'), findsOneWidget);
    expect(find.textContaining('chưa có vụ mùa đang chạy'), findsOneWidget);
  });

  testWidgets('ZoneTodayIrrigationCard renders cached schedules from FarmProvider', (tester) async {
    final provider = FarmProvider();

    // Seed mock schedules in provider matching test-zone-001
    final s1 = ScheduleModel(
      scheduleId: 'sch-01',
      zoneId: 'test-zone-001',
      name: 'Ca sáng dinh dưỡng',
      zoneName: 'Khu A',
      actuatorName: 'Bơm tưới nhỏ giọt A1',
      startTime: '06:30',
      durationMinutes: 20,
      daysOfWeek: const ['*'],
      enableRainDelay: true,
      isEnabled: true,
    );

    final s2 = ScheduleModel(
      scheduleId: 'sch-02',
      zoneId: 'test-zone-001',
      name: 'Ca chiều giữ ẩm',
      zoneName: 'Khu A',
      actuatorName: 'Van điện từ V1',
      startTime: '16:00',
      durationMinutes: 15,
      daysOfWeek: const ['*'],
      enableRainDelay: false,
      isEnabled: false,
    );

    // Add to provider list
    provider.schedules.addAll([s1, s2]);

    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZoneTodayIrrigationCard(zone: testZone),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify both sessions rendered
    expect(find.text('Ca sáng dinh dưỡng'), findsOneWidget);
    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('20 phút'), findsOneWidget);
    expect(find.text('Bơm tưới nhỏ giọt A1'), findsOneWidget);
    expect(find.textContaining('Hoãn khi mưa >70%'), findsOneWidget);

    expect(find.text('Ca chiều giữ ẩm'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(find.text('15 phút'), findsOneWidget);
    expect(find.text('Van điện từ V1'), findsOneWidget);
    expect(find.text('Tạm dừng'), findsOneWidget);

    provider.dispose();
  });

  testWidgets('ZoneTodayIrrigationCard updates when zone changes (didUpdateWidget)', (tester) async {
    final provider = FarmProvider();

    Widget buildCard(ZoneModel z) => ChangeNotifierProvider<FarmProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ZoneTodayIrrigationCard(zone: z),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildCard(testZone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Khu A - Dưa lưới'), findsWidgets);

    // Update with testZoneNoCrop
    await tester.pumpWidget(buildCard(testZoneNoCrop));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Khu B - Trống'), findsWidgets);
    expect(find.textContaining('Khu A - Dưa lưới'), findsNothing);

    provider.dispose();
  });

  testWidgets('ZoneTodayIrrigationCard layout stability at 320px font 1.3x', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = FarmProvider();

    provider.schedules.add(
      ScheduleModel(
        scheduleId: 'sch-stress',
        zoneId: 'test-zone-001',
        name: 'Ca tưới cực dài kiểm tra tràn màn hình nhỏ',
        zoneName: 'Khu A',
        actuatorName: 'Hệ thống van phun mưa phân khu trung tâm',
        startTime: '07:45',
        durationMinutes: 25,
        daysOfWeek: const ['*'],
        enableRainDelay: true,
        isEnabled: true,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FarmProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZoneTodayIrrigationCard(zone: testZone),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('LỊCH TƯỚI HÔM NAY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    provider.dispose();
  });
}
