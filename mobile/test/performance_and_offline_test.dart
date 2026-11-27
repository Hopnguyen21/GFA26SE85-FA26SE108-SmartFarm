import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/utils/debouncer.dart';
import 'package:smartfarm_mobile/core/utils/image_compress.dart';
import 'package:smartfarm_mobile/core/services/offline_task_draft_service.dart';
import 'package:smartfarm_mobile/core/services/offline_gis_cache_service.dart';
import 'package:smartfarm_mobile/core/widgets/shimmer_loading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Debouncer Tests', () {
    test('Debouncer trì hoãn và chỉ thực thi lần gọi cuối cùng', () async {
      final debouncer = Debouncer(milliseconds: 50);
      var count = 0;

      debouncer.run(() => count++);
      debouncer.run(() => count++);
      debouncer.run(() => count++);

      expect(count, 0); // Chưa chạy ngay
      expect(debouncer.isRunning, true);

      await Future.delayed(const Duration(milliseconds: 80));
      expect(count, 1); // Chỉ chạy 1 lần duy nhất cho lệnh cuối
      expect(debouncer.isRunning, false);
    });

    test('Debouncer hủy được tiến trình đang chờ', () async {
      final debouncer = Debouncer(milliseconds: 50);
      var executed = false;

      debouncer.run(() => executed = true);
      debouncer.cancel();

      await Future.delayed(const Duration(milliseconds: 70));
      expect(executed, false);
      expect(debouncer.isRunning, false);
    });
  });

  group('OfflineTaskDraftService Tests', () {
    test('Lưu, kiểm tra, nạp và xóa bản nháp công việc ngoại tuyến', () async {
      const taskId = 'task-demo-123';
      expect(await OfflineTaskDraftService.hasDraft(taskId), false);

      await OfflineTaskDraftService.saveDraft(
        taskId: taskId,
        result: 'Đã hoàn thành kiểm tra vòi tưới',
        imageUrls: ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
      );

      expect(await OfflineTaskDraftService.hasDraft(taskId), true);

      final draft = await OfflineTaskDraftService.getDraft(taskId);
      expect(draft, isNotNull);
      expect(draft!.result, 'Đã hoàn thành kiểm tra vòi tưới');
      expect(draft.imageUrls.length, 2);
      expect(draft.imageUrls.first, 'https://example.com/img1.jpg');

      await OfflineTaskDraftService.clearDraft(taskId);
      expect(await OfflineTaskDraftService.hasDraft(taskId), false);
      expect(await OfflineTaskDraftService.getDraft(taskId), isNull);
    });
  });

  group('OfflineGisCacheService Tests', () {
    test('Lưu và đọc đệm toạ độ ranh giới Zone ngoại tuyến', () async {
      const farmId = 'farm-abc-001';
      final zones = [
        {
          'zoneId': 'zone-1',
          'name': 'Khu Dưa Lưới',
          'points': [
            [11.94, 108.44],
            [11.95, 108.44],
            [11.95, 108.45],
            [11.94, 108.44],
          ],
        }
      ];

      await OfflineGisCacheService.cacheFarmZoneBoundaries(farmId, zones);
      final cached = await OfflineGisCacheService.getCachedFarmZoneBoundaries(farmId);
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first['name'], 'Khu Dưa Lưới');
    });

    test('Lưu và đọc đệm danh sách node thiết bị ngoại tuyến', () async {
      const zoneId = 'zone-xyz-789';
      final nodes = [
        {'id': 'node-1', 'code': 'SN-01', 'latitude': 11.945, 'longitude': 108.445}
      ];

      await OfflineGisCacheService.cacheZoneNodes(zoneId, nodes);
      final cached = await OfflineGisCacheService.getCachedZoneNodes(zoneId);
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first['code'], 'SN-01');
    });
  });

  group('ImageCompressUtil Tests', () {
    test('Ảnh nhỏ hơn ngưỡng sizeThresholdBytes được giữ nguyên an toàn', () async {
      final smallBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final res = await ImageCompressUtil.optimizeForUpload(smallBytes);
      expect(res.length, 100);
      expect(res, equals(smallBytes));
    });
  });

  group('ShimmerLoading Widget Tests', () {
    testWidgets('ShimmerCardSkeleton dựng thành công và animate không lỗi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShimmerCardSkeleton(height: 150),
          ),
        ),
      );

      expect(find.byType(ShimmerLoading), findsOneWidget);
      expect(find.byType(ShimmerCardSkeleton), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
