/// Chữ lỗi cho người dùng. Lỗi kỹ thuật của Dart (kiểu dữ liệu, định dạng, thiếu thành phần) KHÔNG được hiện nguyên văn
/// (kiểu như "type List is not a subtype of type Map"): nói rõ là dữ liệu máy chủ trả về sai định dạng.
/// Lỗi nghiệp vụ từ máy chủ (Exception có thông báo tiếng Việt) giữ nguyên, bỏ tiền tố "Exception: ".
String userFacingError(Object error) {
  if (error is TypeError ||
      error is FormatException ||
      error is NoSuchMethodError) {
    return 'Dữ liệu máy chủ trả về không đúng định dạng. Hãy thử lại sau; nếu vẫn lỗi, báo quản trị viên.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
