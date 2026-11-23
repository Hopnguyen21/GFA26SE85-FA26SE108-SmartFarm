// ignore_for_file: invalid_use_of_visible_for_testing_member
// LUỒNG 1 chạy thật bằng chính các hàm API/logic của mobile, trỏ vào một backend TẠM (DB tạm, cổng 5000) đã nạp seed demo.
// Không chạy trên backend/DB dev đang dùng vì test này ghi dữ liệu. Chạy: flutter test --no-pub test_live/live_flow1_e2e_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/acceptance_report_flow.dart';
import 'package:smartfarm_mobile/features/support/gateway_activation_flow.dart';
import 'package:smartfarm_mobile/features/support/node_placement_logic.dart';
import 'package:smartfarm_mobile/features/support/service_board_logic.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart'
    show serviceStatusOf;

const base = 'http://localhost:5000';
const pwd = 'Demo@12345';
const zoneId = '32000000-0000-0000-0000-000000000001';
const techId = '20000000-0000-0000-0000-000000000004';

Future<String> adminToken() async {
  final r = await http.post(
    Uri.parse('$base/api/v1/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': 'admin@smartfarm.demo', 'password': pwd}),
  );
  return (jsonDecode(r.body) as Map)['accessToken'] as String;
}

Future<http.Response> admin(String method, String path, [Object? body]) async {
  final h = {
    'Authorization': 'Bearer ${await adminToken()}',
    'Content-Type': 'application/json',
  };
  final u = Uri.parse('$base$path');
  return switch (method) {
    'POST' => http.post(u, headers: h, body: jsonEncode(body ?? {})),
    'PUT' => http.put(u, headers: h, body: jsonEncode(body ?? {})),
    _ => http.get(u, headers: h),
  };
}

Future<void> loginAs(String email) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  expect(await ApiService.login(email, pwd), isNotNull, reason: email);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test(
    'Luồng 1 đầu-cuối: yêu cầu → phân công → hợp đồng → cọc → phiếu xuất kho → duyệt → lắp đặt',
    () async {
      ApiService.baseUrl = base;
      // ignore: avoid_print
      void step(String s) => print('▶ $s');

      // 0. Admin: danh mục thiết bị phần cứng trong kho (để khớp mã khi lập phiếu xuất kho)
      for (final hw in [
        ['GW-E2E', 'Gateway E2E', 'Gateway', 'Gateway'],
        ['SN-E2E', 'Node cảm biến E2E', 'SensorNode', 'SensorNode'],
      ]) {
        final r = await admin('POST', '/api/v1/platform/hardware-items', {
          'code': hw[0],
          'name': hw[1],
          'category': hw[2],
          'quantityInStock': 10,
          'unitPrice': 1000000,
          'status': 'Available',
          'estimateRole': hw[3],
          // backend yêu cầu Serial cho Gateway/Node và MAC hợp lệ cho Gateway
          'serialNumber': 'SN-${hw[0]}',
          if (hw[2] == 'Gateway') 'macAddress': 'AA:BB:CC:00:00:01',
        });
        expect(
          r.statusCode,
          anyOf(200, 201),
          reason: 'tạo kho ${hw[0]}: ${r.body}',
        );
      }

      // 1. Owner gửi yêu cầu triển khai cho Zone
      step('Owner gửi yêu cầu triển khai');
      await loginAs('owner@smartfarm.demo');
      final dep = await DeploymentApi.submitDeploymentRequestWithEstimate(
        zoneId,
        notes: 'E2E luồng 1',
      );
      expect(dep.status, 'Submitted');
      final srs = await SupportApi.getServiceRequests();
      final sr = srs.firstWhere(
        (s) => '${s['deploymentRequestId']}' == dep.requestId,
      );
      final srId = '${sr['id']}';
      final farmId = '${sr['farmId']}';
      expect(serviceKindOf(sr), ServiceKind.installation);

      // 2. KTV CHƯA được phân công: không thấy, không mở được, không tự tiếp nhận được
      step('KTV chưa được phân công không thấy / không nhận được');
      await loginAs('technician@smartfarm.demo');
      final before = await DeploymentApi.getTechnicianDeploymentRequests();
      expect(before.any((d) => d.requestId == dep.requestId), isFalse);
      expect(
        (await SupportApi.getServiceRequests()).any(
          (s) => '${s['id']}' == srId,
        ),
        isFalse,
      );
      await expectLater(
        DeploymentApi.getDeploymentRequest(dep.requestId, technician: true),
        throwsA(anything),
      );
      await expectLater(
        DeploymentApi.acceptDeploymentRequest(dep.requestId),
        throwsA(anything),
      );

      // 3. Admin phân công KTV
      step('Admin phân công KTV');
      final assign = await admin(
        'POST',
        '/api/v1/service-requests/$srId/assign',
        {'technicianUserId': techId, 'notes': 'E2E'},
      );
      expect(assign.statusCode, 200, reason: assign.body);

      // 4. KTV thấy yêu cầu, tiếp nhận, ĐIỀN KHẢO SÁT THỰC ĐỊA (chưa khảo sát thì không tự xác nhận được kế hoạch),
      // rồi lập hợp đồng; gửi hợp đồng = tự xác nhận kế hoạch
      step('KTV lập và gửi hợp đồng (tự xác nhận kế hoạch)');
      final mine = await DeploymentApi.getTechnicianDeploymentRequests();
      expect(mine.any((d) => d.requestId == dep.requestId), isTrue);
      await DeploymentApi.acceptDeploymentRequest(dep.requestId);
      await expectLater(
        DeploymentApi.autoConfirmPlan(dep.requestId),
        throwsA(anything),
        reason: 'chưa khảo sát thì không xác nhận kế hoạch',
      );
      await DeploymentApi.surveyDeploymentRequest(
        dep.requestId,
        isFeasible: true,
        siteConditions: 'Mặt bằng và nguồn điện sẵn sàng.',
        notes: 'E2E khảo sát thực địa.',
      );
      final q = await SupportApi.createQuotation(
        srId,
        items: [
          for (final it in [
            ['GW-E2E', 'Gateway E2E', 'Gateway', 1],
            ['SN-E2E', 'Node cảm biến E2E', 'SensorNode', 2],
          ])
            {
              'code': it[0],
              'name': it[1],
              'category': it[2],
              'unit': 'Cái',
              'quantity': it[3],
              'unitPrice': 1000000,
              'vatPercent': 8,
            },
        ],
        notes: 'E2E điều khoản',
        contractTerms: 'E2E điều khoản',
      );
      expect(q.status, 'SentToOwner');
      final afterConfirm = await DeploymentApi.autoConfirmPlan(dep.requestId);
      expect(afterConfirm.status, 'PlanConfirmed');

      // 5. Chưa cọc: cổng Gắn Node khoá vì chưa cọc
      var gate = checkNodePlacement(
        serviceStatus: serviceStatusOf(
          await SupportApi.getServiceRequest(srId),
        ),
        quotationLoaded: true,
        quotationStatus: q.status,
        deploymentStatus: afterConfirm.status,
        linkValid: true,
      );
      expect(gate.allowed, isFalse);
      expect(gate.block, NodePlacementBlock.unpaid);
      // backend cũng không cho bắt đầu lắp đặt khi chưa cọc
      await expectLater(
        DeploymentApi.startDeploymentInstallation(dep.requestId),
        throwsA(anything),
      );

      // 6. Owner ký hợp đồng và cọc (giả lập, không có cổng thanh toán thật)
      step('Owner ký hợp đồng và cọc');
      await loginAs('owner@smartfarm.demo');
      final qOwner = await SupportApi.getQuotation(srId);
      expect(qOwner, isNotNull);
      final pay = await SupportApi.signContractAndPayDeposit(
        srId,
        signerFullName: 'Chủ trại E2E',
        paymentMethod: 'BankTransfer',
        transactionReference: 'E2E-DEP-001',
        expectedDepositAmount: qOwner!.deposit30,
      );
      expect(pay.amount, qOwner.deposit30);

      // 7. Cọc xong là gắn Node được (phiếu xuất kho là chức năng riêng, không chặn)
      step('Cổng Gắn Node sau cọc');
      await loginAs('technician@smartfarm.demo');
      final srAfter = await SupportApi.getServiceRequest(srId);
      gate = checkNodePlacement(
        serviceStatus: serviceStatusOf(srAfter),
        quotationLoaded: true,
        quotationStatus: 'SignedByOwner',
        deploymentStatus: 'PlanConfirmed',
        linkValid: true,
      );
      expect(gate.allowed, isTrue, reason: gate.message);

      // 9. Bắt đầu lắp đặt → Installing; hoàn tất khi chưa gắn thiết bị bị backend từ chối
      step('Bắt đầu lắp đặt');
      final installing = await DeploymentApi.startDeploymentInstallation(
        dep.requestId,
      );
      expect(installing.status, 'Installing');
      await expectLater(
        DeploymentApi.completeDeploymentRequest(dep.requestId),
        throwsA(anything),
      );
      final still = await DeploymentApi.getDeploymentRequest(
        dep.requestId,
        technician: true,
      );
      expect(still.status, 'Installing');
      expect(
        still.planItems,
        isNotEmpty,
        reason: 'backend tự dựng kế hoạch khi xác nhận',
      );

      // 10. Gateway: backend đã tắt cấp phát tay (410). Admin giao một Gateway thật (có MAC) cho KTV; chưa có phần cứng nên MÔ PHỎNG:
      // app đóng vai thiết bị tự đăng ký (API công khai) rồi KTV kích hoạt cho yêu cầu. (Cấp phát Node cần quy trình chuẩn bị phần cứng
      // mới của backend nên chưa nằm trong luồng chạy thật này.)
      step('Mô phỏng Gateway: tự đăng ký + kích hoạt cho yêu cầu');
      final gwItem = await admin('POST', '/api/v1/platform/hardware-items', {
        'code': 'GW-SIM-${dep.requestId.substring(0, 6)}',
        'name': 'Gateway mô phỏng',
        'category': 'Gateway',
        'serialNumber': 'SN-SIM-${dep.requestId.substring(0, 6)}',
        'macAddress': 'AA:BB:CC:DD:EE:0F',
        'quantityInStock': 1,
        'unitPrice': 1000000,
        'status': 'InWarehouse',
      });
      expect(gwItem.statusCode, anyOf(200, 201), reason: gwItem.body);
      final gwItemId = (jsonDecode(gwItem.body) as Map)['id'] as String;
      final giveGw = await admin(
        'POST',
        '/api/v1/platform/hardware-items/$gwItemId/assign',
        {
          'technicianUserId': '20000000-0000-0000-0000-000000000004',
          'quantity': 1,
        },
      );
      expect(giveGw.statusCode, 200, reason: giveGw.body);
      await loginAs('technician@smartfarm.demo');
      final gatewaysBefore = (await DeploymentApi.getFarmGateways(
        farmId,
      )).length; // trang trại demo đã có sẵn Gateway khác
      final msg = await simulateGatewayForDeployment(
        farmId: farmId,
        deploymentRequestId: dep.requestId,
      );
      expect(msg, contains('GW-SIM'));
      final gateways = await DeploymentApi.getFarmGateways(farmId);
      expect(
        gateways,
        hasLength(gatewaysBefore + 1),
        reason: 'Gateway của đợt lắp đặt đã được kích hoạt',
      );
      expect(gateways.any((g) => g.gatewaySerial.startsWith('SN-SIM')), isTrue);
      // đăng ký/kích hoạt lần nữa không tạo Gateway thứ hai
      await expectLater(
        simulateGatewayForDeployment(
          farmId: farmId,
          deploymentRequestId: dep.requestId,
        ),
        throwsA(anything),
      );
      expect(
        await DeploymentApi.getFarmGateways(farmId),
        hasLength(gatewaysBefore + 1),
      );

      // 11. Phiếu xuất kho (chức năng riêng): Admin có 2 Node theo serial ở KHO CHÍNH; KTV tạo phiếu, Admin hoàn thành
      // → Node vào KHO KTV (kho chính không còn). Cọc xong gắn Node không cần phiếu (đã kiểm ở bước 7).
      step('Phiếu xuất kho: kho chính → kho KTV');
      final tag = dep.requestId.substring(0, 6);
      final nodeIds = <String>[];
      final nodeSerials = <String>[];
      for (var i = 1; i <= 2; i++) {
        final r = await admin('POST', '/api/v1/platform/hardware-items', {
          'code': 'NODE-E2E-$i-$tag',
          'name': 'Node cảm biến E2E $i',
          'category': 'Node cảm biến',
          'serialNumber': 'SN-NODE-E2E-$i-$tag',
          'quantityInStock': 1,
          'unitPrice': 500000,
          'status': 'InWarehouse',
        });
        expect(r.statusCode, anyOf(200, 201), reason: r.body);
        nodeIds.add((jsonDecode(r.body) as Map)['id'] as String);
        nodeSerials.add('SN-NODE-E2E-$i-$tag');
      }
      // trước phiếu: kho KTV chưa có hai Node này
      var spare = await DeploymentApi.getTechnicianSpareParts();
      expect(spare.any((p) => nodeIds.contains('${p['id']}')), isFalse);
      final voucher = await StockOutApi.create(
        farmId,
        zoneId: zoneId,
        notes: 'E2E cấp Node cho KTV',
        serviceRequestId: srId,
        details: [
          for (final id in nodeIds)
            {'inventoryItemId': id, 'quantity': 1, 'notes': ''},
        ],
      );
      final voucherId = '${voucher['id']}';
      await StockOutApi.setStatus(farmId, voucherId, 'Pending');
      // chưa hoàn thành: hàng vẫn ở kho chính
      spare = await DeploymentApi.getTechnicianSpareParts();
      expect(spare.any((p) => nodeIds.contains('${p['id']}')), isFalse);
      final done = await admin(
        'PUT',
        '/api/v1/farms/$farmId/stock-outs/$voucherId/status',
        {'status': 'Completed'},
      );
      expect(done.statusCode, 200, reason: done.body);
      spare = await DeploymentApi.getTechnicianSpareParts();
      expect(
        nodeIds.every((id) => spare.any((p) => '${p['id']}' == id)),
        isTrue,
        reason: 'hai Node phải vào kho KTV sau khi Admin hoàn thành phiếu',
      );
      // phiếu đã hoàn thành không hoàn thành lại được (không trừ kho hai lần)
      final again = await admin(
        'PUT',
        '/api/v1/farms/$farmId/stock-outs/$voucherId/status',
        {'status': 'Completed'},
      );
      expect(again.statusCode, 409);

      // 12. KTV gắn Node từ kho của mình → backend trừ kho KTV
      step('Gắn Node: lấy từ kho KTV');
      final gw = (await DeploymentApi.getFarmGateways(
        farmId,
      )).firstWhere((g) => g.gatewaySerial.startsWith('SN-SIM'));
      final provisioned = await DeploymentApi.provisionDevices(
        deploymentRequestId: dep.requestId,
        gatewayId: gw.gatewayId,
        farmId: farmId,
        nodes: [
          for (var i = 0; i < 2; i++)
            {
              'hardwareAddress': nodeSerials[i],
              'hardwareItemId': nodeIds[i],
              'deviceType': 'SensorNode',
            },
        ],
      );
      expect(provisioned, hasLength(2));
      spare = await DeploymentApi.getTechnicianSpareParts();
      expect(
        spare.any((p) => nodeIds.contains('${p['id']}')),
        isFalse,
        reason: 'Node đã gắn phải rời kho KTV',
      );
      // cùng thiết bị gắn cho địa chỉ khác: kho KTV không còn → bị từ chối
      await expectLater(
        DeploymentApi.provisionDevices(
          deploymentRequestId: dep.requestId,
          gatewayId: gw.gatewayId,
          farmId: farmId,
          nodes: [
            {
              'hardwareAddress': 'SN-REUSE-$tag',
              'hardwareItemId': nodeIds[0],
              'deviceType': 'SensorNode',
            },
          ],
        ),
        throwsA(anything),
      );
      // gọi lại đúng địa chỉ đã cấp phát: không lỗi, không trừ lần hai
      expect(
        await DeploymentApi.provisionDevices(
          deploymentRequestId: dep.requestId,
          gatewayId: gw.gatewayId,
          farmId: farmId,
          nodes: [
            {
              'hardwareAddress': nodeSerials[0],
              'hardwareItemId': nodeIds[0],
              'deviceType': 'SensorNode',
            },
          ],
        ),
        hasLength(1),
      );

      // 13. Chấm vị trí trong Zone + kiểm tra kết nối, rồi hoàn tất kèm ghi chú nghiệm thu
      step('Chấm Node, kết nối, hoàn tất kèm biên bản');
      final zone = await FarmApi.getZone(zoneId);
      final poly = zone.polygon!;
      final lat =
          poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length;
      final lng =
          poly.map((p) => p.longitude).reduce((a, b) => a + b) / poly.length;
      await FarmApi.updateDeviceLocations(
        zoneId,
        [
          for (var i = 0; i < 2; i++)
            {
              'deviceId': provisioned[i].deviceId,
              'latitude': lat + i * 0.00002,
              'longitude': lng + i * 0.00002,
              'hardwareAddress': provisioned[i].hardwareAddress,
              'deviceType': 'SensorNode',
              'locationSource': 'MobileMap',
              'deviceName': provisioned[i].hardwareAddress,
            },
        ],
        serviceRequestId: srId,
        deploymentRequestId: dep.requestId,
      );
      for (final d in provisioned) {
        await DeploymentApi.recordConnectionTest(
          dep.requestId,
          deviceId: d.deviceId,
          succeeded: true,
          rssi: -70,
          snr: 8,
          latencyMs: 120,
        );
      }
      const ktvNote = 'E2E: đã kiểm tra 2 node ngoài thực địa, kết nối ổn.';
      final completed = await DeploymentApi.completeDeploymentRequest(
        dep.requestId,
        notes: ktvNote,
      );
      expect(completed.status, 'Completed');
      expect(
        completed.history
            .where((h) => h.decisionType == 'DeploymentCompleted')
            .map((h) => h.notes)
            .last,
        ktvNote,
      );

      // 14. Owner xem biên bản nghiệm thu (dữ liệu thật) rồi ký + thanh toán 70%
      step('Owner xem biên bản và nghiệm thu');
      await loginAs('owner@smartfarm.demo');
      final ownerDep = await DeploymentApi.getDeploymentRequest(
        dep.requestId,
        technician: false,
      );
      final seenNote = ownerDep.history
          .where((h) => h.decisionType == 'DeploymentCompleted')
          .map((h) => h.notes ?? '')
          .last;
      expect(seenNote, ktvNote);
      final report = await loadAcceptanceReport(
        farmId: farmId,
        zoneId: zoneId,
        note: seenNote,
      );
      expect(report, isNotNull);
      // ignore: avoid_print
      print(
        '  biên bản: farm=${report!.farm} field=${report.field} zone=${report.zone} area=${report.area} nodes=${report.nodes.length} located=${report.located} connected=${report.connected}',
      );
      for (final a in nodeSerials) {
        expect(
          report.nodes.any((n) => n.address == a.toUpperCase()),
          isTrue,
          reason: a,
        );
      }
      expect(report.located, greaterThanOrEqualTo(2));
      expect(report.farm, isNot('—'));
      expect(report.zone, isNot('—'));
      final paid = await SupportApi.signAcceptanceAndPayFinal(
        srId,
        signerFullName: 'Chủ trại E2E',
        paymentMethod: 'BankTransfer',
        transactionReference: 'E2E-FINAL-1',
      );
      expect(paid.amount, greaterThan(0));
      expect((await SupportApi.getQuotation(srId))!.status, 'Completed');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
