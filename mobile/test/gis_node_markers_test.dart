import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/core/widgets/mini_gis_map_picker.dart';

void main() {
  test('MapNodeMarker.fromJson: lấy toạ độ thật, bỏ qua thiếu/sai/(0,0)', () {
    final ok = MapNodeMarker.fromJson({
      'deviceName': 'Node đất 1',
      'deviceType': 'SensorNode',
      'latitude': 11.9414,
      'longitude': 108.4595,
      'status': 'Online',
    })!;
    expect(ok.label, 'Node đất 1');
    expect(ok.point.latitude, 11.9414);
    expect(
      MapNodeMarker.fromJson({
        'hardwareAddress': 'AA:BB',
        'latitude': 1,
        'longitude': 2,
      })!.label,
      'AA:BB',
    );
    expect(
      MapNodeMarker.fromJson({'latitude': null, 'longitude': 108.4}),
      isNull,
    );
    expect(MapNodeMarker.fromJson({'latitude': 0, 'longitude': 0}), isNull);
    expect(MapNodeMarker.fromJson({'latitude': 95, 'longitude': 10}), isNull);
  });

  test('pointInPolygon: trong/ngoài/đa giác thiếu đỉnh', () {
    const sq = [
      LatLng(11.9415, 108.4594),
      LatLng(11.9415, 108.4596),
      LatLng(11.9413, 108.4596),
      LatLng(11.9413, 108.4594),
    ];
    expect(pointInPolygon(const LatLng(11.9414, 108.4595), sq), isTrue);
    expect(pointInPolygon(const LatLng(11.9420, 108.4595), sq), isFalse);
    expect(pointInPolygon(const LatLng(11.9414, 108.4600), sq), isFalse);
    expect(
      pointInPolygon(const LatLng(11.9414, 108.4595), sq.take(2).toList()),
      isFalse,
    );
  });

  testWidgets('bản đồ Zone vẽ chấm cho từng node đã chấm toạ độ', (t) async {
    t.view.physicalSize = const Size(500, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const c = LatLng(11.9414, 108.4595);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniGISMapPicker(
            initialCenter: c,
            level: 'ZONE',
            isReadOnly: true,
            autoResolveOnInit: false,
            initialPolygon: const [
              LatLng(11.9415, 108.4594),
              LatLng(11.9415, 108.4596),
              LatLng(11.9413, 108.4596),
              LatLng(11.9413, 108.4594),
            ],
            nodeMarkers: const [
              MapNodeMarker(
                point: c,
                label: 'N1',
                type: 'SensorNode',
                status: 'Online',
              ),
              MapNodeMarker(
                point: LatLng(11.94135, 108.45955),
                label: 'V1',
                type: 'ActuatorNode',
                status: 'Offline',
              ),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byKey(const Key('gis_node_marker')), findsNWidgets(2));
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
