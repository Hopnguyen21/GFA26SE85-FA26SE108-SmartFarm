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

Cấu hình API kết nối backend trong `lib/services/api_service.dart`.
