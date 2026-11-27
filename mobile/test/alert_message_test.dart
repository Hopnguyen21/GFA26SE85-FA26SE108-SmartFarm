import 'package:flutter_test/flutter_test.dart';
import 'package:smartfarm_mobile/core/models/models.dart';

void main() {
  test(
    'cảnh báo vi khí hậu không có message: nêu thông số, giá trị và ngưỡng',
    () {
      final a = AlertModel.fromJson({
        'alertId': 'a1',
        'parameterCode': 'AirHumidity',
        'observedValue': 65.1000,
        'minThreshold': 70.0000,
        'maxThreshold': 80.0000,
        'unit': '%',
        'severity': 'Warning',
      });
      expect(a.message, 'Độ ẩm không khí: 65,1 % (ngưỡng 70–80 %)');
    },
  );

  test(
    'thiếu ngưỡng hoặc thông số lạ: vẫn là câu đọc được, không in "null"',
    () {
      final a = AlertModel.fromJson({
        'alertId': 'a2',
        'parameterCode': 'Temperature',
        'observedValue': 28.7,
        'unit': '°C',
      });
      expect(a.message, 'Nhiệt độ: 28,7 °C (ngoài ngưỡng tối ưu)');
      final b = AlertModel.fromJson({'alertId': 'a3', 'observedValue': 5});
      expect(b.message, isNot(contains('null')));
    },
  );

  test('backend có message riêng thì giữ nguyên', () {
    final a = AlertModel.fromJson({
      'alertId': 'a4',
      'message': 'Thiết bị mất kết nối',
    });
    expect(a.message, 'Thiết bị mất kết nối');
  });

  test(
    'cleanTrailingZeros loại bỏ đúng các số 0 thừa trong chuỗi thông báo cảnh báo',
    () {
      const raw =
          'Độ ẩm không khí ghi nhận mức 65.1% (vượt ngưỡng cho phép 70.000 - 80.000%). Vui lòng kiểm tra hệ thống điều hòa & tưới tiêu.';
      final cleaned = cleanTrailingZeros(raw);
      expect(
        cleaned,
        'Độ ẩm không khí ghi nhận mức 65.1% (vượt ngưỡng cho phép 70 - 80%). Vui lòng kiểm tra hệ thống điều hòa & tưới tiêu.',
      );

      expect(cleanTrailingZeros('65.100%'), '65.1%');
      expect(cleanTrailingZeros('70.000'), '70');
      expect(cleanTrailingZeros('80.00'), '80');
      expect(cleanTrailingZeros('1000'), '1000');
      expect(cleanTrailingZeros('25.500 °C'), '25.5 °C');

      final alert = AlertModel.fromJson({
        'alertId': 'a5',
        'title': 'Cảnh báo 70.000',
        'message': raw,
      });
      expect(alert.message, cleaned);

      final notif = AppNotificationModel.fromJson({
        'notificationId': 'n1',
        'title': 'Cảnh báo tại Nhà Cà Chua',
        'message': raw,
      });
      expect(notif.message, cleaned);
    },
  );
}
