/// Kết quả tải lên hình ảnh / tài liệu lên Cloudinary CDN (`/api/v1/media/upload`).
class CloudinaryUploadResult {
  final String publicId;
  final String url;
  final String secureUrl;
  final String format;
  final int width;
  final int height;
  final int bytes;
  final String resourceType;
  final DateTime? createdAtUtc;

  const CloudinaryUploadResult({
    required this.publicId,
    required this.url,
    required this.secureUrl,
    this.format = '',
    this.width = 0,
    this.height = 0,
    this.bytes = 0,
    this.resourceType = 'image',
    this.createdAtUtc,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) {
    return CloudinaryUploadResult(
      publicId: '${json['publicId'] ?? ''}',
      url: '${json['url'] ?? ''}',
      secureUrl: '${json['secureUrl'] ?? json['url'] ?? ''}',
      format: '${json['format'] ?? ''}',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      resourceType: '${json['resourceType'] ?? 'image'}',
      createdAtUtc: json['createdAtUtc'] != null
          ? DateTime.tryParse('${json['createdAtUtc']}')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'publicId': publicId,
    'url': url,
    'secureUrl': secureUrl,
    'format': format,
    'width': width,
    'height': height,
    'bytes': bytes,
    'resourceType': resourceType,
    if (createdAtUtc != null) 'createdAtUtc': createdAtUtc!.toIso8601String(),
  };

  @override
  String toString() =>
      'CloudinaryUploadResult(publicId: $publicId, secureUrl: $secureUrl, bytes: $bytes)';
}
