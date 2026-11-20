import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/zones/zone_auto_season.dart';

void main() {
  test('vụ có cây thì giữ cây của vụ', () {
    expect(seasonCropLabel({'cropName': 'Lúa'}, 'Ngô'), 'Lúa');
  });
  test('vụ chưa có cây thì lấy cây của Zone', () {
    expect(seasonCropLabel({'cropName': null}, 'Cà chua'), 'Cà chua');
    expect(seasonCropLabel({'cropName': ' '}, 'Cà chua'), 'Cà chua');
    expect(seasonCropLabel({}, 'Cà chua'), 'Cà chua');
  });
  test('Zone chưa gán cây thì hiện —', () {
    expect(seasonCropLabel({}, 'Chưa gán cây'), '—');
    expect(seasonCropLabel({}, ''), '—');
  });
}
