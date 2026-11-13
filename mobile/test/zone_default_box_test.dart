import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/core/widgets/zone_default_box.dart';

// Thửa đất chữ nhật ~110 m (vĩ độ) × ~215 m (kinh độ) quanh Đà Lạt.
const _lat0 = 11.9400, _lng0 = 108.4500;
List<LatLng> _rect(double s, double w, double n, double e) => [
  LatLng(n, w),
  LatLng(n, e),
  LatLng(s, e),
  LatLng(s, w),
];
final _field = _rect(_lat0, _lng0, _lat0 + 0.0010, _lng0 + 0.0020);

bool _in(LatLng p, double s, double w, double n, double e) =>
    p.latitude > s && p.latitude < n && p.longitude > w && p.longitude < e;

void main() {
  test('thửa trống: ô nằm trọn trong thửa, quanh tâm', () {
    final box = suggestZoneBox(parent: _field)!;
    expect(box, hasLength(4));
    expect(
      box.every((p) => _in(p, _lat0, _lng0, _lat0 + 0.0010, _lng0 + 0.0020)),
      isTrue,
    );
    final cLat = box.map((p) => p.latitude).reduce((a, b) => a + b) / 4;
    final cLng = box.map((p) => p.longitude).reduce((a, b) => a + b) / 4;
    expect(cLat, closeTo(_lat0 + 0.0005, 1e-9));
    expect(cLng, closeTo(_lng0 + 0.0010, 1e-9));
  });

  test('có Zone chiếm giữa thửa: ô gợi ý né ra, không chồng lấn', () {
    // Zone đã có chiếm dải giữa theo chiều dọc.
    final zone = _rect(_lat0, _lng0 + 0.0007, _lat0 + 0.0010, _lng0 + 0.0013);
    final box = suggestZoneBox(parent: _field, others: [zone])!;
    expect(
      box.every((p) => _in(p, _lat0, _lng0, _lat0 + 0.0010, _lng0 + 0.0020)),
      isTrue,
    );
    final allLeft = box.every((p) => p.longitude < _lng0 + 0.0007);
    final allRight = box.every((p) => p.longitude > _lng0 + 0.0013);
    expect(allLeft || allRight, isTrue, reason: 'ô phải nằm hẳn một bên Zone');
  });

  test('giới hạn diện tích còn trống: ô gợi ý không vượt quá', () {
    final unlimited = polygonAreaM2(suggestZoneBox(parent: _field)!);
    expect(unlimited, greaterThan(2000));
    final box = suggestZoneBox(parent: _field, maxAreaM2: 1000)!;
    expect(polygonAreaM2(box), lessThanOrEqualTo(1000));
  });

  test('thửa đất nhỏ (~0,1 ha): ô vẫn nằm trong thửa', () {
    final small = _rect(_lat0, _lng0, _lat0 + 0.0003, _lng0 + 0.0003);
    final box = suggestZoneBox(parent: small)!;
    expect(
      box.every((p) => _in(p, _lat0, _lng0, _lat0 + 0.0003, _lng0 + 0.0003)),
      isTrue,
    );
  });

  test('thửa đã kín Zone hoặc thiếu ranh giới: trả null', () {
    expect(suggestZoneBox(parent: _field, others: [_field]), isNull);
    expect(suggestZoneBox(parent: const []), isNull);
  });

  test('polygonAreaM2 xấp xỉ đúng diện tích hình chữ nhật', () {
    // 0.0010° vĩ ≈ 110,5 m; 0.0020° kinh ≈ 217,8 m tại vĩ độ 11,94°.
    expect(polygonAreaM2(_field), closeTo(24080, 300));
  });
}
