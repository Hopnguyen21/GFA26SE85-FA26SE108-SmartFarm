part of '../api_service.dart';

/// Tài liệu tri thức VietGAP.
abstract final class DocumentApi {
  static Future<List<AgricultureDocumentModel>>
  getAgricultureDocuments() async {
    final response = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/ai/knowledge/documents',
      timeout: const Duration(seconds: 30),
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : (decoded is Map ? decoded['value'] : null);
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map(
          (item) => AgricultureDocumentModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  static Future<AgricultureDocumentModel> getAgricultureDocument(
    String id,
  ) async {
    final response = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/ai/knowledge/documents/$id',
      timeout: const Duration(seconds: 30),
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    return AgricultureDocumentModel.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Chỉ cần file; các trường mô tả để trống thì server tự lấy từ nội dung file.
  static Future<AgricultureDocumentModel> uploadAgricultureDocument({
    required String fileName,
    required List<int> bytes,
    String? title,
    String category = 'general',
    String? cropScope,
    String? authorOrganization,
    String? version,
  }) async {
    if (bytes.isEmpty) throw Exception('File rỗng.');
    if (bytes.length > 50 * 1024 * 1024) {
      throw Exception('File vượt giới hạn 50 MB.');
    }
    Future<http.Response> send() async {
      final uploadUri = Uri.parse(
        '${ApiService.baseUrl}/api/v1/ai/knowledge/documents',
      );
      ApiService._assertSecureRequest(uploadUri);
      final request = http.MultipartRequest('POST', uploadUri);
      if (ApiService._accessToken != null) {
        request.headers['Authorization'] = 'Bearer ${ApiService._accessToken}';
      }
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        if (title != null && title.trim().isNotEmpty) 'Title': title.trim(),
        'Category': category,
        if (cropScope != null && cropScope.trim().isNotEmpty)
          'CropScope': cropScope.trim(),
        if (version != null && version.trim().isNotEmpty)
          'Version': version.trim(),
        if (authorOrganization != null && authorOrganization.trim().isNotEmpty)
          'AuthorOrganization': authorOrganization.trim(),
      });
      request.files.add(
        http.MultipartFile.fromBytes('File', bytes, filename: fileName),
      );
      final streamed = await ApiService._client
          .send(request)
          .timeout(const Duration(minutes: 3));
      return http.Response.fromStream(
        streamed,
      ).timeout(const Duration(minutes: 3));
    }

    var response = await send();
    if (response.statusCode == 401 && await ApiService.refreshToken()) {
      response = await send();
    }
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final id = (body['id'] ?? body['documentId'])?.toString();
    if (id == null || id.isEmpty) {
      throw Exception('Máy chủ không trả về ID tài liệu.');
    }
    return getAgricultureDocument(id);
  }

  static Future<Map<String, dynamic>> reviewAgricultureDocument({
    required String id,
    required String contentText,
    required bool approve,
    String? reviewNotes,
    // Chỉnh metadata sau khi đối chiếu file gốc; null = giữ giá trị hệ thống đã nhận diện.
    String? title,
    String? cropScope,
    String? authorOrganization,
    String? version,
    String? documentType,
    bool confirmGeneralScope = false,
  }) async {
    final response = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/ai/knowledge/documents/$id/review',
      {
        'contentText': contentText,
        'approve': approve,
        if (reviewNotes != null && reviewNotes.trim().isNotEmpty)
          'reviewNotes': reviewNotes.trim(),
        'title': ?title,
        'cropScope': ?cropScope,
        'authorOrganization': ?authorOrganization,
        'version': ?version,
        'documentType': ?documentType,
        if (confirmGeneralScope) 'confirmGeneralScope': true,
      },
      timeout: const Duration(seconds: 90),
    );
    if (response == null ||
        (response.statusCode != 200 && response.statusCode != 204)) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<List<int>> downloadAgricultureOriginalFile(String id) async {
    final response = await ApiService._getWithAuth(
      '${ApiService.baseUrl}/api/v1/ai/knowledge/documents/$id/file',
      timeout: const Duration(seconds: 90),
    );
    if (response == null || response.statusCode != 200) {
      throw Exception(ApiService._apiErrorMessage(response));
    }
    return response.bodyBytes;
  }
}
