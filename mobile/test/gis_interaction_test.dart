import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/core/widgets/mini_gis_map_picker.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';

void main() {
  group('MiniGISMapPicker & Zone GIS interaction tests', () {
    testWidgets('Tapping vertex selects it and allows deletion if > 3 vertices', (tester) async {
      List<LatLng> latestPolygon = [];
      final initialPolygon = [
        const LatLng(11.9419, 108.4568),
        const LatLng(11.9419, 108.4582),
        const LatLng(11.9408, 108.4582),
        const LatLng(11.9408, 108.4568),
        const LatLng(11.9400, 108.4575), // 5th vertex
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniGISMapPicker(
              initialCenter: const LatLng(11.9410, 108.4575),
              initialPolygon: initialPolygon,
              level: 'ZONE',
              onPolygonChanged: (pts) => latestPolygon = pts,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find vertex marker #5
      final vertex5 = find.text('#5');
      expect(vertex5, findsOneWidget);

      // Tap on vertex #5 to select it
      await tester.tap(vertex5);
      await tester.pump();

      // Now the overlay shows the selected vertex and "Xóa đỉnh" button
      expect(find.textContaining('Đang chọn đỉnh #5'), findsOneWidget);
      final deleteBtn = find.text('Xóa đỉnh');
      expect(deleteBtn, findsOneWidget);

      // Tap "Xóa đỉnh"
      await tester.tap(deleteBtn);
      await tester.pump();

      // Verify vertex was deleted and polygon now has 4 vertices
      expect(latestPolygon.length, 4);
      expect(find.text('#5'), findsNothing);
    });

    testWidgets('Tapping nudge buttons adjusts vertex coordinates', (tester) async {
      List<LatLng> latestPolygon = [];
      final initialPolygon = [
        const LatLng(11.9419, 108.4568),
        const LatLng(11.9419, 108.4582),
        const LatLng(11.9408, 108.4582),
        const LatLng(11.9408, 108.4568),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniGISMapPicker(
              initialCenter: const LatLng(11.9410, 108.4575),
              initialPolygon: initialPolygon,
              level: 'ZONE',
              onPolygonChanged: (pts) => latestPolygon = pts,
            ),
          ),
        ),
      );
      await tester.pump();

      // Select vertex #1
      final vertex1 = find.text('#1');
      expect(vertex1, findsOneWidget);
      await tester.tap(vertex1);
      await tester.pump();

      // Nudge buttons are displayed
      final arrowUp = find.byIcon(Icons.arrow_upward);
      expect(arrowUp, findsOneWidget);

      final oldLat = initialPolygon[0].latitude;
      await tester.tap(arrowUp);
      await tester.pump();

      // Latitude should increase
      expect(latestPolygon.isNotEmpty, isTrue);
      expect(latestPolygon[0].latitude, greaterThan(oldLat));
    });

    testWidgets('When isReadOnly is true, vertex handles and controls are hidden', (tester) async {
      final initialPolygon = [
        const LatLng(11.9419, 108.4568),
        const LatLng(11.9419, 108.4582),
        const LatLng(11.9408, 108.4582),
        const LatLng(11.9408, 108.4568),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniGISMapPicker(
              initialCenter: const LatLng(11.9410, 108.4575),
              initialPolygon: initialPolygon,
              level: 'ZONE',
              isReadOnly: true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Vertex drag handles (#1..#4) should NOT be rendered
      expect(find.text('#1'), findsNothing);
      expect(find.text('#2'), findsNothing);

      // Lock hint is shown
      expect(find.textContaining('Ranh giới GIS đang khóa cố định'), findsOneWidget);
    });

    test('FarmProvider.updateZonePolygon updates the polygon of the matching zone', () {
      final provider = FarmProvider();
      final testZone = ZoneModel(
        zoneId: 'zone-123',
        farmId: 'farm-1',
        name: 'Zone Test',
        currentCrop: 'Dưa lưới',
        currentStage: 'Cây con',
        areaM2: 500,
        currentSoilMoisture: 65,
        currentTemp: 26,
        currentHumidity: 70,
        currentLux: 800,
        polygon: [const LatLng(11.0, 108.0), const LatLng(11.0, 108.1), const LatLng(11.1, 108.1)],
      );
      provider.setZonesForTesting([testZone]);

      final newPoly = [
        const LatLng(11.0, 108.0),
        const LatLng(11.0, 108.2),
        const LatLng(11.2, 108.2),
        const LatLng(11.2, 108.0),
      ];

      provider.updateZonePolygon('zone-123', newPoly);

      final updated = provider.allZones.firstWhere((z) => z.zoneId == 'zone-123');
      expect(updated.polygon?.length, 4);
      expect(updated.polygon?[1].longitude, 108.2);
    });

    test('parseGeoJsonPolygon parses space-separated string coordinates', () {
      final geoJson = {
        'type': 'Polygon',
        'coordinates': [
          ['108.457 11.939', '108.460 11.939', '108.460 11.942', '108.457 11.942', '108.457 11.939'],
        ],
      };

      final result = parseGeoJsonPolygon(geoJson);
      expect(result.problem, isNull);
      expect(result.points, isNotNull);
      expect(result.points!.length, 5);
      expect(result.points![0].longitude, 108.457);
      expect(result.points![0].latitude, 11.939);
    });
  });
}
