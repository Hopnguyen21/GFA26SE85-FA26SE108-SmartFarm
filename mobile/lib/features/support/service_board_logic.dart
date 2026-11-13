/// Logic thuần cho danh sách yêu cầu dịch vụ của kỹ thuật viên (lắp đặt và bảo trì), tách khỏi giao diện để kiểm thử.
/// Dữ liệu là JSON của `GET /service-requests` (ServiceRequestView) cộng báo giá/bản đồ tải thêm.
library;

/// Mã lỗi của yêu cầu lắp đặt: `INSTALLATION` do luồng triển khai IoT tạo, `NEW_INSTALL` do cổng dịch vụ tạo.
const installationFailureCodes = {'INSTALLATION', 'NEW_INSTALL'};

enum ServiceKind { installation, maintenance }

/// Loại yêu cầu theo mã lỗi (không phân biệt hoa thường). Mọi mã khác là bảo trì/sửa chữa.
ServiceKind serviceKindOf(Map<String, dynamic> r) =>
    installationFailureCodes.contains('${r['failureCode'] ?? ''}'.toUpperCase())
    ? ServiceKind.installation
    : ServiceKind.maintenance;

/// Bộ lọc/ô tóm tắt của bảng. Lắp đặt và bảo trì chỉ tính các yêu cầu CHƯA đóng.
enum ServiceFilter {
  installation('Lắp đặt mới'),
  maintenance('Bảo trì / sửa chữa'),
  ready('Sẵn sàng đóng'),
  closed('Đã đóng');

  final String label;
  const ServiceFilter(this.label);
}

/// Yêu cầu đã giải quyết/đóng: kỹ thuật viên không còn việc phải làm.
bool isClosedStatus(String status) => status == 'Closed';

/// Đã sửa/lắp xong và kiểm tra, đang chờ kỹ thuật viên đóng yêu cầu.
bool isReadyToClose(String status) => status == 'Verified';

/// Yêu cầu có thuộc bộ lọc [f] không.
bool serviceMatches(Map<String, dynamic> r, String status, ServiceFilter f) =>
    switch (f) {
      ServiceFilter.installation =>
        !isClosedStatus(status) &&
            !isReadyToClose(status) &&
            serviceKindOf(r) == ServiceKind.installation,
      ServiceFilter.maintenance =>
        !isClosedStatus(status) &&
            !isReadyToClose(status) &&
            serviceKindOf(r) == ServiceKind.maintenance,
      ServiceFilter.ready => isReadyToClose(status),
      ServiceFilter.closed => isClosedStatus(status),
    };

/// Thứ tự ưu tiên: việc mới giao cần nhận trước, rồi việc đang làm, rồi việc chờ đóng, cuối cùng việc đã đóng.
int serviceUrgency(String status) => switch (status) {
  'Assigned' => 0,
  'Open' => 1,
  'InProgress' => 2,
  'Diagnosed' => 3,
  'WorkCompleted' => 4,
  'Verified' => 5,
  'Resolved' => 6,
  'Closed' => 8,
  _ => 7,
};

/// Số yêu cầu theo từng bộ lọc (đủ 4 mục kể cả mục 0).
Map<ServiceFilter, int> serviceCounts(
  List<Map<String, dynamic>> items,
  String Function(Map<String, dynamic>) statusOf,
) {
  final counts = {for (final f in ServiceFilter.values) f: 0};
  for (final r in items) {
    final s = statusOf(r);
    for (final f in ServiceFilter.values) {
      if (serviceMatches(r, s, f)) counts[f] = counts[f]! + 1;
    }
  }
  return counts;
}

/// Câu mô tả ngắn của yêu cầu: câu đầu của mô tả; không có thì dùng mã lỗi.
String serviceTitle(Map<String, dynamic> r) {
  final d = '${r['description'] ?? ''}'.trim();
  final first = d.split(RegExp(r'[.\n]')).first.trim();
  if (first.isNotEmpty) return first;
  final code = '${r['failureCode'] ?? ''}'.trim();
  return code.isEmpty ? 'Yêu cầu hỗ trợ kỹ thuật' : code;
}

/// Giai đoạn báo giá/hợp đồng của yêu cầu lắp đặt, theo trạng thái báo giá backend
/// (SentToOwner → SignedByOwner → Completed). null = chưa có báo giá.
String contractStageLabel(String? quotationStatus) => switch (quotationStatus) {
  null || '' || 'Draft' => 'Chưa tạo hợp đồng',
  'Completed' => 'Đã nghiệm thu 100%',
  'SignedByOwner' || 'DepositPaid' => 'Đã thanh toán 30% cọc',
  _ => 'Đã gửi HĐ · chờ Owner cọc 30%',
};

/// Lọc theo bộ lọc (null = tất cả) và từ khoá (bỏ trống = không lọc), rồi sắp theo mức khẩn;
/// cùng mức thì giữ thứ tự gốc (máy chủ trả mới nhất trước). [nameOf] cho tên Zone/trang trại để tìm kiếm.
List<Map<String, dynamic>> serviceView(
  List<Map<String, dynamic>> items, {
  required String Function(Map<String, dynamic>) statusOf,
  ServiceFilter? filter,
  String query = '',
  String Function(Map<String, dynamic>)? nameOf,
}) {
  final q = query.trim().toLowerCase();
  final out = <(Map<String, dynamic>, int)>[
    for (var i = 0; i < items.length; i++)
      if ((filter == null ||
              serviceMatches(items[i], statusOf(items[i]), filter)) &&
          (q.isEmpty ||
              [
                '${items[i]['description'] ?? ''}',
                '${items[i]['failureCode'] ?? ''}',
                if (nameOf != null) nameOf(items[i]),
              ].join(' ').toLowerCase().contains(q)))
        (items[i], i),
  ];
  out.sort((a, b) {
    final u = serviceUrgency(
      statusOf(a.$1),
    ).compareTo(serviceUrgency(statusOf(b.$1)));
    return u != 0 ? u : a.$2.compareTo(b.$2);
  });
  return [for (final e in out) e.$1];
}

/// Thao tác tiếp theo của KTV trên MỘT thẻ công việc lắp đặt (tab "Công việc"), theo tiến độ:
/// trước cọc 30%: tiếp nhận → khảo sát → tạo/gửi hợp đồng → chờ Owner thanh toán;
/// đã cọc: chuyển sang triển khai → chấm node, lưu vị trí, ghi kết nối → hoàn tất;
/// sau hoàn tất: chờ Owner thanh toán 70% và nghiệm thu → đóng công việc.
/// Dữ liệu chưa biết (null) thì không suy diễn là đã xong.
String installNextAction({
  String? serviceStatus,
  required String? quotationStatus,
  required String? deploymentStatus,
  required bool closed,
}) {
  if (closed) return 'Đã đóng công việc';
  final dep = deploymentStatus;
  if (dep == 'Cancelled') return 'Yêu cầu đã bị hủy';
  if (dep == 'MaintenanceRequired') {
    return 'Lắp đặt thất bại, theo dõi ở phiếu bảo trì';
  }
  if (quotationStatus == 'Completed') return 'Đóng công việc';
  if (dep == 'Completed') {
    return 'Chờ Owner thanh toán 70% và nghiệm thu';
  }
  final signed =
      quotationStatus == 'SignedByOwner' || quotationStatus == 'DepositPaid';
  if (signed) {
    return 'Gắn Node, lưu vị trí, ghi kết nối rồi hoàn tất';
  }
  final hasQuote =
      quotationStatus != null &&
      quotationStatus.isNotEmpty &&
      quotationStatus != 'Draft';
  if (hasQuote) return 'Chờ Owner thanh toán cọc 30%';
  return switch (dep) {
    'Accepted' => 'Khảo sát',
    'Surveyed' || 'PlanConfirmed' => 'Tạo và gửi hợp đồng',
    'Installing' => 'Gắn Node, lưu vị trí, ghi kết nối rồi hoàn tất',
    _ => 'Tiếp nhận',
  };
}

/// Việc của OWNER trên một phiếu lắp đặt: [needsAction] = đang chờ chính Owner (ký, thanh toán).
({String text, bool needsAction}) ownerNextAction({
  required String? quotationStatus,
  required String? deploymentStatus,
  required bool closed,
}) {
  if (closed) return (text: 'Đã đóng', needsAction: false);
  switch (quotationStatus) {
    case 'SentToOwner':
      return (
        text: 'Cần bạn: ký hợp đồng và thanh toán cọc 30%',
        needsAction: true,
      );
    case 'Completed':
      return (text: 'Đã thanh toán đủ và đã nghiệm thu', needsAction: false);
    case 'SignedByOwner':
    case 'DepositPaid':
      return deploymentStatus == 'Completed'
          ? (
              text: 'Cần bạn: ký nghiệm thu và thanh toán 70%',
              needsAction: true,
            )
          : (
              text: 'Đã cọc 30%, chờ kỹ thuật viên lắp đặt và hoàn tất',
              needsAction: false,
            );
    default:
      return (
        text: 'Chờ kỹ thuật viên khảo sát và gửi hợp đồng',
        needsAction: false,
      );
  }
}

/// Trạng thái một bước trong quy trình lắp đặt.
enum FlowStepState { done, current, todo }

/// Quy trình lắp đặt như trang Lắp đặt trên web: báo giá và hợp đồng → Owner ký và cọc 30% → thi công và chấm node →
/// nghiệm thu và thanh toán 70%. Suy ra từ trạng thái báo giá (null = chưa có), trạng thái triển khai (null = chưa biết)
/// và việc phiếu đã đóng. Dữ liệu chưa biết thì không coi là đã xong.
List<({String label, FlowStepState state})> installFlowSteps({
  required String? quotationStatus,
  required String? deploymentStatus,
  required bool closed,
}) {
  final hasQuote =
      quotationStatus != null &&
      quotationStatus.isNotEmpty &&
      quotationStatus != 'Draft';
  final signed =
      quotationStatus == 'SignedByOwner' ||
      quotationStatus == 'DepositPaid' ||
      quotationStatus == 'Completed';
  final accepted = quotationStatus == 'Completed' || closed;
  final built = deploymentStatus == 'Completed';

  FlowStepState pick({required bool done, required bool ready}) => done
      ? FlowStepState.done
      : ready
      ? FlowStepState.current
      : FlowStepState.todo;

  return [
    (label: 'Báo giá & hợp đồng', state: pick(done: hasQuote, ready: true)),
    (label: 'Owner ký & cọc 30%', state: pick(done: signed, ready: hasQuote)),
    (
      label: 'Thi công & chấm node',
      state: pick(done: built || accepted, ready: signed),
    ),
    (
      label: 'Nghiệm thu 70%',
      state: pick(done: accepted, ready: built || accepted),
    ),
  ];
}
