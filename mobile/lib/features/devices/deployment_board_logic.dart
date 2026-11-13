import '../../core/models/iot_deployment.dart';

/// Các bước của một yêu cầu triển khai theo thứ tự, dùng cho thanh tiến trình.
/// MaintenanceRequired là nhánh thất bại của bước lắp đặt nên không có bước riêng.
const deploymentSteps = <({String status, String label})>[
  (status: 'Submitted', label: 'Gửi'),
  (status: 'Accepted', label: 'Tiếp nhận'),
  (status: 'Surveyed', label: 'Khảo sát'),
  (status: 'PlanConfirmed', label: 'Kế hoạch'),
  (status: 'Installing', label: 'Lắp đặt'),
  (status: 'Completed', label: 'Hoàn tất triển khai'),
];

/// Vị trí (0..5) của trạng thái trên thanh tiến trình. Draft = -1; MaintenanceRequired đứng ở bước lắp đặt.
int deploymentStepIndex(String status) {
  if (status == 'MaintenanceRequired') return 4;
  return deploymentSteps.indexWhere((s) => s.status == status);
}

/// Chủ trại hủy được khi chưa bắt đầu lắp đặt (khớp backend: Draft → PlanConfirmed). Từ Installing trở đi
/// phải qua luồng thất bại/bảo trì vì thiết bị đã được cấp phát.
const cancellableDeploymentStatuses = {
  'Draft',
  'Submitted',
  'Accepted',
  'Surveyed',
  'PlanConfirmed',
};

bool canCancelDeployment(String status) =>
    cancellableDeploymentStatuses.contains(status);

/// Việc kỹ thuật viên cần làm tiếp theo ở mỗi trạng thái; null nếu không còn việc.
String? deploymentNextStepHint(String status) => switch (status) {
  'Submitted' => 'Tiếp nhận yêu cầu để bắt đầu',
  'Accepted' => 'Khảo sát địa điểm',
  'Surveyed' => 'Điều chỉnh kế hoạch rồi xác nhận',
  'PlanConfirmed' => 'Bắt đầu lắp đặt',
  'Installing' => 'Cấp phát thiết bị, kiểm tra kết nối rồi hoàn tất',
  'MaintenanceRequired' =>
    'Đã chuyển bảo trì, theo dõi ở tab Dịch Vụ › Phiếu dịch vụ',
  _ => null,
};

/// Nhóm hiển thị trên bảng việc của kỹ thuật viên.
enum BoardGroup {
  waiting('Chờ tiếp nhận'),
  active('Đang xử lý'),
  maintenance('Cần bảo trì'),
  done('Hoàn tất triển khai');

  final String label;
  const BoardGroup(this.label);
}

/// Nhóm của một trạng thái; null cho trạng thái không thuộc việc của kỹ thuật viên (Draft).
BoardGroup? boardGroupOf(String status) => switch (status) {
  'Submitted' => BoardGroup.waiting,
  'Accepted' ||
  'Surveyed' ||
  'PlanConfirmed' ||
  'Installing' => BoardGroup.active,
  'MaintenanceRequired' => BoardGroup.maintenance,
  'Completed' => BoardGroup.done,
  _ => null,
};

/// Thứ tự ưu tiên khi sắp xếp: việc đã làm dở gần xong lên trước (cần thao tác tiếp), rồi việc mới chờ tiếp nhận,
/// việc đã chuyển bảo trì và việc hoàn tất xuống cuối.
int boardUrgency(String status) => switch (status) {
  'Installing' => 0,
  'PlanConfirmed' => 1,
  'Surveyed' => 2,
  'Accepted' => 3,
  'Submitted' => 4,
  'MaintenanceRequired' => 5,
  'Completed' => 6,
  _ => 7,
};

/// Số yêu cầu theo từng nhóm (đủ 4 nhóm, kể cả nhóm 0).
Map<BoardGroup, int> boardCounts(Iterable<DeploymentRequest> items) {
  final counts = {for (final g in BoardGroup.values) g: 0};
  for (final r in items) {
    final g = boardGroupOf(r.status);
    if (g != null) counts[g] = counts[g]! + 1;
  }
  return counts;
}

/// Văn bản dùng để tìm kiếm của một yêu cầu: Zone, trang trại, thửa đất, địa điểm, cây và mã yêu cầu.
String boardSearchText(DeploymentRequest r) {
  final c = r.context;
  return [
    if (c != null) ...[
      c.zoneName,
      c.farmName,
      c.fieldName,
      c.farmLocation,
      c.cropName,
      c.varietyName,
    ],
    r.requestId,
  ].whereType<String>().join(' ').toLowerCase();
}

/// Lọc theo nhóm (null = tất cả) và từ khoá (bỏ trống = không lọc), rồi sắp theo mức khẩn; cùng mức thì giữ thứ tự gốc.
List<DeploymentRequest> boardView(
  List<DeploymentRequest> items, {
  BoardGroup? group,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final out = [
    for (final r in items)
      if (r.status != 'Draft' &&
          r.status != 'Cancelled' &&
          (group == null || boardGroupOf(r.status) == group) &&
          (q.isEmpty || boardSearchText(r).contains(q)))
        r,
  ];
  // List.sort không ổn định: gắn chỉ số gốc để giữ thứ tự của máy chủ khi cùng mức khẩn.
  final order = {for (var i = 0; i < out.length; i++) out[i]: i};
  out.sort((a, b) {
    final byUrgency = boardUrgency(a.status).compareTo(boardUrgency(b.status));
    return byUrgency != 0 ? byUrgency : order[a]!.compareTo(order[b]!);
  });
  return out;
}
