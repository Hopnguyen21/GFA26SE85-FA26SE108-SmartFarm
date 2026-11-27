import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';

// Thao tác thông báo là cập nhật lạc quan: nếu backend từ chối, danh sách phải được tải lại
// (trước đây thông báo biến mất trên máy dù máy chủ vẫn giữ, vì kết quả API bị bỏ qua).
Future<http.Response> Function(http.Request) handler = (_) async =>
    http.Response('[]', 200);
final calls = <http.Request>[];

http.Response json(Object o, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(o)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _n(String id, {bool read = false}) => {
  'notificationId': id,
  'title': 'Thông báo $id',
  'message': 'Nội dung $id',
  'type': 'ServiceRequest',
  'severity': 'Info',
  'isRead': read,
  'createdAtUtc': DateTime.utc(2026, 11, 20).toIso8601String(),
};

int _gets() => calls
    .where((c) => c.method == 'GET' && c.url.path == '/api/v1/notifications')
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await http.runWithClient(
      () => SupportApi.getServiceRequests().catchError(
        (_) => <Map<String, dynamic>>[],
      ),
      () => MockClient((r) async {
        calls.add(r);
        return handler(r);
      }),
    );
  });

  setUp(() {
    calls.clear();
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 'o@b.c',
      role: 'FarmOwner',
    );
  });

  Future<FarmProvider> loaded({required bool deleteFails}) async {
    handler = (r) async {
      if (r.method == 'GET' && r.url.path == '/api/v1/notifications') {
        return json([_n('a'), _n('b', read: true), _n('c', read: true)]);
      }
      if (r.method == 'DELETE' && r.url.path == '/api/v1/notifications/read') {
        return deleteFails
            ? json({'message': 'lỗi'}, 500)
            : json({'deletedCount': 2});
      }
      return json({}, 404);
    };
    final p = FarmProvider();
    await p.fetchNotifications();
    expect(p.notifications.length, 3);
    calls.clear();
    return p;
  }

  test(
    'xóa thông báo đã đọc thất bại → tải lại, không mất thông báo trên máy',
    () async {
      final p = await loaded(deleteFails: true);
      await p.deleteAllReadNotifications();
      expect(
        calls.any(
          (c) =>
              c.method == 'DELETE' &&
              c.url.path == '/api/v1/notifications/read',
        ),
        isTrue,
      );
      expect(
        _gets(),
        1,
        reason: 'phải tải lại danh sách sau khi backend từ chối',
      );
      expect(p.notifications.length, 3);
    },
  );

  test('xóa thông báo đã đọc thành công → không tải lại thừa', () async {
    final p = await loaded(deleteFails: false);
    await p.deleteAllReadNotifications();
    expect(_gets(), 0);
    expect(p.notifications.map((n) => n.notificationId), ['a']);
  });
}
