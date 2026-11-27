import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/core/widgets/mini_gis_map_picker.dart';

List<LatLng> _sq(double lat, double lng, double s) => [
  LatLng(lat, lng),
  LatLng(lat, lng + s),
  LatLng(lat + s, lng + s),
  LatLng(lat + s, lng),
];

// Field hình chữ U (lõm): hai nhánh, giữa là khe trống.
final _uField = [
  LatLng(0, 0),
  LatLng(0, 3),
  LatLng(3, 3),
  LatLng(3, 2),
  LatLng(1, 2),
  LatLng(1, 1),
  LatLng(3, 1),
  LatLng(3, 0),
];

void main() {
  final field = _sq(10.0, 106.0, 0.01);

  test('zone nằm trọn trong field: hợp lệ', () {
    final zone = _sq(10.002, 106.002, 0.004);
    expect(MiniGISMapPicker.polygonInsideParent(zone, field), isTrue);
    expect(
      MiniGISMapPicker.validateBoundary(zone, parentPolygon: field),
      isNull,
    );
  });

  test('một đỉnh thò ra ngoài field: bị chặn kèm thông báo', () {
    final zone = _sq(10.008, 106.008, 0.004);
    expect(MiniGISMapPicker.polygonInsideParent(zone, field), isFalse);
    expect(
      MiniGISMapPicker.validateBoundary(zone, parentPolygon: field),
      contains('vượt ra ngoài'),
    );
  });

  test('field lõm: mọi đỉnh ở trong nhưng cạnh cắt qua khe trống bị chặn', () {
    // Hai đỉnh nằm ở hai nhánh chữ U, cạnh nối chúng đi qua khe (ngoài field).
    final zone = [
      LatLng(2.0, 0.5),
      LatLng(2.0, 2.5),
      LatLng(2.5, 2.5),
      LatLng(2.5, 0.5),
    ];
    expect(zone.every((p) => pointInPolygon(p, _uField)), isTrue);
    expect(MiniGISMapPicker.polygonInsideParent(zone, _uField), isFalse);
  });

  test('field lõm: zone nằm gọn trong một nhánh vẫn hợp lệ', () {
    final zone = _sq(1.5, 0.2, 0.5);
    expect(MiniGISMapPicker.polygonInsideParent(zone, _uField), isTrue);
  });

  test('không có field mẹ (chưa vẽ): không chặn', () {
    expect(
      MiniGISMapPicker.polygonInsideParent(_sq(0, 0, 1), const []),
      isTrue,
    );
  });
}
