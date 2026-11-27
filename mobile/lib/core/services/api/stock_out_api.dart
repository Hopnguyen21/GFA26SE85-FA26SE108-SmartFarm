part of '../api_service.dart';

/// Phiếu xuất kho theo Farm (`/api/v1/farms/{farmId}/stock-outs`): kỹ thuật viên tạo và gửi duyệt phiếu xuất thiết bị theo hợp đồng lắp đặt,
/// Admin duyệt (trên web). Chỉ Admin và kỹ thuật viên gọi được các API này.
abstract final class StockOutApi {
  static Future<List<Map<String, dynamic>>> getFarmStockOuts(
    String farmId,
  ) async {
    try {
      final resp = await ApiService._getWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/stock-outs',
      );
      if (resp == null || resp.statusCode == 404) return [];
      return ApiService._asMapList(ApiService._decodeUtf8OrThrow(resp));
    } catch (_) {
      return [];
    }
  }

  /// Tạo phiếu ở trạng thái Draft. [details]: `{inventoryItemId, quantity, notes}` (id thiết bị phần cứng trong kho nền tảng).
  static Future<Map<String, dynamic>> create(
    String farmId, {
    required String? zoneId,
    required String notes,
    required List<Map<String, dynamic>> details,
    String? serviceRequestId,
  }) async => Map<String, dynamic>.from(
    ApiService._decodeUtf8OrThrow(
          await ApiService._postWithAuth(
            '${ApiService.baseUrl}/api/v1/farms/$farmId/stock-outs',
            {
              'zoneId': zoneId,
              'notes': notes,
              'details': details,
              'serviceRequestId': ?serviceRequestId,
            },
          ),
        )
        as Map,
  );

  /// Xóa phiếu (backend chỉ cho khi Bản nháp hoặc Đã hủy).
  static Future<void> delete(String farmId, String stockOutId) async {
    ApiService._decodeOrThrow(
      await ApiService._deleteWithAuth(
        '${ApiService.baseUrl}/api/v1/farms/$farmId/stock-outs/$stockOutId',
      ),
      ok: const {200, 204},
    );
  }

  /// Đổi trạng thái: `Pending` = gửi Admin duyệt. (Duyệt/Hoàn thành là việc của Admin trên web, app không gọi.)
  static Future<Map<String, dynamic>> setStatus(
    String farmId,
    String stockOutId,
    String status, {
    String? notes,
  }) async => Map<String, dynamic>.from(
    ApiService._decodeUtf8OrThrow(
          await ApiService._putWithAuth(
            '${ApiService.baseUrl}/api/v1/farms/$farmId/stock-outs/$stockOutId/status',
            {'status': status, 'notes': ?notes},
          ),
        )
        as Map,
  );
}
