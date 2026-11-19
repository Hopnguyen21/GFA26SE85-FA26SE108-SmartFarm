part of '../api_service.dart';

/// Báo cáo khảo sát thực địa (`/api/v1/field-survey-reports`). Xem: Owner, Farmer, KTV, Admin (cùng tenant với Owner/Farmer);
/// tạo/sửa/xoá: kỹ thuật viên (chỉ phiếu của mình) và Admin. Mỗi phiếu dịch vụ chỉ có một báo cáo (tạo lại thì cập nhật báo cáo cũ).
abstract final class FieldSurveyApi {
  static Future<List<FieldSurveyReport>> list({
    String? farmId,
    String? serviceRequestId,
    String? zoneId,
    String? status,
    String? search,
  }) async {
    final q = <String, String>{
      'farmId': ?farmId,
      'serviceRequestId': ?serviceRequestId,
      'zoneId': ?zoneId,
      if (status != null && status.isNotEmpty && status != 'ALL')
        'status': status,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/v1/field-survey-reports',
    ).replace(queryParameters: q.isEmpty ? null : q);
    return [
      for (final m in ApiService._asMapList(
        ApiService._decodeUtf8OrThrow(
          await ApiService._getWithAuth(uri.toString()),
        ),
      ))
        FieldSurveyReport.fromJson(m),
    ];
  }

  static Future<FieldSurveyReport> getById(String id) async =>
      FieldSurveyReport.fromJson(
        Map<String, dynamic>.from(
          ApiService._decodeUtf8OrThrow(
                await ApiService._getWithAuth(
                  '${ApiService.baseUrl}/api/v1/field-survey-reports/$id',
                ),
              )
              as Map,
        ),
      );

  /// Báo cáo của một phiếu dịch vụ; null nếu chưa có (backend trả 204, 200 rỗng hoặc 404).
  static Future<FieldSurveyReport?> getByServiceRequest(
    String serviceRequestId,
  ) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/field-survey-reports/by-service-request/$serviceRequestId',
    );
    if (resp != null && (resp.statusCode == 404 || resp.statusCode == 204)) {
      return null;
    }
    if (resp != null && resp.statusCode == 200 && resp.bodyBytes.isEmpty) {
      return null;
    }
    final data = ApiService._decodeUtf8OrThrow(resp);
    return data is Map
        ? FieldSurveyReport.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  static Future<FieldSurveyReport> create(Map<String, dynamic> payload) async =>
      FieldSurveyReport.fromJson(
        Map<String, dynamic>.from(
          ApiService._decodeUtf8OrThrow(
                await ApiService._postWithAuth(
                  '${ApiService.baseUrl}/api/v1/field-survey-reports',
                  payload,
                ),
              )
              as Map,
        ),
      );

  static Future<FieldSurveyReport> update(
    String id,
    Map<String, dynamic> payload,
  ) async => FieldSurveyReport.fromJson(
    Map<String, dynamic>.from(
      ApiService._decodeUtf8OrThrow(
            await ApiService._putWithAuth(
              '${ApiService.baseUrl}/api/v1/field-survey-reports/$id',
              payload,
            ),
          )
          as Map,
    ),
  );

  static Future<void> delete(String id) async {
    ApiService._decodeOrThrow(
      await ApiService._deleteWithAuth(
        '${ApiService.baseUrl}/api/v1/field-survey-reports/$id',
      ),
      ok: const {200, 204},
    );
  }
}
