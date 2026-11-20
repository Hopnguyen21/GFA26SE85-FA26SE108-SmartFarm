import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfarm_mobile/core/models/field_survey_report.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/core/services/api_service.dart';
import 'package:smartfarm_mobile/features/support/field_survey_logic.dart';
import 'package:smartfarm_mobile/features/support/field_survey_report_screen.dart';
import 'package:smartfarm_mobile/features/support/field_survey_reports_screen.dart';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _report({
  String id = 'r1',
  String status = 'Submitted',
  String createdBy = 'u1',
  String title = 'Báo cáo khảo sát Nhà màng 1',
}) => {
  'id': id,
  'farmId': 'f1',
  'farmName': 'Trang trại A',
  'serviceRequestId': 's1',
  'zoneId': 'z1',
  'zoneName': 'Zone 1',
  'title': title,
  'surveyDate': '2026-11-10T00:00:00Z',
  'location': 'Thôn 3, Đà Lạt',
  'surveyorName': 'KTV Một',
  'representativeName': 'Ông An',
  'farmOverview': 'Nhà màng 500 m²',
  'cropAndSeasonStatus': 'Cà chua giai đoạn cây con',
  'cultivationProcess': '',
  'environmentalMonitoring': '',
  'environmentalThresholdNeeds': '',
  'equipmentAndDataCollection': 'Có đường ống tưới nhỏ giọt',
  'managementAndPermissions': '',
  'difficultiesAndNeeds': 'Thiếu cảm biến độ ẩm đất',
  'teamAssessment': 'Đề xuất lắp 4 node',
  'status': status,
  'createdByUserId': createdBy,
  'createdByUserName': 'KTV Một',
  'createdAtUtc': '2026-11-10T01:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <http.Request>[];
  Future<http.Response> Function(http.Request) handler = (_) async =>
      http.Response('', 404);
  http.Response? existing;
  var postCode = 201;

  Future<http.Response> routes(http.Request r) async {
    calls.add(r);
    final p = r.url.path;
    if (r.method == 'GET' &&
        p.contains('/field-survey-reports/by-service-request/')) {
      return existing ?? http.Response('', 404);
    }
    if (r.method == 'GET' && p.endsWith('/field-survey-reports/r1')) {
      return existing ?? http.Response('', 404);
    }
    if (r.method == 'POST' && p.endsWith('/field-survey-reports')) {
      if (postCode != 201) return _json({'detail': 'Lỗi máy chủ'}, postCode);
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      return _json({
        ..._report(id: 'new1'),
        ...b,
        'farmName': 'Trang trại A',
      }, 201);
    }
    if (r.method == 'PUT' && p.contains('/field-survey-reports/')) {
      final b = jsonDecode(r.body) as Map<String, dynamic>;
      return _json({..._report(), ...b});
    }
    return handler(r);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.setTokens(
      accessToken: 't',
      refreshToken: 'r',
      email: 't@b.c',
      role: 'PlatformTechnician',
    );
    await http.runWithClient(
      () => FieldSurveyApi.list().catchError((_) => <FieldSurveyReport>[]),
      () => MockClient(routes),
    );
  });

  setUp(() {
    calls.clear();
    existing = null;
    postCode = 201;
    handler = (_) async => http.Response('', 404);
  });

  const target = FieldSurveyTarget(
    serviceRequestId: 's1abcdef1234',
    farmId: 'f1',
    farmName: 'Trang trại A',
    zoneId: 'z1',
    zoneName: 'Zone 1',
    requestCode: 's1abcdef',
  );

  Future<FieldSurveyOutcome?> open(
    WidgetTester t, {
    bool readOnly = false,
    bool requireFeasibility = false,
    String? reportId,
    FieldSurveyTarget? tgt = target,
  }) async {
    t.view.physicalSize = const Size(400, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    FieldSurveyOutcome? result;
    await t.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async =>
                  result = await Navigator.push<FieldSurveyOutcome>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FieldSurveyReportScreen(
                        reportId: reportId,
                        target: tgt,
                        readOnly: readOnly,
                        requireFeasibility: requireFeasibility,
                        currentUserName: 'KTV Một',
                      ),
                    ),
                  ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    return result;
  }

  group('logic', () {
    test('tiêu đề mặc định như web; thiếu mã/tên trang trại vẫn đọc được', () {
      expect(
        defaultFieldSurveyTitle(target),
        'Báo cáo khảo sát thực địa [s1abcdef] - Trang trại A',
      );
      expect(
        defaultFieldSurveyTitle(const FieldSurveyTarget(farmId: 'f')),
        'Báo cáo khảo sát thực địa - Trang trại',
      );
    });

    test(
      'surveyDigest: lấy từ báo cáo, không bịa; luôn có Notes và ≤ 2000 ký tự',
      () {
        final r = FieldSurveyReport.fromJson(_report());
        final d = surveyDigest(r, feasible: true);
        expect(d.siteConditions, contains('Thôn 3, Đà Lạt'));
        expect(d.siteConditions, contains('Có đường ống tưới nhỏ giọt'));
        expect(d.notes, 'Đề xuất lắp 4 node');
        final empty = FieldSurveyReport.fromJson({
          'id': 'x',
          'farmId': 'f',
          'title': 'T',
        });
        expect(
          surveyDigest(empty, feasible: false).notes,
          contains('Không khả thi'),
        );
        final big = FieldSurveyReport.fromJson({
          ..._report(),
          'teamAssessment': 'a' * 5000,
          'equipmentAndDataCollection': 'b' * 5000,
        });
        final bd = surveyDigest(big, feasible: true);
        expect(bd.notes.length, 2000);
        expect(bd.siteConditions.length, 2000);
      },
    );

    test(
      'payload: trim, đủ 9 mục, tạo mới mang farm/phiếu/zone, sửa thì không',
      () {
        final p = fieldSurveyPayload(
          farmId: 'f1',
          serviceRequestId: 's1',
          zoneId: 'z1',
          title: '  Tiêu đề ',
          surveyDate: DateTime(2026, 11, 10),
          location: ' Đà Lạt ',
          sections: {'farmOverview': '  Tổng quan  '},
          status: 'Draft',
        );
        expect(p['title'], 'Tiêu đề');
        expect(p['location'], 'Đà Lạt');
        expect(p['farmOverview'], 'Tổng quan');
        expect(p['teamAssessment'], '');
        expect(p['farmId'], 'f1');
        expect(p['surveyDate'], '2026-11-10T00:00:00.000Z');
        final upd = fieldSurveyPayload(
          title: 't',
          surveyDate: DateTime(2026, 11, 10),
          sections: const {},
          status: 'Submitted',
        );
        expect(upd.containsKey('farmId'), isFalse);
      },
    );
  });

  testWidgets(
    'báo cáo mới: điền sẵn tiêu đề/người khảo sát/trang trại; thiếu tiêu đề thì chặn',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        expect(find.text('Lập báo cáo khảo sát thực địa'), findsOneWidget);
        expect(find.text('Trang trại: Trang trại A'), findsOneWidget);
        expect(find.text('Phân khu: Zone 1'), findsOneWidget);
        expect(
          find.widgetWithText(
            TextField,
            'Báo cáo khảo sát thực địa [s1abcdef] - Trang trại A',
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(TextField, 'KTV Một'), findsOneWidget);
        // 9 mục nội dung như web
        for (var i = 2; i <= 10; i++) {
          expect(find.textContaining('Mục $i:'), findsOneWidget);
        }
        await t.enterText(find.byKey(const ValueKey('fs-title')), '   ');
        await t.tap(find.byKey(const ValueKey('fs-submit')));
        await t.pumpAndSettle();
        expect(find.textContaining('nhập tiêu đề'), findsOneWidget);
        expect(calls.where((c) => c.method == 'POST'), isEmpty);
      }, () => MockClient(routes));
    },
  );

  testWidgets(
    'lưu bản nháp: POST Draft và ở lại màn; nộp: Submitted và trả kết quả',
    (t) async {
      await http.runWithClient(() async {
        await open(t);
        await t.enterText(
          find.byKey(const ValueKey('fs-section-farmOverview')),
          '  Nhà màng 500 m²  ',
        );
        await t.tap(find.byKey(const ValueKey('fs-save-draft')));
        await t.pumpAndSettle();
        var posts = calls.where((c) => c.method == 'POST').toList();
        expect(posts, hasLength(1));
        var b = jsonDecode(posts.single.body) as Map;
        expect(b['status'], 'Draft');
        expect(b['farmOverview'], 'Nhà màng 500 m²');
        expect(b['serviceRequestId'], 's1abcdef1234');
        expect(b['zoneId'], 'z1');
        expect(find.byKey(const ValueKey('fs-notice')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('fs-submit')),
          findsOneWidget,
        ); // vẫn ở màn
        // nộp: cập nhật báo cáo vừa tạo (PUT), không tạo trùng
        await t.tap(find.byKey(const ValueKey('fs-submit')));
        await t.pumpAndSettle();
        expect(calls.where((c) => c.method == 'POST'), hasLength(1));
        final puts = calls.where((c) => c.method == 'PUT').toList();
        expect(puts, hasLength(1));
        expect((jsonDecode(puts.single.body) as Map)['status'], 'Submitted');
        expect(
          find.byKey(const ValueKey('fs-submit')),
          findsNothing,
        ); // đã đóng màn
      }, () => MockClient(routes));
    },
  );

  testWidgets(
    'trong luồng lắp đặt: nộp phải có kết luận khả thi/không khả thi và trả về đúng kết luận',
    (t) async {
      await http.runWithClient(() async {
        await t.pumpWidget(const SizedBox());
        t.view.physicalSize = const Size(400, 3000);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        FieldSurveyOutcome? out;
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async =>
                      out = await Navigator.push<FieldSurveyOutcome>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FieldSurveyReportScreen(
                            target: target,
                            requireFeasibility: true,
                          ),
                        ),
                      ),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('fs-submit')));
        await t.pumpAndSettle();
        expect(find.textContaining('Chọn kết luận khảo sát'), findsOneWidget);
        expect(calls.where((c) => c.method == 'POST'), isEmpty);
        await t.ensureVisible(find.byKey(const ValueKey('fs-infeasible')));
        await t.tap(find.byKey(const ValueKey('fs-infeasible')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('fs-submit')));
        await t.pumpAndSettle();
        expect(out, isNotNull);
        expect(out!.feasible, isFalse);
        expect(out!.report.status, 'Submitted');
      }, () => MockClient(routes));
    },
  );

  testWidgets(
    'đã có báo cáo của phiếu: nạp lại và sửa bằng PUT (không tạo mới)',
    (t) async {
      existing = _json(_report(status: 'Draft'));
      await http.runWithClient(() async {
        await open(t);
        expect(find.text('Báo cáo khảo sát thực địa'), findsWidgets);
        expect(find.text('Bản nháp'), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Báo cáo khảo sát Nhà màng 1'),
          findsOneWidget,
        );
        expect(find.text('Cập nhật & nộp'), findsOneWidget);
        await t.enterText(find.byKey(const ValueKey('fs-location')), 'Lô B');
        await t.tap(find.byKey(const ValueKey('fs-save-draft')));
        await t.pumpAndSettle();
        expect(calls.where((c) => c.method == 'POST'), isEmpty);
        final put = calls.firstWhere((c) => c.method == 'PUT');
        expect(put.url.path, endsWith('/field-survey-reports/r1'));
        final b = jsonDecode(put.body) as Map;
        expect(b['location'], 'Lô B');
        expect(b['status'], 'Draft');
        expect(b.containsKey('farmId'), isFalse);
      }, () => MockClient(routes));
    },
  );

  testWidgets(
    'chỉ xem (Owner/Farmer) và báo cáo đã duyệt: hiện nội dung, không có ô nhập hay nút lưu',
    (t) async {
      existing = _json(_report(status: 'Approved'));
      await http.runWithClient(() async {
        await open(t, readOnly: true, reportId: 'r1', tgt: null);
        expect(find.text('Đã duyệt'), findsOneWidget);
        expect(find.text('Nhà màng 500 m²'), findsOneWidget);
        expect(find.text('Đề xuất lắp 4 node'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(find.byKey(const ValueKey('fs-submit')), findsNothing);
        expect(find.byKey(const ValueKey('fs-save-draft')), findsNothing);
      }, () => MockClient(routes));
    },
  );

  testWidgets(
    'lưu lỗi từ máy chủ: giữ nội dung đã nhập và báo lý do, không đóng màn',
    (t) async {
      postCode = 500;
      await http.runWithClient(() async {
        await open(t);
        await t.enterText(
          find.byKey(const ValueKey('fs-section-farmOverview')),
          'Nội dung dài đã nhập',
        );
        await t.tap(find.byKey(const ValueKey('fs-save-draft')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('fs-error')), findsOneWidget);
        expect(find.textContaining('Không lưu được báo cáo'), findsOneWidget);
        expect(find.text('Nội dung dài đã nhập'), findsOneWidget);
      }, () => MockClient(routes));
    },
  );

  group('danh sách', () {
    FarmProvider provider(String role, String userId) {
      final p = FarmProvider();
      p.switchRole(role);
      p.setMeForTesting({'userId': userId, 'fullName': 'X', 'role': role});
      return p;
    }

    Future<void> pumpList(WidgetTester t, FarmProvider p) async {
      t.view.physicalSize = const Size(400, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        ChangeNotifierProvider<FarmProvider>.value(
          value: p,
          child: MaterialApp(
            key: UniqueKey(),
            home: const FieldSurveyReportsScreen(),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets(
      'KTV: thấy báo cáo, lọc theo trạng thái/tìm kiếm, xoá được báo cáo của mình',
      (t) async {
        var items = [
          _report(
            id: 'a',
            status: 'Draft',
            title: 'Báo cáo Nháp A',
            createdBy: 'u1',
          ),
          _report(
            id: 'b',
            status: 'Submitted',
            title: 'Báo cáo Nộp B',
            createdBy: 'u2',
          ),
        ];
        handler = (r) async {
          if (r.method == 'GET' &&
              r.url.path.endsWith('/field-survey-reports')) {
            return _json(items);
          }
          if (r.method == 'DELETE') {
            items = items
                .where((e) => !r.url.path.endsWith('/${e['id']}'))
                .toList();
            return http.Response('', 204);
          }
          return http.Response('', 404);
        };
        final p = provider('TECHNICIAN', 'u1');
        await http.runWithClient(() async {
          await pumpList(t, p);
          expect(find.text('Báo cáo Nháp A'), findsOneWidget);
          expect(find.text('Báo cáo Nộp B'), findsOneWidget);
          // chỉ báo cáo của mình có nút xoá
          expect(find.byKey(const ValueKey('fs-delete-a')), findsOneWidget);
          expect(find.byKey(const ValueKey('fs-delete-b')), findsNothing);
          await t.tap(find.byKey(const ValueKey('fs-filter-Draft')));
          await t.pumpAndSettle();
          expect(find.text('Báo cáo Nháp A'), findsOneWidget);
          expect(find.text('Báo cáo Nộp B'), findsNothing);
          await t.tap(find.byKey(const ValueKey('fs-filter-ALL')));
          await t.pumpAndSettle();
          await t.enterText(find.byKey(const ValueKey('fs-search')), 'nộp b');
          await t.pumpAndSettle();
          expect(find.text('Báo cáo Nháp A'), findsNothing);
          await t.enterText(find.byKey(const ValueKey('fs-search')), '');
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('fs-delete-a')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const ValueKey('fs-confirm-delete')));
          await t.pumpAndSettle();
          expect(find.text('Báo cáo Nháp A'), findsNothing);
          expect(calls.where((c) => c.method == 'DELETE'), hasLength(1));
        }, () => MockClient(routes));
        p.dispose();
      },
    );

    testWidgets(
      'Owner: chỉ xem, không có nút xoá; danh sách rỗng và lỗi tải đều báo rõ',
      (t) async {
        handler = (r) async => _json([_report(id: 'a', title: 'Báo cáo A')]);
        final p = provider('OWNER', 'o1');
        await http.runWithClient(() async {
          await pumpList(t, p);
          expect(find.text('Báo cáo A'), findsOneWidget);
          expect(find.byKey(const ValueKey('fs-delete-a')), findsNothing);
          handler = (r) async => _json(<Object>[]);
          await t.tap(find.byIcon(Icons.refresh));
          await t.pumpAndSettle();
          expect(
            find.text('Chưa có báo cáo khảo sát thực địa nào.'),
            findsOneWidget,
          );
        }, () => MockClient(routes));
        p.dispose();
        final p2 = provider('FARMER', 'f1');
        handler = (r) async => http.Response('boom', 500);
        await http.runWithClient(() async {
          await pumpList(t, p2);
          expect(
            find.textContaining('Không tải được danh sách'),
            findsOneWidget,
          );
        }, () => MockClient(routes));
        p2.dispose();
      },
    );
  });
}
