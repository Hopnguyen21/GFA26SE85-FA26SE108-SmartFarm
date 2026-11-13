import '../../core/services/api_service.dart';

/// Số ngày dự kiến mặc định của vụ tạo kèm Zone (giống web).
const autoSeasonDays = 90;

/// Backend yêu cầu ngày kết thúc dự kiến sau ngày bắt đầu ít nhất chừng này ngày.
const minSeasonDays = 20;

/// Ngày dạng yyyy-MM-dd (định dạng DateOnly của backend).
String autoSeasonDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Ngày kết thúc dự kiến sớm nhất hợp lệ cho một ngày bắt đầu.
DateTime minSeasonEnd(DateTime start) =>
    DateTime(start.year, start.month, start.day + minSeasonDays);

/// Payload tạo vụ trồng kèm Zone vừa tạo, dùng đúng hồ sơ đã gắn cho Zone.
/// Bỏ trống [name]/[startDate]/[expectedEndDate] thì dùng mặc định: `Vụ <cây> <năm>`, hôm nay, sau [autoSeasonDays] ngày.
Map<String, dynamic> buildAutoSeasonPayload({
  required String cropId,
  required String cropName,
  required String growthProfileId,
  String? varietyId,
  required DateTime today,
  String? name,
  DateTime? startDate,
  DateTime? expectedEndDate,
}) {
  final start = startDate ?? today;
  final end =
      expectedEndDate ??
      DateTime(start.year, start.month, start.day + autoSeasonDays);
  final custom = name?.trim() ?? '';
  return {
    'name': custom.isNotEmpty ? custom : autoSeasonName(cropName, start),
    'cropId': cropId,
    'varietyId': ?varietyId,
    'growthProfileId': growthProfileId,
    'startDate': autoSeasonDate(start),
    'expectedEndDate': autoSeasonDate(end),
  };
}

String autoSeasonName(String cropName, DateTime start) {
  final crop = cropName.trim();
  return crop.isEmpty ? 'Vụ ${start.year}' : 'Vụ $crop ${start.year}';
}

/// Kết quả tạo vụ. `created == false` thì [message] là lý do để báo cho người dùng (Zone vẫn đã được tạo).
typedef AutoSeasonResult = ({bool created, String message});

/// Tạo vụ trồng ngay sau khi tạo Zone. Không ném lỗi: lỗi được trả về để hiển thị, không nuốt im lặng.
Future<AutoSeasonResult> autoCreateSeasonForNewZone({
  required String zoneId,
  required String cropId,
  required String cropName,
  required String growthProfileId,
  String? varietyId,
  String? name,
  DateTime? startDate,
  DateTime? expectedEndDate,
  DateTime? now,
  Future<Map<String, dynamic>> Function(String zoneId, Map<String, dynamic>)?
  createSeason,
}) async {
  final payload = buildAutoSeasonPayload(
    cropId: cropId,
    cropName: cropName,
    growthProfileId: growthProfileId,
    varietyId: varietyId,
    today: now ?? DateTime.now(),
    name: name,
    startDate: startDate,
    expectedEndDate: expectedEndDate,
  );
  try {
    await (createSeason ?? CropApi.createPlantingSeason)(zoneId, payload);
    return (
      created: true,
      message:
          'Đã tạo vụ trồng "${payload['name']}" (${payload['startDate']} → ${payload['expectedEndDate']}).',
    );
  } catch (e) {
    return (
      created: false,
      message:
          'Chưa tạo được vụ trồng: ${e.toString().replaceFirst('Exception: ', '')}',
    );
  }
}

/// Kết quả bắt đầu vụ. `ok == false` thì [message] là lý do backend từ chối (chưa đến ngày bắt đầu, Zone đang có vụ khác...).
typedef StartSeasonResult = ({bool ok, String message});

/// Bắt đầu một vụ dự kiến của Zone. Không ném lỗi: lỗi được trả về để hiển thị, không nuốt im lặng.
Future<StartSeasonResult> startSeasonForZone(
  String zoneId,
  String seasonId, {
  Future<Map<String, dynamic>> Function(String zoneId, String seasonId)? start,
}) async {
  try {
    await (start ?? CropApi.startPlantingSeason)(zoneId, seasonId);
    return (ok: true, message: 'Đã bắt đầu vụ: vụ chuyển sang đang canh tác.');
  } catch (e) {
    return (
      ok: false,
      message:
          'Chưa bắt đầu được vụ: ${e.toString().replaceFirst('Exception: ', '')}',
    );
  }
}
