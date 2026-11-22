part of '../api_service.dart';

/// Dịch vụ tải lên hình ảnh và tệp tin đa phương tiện lên Cloudinary CDN (`/api/v1/media`).
abstract final class MediaApi {
  /// Tải lên tệp hình ảnh/tài liệu từ mảng bytes hoặc file.
  /// [fileName]: tên tệp (ví dụ 'avatar.jpg', 'farm_cover.png', 'task_proof.jpg')
  /// [bytes]: dữ liệu nhị phân của tệp (tối đa 20MB)
  /// [folder]: thư mục Cloudinary lưu trữ (ví dụ 'farms', 'tasks', 'surveys', 'avatars')
  /// [contentType]: định dạng MIME (ví dụ 'image/jpeg', 'image/png')
  static Future<CloudinaryUploadResult> uploadFile({
    required String fileName,
    required List<int> bytes,
    String? folder,
    String? contentType,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Tệp tin rỗng.');
    }
    if (bytes.length > 20 * 1024 * 1024) {
      throw Exception('Dung lượng tệp vượt quá giới hạn cho phép (20 MB).');
    }

    Future<http.Response> send() async {
      final uploadUri = Uri.parse('${ApiService.baseUrl}/api/v1/media/upload');
      ApiService._assertSecureRequest(uploadUri);
      final request = http.MultipartRequest('POST', uploadUri);
      if (ApiService._accessToken != null) {
        request.headers['Authorization'] = 'Bearer ${ApiService._accessToken}';
      }
      request.headers['Accept'] = 'application/json';
      if (folder != null && folder.trim().isNotEmpty) {
        request.fields['Folder'] = folder.trim();
      }

      final multipartFile = http.MultipartFile.fromBytes(
        'File',
        bytes,
        filename: fileName,
      );
      request.files.add(multipartFile);

      final streamed = await ApiService._client
          .send(request)
          .timeout(const Duration(minutes: 2));
      return http.Response.fromStream(streamed)
          .timeout(const Duration(minutes: 2));
    }

    var response = await send();
    if (response.statusCode == 401 && await ApiService.refreshToken()) {
      response = await send();
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(ApiService._apiErrorMessage(response));
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return CloudinaryUploadResult.fromJson(data);
  }

  /// Tải lên hình ảnh dạng chuỗi Base64
  static Future<CloudinaryUploadResult> uploadBase64({
    required String base64Data,
    String? fileName,
    String? folder,
  }) async {
    if (base64Data.trim().isEmpty) {
      throw Exception('Dữ liệu ảnh rỗng.');
    }

    final response = await ApiService._postWithAuth(
      '${ApiService.baseUrl}/api/v1/media/upload-base64',
      {
        'base64Data': base64Data,
        if (fileName != null && fileName.trim().isNotEmpty)
          'fileName': fileName.trim(),
        if (folder != null && folder.trim().isNotEmpty)
          'folder': folder.trim(),
      },
      timeout: const Duration(minutes: 2),
    );

    if (response == null || (response.statusCode != 200 && response.statusCode != 201)) {
      throw Exception(ApiService._apiErrorMessage(response));
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return CloudinaryUploadResult.fromJson(data);
  }
}
