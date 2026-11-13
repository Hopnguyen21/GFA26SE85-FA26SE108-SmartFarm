import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/zones/zone_auto_season.dart';

void main() {
  startSeasonTests();
  final today = DateTime(2026, 11, 12);

  test(
    'payload mặc định: bắt đầu hôm nay, dự kiến 90 ngày, đúng hồ sơ và cây',
    () {
      final p = buildAutoSeasonPayload(
        cropId: 'crop-1',
        cropName: ' Cà chua ',
        growthProfileId: 'profile-1',
        today: today,
      );
      expect(p, {
        'name': 'Vụ Cà chua 2026',
        'cropId': 'crop-1',
        'growthProfileId': 'profile-1',
        'startDate': '2026-11-12',
        'expectedEndDate': '2027-02-10',
      });
      expect(p.containsKey('varietyId'), isFalse);
    },
  );

  test('payload có giống khi hồ sơ thuộc một giống', () {
    final p = buildAutoSeasonPayload(
      cropId: 'c',
      cropName: '',
      growthProfileId: 'g',
      varietyId: 'v-1',
      today: today,
    );
    expect(p['varietyId'], 'v-1');
    expect(p['name'], 'Vụ 2026');
  });

  test('payload theo tên và ngày người dùng nhập trong form tạo Zone', () {
    final p = buildAutoSeasonPayload(
      cropId: 'c',
      cropName: 'Dưa lưới',
      growthProfileId: 'g',
      today: today,
      name: '  Vụ Tết  ',
      startDate: DateTime(2026, 11, 1),
      expectedEndDate: DateTime(2027, 1, 15),
    );
    expect(p['name'], 'Vụ Tết');
    expect(p['startDate'], '2026-11-01');
    expect(p['expectedEndDate'], '2027-01-15');

    // Tên để trống: đặt theo cây và năm của ngày bắt đầu; không nhập ngày kết thúc: sau ngày bắt đầu 90 ngày.
    final d = buildAutoSeasonPayload(
      cropId: 'c',
      cropName: 'Dưa lưới',
      growthProfileId: 'g',
      today: today,
      name: '   ',
      startDate: DateTime(2025, 12, 20),
    );
    expect(d['name'], 'Vụ Dưa lưới 2025');
    expect(d['expectedEndDate'], '2026-03-20');
  });

  test('ngày kết thúc sớm nhất = ngày bắt đầu + 20 ngày', () {
    expect(minSeasonEnd(DateTime(2026, 11, 20)), DateTime(2026, 12, 10));
    expect(autoSeasonDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('tạo vụ thành công: gọi API đúng Zone và báo đã tạo', () async {
    String? calledZone;
    Map<String, dynamic>? sent;
    final r = await autoCreateSeasonForNewZone(
      zoneId: 'zone-9',
      cropId: 'crop-1',
      cropName: 'Dưa lưới',
      growthProfileId: 'profile-1',
      now: today,
      createSeason: (z, body) async {
        calledZone = z;
        sent = body;
        return {'seasonId': 's-1'};
      },
    );
    expect(r.created, isTrue);
    expect(calledZone, 'zone-9');
    expect(sent?['name'], 'Vụ Dưa lưới 2026');
    expect(r.message, contains('Vụ Dưa lưới 2026'));
    expect(r.message, contains('2026-11-12 → 2027-02-10'));
  });

  test('tạo vụ lỗi: không ném, trả lý do để hiển thị', () async {
    final r = await autoCreateSeasonForNewZone(
      zoneId: 'zone-9',
      cropId: 'crop-1',
      cropName: 'Dưa lưới',
      growthProfileId: 'profile-1',
      now: today,
      createSeason: (_, _) async =>
          throw Exception('Zone đang có vụ đang canh tác.'),
    );
    expect(r.created, isFalse);
    expect(r.message, 'Chưa tạo được vụ trồng: Zone đang có vụ đang canh tác.');
  });
}

void startSeasonTests() {
  test('bắt đầu vụ thành công: gọi đúng Zone và vụ', () async {
    String? zone, season;
    final r = await startSeasonForZone(
      'z-1',
      's-1',
      start: (z, s) async {
        zone = z;
        season = s;
        return {'status': 'InProgress'};
      },
    );
    expect(r.ok, isTrue);
    expect((zone, season), ('z-1', 's-1'));
    expect(r.message, contains('đang canh tác'));
  });

  test('bắt đầu vụ bị từ chối: không ném, trả lý do', () async {
    final r = await startSeasonForZone(
      'z-1',
      's-1',
      start: (_, _) async =>
          throw Exception('Chưa đến ngày bắt đầu vụ dự kiến.'),
    );
    expect(r.ok, isFalse);
    expect(
      r.message,
      'Chưa bắt đầu được vụ: Chưa đến ngày bắt đầu vụ dự kiến.',
    );
  });
}
