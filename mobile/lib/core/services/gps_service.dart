import 'package:geolocator/geolocator.dart';

/// Một lần đọc GPS: toạ độ và độ chính xác ước tính (mét, càng nhỏ càng tốt).
class GpsFix {
  final double latitude;
  final double longitude;
  final double accuracyM;
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
  });
}

enum GpsFailure {
  /// Dịch vụ vị trí của thiết bị đang tắt.
  serviceDisabled,

  /// Người dùng từ chối quyền vị trí (có thể xin lại).
  denied,

  /// Người dùng từ chối vĩnh viễn: phải mở cài đặt hệ thống.
  deniedForever,

  /// Không có tín hiệu trong thời gian cho phép.
  timeout,
  unknown,
}

class GpsException implements Exception {
  final GpsFailure failure;
  final String message;
  const GpsException(this.failure, this.message);
  @override
  String toString() => message;
}

/// Nguồn GPS dùng cho Chấm Node; tách thành giao diện để kiểm thử mà không cần cảm biến thật.
abstract class GpsProvider {
  /// Đọc vị trí hiện tại; ném [GpsException] khi không đọc được (không bao giờ trả toạ độ giả).
  Future<GpsFix> current();
}

class GeolocatorGpsProvider implements GpsProvider {
  const GeolocatorGpsProvider();

  @override
  Future<GpsFix> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const GpsException(
          GpsFailure.serviceDisabled,
          'Dịch vụ vị trí đang tắt. Hãy bật GPS trên thiết bị rồi thử lại.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const GpsException(
          GpsFailure.denied,
          'Chưa được cấp quyền vị trí. Hãy cho phép ứng dụng dùng vị trí để lấy điểm Node.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const GpsException(
          GpsFailure.deniedForever,
          'Quyền vị trí bị từ chối vĩnh viễn. Hãy bật lại trong Cài đặt của thiết bị.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GpsFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracyM: p.accuracy,
      );
    } on GpsException {
      rethrow;
    } on Exception catch (e) {
      final text = '$e';
      if (text.contains('TimeoutException')) {
        throw const GpsException(
          GpsFailure.timeout,
          'Không nhận được tín hiệu GPS trong 20 giây. Ra chỗ thoáng rồi thử lại.',
        );
      }
      throw GpsException(GpsFailure.unknown, 'Không đọc được GPS: $text');
    }
  }
}
