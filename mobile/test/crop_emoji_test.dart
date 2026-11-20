import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/utils/crop_emoji.dart';

void main() {
  test('tên cây thật trong DB ra đúng biểu tượng (cả có dấu và không dấu)', () {
    expect(cropEmoji('Cà Chua Beefsteak (Tomato)'), '🍅');
    expect(cropEmoji('Ca Chua Chuong (Sweet Pepper)'), '🫑');
    expect(cropEmoji('Cà chua chuông'), '🫑');
    expect(cropEmoji('Dau Tay Hana (Strawberry)'), '🍓');
    expect(cropEmoji('Dưa leo màu'), '🥒');
    expect(cropEmoji('Dưa lưới'), '🍈');
    expect(cropEmoji('Lúa ST25'), '🌾');
  });
  test('cây lạ hoặc rỗng → mầm cây; từ ngắn chỉ khớp nguyên từ', () {
    expect(cropEmoji(''), '🌱');
    expect(cropEmoji('Chưa gán cây'), '🌱');
    expect(cropEmoji('Hoàng kim'), '🌱'); // "hoa" không khớp trong "hoang"
  });
}
