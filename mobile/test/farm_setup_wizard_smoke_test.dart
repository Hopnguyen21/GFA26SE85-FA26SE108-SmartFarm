import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/farms/farm_setup_wizard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'a@b.c',
      role: 'FarmOwner',
    );
  });

  testWidgets(
    'wizard 5 bước: hiện tiến trình, nút Tiếp tục cố định, chặn khi chưa nhập, không tràn ở 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = FarmProvider();
      await http.runWithClient(() async {
        provider.switchRole('OWNER');
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: const MaterialApp(home: FarmSetupWizardScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('Bước 1 / 5'), findsOneWidget);
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(find.text('Quay lại'), findsNothing);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump();
        expect(
          find.textContaining('Bước 1 / 5'),
          findsOneWidget,
          reason: 'chưa nhập thì không sang bước 2',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      }, () => MockClient((req) async => http.Response('[]', 200)));
      provider.dispose();
    },
  );
}
