class AgricultureDocumentModel {
  final String id;
  final String title;
  final String? fileName;
  final String fileType;
  final String? authorOrganization;
  final String category;
  final String cropScope;
  final String? version;
  final int chunkCount;
  final String reviewStatus;
  final String? reviewNotes;
  final String? contentText;
  final bool hasOriginalFile;
  final String documentType;

  /// Kết quả hệ thống nhận diện từ nội dung (giá trị, trạng thái detected/uncertain/not_found, bằng chứng).
  final Map<String, dynamic>? metadataDetection;

  /// Kết quả AI rà soát đối chiếu nguồn quy chuẩn đã xác minh (null khi chưa có kết quả).
  final Map<String, dynamic>? verification;

  /// Pending, Consistent, PotentialIssue, UnableToVerify, VerificationError hoặc null (tài liệu cũ).
  final String? verificationStatus;

  const AgricultureDocumentModel({
    required this.id,
    required this.title,
    this.fileName,
    required this.fileType,
    this.authorOrganization,
    required this.category,
    required this.cropScope,
    this.version,
    required this.chunkCount,
    required this.reviewStatus,
    this.reviewNotes,
    this.contentText,
    required this.hasOriginalFile,
    this.documentType = 'Unspecified',
    this.metadataDetection,
    this.verification,
    this.verificationStatus,
  });

  factory AgricultureDocumentModel.fromJson(Map<String, dynamic> json) =>
      AgricultureDocumentModel(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Tài liệu VietGAP',
        fileName: json['fileName']?.toString(),
        fileType: json['fileType']?.toString() ?? 'text',
        authorOrganization: json['authorOrganization']?.toString(),
        category: json['category']?.toString() ?? 'general',
        cropScope: json['cropScope']?.toString() ?? '',
        version: json['version']?.toString(),
        chunkCount: (json['chunkCount'] as num?)?.toInt() ?? 0,
        reviewStatus: json['reviewStatus']?.toString() ?? 'PendingReview',
        reviewNotes: json['reviewNotes']?.toString(),
        contentText: json['contentText']?.toString(),
        hasOriginalFile: json['hasOriginalFile'] == true,
        documentType: json['documentType']?.toString() ?? 'Unspecified',
        metadataDetection: json['metadataDetection'] is Map<String, dynamic>
            ? json['metadataDetection'] as Map<String, dynamic>
            : null,
        verification: json['verification'] is Map<String, dynamic>
            ? json['verification'] as Map<String, dynamic>
            : null,
        verificationStatus: json['verificationStatus']?.toString(),
      );

  AgricultureDocumentModel copyWith({
    String? reviewStatus,
    String? reviewNotes,
    String? contentText,
    int? chunkCount,
  }) => AgricultureDocumentModel(
    id: id,
    title: title,
    fileName: fileName,
    fileType: fileType,
    authorOrganization: authorOrganization,
    category: category,
    cropScope: cropScope,
    version: version,
    chunkCount: chunkCount ?? this.chunkCount,
    reviewStatus: reviewStatus ?? this.reviewStatus,
    reviewNotes: reviewNotes ?? this.reviewNotes,
    contentText: contentText ?? this.contentText,
    hasOriginalFile: hasOriginalFile,
    documentType: documentType,
    metadataDetection: metadataDetection,
    verification: verification,
    verificationStatus: verificationStatus,
  );

  String get statusLabel => switch (reviewStatus) {
    'Approved' => 'Đã đối chiếu & duyệt',
    'NeedsCorrection' => 'Cần chỉnh sửa',
    _ => 'Chờ đối chiếu',
  };
}
