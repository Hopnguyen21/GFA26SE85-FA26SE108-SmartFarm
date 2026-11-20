// Quy tắc kiểm tra form hợp đồng thuê Zone (thuần Dart để kiểm thử). Khớp CreateZoneContractCommand của backend:
// bên thuê bắt buộc, ngày kết thúc sau ngày bắt đầu, tiền không âm, chiết khấu 0–50%.
// Giá trị chính thức (tổng, VAT/chiết khấu tự động, tiền cọc mặc định 30%) do backend tính; app chỉ ước tính.
import '../../core/models/models.dart' show ZoneContractModel;

/// Số tháng giống cách backend tính: chênh lệch năm*12 + tháng, tối thiểu 1.
int contractMonthsBetween(DateTime start, DateTime end) {
  final m = (end.year - start.year) * 12 + end.month - start.month;
  return m < 1 ? 1 : m;
}

/// Zone phải thuộc đúng Farm của hợp đồng (backend từ chối Zone ngoài tenant/farm).
bool zoneBelongsToFarm({required String zoneFarmId, required String farmId}) =>
    zoneFarmId.isNotEmpty && zoneFarmId.toLowerCase() == farmId.toLowerCase();

String? validateZoneContractInput({
  required bool isOwner,
  required bool zoneInSelectedFarm,
  required String lesseeName,
  String? lesseePhone,
  String? lesseeIdentity,
  required double? monthlyRent,
  required DateTime start,
  required DateTime end,
  String? discountPercentText,
  String? depositText,
  double? depositValue,
}) {
  if (!isOwner) return 'Chỉ chủ trang trại mới được lập hợp đồng Zone.';
  if (!zoneInSelectedFarm)
    return 'Zone được chọn không thuộc trang trại đang chọn.';
  if (lesseeName.trim().length < 2)
    return 'Nhập tên bên ký hợp đồng (ít nhất 2 ký tự).';
  final phone = (lesseePhone ?? '').replaceAll(RegExp(r'[\s.\-]'), '');
  if (phone.isNotEmpty && !RegExp(r'^\+?\d{9,12}$').hasMatch(phone)) {
    return 'Số điện thoại không hợp lệ (9–12 chữ số).';
  }
  final id = (lesseeIdentity ?? '').replaceAll(RegExp(r'\s'), '');
  if (id.isNotEmpty && !RegExp(r'^\d{9}$|^\d{12}$').hasMatch(id)) {
    return 'Số CCCD/CMND phải gồm 9 hoặc 12 chữ số.';
  }
  if (monthlyRent == null || monthlyRent <= 0)
    return 'Nhập giá trị hợp đồng mỗi tháng (lớn hơn 0).';
  if (!end.isAfter(start)) return 'Ngày kết thúc phải sau ngày bắt đầu.';
  final dText = (discountPercentText ?? '').trim();
  if (dText.isNotEmpty) {
    final d = double.tryParse(dText.replaceAll(',', '.'));
    if (d == null || d < 0 || d > 50) return 'Chiết khấu phải từ 0 đến 50%.';
  }
  if ((depositText ?? '').trim().isNotEmpty) {
    if (depositValue == null || depositValue < 0)
      return 'Tiền cọc không hợp lệ.';
    // Cọc không được vượt tổng giá trị trước chiết khấu (ước tính) — tránh nhập nhầm thừa số 0.
    final rawTotal = monthlyRent * contractMonthsBetween(start, end);
    if (depositValue > rawTotal) {
      return 'Tiền cọc vượt tổng giá trị ước tính của hợp đồng. Kiểm tra lại số tiền.';
    }
  }
  return null;
}

/// Hợp đồng chính cùng các hợp đồng bổ sung của nó (mua thêm thiết bị khi hợp đồng chính còn hạn).
class ContractGroup {
  final ZoneContractModel main;
  final List<ZoneContractModel> supplements;
  const ContractGroup(this.main, this.supplements);
}

/// Gom danh sách phẳng thành nhóm: hợp đồng có `parentContractId` trỏ tới một hợp đồng CHƯA bị thay thế (khác `Renewed`)
/// và có trong danh sách thì là hợp đồng bổ sung của nó; hợp đồng gia hạn (cha đã `Renewed`) hoặc không thấy cha thì đứng riêng.
/// Giữ thứ tự gốc của hợp đồng chính; hợp đồng bổ sung xếp theo thứ tự xuất hiện.
List<ContractGroup> groupContractsWithSupplements(
  List<ZoneContractModel> contracts,
) {
  final byId = {for (final c in contracts) c.id: c};
  bool isSupplement(ZoneContractModel c) {
    final p = c.parentContractId == null ? null : byId[c.parentContractId];
    return p != null && p.id != c.id && p.status != 'Renewed';
  }

  final children = <String, List<ZoneContractModel>>{};
  for (final c in contracts.where(isSupplement)) {
    children.putIfAbsent(c.parentContractId!, () => []).add(c);
  }
  return [
    for (final c in contracts.where((c) => !isSupplement(c)))
      ContractGroup(c, children[c.id] ?? const []),
  ];
}
