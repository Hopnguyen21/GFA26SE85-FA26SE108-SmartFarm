import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartfarm_mobile/core/models/models.dart';
import 'package:smartfarm_mobile/core/providers/farm_provider.dart';
import 'package:smartfarm_mobile/features/farmer/farmer_dashboard_screen.dart';
import 'package:smartfarm_mobile/features/tasks/widgets/task_actions.dart';

ZoneModel _zone(String id, String name) => ZoneModel(
  zoneId: id,
  farmId: 'farm1',
  name: name,
  currentCrop: 'Dưa lưới',
  currentStage: 'Phát triển thân lá',
  areaM2: 800,
  currentSoilMoisture: 65,
  currentTemp: 27,
  currentHumidity: 72,
  currentLux: 600,
  telemetryIsFresh: true,
);

TaskModel _createTask({
  required String id,
  required String status,
  String title = 'Kiểm tra hệ thống tưới',
  String? requirements,
  String? description,
  int progressPercent = 0,
  String? progressNote,
  String? result,
  String? failureReason,
  DateTime? dueAtUtc,
}) {
  return TaskModel(
    taskId: id,
    title: title,
    zoneName: 'Khu A - Nhà màng 1',
    priority: 'Cao',
    dueDate: '20/11/2026',
    status: status,
    description: description,
    requirements: requirements,
    dueAtUtc: dueAtUtc ?? DateTime.now().add(const Duration(days: 2)),
    assignments: [
      TaskAssignmentModel(
        farmerId: 'farmer1',
        farmerName: 'Nguyễn Văn Nông',
        status: status,
        progressPercent: progressPercent,
        progressNote: progressNote,
        result: result,
        failureReason: failureReason,
      ),
    ],
  );
}

FarmProvider _setupProvider({required String role}) {
  final provider = FarmProvider();
  provider.switchRole(role);
  provider.setSelectedFarmIdForTesting('farm1');
  provider.setMeForTesting({
    'userId': 'farmer1',
    'fullName': 'Nguyễn Văn Nông',
    'role': role == 'OWNER' ? 'FarmOwner' : 'Farmer',
    'zoneAccess': [
      {'zoneId': 'z1', 'canControl': true},
    ],
  });
  provider.setZonesForTesting([_zone('z1', 'Khu A - Nhà màng 1')]);
  return provider;
}

Future<void> _pumpFarmerDashboard(
  WidgetTester tester,
  FarmProvider provider,
) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<FarmProvider>.value(
      value: provider,
      child: const MaterialApp(home: FarmerDashboardScreen()),
    ),
  );
  await tester.pump();
}

Future<void> _pumpTaskActions(
  WidgetTester tester,
  FarmProvider provider,
  TaskModel task, {
  required bool isOwner,
}) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ChangeNotifierProvider<FarmProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: TaskActions(task: task, isOwner: isOwner),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('TaskModel & TaskAssignmentModel JSON Deserialization', () {
    test(
      'Parse đầy đủ các trường mới: requirements, progressNote, failureReason',
      () {
        final json = {
          'id': 't100',
          'title': 'Cắt tỉa cành thừa',
          'description': 'Tỉa nhánh phụ phía dưới gốc',
          'requirements': 'Dùng kéo vô trùng, đeo găng tay',
          'status': 'InProgress',
          'dueAtUtc': '2026-11-25T17:00:00Z',
          'assignments': [
            {
              'farmerId': 'f101',
              'farmerName': 'Trần Văn B',
              'status': 'InProgress',
              'progressPercent': 45,
              'progressNote': 'Đã tỉa xong 4 luống đầu',
              'result': null,
              'failureReason': null,
            },
            {
              'farmerId': 'f102',
              'farmerName': 'Lê Văn C',
              'status': 'Declined',
              'progressPercent': 0,
              'progressNote': null,
              'result': null,
              'failureReason': 'Trùng ca thu hoạch nhà màng 2',
            },
          ],
        };

        final task = TaskModel.fromJson(json);

        expect(task.taskId, 't100');
        expect(task.title, 'Cắt tỉa cành thừa');
        expect(task.description, 'Tỉa nhánh phụ phía dưới gốc');
        expect(task.requirements, 'Dùng kéo vô trùng, đeo găng tay');
        expect(task.status, 'InProgress');
        expect(task.assignments.length, 2);

        final a1 = task.assignments[0];
        expect(a1.farmerId, 'f101');
        expect(a1.farmerName, 'Trần Văn B');
        expect(a1.status, 'InProgress');
        expect(a1.progressPercent, 45);
        expect(a1.progressNote, 'Đã tỉa xong 4 luống đầu');
        expect(a1.result, isNull);
        expect(a1.failureReason, isNull);

        final a2 = task.assignments[1];
        expect(a2.farmerId, 'f102');
        expect(a2.farmerName, 'Lê Văn C');
        expect(a2.status, 'Declined');
        expect(a2.progressPercent, 0);
        expect(a2.failureReason, 'Trùng ca thu hoạch nhà màng 2');
      },
    );

    test('Xử lý an toàn khi các trường mới bị null hoặc khuyết', () {
      final json = {
        'id': 't101',
        'title': 'Tưới phân NPK đợt 1',
        'status': 'Pending',
        'assignments': [
          {'farmerId': 'f103', 'farmerName': 'Phạm D', 'status': 'Pending'},
        ],
      };

      final task = TaskModel.fromJson(json);
      expect(task.requirements, isNull);
      expect(task.assignments.single.progressNote, isNull);
      expect(task.assignments.single.result, isNull);
      expect(task.assignments.single.failureReason, isNull);
      expect(task.assignments.single.progressPercent, 0);
    });
  });

  group('Farmer Dashboard Task Display & Web Parity', () {
    testWidgets('Hiển thị yêu cầu kỹ thuật, tiến độ %, ghi chú và kết quả nộp', (
      tester,
    ) async {
      final provider = _setupProvider(role: 'FARMER');
      final task = _createTask(
        id: 't_review',
        status: 'CompletedPendingReview',
        title: 'Buộc giàn và kiểm tra bọ trĩ',
        requirements: 'Kiểm tra mặt dưới lá bánh tẻ',
        progressPercent: 100,
        progressNote: 'Đã hoàn tất toàn bộ khu vực',
        result: 'Đã buộc 20 hàng cây thẳng đứng, không phát hiện bọ trĩ.',
      );
      provider.tasks.add(task);

      await _pumpFarmerDashboard(tester, provider);

      // Chuyển sang tab "Chờ duyệt"
      await tester.tap(find.text('Chờ duyệt (1)'));
      await tester.pump();

      // Kiểm tra tiêu đề và nhãn trạng thái
      expect(find.text('Buộc giàn và kiểm tra bọ trĩ'), findsOneWidget);
      expect(find.text('Đã nộp, chờ chủ trang trại duyệt'), findsOneWidget);

      // Kiểm tra ô yêu cầu kỹ thuật
      expect(
        find.text('Yêu cầu: Kiểm tra mặt dưới lá bánh tẻ'),
        findsOneWidget,
      );

      // Kiểm tra thanh tiến độ 100%
      expect(find.text('100%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Kiểm tra ghi chú tiến độ
      expect(
        find.text('Ghi chú tiến độ: Đã hoàn tất toàn bộ khu vực'),
        findsOneWidget,
      );

      // Kiểm tra kết quả đã nộp
      expect(
        find.text(
          'Kết quả đã nộp: Đã buộc 20 hàng cây thẳng đứng, không phát hiện bọ trĩ.',
        ),
        findsOneWidget,
      );

      provider.dispose();
    });

    testWidgets('Hiển thị lý do từ chối hoặc thất bại khi có failureReason', (
      tester,
    ) async {
      final provider = _setupProvider(role: 'FARMER');
      final taskFailed = _createTask(
        id: 't_failed',
        status: 'Failed',
        title: 'Phun thuốc phòng nấm phấn trắng',
        failureReason: 'Trời mưa to đột xuất, nước ngập lối đi',
      );
      provider.tasks.add(taskFailed);

      await _pumpFarmerDashboard(tester, provider);

      // Mặc định ở tab "Cần làm"
      expect(find.text('Phun thuốc phòng nấm phấn trắng'), findsOneWidget);
      expect(find.text('Bạn báo không hoàn thành'), findsOneWidget);
      expect(
        find.text('Lý do: Trời mưa to đột xuất, nước ngập lối đi'),
        findsOneWidget,
      );

      provider.dispose();
    });
  });

  group('Farmer Task Dialogs & Workflow Actions', () {
    testWidgets('Từ chối công việc: mở dialog, nhập lý do và đóng dialog', (
      tester,
    ) async {
      final provider = _setupProvider(role: 'FARMER');
      final task = _createTask(
        id: 't_pending',
        status: 'Pending',
        title: 'Bón lót phân vi sinh',
      );
      provider.tasks.add(task);

      await _pumpFarmerDashboard(tester, provider);

      // Nút "Nhận việc" và "Từ chối" xuất hiện
      expect(find.text('Nhận việc'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);

      // Bấm "Từ chối"
      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();

      // Dialog mở ra
      expect(find.text('Từ Chối Nhận Việc'), findsOneWidget);
      expect(find.text('Lý do từ chối (không bắt buộc):'), findsOneWidget);
      expect(find.text('Xác nhận từ chối'), findsOneWidget);

      // Nhập lý do
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Nhập lý do bạn không thể nhận công việc này...',
        ),
        'Bận ca trực tưới khu B',
      );
      await tester.pump();

      // Bấm "Quay lại" để hủy
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();

      // Dialog đóng, quay lại màn hình chính
      expect(find.text('Từ Chối Nhận Việc'), findsNothing);
      expect(find.text('Bón lót phân vi sinh'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('Báo không thể hoàn thành: validate bắt buộc nhập lý do', (
      tester,
    ) async {
      final provider = _setupProvider(role: 'FARMER');
      final task = _createTask(
        id: 't_accepted',
        status: 'Accepted',
        title: 'Lắp bẫy dính vàng diệt côn trùng',
      );
      provider.tasks.add(task);

      await _pumpFarmerDashboard(tester, provider);

      // Nút "Bắt đầu làm" và "Báo không hoàn thành"
      expect(find.text('Bắt đầu làm'), findsOneWidget);
      expect(find.text('Báo không hoàn thành'), findsOneWidget);

      // Bấm "Báo không hoàn thành"
      await tester.tap(find.text('Báo không hoàn thành'));
      await tester.pumpAndSettle();

      expect(find.text('Báo Không Thể Hoàn Thành'), findsOneWidget);
      expect(find.text('Vì sao không thể hoàn thành? *'), findsOneWidget);

      // Bấm gửi khi chưa nhập gì -> Hiển thị thông báo lỗi xác thực
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pump();
      expect(
        find.text('Vui lòng nhập lý do không thể hoàn thành.'),
        findsOneWidget,
      );

      // Nhập lý do
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Mô tả trở ngại, sự cố thiết bị, thời tiết...',
        ),
        'Kho hết bẫy dính màu vàng',
      );
      await tester.pump();

      // Đóng dialog bằng "Quay lại"
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Báo Không Thể Hoàn Thành'), findsNothing);

      provider.dispose();
    });

    testWidgets('Cập nhật tiến độ: hiển thị Slider và ô nhập ghi chú tiến độ', (
      tester,
    ) async {
      final provider = _setupProvider(role: 'FARMER');
      final task = _createTask(
        id: 't_in_progress',
        status: 'InProgress',
        title: 'Châm phân hệ thống tưới nhỏ giọt',
        progressPercent: 30,
        progressNote: 'Đang pha bồn A',
      );
      provider.tasks.add(task);

      await _pumpFarmerDashboard(tester, provider);

      // Kiểm tra nút "Cập nhật tiến độ"
      expect(find.text('Cập nhật tiến độ'), findsOneWidget);
      expect(find.text('Nộp kết quả'), findsOneWidget);

      // Bấm "Cập nhật tiến độ"
      await tester.tap(find.text('Cập nhật tiến độ'));
      await tester.pumpAndSettle();

      expect(find.text('Cập Nhật Tiến Độ Thực Địa'), findsOneWidget);
      expect(find.text('Tiến độ thực hiện:'), findsOneWidget);
      expect(find.text('30%'), findsWidgets);
      expect(find.text('Ghi chú tiến độ (không bắt buộc):'), findsOneWidget);
      expect(find.text('Đang pha bồn A'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Đóng dialog
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Cập Nhật Tiến Độ Thực Địa'), findsNothing);

      provider.dispose();
    });

    testWidgets('Nộp kết quả: validate bắt buộc nhập mô tả kết quả', (
      tester,
    ) async {
      final provider = _setupProvider(role: 'FARMER');
      final task = _createTask(
        id: 't_complete_test',
        status: 'InProgress',
        title: 'Lau chùi cảm biến ánh sáng và nhiệt ẩm',
      );
      provider.tasks.add(task);

      await _pumpFarmerDashboard(tester, provider);

      // Bấm "Nộp kết quả"
      await tester.tap(find.text('Nộp kết quả'));
      await tester.pumpAndSettle();

      expect(find.text('Nộp Kết Quả Công Việc Thực Địa'), findsOneWidget);
      expect(find.text('Mô tả kết quả đã làm *'), findsOneWidget);

      // Bấm "Nộp kết quả" khi rỗng -> báo lỗi
      await tester.tap(find.widgetWithText(FilledButton, 'Nộp kết quả').last);
      await tester.pump();
      expect(find.text('Vui lòng nhập mô tả kết quả đã làm.'), findsOneWidget);

      // Nhập nội dung
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Ví dụ: Đã kiểm tra xong toàn bộ đầu vòi phun sương, vệ sinh 1 vòi nghẹt, cây phát triển đồng đều...',
        ),
        'Đã vệ sinh 3 đầu cảm biến trong nhà màng, số đo gửi về bình thường.',
      );
      await tester.pump();

      // Đóng dialog
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Nộp Kết Quả Công Việc Thực Địa'), findsNothing);

      provider.dispose();
    });
  });

  group('TaskActions Widget: Owner & Farmer Views', () {
    testWidgets(
      'Giao diện Chủ trang trại (Owner): hiển thị thẻ phân công con, tiến độ và nút Duyệt kết quả',
      (tester) async {
        final provider = _setupProvider(role: 'OWNER');
        final multiAssignTask = TaskModel(
          taskId: 't_multi',
          title: 'Thu hoạch cà chua đợt 2',
          zoneName: 'Khu A',
          priority: 'Khẩn cấp',
          dueDate: '22/11/2026',
          status: 'InProgress',
          assignments: [
            const TaskAssignmentModel(
              farmerId: 'f1',
              farmerName: 'Nguyễn Văn A',
              status: 'CompletedPendingReview',
              progressPercent: 100,
              progressNote: 'Thu xong 10 giỏ',
              result: 'Đã thu hoạch 150kg cà chua chín đều.',
            ),
            const TaskAssignmentModel(
              farmerId: 'f2',
              farmerName: 'Lê Thị B',
              status: 'InProgress',
              progressPercent: 60,
              progressNote: 'Đang xếp giỏ số 7',
            ),
          ],
        );

        await _pumpTaskActions(
          tester,
          provider,
          multiAssignTask,
          isOwner: true,
        );

        // Hiển thị tên nhân công
        expect(find.text('Nguyễn Văn A'), findsOneWidget);
        expect(find.text('Lê Thị B'), findsOneWidget);

        // Thẻ Nguyễn Văn A có nút "Duyệt kết quả" vì trạng thái là CompletedPendingReview
        expect(find.text('Duyệt kết quả'), findsOneWidget);
        expect(
          find.text('Kết quả: Đã thu hoạch 150kg cà chua chín đều.'),
          findsOneWidget,
        );

        // Hiển thị tiến độ của cả 2 nhân công
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

        // Nút quản lý người thực hiện
        expect(find.text('Người thực hiện'), findsOneWidget);

        provider.dispose();
      },
    );

    testWidgets(
      'Giao diện Nông dân (Farmer): hiển thị tiến độ cá nhân và nút hành động',
      (tester) async {
        final provider = _setupProvider(role: 'FARMER');
        final farmerTask = _createTask(
          id: 't_action_farmer',
          status: 'InProgress',
          progressPercent: 75,
          progressNote: 'Xong 3/4 diện tích',
        );

        await _pumpTaskActions(tester, provider, farmerTask, isOwner: false);

        expect(find.text('Đang thực hiện'), findsOneWidget);
        expect(find.text('75%'), findsOneWidget);
        expect(
          find.text('Ghi chú tiến độ: Xong 3/4 diện tích'),
          findsOneWidget,
        );
        expect(find.text('Nộp kết quả'), findsOneWidget);
        expect(find.text('Cập nhật %'), findsOneWidget);
        expect(find.text('Báo không hoàn thành'), findsOneWidget);

        provider.dispose();
      },
    );
  });
}
