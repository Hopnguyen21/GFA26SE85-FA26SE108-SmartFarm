// Tính trạng thái từng bước CF1 từ dữ liệu THẬT do server trả về (thuần Dart để kiểm thử).
// Không có dữ liệu (null) nghĩa là chưa tải được → "unavailable", không đoán là hoàn tất.

enum Cf1StepState { notStarted, inProgress, done, needsAction, unavailable }

String cf1StateLabel(Cf1StepState s) => switch (s) {
  Cf1StepState.notStarted => 'Chưa bắt đầu',
  Cf1StepState.inProgress => 'Đang xử lý',
  Cf1StepState.done => 'Hoàn tất',
  Cf1StepState.needsAction => 'Cần xử lý',
  Cf1StepState.unavailable => 'Chưa tải được',
};

/// Bước 1: Farm → Lô → Zone.
Cf1StepState structureState({
  required int farms,
  required int fields,
  required int zones,
}) {
  if (zones > 0) return Cf1StepState.done;
  if (farms > 0 || fields > 0) return Cf1StepState.inProgress;
  return Cf1StepState.notStarted;
}

/// Bước 2: Vụ trồng — cần có Zone trước.
Cf1StepState seasonState({required int zones, int? seasons}) {
  if (seasons == null) return Cf1StepState.unavailable;
  if (seasons > 0) return Cf1StepState.done;
  return zones > 0 ? Cf1StepState.needsAction : Cf1StepState.notStarted;
}

/// Bước 3 (TUỲ CHỌN): hợp đồng thuê Zone. Không có hợp đồng không phải lỗi và không chặn IoT.
Cf1StepState contractState({int? contracts}) {
  if (contracts == null) return Cf1StepState.unavailable;
  return contracts > 0 ? Cf1StepState.done : Cf1StepState.notStarted;
}

/// Bước 4: Nhân công — Farmer chưa có quyền Zone nào thì chưa thể được giao việc.
Cf1StepState staffState({
  required int farmers,
  required int farmersWithoutZoneAccess,
  int? pendingInvitations,
}) {
  if (farmers > 0)
    return farmersWithoutZoneAccess > 0
        ? Cf1StepState.needsAction
        : Cf1StepState.done;
  if ((pendingInvitations ?? 0) > 0) return Cf1StepState.inProgress;
  return Cf1StepState.notStarted;
}

const _deployDone = {'Completed'};
const _deployProblem = {
  'MaintenanceRequired',
  'Failed',
  'Rejected',
  'Cancelled',
};

/// Bước 5: Triển khai IoT theo trạng thái yêu cầu trên server.
Cf1StepState deploymentState(List<String>? statuses) {
  if (statuses == null) return Cf1StepState.unavailable;
  if (statuses.isEmpty) return Cf1StepState.notStarted;
  if (statuses.any(_deployProblem.contains)) return Cf1StepState.needsAction;
  if (statuses.every(_deployDone.contains)) return Cf1StepState.done;
  return Cf1StepState.inProgress;
}
