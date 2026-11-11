import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Quy tắc kiểm tra và đọc kết quả của wizard thiết lập trang trại (thuần Dart, không phụ thuộc UI để dễ kiểm thử).
/// Các ràng buộc khớp với backend: POST /farms/wizard-setup (FarmOwner).

bool isValidLatLng(double? lat, double? lng) =>
    lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && !(lat == 0 && lng == 0);

/// Bước 1: Trang trại.
String? validateFarmStep({required String name, required double? lat, required double? lng, double? totalAreaM2}) {
  if (name.trim().length < 2) return 'Nhập tên trang trại (ít nhất 2 ký tự).';
  if (!isValidLatLng(lat, lng)) {
    return 'Chưa chọn vị trí trang trại. Di chuyển bản đồ hoặc dùng nút tìm kiếm để đặt ghim.';
  }
  return null;
}

/// Bước 2: Lô đất. Diện tích lô không được vượt tổng diện tích trang trại.
String? validateFieldStep({
  required String name,
  required double? areaM2,
  required double? farmAreaM2,
  required List<LatLng>? boundary,
}) {
  if (name.trim().length < 2) return 'Nhập tên lô đất (ít nhất 2 ký tự).';
  if (areaM2 == null || areaM2 <= 0) return 'Nhập diện tích lô đất (m²) lớn hơn 0.';
  if (farmAreaM2 != null && areaM2 > farmAreaM2) {
    return 'Diện tích lô đất (${areaM2.toStringAsFixed(0)} m²) vượt tổng diện tích trang trại (${farmAreaM2.toStringAsFixed(0)} m²).';
  }
  if (boundary != null && boundary.isNotEmpty && boundary.length < 3) return 'Ranh giới lô đất cần ít nhất 3 đỉnh.';
  return null;
}

/// Bước 3: Zone. Diện tích Zone không được vượt diện tích lô; ranh giới (nếu có) nằm trong lô.
String? validateZoneStep({
  required String name,
  required double? areaM2,
  required double? fieldAreaM2,
  required List<LatLng>? boundary,
  List<LatLng>? fieldBoundary,
}) {
  if (name.trim().length < 2) return 'Nhập tên Zone (ít nhất 2 ký tự).';
  if (areaM2 == null || areaM2 <= 0) return 'Nhập diện tích Zone (m²) lớn hơn 0.';
  if (fieldAreaM2 != null && areaM2 > fieldAreaM2) {
    return 'Diện tích Zone (${areaM2.toStringAsFixed(0)} m²) vượt diện tích lô đất (${fieldAreaM2.toStringAsFixed(0)} m²).';
  }
  if (boundary != null && boundary.isNotEmpty) {
    if (boundary.length < 3) return 'Ranh giới Zone cần ít nhất 3 đỉnh.';
    if (fieldBoundary != null && fieldBoundary.length >= 3 && boundary.any((p) => !pointInPolygon(p, fieldBoundary))) {
      return 'Ranh giới Zone đang vượt ra ngoài lô đất. Hãy kéo các đỉnh vào trong.';
    }
  }
  return null;
}

/// Bước 4: Vụ trồng (tuỳ chọn). Nếu bật thì phải có cây và hồ sơ sinh trưởng CÓ giai đoạn
/// (backend bỏ qua vụ trồng mà không báo lỗi khi hồ sơ không có giai đoạn).
String? validateSeasonStep({
  required bool enabled,
  required String name,
  required String? cropId,
  required String? profileId,
  required int? profileStageCount,
  required DateTime start,
  required DateTime? expectedEnd,
}) {
  if (!enabled) return null;
  if (name.trim().isEmpty) return 'Nhập tên vụ trồng.';
  if (cropId == null) return 'Chọn cây trồng cho vụ.';
  if (profileId == null) {
    return 'Cây này chưa có hồ sơ sinh trưởng nào trên hệ thống nên chưa thể tạo vụ. '
        'Hãy tắt phần vụ trồng và tạo vụ sau khi có hồ sơ, hoặc chọn cây khác.';
  }
  if (profileStageCount == null || profileStageCount < 1) {
    return 'Hồ sơ sinh trưởng đã chọn chưa có giai đoạn nào nên hệ thống sẽ không tạo vụ. Hãy chọn hồ sơ khác.';
  }
  if (expectedEnd == null)
    return 'Chọn ngày thu hoạch dự kiến (hồ sơ này không khai báo số ngày nên không tự tính được).';
  if (!expectedEnd.isAfter(start)) return 'Ngày thu hoạch dự kiến phải sau ngày bắt đầu.';
  return null;
}

/// Bước 5: Yêu cầu IoT (tuỳ chọn) — backend chỉ tạo khi đã có vụ trồng.
String? validateIotStep({required bool seasonEnabled, required bool iotEnabled, required Set<String> parameters}) {
  if (!iotEnabled) return null;
  if (!seasonEnabled) return 'Yêu cầu triển khai IoT trong wizard cần có vụ trồng. Bật vụ trồng hoặc tắt yêu cầu IoT.';
  if (parameters.isEmpty) return 'Chọn ít nhất một thông số cần đo.';
  return null;
}

/// Ray casting: điểm nằm trong đa giác (toạ độ lat/lng).
bool pointInPolygon(LatLng pt, List<LatLng> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].longitude, yi = poly[i].latitude;
    final xj = poly[j].longitude, yj = poly[j].latitude;
    if (((yi > pt.latitude) != (yj > pt.latitude)) &&
        (pt.longitude < (xj - xi) * (pt.latitude - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}

/// Chuỗi GeoJSON Polygon (backend nhận BoundaryGeoJson dạng string; thứ tự [lng, lat], vòng khép kín).
String? boundaryGeoJsonString(List<LatLng>? pts) {
  if (pts == null || pts.length < 3) return null;
  final ring = [
    for (final p in pts) [p.longitude, p.latitude],
  ];
  if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) ring.add(List.of(ring.first));
  return jsonEncode({
    'type': 'Polygon',
    'coordinates': [ring],
  });
}

/// Trạng thái của từng đối tượng sau khi gửi wizard.
enum WizardItemState { created, notRequested, notCreated }

class WizardItem {
  final String key; // khoá trong phản hồi: farmId | fieldId | zoneId | seasonId | deploymentRequestId
  final String label;
  final WizardItemState state;
  final String? id;
  final String? problem; // lý do & cách tiếp tục khi notCreated
  const WizardItem(this.key, this.label, this.state, {this.id, this.problem});
}

class WizardOutcome {
  final List<WizardItem> items;
  const WizardOutcome(this.items);

  bool get isComplete => items.every((i) => i.state != WizardItemState.notCreated);
  bool get isPartial => !isComplete && items.any((i) => i.state == WizardItemState.created);
  List<WizardItem> get missing => items.where((i) => i.state == WizardItemState.notCreated).toList();
  String? idOf(String key) => items.where((i) => i.key == key).firstOrNull?.id;
}

/// So khớp những gì người dùng YÊU CẦU với các ID backend thật sự trả về, không tin mặc định là thành công.
/// Backend tạo Farm → Field → Zone → Vụ trồng → Yêu cầu IoT trong một giao dịch nhưng im lặng bỏ qua vụ trồng
/// khi hồ sơ sinh trưởng không có giai đoạn (và do đó cũng bỏ qua yêu cầu IoT).
WizardOutcome analyzeWizardResult({
  required Map<String, dynamic> result,
  required bool requestedField,
  required bool requestedZone,
  required bool requestedSeason,
  required bool requestedIot,
}) {
  String? idOf(String k) {
    final v = result[k]?.toString();
    return (v == null || v.isEmpty || v == 'null' || v == '00000000-0000-0000-0000-000000000000') ? null : v;
  }

  WizardItem build(String key, String label, bool requested, String problem) {
    final id = idOf(key);
    if (!requested) return WizardItem(key, label, WizardItemState.notRequested);
    if (id != null) return WizardItem(key, label, WizardItemState.created, id: id);
    return WizardItem(key, label, WizardItemState.notCreated, problem: problem);
  }

  final farmId = idOf('farmId');
  return WizardOutcome([
    farmId != null
        ? WizardItem('farmId', 'Trang trại', WizardItemState.created, id: farmId)
        : const WizardItem(
            'farmId',
            'Trang trại',
            WizardItemState.notCreated,
            problem: 'Máy chủ không trả về mã trang trại. Hãy tải lại danh sách để kiểm tra trước khi tạo lại.',
          ),
    build('fieldId', 'Lô đất', requestedField, 'Lô đất chưa được tạo. Thêm lô đất trong mục Quản lý trang trại.'),
    build('zoneId', 'Zone', requestedZone, 'Zone chưa được tạo. Thêm Zone trong mục Quản lý trang trại.'),
    build(
      'seasonId',
      'Vụ trồng',
      requestedSeason,
      'Máy chủ bỏ qua vụ trồng (thường do hồ sơ sinh trưởng chưa có giai đoạn). Hãy tạo vụ trồng cho Zone sau khi chọn hồ sơ hợp lệ.',
    ),
    build(
      'deploymentRequestId',
      'Yêu cầu triển khai IoT',
      requestedIot,
      'Yêu cầu IoT chưa được tạo (cần có vụ trồng). Hãy gửi yêu cầu từ màn Triển khai IoT của Zone.',
    ),
  ]);
}

// ───────────────────────── Bước 4: Cây trồng & Vụ mùa ─────────────────────────

/// Tên tham số môi trường của backend (EnvironmentalParameterCode) theo thứ tự enum, để đọc cả dạng số.
const _parameterEnumNames = ['Temperature', 'SoilMoisture', 'AirHumidity', 'Ph', 'LightIntensity', 'Ec'];

String? _parameterName(Object? raw) {
  if (raw == null) return null;
  if (raw is int) return raw >= 0 && raw < _parameterEnumNames.length ? _parameterEnumNames[raw] : null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  final asInt = int.tryParse(s);
  if (asInt != null) return _parameterName(asInt);
  for (final n in _parameterEnumNames) {
    if (n.toLowerCase() == s.toLowerCase()) return n;
  }
  return null;
}

/// Các giai đoạn của hồ sơ, sắp theo thứ tự.
List<Map<String, dynamic>> profileStages(Map<String, dynamic>? profile) {
  final st = profile?['stages'];
  if (st is! List) return const [];
  final list = [
    for (final s in st)
      if (s is Map) Map<String, dynamic>.from(s),
  ];
  list.sort((a, b) => (num.tryParse('${a['stageOrder']}') ?? 0).compareTo(num.tryParse('${b['stageOrder']}') ?? 0));
  return list;
}

/// Tổng số ngày các giai đoạn của hồ sơ; null khi hồ sơ không có giai đoạn nào có số ngày hợp lệ.
int? profileTotalDays(Map<String, dynamic>? profile) {
  var total = 0;
  for (final s in profileStages(profile)) {
    total += int.tryParse('${s['durationDays']}') ?? 0;
  }
  return total > 0 ? total : null;
}

/// Thông số cần đo theo hồ sơ: lấy từ yêu cầu môi trường của giai đoạn ĐẦU TIÊN (backend sao chép yêu cầu của
/// giai đoạn hiện tại vào vụ khi tạo vụ, và IoT-requirements đọc từ đó). Hồ sơ không khai báo thì trả về rỗng,
/// KHÔNG tự điền danh sách mặc định.
List<String> profileRequiredParameters(Map<String, dynamic>? profile) {
  final stages = profileStages(profile);
  if (stages.isEmpty) return const [];
  final reqs = stages.first['requirements'];
  final out = <String>{};
  if (reqs is List) {
    for (final r in reqs) {
      if (r is Map) {
        final n = _parameterName(r['parameterCode'] ?? r['code']);
        if (n != null) out.add(n);
      }
    }
  }
  return _parameterEnumNames.where(out.contains).toList();
}

/// Ngày thu hoạch dự kiến = ngày bắt đầu + tổng số ngày các giai đoạn của hồ sơ.
DateTime expectedEndFromProfile(DateTime start, int totalDays) =>
    DateTime(start.year, start.month, start.day).add(Duration(days: totalDays));

/// Gợi ý tên vụ (người dùng vẫn sửa được).
String suggestedSeasonName(String cropName, DateTime start) {
  final base = cropName.split('(').first.trim();
  final season = switch (start.month) {
    >= 11 || <= 2 => 'Đông Xuân',
    >= 3 && <= 6 => 'Hè Thu',
    _ => 'Thu Đông',
  };
  return 'Vụ $base $season ${start.year}';
}

/// Thất bại khi gửi wizard: mất kết nối/timeout là TRƯỜNG HỢP MƠ HỒ (máy chủ có thể đã tạo xong nhưng phản hồi
/// bị mất), khác với lỗi HTTP có phản hồi rõ ràng (dữ liệu sai, không có quyền, xung đột) — các lỗi này chưa tạo gì.
enum WizardFailureKind { ambiguousNetwork, rejected }

WizardFailureKind classifyWizardFailure(Object error) {
  if (error is TimeoutException || error is SocketException || error is http.ClientException) {
    return WizardFailureKind.ambiguousNetwork;
  }
  final t = error.runtimeType.toString();
  if (t.contains('Socket') || t.contains('Timeout') || t.contains('ClientException') || t.contains('Handshake')) {
    return WizardFailureKind.ambiguousNetwork;
  }
  return WizardFailureKind.rejected;
}

/// Ghi chú gửi kèm yêu cầu IoT. Backend wizard CHƯA lưu danh sách thiết bị (Plan Items), nên số lượng ước tính
/// chỉ được ghi vào ghi chú dưới dạng tham khảo, có gắn nhãn rõ là ước tính.
String buildWizardIotNotes({String? userNotes, int? gateways, int? sensors, int? actuators, double? totalVnd}) {
  final parts = <String>[];
  final u = userNotes?.trim() ?? '';
  if (u.isNotEmpty) parts.add(u);
  if (gateways != null && sensors != null && actuators != null) {
    final cost = totalVnd == null ? '' : ', chi phí ước tính ~${totalVnd.round()} đ';
    parts.add(
      '[Ước tính từ ứng dụng, chưa phải kế hoạch thiết bị] $gateways gateway, $sensors node cảm biến, $actuators node van/bơm$cost.',
    );
  }
  final text = parts.join('\n');
  return text.length > 1000 ? text.substring(0, 1000) : text;
}
