import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/workforce/workforce_screen.dart';

Future<FarmProvider> _pump(WidgetTester tester, String role) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final provider = FarmProvider();
  provider.switchRole(role);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(home: WorkforceScreen()),
    ),
  );
  await tester.pump();
  return provider;
}

void main() {
  testWidgets('blocks non-owner', (tester) async {
    final provider = await _pump(tester, 'FARMER');
    expect(find.textContaining('Chỉ chủ trang trại'), findsOneWidget);
    provider.dispose();
  });

  testWidgets('owner without API data sees empty state, not sample farms', (tester) async {
    final provider = await _pump(tester, 'OWNER');
    expect(find.text('Chưa có trang trại nào.'), findsOneWidget);
    expect(find.textContaining('Đà Lạt'), findsNothing);
    provider.dispose();
  });
}
