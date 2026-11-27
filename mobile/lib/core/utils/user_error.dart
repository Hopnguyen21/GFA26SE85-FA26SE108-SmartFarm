/// Chữ lỗi cho người dùng. Lỗi kỹ thuật của Dart (kiểu dữ liệu, định dạng, thiếu thành phần) KHÔNG được hiện nguyên văn
/// (kiểu như "type List is not a subtype of type Map"): nói rõ là dữ liệu máy chủ trả về sai định dạng.
/// Lỗi nghiệp vụ từ máy chủ (Exception có thông báo tiếng Việt) giữ nguyên, bỏ tiền tố "Exception: ".
String userFacingError(Object error) {
  if (error is TypeError ||
      error is FormatException ||
      error is NoSuchMethodError) {
    return 'Dữ liệu máy chủ trả về không đúng định dạng. Hãy thử lại sau; nếu vẫn lỗi, báo quản trị viên.';
  }
  final msg = error.toString().replaceFirst('Exception: ', '').trim();
  final low = msg.toLowerCase();
  if (low.contains('the account is temporarily locked')) {
    return 'Tài khoản đã bị tạm khóa do nhập sai mật khẩu nhiều lần. Vui lòng thử lại sau 15 phút hoặc liên hệ quản trị viên.';
  }
  if (low.contains('the account is not active')) {
    return 'Tài khoản hiện đang bị khóa hoặc chưa được kích hoạt.';
  }
  if (low.contains('invalid email or password')) {
    return 'Email hoặc mật khẩu không chính xác.';
  }
  if (low.contains('password must be 8-100 characters')) {
    return 'Mật khẩu phải dài 8–100 ký tự và bao gồm chữ hoa, chữ thường, chữ số và ký tự đặc biệt.';
  }
  if (low.contains('current password is incorrect')) {
    return 'Mật khẩu hiện tại không chính xác.';
  }
  return msg;
}
