# SmartFarm Mobile Application

Ứng dụng di động dành cho Chủ Trang Trại (Farm Owner) và Kỹ sư / Công nhân Nông nghiệp (Farmer) trong hệ thống quản lý nông trại thông minh **SmartFarm**.

## Tính Năng Chính
1. **Giám sát Vi Khí Hậu Thời Gian Thực**: Theo dõi chỉ số nhiệt độ, độ ẩm đất, độ ẩm không khí, ánh sáng, pH và EC từ các trạm cảm biến LoRa Gateway.
2. **Quản Lý Khu Vực Canh Tác (Zones)**: Xem cấu trúc Lô đất (Fields), Khu vực (Zones), mùa vụ đang canh tác và ngày tuổi sinh trưởng của cây trồng.
3. **Điều Khiển Thiết Bị Chấp Hành (Actuator Control)**: Bật/tắt máy bơm tưới nhỏ giọt, quạt thông gió, van phun sương và xem trạng thái ACK xác thực từ thiết bị.
4. **Trợ Lý AI & Khuyến Nghị VietGAP**: Tích hợp khuyến nghị tưới tiêu an toàn dựa trên tiêu chuẩn VietGAP và dự báo thời tiết OpenMeteo.
5. **Cảnh Báo & Sự Cố Nông Nghiệp**: Nhận diện vượt ngưỡng môi trường, sự cố thiết bị offline, hỗ trợ báo cáo bảo trì.

## Giới Hạn Dữ Liệu Demo

- Khi backend chưa kết nối, ứng dụng có thể dùng dữ liệu mẫu trong bộ nhớ; các chỉ số telemetry chưa xác nhận từ DB được đánh dấu không mới và màn hình giám sát hiển thị `—`.
- Không dùng dữ liệu demo để đánh giá tình trạng thực tế của trang trại.
- Lệnh actuator chỉ được mô phỏng ở backend khi `ASPNETCORE_ENVIRONMENT=Development` và `SimulatedIot:Enabled=true`; mô phỏng không xác nhận phần cứng ngoài đời.

## Cài Đặt & Chạy Thử
```bash
cd mobile
flutter pub get
flutter run
```

Cấu hình API kết nối backend trong `lib/core/services/api_service.dart`.

## Cấu Trúc Mã Nguồn

```
lib/
  main.dart                    Khởi động app, chọn màn theo vai trò, thanh điều hướng
  core/
    models/models.dart         Import duy nhất cho mọi model; từng nhóm nằm ở models/parts/
    services/api_service.dart  Lõi HTTP: base URL, token, tự refresh, helper giải mã lỗi
    services/api/*_api.dart    API theo nghiệp vụ: FarmApi, CropApi, TaskApi, AutomationApi,
                               DeploymentApi, SupportApi, ContractApi, AccountApi, AiApi,
                               DocumentApi, ReportApi (gọi dạng ContractApi.getZoneContracts(...))
    providers/farm_provider.dart  State dùng chung; các nhóm hành động ở providers/parts/
    widgets/  utils/           Widget & tiện ích dùng chung (bản đồ GIS, xuất file...)
  features/<tính năng>/
    *_screen.dart              Màn hình chính của tính năng (đọc file này trước)
    parts/                     Các phần của màn hình đó (tab, hộp thoại, thẻ) — `part of` file chính
    widgets/                   Widget riêng của tính năng, dùng được từ nơi khác
```

Tính năng: `auth`, `home`, `farms`, `workforce`, `zones`, `crops`, `farmer`, `irrigation`,
`tasks`, `monitoring`, `ai`, `contracts`, `devices`, `support`, `inventory`, `reports`, `profile`.

Quy ước:
- Mỗi file nên dưới ~600 dòng. Khi màn hình dài thêm, tách tab/hộp thoại sang `parts/`
  (dạng `extension _TênPhần on _TênState { ... }`; trong part dùng `_rebuild(...)` thay cho `setState`).
- Gọi backend qua class `*Api` tương ứng; không gọi `http` trực tiếp từ màn hình.
- Không hiển thị số liệu giả: khi API lỗi hoặc chưa có dữ liệu, hiện trạng thái lỗi/trống rõ ràng.

Quy ước giao diện:
- Màu, bo góc, nút, ô nhập, hộp thoại, snackbar do `core/theme/app_theme.dart` quy định (`AppColors`, `AppSpacing`,
  `buildAppTheme`); màn mới dùng token này thay vì tự viết mã màu.
- Trạng thái tải/rỗng/lỗi dùng `core/widgets/state_views.dart` (`AppLoading`, `AppEmptyState`, `AppErrorState`);
  danh sách chính phải kéo xuống để làm mới được (`RefreshIndicator`, kể cả khi rỗng).
- Cỡ chữ tối thiểu 11; mọi `IconButton` cần `tooltip`; vùng chạm tối thiểu 44–48dp.
- Bố cục phải chịu được màn hình 320px và chữ phóng 1.3× — `test/layout_overflow_test.dart` kiểm tra tự động
  các màn chính; thêm màn quan trọng mới thì thêm vào đó.
