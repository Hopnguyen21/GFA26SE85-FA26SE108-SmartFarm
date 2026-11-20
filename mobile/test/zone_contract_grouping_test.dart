import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart'
    show ZoneContractModel;
import 'package:smartfarm_mobile/features/contracts/zone_contract_logic.dart';

ZoneContractModel _c(String id, String status, {String? parent}) =>
    ZoneContractModel.fromJson({
      'id': id,
      'contractNumber': 'HD-$id',
      'status': status,
      'parentContractId': parent,
    });

void main() {
  test(
    'hợp đồng bổ sung được gom dưới hợp đồng chính còn hiệu lực, giữ thứ tự',
    () {
      final g = groupContractsWithSupplements([
        _c('A', 'Active'),
        _c('S1', 'Active', parent: 'A'),
        _c('B', 'Active'),
        _c('S2', 'Active', parent: 'A'),
      ]);
      expect(g.map((e) => e.main.id), ['A', 'B']);
      expect(g[0].supplements.map((e) => e.id), ['S1', 'S2']);
      expect(g[1].supplements, isEmpty);
    },
  );

  test(
    'hợp đồng gia hạn (cha đã Renewed) hoặc không thấy cha thì đứng riêng',
    () {
      final g = groupContractsWithSupplements([
        _c('OLD', 'Renewed'),
        _c('NEW', 'Active', parent: 'OLD'),
        _c('ORPHAN', 'Active', parent: 'MISSING'),
      ]);
      expect(g.map((e) => e.main.id), ['OLD', 'NEW', 'ORPHAN']);
      expect(g.every((e) => e.supplements.isEmpty), isTrue);
    },
  );

  test('không có hợp đồng nào: danh sách rỗng', () {
    expect(groupContractsWithSupplements(const []), isEmpty);
  });
}
