/// Mã giảm giá / Coupon ưu đãi (`/api/v1/discount-codes`).
class DiscountCodeModel {
  final String id;
  final String code;
  final String description;
  final int discountType; // 0 = Percentage, 1 = FixedAmount
  final String discountTypeText;
  final double discountValue;
  final double minContractValue;
  final double? maxDiscountAmount;
  final DateTime? startDateUtc;
  final DateTime? endDateUtc;
  final int? usageLimit;
  final int usedCount;
  final bool isActive;

  const DiscountCodeModel({
    required this.id,
    required this.code,
    this.description = '',
    this.discountType = 0,
    this.discountTypeText = 'Phần trăm (%)',
    this.discountValue = 0,
    this.minContractValue = 0,
    this.maxDiscountAmount,
    this.startDateUtc,
    this.endDateUtc,
    this.usageLimit,
    this.usedCount = 0,
    this.isActive = true,
  });

  factory DiscountCodeModel.fromJson(Map<String, dynamic> j) {
    return DiscountCodeModel(
      id: '${j['id'] ?? ''}',
      code: '${j['code'] ?? ''}',
      description: '${j['description'] ?? ''}',
      discountType: (j['discountType'] as num?)?.toInt() ?? 0,
      discountTypeText:
          '${j['discountTypeText'] ?? (j['discountType'] == 1 ? 'Số tiền cố định' : 'Phần trăm (%)')}',
      discountValue: (j['discountValue'] as num?)?.toDouble() ?? 0.0,
      minContractValue: (j['minContractValue'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (j['maxDiscountAmount'] as num?)?.toDouble(),
      startDateUtc: j['startDateUtc'] != null
          ? DateTime.tryParse('${j['startDateUtc']}')
          : null,
      endDateUtc: j['endDateUtc'] != null
          ? DateTime.tryParse('${j['endDateUtc']}')
          : null,
      usageLimit: (j['usageLimit'] as num?)?.toInt(),
      usedCount: (j['usedCount'] as num?)?.toInt() ?? 0,
      isActive: j['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'description': description,
    'discountType': discountType,
    'discountTypeText': discountTypeText,
    'discountValue': discountValue,
    'minContractValue': minContractValue,
    if (maxDiscountAmount != null) 'maxDiscountAmount': maxDiscountAmount,
    if (startDateUtc != null) 'startDateUtc': startDateUtc!.toIso8601String(),
    if (endDateUtc != null) 'endDateUtc': endDateUtc!.toIso8601String(),
    if (usageLimit != null) 'usageLimit': usageLimit,
    'usedCount': usedCount,
    'isActive': isActive,
  };
}

/// Kết quả kiểm tra tính hợp lệ của mã giảm giá (`POST /api/v1/discount-codes/validate`).
class ValidateDiscountResult {
  final bool isValid;
  final String? message;
  final String code;
  final int? discountType;
  final double discountPercent;
  final double discountAmount;
  final double finalAmount;

  const ValidateDiscountResult({
    required this.isValid,
    this.message,
    required this.code,
    this.discountType,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    required this.finalAmount,
  });

  factory ValidateDiscountResult.fromJson(Map<String, dynamic> j) {
    return ValidateDiscountResult(
      isValid: j['isValid'] == true,
      message: j['message']?.toString(),
      code: '${j['code'] ?? ''}',
      discountType: (j['discountType'] as num?)?.toInt(),
      discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: (j['finalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'isValid': isValid,
    if (message != null) 'message': message,
    'code': code,
    if (discountType != null) 'discountType': discountType,
    'discountPercent': discountPercent,
    'discountAmount': discountAmount,
    'finalAmount': finalAmount,
  };
}

/// Kết quả tìm mã giảm giá tối ưu nhất (`GET /api/v1/discount-codes/best-applicable`).
class BestDiscountResult {
  final bool hasDiscount;
  final String? message;
  final DiscountCodeModel? discountCode;
  final double discountAmount;
  final double finalAmount;

  const BestDiscountResult({
    required this.hasDiscount,
    this.message,
    this.discountCode,
    this.discountAmount = 0.0,
    required this.finalAmount,
  });

  factory BestDiscountResult.fromJson(Map<String, dynamic> j) {
    return BestDiscountResult(
      hasDiscount: j['hasDiscount'] == true,
      message: j['message']?.toString(),
      discountCode: j['discountCode'] is Map
          ? DiscountCodeModel.fromJson(
              Map<String, dynamic>.from(j['discountCode']),
            )
          : null,
      discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: (j['finalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
