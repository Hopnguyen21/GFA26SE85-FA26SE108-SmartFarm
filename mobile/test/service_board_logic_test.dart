import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/features/support/service_board_logic.dart';
import 'package:smartfarm_mobile/core/models/models.dart'
    show ZoneContractModel;

Map<String, dynamic> _r(
  String id,
  String code,
  String status, {
  String desc = '',
}) => {'id': id, 'failureCode': code, 'status': status, 'description': desc};

String _status(Map<String, dynamic> r) => '${r['status']}';

void main() {
  zoneContractTests();
  maintenanceMessageTest();
  group('ownerNextAction (việc đang chờ Owner)', () {
    ({String text, bool needsAction}) o(String? q, String? d) =>
        ownerNextAction(quotationStatus: q, deploymentStatus: d, closed: false);
    test('hợp đồng đã gửi: Owner phải ký và cọc 30%', () {
      final r = o('SentToOwner', 'Surveyed');
      expect(r.needsAction, isTrue);
      expect(r.text, contains('cọc 30%'));
    });
    test('đã cọc: chờ KTV; KTV hoàn tất thì Owner ký nghiệm thu 70%', () {
      expect(o('SignedByOwner', 'Installing').needsAction, isFalse);
      final r = o('SignedByOwner', 'Completed');
      expect(r.needsAction, isTrue);
      expect(r.text, contains('70%'));
    });
    test(
      'chưa có hợp đồng / đã nghiệm thu / đã đóng: không đòi Owner làm gì',
      () {
        expect(o(null, 'Accepted').needsAction, isFalse);
        expect(o('Completed', 'Completed').needsAction, isFalse);
        expect(
          ownerNextAction(
            quotationStatus: 'SentToOwner',
            deploymentStatus: null,
            closed: true,
          ).needsAction,
          isFalse,
        );
      },
    );
  });

  group('installNextAction (một thẻ, thao tác đổi theo tiến độ)', () {
    String a(String? q, String? d, {bool closed = false}) => installNextAction(
      quotationStatus: q,
      deploymentStatus: d,
      closed: closed,
    );
    test(
      'trước cọc 30%: tiếp nhận → khảo sát → tạo/gửi hợp đồng → chờ Owner',
      () {
        expect(a(null, 'Submitted'), 'Tiếp nhận');
        expect(a(null, 'Accepted'), 'Khảo sát');
        expect(a(null, 'Surveyed'), 'Tạo và gửi hợp đồng');
        expect(a(null, 'PlanConfirmed'), 'Tạo và gửi hợp đồng');
        expect(a('SentToOwner', 'Surveyed'), 'Chờ Owner thanh toán cọc 30%');
      },
    );
    test('đã cọc: chuyển sang triển khai → chấm node → hoàn tất', () {
      expect(a('SignedByOwner', 'PlanConfirmed'), contains('Gắn Node'));
      expect(a('SignedByOwner', 'Installing'), contains('Gắn Node'));
    });
    test('sau hoàn tất: chờ 70% và nghiệm thu → đóng công việc', () {
      expect(
        a('SignedByOwner', 'Completed'),
        'Chờ Owner thanh toán 70% và nghiệm thu',
      );
      expect(a('Completed', 'Completed'), 'Đóng công việc');
      expect(a('Completed', 'Completed', closed: true), 'Đã đóng công việc');
    });
    test(
      'phiếu chưa nhận (Open/Assigned): không còn bước nhận việc, vào thẳng bước triển khai',
      () {
        for (final s in ['Open', 'Assigned']) {
          expect(
            installNextAction(
              serviceStatus: s,
              quotationStatus: null,
              deploymentStatus: 'Accepted',
              closed: false,
            ),
            'Khảo sát',
          );
        }
      },
    );
    test('thất bại / hủy không đòi thao tác lắp đặt', () {
      expect(a('SignedByOwner', 'MaintenanceRequired'), contains('bảo trì'));
      expect(a(null, 'Cancelled'), 'Yêu cầu đã bị hủy');
    });
  });

  quyTrinhTests();
  test(
    'loại yêu cầu: INSTALLATION và NEW_INSTALL là lắp đặt (không phân biệt hoa thường), còn lại là bảo trì',
    () {
      expect(
        serviceKindOf(_r('1', 'INSTALLATION', 'Open')),
        ServiceKind.installation,
      );
      expect(
        serviceKindOf(_r('2', 'NEW_INSTALL', 'Open')),
        ServiceKind.installation,
      );
      expect(
        serviceKindOf(_r('3', 'new_install', 'Open')),
        ServiceKind.installation,
      );
      expect(
        serviceKindOf(_r('4', 'SENSOR_OFFLINE', 'Open')),
        ServiceKind.maintenance,
      );
      expect(serviceKindOf({'status': 'Open'}), ServiceKind.maintenance);
    },
  );

  test(
    'bộ lọc: lắp đặt/bảo trì chỉ tính yêu cầu chưa đóng và chưa sẵn sàng đóng',
    () {
      final items = [
        _r('a', 'INSTALLATION', 'Assigned'),
        _r('b', 'NEW_INSTALL', 'InProgress'),
        _r('c', 'INSTALLATION', 'Verified'),
        _r('d', 'SENSOR_OFFLINE', 'Diagnosed'),
        _r('e', 'SENSOR_OFFLINE', 'Resolved'),
        _r('f', 'SENSOR_OFFLINE', 'Closed'),
        _r('g', 'SENSOR_OFFLINE', 'Cancelled'), // đã hủy: không còn việc
      ];
      final c = serviceCounts(items, _status);
      expect(c[ServiceFilter.installation], 2);
      expect(c[ServiceFilter.maintenance], 2);
      expect(c[ServiceFilter.ready], 1);
      expect(isReadyToClose('Resolved'), isFalse);
      expect(c[ServiceFilter.closed], 2); // Closed + Cancelled
      expect(serviceCounts(const [], _status).values, everyElement(0));
    },
  );

  test(
    'sắp theo mức khẩn: mới giao trước, đang làm, chờ đóng, đã đóng cuối; cùng mức giữ thứ tự gốc',
    () {
      final out = serviceView([
        _r('closed', 'X', 'Closed'),
        _r('prog1', 'X', 'InProgress'),
        _r('assigned', 'X', 'Assigned'),
        _r('prog2', 'X', 'InProgress'),
        _r('ready', 'X', 'Verified'),
        _r('diag', 'X', 'Diagnosed'),
      ], statusOf: _status);
      expect(
        [for (final r in out) r['id']],
        ['assigned', 'prog1', 'prog2', 'diag', 'ready', 'closed'],
      );
    },
  );

  test('lọc theo bộ lọc và tìm kiếm (mô tả, mã lỗi, tên Zone/trang trại)', () {
    final items = [
      _r('1', 'INSTALLATION', 'Assigned', desc: 'Lắp đặt cho Nhà màng 03.'),
      _r('2', 'SENSOR_OFFLINE', 'InProgress', desc: 'Cảm biến mất tín hiệu.'),
      _r('3', 'NEW_INSTALL', 'Closed', desc: 'Đã xong.'),
    ];
    String nameOf(Map<String, dynamic> r) =>
        r['id'] == '2' ? 'Líp 00 · Đất Mầu' : '';
    List<Object?> ids(List<Map<String, dynamic>> l) => [
      for (final r in l) r['id'],
    ];

    expect(
      ids(
        serviceView(
          items,
          statusOf: _status,
          filter: ServiceFilter.installation,
        ),
      ),
      ['1'],
    );
    expect(
      ids(serviceView(items, statusOf: _status, filter: ServiceFilter.closed)),
      ['3'],
    );
    expect(ids(serviceView(items, statusOf: _status, query: 'sensor')), ['2']);
    expect(
      ids(
        serviceView(items, statusOf: _status, query: 'ĐẤT MẦU', nameOf: nameOf),
      ),
      ['2'],
    );
    expect(
      ids(serviceView(items, statusOf: _status, query: 'không có')),
      isEmpty,
    );
  });

  test('tiêu đề lấy câu đầu của mô tả, rỗng thì dùng mã lỗi', () {
    expect(
      serviceTitle(
        _r(
          '1',
          'INSTALLATION',
          'Open',
          desc: 'Yêu cầu khảo sát và lắp đặt IoT cho Zone. Chi tiết khác',
        ),
      ),
      'Yêu cầu khảo sát và lắp đặt IoT cho Zone',
    );
    expect(serviceTitle(_r('2', 'SENSOR_OFFLINE', 'Open')), 'SENSOR_OFFLINE');
    expect(serviceTitle({'status': 'Open'}), 'Yêu cầu hỗ trợ kỹ thuật');
  });

  test('giai đoạn báo giá/hợp đồng theo trạng thái báo giá', () {
    expect(contractStageLabel(null), 'Chưa tạo hợp đồng');
    expect(contractStageLabel('SentToOwner'), 'Đã gửi HĐ · chờ Owner cọc 30%');
    expect(contractStageLabel('SignedByOwner'), 'Đã thanh toán 30% cọc');
    expect(contractStageLabel('Completed'), 'Đã nghiệm thu 100%');
  });
}

void quyTrinhTests() {
  List<FlowStepState> states(
    String? quote,
    String? dep, {
    bool closed = false,
  }) => [
    for (final s in installFlowSteps(
      quotationStatus: quote,
      deploymentStatus: dep,
      closed: closed,
    ))
      s.state,
  ];
  const d = FlowStepState.done,
      c = FlowStepState.current,
      t = FlowStepState.todo;

  test('quy trình lắp đặt: chưa có báo giá thì đang ở bước 1', () {
    expect(states(null, null), [c, t, t, t]);
    expect(states('Draft', null), [c, t, t, t]);
  });

  test('đã gửi báo giá: chờ Owner ký và cọc', () {
    expect(states('SentToOwner', 'Surveyed'), [d, c, t, t]);
  });

  test('Owner đã ký và cọc: tới bước thi công, chưa nghiệm thu', () {
    expect(states('SignedByOwner', 'Installing'), [d, d, c, t]);
    expect(states('DepositPaid', null), [d, d, c, t]);
  });

  test('triển khai hoàn tất: chờ nghiệm thu 70%', () {
    expect(states('SignedByOwner', 'Completed'), [d, d, d, c]);
  });

  test('đã nghiệm thu hoặc phiếu đã đóng: xong cả bốn bước', () {
    expect(states('Completed', 'Completed'), [d, d, d, d]);
    expect(states('Completed', null), [d, d, d, d]);
    expect(states('SignedByOwner', 'Completed', closed: true), [d, d, d, d]);
  });

  test('dữ liệu chưa biết không bị coi là đã xong', () {
    expect(states('SignedByOwner', null), [d, d, c, t]);
  });

  group('effectiveQuotationStatus (cờ trên phiếu dịch vụ)', () {
    test('không có cờ: giữ nguyên trạng thái báo giá', () {
      expect(
        effectiveQuotationStatus('SentToOwner', {'isDepositPaid': false}),
        'SentToOwner',
      );
      expect(effectiveQuotationStatus(null, null), isNull);
      expect(effectiveQuotationStatus(null, {}), isNull);
    });
    test(
      'cờ đã cọc / đã ký: coi là SignedByOwner kể cả khi đọc báo giá lỗi',
      () {
        expect(
          effectiveQuotationStatus(null, {'isDepositPaid': true}),
          'SignedByOwner',
        );
        expect(
          effectiveQuotationStatus('SentToOwner', {'isContractSigned': true}),
          'SignedByOwner',
        );
      },
    );
    test('cờ nghiệm thu / thanh toán đủ: Completed', () {
      expect(
        effectiveQuotationStatus('SignedByOwner', {'isFullyPaid': true}),
        'Completed',
      );
      expect(
        effectiveQuotationStatus(null, {'isAcceptanceSigned': true}),
        'Completed',
      );
      expect(
        effectiveQuotationStatus('Completed', {'isDepositPaid': true}),
        'Completed',
      );
    });
  });
}

ZoneContractModel _c(String status, String end, {int days = 0}) =>
    ZoneContractModel.fromJson({
      'id': 'c-$status-$end',
      'zoneName': 'Zone A',
      'contractNumber': 'HD-ZN-1',
      'status': status,
      'endDate': end,
      'daysRemaining': days,
    });

void zoneContractTests() {
  final today = DateTime(2026, 11, 18);
  group('mua thêm thiết bị: hợp đồng dịch vụ của Zone', () {
    test('Zone chưa có hợp đồng (lần lắp đầu): không chặn', () {
      expect(zoneContractBlockReason(const [], today), isNull);
    });
    test(
      'có hợp đồng đang hiệu lực còn hạn (kể cả sắp hết hạn): không chặn',
      () {
        expect(
          zoneContractBlockReason([_c('Active', '2027-03-01')], today),
          isNull,
        );
        expect(
          zoneContractBlockReason([_c('ExpiringSoon', '2026-11-18')], today),
          isNull,
        );
      },
    );
    test(
      'mọi hợp đồng đã hết hạn / thay thế / chấm dứt: chặn và nêu số hợp đồng + ngày hết hạn',
      () {
        final r = zoneContractBlockReason([
          _c('Expired', '2026-10-01'),
          _c('Renewed', '2026-06-01'),
        ], today);
        expect(r, contains('HD-ZN-1'));
        expect(r, contains('01/10/2026'));
        expect(
          zoneContractBlockReason([_c('Active', '2026-11-17')], today),
          isNotNull,
        );
      },
    );
    test('hợp đồng còn hiệu lực cũ hơn không che hợp đồng mới đã hết hạn', () {
      expect(
        zoneContractBlockReason([
          _c('Renewed', '2027-01-01'),
          _c('Expired', '2026-10-01'),
        ], today),
        isNotNull,
      );
    });
  });

  test('yêu cầu triển khai đang chạy: từ Gửi đến Đang lắp đặt', () {
    for (final s in [
      'Submitted',
      'Accepted',
      'Surveyed',
      'PlanConfirmed',
      'Installing',
    ]) {
      expect(deploymentRequestIsRunning(s), isTrue, reason: s);
    }
    for (final s in [
      'Draft',
      'Completed',
      'MaintenanceRequired',
      'Cancelled',
    ]) {
      expect(deploymentRequestIsRunning(s), isFalse, reason: s);
    }
  });
}

void maintenanceMessageTest() {
  test('thông báo chặn nêu đúng việc đang làm (bảo trì)', () {
    final r = zoneContractBlockReason(
      [_c('Expired', '2026-10-01')],
      DateTime(2026, 11, 18),
      action: 'gửi yêu cầu bảo trì',
    );
    expect(r, contains('gửi yêu cầu bảo trì'));
  });
}
