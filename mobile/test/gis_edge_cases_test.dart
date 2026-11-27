import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/core/widgets/mini_gis_map_picker.dart';

void main() {
  group('GIS Edge Cases - Polygon Self-Intersection (Bow-tie / Figure-8)', () {
    test('Convex rectangle does not self-intersect', () {
      final rect = [
        const LatLng(11.940, 108.450),
        const LatLng(11.942, 108.450),
        const LatLng(11.942, 108.452),
        const LatLng(11.940, 108.452),
      ];
      expect(MiniGISMapPicker.polygonSelfIntersects(rect), isFalse);
    });

    test('L-shape concave polygon without self-intersection passes', () {
      final lShape = [
        const LatLng(10.0, 10.0),
        const LatLng(10.0, 12.0),
        const LatLng(11.0, 12.0),
        const LatLng(11.0, 11.0),
        const LatLng(12.0, 11.0),
        const LatLng(12.0, 10.0),
      ];
      expect(MiniGISMapPicker.polygonSelfIntersects(lShape), isFalse);
    });

    test(
      'Hourglass / figure-8 bowtie polygon is detected as self-intersecting',
      () {
        // (0,0) -> (2,2) -> (0,2) -> (2,0): diagonal segments cross in center
        final bowtie = [
          const LatLng(0.0, 0.0),
          const LatLng(2.0, 2.0),
          const LatLng(0.0, 2.0),
          const LatLng(2.0, 0.0),
        ];
        expect(MiniGISMapPicker.polygonSelfIntersects(bowtie), isTrue);
      },
    );

    test('Five-pointed star self-crossing polygon is detected', () {
      // Order of vertices produces self-crossing pentagram
      final star = [
        const LatLng(0.0, 1.0),
        const LatLng(2.0, 2.0),
        const LatLng(0.5, 0.0),
        const LatLng(0.5, 2.5),
        const LatLng(2.0, 0.5),
      ];
      expect(MiniGISMapPicker.polygonSelfIntersects(star), isTrue);
    });

    test('Degenerate polygon with fewer than 4 points returns false', () {
      expect(MiniGISMapPicker.polygonSelfIntersects([]), isFalse);
      expect(
        MiniGISMapPicker.polygonSelfIntersects([const LatLng(1, 1)]),
        isFalse,
      );
      expect(
        MiniGISMapPicker.polygonSelfIntersects([
          const LatLng(1, 1),
          const LatLng(2, 2),
        ]),
        isFalse,
      );
      expect(
        MiniGISMapPicker.polygonSelfIntersects([
          const LatLng(1, 1),
          const LatLng(2, 2),
          const LatLng(1, 2),
        ]),
        isFalse,
      );
    });
  });

  group('GIS Edge Cases - Polygon Overlap Detection', () {
    final polyA = [
      const LatLng(10.0, 10.0),
      const LatLng(10.0, 20.0),
      const LatLng(20.0, 20.0),
      const LatLng(20.0, 10.0),
    ];

    test('Disjoint polygons do not overlap', () {
      final polyB = [
        const LatLng(30.0, 30.0),
        const LatLng(30.0, 40.0),
        const LatLng(40.0, 40.0),
        const LatLng(40.0, 30.0),
      ];
      expect(MiniGISMapPicker.polygonsOverlap(polyA, polyB), isFalse);
    });

    test('Nested polygon (B inside A) is detected as overlapping', () {
      final polyInside = [
        const LatLng(12.0, 12.0),
        const LatLng(12.0, 18.0),
        const LatLng(18.0, 18.0),
        const LatLng(18.0, 12.0),
      ];
      expect(MiniGISMapPicker.polygonsOverlap(polyA, polyInside), isTrue);
      expect(MiniGISMapPicker.polygonsOverlap(polyInside, polyA), isTrue);
    });

    test(
      'Cross / Plus shape overlap (edges cross, vertices outside) is detected',
      () {
        // polyA: x in [10, 20], y in [10, 20]
        // polyCross: x in [5, 25], y in [14, 16] - thin horizontal strip cutting through polyA
        final polyCross = [
          const LatLng(14.0, 5.0),
          const LatLng(16.0, 5.0),
          const LatLng(16.0, 25.0),
          const LatLng(14.0, 25.0),
        ];
        // Note: polyCross has vertices at (14,5), (16,5), (16,25), (14,25), all outside polyA!
        // But edges cross, so polygonsOverlap must return true!
        expect(MiniGISMapPicker.polygonsOverlap(polyA, polyCross), isTrue);
        expect(MiniGISMapPicker.polygonsOverlap(polyCross, polyA), isTrue);
      },
    );

    test('Degenerate polygons with < 3 points return false', () {
      expect(MiniGISMapPicker.polygonsOverlap(polyA, []), isFalse);
      expect(
        MiniGISMapPicker.polygonsOverlap(polyA, [
          const LatLng(10, 10),
          const LatLng(11, 11),
        ]),
        isFalse,
      );
    });
  });

  group('GIS Edge Cases - Boundary Validation Helper', () {
    final parent = [
      const LatLng(10.0, 10.0),
      const LatLng(10.0, 30.0),
      const LatLng(30.0, 30.0),
      const LatLng(30.0, 10.0),
    ];

    test('Null or < 3 points returns required vertices error', () {
      expect(
        MiniGISMapPicker.validateBoundary(null),
        contains('ít nhất 3 đỉnh'),
      );
      expect(
        MiniGISMapPicker.validateBoundary([const LatLng(1, 1)]),
        contains('ít nhất 3 đỉnh'),
      );
    });

    test('Self-intersecting polygon returns bow-tie error', () {
      final bowtie = [
        const LatLng(12.0, 12.0),
        const LatLng(18.0, 18.0),
        const LatLng(12.0, 18.0),
        const LatLng(18.0, 12.0),
      ];
      final err = MiniGISMapPicker.validateBoundary(bowtie);
      expect(err, isNotNull);
      expect(err, contains('tự cắt chéo'));
    });

    test('Polygon exceeding parent boundary returns outside error', () {
      final partlyOutside = [
        const LatLng(12.0, 12.0),
        const LatLng(12.0, 35.0), // outside parent (parent y max is 30)
        const LatLng(18.0, 35.0),
        const LatLng(18.0, 12.0),
      ];
      final err = MiniGISMapPicker.validateBoundary(
        partlyOutside,
        parentPolygon: parent,
        level: 'ZONE',
      );
      expect(err, isNotNull);
      expect(err, contains('vượt ra ngoài Thửa đất mẹ'));
    });

    test(
      'Polygon overlapping existing sibling returns conflict error with sibling name',
      () {
        final existingZone = [
          const LatLng(12.0, 12.0),
          const LatLng(12.0, 18.0),
          const LatLng(18.0, 18.0),
          const LatLng(18.0, 12.0),
        ];
        final newZone = [
          const LatLng(15.0, 15.0),
          const LatLng(15.0, 22.0),
          const LatLng(22.0, 22.0),
          const LatLng(22.0, 15.0),
        ];
        final err = MiniGISMapPicker.validateBoundary(
          newZone,
          parentPolygon: parent,
          existingPolygons: [
            {'name': 'Khu Dưa Lưới 01', 'polygon': existingZone},
          ],
          level: 'ZONE',
        );
        expect(err, isNotNull);
        expect(err, contains('chồng đè lên "Khu Dưa Lưới 01"'));
      },
    );

    test('Clean polygon inside parent with no conflicts passes validation', () {
      final existingZone = [
        const LatLng(12.0, 12.0),
        const LatLng(12.0, 18.0),
        const LatLng(18.0, 18.0),
        const LatLng(18.0, 12.0),
      ];
      final newZoneClean = [
        const LatLng(22.0, 22.0),
        const LatLng(22.0, 28.0),
        const LatLng(28.0, 28.0),
        const LatLng(28.0, 22.0),
      ];
      final err = MiniGISMapPicker.validateBoundary(
        newZoneClean,
        parentPolygon: parent,
        existingPolygons: [
          {'name': 'Khu Dưa Lưới 01', 'polygon': existingZone},
        ],
        level: 'ZONE',
      );
      expect(err, isNull);
    });
  });

  group('GIS Edge Cases - Point in Polygon (Ray Casting)', () {
    final square = [
      const LatLng(10.0, 10.0),
      const LatLng(10.0, 20.0),
      const LatLng(20.0, 20.0),
      const LatLng(20.0, 10.0),
    ];

    test('Interior points return true', () {
      expect(pointInPolygon(const LatLng(15.0, 15.0), square), isTrue);
      expect(pointInPolygon(const LatLng(11.0, 11.0), square), isTrue);
      expect(pointInPolygon(const LatLng(19.0, 19.0), square), isTrue);
    });

    test('Exterior points return false', () {
      expect(pointInPolygon(const LatLng(5.0, 15.0), square), isFalse);
      expect(pointInPolygon(const LatLng(25.0, 15.0), square), isFalse);
      expect(pointInPolygon(const LatLng(15.0, 5.0), square), isFalse);
      expect(pointInPolygon(const LatLng(15.0, 25.0), square), isFalse);
    });
  });
}
