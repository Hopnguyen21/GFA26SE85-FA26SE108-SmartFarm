part of '../models.dart';

class ZoneContractRenewalModel {
  final String id;
  final String contractId;
  final String newEndDate;
  final double? newMonthlyRentVnd;
  final double renewalValueVnd;
  final String? notes;
  final String createdAt;

  const ZoneContractRenewalModel({
    required this.id,
    required this.contractId,
    required this.newEndDate,
    this.newMonthlyRentVnd,
    required this.renewalValueVnd,
    this.notes,
    required this.createdAt,
  });

  factory ZoneContractRenewalModel.fromJson(Map<String, dynamic> json) {
    return ZoneContractRenewalModel(
      id: json['id']?.toString() ?? '',
      contractId: json['contractId']?.toString() ?? '',
      newEndDate: json['newEndDate']?.toString() ?? '',
      newMonthlyRentVnd: (json['newMonthlyRentVnd'] as num?)?.toDouble(),
      renewalValueVnd: (json['renewalValueVnd'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: json['createdAtUtc']?.toString() ?? '',
    );
  }
}

class ZoneContractModel {
  final String id;
  final String tenantId;
  final String farmId;
  final String farmName;
  final String zoneId;
  final String zoneName;
  final String? parentContractId;
  final String? parentContractNumber;
  final String? contractPackageName;
  final bool isCustomPackage;
  final String contractNumber;
  final String? cropType;
  final double monthlyRentVnd;
  final double depositVnd;
  final double totalContractValueVnd;
  final String startDate;
  final String endDate;
  final String status; // Active, ExpiringSoon, Expired, Terminated, Renewed
  final String statusText;
  final int daysRemaining;
  final String lesseeName;
  final String? lesseePhone;
  final String? lesseeIdentityNumber;
  final String? lesseeAddress;
  final String? specialTerms;
  final String? notes;
  final String? signedAtUtc;
  final List<ZoneContractRenewalModel> renewals;
  final String createdAt;

  const ZoneContractModel({
    required this.id,
    required this.tenantId,
    required this.farmId,
    required this.farmName,
    required this.zoneId,
    required this.zoneName,
    this.parentContractId,
    this.parentContractNumber,
    this.contractPackageName,
    this.isCustomPackage = false,
    required this.contractNumber,
    this.cropType,
    required this.monthlyRentVnd,
    required this.depositVnd,
    required this.totalContractValueVnd,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.statusText,
    required this.daysRemaining,
    required this.lesseeName,
    this.lesseePhone,
    this.lesseeIdentityNumber,
    this.lesseeAddress,
    this.specialTerms,
    this.notes,
    this.signedAtUtc,
    this.renewals = const [],
    required this.createdAt,
    this.subtotalVnd = 0,
    this.discountPercent = 0,
    this.discountVnd = 0,
    this.vatPercent = 0,
    this.vatAmountVnd = 0,
    this.equipment = const [],
  });

  /// Thành tiền trước VAT/chiết khấu, chiết khấu, VAT do backend tính.
  final double subtotalVnd;
  final double discountPercent;
  final double discountVnd;
  final double vatPercent;
  final double vatAmountVnd;

  /// Thiết bị kèm theo hợp đồng (từ báo giá lắp đặt của Zone).
  final List<ZoneContractEquipmentModel> equipment;

  /// Còn hiệu lực: backend có cả Active và ExpiringSoon (còn ≤ 30 ngày), cả hai đều là hợp đồng đang chạy.
  bool get isActive => status == 'Active' || status == 'ExpiringSoon';

  /// Còn hạn thật sự: đang chạy theo trạng thái VÀ chưa quá ngày kết thúc (không tin riêng trạng thái, vì trạng thái
  /// do máy chủ cập nhật theo lịch có thể chậm so với ngày hết hạn).
  bool isInEffect({DateTime? now}) {
    if (!isActive) return false;
    final end = DateTime.tryParse(endDate);
    if (end == null) return daysRemaining >= 0;
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return !DateTime(end.year, end.month, end.day).isBefore(today);
  }

  /// Đã hết hạn thực tế: trạng thái Expired, hoặc còn ghi Active/ExpiringSoon nhưng đã quá ngày kết thúc.
  /// Không gồm hợp đồng đã tái ký (Renewed) hay chấm dứt (Terminated).
  bool isLapsed({DateTime? now}) =>
      !isInEffect(now: now) && (status == 'Expired' || isActive);

  /// Sắp hết hạn: chỉ tính hợp đồng đang chạy còn 0–30 ngày (không tính đã tái ký / chấm dứt / hết hạn).
  bool get isExpiringSoon =>
      isActive && daysRemaining >= 0 && daysRemaining <= 30;

  factory ZoneContractModel.fromJson(Map<String, dynamic> json) {
    var rawRenewals = json['renewals'];
    List<ZoneContractRenewalModel> parsedRenewals = [];
    if (rawRenewals is List) {
      parsedRenewals = rawRenewals
          .map(
            (r) => ZoneContractRenewalModel.fromJson(r as Map<String, dynamic>),
          )
          .toList();
    }

    final rawStatus = json['status']?.toString() ?? 'Active';
    // Enum backend: Active=0, ExpiringSoon=1, Expired=2, Terminated=3, Renewed=4 (API trả chuỗi; số chỉ để dự phòng).
    const byIndex = [
      'Active',
      'ExpiringSoon',
      'Expired',
      'Terminated',
      'Renewed',
    ];
    final idx = int.tryParse(rawStatus);
    final displayStatus = idx != null && idx >= 0 && idx < byIndex.length
        ? byIndex[idx]
        : byIndex.firstWhere(
            (s) => s.toLowerCase() == rawStatus.toLowerCase(),
            orElse: () => rawStatus,
          );

    return ZoneContractModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? '',
      farmName: json['farmName']?.toString() ?? 'Nông trại',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? 'Vùng trồng',
      parentContractId: json['parentContractId']?.toString(),
      parentContractNumber: json['parentContractNumber']?.toString(),
      contractPackageName: json['contractPackageName']?.toString(),
      isCustomPackage: json['isCustomPackage'] == true,
      contractNumber: json['contractNumber']?.toString() ?? '',
      cropType: json['cropType']?.toString(),
      monthlyRentVnd: (json['monthlyRentVnd'] as num?)?.toDouble() ?? 0.0,
      depositVnd: (json['depositVnd'] as num?)?.toDouble() ?? 0.0,
      totalContractValueVnd:
          (json['totalContractValueVnd'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      status: displayStatus,
      statusText:
          json['statusText']?.toString() ??
          (displayStatus == 'Active' ? 'Đang hiệu lực' : displayStatus),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      lesseeName: json['lesseeName']?.toString() ?? '',
      lesseePhone: json['lesseePhone']?.toString(),
      lesseeIdentityNumber: json['lesseeIdentityNumber']?.toString(),
      lesseeAddress: json['lesseeAddress']?.toString(),
      specialTerms: json['specialTerms']?.toString(),
      notes: json['notes']?.toString(),
      signedAtUtc: json['signedAtUtc']?.toString(),
      renewals: parsedRenewals,
      createdAt: json['createdAtUtc']?.toString() ?? '',
      subtotalVnd: (json['subtotalVnd'] as num?)?.toDouble() ?? 0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0,
      discountVnd: (json['discountVnd'] as num?)?.toDouble() ?? 0,
      vatPercent: (json['vatPercent'] as num?)?.toDouble() ?? 0,
      vatAmountVnd: (json['vatAmountVnd'] as num?)?.toDouble() ?? 0,
      equipment: [
        for (final e in (json['equipment'] as List? ?? const []))
          ZoneContractEquipmentModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
      ],
    );
  }
}

/// Một dòng thiết bị trong hợp đồng thuê Zone.
class ZoneContractEquipmentModel {
  final String code;
  final String name;
  final String category;
  final String unit;
  final int quantity;
  final double unitPrice;

  const ZoneContractEquipmentModel({
    required this.code,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
  });

  double get lineTotal => quantity * unitPrice;

  factory ZoneContractEquipmentModel.fromJson(Map<String, dynamic> j) =>
      ZoneContractEquipmentModel(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        unit: j['unit']?.toString() ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

class DeviceDepreciationModel {
  final String id;
  final String zoneId;
  final String zoneName;
  final String deviceId;
  final String deviceName;
  final String hardwareAddress;
  final String deviceType;
  final double originalCostVnd;
  final double monthlyDepreciationVnd;
  final double accumulatedDepreciationVnd;
  final double currentBookValueVnd;
  final int depreciationLifetimeMonths;
  final int monthsElapsed;
  final int remainingMonths;
  final String method;
  final String startDate;
  final String
  depreciationStatus; // 'Active', 'ExpiringSoon', 'FullyDepreciated'
  final bool isNearContractRenewal;
  final String? notes;
  final String createdAt;

  const DeviceDepreciationModel({
    required this.id,
    required this.zoneId,
    required this.zoneName,
    required this.deviceId,
    required this.deviceName,
    required this.hardwareAddress,
    required this.deviceType,
    required this.originalCostVnd,
    required this.monthlyDepreciationVnd,
    required this.accumulatedDepreciationVnd,
    required this.currentBookValueVnd,
    required this.depreciationLifetimeMonths,
    required this.monthsElapsed,
    required this.remainingMonths,
    required this.method,
    required this.startDate,
    required this.depreciationStatus,
    required this.isNearContractRenewal,
    this.notes,
    required this.createdAt,
  });

  double get progressPercentage {
    if (depreciationLifetimeMonths <= 0) return 1.0;
    final p = monthsElapsed / depreciationLifetimeMonths;
    return p.clamp(0.0, 1.0);
  }

  factory DeviceDepreciationModel.fromJson(Map<String, dynamic> json) {
    return DeviceDepreciationModel(
      id: json['id']?.toString() ?? '',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? 'Khu vực',
      deviceId: json['deviceId']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Thiết bị IoT',
      hardwareAddress: json['hardwareAddress']?.toString() ?? '',
      deviceType: json['deviceType']?.toString() ?? 'Node',
      originalCostVnd: (json['originalCostVnd'] as num?)?.toDouble() ?? 0.0,
      monthlyDepreciationVnd:
          (json['monthlyDepreciationVnd'] as num?)?.toDouble() ?? 0.0,
      accumulatedDepreciationVnd:
          (json['accumulatedDepreciationVnd'] as num?)?.toDouble() ?? 0.0,
      currentBookValueVnd:
          (json['currentBookValueVnd'] as num?)?.toDouble() ?? 0.0,
      depreciationLifetimeMonths:
          (json['depreciationLifetimeMonths'] as num?)?.toInt() ?? 24,
      monthsElapsed: (json['monthsElapsed'] as num?)?.toInt() ?? 0,
      remainingMonths: (json['remainingMonths'] as num?)?.toInt() ?? 0,
      method: json['method']?.toString() ?? 'STRAIGHT_LINE',
      startDate: json['startDate']?.toString() ?? '',
      depreciationStatus: json['depreciationStatus']?.toString() ?? 'Active',
      isNearContractRenewal: json['isNearContractRenewal'] == true,
      notes: json['notes']?.toString(),
      createdAt: json['createdAtUtc']?.toString() ?? '',
    );
  }
}

class ExpiringContractAlertModel {
  final String contractId;
  final String contractNumber;
  final String farmId;
  final String farmName;
  final String zoneId;
  final String zoneName;
  final String? cropType;
  final String endDate;
  final int daysRemaining;
  final String status;
  final double totalContractValueVnd;

  const ExpiringContractAlertModel({
    required this.contractId,
    required this.contractNumber,
    required this.farmId,
    required this.farmName,
    required this.zoneId,
    required this.zoneName,
    this.cropType,
    required this.endDate,
    required this.daysRemaining,
    required this.status,
    required this.totalContractValueVnd,
  });

  factory ExpiringContractAlertModel.fromJson(Map<String, dynamic> json) {
    return ExpiringContractAlertModel(
      contractId: json['contractId']?.toString() ?? '',
      contractNumber: json['contractNumber']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? '',
      farmName: json['farmName']?.toString() ?? '',
      zoneId: json['zoneId']?.toString() ?? '',
      zoneName: json['zoneName']?.toString() ?? '',
      cropType: json['cropType']?.toString(),
      endDate: json['endDate']?.toString() ?? '',
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'Active',
      totalContractValueVnd:
          (json['totalContractValueVnd'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Tham số nghiệp vụ do Admin cấu hình (tỷ lệ cọc, ngưỡng mưa, giảm giá); app chỉ hiển thị/ước tính theo giá trị server.
class BusinessParameters {
  final double depositPercent;
  final double rainGuardThresholdPercent;
  final double repeatPurchaseDiscountPercent;
  final double renewalDiscountPercent;

  const BusinessParameters({
    required this.depositPercent,
    required this.rainGuardThresholdPercent,
    required this.repeatPurchaseDiscountPercent,
    required this.renewalDiscountPercent,
  });

  /// Chỉ dùng khi chưa tải xong hoặc server không trả lời; khớp giá trị mặc định ở backend.
  static const fallback = BusinessParameters(
    depositPercent: 30,
    rainGuardThresholdPercent: 70,
    repeatPurchaseDiscountPercent: 15,
    renewalDiscountPercent: 10,
  );

  /// Giá trị hiện hành dùng cho nhãn / tính nhanh ở các nơi không giữ store API (logic thuần); [BusinessParametersStore.refresh] cập nhật.
  static BusinessParameters active = fallback;

  factory BusinessParameters.fromJson(Map<String, dynamic> json) =>
      BusinessParameters(
        depositPercent:
            (json['depositPercent'] as num?)?.toDouble() ??
            fallback.depositPercent,
        rainGuardThresholdPercent:
            (json['rainGuardThresholdPercent'] as num?)?.toDouble() ??
            fallback.rainGuardThresholdPercent,
        repeatPurchaseDiscountPercent:
            (json['repeatPurchaseDiscountPercent'] as num?)?.toDouble() ??
            fallback.repeatPurchaseDiscountPercent,
        renewalDiscountPercent:
            (json['renewalDiscountPercent'] as num?)?.toDouble() ??
            fallback.renewalDiscountPercent,
      );

  /// Phần trăm còn lại sau tạm ứng (nghiệm thu).
  double get remainingPercent => 100 - depositPercent;

  /// "30" thay vì "30.0"; giữ phần lẻ nếu có ("32.5").
  static String fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Nhãn phần trăm dùng chung ("30%"); [remainingOf] cho phần còn lại sau tạm ứng (làm tròn 2 số lẻ).
  static String pct(double v) => '${fmt(v)}%';
  static String remainingOf(double depositPercent) =>
      pct(double.parse((100 - depositPercent).toStringAsFixed(2)));
  String get depositLabel => pct(depositPercent);
  String get remainingLabel => pct(remainingPercent);
}

/// Hóa đơn thu phí theo hợp đồng Zone.
class BillModel {
  final String id;
  final String billCode;
  final String contractId;
  final String contractNumber;
  final String lesseeName;
  final double amount;
  final double paidAmount;
  final double remainingAmount;

  /// Tên enum của backend: Draft, Issued, PartiallyPaid, Paid, Overdue, Cancelled.
  final String status;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final DateTime? paidDate;
  final String? paymentMethod;
  final String? notes;
  final String createdByName;

  const BillModel({
    required this.id,
    required this.billCode,
    required this.contractId,
    required this.contractNumber,
    required this.lesseeName,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.issueDate,
    this.dueDate,
    this.paidDate,
    this.paymentMethod,
    this.notes,
    this.createdByName = '',
  });

  static const _statusByIndex = [
    'Draft',
    'Issued',
    'PartiallyPaid',
    'Paid',
    'Overdue',
    'Cancelled',
  ];

  factory BillModel.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    final rawStatus = j['status'];
    final status = rawStatus is int
        ? (rawStatus >= 0 && rawStatus < _statusByIndex.length
              ? _statusByIndex[rawStatus]
              : 'Draft')
        : (rawStatus?.toString() ?? 'Draft');
    return BillModel(
      id: j['id']?.toString() ?? '',
      billCode: j['billCode']?.toString() ?? '',
      contractId: j['contractId']?.toString() ?? '',
      contractNumber: j['contractNumber']?.toString() ?? '',
      lesseeName: j['lesseeName']?.toString() ?? '',
      amount: d(j['amount']),
      paidAmount: d(j['paidAmount']),
      remainingAmount: d(j['remainingAmount']),
      status: status,
      issueDate: DateTime.tryParse(j['issueDate']?.toString() ?? ''),
      dueDate: DateTime.tryParse(j['dueDate']?.toString() ?? ''),
      paidDate: DateTime.tryParse(j['paidDate']?.toString() ?? ''),
      paymentMethod: j['paymentMethod']?.toString(),
      notes: j['notes']?.toString(),
      createdByName: j['createdByName']?.toString() ?? '',
    );
  }

  bool get isCancelled => status == 'Cancelled';

  /// Còn nợ và chưa hủy: kỹ thuật viên có thể thu tiền.
  bool get canCollect =>
      remainingAmount > 0 && !isCancelled && status != 'Paid';

  /// Backend chỉ cho sửa khi chưa thanh toán đủ; chỉ xóa hóa đơn nháp hoặc đã hủy.
  bool get canEdit => status != 'Paid' && !isCancelled;
  bool get canDelete => status == 'Draft' || status == 'Cancelled';
}
