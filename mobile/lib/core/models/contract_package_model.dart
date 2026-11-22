/// Gói dịch vụ hợp đồng mẫu (`/api/v1/contract-packages`).
class ContractPackageModel {
  final String id;
  final String packageName;
  final String description;
  final int durationMonths;
  final int maxZones;
  final double price;
  final String currency;
  final String status;
  final String statusText;
  final bool isCustom;
  final String? customerName;
  final DateTime? createdAtUtc;

  const ContractPackageModel({
    required this.id,
    required this.packageName,
    this.description = '',
    this.durationMonths = 12,
    this.maxZones = 1,
    this.price = 0,
    this.currency = 'VND',
    this.status = 'Active',
    this.statusText = 'Hoạt động',
    this.isCustom = false,
    this.customerName,
    this.createdAtUtc,
  });

  factory ContractPackageModel.fromJson(Map<String, dynamic> j) {
    return ContractPackageModel(
      id: '${j['id'] ?? ''}',
      packageName: '${j['packageName'] ?? ''}',
      description: '${j['description'] ?? ''}',
      durationMonths: (j['durationMonths'] as num?)?.toInt() ?? 12,
      maxZones: (j['maxZones'] as num?)?.toInt() ?? 1,
      price: (j['price'] as num?)?.toDouble() ?? 0.0,
      currency: '${j['currency'] ?? 'VND'}',
      status: '${j['status'] ?? 'Active'}',
      statusText: '${j['statusText'] ?? 'Hoạt động'}',
      isCustom: j['isCustom'] == true,
      customerName: j['customerName']?.toString(),
      createdAtUtc: j['createdAtUtc'] != null
          ? DateTime.tryParse('${j['createdAtUtc']}')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'packageName': packageName,
    'description': description,
    'durationMonths': durationMonths,
    'maxZones': maxZones,
    'price': price,
    'currency': currency,
    'status': status,
    'statusText': statusText,
    'isCustom': isCustom,
    if (customerName != null) 'customerName': customerName,
    if (createdAtUtc != null) 'createdAtUtc': createdAtUtc!.toIso8601String(),
  };
}
