/// Dữ liệu liên kết và mã QR thanh toán PayOS (`PayOSPaymentLinkResult`).
class PayOSPaymentLinkModel {
  final int orderCode;
  final double amount;
  final String description;
  final String status;
  final String checkoutUrl;
  final String? qrCode;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final String? bankBin;
  final String? bankName;
  final String? paymentLinkId;
  final String billId;
  final String billCode;

  const PayOSPaymentLinkModel({
    required this.orderCode,
    required this.amount,
    required this.description,
    required this.status,
    required this.checkoutUrl,
    this.qrCode,
    this.bankAccountNumber,
    this.bankAccountName,
    this.bankBin,
    this.bankName,
    this.paymentLinkId,
    required this.billId,
    required this.billCode,
  });

  factory PayOSPaymentLinkModel.fromJson(Map<String, dynamic> json) {
    return PayOSPaymentLinkModel(
      orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      checkoutUrl: json['checkoutUrl']?.toString() ?? '',
      qrCode: json['qrCode']?.toString(),
      bankAccountNumber: json['bankAccountNumber']?.toString(),
      bankAccountName: json['bankAccountName']?.toString(),
      bankBin: json['bankBin']?.toString(),
      bankName: json['bankName']?.toString(),
      paymentLinkId: json['paymentLinkId']?.toString(),
      billId: json['billId']?.toString() ?? '',
      billCode: json['billCode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'orderCode': orderCode,
    'amount': amount,
    'description': description,
    'status': status,
    'checkoutUrl': checkoutUrl,
    'qrCode': qrCode,
    'bankAccountNumber': bankAccountNumber,
    'bankAccountName': bankAccountName,
    'bankBin': bankBin,
    'bankName': bankName,
    'paymentLinkId': paymentLinkId,
    'billId': billId,
    'billCode': billCode,
  };

  /// Tạo link ảnh VietQR chuẩn Napas247 tương tự Web.
  String get vietQrImageUrl {
    final bin = (bankBin != null && bankBin!.isNotEmpty) ? bankBin! : '970422';
    final acc = bankAccountNumber ?? '';
    final name = Uri.encodeComponent(bankAccountName ?? '');
    final desc = Uri.encodeComponent(description);
    return 'https://img.vietqr.io/image/$bin-$acc-compact2.png?amount=${amount.round()}&addInfo=$desc&accountName=$name';
  }
}

/// Kết quả kiểm tra trạng thái thanh toán PayOS (`PayOSPaymentStatusResult`).
class PayOSPaymentStatusModel {
  final int orderCode;
  final String status;
  final double amount;
  final double amountPaid;
  final double amountRemaining;
  final bool isSuccess;
  final String? transactionDateTime;
  final String? reference;

  const PayOSPaymentStatusModel({
    required this.orderCode,
    required this.status,
    required this.amount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.isSuccess,
    this.transactionDateTime,
    this.reference,
  });

  factory PayOSPaymentStatusModel.fromJson(Map<String, dynamic> json) {
    return PayOSPaymentStatusModel(
      orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      amountRemaining: (json['amountRemaining'] as num?)?.toDouble() ?? 0.0,
      isSuccess: json['isSuccess'] == true || json['status'] == 'PAID',
      transactionDateTime: json['transactionDateTime']?.toString(),
      reference: json['reference']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'orderCode': orderCode,
    'status': status,
    'amount': amount,
    'amountPaid': amountPaid,
    'amountRemaining': amountRemaining,
    'isSuccess': isSuccess,
    'transactionDateTime': transactionDateTime,
    'reference': reference,
  };
}
