part of '../api_service.dart';

/// Cổng thanh toán trực tuyến tự động PayOS / VietQR (`/api/v1/payments/payos`).
abstract final class PaymentApi {
  /// Khởi tạo liên kết thanh toán và mã VietQR cho một hóa đơn
  static Future<PayOSPaymentLinkModel> createBillPayment(
    String billId, {
    double? amount,
    String? returnUrl,
    String? cancelUrl,
  }) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/payments/payos/create-bill-payment/$billId',
      {
        if (amount != null && amount > 0) 'amount': amount,
        'returnUrl': ?returnUrl,
        'cancelUrl': ?cancelUrl,
      },
    );

    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resultData = data['value'] is Map ? data['value'] as Map<String, dynamic> : data;
    return PayOSPaymentLinkModel.fromJson(resultData);
  }

  /// Kiểm tra trạng thái thanh toán từ PayOS theo orderCode (tự động đồng bộ hóa đơn)
  static Future<PayOSPaymentStatusModel> checkPayOSStatus(int orderCode) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/payments/payos/check-status/$orderCode',
    );

    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resultData = data['value'] is Map ? data['value'] as Map<String, dynamic> : data;
    return PayOSPaymentStatusModel.fromJson(resultData);
  }

  /// Xác nhận thanh toán thủ công khi ngân hàng/PayOS đồng bộ chậm hoặc kiểm thử (POST /api/v1/payments/payos/confirm-manual/{orderCode})
  static Future<PayOSPaymentStatusModel> confirmManualPayOS(int orderCode) async {
    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/payments/payos/confirm-manual/$orderCode',
      {},
    );

    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resultData = data['value'] is Map ? data['value'] as Map<String, dynamic> : data;
    return PayOSPaymentStatusModel.fromJson(resultData);
  }
}
