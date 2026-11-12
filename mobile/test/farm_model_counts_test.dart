import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';

void main() {
  test(
    'FarmModel đọc số Zone/Thửa đất do backend đếm cho từng farm (GET /farms)',
    () {
      final f = FarmModel.fromJson({
        'farmId': 'f1',
        'name': 'Nong Trai Canh Tac Luong Dat Don Duong',
        'totalAreaM2': 35000,
        'fieldsCount': 2,
        'zonesCount': 3,
      });
      expect(f.zonesCount, 3);
      expect(f.fieldsCount, 2);
    },
  );

  test('backend không trả số lượng: để null (UI không được coi là 0)', () {
    final f = FarmModel.fromJson({
      'farmId': 'f1',
      'name': 'X',
      'totalAreaM2': 1000,
    });
    expect(f.zonesCount, isNull);
    expect(f.fieldsCount, isNull);
  });

  test('số lượng 0 thật sự là 0, khác với không có dữ liệu', () {
    final f = FarmModel.fromJson({
      'farmId': 'f1',
      'name': 'X',
      'totalAreaM2': 1000,
      'zonesCount': 0,
    });
    expect(f.zonesCount, 0);
  });
}
