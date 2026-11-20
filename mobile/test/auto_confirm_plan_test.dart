import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

/// KTV gửi hợp đồng = xác nhận kế hoạch: chỉ khi khảo sát thực địa đã có kết quả khả thi; app không tự bịa khảo sát.
void main() {
  var status = 'Submitted';
  final posts = <String>[];

  Map<String, dynamic> dep() => {
    'requestId': 'dep-0001',
    'status': status,
    'surveys': (status == 'Submitted' || status == 'Accepted')
        ? []
        : [
            {'isFeasible': true},
          ],
  };

  http.Client mock() => MockClient((req) async {
    if (req.method == 'POST') {
      final step = req.url.path.split('/').last;
      posts.add(step);
      status = switch (step) {
        'accept' => 'Accepted',
        'survey' => 'Surveyed',
        'confirm' => 'PlanConfirmed',
        _ => status,
      };
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(dep())),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  // Client giả được giữ toàn cục cho cả file sau lần gọi đầu, nên dùng một handler đọc trạng thái dùng chung.
  setUpAll(() async {
    await http.runWithClient(
      () => DeploymentApi.getDeploymentRequest('dep-0001', technician: true),
      mock,
    );
  });

  Future<String> run(String start) async {
    status = start;
    posts.clear();
    return (await DeploymentApi.autoConfirmPlan('dep-0001')).status;
  }

  test(
    'chưa khảo sát (Submitted/Accepted): KHÔNG tự bịa khảo sát, báo cần khảo sát',
    () async {
      for (final st in ['Submitted', 'Accepted']) {
        await expectLater(
          run(st),
          throwsA(predicate((e) => '$e'.contains('khảo sát thực địa'))),
          reason: st,
        );
        expect(
          posts,
          isEmpty,
          reason: 'không gọi accept/survey/confirm khi $st',
        );
      }
    },
  );

  test('từ Surveyed: chỉ xác nhận kế hoạch', () async {
    expect(await run('Surveyed'), 'PlanConfirmed');
    expect(posts, ['confirm']);
  });

  test('đã xác nhận kế hoạch rồi: không gọi gì thêm', () async {
    expect(await run('PlanConfirmed'), 'PlanConfirmed');
    expect(posts, isEmpty);
  });
}
