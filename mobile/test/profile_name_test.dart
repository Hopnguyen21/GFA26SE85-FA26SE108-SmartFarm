import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/utils/profile_name.dart';

void main() {
  const base = 'Quy trình VietGAP Cà Chua Beefsteak Nhà Màng (90 ngày)';
  const guid = 'db1c890696164cd4b54b48652d334462';

  group('displayProfileName', () {
    test('bỏ mã GUID ở cuối; giữ tên Zone khi không biết Zone', () {
      expect(
        displayProfileName('$base · Nhà màng 03 - Khu Lâm Đồng · $guid'),
        '$base · Nhà màng 03 - Khu Lâm Đồng',
      );
      expect(displayProfileName('$base · $guid'), base);
    });

    test('biết tên Zone thì bỏ luôn đoạn tên Zone', () {
      expect(
        displayProfileName(
          '$base · Nhà màng 03 - Khu Lâm Đồng · $guid',
          zoneName: 'Nhà màng 03 - Khu Lâm Đồng',
        ),
        base,
      );
    });

    test('backend cắt tên Zone 40 ký tự: vẫn nhận ra', () {
      final zone = 'Nhà màng công nghệ cao số 03 khu vực Lâm Đồng phía Bắc';
      final cut = zone.substring(0, 40);
      expect(displayProfileName('$base · $cut · $guid', zoneName: zone), base);
    });

    test('GUID có gạch ngang cũng bị bỏ', () {
      expect(
        displayProfileName('$base · db1c8906-9616-4cd4-b54b-48652d334462'),
        base,
      );
    });

    test('tên người dùng đặt không bị đụng tới', () {
      expect(displayProfileName('Hồ sơ A · Vụ Tết'), 'Hồ sơ A · Vụ Tết');
      // Đoạn trùng tên Zone nhưng không có mã GUID vẫn được bỏ khi đúng tên Zone của chính Zone đó.
      expect(
        displayProfileName('Hồ sơ A · Nhà màng 1', zoneName: 'Nhà màng 1'),
        'Hồ sơ A',
      );
      expect(displayProfileName(null), '');
      expect(displayProfileNameOrNull(null), isNull);
    });

    test('withDisplayProfileNames làm sạch name và growthProfileName', () {
      final out = withDisplayProfileNames([
        {'name': '$base · $guid', 'cropId': 'c1'},
        {'growthProfileName': '$base · $guid', 'status': 'InProgress'},
        {'name': 'Hồ sơ chung'},
      ]);
      expect(out[0]['name'], base);
      expect(out[0]['cropId'], 'c1');
      expect(out[1]['growthProfileName'], base);
      expect(out[2]['name'], 'Hồ sơ chung');
    });
  });

  test('ZoneModel: tên hồ sơ gắn cho Zone không còn mã và tên Zone', () {
    final z = ZoneModel.fromJson(
      {
        'zoneId': 'z1',
        'name': 'Nhà màng 03 - Khu Lâm Đồng',
        'areaM2': 507,
        'growthProfileId': 'p1',
        'growthProfileName': '$base · Nhà màng 03 - Khu Lâm Đồng · $guid',
      },
      farmId: 'f1',
      fieldId: 'fl1',
    );
    expect(z.growthProfileName, base);
  });
}
