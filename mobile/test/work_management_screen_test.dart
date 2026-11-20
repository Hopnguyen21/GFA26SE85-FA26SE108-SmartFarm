import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/tasks/alerts_tasks_screen.dart';
import 'package:smartfarm_mobile/features/workforce/work_management_screen.dart';
import 'layout_overflow_test.dart' show route;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async => route(req)),
    );
  });

  testWidgets(
    'tab Công việc của Chủ trại: có Nhiệm vụ và Nhân công, chuyển qua lại được',
    (tester) async {
      ApiService.setTokens(
        accessToken: 't',
        refreshToken: 'r',
        email: 'a@b.c',
        role: 'FarmOwner',
      );
      final provider = FarmProvider();
      provider.switchRole('OWNER');
      await http.runWithClient(
        () => provider.fetchFromApi(),
        () => MockClient((req) async => route(req)),
      );
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          ChangeNotifierProvider<FarmProvider>.value(
            value: provider,
            child: const MaterialApp(home: WorkManagementScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Công Việc & Nhân Công'), findsOneWidget);
        expect(find.byType(TasksTabView), findsOneWidget);

        await tester.tap(find.text('Nhân Công'));
        await tester.pumpAndSettle();
        // Chỉ một AppBar (của màn Công việc); phần Nhân công nhúng, có nút thêm nhân công.
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Thêm nhân công'), findsOneWidget);
        expect(find.text('Quản lý Nhân công'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }, () => MockClient((req) async => route(req)));
      provider.dispose();
    },
  );
}
