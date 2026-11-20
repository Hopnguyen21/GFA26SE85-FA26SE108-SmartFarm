import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/support/node_placement_logic.dart';

void main() {
  test('encodeNodeAddress: thêm tiền tố, gộp khoảng trắng, trống thì null', () {
    expect(
      encodeNodeAddress('  Nhà màng 02,\n  Đà Lạt '),
      'Địa chỉ: Nhà màng 02, Đà Lạt',
    );
    expect(encodeNodeAddress('   '), isNull);
    expect(encodeNodeAddress(null), isNull);
  });

  test('encodeNodeAddress: cắt tối đa 300 ký tự', () {
    final r = encodeNodeAddress('a' * 500)!;
    expect(r.length, nodeAddressPrefix.length + nodeAddressMaxLength);
  });

  test(
    'decodeNodeAddress: chỉ nhận chuỗi có tiền tố; ghi chú cũ không bị nhầm là địa chỉ',
    () {
      expect(decodeNodeAddress('Địa chỉ: Lô A, Đà Lạt'), 'Lô A, Đà Lạt');
      expect(decodeNodeAddress('AA:BB:CC (GPS ±3 m)'), isNull);
      expect(decodeNodeAddress('Ghi chú khác'), isNull);
      expect(decodeNodeAddress('Địa chỉ: '), isNull);
      expect(decodeNodeAddress(null), isNull);
    },
  );

  test('encode rồi decode trả lại đúng địa chỉ', () {
    expect(
      decodeNodeAddress(encodeNodeAddress('Thôn 3, Lâm Đồng')),
      'Thôn 3, Lâm Đồng',
    );
  });
}
