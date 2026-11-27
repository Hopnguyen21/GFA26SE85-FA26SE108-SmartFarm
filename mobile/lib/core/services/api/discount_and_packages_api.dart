part of '../api_service.dart';

/// Dịch vụ tra cứu và áp dụng Mã giảm giá (`/api/v1/discount-codes`).
abstract final class DiscountApi {
  /// Lấy danh sách mã giảm giá đang hoạt động (Owner, Technician, Admin)
  static Future<List<DiscountCodeModel>> getDiscountCodes({
    bool? activeOnly,
  }) async {
    final query = <String, String>{
      if (activeOnly != null) 'activeOnly': activeOnly.toString(),
    };
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/v1/discount-codes',
    ).replace(queryParameters: query.isEmpty ? null : query);

    final resp = await ApiService._getWithAuth(uri.toString());
    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['value'] ?? decoded['data']) : null);
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map((j) => DiscountCodeModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// Kiểm tra tính hợp lệ và tính số tiền giảm giá cho một giá trị hợp đồng / hóa đơn
  static Future<ValidateDiscountResult> validateDiscountCode({
    required String code,
    required double contractAmount,
  }) async {
    if (code.trim().isEmpty) {
      throw Exception('Vui lòng nhập mã giảm giá.');
    }

    final resp = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/discount-codes/validate',
      {'code': code.trim(), 'contractAmount': contractAmount},
    );

    if (resp == null || (resp.statusCode != 200 && resp.statusCode != 400)) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resultData = data['value'] is Map
        ? data['value'] as Map<String, dynamic>
        : data;
    return ValidateDiscountResult.fromJson(resultData);
  }

  /// Tìm và đề xuất mã giảm giá tối ưu nhất cho giá trị hợp đồng
  static Future<BestDiscountResult> getBestDiscount({
    required double contractAmount,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/v1/discount-codes/best-applicable',
    ).replace(queryParameters: {'contractAmount': contractAmount.toString()});

    final resp = await ApiService._getWithAuth(uri.toString());
    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resultData = data['value'] is Map
        ? data['value'] as Map<String, dynamic>
        : data;
    return BestDiscountResult.fromJson(resultData);
  }
}

/// Dịch vụ tra cứu Gói dịch vụ mẫu (`/api/v1/contract-packages`).
abstract final class ContractPackageApi {
  /// Lấy danh sách các gói dịch vụ mẫu
  static Future<List<ContractPackageModel>> getPackages({
    bool? activeOnly,
    bool isCustom = false,
  }) async {
    final query = <String, String>{
      if (activeOnly != null) 'activeOnly': activeOnly.toString(),
      'isCustom': isCustom.toString(),
    };
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/v1/contract-packages',
    ).replace(queryParameters: query);

    final resp = await ApiService._getWithAuth(uri.toString());
    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? (decoded['value'] ?? decoded['data']) : null);
    if (rawList is! List) return [];

    return rawList
        .whereType<Map>()
        .map((j) => ContractPackageModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// Lấy thông tin chi tiết một gói hợp đồng
  static Future<ContractPackageModel> getPackageById(String id) async {
    final resp = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/contract-packages/$id',
    );
    if (resp == null || resp.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(resp));
    }

    final data =
        jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final resultData = data['value'] is Map
        ? data['value'] as Map<String, dynamic>
        : data;
    return ContractPackageModel.fromJson(resultData);
  }
}
