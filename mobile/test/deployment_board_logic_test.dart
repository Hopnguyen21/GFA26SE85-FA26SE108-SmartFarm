import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/iot_deployment.dart';
import 'package:smartfarm_mobile/features/devices/deployment_board_logic.dart';

DeploymentRequest _req(
  String id,
  String status, {
  String zone = 'Nhà màng 1',
  String farm = 'Trang trại A',
  String? crop,
}) => DeploymentRequest.fromJson({
  'requestId': id,
  'farmId': 'f',
  'zoneId': 'z',
  'status': status,
  'requiredParameters': <String>[],
  'planItems': <Map<String, dynamic>>[],
  'surveys': <Map<String, dynamic>>[],
  'decisionHistory': <Map<String, dynamic>>[],
  'context': {
    'farmName': farm,
    'fieldName': 'Lô 1',
    'zoneName': zone,
    'zoneType': 'Greenhouse',
    'zoneAreaM2': 100.0,
    'cropName': crop,
    'seasonName': 'Vụ',
    'seasonStatus': 'InProgress',
    'seasonStartDate': '2026-11-01',
    'seasonExpectedEndDate': '2027-02-01',
  },
});

void main() {
  test(
    'bước trên thanh tiến trình: đúng thứ tự; thất bại đứng ở bước lắp đặt',
    () {
      expect(
        [for (final s in deploymentSteps) deploymentStepIndex(s.status)],
        [0, 1, 2, 3, 4, 5],
      );
      expect(deploymentStepIndex('MaintenanceRequired'), 4);
      expect(deploymentStepIndex('Draft'), -1);
      expect(deploymentStepIndex('không-biết'), -1);
    },
  );

  test(
    'việc tiếp theo có ở mọi trạng thái đang xử lý và không có khi đã xong',
    () {
      for (final s in [
        'Submitted',
        'Accepted',
        'Surveyed',
        'PlanConfirmed',
        'Installing',
        'MaintenanceRequired',
      ]) {
        expect(deploymentNextStepHint(s), isNotNull, reason: s);
      }
      expect(deploymentNextStepHint('Completed'), isNull);
      expect(deploymentNextStepHint('Draft'), isNull);
    },
  );

  test('nhóm và số đếm: đủ 4 nhóm kể cả nhóm rỗng, bỏ qua bản nháp', () {
    final items = [
      _req('1', 'Submitted'),
      _req('2', 'Submitted'),
      _req('3', 'Accepted'),
      _req('4', 'Installing'),
      _req('5', 'MaintenanceRequired'),
      _req('6', 'Draft'),
    ];
    final c = boardCounts(items);
    expect(c[BoardGroup.waiting], 2);
    expect(c[BoardGroup.active], 2);
    expect(c[BoardGroup.maintenance], 1);
    expect(c[BoardGroup.done], 0);
    expect(boardCounts(const []).values, everyElement(0));
  });

  test(
    'sắp theo mức khẩn: việc dở dang trước, chờ tiếp nhận, rồi bảo trì và hoàn tất',
    () {
      final out = boardView([
        _req('done', 'Completed'),
        _req('wait', 'Submitted'),
        _req('maint', 'MaintenanceRequired'),
        _req('accepted', 'Accepted'),
        _req('install', 'Installing'),
        _req('plan', 'PlanConfirmed'),
        _req('survey', 'Surveyed'),
      ]);
      expect(
        [for (final r in out) r.requestId],
        ['install', 'plan', 'survey', 'accepted', 'wait', 'maint', 'done'],
      );
    },
  );

  test('cùng mức khẩn thì giữ thứ tự của máy chủ', () {
    final out = boardView([
      for (var i = 0; i < 30; i++) _req('r$i', 'Accepted'),
    ]);
    expect(
      [for (final r in out) r.requestId],
      [for (var i = 0; i < 30; i++) 'r$i'],
    );
  });

  test(
    'lọc theo nhóm và tìm kiếm không phân biệt hoa thường, theo Zone/trang trại/cây',
    () {
      final items = [
        _req('1', 'Submitted', zone: 'Nhà màng Lâm Đồng', farm: 'CNC Đà Lạt'),
        _req(
          '2',
          'Accepted',
          zone: 'Líp 00',
          farm: 'Đất Mầu',
          crop: 'Dưa lưới',
        ),
        _req('3', 'Installing', zone: 'Zone 11', farm: 'Đất Mầu'),
      ];
      expect(
        boardView(items, group: BoardGroup.active).map((r) => r.requestId),
        ['3', '2'],
      );
      expect(boardView(items, query: 'đất mầu').map((r) => r.requestId), [
        '3',
        '2',
      ]);
      expect(boardView(items, query: 'DƯA').map((r) => r.requestId), ['2']);
      expect(boardView(items, query: '  lâm  ').map((r) => r.requestId), ['1']);
      expect(
        boardView(items, group: BoardGroup.waiting, query: 'đất mầu'),
        isEmpty,
      );
      expect(boardView(items, query: 'không có').isEmpty, isTrue);
    },
  );

  test('bản nháp không hiện trên bảng việc của kỹ thuật viên', () {
    expect(boardView([_req('d', 'Draft')]), isEmpty);
  });

  test(
    'yêu cầu đã hủy không hiện trên bảng việc và không tính vào ô đếm nào',
    () {
      final items = [_req('c', 'Cancelled'), _req('s', 'Submitted')];
      expect([for (final r in boardView(items)) r.requestId], ['s']);
      expect(boardCounts(items)[BoardGroup.waiting], 1);
      expect(boardCounts(items).values.fold<int>(0, (a, b) => a + b), 1);
    },
  );

  test('chỉ hủy được từ Draft đến PlanConfirmed (khớp backend)', () {
    for (final s in [
      'Draft',
      'Submitted',
      'Accepted',
      'Surveyed',
      'PlanConfirmed',
    ]) {
      expect(canCancelDeployment(s), isTrue, reason: s);
    }
    for (final s in [
      'Installing',
      'Completed',
      'MaintenanceRequired',
      'Cancelled',
      'Unknown',
    ]) {
      expect(canCancelDeployment(s), isFalse, reason: s);
    }
  });
}
