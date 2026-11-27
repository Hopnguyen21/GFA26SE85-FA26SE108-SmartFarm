import 'dart:typed_data';
import 'dart:ui' as ui;

/// Tiện ích tối ưu và nén kích thước ảnh (Image Optimization) trước khi upload lên máy chủ.
/// Sử dụng trực tiếp bộ giải mã `instantiateImageCodec` native của Flutter engine để
/// giảm chiều dài/rộng ảnh camera (thường 4000x3000px) về chuẩn HD/FullHD (tối đa 1920px),
/// giúp tiết kiệm băng thông 4G vùng nông thôn và tăng tốc upload gấp 5-10 lần.
///
/// Lưu ý: engine chỉ mã hoá lại được sang PNG. Khi trả về bytes mới (khác `rawBytes`) thì dữ liệu là PNG,
/// nên phải đổi tên tệp bằng [uploadFileName] để đuôi tệp khớp nội dung.
class ImageCompressUtil {
  ImageCompressUtil._();

  /// Tên tệp khớp với dữ liệu sẽ gửi: giữ nguyên nếu không nén lại, đổi đuôi sang `.png` nếu đã mã hoá lại.
  static String uploadFileName(
    String originalName,
    Uint8List rawBytes,
    Uint8List optimizedBytes,
  ) {
    if (identical(rawBytes, optimizedBytes)) return originalName;
    final dot = originalName.lastIndexOf('.');
    final base = dot > 0 ? originalName.substring(0, dot) : originalName;
    return '$base.png';
  }

  static Future<Uint8List> optimizeForUpload(
    Uint8List rawBytes, {
    int maxDimension = 1920,
    int sizeThresholdBytes = 600 * 1024, // 600KB
  }) async {
    // Nếu ảnh đã nhỏ hơn 600KB, giữ nguyên không cần nén lại
    if (rawBytes.lengthInBytes <= sizeThresholdBytes) {
      return rawBytes;
    }

    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;

      // Nếu kích thước đã nhỏ hơn maxDimension, không cần hạ độ phân giải
      if (width <= maxDimension && height <= maxDimension) {
        return rawBytes;
      }

      int targetW = width;
      int targetH = height;
      if (width > height) {
        targetW = maxDimension;
        targetH = (height * maxDimension / width).round();
      } else {
        targetH = maxDimension;
        targetW = (width * maxDimension / height).round();
      }

      final resizedCodec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final byteData = await resizedFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final compressedBytes = byteData.buffer.asUint8List();
        // Nếu ảnh nén nhỏ hơn ảnh gốc thì dùng ảnh nén
        if (compressedBytes.lengthInBytes < rawBytes.lengthInBytes) {
          return compressedBytes;
        }
      }
      return rawBytes;
    } catch (_) {
      // Khi gặp định dạng lạ hoặc lỗi giải mã, fallback an toàn về bytes gốc
      return rawBytes;
    }
  }
}
