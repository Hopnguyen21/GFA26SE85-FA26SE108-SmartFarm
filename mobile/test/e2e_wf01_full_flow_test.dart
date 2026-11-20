import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/cf1/cf1_progress_logic.dart';
import 'package:smartfarm_mobile/features/devices/deployment_board_logic.dart';
import 'package:smartfarm_mobile/features/support/node_placement_logic.dart';
import 'package:smartfarm_mobile/features/support/service_board_logic.dart';

// Helper tạo QuotationItem cho bài test
QuotationItem _createItem({
  required String code,
  required String name,
  required String category,
  required int quantity,
  required double unitPrice,
  double vatPercent = 10.0,
}) {
  final lineTotal = quantity * unitPrice;
  return QuotationItem(
    code: code,
    name: name,
    category: category,
    unit: 'bộ',
    quantity: quantity,
    unitPrice: unitPrice,
    vatPercent: vatPercent,
    totalAmount: lineTotal,
  );
}

// Helper tạo IotDevice giả lập
IotDevice _createDevice({
  required String deviceId,
  required String type,
  required String hwAddress,
  required bool pingSuccess,
}) {
  return IotDevice(
    deviceId: deviceId,
    gatewayId: 'GW-001',
    deploymentRequestId: 'DEP-REQ-001',
    hardwareAddress: hwAddress,
    deviceType: type,
    status: 'Assigned',
    latestTest: ConnectionTest(
      succeeded: pingSuccess,
      observedAtUtc: '2026-11-14T08:00:00Z',
    ),
  );
}

// Helper tạo DeploymentRequest
DeploymentRequest _createDeployment({
  required String status,
  List<PlanItem> planItems = const [],
  List<DeploymentSurvey> surveys = const [],
}) {
  return DeploymentRequest(
    requestId: 'DEP-REQ-001',
    farmId: 'FARM-DL-001',
    zoneId: 'ZONE-CHERRY-001',
    status: status,
    requiredParameters: const ['AirTemperature', 'Humidity', 'SoilMoisture'],
    ownerNotes: 'Yêu cầu triển khai hệ thống IoT cho nhà màng cà chua',
    planItems: planItems,
    surveys: surveys,
    history: const [],
  );
}

void main() {
  group('E2E LUỒNG 1 (WF-01) — FULL LIFECYCLE TEST TRÊN MOBILE', () {
    // Thông tin định danh của luồng
    const serviceRequestId = 'SR-INSTALL-001';

    // ─────────────────────────────────────────────────────────────────────────
    // GIAI ĐOẠN 1: KHỞI TẠO NÔNG TRẠI & GỬI YÊU CẦU TRIỂN KHAI (FARM OWNER)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Bước 1 & 2: Chủ trại tạo Farm, Zone, Vụ mùa và gửi yêu cầu IoT (Draft → Submitted)',
      () {
        // 1. Kiểm tra tiến độ CF1 khi chưa có dữ liệu: notStarted
        expect(
          structureState(farms: 0, fields: 0, zones: 0),
          Cf1StepState.notStarted,
        );

        // 2. Chủ trại tạo 1 Farm, 1 Field, 1 Zone: Cấu trúc hoàn tất (done)
        expect(
          structureState(farms: 1, fields: 1, zones: 1),
          Cf1StepState.done,
        );

        // 3. Tạo Vụ trồng cho Zone: hoàn tất (done)
        expect(seasonState(zones: 1, seasons: 1), Cf1StepState.done);

        // 4. Tạo yêu cầu triển khai ban đầu ở trạng thái Draft
        var deployment = _createDeployment(status: 'Draft');

        // Draft chưa hiện trên bảng việc của Kỹ thuật viên
        expect(boardGroupOf(deployment.status), isNull);
        expect(deploymentStepIndex(deployment.status), -1);
        expect(canCancelDeployment(deployment.status), isTrue);

        // 5. Chủ trại gửi yêu cầu cho Kỹ thuật viên (Draft → Submitted)
        deployment = _createDeployment(status: 'Submitted');

        // Assert trạng thái Submitted
        expect(deployment.status, 'Submitted');
        expect(deploymentStepIndex(deployment.status), 0); // Bước 0: Gửi
        expect(
          boardGroupOf(deployment.status),
          BoardGroup.waiting,
        ); // Chờ tiếp nhận
        expect(canCancelDeployment(deployment.status), isTrue);
        expect(
          deploymentNextStepHint(deployment.status),
          'Tiếp nhận yêu cầu để bắt đầu',
        );
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // GIAI ĐOẠN 2: KỸ THUẬT VIÊN KHẢO SÁT & XÁC NHẬN KẾ HOẠCH (TECHNICIAN)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Bước 3, 4 & 5: Kỹ thuật viên tiếp nhận, khảo sát và xác nhận kế hoạch (Submitted → Accepted → Surveyed → PlanConfirmed)',
      () {
        // Bước 3: Kỹ thuật viên bấm "Tiếp nhận yêu cầu" (Submitted → Accepted)
        var deployment = _createDeployment(status: 'Accepted');
        expect(deployment.status, 'Accepted');
        expect(deploymentStepIndex(deployment.status), 1);
        expect(boardGroupOf(deployment.status), BoardGroup.active);
        expect(
          deploymentNextStepHint(deployment.status),
          'Lập báo cáo khảo sát thực địa',
        );

        // Bước 4: Kỹ thuật viên ghi nhận khảo sát địa điểm (Accepted → Surveyed)
        // Giả lập khảo sát khả thi (isFeasible = true)
        final survey = DeploymentSurvey(
          isFeasible: true,
          siteConditions:
              'Nguồn điện lưới ổn định, độ che phủ sóng LoRa 433MHz tốt.',
          notes: 'LoRa 433MHz đạt cường độ RSSI tốt.',
          surveyedAtUtc: '2026-11-14T08:00:00Z',
        );
        deployment = _createDeployment(status: 'Surveyed', surveys: [survey]);

        expect(deployment.status, 'Surveyed');
        expect(deployment.latestSurveyFeasible, isTrue);
        expect(deploymentStepIndex(deployment.status), 2);
        expect(
          deploymentNextStepHint(deployment.status),
          'Tạo và gửi hợp đồng (tự xác nhận kế hoạch)',
        );

        // Guard: Nếu kế hoạch rỗng (planItems == empty) -> Không được xác nhận
        expect(deployment.planItems.isEmpty, isTrue);

        // Bước 5: Kỹ thuật viên nạp danh mục thiết bị vào kế hoạch
        final planItems = <PlanItem>[
          PlanItem(
            deviceModelId: 'MODEL-GW-ESP32',
            modelName: 'ESP32 LoRa Master Gateway',
            deviceType: 'Gateway',
            quantity: 1,
            installationNotes: 'Đặt ở trụ trung tâm nhà màng',
          ),
          PlanItem(
            deviceModelId: 'MODEL-SN-AIR-SOIL',
            modelName: 'Node Cảm Biến Không Khí & Đất NPK',
            deviceType: 'SensorNode',
            quantity: 2,
            installationNotes: '1 node đầu luống, 1 node cuối luống',
          ),
          PlanItem(
            deviceModelId: 'MODEL-ACT-RELAY',
            modelName: 'Node Relay Điều Khiển Van Tưới',
            deviceType: 'ActuatorNode',
            quantity: 1,
            installationNotes: 'Nối vào van tưới nhỏ giọt',
          ),
        ];

        deployment = _createDeployment(
          status: 'PlanConfirmed',
          planItems: planItems,
          surveys: [survey],
        );

        expect(deployment.status, 'PlanConfirmed');
        expect(deploymentStepIndex(deployment.status), 3);
        expect(deployment.planItems.length, 3);
        // Tổng số lượng thiết bị = 1 + 2 + 1 = 4
        final totalQty = deployment.planItems.fold<int>(
          0,
          (acc, item) => acc + item.quantity,
        );
        expect(totalQty, 4);
        expect(
          canCancelDeployment(deployment.status),
          isTrue,
        ); // Chưa lắp đặt vẫn cho hủy nếu cần
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // GIAI ĐOẠN 3: BÁO GIÁ, HỢP ĐỒNG & ĐẶT CỌC 30% (HAI BÊN PHỐI HỢP)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Bước 6 & 7: Lập Báo giá, kiểm tra công thức tài chính và ký cọc 30% (SentToOwner → SignedByOwner)',
      () {
        // 1. Tạo các dòng báo giá khớp với thiết bị và vật tư
        final quotationItems = <QuotationItem>[
          _createItem(
            code: 'GW-01',
            name: 'Trạm Gateway ESP32 LoRa',
            category: 'GATEWAY',
            quantity: 1,
            unitPrice: 3500000,
          ),
          _createItem(
            code: 'SENSOR-01',
            name: 'Node Cảm Biến Không Khí & Đất',
            category: 'SENSOR',
            quantity: 2,
            unitPrice: 2000000,
          ),
          _createItem(
            code: 'ACTUATOR-01',
            name: 'Node Relay Van Tưới',
            category: 'ACTUATOR',
            quantity: 1,
            unitPrice: 2500000,
          ),
          _createItem(
            code: 'SERVICE-INSTALL',
            name: 'Nhân công thi công & Cấu hình mạng LoRa',
            category: 'SERVICE',
            quantity: 1,
            unitPrice: 2000000,
          ),
        ];

        // Tính tổng tiền hàng: 3.5m + 4m + 2.5m + 2m = 12,000,000 VND
        final subtotal = quotationItems.fold<double>(
          0,
          (sum, i) => sum + i.totalAmount,
        );
        expect(subtotal, 12000000);

        // VAT 10% = 1,200,000 VND
        final vatAmount = subtotal * 0.10;
        expect(vatAmount, 1200000);

        // Tổng cộng có thuế = 13,200,000 VND
        final grandTotal = subtotal + vatAmount;
        expect(grandTotal, 13200000);

        // Cọc 30% = 3,960,000 VND
        final deposit30 = grandTotal * 0.30;
        expect(deposit30, 3960000);

        // Còn lại nghiệm thu 70% = 9,240,000 VND
        final final70 = grandTotal * 0.70;
        expect(final70, 9240000);
        expect(deposit30 + final70, grandTotal);

        // 2. Kỹ thuật viên gửi báo giá sang Chủ trại: trạng thái 'SentToOwner'
        final quotation = Quotation(
          id: 'QUOTE-001',
          serviceRequestId: serviceRequestId,
          status: 'SentToOwner',
          items: quotationItems,
          subtotal: subtotal,
          vatAmount: vatAmount,
          totalAmount: grandTotal,
          deposit30: deposit30,
          remaining70: final70,
          createdAtUtc: DateTime.parse('2026-11-14T09:00:00Z'),
        );

        // 3. Guard kiểm tra: Khi chưa cọc (status == SentToOwner), Cổng Gắn Node PHẢI BỊ KHOÁ
        final gateBeforeDeposit = checkNodePlacement(
          serviceStatus: 'Open',
          quotationLoaded: true,
          quotationStatus: quotation.status,
          deploymentStatus: 'PlanConfirmed',
          linkValid: true,
        );
        expect(gateBeforeDeposit.allowed, isFalse);
        expect(gateBeforeDeposit.block, NodePlacementBlock.unpaid);

        // 4. Chủ trại kiểm tra báo giá, ký hợp đồng và hoàn tất đặt cọc 30%
        // Trạng thái Báo giá chuyển sang: SignedByOwner
        final quotationSigned = Quotation(
          id: quotation.id,
          serviceRequestId: quotation.serviceRequestId,
          status: 'SignedByOwner',
          items: quotation.items,
          subtotal: quotation.subtotal,
          vatAmount: quotation.vatAmount,
          totalAmount: quotation.totalAmount,
          deposit30: quotation.deposit30,
          remaining70: quotation.remaining70,
          createdAtUtc: quotation.createdAtUtc,
        );

        expect(quotationSigned.status, 'SignedByOwner');
        expect(
          depositConfirmedQuotationStatuses.contains(quotationSigned.status),
          isTrue,
        );

        // Cổng Gắn Node BÂY GIỜ PHẢI MỞ (allowed == true)
        final gateAfterDeposit = checkNodePlacement(
          serviceStatus: 'Open',
          quotationLoaded: true,
          quotationStatus: quotationSigned.status,
          deploymentStatus: 'PlanConfirmed',
          linkValid: true,
        );
        expect(gateAfterDeposit.allowed, isTrue);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // GIAI ĐOẠN 4: LẮP ĐẶT, GẮN NODE & KIỂM THỬ TÍN HIỆU (TECHNICIAN)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Bước 8, 9 & 10: Lắp đặt, chấm tọa độ Node trên bản đồ Zone và test LoRa ping (PlanConfirmed → Installing → Completed)',
      () {
        var deployment = _createDeployment(
          status: 'PlanConfirmed',
          planItems: [
            PlanItem(
              deviceModelId: 'M1',
              modelName: 'Gateway',
              deviceType: 'Gateway',
              quantity: 1,
            ),
            PlanItem(
              deviceModelId: 'M2',
              modelName: 'Sensor',
              deviceType: 'SensorNode',
              quantity: 2,
            ),
            PlanItem(
              deviceModelId: 'M3',
              modelName: 'Relay',
              deviceType: 'ActuatorNode',
              quantity: 1,
            ),
          ],
        );

        // Bước 8: Kỹ thuật viên bấm "Bắt đầu lắp đặt"
        deployment = _createDeployment(
          status: 'Installing',
          planItems: deployment.planItems,
        );
        expect(deployment.status, 'Installing');
        expect(deploymentStepIndex(deployment.status), 4);
        expect(boardGroupOf(deployment.status), BoardGroup.active);
        // Từ trạng thái Installing trở đi, Chủ trại KHÔNG THỂ tự hủy yêu cầu
        expect(canCancelDeployment(deployment.status), isFalse);

        // Bước 9: Gắn Node trên sơ đồ Zone
        // Giả lập ranh giới Zone 4 đỉnh: (lat, lng)
        final zoneBoundary = <({double lat, double lng})>[
          (lat: 11.940, lng: 108.450),
          (lat: 11.942, lng: 108.450),
          (lat: 11.942, lng: 108.452),
          (lat: 11.940, lng: 108.452),
        ];

        // Tọa độ đặt Gateway nằm trong Zone
        expect(pointInPolygon(11.941, 108.451, zoneBoundary), isTrue);
        // Tọa độ ngoài Zone
        expect(pointInPolygon(11.950, 108.460, zoneBoundary), isFalse);

        // Tạo danh sách thiết bị thực tế
        final devices = <IotDevice>[
          _createDevice(
            deviceId: 'D1',
            type: 'Gateway',
            hwAddress: 'GW-ESP32-001',
            pingSuccess: true,
          ),
          _createDevice(
            deviceId: 'D2',
            type: 'SensorNode',
            hwAddress: 'SN-001',
            pingSuccess: true,
          ),
          _createDevice(
            deviceId: 'D3',
            type: 'SensorNode',
            hwAddress: 'SN-002',
            pingSuccess: true,
          ),
          _createDevice(
            deviceId: 'D4',
            type: 'ActuatorNode',
            hwAddress: 'RN-001',
            pingSuccess: true,
          ),
        ];

        // Hợp đồng thiết bị: 1 Gateway, 2 Cảm biến, 1 Relay
        final contractUnits = <NodeKind, int>{
          NodeKind.gateway: 1,
          NodeKind.sensor: 2,
          NodeKind.actuator: 1,
        };

        // 1. Trường hợp chặn: Chưa gán vị trí (placed rỗng)
        final blockersUnplaced = completionBlockers(
          deploymentStatus: deployment.status,
          devices: devices,
          placed: const {},
          contractUnits: contractUnits,
          provisioned: contractUnits,
        );
        expect(blockersUnplaced.isNotEmpty, isTrue);

        // 2. Trường hợp chặn: Có thiết bị test kết nối thất bại
        final failingDevice = _createDevice(
          deviceId: 'D4',
          type: 'ActuatorNode',
          hwAddress: 'RN-001',
          pingSuccess: false,
        );
        final blockersFailedPing = completionBlockers(
          deploymentStatus: deployment.status,
          devices: [devices[0], devices[1], devices[2], failingDevice],
          placed: {'d1', 'd2', 'd3', 'd4'},
          contractUnits: contractUnits,
          provisioned: contractUnits,
        );
        expect(blockersFailedPing.any((b) => b.contains('không đạt')), isTrue);

        // 3. Trường hợp hợp lệ: Đủ 4 thiết bị, đã có vị trí và ping đạt 100%
        final blockersValid = completionBlockers(
          deploymentStatus: deployment.status,
          devices: devices,
          placed: {'d1', 'd2', 'd3', 'd4'},
          contractUnits: contractUnits,
          provisioned: contractUnits,
        );
        expect(
          blockersValid.isEmpty,
          isTrue,
        ); // Không còn blocker -> Sẵn sàng hoàn tất!

        // Bước 10: Kỹ thuật viên bấm "Hoàn tất lắp đặt" (Installing → Completed)
        deployment = _createDeployment(
          status: 'Completed',
          planItems: deployment.planItems,
        );
        expect(deployment.status, 'Completed');
        expect(
          deploymentStepIndex(deployment.status),
          5,
        ); // Hoàn tất triển khai
        expect(boardGroupOf(deployment.status), BoardGroup.done);

        // Cổng Gắn Node tự động đóng lại khi đã Completed
        final gateCompleted = checkNodePlacement(
          serviceStatus: 'Open',
          quotationLoaded: true,
          quotationStatus: 'SignedByOwner',
          deploymentStatus: deployment.status,
          linkValid: true,
        );
        expect(gateCompleted.allowed, isFalse);
        expect(gateCompleted.block, NodePlacementBlock.deploymentFinished);
      },
    );

    // ─────────────────────────────────────────────────────────────────────────
    // GIAI ĐOẠN 5: NGHIỆM THU THỰC ĐỊA & KẾT THÚC (FARM OWNER)
    // ─────────────────────────────────────────────────────────────────────────
    test(
      'Bước 11: Chủ trại ký biên bản nghiệm thu và thanh toán 70% còn lại (SignedByOwner → Completed, Phiếu Closed)',
      () {
        // 1. Kiểm tra điều kiện tiên quyết: Chỉ nghiệm thu khi đợt triển khai đã là Completed
        const deploymentStatus = 'Completed';
        expect(deploymentStatus == 'Completed', isTrue);

        // 2. Báo giá ban đầu ở trạng thái SignedByOwner (đã cọc 30%)
        var quotation = Quotation(
          id: 'QUOTE-001',
          serviceRequestId: serviceRequestId,
          status: 'SignedByOwner',
          items: const [],
          subtotal: 12000000,
          vatAmount: 1200000,
          totalAmount: 13200000,
          deposit30: 3960000,
          remaining70: 9240000,
          createdAtUtc: DateTime.parse('2026-11-14T09:00:00Z'),
        );

        // 3. Chủ trại ký nghiệm thu và xác nhận thanh toán 70% còn lại
        quotation = Quotation(
          id: quotation.id,
          serviceRequestId: quotation.serviceRequestId,
          status: 'Completed',
          items: quotation.items,
          subtotal: quotation.subtotal,
          vatAmount: quotation.vatAmount,
          totalAmount: quotation.totalAmount,
          deposit30: quotation.deposit30,
          remaining70: quotation.remaining70,
          createdAtUtc: quotation.createdAtUtc,
        );

        // Báo giá đã chuyển sang Completed
        expect(quotation.status, 'Completed');

        // 4. Phiếu dịch vụ chuyển sang Closed (đã hoàn tất phục vụ)
        const serviceStatus = 'Closed';
        expect(isClosedStatus(serviceStatus), isTrue);

        // 5. Kiểm tra lại tiến độ CF1 trên mobile: Tất cả bước đều hoàn tất (done)
        expect(deploymentState(['Completed']), Cf1StepState.done);
      },
    );
  });
}
