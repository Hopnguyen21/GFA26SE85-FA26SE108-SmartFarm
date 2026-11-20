import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/gateway_activation_flow.dart';
import 'package:smartfarm_mobile/features/support/gateway_activation_logic.dart';

Map<String, dynamic> _part(
  String id,
  String code, {
  String category = 'Gateway',
  String? mac = 'AA:BB:CC:00:11:22',
  String? serial = 'SN-1',
}) => {
  'id': id,
  'code': code,
  'name': 'Gateway LoRa',
  'category': category,
  'macAddress': mac,
  'serialNumber': serial,
};

void main() {
  group('logic', () {
    test('chỉ lấy Gateway trong kho, gắn trạng thái đăng ký từng thiết bị', () {
      final list = gatewayChoices(
        [
          _part('g1', 'GW-1'),
          _part('n1', 'SN-1', category: 'Node cảm biến'),
          _part('g2', 'GW-2'),
          _part('g3', 'GW-3'),
        ],
        {
          'g1': {'id': 'e1', 'status': 'Enrolled'},
          'g2': null,
          'g3': {'id': 'e3', 'status': 'Activated', 'gatewayId': 'gw'},
        },
      );
      expect(list.map((g) => g.code), ['GW-1', 'GW-2', 'GW-3']);
      expect(list[0].canActivate, isTrue);
      expect(list[1].enrollmentId, isNull);
      expect(list[1].canSimulate, isTrue);
      expect(list[2].activated, isTrue);
      expect(list[2].canActivate, isFalse);
      expect(list[2].canSimulate, isFalse);
    });

    test(
      'chọn Gateway để mô phỏng: ưu tiên cái đã đăng ký, rồi cái chưa đăng ký có MAC',
      () {
        final a = gatewayChoices(
          [_part('g1', 'GW-1'), _part('g2', 'GW-2')],
          {
            'g1': null,
            'g2': {'id': 'e2', 'status': 'Enrolled'},
          },
        );
        expect(pickGatewayToSimulate(a)!.code, 'GW-2');
        final b = gatewayChoices(
          [_part('g1', 'GW-1', mac: null)],
          {'g1': null},
        );
        expect(pickGatewayToSimulate(b), isNull);
        expect(noGatewayToSimulateMessage(b), contains('MAC'));
        expect(
          noGatewayToSimulateMessage(const []),
          contains('chưa có Gateway'),
        );
        final c = gatewayChoices(
          [_part('g1', 'GW-1')],
          {
            'g1': {'id': 'e1', 'status': 'Activated'},
          },
        );
        expect(noGatewayToSimulateMessage(c), contains('đã được kích hoạt'));
      },
    );
  });

  group('luồng gọi API (MockClient)', () {
    final calls = <http.Request>[];
    late List<Map<String, dynamic>> parts;
    Map<String, dynamic>? enrollment; // đăng ký của g1 (null = 204)
    var activateFails = false;
    var simulateDisabled = false;

    http.Response json(Object o, [int code = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(o)),
      code,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    http.Response route(http.Request r) {
      calls.add(r);
      final p = r.url.path;
      if (p == '/api/v1/platform/technicians/me/spare-parts')
        return json(parts);
      if (p.startsWith('/api/v1/gateway-enrollment/by-hardware/')) {
        return enrollment == null ? http.Response('', 204) : json(enrollment!);
      }
      if (p == '/api/v1/gateway-enrollment/auto') {
        enrollment = {'id': 'e-new', 'status': 'Enrolled'};
        return json(enrollment!);
      }
      if (p == '/api/v1/gateway-enrollment/simulate') {
        if (simulateDisabled) {
          return json({
            'detail': 'Gateway simulation is disabled in this environment.',
          }, 404);
        }
        return json({
          'id': 'e-sim',
          'status': 'Activated',
          'gatewayId': 'gw-sim',
          'gatewaySerial': 'SIM-ABC123',
        });
      }
      if (p.endsWith('/activate')) {
        if (activateFails) {
          return json({
            'detail': 'Gateway bootstrap handshake has not been verified.',
          }, 409);
        }
        return json({
          'id': 'e-new',
          'status': 'Activated',
          'gatewayId': 'gw-1',
        });
      }
      return http.Response('', 404);
    }

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      ApiService.setTokens(
        accessToken: 't',
        refreshToken: 'r',
        email: 't@b.c',
        role: 'PlatformTechnician',
      );
      await http.runWithClient(
        () => SupportApi.getServiceRequests().catchError(
          (_) => <Map<String, dynamic>>[],
        ),
        () => MockClient((r) async => route(r)),
      );
    });

    setUp(() {
      calls.clear();
      parts = [_part('g1', 'GW-1'), _part('n1', 'SN-1', category: 'Node')];
      enrollment = null;
      activateFails = false;
      simulateDisabled = false;
    });

    test(
      'mô phỏng: tự đăng ký bằng MAC trong kho rồi kích hoạt cho đúng yêu cầu',
      () async {
        final msg = await simulateGatewayForDeployment(
          farmId: 'f1',
          deploymentRequestId: 'dep-1',
        );
        expect(msg, contains('GW-1'));
        final auto = calls.firstWhere(
          (c) => c.url.path == '/api/v1/gateway-enrollment/auto',
        );
        final autoBody = jsonDecode(auto.body) as Map;
        expect(autoBody['macAddress'], 'AA:BB:CC:00:11:22');
        expect(autoBody['chipId'], 'SIM-AABBCC001122');
        expect(autoBody['gatewaySerial'], 'SN-1');
        final act = calls.firstWhere((c) => c.url.path.endsWith('/activate'));
        expect(act.url.path, '/api/v1/gateway-enrollment/e-new/activate');
        expect(jsonDecode(act.body), {
          'farmId': 'f1',
          'deploymentRequestId': 'dep-1',
          'frequencyBand': '433MHz',
        });
      },
    );

    test('đã đăng ký sẵn: mô phỏng chỉ kích hoạt, không đăng ký lại', () async {
      enrollment = {'id': 'e-old', 'status': 'Enrolled'};
      await simulateGatewayForDeployment(
        farmId: 'f1',
        deploymentRequestId: 'dep-1',
      );
      expect(
        calls.where((c) => c.url.path == '/api/v1/gateway-enrollment/auto'),
        isEmpty,
      );
      expect(
        calls.any(
          (c) => c.url.path == '/api/v1/gateway-enrollment/e-old/activate',
        ),
        isTrue,
      );
    });

    test(
      'kho KTV không có Gateway: nhờ backend dựng Gateway mô phỏng (đăng ký + kích hoạt làm ở backend)',
      () async {
        parts = [_part('n1', 'SN-1', category: 'Node')];
        final msg = await simulateGatewayForDeployment(
          farmId: 'f1',
          deploymentRequestId: 'dep-1',
        );
        expect(msg, contains('SIM-ABC123'));
        final sim = calls.firstWhere(
          (c) => c.url.path == '/api/v1/gateway-enrollment/simulate',
        );
        expect(jsonDecode(sim.body), {
          'farmId': 'f1',
          'deploymentRequestId': 'dep-1',
        });
        expect(
          calls.where(
            (c) =>
                c.url.path.contains('gateway-enrollment/auto') ||
                c.url.path.endsWith('/activate'),
          ),
          isEmpty,
        );
      },
    );

    test(
      'môi trường không bật mô phỏng và kho không có Gateway: báo nhờ Admin giao Gateway',
      () async {
        parts = [_part('n1', 'SN-1', category: 'Node')];
        simulateDisabled = true;
        await expectLater(
          simulateGatewayForDeployment(
            farmId: 'f1',
            deploymentRequestId: 'dep-1',
          ),
          throwsA(predicate((e) => '$e'.contains('chưa có Gateway'))),
        );
      },
    );

    test(
      'backend từ chối kích hoạt: lỗi được ném ra để báo đúng lý do',
      () async {
        activateFails = true;
        await expectLater(
          simulateGatewayForDeployment(
            farmId: 'f1',
            deploymentRequestId: 'dep-1',
          ),
          throwsA(predicate((e) => '$e'.contains('handshake'))),
        );
      },
    );

    testWidgets('bảng kích hoạt: Mô phỏng → đóng bảng trả true', (t) async {
      t.view.physicalSize = const Size(480, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var done = false;
      await http.runWithClient(() async {
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async =>
                        done = await showGatewayActivationSheet(
                          context,
                          farmId: 'f1',
                          deploymentRequestId: 'dep-1',
                        ),
                    child: const Text('mở'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        expect(find.text('[GW-1] Gateway LoRa'), findsOneWidget);
        expect(find.textContaining('Chưa đăng ký'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('simulate-gateway')));
        await t.pumpAndSettle();
        expect(done, isTrue);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
      }, () => MockClient((r) async => route(r)));
    });

    testWidgets(
      'Gateway đã đăng ký có nút Kích hoạt; kích hoạt xong đóng bảng',
      (t) async {
        enrollment = {'id': 'e-old', 'status': 'Enrolled'};
        t.view.physicalSize = const Size(480, 1400);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        var done = false;
        await http.runWithClient(() async {
          await t.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async =>
                          done = await showGatewayActivationSheet(
                            context,
                            farmId: 'f1',
                            deploymentRequestId: 'dep-1',
                          ),
                      child: const Text('mở'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.tap(find.text('mở'));
          await t.pumpAndSettle();
          expect(find.text('Đã đăng ký, sẵn sàng kích hoạt'), findsOneWidget);
          await t.tap(find.byKey(const ValueKey('activate-g1')));
          await t.pumpAndSettle();
          expect(done, isTrue);
          expect(
            calls.any(
              (c) => c.url.path == '/api/v1/gateway-enrollment/e-old/activate',
            ),
            isTrue,
          );
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 1));
        }, () => MockClient((r) async => route(r)));
      },
    );
  });
}
