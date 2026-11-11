import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/farms/farm_create_logic.dart';

Future<http.Response> Function(http.Request) handler = (_) async => http.Response('[]', 200);
final calls = <http.Request>[];

http.Response utf8Json(Object o, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(o)), code, headers: {'content-type': 'application/json; charset=utf-8'});

bool _isCreate(http.Request r) => r.method == 'POST' && r.url.path == '/api/v1/farms';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests(),
      () => MockClient((req) async {
        calls.add(req);
        return handler(req);
      }),
    );
  });

  setUp(() {
    calls.clear();
    handler = (_) async => http.Response('[]', 200);
    ApiService.setTokens(accessToken: 't', refreshToken: 'r', email: 'a@b.c', role: 'FarmOwner');
  });

  group('validateNewFarmInput / FarmCreateDraft', () {
    test('chưa chọn ghim: không dùng tọa độ mặc định', () {
      final d = FarmCreateDraft(nextNum: 1);
      d.addressCtrl.text = 'Xã A, Lâm Đồng';
      expect(d.pinConfirmed, isFalse);
      expect(d.validate(), contains('Chưa chọn vị trí'));
      expect(
        validateNewFarmInput(pinConfirmed: false, lat: farmMapViewLat, lng: farmMapViewLng, address: 'x'),
        isNotNull,
        reason: 'tọa độ mặc định không được coi là vị trí Farm',
      );
      d.dispose();
    });

    test('đã chọn ghim nhưng địa chỉ rỗng → không cho tạo', () {
      final d = FarmCreateDraft(nextNum: 1)..onPinChosen(11.94, 108.45);
      expect(d.validate(), contains('địa chỉ'));
      d.addressCtrl.text = '   ';
      expect(d.validate(), isNotNull);
      d.dispose();
    });

    test('ghim + địa chỉ nhập tay (khi reverse-geocode lỗi) → hợp lệ, địa chỉ không bị bản đồ ghi đè', () {
      final d = FarmCreateDraft(nextNum: 1)..onPinChosen(11.94, 108.45);
      d.addressSync.onLoading();
      d.addressSync.onFailed('502 providerUnavailable');
      expect(d.addressCtrl.text, isEmpty, reason: 'lỗi geocode không được ghi gì vào ô');
      d.addressCtrl.text = 'Thôn 3, tự nhập';
      d.addressSync.onUserChanged(d.addressCtrl.text);
      d.addressSync.onResolved('Địa chỉ từ bản đồ');
      expect(d.addressCtrl.text, 'Thôn 3, tự nhập');
      expect(d.validate(), isNull);
      expect(d.lat, 11.94);
      d.dispose();
    });

    test('tên mặc định chỉ dùng khi ô tên trống', () {
      final d = FarmCreateDraft(nextNum: 3);
      expect(d.effectiveName, 'Nông trại 03');
      d.nameCtrl.text = '  Trại của tôi ';
      expect(d.effectiveName, 'Trại của tôi');
      d.dispose();
    });
  });

  group('FarmNameAutofill', () {
    test('gợi ý khi ô trống và cập nhật gợi ý cũ khi vùng đổi', () {
      final c = TextEditingController();
      final n = FarmNameAutofill(c)..suggest('Nông trại CNC A (Cơ sở 01)');
      expect(c.text, 'Nông trại CNC A (Cơ sở 01)');
      n.suggest('Nông trại CNC B (Cơ sở 01)');
      expect(c.text, 'Nông trại CNC B (Cơ sở 01)');
    });

    test('không bao giờ ghi đè tên người dùng đã nhập', () {
      final c = TextEditingController();
      final n = FarmNameAutofill(c);
      c.text = 'Trại Hoa Hồng';
      n.onUserChanged(c.text);
      n.suggest('Nông trại CNC A (Cơ sở 01)');
      expect(c.text, 'Trại Hoa Hồng');
    });

    test('người dùng đã xoá trắng vẫn được tôn trọng (không tự điền lại)', () {
      final c = TextEditingController();
      final n = FarmNameAutofill(c)..suggest('Gợi ý');
      c.clear();
      n.onUserChanged('');
      n.suggest('Gợi ý khác');
      expect(c.text, isEmpty);
    });
  });

  group('parseCreatedFarmId', () {
    test('chấp nhận farmId/FarmId/id hợp lệ', () {
      expect(parseCreatedFarmId({'farmId': 'abc'}), 'abc');
      expect(parseCreatedFarmId({'FarmId': 'abc'}), 'abc');
      expect(parseCreatedFarmId({'id': 'abc'}), 'abc');
    });
    test('thiếu / rỗng / GUID rỗng / null → null', () {
      expect(parseCreatedFarmId({}), isNull);
      expect(parseCreatedFarmId({'farmId': ''}), isNull);
      expect(parseCreatedFarmId({'farmId': '00000000-0000-0000-0000-000000000000'}), isNull);
      expect(parseCreatedFarmId({'farmId': null}), isNull);
    });
  });

  group('FarmProvider.createFarm', () {
    test('gửi địa chỉ (không null) và tọa độ; thiếu địa chỉ thì không gửi gì', () async {
      handler = (r) async => _isCreate(r) ? utf8Json({'farmId': 'f-new'}, 201) : http.Response('[]', 200);
      final p = FarmProvider();
      final empty = await p.createFarm(name: 'F', address: '  ', totalAreaM2: 100, latitude: 11.9, longitude: 108.4);
      expect(empty.error, isNotNull);
      expect(calls.where(_isCreate), isEmpty);

      await p.createFarm(name: 'F', address: 'Xã A', totalAreaM2: 100, latitude: 11.9, longitude: 108.4);
      final body = jsonDecode(calls.firstWhere(_isCreate).body) as Map<String, dynamic>;
      expect(body['locationText'], 'Xã A');
      expect(body['latitude'], 11.9);
      expect(body['longitude'], 108.4);
      p.dispose();
    });

    test('response thiếu mã Farm → lỗi, không báo thành công, không đồng bộ giả', () async {
      handler = (r) async => _isCreate(r) ? utf8Json({'name': 'F'}, 201) : http.Response('[]', 200);
      final p = FarmProvider();
      final r = await p.createFarm(name: 'F', address: 'Xã A', totalAreaM2: 100, latitude: 11.9, longitude: 108.4);
      expect(r.created, isFalse);
      expect(r.error, contains('mã trang trại'));
      expect(p.farms, isEmpty);
      p.dispose();
    });

    test('tạo thành công nhưng tải lại lỗi → vẫn là đã tạo, giữ mã Farm, báo refreshFailed', () async {
      handler = (r) async {
        if (_isCreate(r)) return utf8Json({'farmId': 'f-new'}, 201);
        return http.Response('{"title":"boom"}', 500); // mọi lần tải lại đều lỗi
      };
      final p = FarmProvider();
      final r = await p.createFarm(name: 'F', address: 'Xã A', totalAreaM2: 100, latitude: 11.9, longitude: 108.4);
      expect(r.error, isNull);
      expect(r.created, isTrue);
      expect(r.farmId, 'f-new');
      expect(r.refreshFailed, isTrue);
      expect(p.selectedFarmId, 'f-new', reason: 'giữ mã Farm vừa tạo để thử đồng bộ lại');
      p.dispose();
    });

    test('tạo thành công và tải lại thấy Farm mới → chọn đúng Farm mới', () async {
      handler = (r) async {
        if (_isCreate(r)) return utf8Json({'farmId': 'f-new'}, 201);
        if (r.method == 'GET' && r.url.path == '/api/v1/farms') {
          return utf8Json([
            {'farmId': 'f-old', 'name': 'Cũ', 'totalAreaM2': 100},
            {'farmId': 'f-new', 'name': 'Mới', 'totalAreaM2': 100},
          ]);
        }
        return http.Response('[]', 200);
      };
      final p = FarmProvider();
      final r = await p.createFarm(name: 'Mới', address: 'Xã A', totalAreaM2: 100, latitude: 11.9, longitude: 108.4);
      expect(r.refreshFailed, isFalse);
      expect(p.selectedFarmId, 'f-new');
      p.dispose();
    });

    test('lỗi từ server (400) → trả lý do, không coi là đã tạo', () async {
      handler = (r) async => _isCreate(r) ? utf8Json({'message': 'Tên không hợp lệ'}, 400) : http.Response('[]', 200);
      final p = FarmProvider();
      final r = await p.createFarm(name: 'F', address: 'Xã A', totalAreaM2: 100, latitude: 11.9, longitude: 108.4);
      expect(r.created, isFalse);
      expect(r.error, isNotNull);
      p.dispose();
    });
  });

  group('runFarmCreate (form)', () {
    Future<(FarmProvider, FarmCreateDraft)> pumpForm(WidgetTester tester) async {
      final provider = FarmProvider();
      final draft = FarmCreateDraft(nextNum: 1);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (home) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    home,
                    MaterialPageRoute(
                      builder: (sheet) => Scaffold(
                        body: Builder(
                          builder: (ctx) => ElevatedButton(
                            onPressed: () => runFarmCreate(
                              sheetContext: sheet,
                              messenger: ScaffoldMessenger.of(home),
                              provider: provider,
                              draft: draft,
                              totalAreaM2: 100,
                            ),
                            child: const Text('Tạo'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      return (provider, draft);
    }

    testWidgets('chưa chọn ghim → báo yêu cầu chọn vị trí và không gửi request tạo', (tester) async {
      final (provider, draft) = await pumpForm(tester);
      draft.addressCtrl.text = 'Xã A';
      await tester.tap(find.text('Tạo'));
      await tester.pump();
      expect(find.textContaining('Chưa chọn vị trí'), findsOneWidget);
      expect(calls.where(_isCreate), isEmpty);
      await tester.pumpWidget(const SizedBox());
      draft.dispose();
      provider.dispose();
    });

    testWidgets('bấm lặp trong lúc đang gửi chỉ tạo một Farm', (tester) async {
      final gate = Completer<http.Response>();
      handler = (r) => _isCreate(r) ? gate.future : Future.value(http.Response('[]', 200));
      final (provider, draft) = await pumpForm(tester);
      draft
        ..onPinChosen(11.94, 108.45)
        ..addressCtrl.text = 'Xã A, Lâm Đồng';

      await tester.tap(find.text('Tạo'));
      await tester.pump();
      expect(draft.submitting, isTrue);
      await tester.tap(find.text('Tạo'));
      await tester.pump();
      expect(calls.where(_isCreate), hasLength(1));

      gate.complete(utf8Json({'farmId': 'f-new'}, 201));
      await tester.pumpAndSettle();
      expect(calls.where(_isCreate), hasLength(1));
      expect(draft.submitting, isFalse);
      await tester.pumpWidget(const SizedBox());
      draft.dispose();
      provider.dispose();
    });

    testWidgets('tạo được nhưng tải lại lỗi → thông báo "đã tạo, chưa tải lại được", có nút đồng bộ lại', (
      tester,
    ) async {
      handler = (r) async => _isCreate(r) ? utf8Json({'farmId': 'f-new'}, 201) : http.Response('boom', 500);
      final (provider, draft) = await pumpForm(tester);
      draft
        ..onPinChosen(11.94, 108.45)
        ..addressCtrl.text = 'Xã A, Lâm Đồng';

      await tester.tap(find.text('Tạo'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Đã tạo trang trại'), findsOneWidget);
      expect(find.textContaining('chưa tải lại được'), findsOneWidget);
      expect(find.text('Đồng bộ lại'), findsOneWidget);
      expect(find.textContaining('thất bại'), findsNothing);
      expect(provider.selectedFarmId, 'f-new');
      await tester.pumpWidget(const SizedBox());
      draft.dispose();
      provider.dispose();
    });
  });
}
