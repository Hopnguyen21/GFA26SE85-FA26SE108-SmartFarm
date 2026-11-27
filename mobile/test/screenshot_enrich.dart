// Làm giàu dữ liệu mẫu cho bộ chụp ảnh màn hình.
//
// Dữ liệu gốc là phản hồi THẬT của backend demo (xem mobile/tool/record_screenshot_fixtures.ps1) nhưng cơ sở dữ liệu demo chỉ có
// 0-2 bản ghi mỗi loại và gần như trống với Nông dân/Kỹ thuật viên, nên ảnh chụp toàn trạng thái rỗng. Ở đây ta NHÂN BẢN bản ghi
// thật rồi đổi trạng thái/giá trị để mỗi màn có nhiều trạng thái đại diện. Chỉ dùng cho ảnh chụp, không liên quan mã ứng dụng.
import 'dart:convert';

dynamic _clone(Object? v) => jsonDecode(jsonEncode(v));

String _guid(String prefix, int n) =>
    '$prefix-0000-0000-0000-${n.toString().padLeft(12, '0')}';

String _iso(Duration ago) =>
    DateTime.now().toUtc().subtract(ago).toIso8601String();

/// Bản sao của [base] với các trường ghi đè.
Map<String, dynamic> _with(Map base, Map<String, dynamic> over) {
  final m = (_clone(base) as Map).cast<String, dynamic>();
  m.addAll(over);
  return m;
}

const _techId = '20000000-0000-0000-0000-000000000004';
const _farmerId = '20000000-0000-0000-0000-000000000002';

// Ranh giới mẫu (Đà Lạt) để bản đồ GIS có vùng vẽ thay vì thông báo "chưa có ranh giới".
Map<String, dynamic> _polygon(double w, double s, double e, double n) => {
  'type': 'Polygon',
  'coordinates': [
    [
      [w, n],
      [e, n],
      [e, s],
      [w, s],
      [w, n],
    ],
  ],
};

/// Trả dữ liệu đã làm giàu cho (vai trò, khóa 'METHOD /đường/dẫn'); không có quy tắc thì trả nguyên [data].
dynamic enrichFixture(String role, String key, dynamic data) {
  bool endsWith(String s) => key.endsWith(s);
  bool matches(String re) => RegExp(re).hasMatch(key);
  final list = data is List ? data : const [];

  // ── Telemetry/thiết bị: số đo mới, thiết bị Online, biểu đồ nhiều điểm (dữ liệu demo gốc đã cũ vì seed từ lâu) ──
  Map<String, dynamic> freshMetric(Map m, int i) => _with(m, {
    'capturedAtUtc': _iso(Duration(minutes: 1 + i)),
    'receivedAtUtc': _iso(Duration(minutes: 1 + i)),
    'isFresh': true,
  });
  if (matches(r'/telemetry/latest$') && data is Map) {
    final ms = [...(data['metrics'] as List? ?? const [])];
    // Bộ mẫu gốc không có số đo ánh sáng; app chỉ coi Zone là "đang nhận tín hiệu" khi đủ nhiệt độ, độ ẩm đất, độ ẩm không khí và ánh sáng.
    if (!ms.any(
      (m) => '${(m as Map)['parameterCode']}'.toLowerCase().contains('light'),
    )) {
      ms.add({
        'parameterCode': 'Light',
        'value': 18400.0,
        'unit': 'lux',
        'thresholdStatus': 'Normal',
      });
    }
    return _with(data, {
      'latestReceivedAtUtc': _iso(const Duration(minutes: 1)),
      'hasFreshTelemetry': true,
      'metrics': [
        for (var i = 0; i < ms.length; i++) freshMetric(ms[i] as Map, i),
      ],
    });
  }
  if (matches(r'/telemetry/latest-by-device$') && data is Map) {
    return _with(data, {
      'devices': [
        for (final d in (data['devices'] as List? ?? const []))
          _with(d as Map, {
            'status': 'Online',
            'batteryLevel': 87,
            'rssi': -62,
            'metrics': [
              for (var i = 0; i < (d['metrics'] as List).length; i++)
                freshMetric((d['metrics'] as List)[i] as Map, i),
            ],
          }),
      ],
    });
  }
  if (matches(r'/telemetry/history$') && data is Map) {
    final now = DateTime.now().toUtc();
    final top = DateTime.utc(now.year, now.month, now.day, now.hour);
    return _with(data, {
      'data': [
        for (var h = 23; h >= 0; h--)
          {
            'bucketStartUtc': top
                .subtract(Duration(hours: h))
                .toIso8601String(),
            'average':
                58 + 6 * (h % 6 == 0 ? -1 : 1) * ((h % 5) / 5.0) + (h % 3),
            'minimum': 54 + (h % 3),
            'maximum': 63 + (h % 4),
            'count': 12,
          },
      ],
    });
  }
  if (matches(r'/(devices|gateways)$') &&
      list.isNotEmpty &&
      list.first is Map &&
      (list.first as Map).containsKey('status')) {
    return [
      for (final d in list)
        _with(d as Map, {
          'status': 'Online',
          'lastSeenAtUtc': _iso(const Duration(minutes: 1)),
          'heartbeatIntervalSeconds': 30,
        }),
    ];
  }
  if (matches(r'/gateways/[^/]+$') && data is Map) {
    return _with(data, {
      'status': 'Online',
      'lastSeenAtUtc': _iso(const Duration(minutes: 1)),
    });
  }
  if (matches(r'/mqtt-status$') && data is Map) {
    return _with(data, {
      'mqttConnected': true,
      'lastHeartbeatAtUtc': _iso(const Duration(seconds: 20)),
    });
  }
  if (matches(r'/actuators/history$') && data is Map) {
    final cmds = (data['commands'] as List? ?? const []);
    if (cmds.isNotEmpty) {
      Map<String, dynamic> cmd(
        int n,
        String action,
        String status,
        Duration ago,
        String src,
      ) => _with(cmds.first as Map, {
        'commandId': _guid('63000000', 100 + n),
        'action': action,
        'status': status,
        'triggerSource': src,
        'queuedAtUtc': _iso(ago),
        'sentAtUtc': _iso(ago - const Duration(seconds: 5)),
        'acknowledgedAtUtc': status == 'Acknowledged'
            ? _iso(ago - const Duration(seconds: 12))
            : null,
      });
      return _with(data, {
        'commands': [
          cmd(1, 'TurnOn', 'Acknowledged', const Duration(hours: 1), 'Manual'),
          cmd(
            2,
            'TurnOff',
            'Acknowledged',
            const Duration(minutes: 50),
            'Manual',
          ),
          cmd(
            3,
            'TurnOn',
            'Acknowledged',
            const Duration(hours: 5),
            'Schedule',
          ),
          cmd(
            4,
            'TurnOff',
            'Acknowledged',
            const Duration(hours: 4, minutes: 45),
            'Schedule',
          ),
          cmd(5, 'TurnOn', 'Failed', const Duration(hours: 9), 'Rule'),
        ],
      });
    }
  }

  // ── Cấu trúc trang trại: có ranh giới để bản đồ GIS hiển thị ──
  if (matches(r'^GET /api/v1/farms/[^/]+/fields$') && list.isNotEmpty) {
    return [
      for (final f in list)
        _with(f as Map, {
          'boundaryGeoJson': _polygon(108.4560, 11.9390, 108.4600, 11.9420),
        }),
    ];
  }
  if (matches(r'^GET /api/v1/fields/[^/]+/zones$') && list.isNotEmpty) {
    return [
      for (final z in list)
        _with(z as Map, {
          'boundaryGeoJson': _polygon(108.4570, 11.9398, 108.4590, 11.9410),
        }),
    ];
  }
  if (endsWith('/devices/map-locations') && list.isNotEmpty) {
    var i = 0;
    return [
      for (final d in list)
        _with(d as Map, {
          'gpsLatitude': 11.9399 + 0.0004 * (i),
          'gpsLongitude': 108.4574 + 0.0006 * (i),
          'latitude': 11.9399 + 0.0004 * (i),
          'longitude': 108.4574 + 0.0006 * (i++),
          'status': 'Online',
          'lastSeenAtUtc': _iso(const Duration(minutes: 1)),
        }),
    ];
  }

  // ── Công việc ──
  if (matches(r'^GET /api/v1/farms/[^/]+/tasks$') && list.isNotEmpty) {
    final base = list.first as Map;
    Map<String, dynamic> task(
      int n,
      String title,
      String status,
      int pct,
      Duration due, {
      String? result,
    }) {
      final a = (base['assignments'] as List).isNotEmpty
          ? ((base['assignments'] as List).first as Map)
          : <String, dynamic>{};
      return _with(base, {
        'id': _guid('73000000', n),
        'title': title,
        'status': status,
        'dueAtUtc': DateTime.now().toUtc().add(due).toIso8601String(),
        'createdAtUtc': _iso(const Duration(days: 1)),
        'assignments': [
          _with(a, {
            'id': _guid('73200000', n),
            'farmerId': _farmerId,
            'status': status,
            'progressPercent': pct,
            'progressNote': pct > 0 && pct < 100
                ? 'Đã xong $pct% khối lượng'
                : null,
            'result': result,
          }),
        ],
      });
    }

    return [
      ...list,
      task(
        2,
        'Bón phân NPK cho luống số 3',
        'Pending',
        0,
        const Duration(days: 2),
      ),
      task(
        3,
        'Phun thuốc sinh học phòng nấm phấn trắng',
        'InProgress',
        60,
        const Duration(days: 1),
      ),
      task(
        4,
        'Thu hoạch dưa leo đợt 1 (khu A)',
        'CompletedPendingReview',
        100,
        const Duration(hours: -3),
        result: 'Thu được 85 kg, loại 1 đạt 92%.',
      ),
    ];
  }

  // ── Cảnh báo ──
  if ((matches(r'^GET /api/v1/farms/[^/]+/alerts$') ||
          matches(r'^GET /api/v1/zones/[^/]+/alerts$')) &&
      list.isNotEmpty) {
    final base = list.first as Map;
    Map<String, dynamic> alert(
      int n,
      String param,
      double v,
      double lo,
      double hi,
      String unit,
      String sev,
      String status,
      String title,
      Duration ago,
    ) => _with(base, {
      'alertId': _guid('62000000', n),
      'parameterCode': param,
      'observedValue': v,
      'minThreshold': lo,
      'maxThreshold': hi,
      'unit': unit,
      'severity': sev,
      'status': status,
      'title': title,
      'createdAtUtc': _iso(ago),
      'acknowledgedAtUtc': status == 'Open'
          ? null
          : _iso(ago - const Duration(minutes: 10)),
      'resolvedAtUtc': status == 'Resolved'
          ? _iso(ago - const Duration(minutes: 40))
          : null,
      'history': <dynamic>[],
    });
    return [
      ...list,
      alert(
        2,
        'Temperature',
        35.2,
        18,
        30,
        '°C',
        'Critical',
        'Open',
        'Nhiệt độ vượt ngưỡng tối đa 30°C',
        const Duration(minutes: 25),
      ),
      alert(
        3,
        'AirHumidity',
        41,
        45,
        85,
        '%',
        'Warning',
        'Acknowledged',
        'Độ ẩm không khí thấp hơn ngưỡng 45%',
        const Duration(hours: 3),
      ),
      alert(
        4,
        'Ph',
        6.1,
        5.5,
        6.8,
        '',
        'Info',
        'Resolved',
        'pH đã trở lại ngưỡng cho phép',
        const Duration(hours: 9),
      ),
    ];
  }

  // ── Thông báo (mọi vai trò; Nông dân/Kỹ thuật viên trong cơ sở dữ liệu demo không có thông báo nào) ──
  if (matches(r'^GET /api/v1/notifications$')) {
    Map<String, dynamic> n(
      int i,
      String title,
      String msg,
      String type,
      String sev,
      bool read,
      Duration ago,
    ) => {
      'notificationId': _guid('69000000', i),
      'userId': _techId,
      'tenantId': '10000000-0000-0000-0000-000000000001',
      'title': title,
      'message': msg,
      'type': type,
      'severity': sev,
      'isRead': read,
      'readAtUtc': read ? _iso(ago - const Duration(minutes: 5)) : null,
      'targetUrl': null,
      'referenceId': null,
      'createdAtUtc': _iso(ago),
    };
    if (role == 'technician') {
      return [
        n(
          1,
          'Bạn có yêu cầu mới',
          'Yêu cầu lắp đặt IoT tại Phân Khu 1 vừa được giao cho bạn.',
          'Service',
          'Info',
          false,
          const Duration(minutes: 12),
        ),
        n(
          2,
          'Chủ trang trại đã ký hợp đồng và đóng cọc',
          'Có thể bắt đầu lắp đặt và gắn Node.',
          'Service',
          'Info',
          false,
          const Duration(hours: 2),
        ),
        n(
          3,
          'Phiếu xuất kho đã duyệt',
          'Phiếu PXK-2026-014 đã được Admin duyệt.',
          'StockOut',
          'Info',
          true,
          const Duration(hours: 6),
        ),
        n(
          4,
          'Chủ trang trại đã ký nghiệm thu',
          'Yêu cầu lắp đặt đã hoàn tất thanh toán.',
          'Service',
          'Info',
          true,
          const Duration(days: 1),
        ),
      ];
    }
    if (role == 'farmer') {
      return [
        n(
          1,
          'Bạn được giao công việc mới',
          'Bón phân NPK cho luống số 3 (hạn sau 2 ngày).',
          'Task',
          'Info',
          false,
          const Duration(minutes: 30),
        ),
        n(
          2,
          'Cảnh báo độ ẩm đất Phân Khu 1',
          'Độ ẩm đất 52,4%, thấp hơn ngưỡng tối thiểu 55%.',
          'Alert',
          'Warning',
          false,
          const Duration(hours: 1),
        ),
        n(
          3,
          'Công việc đã được duyệt',
          'Kiểm tra đường ống tưới nhỏ giọt đã được chủ trang trại duyệt.',
          'Task',
          'Info',
          true,
          const Duration(days: 1),
        ),
      ];
    }
    return [
      ...list,
      n(
        2,
        'Khuyến nghị AI mới',
        'AI đề xuất bật bơm tưới Phân Khu 1 trong 5 phút.',
        'Advice',
        'Info',
        false,
        const Duration(minutes: 20),
      ),
      n(
        3,
        'Công việc chờ duyệt',
        'Thu hoạch dưa leo đợt 1 đã được nông dân báo hoàn thành.',
        'Task',
        'Info',
        false,
        const Duration(hours: 3),
      ),
      n(
        4,
        'Hóa đơn sắp đến hạn',
        'BILL-2026-002 đến hạn thanh toán sau 5 ngày.',
        'Bill',
        'Warning',
        true,
        const Duration(days: 2),
      ),
    ];
  }

  // ── Kho vật tư ──
  if (matches(r'^GET /api/v1/farms/[^/]+/inventory$') && list.isNotEmpty) {
    final base = list.first as Map;
    Map<String, dynamic> item(
      int n,
      String name,
      String type,
      String unit,
      double qty,
      double low,
    ) => _with(base, {
      'id': _guid('70000000', n),
      'name': name,
      'materialType': type,
      'unit': unit,
      'quantityOnHand': qty,
      'lowStockThreshold': low,
      'isLowStock': qty <= low,
      'requirements': <dynamic>[],
    });
    return [
      ...list,
      item(2, 'Hạt giống Dưa leo Baby F1', 'Seed', 'gói', 120, 30),
      item(3, 'Thuốc bảo vệ thực vật sinh học', 'Pesticide', 'lít', 12, 15),
      item(4, 'Phân hữu cơ vi sinh', 'Fertilizer', 'kg', 480, 100),
      item(5, 'Dây tưới nhỏ giọt Ø16', 'Equipment', 'm', 300, 100),
    ];
  }

  // ── Hóa đơn ──
  if (endsWith('/api/v1/bills') && list.isNotEmpty) {
    final base = list.first as Map;
    Map<String, dynamic> bill(
      int n,
      String code,
      double amount,
      double paid,
      String status,
      String text,
      int dueDays,
    ) => _with(base, {
      'id': _guid('93000000', n),
      'billCode': code,
      'amount': amount,
      'paidAmount': paid,
      'remainingAmount': amount - paid,
      'status': status,
      'statusText': text,
      'paidDate': paid > 0 ? _iso(const Duration(days: 3)) : null,
      'issueDate': DateTime.now()
          .subtract(const Duration(days: 10))
          .toIso8601String()
          .substring(0, 10),
      'dueDate': DateTime.now()
          .add(Duration(days: dueDays))
          .toIso8601String()
          .substring(0, 10),
    });
    return [
      bill(2, 'BILL-2026-002', 5000000, 0, 'Issued', 'Đã phát hành', 5),
      bill(
        3,
        'BILL-2026-003',
        8000000,
        3000000,
        'PartiallyPaid',
        'Đã thanh toán một phần',
        12,
      ),
      ...list,
    ];
  }

  // ── Phiếu dịch vụ ──
  if (endsWith('/api/v1/service-requests') && list.isNotEmpty) {
    final base = list.first as Map;
    // Phiếu lắp đặt mới (n=2) đã ký hợp đồng + đóng cọc 30% và gắn đúng yêu cầu triển khai "Installing": màn Gắn Node mới mở bản đồ thay vì khóa.
    Map<String, dynamic> sr(
      int n,
      String code,
      String desc,
      String status, {
      bool tech = false,
    }) => _with(base, {
      if (n == 2) ...{
        'isContractSigned': true,
        'isDepositPaid': true,
        'isAcceptanceSigned': false,
        'isFullyPaid': false,
        'deploymentRequestId': _guid('50000000', 5),
      },
      'id': _guid('80000000', n),
      'failureCode': code,
      'description': desc,
      'status': status,
      'assignedTechnicianId': (tech || status != 'Open') ? _techId : null,
      'createdAtUtc': _iso(Duration(days: n)),
    });
    return [
      sr(
        2,
        'NEW_INSTALL',
        'Lắp đặt thêm trạm cảm biến cho Phân Khu 1',
        'Assigned',
        tech: true,
      ),
      sr(
        3,
        'SENSOR_FAULT',
        'Cảm biến độ ẩm đất báo giá trị bất thường',
        'InProgress',
        tech: true,
      ),
      sr(
        4,
        'MAINTENANCE_CORRECTIVE',
        'Van điện từ không đóng hoàn toàn',
        'Resolved',
        tech: true,
      ),
      ...list,
    ];
  }

  // ── Yêu cầu triển khai (Chủ: /deployment-requests, Kỹ thuật viên: /platform/deployment-requests) ──
  if ((endsWith('/api/v1/deployment-requests') ||
          endsWith('/api/v1/platform/deployment-requests')) &&
      list.isNotEmpty) {
    final base = list.first as Map;
    Map<String, dynamic> dep(int n, String status, {bool tech = true}) =>
        _with(base, {
          'requestId': _guid('50000000', n),
          'status': status,
          'technicianUserId': tech ? _techId : null,
          'ownerNotes': 'Yêu cầu triển khai hệ thống IoT cho khu canh tác mới.',
        });
    return [
      dep(2, 'Submitted', tech: false),
      dep(3, 'Accepted'),
      dep(4, 'Surveyed'),
      dep(5, 'Installing'),
      ...list,
    ];
  }

  // ── Lời mời Farm ──
  if (matches(r'^GET /api/v1/farms/[^/]+/invitations$') && list.isNotEmpty) {
    final base = list.first as Map;
    return [
      _with(base, {
        'id': _guid('75000000', 2),
        'email': 'thao@smartfarm.demo',
        'status': 'Pending',
      }),
      _with(base, {
        'id': _guid('75000000', 3),
        'email': 'minh@smartfarm.demo',
        'status': 'Declined',
      }),
      ...list,
    ];
  }
  if (endsWith('/api/v1/farm-invitations/mine') && list.isEmpty) {
    return [
      {
        'id': _guid('75000000', 9),
        'farmId': '30000000-0000-0000-0000-000000000001',
        'farmName': 'Trang Trại Công Nghệ Cao Đà Lạt Eco',
        'email': 'farmer@smartfarm.demo',
        'status': 'Pending',
        'createdAtUtc': _iso(const Duration(hours: 5)),
        'expiresAtUtc': DateTime.now()
            .toUtc()
            .add(const Duration(days: 6))
            .toIso8601String(),
      },
    ];
  }

  // ── Phiếu xuất kho (Kỹ thuật viên) ──
  if (matches(r'^GET /api/v1/farms/[^/]+/stock-outs$') && list.isEmpty) {
    Map<String, dynamic> so(
      int n,
      String code,
      String status,
      String text,
      String zone,
    ) => {
      'id': _guid('94000000', n),
      'tenantId': '10000000-0000-0000-0000-000000000001',
      'farmId': '30000000-0000-0000-0000-000000000001',
      'farmName': 'Trang Trại Công Nghệ Cao Đà Lạt Eco',
      'zoneId': '32000000-0000-0000-0000-000000000001',
      'zoneName': zone,
      'stockOutCode': code,
      'status': status,
      'statusText': text,
      'createdByUserId': _techId,
      'createdByName': 'Lê Kỹ Thuật Viên',
      'approvedByUserId': status == 'Approved'
          ? '20000000-0000-0000-0000-000000000003'
          : null,
      'approvedByName': status == 'Approved' ? 'Tổng Quản Trị Hệ Thống' : null,
      'completedAtUtc': null,
      'notes': 'Xuất thiết bị lắp đặt theo hợp đồng.',
      'createdAtUtc': _iso(Duration(hours: n * 6)),
      'details': [
        {
          'id': _guid('94100000', n),
          'stockOutId': _guid('94000000', n),
          'inventoryItemId': _guid('88000000', 1),
          'itemName': 'Trạm LoRa Gateway Ngoài Trời SX1302 8 Kênh',
          'unit': 'cái',
          'quantity': 1,
          'currentStock': 20,
          'notes': null,
        },
        {
          'id': _guid('94100000', n + 10),
          'stockOutId': _guid('94000000', n),
          'inventoryItemId': _guid('88000000', 3),
          'itemName': 'Node Điều Khiển Bơm & Van Điện Từ 2 Kênh Relay',
          'unit': 'cái',
          'quantity': 2,
          'currentStock': 18,
          'notes': null,
        },
      ],
    };
    return [
      so(
        1,
        'PXK-2026-014',
        'Approved',
        'Đã duyệt',
        'Phân Khu 1 - Nhà Màng Dưa Leo Baby',
      ),
      so(
        2,
        'PXK-2026-015',
        'Pending',
        'Chờ duyệt',
        'Phân Khu 1 - Nhà Màng Dưa Leo Baby',
      ),
    ];
  }

  return data;
}
