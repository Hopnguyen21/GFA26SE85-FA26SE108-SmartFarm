import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/cf1/cf1_progress_logic.dart';

void main() {
  test('cấu trúc: trống → chưa bắt đầu, có farm → đang xử lý, có Zone → hoàn tất', () {
    expect(structureState(farms: 0, fields: 0, zones: 0), Cf1StepState.notStarted);
    expect(structureState(farms: 1, fields: 0, zones: 0), Cf1StepState.inProgress);
    expect(structureState(farms: 1, fields: 1, zones: 2), Cf1StepState.done);
  });

  test('vụ trồng: có Zone mà chưa có vụ → cần xử lý; lỗi tải → unavailable', () {
    expect(seasonState(zones: 0, seasons: 0), Cf1StepState.notStarted);
    expect(seasonState(zones: 2, seasons: 0), Cf1StepState.needsAction);
    expect(seasonState(zones: 2, seasons: 1), Cf1StepState.done);
    expect(seasonState(zones: 2, seasons: null), Cf1StepState.unavailable);
  });

  test('hợp đồng là tuỳ chọn: không có hợp đồng chỉ là chưa bắt đầu', () {
    expect(contractState(contracts: 0), Cf1StepState.notStarted);
    expect(contractState(contracts: 1), Cf1StepState.done);
    expect(contractState(), Cf1StepState.unavailable);
  });

  test('nhân công: Farmer chưa có quyền Zone → cần xử lý', () {
    expect(staffState(farmers: 0, farmersWithoutZoneAccess: 0), Cf1StepState.notStarted);
    expect(staffState(farmers: 0, farmersWithoutZoneAccess: 0, pendingInvitations: 2), Cf1StepState.inProgress);
    expect(staffState(farmers: 2, farmersWithoutZoneAccess: 1), Cf1StepState.needsAction);
    expect(staffState(farmers: 2, farmersWithoutZoneAccess: 0), Cf1StepState.done);
  });

  test('IoT theo trạng thái server', () {
    expect(deploymentState(null), Cf1StepState.unavailable);
    expect(deploymentState([]), Cf1StepState.notStarted);
    expect(deploymentState(['Submitted', 'Completed']), Cf1StepState.inProgress);
    expect(deploymentState(['Completed']), Cf1StepState.done);
    expect(deploymentState(['Installing', 'MaintenanceRequired']), Cf1StepState.needsAction);
  });
}
