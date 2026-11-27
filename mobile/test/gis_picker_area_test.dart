import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartfarm_mobile/core/widgets/mini_gis_map_picker.dart';

Widget _picker(List<LatLng> pts, {String level = 'ZONE'}) => MaterialApp(
  home: Scaffold(
    body: MiniGISMapPicker(
      initialCenter: const LatLng(11.9410, 108.4575),
      initialPolygon: pts,
      level: level,
    ),
  ),
);

/// Đếm điểm ảnh xanh lá (#10B981 ± dung sai) — màu viền/tô của ranh giới Zone đang vẽ (giống web) — trong ảnh render thật của widget.
Future<int> _countAmberPixels(WidgetTester tester, Finder f) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(f);
  return (await tester.runAsync(() async {
    final ui.Image img = await boundary.toImage(pixelRatio: 1);
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    var n = 0;
    for (var i = 0; i < data.lengthInBytes; i += 4) {
      final r = data.getUint8(i),
          g = data.getUint8(i + 1),
          b = data.getUint8(i + 2);
      if ((r - 16).abs() < 30 && (g - 185).abs() < 30 && (b - 129).abs() < 40)
        n++;
    }
    return n;
  }))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tmp = Directory.systemTemp.createTempSync('gis_picker_test').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider_windows'),
          (_) async => tmp,
        );
  });
  testWidgets('đủ 3+ đỉnh: vẽ vùng và ghi diện tích (m²) ngay trên bản đồ', (
    tester,
  ) async {
    // ~ 150 m × 120 m ≈ 18.000 m²
    await tester.pumpWidget(
      _picker(const [
        LatLng(11.9419, 108.4568),
        LatLng(11.9419, 108.4582),
        LatLng(11.9408, 108.4582),
        LatLng(11.9408, 108.4568),
      ]),
    );
    await tester.pump();
    expect(find.byType(PolygonLayer), findsWidgets);
    final chip = find.byKey(const ValueKey('gis-area-chip'));
    expect(chip, findsOneWidget);
    expect(find.textContaining('Diện tích:'), findsOneWidget);
    expect(find.textContaining('m²'), findsWidgets);
    expect(find.textContaining('Cần ít nhất 3 đỉnh'), findsNothing);
  });

  testWidgets(
    'Zone trong Thửa đất ở zoom sâu (20): vẫn vẽ vùng, viền nối đỉnh và nhãn diện tích',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 460,
              child: MiniGISMapPicker(
                initialCenter: const LatLng(11.9410, 108.4575),
                initialZoom: 20,
                level: 'ZONE',
                parentPolygon: const [
                  LatLng(11.9400, 108.4565),
                  LatLng(11.9400, 108.4585),
                  LatLng(11.9420, 108.4585),
                  LatLng(11.9420, 108.4565),
                ],
                initialPolygon: const [
                  LatLng(11.94105, 108.45745),
                  LatLng(11.94105, 108.45760),
                  LatLng(11.94097, 108.45755),
                  LatLng(11.94095, 108.45742),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byType(PolygonLayer),
        findsNWidgets(2),
      ); // Thửa đất mẹ + vùng đang vẽ
      expect(
        find.byKey(const ValueKey('gis-boundary-outline')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('gis-area-chip')), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
    },
  );

  for (final zoom in [19.0, 20.0]) {
    testWidgets('điểm ảnh thật ở zoom $zoom: có viền cam của ranh giới Zone', (
      tester,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                height: 460,
                child: MiniGISMapPicker(
                  initialCenter: const LatLng(11.9410, 108.4575),
                  initialZoom: zoom,
                  level: 'ZONE',
                  initialPolygon: const [
                    LatLng(11.94105, 108.45745),
                    LatLng(11.94105, 108.45760),
                    LatLng(11.94097, 108.45755),
                    LatLng(11.94095, 108.45742),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final amber = await _countAmberPixels(tester, find.byKey(key));
      // Viền dày 3px nối 4 đỉnh: ở mọi mức zoom phải có hàng trăm điểm ảnh cam; 0 nghĩa là vùng không vẽ.
      expect(
        amber,
        greaterThan(150),
        reason: 'zoom $zoom: chỉ có $amber điểm ảnh cam',
      );
    });
  }

  testWidgets(
    'ô mặc định (chưa có ranh giới): tự căn khung nên viền nối đỉnh nhìn thấy ngay',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: const SizedBox(
                height: 460,
                child: MiniGISMapPicker(
                  initialCenter: LatLng(11.9410, 108.4575),
                  level: 'ZONE',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final amber = await _countAmberPixels(tester, find.byKey(key));
      expect(
        amber,
        greaterThan(300),
        reason: 'ô mặc định chỉ có $amber điểm ảnh cam',
      );
    },
  );

  Widget withParent(List<LatLng> poly, {List<Map<String, dynamic>>? others}) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 460,
            child: MiniGISMapPicker(
              initialCenter: const LatLng(11.9410, 108.4575),
              level: 'ZONE',
              parentPolygon: const [
                LatLng(11.9400, 108.4565),
                LatLng(11.9400, 108.4585),
                LatLng(11.9420, 108.4585),
                LatLng(11.9420, 108.4565),
              ],
              existingZones: others,
              initialPolygon: poly,
            ),
          ),
        ),
      );

  testWidgets(
    'kết quả kiểm tra (lưu đệm) vẫn đúng: ngoài thửa đất báo cảnh báo, đổi sang trong thì hết',
    (tester) async {
      const outside = [
        LatLng(11.9430, 108.4575),
        LatLng(11.9430, 108.4580),
        LatLng(11.9425, 108.4580),
      ];
      const inside = [
        LatLng(11.9412, 108.4572),
        LatLng(11.9412, 108.4578),
        LatLng(11.9408, 108.4578),
      ];
      await tester.pumpWidget(withParent(outside));
      await tester.pump();
      expect(find.textContaining('nằm ngoài Thửa đất'), findsOneWidget);
      await tester.pumpWidget(withParent(inside));
      await tester.pump();
      expect(find.textContaining('nằm ngoài Thửa đất'), findsNothing);
    },
  );

  testWidgets('đè lên Zone khác: báo tên Zone bị đè', (tester) async {
    await tester.pumpWidget(
      withParent(
        const [
          LatLng(11.9412, 108.4572),
          LatLng(11.9412, 108.4578),
          LatLng(11.9408, 108.4578),
        ],
        others: [
          {
            'name': 'Zone cũ',
            'polygon': const [
              LatLng(11.9413, 108.4570),
              LatLng(11.9413, 108.4580),
              LatLng(11.9406, 108.4580),
              LatLng(11.9406, 108.4570),
            ],
          },
        ],
      ),
    );
    await tester.pump();
    expect(find.textContaining('Zone cũ'), findsWidgets);
  });

  testWidgets(
    'ô nhỏ trên màn hình: vùng kéo cả ô co lại (không nuốt cú chạm kéo bản đồ)',
    (tester) async {
      await tester.pumpWidget(
        _picker(const [
          LatLng(11.94105, 108.45745),
          LatLng(11.94105, 108.45760),
          LatLng(11.94097, 108.45755),
          LatLng(11.94095, 108.45742),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final sizes = tester
          .widgetList<MarkerLayer>(find.byType(MarkerLayer))
          .expand((l) => l.markers)
          .where((m) => m.width == m.height)
          .map((m) => m.width)
          .toSet();
      expect(
        sizes.contains(140),
        isFalse,
        reason: 'vùng kéo ô không còn cố định 140px',
      );
      expect(
        sizes.any((v) => v >= 36 && v < 140),
        isTrue,
        reason: 'vùng kéo ô co theo kích thước ô thật (hiện: $sizes)',
      );
    },
  );

  testWidgets(
    'trong danh sách cuộn: chạm đỉnh vẫn chọn được và kéo trên bản đồ không cuộn trang',
    (tester) async {
      final scroll = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 120),
                  SizedBox(
                    height: 460,
                    child: MiniGISMapPicker(
                      initialCenter: const LatLng(11.9410, 108.4575),
                      level: 'ZONE',
                      initialPolygon: const [
                        LatLng(11.94105, 108.45745),
                        LatLng(11.94105, 108.45760),
                        LatLng(11.94097, 108.45755),
                        LatLng(11.94095, 108.45742),
                      ],
                      initialZoom: 19,
                    ),
                  ),
                  const SizedBox(height: 1500),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // 1) Chạm đỉnh #1: phải chọn được (bộ nhận diện cử chỉ không được nuốt cú chạm).
      await tester.tap(find.text('#1'));
      await tester.pump();
      expect(find.textContaining('Đang chọn đỉnh #1'), findsOneWidget);
      // 2) Kéo dọc trên vùng bản đồ: trang cha không được cuộn.
      final topLeft = tester.getTopLeft(find.byType(FlutterMap));
      await tester.dragFrom(
        topLeft + const Offset(240, 60),
        const Offset(0, -150),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        scroll.offset,
        0,
        reason: 'kéo trên bản đồ không được cuộn trang cha',
      );
    },
  );

  testWidgets(
    'ranh giới truyền sẵn nhưng quá nhỏ ở zoom mở đầu: tự căn khung, viền nhìn thấy và nhãn diện tích ở đầu bản đồ',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SizedBox(
                height: 300,
                child: MiniGISMapPicker(
                  initialCenter: const LatLng(11.9410, 108.4575),
                  initialZoom: 16.5,
                  level: 'ZONE',
                  initialPolygon: const [
                    LatLng(11.94105, 108.45745),
                    LatLng(11.94105, 108.45760),
                    LatLng(11.94097, 108.45755),
                    LatLng(11.94095, 108.45742),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        await _countAmberPixels(tester, find.byKey(key)),
        greaterThan(300),
      );
      final chip = tester.getTopLeft(
        find.byKey(const ValueKey('gis-area-chip')),
      );
      final map = tester.getTopLeft(find.byType(FlutterMap));
      expect(
        chip.dy - map.dy,
        lessThan(80),
        reason: 'nhãn diện tích phải ở đầu bản đồ',
      );
    },
  );

  testWidgets(
    'nhãn các Zone khác không chồng nhau: hai Zone sát nhau chỉ hiện một nhãn, Zone xa vẫn hiện',
    (tester) async {
      List<LatLng> box(double lat, double lng, double d) => [
        LatLng(lat + d, lng - d),
        LatLng(lat + d, lng + d),
        LatLng(lat - d, lng + d),
        LatLng(lat - d, lng - d),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 460,
              child: MiniGISMapPicker(
                initialCenter: const LatLng(11.9410, 108.4575),
                initialZoom: 17,
                level: 'ZONE',
                existingZones: [
                  {
                    'name': 'Zone Gần A',
                    'polygon': box(11.9410, 108.4573, 0.00003),
                  },
                  {
                    'name': 'Zone Gần B',
                    'polygon': box(11.94101, 108.45731, 0.00003),
                  },
                  {
                    'name': 'Zone Xa C',
                    'polygon': box(11.9410, 108.4577, 0.00003),
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Zone Gần A'), findsOneWidget);
      expect(find.text('Zone Gần B'), findsNothing);
      expect(find.text('Zone Xa C'), findsOneWidget);
    },
  );

  testWidgets(
    'giống web: thanh số liệu "N đỉnh · Diện tích" và chú giải Phân khu mẹ / Hiện tại (ZONE)',
    (tester) async {
      await tester.pumpWidget(
        withParent(const [
          LatLng(11.9412, 108.4572),
          LatLng(11.9412, 108.4578),
          LatLng(11.9408, 108.4578),
          LatLng(11.9408, 108.4572),
        ]),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('4 đỉnh · Diện tích:'), findsOneWidget);
      expect(find.byKey(const ValueKey('gis-legend')), findsOneWidget);
      expect(find.text('Phân khu mẹ'), findsOneWidget);
      expect(find.text('Hiện tại (ZONE)'), findsOneWidget);
    },
  );

  testWidgets(
    'diện tích báo cho form (onAreaCalculated) đúng cho tam giác ~12.000 m²',
    (tester) async {
      double? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniGISMapPicker(
              initialCenter: const LatLng(11.9410, 108.4505),
              level: 'FIELD',
              autoResolveOnInit: false,
              initialPolygon: const [
                LatLng(11.9400, 108.4500),
                LatLng(11.9420, 108.4505),
                LatLng(11.9400, 108.4510),
              ],
              onAreaCalculated: (a) => reported = a,
            ),
          ),
        ),
      );
      await tester.pump();
      // Công thức cũ báo ~3.000 m² cho hình này rồi ghi vào ô diện tích gửi lên máy chủ.
      expect(reported, closeTo(12040, 150));
      expect(find.textContaining('3 đỉnh · Diện tích: 12.0'), findsOneWidget);
    },
  );

  testWidgets('cấp FARM không hiện nhãn diện tích', (tester) async {
    await tester.pumpWidget(_picker(const [], level: 'FARM'));
    await tester.pump();
    expect(find.byKey(const ValueKey('gis-area-chip')), findsNothing);
  });

  testWidgets('Zone chỉ xem không có node vẫn căn khung đủ ranh giới', (
    tester,
  ) async {
    const points = [
      LatLng(11.8360, 108.5700),
      LatLng(11.8360, 108.5740),
      LatLng(11.8340, 108.5740),
      LatLng(11.8340, 108.5700),
    ];
    final changes = <List<LatLng>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 330,
              child: RepaintBoundary(
                key: const Key('readonly-gis-render'),
                child: MiniGISMapPicker(
                  initialCenter: points.first,
                  initialPolygon: points,
                  height: 240,
                  level: 'ZONE',
                  isReadOnly: true,
                  autoResolveOnInit: false,
                  onPolygonChanged: changes.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final camera = map.mapController!.camera;
    for (final point in points) {
      final screen = camera.latLngToScreenOffset(point);
      expect(screen.dx, inInclusiveRange(27, 279));
      expect(screen.dy, inInclusiveRange(43, 197));
    }
    final boundaryFinder = find.byKey(const Key('readonly-gis-render'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
    final mapOffset =
        tester.getTopLeft(find.byType(FlutterMap)) -
        tester.getTopLeft(boundaryFinder);
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final pixels = (await image.toByteData())!;
        for (var i = 0; i < points.length; i++) {
          final start = camera.latLngToScreenOffset(points[i]);
          final end = camera.latLngToScreenOffset(
            points[(i + 1) % points.length],
          );
          final midpoint = mapOffset + (start + end) / 2;
          final pixel =
              (midpoint.dy.round() * image.width + midpoint.dx.round()) * 4;
          expect(pixels.getUint32(pixel), 0x10B981FF, reason: 'Cạnh $i');
        }
      } finally {
        image.dispose();
      }
    });
    final start = camera.center;
    await tester.drag(find.byType(FlutterMap), const Offset(22, 12));
    await tester.pump(const Duration(seconds: 2));
    expect(map.mapController!.camera.center, isNot(start));
    expect(changes, isEmpty);
  });
}
