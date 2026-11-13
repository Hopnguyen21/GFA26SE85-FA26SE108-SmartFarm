import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/features/contracts/zone_contract_forms.dart';

ZoneModel _zone(String id, String name) => ZoneModel.fromJson({
  'zoneId': id,
  'farmId': 'f1',
  'fieldId': 'fl1',
  'name': name,
  'areaM2': 1000,
});

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('contractMonths (khớp cách backend tính)', () {
    test(
      '6 tháng',
      () => expect(
        contractMonths(DateTime(2026, 1, 15), DateTime(2026, 7, 15)),
        6,
      ),
    );
    test(
      'qua năm',
      () => expect(
        contractMonths(DateTime(2026, 11, 1), DateTime(2027, 2, 1)),
        3,
      ),
    );
    test(
      'cùng tháng → tối thiểu 1',
      () => expect(
        contractMonths(DateTime(2026, 3, 1), DateTime(2026, 3, 20)),
        1,
      ),
    );
  });

  testWidgets('Owner bị chặn khi mở trực tiếp form tạo hợp đồng', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FarmProvider(),
        child: MaterialApp(
          home: ZoneContractCreateScreen(
            farmId: 'f1',
            zones: [_zone('z1', 'Nhà màng A')],
            existingContracts: const [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Owner không tự lập hợp đồng'), findsOneWidget);
    expect(find.text('Ký & lưu hợp đồng'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Farmer không thấy form tạo hợp đồng thuê Zone', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FarmProvider()..switchRole('FARMER'),
        child: MaterialApp(
          home: ZoneContractCreateScreen(
            farmId: 'f1',
            zones: [_zone('z1', 'A')],
            existingContracts: const [],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('không tự lập hợp đồng'), findsOneWidget);
    expect(find.text('Ký & lưu hợp đồng'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
