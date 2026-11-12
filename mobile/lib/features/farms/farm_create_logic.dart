import 'package:flutter/material.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/widgets/address_autofill.dart';
import 'farm_setup_logic.dart';

/// Logic dùng chung cho HAI form tạo Farm (Quản lý trang trại và thêm nhanh ở Trang chủ):
///  - tọa độ chỉ được gửi sau khi người dùng đã chọn/tìm vị trí (ghim), không dùng tọa độ mặc định;
///  - địa chỉ thực địa bắt buộc, không gửi `locationText: null`;
///  - tên Farm người dùng đã nhập không bị bản đồ ghi đè;
///  - chặn gửi lặp, và phân biệt "đã tạo" với "tải lại danh sách lỗi".

/// Vị trí khung nhìn ban đầu của bản đồ. KHÔNG phải vị trí Farm: chỉ là nơi bản đồ mở ra.
const farmMapViewLat = 11.8341;
const farmMapViewLng = 108.5724;

String? validateNewFarmInput({
  required bool pinConfirmed,
  required double? lat,
  required double? lng,
  required String address,
}) {
  if (!pinConfirmed || !isValidLatLng(lat, lng)) {
    return 'Chưa chọn vị trí trang trại. Kéo/chạm bản đồ hoặc dùng nút tìm kiếm để đặt ghim.';
  }
  if (address.trim().isEmpty) {
    return 'Nhập địa chỉ thực địa hoặc bấm "Lấy tên địa điểm từ ghim". Bạn có thể nhập tay khi không lấy được tên.';
  }
  return null;
}

/// Gợi ý tên Farm theo khu vực của bản đồ, nhưng không bao giờ ghi đè tên người dùng đã nhập.
class FarmNameAutofill {
  final TextEditingController controller;
  bool _userEdited = false;
  String? _lastSuggestion;

  FarmNameAutofill(this.controller);

  bool get userEdited => _userEdited;

  /// Gắn vào `TextField.onChanged` (chỉ chạy khi người dùng gõ).
  void onUserChanged(String _) => _userEdited = true;

  /// Chỉ đặt tên khi người dùng chưa sửa và ô còn trống hoặc vẫn đang là gợi ý trước đó.
  void suggest(String name) {
    if (_userEdited) return;
    final current = controller.text.trim();
    if (current.isEmpty || current == _lastSuggestion) {
      _lastSuggestion = name;
      controller.text = name;
    }
  }
}

/// Kết quả của một lần bấm "Tạo trang trại".
class FarmCreateOutcome {
  final String? validationError; // chưa gửi gì lên server
  final FarmCreateResult? result;
  const FarmCreateOutcome._(this.validationError, this.result);
  const FarmCreateOutcome.invalid(String message) : this._(message, null);
  const FarmCreateOutcome.sent(FarmCreateResult r) : this._(null, r);
}

/// Trạng thái nháp của một form tạo Farm.
class FarmCreateDraft extends ChangeNotifier {
  final int nextNum;
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  late final AddressAutofill addressSync = AddressAutofill(addressCtrl);
  late final FarmNameAutofill nameSync = FarmNameAutofill(nameCtrl);

  double lat = farmMapViewLat;
  double lng = farmMapViewLng;
  bool pinConfirmed = false;
  bool submitting = false;

  bool _disposed = false;

  FarmCreateDraft({required this.nextNum});

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Gọi khi người dùng kéo/chạm/tìm vị trí trên bản đồ. Lần khởi tạo bản đồ KHÔNG gọi hàm này.
  void onPinChosen(double newLat, double newLng) {
    lat = newLat;
    lng = newLng;
    pinConfirmed = true;
    notifyListeners();
  }

  String get effectiveName => nameCtrl.text.trim().isEmpty
      ? 'Nông trại 0$nextNum'
      : nameCtrl.text.trim();

  String? validate() => validateNewFarmInput(
    pinConfirmed: pinConfirmed,
    lat: pinConfirmed ? lat : null,
    lng: pinConfirmed ? lng : null,
    address: addressCtrl.text,
  );

  /// Kiểm tra rồi gửi. Gọi lặp trong lúc đang gửi sẽ bị bỏ qua (trả null).
  Future<FarmCreateOutcome?> submit(
    FarmProvider provider, {
    required double totalAreaM2,
  }) async {
    if (submitting) return null;
    final err = validate();
    if (err != null) return FarmCreateOutcome.invalid(err);
    submitting = true;
    notifyListeners();
    try {
      final r = await provider.createFarm(
        name: effectiveName,
        address: addressCtrl.text.trim(),
        totalAreaM2: totalAreaM2,
        latitude: lat,
        longitude: lng,
      );
      return FarmCreateOutcome.sent(r);
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Controller được giải phóng muộn bởi disposeControllersLater ở nơi gọi.
    _disposed = true;
    addressSync.dispose();
    super.dispose();
  }
}

/// Dòng trạng thái ghim dưới bản đồ.
Widget farmPinStatusLine(FarmCreateDraft d) => ListenableBuilder(
  listenable: d,
  builder: (_, _) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      d.pinConfirmed
          ? 'Đã chọn vị trí: ${d.lat.toStringAsFixed(6)}, ${d.lng.toStringAsFixed(6)}'
          : 'Chưa chọn vị trí. Kéo/chạm bản đồ hoặc tìm địa chỉ để đặt ghim.',
      style: TextStyle(
        fontSize: 11,
        color: d.pinConfirmed
            ? const Color(0xFF059669)
            : const Color(0xFFB45309),
      ),
    ),
  ),
);

/// Xử lý bấm nút tạo ở cả hai form: kiểm tra, chặn gửi lặp, báo kết quả đúng thực tế.
Future<void> runFarmCreate({
  required BuildContext sheetContext,
  required ScaffoldMessengerState messenger,
  required FarmProvider provider,
  required FarmCreateDraft draft,
  required double totalAreaM2,
}) async {
  if (draft.submitting) return;
  void snack(String text, {Color? color, SnackBarAction? action}) =>
      messenger.showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: color,
          action: action,
          behavior: SnackBarBehavior.floating,
        ),
      );

  final pending = draft.validate();
  if (pending != null) {
    snack(pending, color: const Color(0xFFB45309));
    return;
  }
  final name = draft.effectiveName;
  final outcome = await draft.submit(provider, totalAreaM2: totalAreaM2);
  if (outcome == null) return;
  if (outcome.validationError != null) {
    snack(outcome.validationError!, color: const Color(0xFFB45309));
    return;
  }
  final r = outcome.result!;
  if (r.error != null) {
    snack(r.error!, color: const Color(0xFFEF4444));
    return;
  }
  if (sheetContext.mounted) Navigator.pop(sheetContext);
  if (r.refreshFailed) {
    // Farm ĐÃ được tạo trên server; chỉ việc tải lại danh sách lỗi. Không báo thất bại, cũng không báo đã đồng bộ.
    snack(
      'Đã tạo trang trại "$name" nhưng chưa tải lại được dữ liệu: ${r.refreshError}',
      color: const Color(0xFFB45309),
      action: SnackBarAction(
        label: 'Đồng bộ lại',
        onPressed: () => provider.fetchFromApi(),
      ),
    );
  } else {
    snack(
      'Đã tạo trang trại "$name" và chuyển vùng làm việc.',
      color: const Color(0xFF059669),
    );
  }
}

/// Câu giới thiệu theo tổ chức thật (GET /tenants/me); chưa có tên thì dùng câu trung tính.
String farmCreateIntro(FarmProvider p) {
  final t = p.tenantName;
  return t == null
      ? 'Khởi tạo cơ sở sản xuất mới.'
      : 'Khởi tạo cơ sở sản xuất mới thuộc tổ chức $t.';
}
