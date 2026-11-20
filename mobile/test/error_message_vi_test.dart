import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartfarm_mobile/core/services/api_service.dart';

http.Response _problem(int code, String detail) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'title': 'Resource conflict',
      'status': code,
      'detail': detail,
    }),
  ),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('lỗi tiếng Anh của backend trong luồng lắp đặt được Việt hóa', () {
    expect(
      ApiService.errorMessageFor(
        _problem(
          403,
          'Only the assigned technician may read the estimate for this quotation.',
        ),
      ),
      contains('chưa được quản trị viên giao cho bạn'),
    );
    expect(
      ApiService.errorMessageFor(
        _problem(
          400,
          'Plan items must be non-empty, unique by model and quantity 1–100.',
        ),
      ),
      contains('Kế hoạch thiết bị đang trống'),
    );
    expect(
      ApiService.errorMessageFor(
        _problem(409, 'Device Model is not in the confirmed deployment plan.'),
      ),
      contains('không thuộc model nào trong kế hoạch'),
    );
    expect(
      ApiService.errorMessageFor(
        _problem(
          409,
          'Final acceptance requires the linked deployment request to be Completed.',
        ),
      ),
      contains('Hoàn tất lắp đặt'),
    );
  });

  test('thông báo tiếng Việt hoặc không biết thì giữ nguyên', () {
    expect(
      ApiService.errorMessageFor(
        _problem(409, "Cảm biến 'X' không còn trong kho Technician."),
      ),
      "Cảm biến 'X' không còn trong kho Technician.",
    );
    expect(
      ApiService.errorMessageFor(_problem(409, 'Some other conflict.')),
      'Some other conflict.',
    );
  });
}
