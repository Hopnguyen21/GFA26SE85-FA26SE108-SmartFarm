import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/core/theme/app_theme.dart';
import 'screenshot_enrich.dart';

// Group 0: Public & Auth
import 'package:smartfarm_mobile/features/auth/landing_screen.dart';
import 'package:smartfarm_mobile/features/auth/login_screen.dart';
import 'package:smartfarm_mobile/features/auth/register_screen.dart';
import 'package:smartfarm_mobile/features/auth/password_screens.dart';

// Group 1, 2, 3: All Feature Screens
import 'package:smartfarm_mobile/features/home/home_screen.dart';
import 'package:smartfarm_mobile/features/farms/farms_management_screen.dart';
import 'package:smartfarm_mobile/features/farms/farm_setup_wizard_screen.dart';
import 'package:smartfarm_mobile/features/farms/gis_map_screen.dart';
import 'package:smartfarm_mobile/features/ai/ai_screen.dart';
import 'package:smartfarm_mobile/features/workforce/work_management_screen.dart';
import 'package:smartfarm_mobile/features/workforce/workforce_screen.dart';
import 'package:smartfarm_mobile/features/workforce/farm_invitations_screen.dart';
import 'package:smartfarm_mobile/features/zones/zone_detail_screen.dart';
import 'package:smartfarm_mobile/features/zones/zone_operations_screens.dart';
import 'package:smartfarm_mobile/features/alerts/zone_alert_center_screen.dart';
import 'package:smartfarm_mobile/features/monitoring/monitoring_history_screen.dart';
import 'package:smartfarm_mobile/features/crops/crop_profiles_screen.dart';
import 'package:smartfarm_mobile/features/crops/crop_detail_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/irrigation_calendar_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/season_irrigation_calendar_screen.dart';
import 'package:smartfarm_mobile/features/irrigation/schedules_automation_screen.dart';
import 'package:smartfarm_mobile/features/devices/device_health_screen.dart';
import 'package:smartfarm_mobile/features/devices/deployment_screens.dart';
import 'package:smartfarm_mobile/features/devices/deployment_request_send_screen.dart';
import 'package:smartfarm_mobile/features/devices/technician_devices_screen.dart';
import 'package:smartfarm_mobile/features/devices/technician_gateway_tools_screen.dart';
import 'package:smartfarm_mobile/features/devices/provisioning_screen.dart';
import 'package:smartfarm_mobile/features/inventory/inventory_screen.dart';
import 'package:smartfarm_mobile/features/inventory/stock_out_screen.dart';
import 'package:smartfarm_mobile/features/cf1/cf1_progress_screen.dart';
import 'package:smartfarm_mobile/features/contracts/contracts_depreciation_screen.dart';
import 'package:smartfarm_mobile/features/bills/bills_screen.dart';
import 'package:smartfarm_mobile/features/reports/reports_screen.dart';
import 'package:smartfarm_mobile/features/reports/vietgap_documents_screen.dart';
import 'package:smartfarm_mobile/features/support/support_requests_screen.dart';
import 'package:smartfarm_mobile/features/support/technician_work_screen.dart';
import 'package:smartfarm_mobile/features/support/technician_maintenance_screen.dart';
import 'package:smartfarm_mobile/features/support/field_survey_reports_screen.dart';
import 'package:smartfarm_mobile/features/support/placed_nodes_screen.dart';
import 'package:smartfarm_mobile/features/support/node_placement_screen.dart';
import 'package:smartfarm_mobile/features/farmer/farmer_dashboard_screen.dart';
import 'package:smartfarm_mobile/features/tasks/alerts_tasks_screen.dart';
import 'package:smartfarm_mobile/features/tasks/technician_notifications_screen.dart';
import 'package:smartfarm_mobile/features/profile/profile_screen.dart';
import 'package:smartfarm_mobile/features/profile/connection_notification_screens.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// Dữ liệu mẫu THẬT ghi từ backend demo (mobile/tool/record_screenshot_fixtures.ps1): vai trò -> { 'GET /đường/dẫn': JSON }.
late final Map<String, dynamic> _fixtures;
String _roleKey = 'owner';

/// Bộ định tuyến của MockClient: mẫu thật theo vai trò (làm giàu bởi screenshot_enrich.dart); thiếu/rỗng thì dùng dữ liệu giả cũ bên dưới.
String?
_failMode; // null | 'offline' | 'server' | 'empty' | 'badlogin' — chụp ảnh luồng ngoại lệ
Future<http.Response> _router(http.Request r) async {
  if (_failMode == 'badlogin' &&
      r.method == 'POST' &&
      r.url.path.contains('/auth/login')) {
    return _json({
      'error': 'Email hoặc mật khẩu không đúng.',
      'message': 'Email hoặc mật khẩu không đúng.',
    }, 401);
  }
  if (_failMode != null &&
      _failMode != 'badlogin' &&
      r.url.host != 'mt1.google.com' &&
      r.url.host != 'tile.openstreetmap.org' &&
      r.method == 'GET') {
    if (_failMode == 'offline')
      throw http.ClientException('Failed host lookup');
    if (_failMode == 'server')
      return _json({'error': 'Internal Server Error'}, 500);
    if (_failMode == 'empty') return _json(<Object>[]);
  }
  // Ô bản đồ (vệ tinh/đường phố) lấy thật từ mạng để ảnh chụp bản đồ có nền thật; các API còn lại vẫn là dữ liệu mẫu.
  if (r.url.host == 'mt1.google.com' ||
      r.url.host == 'tile.openstreetmap.org') {
    try {
      // Zone.root: thoát khỏi đồng hồ giả (FakeAsync) của test để I/O mạng chạy thật.
      return await Zone.root.run(() async {
        final real = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6);
        final req = await real.getUrl(r.url);
        req.headers.set('User-Agent', 'com.smartfarm.mobile');
        final res = await req.close();
        final bytes = await res.expand((c) => c).toList();
        real.close();
        return http.Response.bytes(
          bytes,
          res.statusCode,
          headers: {
            'content-type': res.headers.contentType?.mimeType ?? 'image/png',
          },
        );
      });
    } catch (_) {
      return http.Response('', 404);
    }
  }
  final map = _fixtures[_roleKey] as Map<String, dynamic>;
  final key = '${r.method} ${r.url.path}';
  if (map.containsKey(key)) {
    final data = enrichFixture(_roleKey, key, map[key]);
    final isEmpty =
        (data is List && data.isEmpty) || (data is Map && data.isEmpty);
    if (!isEmpty) return _json(data as Object);
  }
  final d = RegExp(
    r'^GET /api/v1/(platform/deployment-requests|deployment-requests|service-requests)/([^/]+)(/quotation)?$',
  ).firstMatch(key);
  if (d != null) {
    final listKey = 'GET /api/v1/${d.group(1)}';
    final raw = map[listKey];
    if (raw is List && raw.isNotEmpty) {
      final idKey = d.group(1)!.contains('deployment') ? 'requestId' : 'id';
      final baseKey =
          'GET /api/v1/${d.group(1)}/${(raw.first as Map)[idKey]}${d.group(3) ?? ''}';
      final detail = map[baseKey];
      if (detail != null) {
        if (d.group(3) != null || detail is! Map)
          return _json(detail as Object);
        final row = (enrichFixture(_roleKey, listKey, raw) as List)
            .cast<Map>()
            .where((e) => e[idKey] == d.group(2))
            .firstOrNull;
        return _json({...detail, ...?row});
      }
    }
  }
  // Kỹ thuật viên có thể đang chọn trang trại/Zone khác id đã ghi mẫu: dùng mẫu của Zone/trang trại đã ghi cho cùng loại endpoint.
  if (RegExp(r'^GET /api/v1/farms/[^/]+/stock-outs$').hasMatch(key)) {
    return _json(enrichFixture(_roleKey, key, const []) as Object);
  }
  if (RegExp(
    r'^GET /api/v1/zones/[^/]+/devices/map-locations$',
  ).hasMatch(key)) {
    final devs = (map['GET /api/v1/zones/$_zid/devices'] as List?) ?? const [];
    final locs = enrichFixture(
      _roleKey,
      key,
      devs.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    return _json(locs as Object);
  }
  return _mockHttpHandler(r);
}

Future<http.Response> _mockHttpHandler(http.Request r) async {
  final p = r.url.path;

  if (p == '/api/v1/auth/login') {
    return _json({
      'accessToken': 'dummy_token',
      'refreshToken': 'dummy_refresh',
      'user': {
        'userId': 'u1',
        'role': 'FarmOwner',
        'fullName': 'Nguyễn Văn Chủ',
      },
    });
  }

  if (p == '/api/v1/platform/business-parameters') {
    return _json({
      'depositPercent': 30,
      'rainGuardThresholdPercent': 70,
      'repeatPurchaseDiscountPercent': 15,
      'renewalDiscountPercent': 10,
    });
  }

  if (p == '/api/v1/farms') {
    return _json([
      {
        'farmId': 'f1',
        'name': 'Nông trại Thông minh Đà Lạt Green',
        'locationText': 'Phường 7, TP. Đà Lạt, Lâm Đồng',
        'totalAreaM2': 25000,
        'zonesCount': 2,
        'fieldsCount': 1,
      },
    ]);
  }

  if (p.endsWith('/fields')) {
    return _json([
      {
        'fieldId': 'field-1',
        'farmId': 'f1',
        'name': 'Lô Nhà Màng A',
        'soilType': 'Đất đỏ bazan',
        'areaM2': 5000,
      },
    ]);
  }

  if (p.endsWith('/zones') && !p.contains('planting-seasons')) {
    return _json([
      {
        'zoneId': 'z1',
        'farmId': 'f1',
        'fieldId': 'field-1',
        'name': 'Khu A - Cà chua Beef VietGAP',
        'areaM2': 1200,
        'currentCrop': 'Cà chua Beef',
        'currentStage': 'Ra hoa & Nuôi quả',
        'seasonStatus': 'InProgress',
        'growthProfileId': 'cp-01',
      },
      {
        'zoneId': 'z2',
        'farmId': 'f1',
        'fieldId': 'field-1',
        'name': 'Khu B - Dâu tây New Zealand',
        'areaM2': 800,
        'currentCrop': 'Dâu tây',
        'currentStage': 'Cây con phát triển',
        'seasonStatus': 'InProgress',
      },
    ]);
  }

  if (p.contains('/telemetry/latest')) {
    return _json({
      'zoneId': 'z1',
      'isFresh': true,
      'readings': [
        {
          'parameterCode': 'Temperature',
          'value': 24.8,
          'unit': '°C',
          'isFresh': true,
          'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'parameterCode': 'AirHumidity',
          'value': 68.2,
          'unit': '%',
          'isFresh': true,
          'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'parameterCode': 'SoilMoisture',
          'value': 65.4,
          'unit': '%',
          'isFresh': true,
          'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        },
        {
          'parameterCode': 'LightIntensity',
          'value': 45000,
          'unit': 'lux',
          'isFresh': true,
          'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        },
      ],
    });
  }

  if (p.contains('/ai/context')) {
    return _json({
      'zoneName': 'Khu A - Cà chua Beef VietGAP',
      'cropName': 'Cà chua Beef',
      'growthStageName': 'Ra hoa & Nuôi quả',
      'seasonAgeDays': 35,
      'telemetry': [
        {
          'parameterCode': 'SoilMoisture',
          'value': 48.5,
          'unit': '%',
          'isFresh': true,
        },
        {
          'parameterCode': 'Temperature',
          'value': 26.2,
          'unit': '°C',
          'isFresh': true,
        },
        {
          'parameterCode': 'AirHumidity',
          'value': 65.0,
          'unit': '%',
          'isFresh': true,
        },
      ],
      'requirements': [
        {'parameterCode': 'SoilMoisture', 'minValue': 60, 'maxValue': 80},
      ],
      'weather': {'available': true, 'rainProbabilityNext6HoursMaxPercent': 10},
    });
  }

  if (p.contains('/ai/history')) {
    return _json([
      {
        'recommendationId': 'rec-01',
        'question': 'Có cần tưới nước cho cây lúc này không?',
        'summary':
            'Độ ẩm đất đang ở mức 48.5%, thấp hơn ngưỡng khuyến nghị (60-80%). Cần kích hoạt tưới nhỏ giọt.',
        'details':
            'Dự báo không có mưa trong 6 giờ tới. Giai đoạn nuôi quả cần duy trì độ ẩm ổn định để tránh nứt quả.',
        'isActionable': true,
        'proposedAction': 'TurnOn',
        'proposedDurationSeconds': 300,
        'confidence': 0.94,
        'status': 'Ready',
        'validUntilUtc': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 12))
            .toIso8601String(),
        'createdAtUtc': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 3))
            .toIso8601String(),
        'limitations': ['Trạm đo số 1'],
        'sources': [
          {
            'title': 'TCVN 11892-1:2017 Quy trình VietGAP Trồng trọt',
            'standardCode': 'TCVN 11892-1',
            'similarity': 0.92,
            'contentSnippet':
                'Giai đoạn ra hoa kết trái cần tưới đủ ẩm, tránh dao động độ ẩm đất đột ngột.',
          },
        ],
      },
    ]);
  }

  if (p.contains('/actuators/history')) {
    return _json({
      'commands': [
        {
          'commandId': 'cmd-01',
          'actuatorName': 'Bơm tưới nhỏ giọt chính',
          'action': 'TurnOn',
          'durationSeconds': 300,
          'status': 'Acknowledged',
          'triggerSource': 'AI_APPROVED',
          'createdAtUtc': '2026-11-24T08:00:00Z',
        },
        {
          'commandId': 'cmd-02',
          'actuatorName': 'Van tưới điện từ Lô A1',
          'action': 'TurnOn',
          'durationSeconds': 600,
          'status': 'Completed',
          'triggerSource': 'Schedule',
          'createdAtUtc': '2026-11-24T06:30:00Z',
        },
      ],
    });
  }

  if (p.contains('/actuators')) {
    return _json([
      {
        'actuatorId': 'act-1',
        'name': 'Bơm tưới nhỏ giọt chính',
        'type': 'Pump',
        'status': 'Off',
        'isOnline': true,
      },
      {
        'actuatorId': 'act-2',
        'name': 'Van tưới điện từ Lô A1',
        'type': 'Valve',
        'status': 'Off',
        'isOnline': true,
      },
      {
        'actuatorId': 'act-3',
        'name': 'Quạt đối lưu nhà màng',
        'type': 'Fan',
        'status': 'On',
        'isOnline': true,
      },
    ]);
  }

  if (p.contains('/bills')) {
    return _json([
      {
        'id': 'b1',
        'billCode': 'HDN-2026-001',
        'contractNumber': 'HĐ-THUE-001',
        'lesseeName': 'Nguyễn Văn Chủ Trang Trại',
        'amount': 15000000,
        'paidAmount': 5000000,
        'remainingAmount': 10000000,
        'status': 'PartiallyPaid',
        'issueDate': '2026-11-01',
        'dueDate': '2026-12-01',
        'createdByName': 'KTV Hệ Thống',
      },
      {
        'id': 'b2',
        'billCode': 'HDN-2026-002',
        'contractNumber': 'HĐ-THUE-002',
        'lesseeName': 'Nguyễn Văn Chủ Trang Trại',
        'amount': 8500000,
        'paidAmount': 8500000,
        'remainingAmount': 0,
        'status': 'Paid',
        'issueDate': '2026-10-15',
        'dueDate': '2026-11-15',
        'createdByName': 'KTV Hệ Thống',
      },
    ]);
  }

  if (p.contains('/zone-contracts') || p.contains('/contracts')) {
    return _json([
      {
        'id': 'c1',
        'contractNumber': 'HĐ-THUE-001',
        'lesseeName': 'Nguyễn Văn Chủ Trang Trại',
        'totalContractValueVnd': 15000000,
        'equipmentDepositVnd': 4500000,
        'status': 'Active',
        'startDate': '2026-11-01',
        'endDate': '2027-11-01',
        'zoneName': 'Khu A - Cà chua Beef VietGAP',
      },
    ]);
  }

  if (p.contains('/service-requests')) {
    return _json([
      {
        'requestId': 'req-1',
        'farmId': 'f1',
        'zoneId': 'z1',
        'status': 'Approved',
        'requestedDate': '2026-11-20',
        'context': {
          'farmName': 'Nông trại Đà Lạt Green',
          'farmLocation': 'Phường 7, TP. Đà Lạt',
          'zoneName': 'Khu A - Cà chua Beef VietGAP',
          'cropName': 'Cà chua Beef',
          'seasonName': 'Vụ đông xuân 2026',
        },
        'planItems': [
          {
            'name': 'Trạm cảm biến đa chỉ tiêu (Đất/Khí hậu)',
            'quantity': 2,
            'status': 'Pending',
          },
          {
            'name': 'Bộ điều khiển van tưới 4 kênh',
            'quantity': 1,
            'status': 'Pending',
          },
        ],
        'surveys': [],
        'decisionHistory': [],
      },
    ]);
  }

  if (p.contains('/tasks')) {
    return _json([
      {
        'id': 't1',
        'title': 'Kiểm tra hệ thống tưới nhỏ giọt Khu A',
        'zoneName': 'Khu A - Cà chua Beef VietGAP',
        'priority': 'Cao',
        'status': 'Pending',
        'dueDate': '2026-11-25 15:00',
        'assignedFarmerName': 'Trần Văn Nông',
      },
      {
        'id': 't2',
        'title': 'Bón phân hữu cơ sinh học theo quy trình VietGAP',
        'zoneName': 'Khu B - Dâu tây New Zealand',
        'priority': 'Trung bình',
        'status': 'InProgress',
        'dueDate': '2026-11-26 10:00',
        'assignedFarmerName': 'Trần Văn Nông',
      },
    ]);
  }

  if (p.contains('/alerts')) {
    return _json([
      {
        'alertId': 'a1',
        'parameterCode': 'SoilMoisture',
        'unit': '%',
        'observedValue': 38.5,
        'minThreshold': 60,
        'maxThreshold': 80,
        'severity': 'WARNING',
        'createdAtUtc': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 20))
            .toIso8601String(),
        'zoneId': 'z1',
        'zoneName': 'Khu A - Cà chua Beef VietGAP',
      },
    ]);
  }

  if (p.contains('/notifications')) {
    return _json([
      {
        'notificationId': 'n1',
        'title': 'Khuyến nghị AI mới',
        'message': 'AI đề xuất bật bơm tưới Khu A trong 5 phút.',
        'type': 'Advice',
        'severity': 'Info',
        'isRead': false,
        'createdAt': '2026-11-25T00:10:00Z',
      },
    ]);
  }

  if (p.contains('/vietgap') || p.contains('/documents')) {
    return _json([
      {
        'id': 'doc-1',
        'title':
            'TCVN 11892-1:2017 Quy trình thực hành nông nghiệp tốt (VietGAP) - Phần 1: Trồng trọt',
        'documentType': 'Standard',
        'standardCode': 'TCVN 11892-1:2017',
        'issuingAgency': 'Bộ Nông nghiệp và Phát triển nông thôn',
        'summary':
            'Tiêu chuẩn quốc gia quy định các yêu cầu về an toàn thực phẩm, chất lượng sản phẩm, sức khỏe người lao động.',
        'totalChunks': 42,
      },
    ]);
  }

  if (p.contains('/field-survey')) {
    return _json([
      {
        'id': 'fs-1',
        'reportCode': 'BB-KS-2026-001',
        'farmName': 'Nông trại Đà Lạt Green',
        'zoneName': 'Khu A - Cà chua Beef',
        'technicianName': 'Lê Kỹ Thuật Viên',
        'surveyDate': '2026-11-22',
        'status': 'Approved',
        'topography': 'Bằng phẳng, trong nhà màng kính',
        'soilType': 'Đất đỏ bazan pha cát nhẹ',
      },
    ]);
  }

  if (p.contains('/irrigation-calendar')) {
    return _json({
      'zoneId': 'z1',
      'seasonId': 's1',
      'days': [
        {
          'dayNumber': 1,
          'stageName': 'Gieo hạt - Bén rễ',
          'totalVolumeLiters': 120,
          'sessions': [
            {'startTime': '07:00', 'durationMinutes': 10, 'volumeLiters': 60},
            {'startTime': '16:30', 'durationMinutes': 10, 'volumeLiters': 60},
          ],
        },
        {
          'dayNumber': 2,
          'stageName': 'Cây con',
          'totalVolumeLiters': 150,
          'sessions': [
            {'startTime': '07:00', 'durationMinutes': 12, 'volumeLiters': 75},
            {'startTime': '16:30', 'durationMinutes': 12, 'volumeLiters': 75},
          ],
        },
      ],
    });
  }

  if (p.contains('/mqtt')) {
    return _json({
      'connected': true,
      'brokerUrl': 'mqtt://localhost:1883',
      'activeGateways': 2,
      'messagesPerMinute': 24,
    });
  }

  if (p.contains('/growth-profiles/cp-01')) {
    return _json({
      'profileId': 'cp-01',
      'cropName': 'Cà chua Beef F1',
      'stages': [
        {
          'stageId': 'st-1',
          'name': 'Cây con bén rễ',
          'stageOrder': 1,
          'durationDays': 20,
        },
        {
          'stageId': 'st-2',
          'name': 'Ra hoa & Nuôi quả',
          'stageOrder': 2,
          'durationDays': 55,
        },
      ],
    });
  }

  return _json(<dynamic>[]);
}

Future<void> loadTestFonts() async {
  final iconFile = File(
    r'C:\src\flutter\bin\cache\artifacts\material_fonts\MaterialIcons-Regular.otf',
  );
  if (await iconFile.exists()) {
    final bytes = await iconFile.readAsBytes();
    final fontLoader = FontLoader('MaterialIcons');
    fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await fontLoader.load();
  }

  final regularFile = File(r'C:\Windows\Fonts\segoeui.ttf');
  final boldFile = File(r'C:\Windows\Fonts\segoeuib.ttf');
  final regBytes = await regularFile.readAsBytes();
  final boldBytes = await boldFile.readAsBytes();

  // 'FlutterTest' là font mặc định của chữ KHÔNG khai báo fontFamily trong flutter test (nếu không nạp sẽ thành ô vuông).
  for (final fam in [
    'Segoe UI',
    'Roboto',
    'Ahem',
    'FlutterTest',
    'sans-serif',
    'sans',
    'Arial',
    'Helvetica',
    'Noto Sans',
    'DejaVu Sans',
    'Droid Sans',
    'system-ui',
    'Open Sans',
    '.SF UI Text',
    '.SF Pro Text',
  ]) {
    final loader = FontLoader(fam);
    loader.addFont(Future.value(ByteData.view(regBytes.buffer)));
    loader.addFont(Future.value(ByteData.view(boldBytes.buffer)));
    await loader.load();
  }

  // Các font còn thiếu làm chữ/biểu tượng hiện thành ô vuông trong ảnh: monospace (app dùng ở 29 chỗ), emoji và ký hiệu.
  Future<void> loadFamily(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var any = false;
    for (final path in paths) {
      final f = File(path);
      if (await f.exists()) {
        loader.addFont(
          Future.value(ByteData.view((await f.readAsBytes()).buffer)),
        );
        any = true;
      }
    }
    if (any) await loader.load();
  }

  await loadFamily('monospace', [
    r'C:\Windows\Fonts\consola.ttf',
    r'C:\Windows\Fonts\consolab.ttf',
  ]);
  await loadFamily('Segoe UI Emoji', [r'C:\Windows\Fonts\seguiemj.ttf']);
  await loadFamily('Segoe UI Symbol', [r'C:\Windows\Fonts\seguisym.ttf']);
}

ThemeData _createAppThemeWithFont(String fontFamily) {
  final base = buildAppTheme();
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: const ['Segoe UI Emoji', 'Segoe UI Symbol'],
    ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        fontFamily: fontFamily,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(fontFamily: fontFamily),
      secondaryLabelStyle: base.chipTheme.secondaryLabelStyle?.copyWith(
        fontFamily: fontFamily,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: (base.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}

// ── Id và Zone lấy từ chính mẫu thật (kỹ thuật viên không nạp danh sách Zone nên không dùng provider.allZones) ──
Map<String, dynamic> get _meta => _fixtures['_meta'] as Map<String, dynamic>;
String get _fid => _meta['farmId'] as String;
String get _zid => _meta['zoneId'] as String;
List _list(String role, String route) =>
    (_fixtures[role] as Map<String, dynamic>)['GET $route'] as List;
List _enriched(String role, String route) =>
    enrichFixture(role, 'GET $route', _list(role, route)) as List;
String get _srid =>
    _enriched('technician', '/api/v1/service-requests').first['id']
        as String; // phiếu lắp đặt mới đang giao cho KTV
String get _depid =>
    (_enriched(
              'technician',
              '/api/v1/platform/deployment-requests',
            ).firstWhere((e) => e['status'] == 'Installing')
            as Map)['requestId']
        as String;
String get _profileId =>
    _list('owner', '/api/v1/growth-profiles').first['profileId'] as String;
ZoneModel _fixtureZone() {
  final farm = _list('owner', '/api/v1/farms').first as Map<String, dynamic>;
  final field =
      _list('owner', '/api/v1/farms/$_fid/fields').first
          as Map<String, dynamic>;
  final zone =
      enrichFixture(
            'owner',
            'GET /api/v1/fields/${field['fieldId']}/zones',
            _list('owner', '/api/v1/fields/${field['fieldId']}/zones'),
          )
          as List;
  return ZoneModel.fromJson(
    (zone.first as Map).cast<String, dynamic>(),
    farmId: _fid,
    fieldId: field['fieldId'] as String,
    farmName: '${farm['name']}',
    fieldName: '${field['name']}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    HttpOverrides.global =
        null; // cho phép tải ô bản đồ thật (flutter test mặc định chặn mạng)
    _fixtures =
        jsonDecode(
              File(
                'test/fixtures/screenshot_routes.json',
              ).readAsStringSync(encoding: utf8),
            )
            as Map<String, dynamic>;
    final tmp = Directory.systemTemp.createTempSync('gis_test').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp,
        );
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await loadTestFonts();
    ApiService.setTokens(
      accessToken: 'sample_token',
      refreshToken: 'sample_refresh',
      email: 'owner@smartfarm.demo',
      role: 'FarmOwner',
    );
    // Gắn MockClient cho ApiService ngay trong setUpAll để mọi màn hình nhận dữ liệu mẫu 200 OK
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient(_router),
    );
  });

  Future<void> renderScreen(
    WidgetTester tester,
    Widget Function(FarmProvider) build,
    String goldenFileName, {
    String role = 'OWNER',
    Size size = const Size(430, 932),
    String? failMode,
    Future<void> Function(WidgetTester)? after,
  }) async {
    // Kích thước LOGIC giữ nguyên (430×932, điện thoại cỡ lớn); chụp ở tỉ lệ điểm ảnh 3× (ảnh 1290×2796) để chữ và
    // biểu tượng sắc nét khi phóng to/in. Trước đây dùng 1.0 nên ảnh chỉ 430×932 và bị mờ.
    if (!autoUpdateGoldenFiles) {
      // Ảnh có chữ phụ thuộc giờ hiện tại (vd. "5 phút trước") nên không so khớp pixel giữa các lần chạy; chỉ tạo khi cập nhật:
      //   flutter test test/generate_all_screenshots_test.dart --update-goldens
      markTestSkipped('Chỉ chạy với --update-goldens.');
      return;
    }
    const pixelRatio = 3.0;
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final apiRole = role == 'OWNER'
        ? 'FarmOwner'
        : (role == 'FARMER' ? 'Farmer' : 'PlatformTechnician');
    ApiService.setTokens(
      accessToken: 'sample_token',
      refreshToken: 'sample_refresh',
      email: '${role.toLowerCase()}@smartfarm.demo',
      role: apiRole,
    );

    _roleKey = role == 'OWNER'
        ? 'owner'
        : (role == 'FARMER' ? 'farmer' : 'technician');
    // Provider THẬT nạp từ mẫu (id nhất quán giữa trang trại, Zone, vụ trồng, thiết bị...), không dựng tay.
    _failMode = null;
    final provider = FarmProvider()..switchRole(role);
    await provider.fetchFromApi();
    await provider.loadCropProfiles();
    _failMode = failMode;
    // Nạp số đo mới nhất cho mọi Zone như app thật (nếu không thẻ Zone hiện "Mất tín hiệu" dù dữ liệu có sẵn).
    await http.runWithClient(
      () => provider.refreshAllZonesTelemetry(),
      () => MockClient(_router),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: _createAppThemeWithFont('Segoe UI'),
            debugShowCheckedModeBanner: false,
            home: build(provider),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Ảnh trong app (banner, logo...) giải mã bất đồng bộ ngoài đồng hồ giả: chờ để không bị ô xám.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (RegExp(r'map|placement|placed').hasMatch(goldenFileName)) {
        // Chờ ô bản đồ tải xong (I/O thật, ngoài đồng hồ giả của test).
        for (var i = 0; i < 14; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 1)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      if (after != null) {
        await after(tester);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$goldenFileName'),
      );
    }, () => MockClient(_router));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
    provider.dispose();
  }

  // =========================================================================
  // GROUP 0: PUBLIC & AUTHENTICATION (5 screens)
  // =========================================================================
  group('Group 0: Public & Auth', () {
    testWidgets('00_01 Landing Screen', (t) async {
      await renderScreen(
        t,
        (p) => LandingScreen(onLoginSuccess: () {}),
        '00_01_landing.png',
      );
    });
    testWidgets('00_02 Login Screen', (t) async {
      await renderScreen(
        t,
        (p) => LoginScreen(onLoginSuccess: () {}),
        '00_02_login.png',
      );
    });
    testWidgets('00_03 Register Screen', (t) async {
      await renderScreen(
        t,
        (p) => const RegisterScreen(),
        '00_03_register.png',
      );
    });
    testWidgets('00_04 Forgot Password Screen', (t) async {
      await renderScreen(
        t,
        (p) => const ForgotPasswordScreen(),
        '00_04_forgot_password.png',
      );
    });
    testWidgets('00_05 Change Password Screen', (t) async {
      await renderScreen(
        t,
        (p) => const ChangePasswordScreen(),
        '00_05_change_password.png',
      );
    });
  });

  // =========================================================================
  // GROUP 1: ROLE FARM OWNER (33 screens)
  // =========================================================================
  group('Group 1: Farm Owner', () {
    testWidgets('01_01 Owner Home', (t) async {
      await renderScreen(
        t,
        (p) => const HomeScreen(),
        '01_01_owner_home.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_02 Owner Farms Management', (t) async {
      await renderScreen(
        t,
        (p) => const FarmsManagementScreen(),
        '01_02_owner_farms_management.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_03 Owner Farm Setup Wizard', (t) async {
      await renderScreen(
        t,
        (p) => const FarmSetupWizardScreen(),
        '01_03_owner_farm_setup_wizard.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_04 Owner GIS Map', (t) async {
      await renderScreen(
        t,
        (p) => const GISMapScreen(),
        '01_04_owner_gis_map.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_05 Owner AI Assistant', (t) async {
      await renderScreen(
        t,
        (p) => const AiAssistantScreen(),
        '01_05_owner_ai_assistant.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_06 Owner Work Management', (t) async {
      await renderScreen(
        t,
        (p) => const WorkManagementScreen(),
        '01_06_owner_work_management.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_07 Owner Workforce', (t) async {
      await renderScreen(
        t,
        (p) => const WorkforceScreen(),
        '01_07_owner_workforce.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_09 Owner Zone Detail', (t) async {
      await renderScreen(
        t,
        (p) => ZoneDetailScreen(zone: _fixtureZone()),
        '01_09_owner_zone_detail.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_10 Owner Zone Alert Center', (t) async {
      await renderScreen(
        t,
        (p) => ZoneAlertCenterScreen(zone: _fixtureZone()),
        '01_10_owner_zone_alert_center.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_11 Owner Zone Nodes', (t) async {
      await renderScreen(
        t,
        (p) => ZoneNodesScreen(
          zoneId: _zid,
          zoneName: 'Khu A - Cà chua Beef',
          canEditLocations: true,
        ),
        '01_11_owner_zone_nodes.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_12 Owner Zone Planting Seasons', (t) async {
      await renderScreen(
        t,
        (p) => ZonePlantingSeasonsScreen(zone: _fixtureZone()),
        '01_12_owner_zone_planting_seasons.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_13 Owner Actuator History', (t) async {
      await renderScreen(
        t,
        (p) => ActuatorHistoryScreen(zone: _fixtureZone()),
        '01_13_owner_actuator_history.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_14 Owner Monitoring History', (t) async {
      await renderScreen(
        t,
        (p) => const MonitoringHistoryScreen(),
        '01_14_owner_monitoring_history.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_15 Owner Crop Profiles', (t) async {
      await renderScreen(
        t,
        (p) => const CropProfilesScreen(),
        '01_15_owner_crop_profiles.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_16 Owner Crop Detail', (t) async {
      await renderScreen(
        t,
        (p) => CropDetailScreen(profile: p.defaultCropProfiles.first),
        '01_16_owner_crop_detail.png',
        role: 'OWNER',
        size: const Size(600, 1000),
      );
    });
    testWidgets('01_17 Owner Growth Stages', (t) async {
      await renderScreen(
        t,
        (p) =>
            GrowthStagesScreen(profileId: _profileId, title: 'Cà chua Beef F1'),
        '01_17_owner_growth_stages.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_18 Owner Irrigation Calendar', (t) async {
      await renderScreen(
        t,
        (p) => IrrigationCalendarScreen(
          profile: p.defaultCropProfiles.first,
          zoneName: _fixtureZone().name,
        ),
        '01_18_owner_irrigation_calendar.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_19 Owner Season Irrigation Calendar', (t) async {
      await renderScreen(
        t,
        (p) => SeasonIrrigationCalendarScreen(zone: _fixtureZone()),
        '01_19_owner_season_irrigation_calendar.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_20 Owner Schedules Automation', (t) async {
      await renderScreen(
        t,
        (p) => const SchedulesAutomationScreen(),
        '01_20_owner_schedules_automation.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_21 Owner Device Health', (t) async {
      await renderScreen(
        t,
        (p) => const DeviceHealthScreen(),
        '01_21_owner_device_health.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_22 Owner Inventory', (t) async {
      await renderScreen(
        t,
        (p) => const InventoryScreen(),
        '01_22_owner_inventory.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_23 Owner Deployment Requests', (t) async {
      await renderScreen(
        t,
        (p) => const OwnerDeploymentRequestsScreen(),
        '01_23_owner_deployment_requests.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_24 Owner Deployment Send', (t) async {
      await renderScreen(
        t,
        (p) => DeploymentRequestSendScreen(zoneId: _zid),
        '01_24_owner_deployment_send.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_25 Owner CF1 Progress', (t) async {
      await renderScreen(
        t,
        (p) => const Cf1ProgressScreen(),
        '01_25_owner_cf1_progress.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_26 Owner Contracts & Depreciation', (t) async {
      await renderScreen(
        t,
        (p) => const ContractsDepreciationScreen(),
        '01_26_owner_contracts_depreciation.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_27 Owner Bills', (t) async {
      await renderScreen(
        t,
        (p) => const BillsScreen(),
        '01_27_owner_bills.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_28 Owner Reports', (t) async {
      await renderScreen(
        t,
        (p) => const ReportsScreen(),
        '01_28_owner_reports.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_29 Owner VietGAP Documents', (t) async {
      await renderScreen(
        t,
        (p) => const VietGapDocumentsScreen(),
        '01_29_owner_vietgap_documents.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_30 Owner Support Requests', (t) async {
      await renderScreen(
        t,
        (p) => SupportRequestsScreen(zone: _fixtureZone()),
        '01_30_owner_support_requests.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_31 Owner Profile', (t) async {
      await renderScreen(
        t,
        (p) => const ProfileScreen(),
        '01_31_owner_profile.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_32 Owner MQTT Status', (t) async {
      await renderScreen(
        t,
        (p) => const MqttStatusScreen(),
        '01_32_owner_mqtt_status.png',
        role: 'OWNER',
      );
    });
    testWidgets('01_33 Owner Notification Settings', (t) async {
      await renderScreen(
        t,
        (p) => const NotificationSettingsScreen(),
        '01_33_owner_notification_settings.png',
        role: 'OWNER',
      );
    });
  });

  // =========================================================================
  // GROUP 2: ROLE FARMER (9 screens)
  // =========================================================================
  group('Group 2: Farmer', () {
    testWidgets('02_01 Farmer Dashboard', (t) async {
      await renderScreen(
        t,
        (p) => FarmerDashboardScreen(onSelectTab: (i) {}),
        '02_01_farmer_dashboard.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_02 Farmer Crop Profiles', (t) async {
      await renderScreen(
        t,
        (p) => const CropProfilesScreen(),
        '02_02_farmer_crop_profiles.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_03 Farmer GIS Map', (t) async {
      await renderScreen(
        t,
        (p) => const GISMapScreen(),
        '02_03_farmer_gis_map.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_04 Farmer Alerts & Tasks', (t) async {
      await renderScreen(
        t,
        (p) => const AlertsTasksScreen(),
        '02_04_farmer_alerts_tasks.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_05 Farmer Zone Detail', (t) async {
      await renderScreen(
        t,
        (p) => ZoneDetailScreen(zone: _fixtureZone()),
        '02_05_farmer_zone_detail.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_06 Farmer Zone Alert Center', (t) async {
      await renderScreen(
        t,
        (p) => ZoneAlertCenterScreen(zone: _fixtureZone()),
        '02_06_farmer_zone_alert_center.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_07 Farmer Season Irrigation Calendar', (t) async {
      await renderScreen(
        t,
        (p) => SeasonIrrigationCalendarScreen(zone: _fixtureZone()),
        '02_07_farmer_season_irrigation.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_08 Farmer Inventory', (t) async {
      await renderScreen(
        t,
        (p) => const InventoryScreen(),
        '02_08_farmer_inventory.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_10 Farmer Farm Invitations', (t) async {
      // Màn dành cho Nông dân: xem và trả lời lời mời tham gia Farm do Chủ trang trại gửi.
      await renderScreen(
        t,
        (p) => const FarmInvitationsScreen(),
        '02_10_farmer_farm_invitations.png',
        role: 'FARMER',
      );
    });
    testWidgets('02_09 Farmer Profile', (t) async {
      await renderScreen(
        t,
        (p) => const ProfileScreen(),
        '02_09_farmer_profile.png',
        role: 'FARMER',
      );
    });
  });

  // =========================================================================
  // GROUP 3: ROLE TECHNICIAN (12 screens)
  // =========================================================================
  group('Group 3: Technician', () {
    testWidgets('03_01 Technician Work', (t) async {
      await renderScreen(
        t,
        (p) => const TechnicianWorkScreen(),
        '03_01_tech_work.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_02 Technician Devices', (t) async {
      await renderScreen(
        t,
        (p) => const TechnicianDevicesScreen(),
        '03_02_tech_devices.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_03 Technician Deployments', (t) async {
      await renderScreen(
        t,
        (p) => const TechnicianDeploymentsScreen(),
        '03_03_tech_deployments.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_04 Technician Maintenance', (t) async {
      await renderScreen(
        t,
        (p) => const TechnicianMaintenanceScreen(),
        '03_04_tech_maintenance.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_05 Technician Gateway Tools', (t) async {
      await renderScreen(
        t,
        (p) => const TechnicianGatewayToolsScreen(),
        '03_05_tech_gateway_tools.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_06 Technician Provisioning', (t) async {
      await renderScreen(
        t,
        (p) => const ProvisioningScreen(),
        '03_06_tech_provisioning.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_07 Technician Stock Out', (t) async {
      await renderScreen(
        t,
        (p) => const StockOutScreen(),
        '03_07_tech_stock_out.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_08 Technician Field Survey Reports', (t) async {
      await renderScreen(
        t,
        (p) => const FieldSurveyReportsScreen(),
        '03_08_tech_field_survey_reports.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_09 Technician Placed Nodes', (t) async {
      await renderScreen(
        t,
        (p) =>
            PlacedNodesScreen(zoneId: _zid, farmId: _fid, zone: _fixtureZone()),
        '03_09_tech_placed_nodes.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_10 Technician Node Placement', (t) async {
      await renderScreen(
        t,
        (p) => NodePlacementScreen(
          serviceRequestId: _srid,
          farmId: _fid,
          zoneId: _zid,
          deploymentRequestId: _depid,
          zone: _fixtureZone(),
        ),
        '03_10_tech_node_placement.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_11 Technician Notifications', (t) async {
      await renderScreen(
        t,
        (p) => const TechnicianNotificationsScreen(),
        '03_11_tech_notifications.png',
        role: 'TECHNICIAN',
      );
    });
    testWidgets('03_12 Technician Profile', (t) async {
      await renderScreen(
        t,
        (p) => const ProfileScreen(),
        '03_12_tech_profile.png',
        role: 'TECHNICIAN',
      );
    });
  });

  group('Group 9: Exception flows (E)', () {
    testWidgets('E01 Login empty', (t) async {
      await renderScreen(
        t,
        (p) => LoginScreen(onLoginSuccess: () {}),
        'E01_login_empty.png',
        after: (t) async {
          await t.tap(find.text('Đăng nhập ngay'));
        },
      );
    });
    testWidgets('E02 Login wrong password', (t) async {
      await renderScreen(
        t,
        (p) => LoginScreen(onLoginSuccess: () {}),
        'E02_login_wrong_password.png',
        failMode: 'badlogin',
        after: (t) async {
          final f = find.byType(TextField);
          await t.enterText(f.at(0), 'owner@smartfarm.demo');
          await t.enterText(f.at(1), 'SaiMatKhau1');
          await t.pump();
          await t.tap(find.text('Đăng nhập ngay'));
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 300)),
          );
          await t.pump(const Duration(milliseconds: 300));
        },
      );
    });
    testWidgets('E03 Home offline', (t) async {
      await renderScreen(
        t,
        (p) => const HomeScreen(),
        'E03_home_offline.png',
        failMode: 'offline',
      );
    });
    testWidgets('E04 Deployment requests server error', (t) async {
      await renderScreen(
        t,
        (p) => const OwnerDeploymentRequestsScreen(),
        'E04_cf1_server_error.png',
        failMode: 'server',
      );
    });
    testWidgets('E05 Alert center empty', (t) async {
      await renderScreen(
        t,
        (p) => ZoneAlertCenterScreen(zone: _fixtureZone()),
        'E05_cf2_alerts_empty.png',
        failMode: 'empty',
      );
    });
    testWidgets('E06 Monitoring history offline', (t) async {
      await renderScreen(
        t,
        (p) => const MonitoringHistoryScreen(),
        'E06_cf2_history_offline.png',
        failMode: 'offline',
      );
    });
    testWidgets('E07 Schedules empty', (t) async {
      await renderScreen(
        t,
        (p) => const SchedulesAutomationScreen(),
        'E07_cf3_rules_empty.png',
        failMode: 'empty',
      );
    });
    testWidgets('E08 Device health offline', (t) async {
      await renderScreen(
        t,
        (p) => const DeviceHealthScreen(),
        'E08_cf3_devices_offline.png',
        failMode: 'offline',
      );
    });
    testWidgets('E09 AI server error', (t) async {
      await renderScreen(
        t,
        (p) => const AiAssistantScreen(),
        'E09_cf4_ai_server_error.png',
        failMode: 'server',
      );
    });
  });
}
