import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/utils/user_error.dart';

void main() {
  test('lỗi kỹ thuật của Dart không hiện nguyên văn cho người dùng', () {
    final typeError = (() {
      try {
        // ignore: unnecessary_cast
        return (<dynamic>[] as dynamic) as Map<String, dynamic>;
      } catch (e) {
        return e;
      }
    })();
    expect(typeError, isA<TypeError>());
    expect(userFacingError(typeError), contains('không đúng định dạng'));
    expect(userFacingError(typeError), isNot(contains('subtype')));
    expect(
      userFacingError(const FormatException('x')),
      contains('không đúng định dạng'),
    );
  });

  test('lỗi nghiệp vụ giữ nguyên thông báo, bỏ tiền tố Exception', () {
    expect(
      userFacingError(Exception('Vụ đã kết thúc nên không thể sửa lịch tưới.')),
      'Vụ đã kết thúc nên không thể sửa lịch tưới.',
    );
  });
}
