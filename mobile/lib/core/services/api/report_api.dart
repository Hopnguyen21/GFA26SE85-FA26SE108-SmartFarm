part of '../api_service.dart';

/// Báo cáo trang trại và xuất Excel.
abstract final class ReportApi {
  // ─── Báo cáo ────────────────────────────────────────────────────────
  static const Set<String> _reportKinds = {
    'overview',
    'water-usage',
    'electricity',
    'inventory',
    'tasks',
    'maintenance',
  };

  static String _reportQuery(DateTime? from, DateTime? to) {
    final q = <String>[
      if (from != null) 'fromUtc=${Uri.encodeComponent(from.toUtc().toIso8601String())}',
      if (to != null) 'toUtc=${Uri.encodeComponent(to.toUtc().toIso8601String())}',
    ];
    return q.isEmpty ? '' : '?${q.join('&')}';
  }

  static Future<Map<String, dynamic>> getFarmReport(String farmId, String kind, {DateTime? from, DateTime? to}) async {
    if (!_reportKinds.contains(kind)) throw ArgumentError('Loại báo cáo không hợp lệ: $kind');
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/report/$kind${_reportQuery(from, to)}',
    );
    if (resp == null || resp.statusCode != 200) throw Exception(ApiService._apiErrorMessage(resp));
    return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
  }

  /// Tải tệp Excel do backend tạo. kind = null → báo cáo tài nguyên tổng hợp (/report/excel).
  static Future<Uint8List> downloadFarmReportExcel(String farmId, {String? kind, DateTime? from, DateTime? to}) async {
    if (kind != null && !_reportKinds.contains(kind)) throw ArgumentError('Loại báo cáo không hợp lệ: $kind');
    final path = kind == null ? 'report/excel' : 'report/$kind/excel';
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/farms/$farmId/$path${kind == 'overview' ? '' : _reportQuery(from, to)}',
      timeout: const Duration(seconds: 60),
    );
    if (resp == null || resp.statusCode != 200) throw Exception(ApiService._apiErrorMessage(resp));
    return resp.bodyBytes;
  }
}
