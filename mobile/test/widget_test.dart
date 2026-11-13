// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartfarm_mobile/main.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/tasks/alerts_tasks_screen.dart';
import 'package:smartfarm_mobile/features/farmer/farmer_dashboard_screen.dart';
import 'package:smartfarm_mobile/features/contracts/contracts_depreciation_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/schedules_automation_screen.dart';
import 'package:smartfarm_mobile/features/auth/landing_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('SmartFarm app renders on small phone (320x568)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SmartFarm app renders on standard phone (390x844)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SmartFarm app renders on large phone (430x932)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SmartFarm app renders on tablet (768x1024)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AlertsTasksScreen renders on small phone (320x568) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: AlertsTasksScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertsTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AlertsTasksScreen renders on standard phone (390x844) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: AlertsTasksScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertsTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AlertsTasksScreen renders on tablet (768x1024) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: AlertsTasksScreen()),
        ),
      );
      expect(find.byType(AlertsTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FarmerDashboardScreen renders on small phone (320x568) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: FarmerDashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FarmerDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FarmerDashboardScreen renders on standard phone (390x844) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: FarmerDashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FarmerDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FarmerDashboardScreen renders on tablet (768x1024) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: FarmerDashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FarmerDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ContractsDepreciationScreen renders on standard phone without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: ContractsDepreciationScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ContractsDepreciationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SmartFarm app renders on standard phone (390x844)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SmartFarm app renders on large phone (430x932)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SmartFarm app renders on tablet (768x1024)', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
        child: const SmartFarmApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AlertsTasksScreen renders on small phone (320x568) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: AlertsTasksScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertsTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AlertsTasksScreen renders on standard phone (390x844) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: AlertsTasksScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertsTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AlertsTasksScreen renders on tablet (768x1024) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: AlertsTasksScreen()),
        ),
      );
      expect(find.byType(AlertsTasksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FarmerDashboardScreen renders on small phone (320x568) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: FarmerDashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FarmerDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FarmerDashboardScreen renders on standard phone (390x844) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: FarmerDashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FarmerDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'FarmerDashboardScreen renders on tablet (768x1024) without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: FarmerDashboardScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FarmerDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ContractsDepreciationScreen renders on standard phone without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: ContractsDepreciationScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ContractsDepreciationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SchedulesAutomationScreen renders on standard phone without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => FarmProvider())],
          child: const MaterialApp(home: SchedulesAutomationScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SchedulesAutomationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LandingScreen renders with all sections without overflow on standard and small phone',
    (WidgetTester tester) async {
      for (final size in [const Size(320, 600), const Size(390, 844)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(home: LandingScreen(onLoginSuccess: () {})),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(LandingScreen), findsOneWidget);
        expect(find.text('MỚI 2026'), findsOneWidget);
        expect(find.text('Trạm Gateway & Cảm Biến Bền Bỉ'), findsOneWidget);
        expect(find.text('Từ Khảo Sát Đến Nghiệm Thu'), findsOneWidget);
        expect(find.text('Đồng Hành Cùng Nông Nghiệp Xanh'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
