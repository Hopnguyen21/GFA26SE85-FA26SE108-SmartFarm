import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartfarm_mobile/features/farms/farm_setup_logic.dart';

Map<String, dynamic> _profile() => {
  'profileId': 'p1',
  'stages': [
    {
      'stageOrder': 2,
      'name': 'Sinh trưởng',
      'durationDays': 25,
      'requirements': [
        {'parameterCode': 'Ph'},
      ],
    },
    {
      'stageOrder': 1,
      'name': 'Cây con',
      'durationDays': 14,
      'requirements': [
        {'parameterCode': 'SoilMoisture'},
        {'parameterCode': 1},
        {'parameterCode': 'Temperature'},
        {'parameterCode': 'Bogus'},
      ],
    },
  ],
};

void main() {
  test(
    'tổng ngày = cộng các giai đoạn; hồ sơ không khai báo ngày thì null',
    () {
      expect(profileTotalDays(_profile()), 39);
      expect(profileTotalDays({'stages': []}), isNull);
      expect(
        profileTotalDays({
          'stages': [
            {'name': 'x'},
          ],
        }),
        isNull,
      );
      expect(profileTotalDays(null), isNull);
    },
  );

  test(
    'ngày thu hoạch = bắt đầu + tổng ngày của hồ sơ (không dùng 90 ngày mặc định của backend)',
    () {
      expect(
        expectedEndFromProfile(DateTime(2026, 10, 1, 13), 90),
        DateTime(2026, 12, 30),
      );
      expect(
        expectedEndFromProfile(DateTime(2026, 10, 1), 39),
        DateTime(2026, 11, 9),
      );
    },
  );

  test(
    'thông số cần đo lấy từ giai đoạn đầu của hồ sơ, đọc được cả mã số; bỏ mã lạ; không bịa mặc định',
    () {
      expect(profileRequiredParameters(_profile()), [
        'Temperature',
        'SoilMoisture',
      ]);
      expect(
        profileRequiredParameters({
          'stages': [
            {'stageOrder': 1, 'requirements': []},
          ],
        }),
        isEmpty,
      );
      expect(profileRequiredParameters(null), isEmpty);
    },
  );

  test('tên vụ gợi ý theo cây và thời điểm', () {
    expect(
      suggestedSeasonName('Cà chua Beefsteak (Tomato)', DateTime(2026, 11, 1)),
      'Vụ Cà chua Beefsteak Đông Xuân 2026',
    );
    expect(
      suggestedSeasonName('Ớt', DateTime(2026, 5, 1)),
      'Vụ Ớt Hè Thu 2026',
    );
  });

  test(
    'bước vụ mùa: bắt buộc tên, cây, hồ sơ có giai đoạn, ngày thu hoạch sau ngày bắt đầu',
    () {
      String? v({
        String name = 'Vụ',
        String? crop = 'c',
        String? profile = 'p',
        int? stages = 3,
        DateTime? end,
      }) => validateSeasonStep(
        enabled: true,
        name: name,
        cropId: crop,
        profileId: profile,
        profileStageCount: stages,
        start: DateTime(2026, 10, 1),
        expectedEnd: end,
      );
      final ok = DateTime(2027, 1, 1);
      expect(v(end: ok), isNull);
      expect(v(name: ' ', end: ok), contains('tên vụ'));
      expect(v(crop: null, end: ok), contains('cây'));
      expect(v(profile: null, end: ok), contains('hồ sơ'));
      expect(v(stages: 0, end: ok), contains('giai đoạn'));
      expect(v(end: null), contains('ngày thu hoạch'));
      expect(v(end: DateTime(2026, 10, 1)), contains('sau ngày bắt đầu'));
    },
  );

  test(
    'lỗi mạng/timeout là mơ hồ (có thể đã tạo); lỗi do máy chủ từ chối thì không',
    () {
      expect(
        classifyWizardFailure(TimeoutException('t')),
        WizardFailureKind.ambiguousNetwork,
      );
      expect(
        classifyWizardFailure(const SocketException('x')),
        WizardFailureKind.ambiguousNetwork,
      );
      expect(
        classifyWizardFailure(http.ClientException('x')),
        WizardFailureKind.ambiguousNetwork,
      );
      expect(
        classifyWizardFailure(Exception('Tài khoản của bạn không có quyền')),
        WizardFailureKind.rejected,
      );
    },
  );

  test(
    'ghi chú IoT gắn nhãn ước tính, không nói là kế hoạch thiết bị; có giới hạn 1000 ký tự',
    () {
      final n = buildWizardIotNotes(
        userNotes: ' Gần cổng ',
        gateways: 1,
        sensors: 4,
        actuators: 3,
        totalVnd: 10400000,
      );
      expect(n, startsWith('Gần cổng\n'));
      expect(n, contains('Dự toán tham khảo'));
      expect(n, contains('chưa phải kế hoạch thiết bị chính thức'));
      expect(n, contains('1 gateway, 4 node cảm biến, 3 node van/bơm'));
      expect(buildWizardIotNotes(userNotes: ''), isEmpty);
      expect(buildWizardIotNotes(userNotes: 'x' * 2000).length, 1000);
    },
  );
}
