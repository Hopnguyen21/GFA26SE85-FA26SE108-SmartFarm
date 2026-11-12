import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Điều phối ô "Địa Chỉ Thực Địa" với kết quả reverse-geocode của bản đồ:
///  - chỉ ghi tên địa điểm THẬT (không ghi toạ độ, không ghi chữ "đang lấy…" vào ô),
///  - không ghi đè địa chỉ người dùng đã tự gõ,
///  - lỗi/không tìm thấy thì giữ nguyên ô và hiện trạng thái để thử lại hoặc nhập tay.
class AddressAutofill extends ChangeNotifier {
  final TextEditingController controller;
  bool _userEdited = false;
  bool _loading = false;
  String? _error;
  int _retryId = 0;
  bool _disposed = false;

  AddressAutofill(this.controller);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get loading => _loading;
  String? get error => _error;
  bool get userEdited => _userEdited;

  /// Gắn vào `TextField.onChanged` (chỉ chạy khi NGƯỜI DÙNG gõ, không chạy khi gán `controller.text` bằng code).
  void onUserChanged(String _) {
    if (_disposed || _userEdited) return;
    _userEdited = true;
    notifyListeners();
  }

  /// Bản đồ bắt đầu lấy địa chỉ.
  void onLoading() {
    if (_disposed) return;
    if (_loading && _error == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
  }

  /// Bản đồ đã có tên địa điểm thật.
  void onResolved(String address) {
    if (_disposed) return;
    _loading = false;
    _error = null;
    final text = address.trim();
    if (text.isNotEmpty &&
        (!_userEdited || controller.text.trim().isEmpty) &&
        controller.text != text) {
      controller.text = text;
      _userEdited = false;
    }
    notifyListeners();
  }

  /// Lấy địa chỉ thất bại: GIỮ nội dung ô, chỉ báo lý do.
  void onFailed(String message) {
    if (_disposed) return;
    _loading = false;
    _error = message;
    notifyListeners();
  }

  /// Người dùng bấm "Lấy tên địa điểm từ ghim": chủ động nên được phép thay nội dung ô.
  Future<void> retry(
    double lat,
    double lng, {
    Future<GeocodeResult> Function(double, double)? lookup,
  }) async {
    final id = ++_retryId;
    _loading = true;
    _error = null;
    notifyListeners();
    final res = await (lookup ?? FarmApi.reverseGeocodeDetailed)(lat, lng);
    if (_disposed || id != _retryId)
      return; // đã đóng form hoặc có lần thử lại mới hơn
    _loading = false;
    if (res.ok) {
      controller.text = res.displayName!;
      _userEdited = false;
      _error = null;
    } else {
      _error = res.message;
    }
    notifyListeners();
  }

  /// Dòng trạng thái dưới ô địa chỉ.
  Widget statusLine() => ListenableBuilder(
    listenable: this,
    builder: (_, _) {
      if (_loading) {
        return const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Đang lấy tên địa điểm…',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        );
      }
      if (_error != null) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _error!,
            style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
