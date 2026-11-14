part of '../api_service.dart';

/// Hóa đơn thu phí liên kết hợp đồng Zone (`/api/v1/bills`).
/// Owner chỉ xem; kỹ thuật viên (và Admin) tạo, ghi nhận thanh toán, đổi trạng thái, sửa, xóa (khớp backend).
abstract final class BillApi {
  static Future<List<BillModel>> getBills({String? contractId}) async {
    final q = contractId == null || contractId.isEmpty
        ? ''
        : '?contractId=${Uri.encodeQueryComponent(contractId)}';
    return [
      for (final m in ApiService._listOf(
        ApiService._decodeUtf8OrThrow(
          await ApiService._getWithAuth('${ApiService.baseUrl}/api/v1/bills$q'),
        ),
      ))
        BillModel.fromJson(m),
    ];
  }

  static Future<BillModel> createFromContract({
    required String contractId,
    required double amount,
    required DateTime dueDate,
    String? paymentMethod,
    String? notes,
  }) async => BillModel.fromJson(
    _asMap(
      ApiService._decodeUtf8OrThrow(
        await ApiService._postWithAuth('${ApiService.baseUrl}/api/v1/bills', {
          'contractId': contractId,
          'amount': amount,
          'dueDate': ApiService._isoDate(dueDate),
          'paymentMethod': ?paymentMethod,
          'notes': ?notes,
        }),
      ),
    ),
  );

  static Future<BillModel> recordPayment(
    String billId, {
    required double paymentAmount,
    String? paymentMethod,
    String? notes,
  }) async => BillModel.fromJson(
    _asMap(
      ApiService._decodeUtf8OrThrow(
        await ApiService._postWithAuth(
          '${ApiService.baseUrl}/api/v1/bills/$billId/payments',
          {
            'paymentAmount': paymentAmount,
            'paymentMethod': ?paymentMethod,
            'notes': ?notes,
          },
        ),
      ),
    ),
  );

  /// status là tên enum của backend: Draft, Issued, PartiallyPaid, Paid, Overdue, Cancelled.
  static Future<BillModel> updateStatus(
    String billId,
    String status, {
    String? notes,
  }) async => BillModel.fromJson(
    _asMap(
      ApiService._decodeUtf8OrThrow(
        await ApiService._putWithAuth(
          '${ApiService.baseUrl}/api/v1/bills/$billId/status',
          {'status': status, 'notes': ?notes},
        ),
      ),
    ),
  );

  static Future<BillModel> update(
    String billId, {
    required double amount,
    required DateTime dueDate,
    String? paymentMethod,
    String? notes,
  }) async => BillModel.fromJson(
    _asMap(
      ApiService._decodeUtf8OrThrow(
        await ApiService._putWithAuth(
          '${ApiService.baseUrl}/api/v1/bills/$billId',
          {
            'amount': amount,
            'dueDate': ApiService._isoDate(dueDate),
            'paymentMethod': ?paymentMethod,
            'notes': ?notes,
          },
        ),
      ),
    ),
  );

  static Future<void> delete(String billId) async {
    final resp = await ApiService._deleteWithAuth(
      '${ApiService.baseUrl}/api/v1/bills/$billId',
    );
    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 204)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }
  }

  static Map<String, dynamic> _asMap(dynamic d) =>
      d is Map<String, dynamic> ? d : <String, dynamic>{};
}
