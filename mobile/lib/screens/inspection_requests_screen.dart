import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import 'equipment_orders_screen.dart';

class InspectionRequestsScreen extends StatelessWidget {
  const InspectionRequestsScreen({super.key});

  static const _statusMap = <String, (String, Color)>{
    'PENDING': ('⏳ Chờ Admin duyệt', Color(0xFFD97706)),
    'APPROVED': ('✅ Admin đã duyệt', Color(0xFF0284C7)),
    'DISPATCHED': ('🛵 KTV đang tiếp nhận & xử lý', Color(0xFF059669)),
    'COMPLETED': ('🎯 Hoàn tất khảo sát', Color(0xFF10B981)),
    'REJECTED': ('⛔ Bị từ chối', Color(0xFFDC2626)),
  };

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final role = provider.currentRole;
    final list = provider.inspectionRequests;
    final isTech = role == 'TECHNICIAN';
    final assignedCount = list.where((r) => r.status == 'DISPATCHED' || r.status == 'APPROVED').length;
    final pendingCount = list.where((r) => r.status == 'PENDING').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isTech ? 'Phiếu Phân Công Khảo Sát KTV' : 'Yêu Cầu Khảo Sát Thực Địa',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          if (!isTech)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
              tooltip: 'Gửi yêu cầu mới',
              onPressed: () => _showCreateRequestModal(context, provider),
            ),
        ],
      ),
      floatingActionButton: !isTech
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateRequestModal(context, provider),
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Gửi Yêu Cầu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Hướng dẫn
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isTech ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isTech ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isTech ? Icons.engineering_rounded : Icons.info_outline_rounded,
                  color: isTech ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTech
                            ? 'Kỹ Thuật Viên: Có $assignedCount phiếu khảo sát cần xử lý'
                            : 'Chủ Trang Trại: Có $pendingCount phiếu đang chờ Admin duyệt',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isTech ? const Color(0xFF166534) : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTech
                            ? 'Chạm vào "Xem chi tiết & Kiểm tra thực địa" để kiểm tra thông số mặt bằng, checklist nguồn điện/nước/LoRa và lập biên bản.'
                            : 'Admin hệ thống sẽ kiểm duyệt thông tin và phân công Kỹ thuật viên IoT xuống tận nơi đo đạc sóng và lập phương án kỹ thuật.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isTech ? const Color(0xFF15803D) : const Color(0xFF78350F),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text('Chưa có yêu cầu khảo sát nào', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...list.map((r) => _card(context, provider, r, role)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, FarmProvider provider, FieldInspectionRequestModel r, String role) {
    final info = _statusMap[r.status] ?? ('—', const Color(0xFF64748B));
    final color = info.$2;
    final isTech = role == 'TECHNICIAN';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 16, color: Color(0xFF0F172A)),
                    const SizedBox(width: 6),
                    Text(r.requestId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(info.$1, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.zoneName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.farmName} • ${r.areaM2.toInt()} m² • ${r.cropName}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _rowInfo(Icons.calendar_today_outlined, 'Thời gian hẹn', r.preferredDate),
                      const SizedBox(height: 5),
                      _rowInfo(Icons.person_outline, 'Khách hàng', '${r.contactName} (${r.contactPhone})'),
                      const SizedBox(height: 5),
                      _rowInfo(Icons.edit_note, 'Yêu cầu', r.note),
                    ],
                  ),
                ),

                if (r.assignedTechnicianName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.engineering, size: 14, color: Color(0xFF15803D)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'KTV phụ trách: ${r.assignedTechnicianName} • ${r.technicianPhone ?? ""}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (r.adminNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Ghi chú Admin: ${r.adminNote}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                  ),
                ],

                if (r.inspectionNotes != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '📋 Kết quả khảo sát: ${r.inspectionNotes}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Button Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showInspectionDetailModal(context, provider, r, isTech),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                        label: const Text('Xem Chi Tiết Khảo Sát', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (r.status == 'COMPLETED') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EquipmentOrdersScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                          label: const Text('Đơn Hàng & Cọc 30%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowInfo(IconData icon, String label, String val) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(val, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Bottom Sheet Xem Chi Tiết & Khảo Sát Thực Địa Cho KTV
  // ─────────────────────────────────────────
  void _showInspectionDetailModal(BuildContext context, FarmProvider provider, FieldInspectionRequestModel r, bool isTech) {
    final noteCtrl = TextEditingController(text: r.inspectionNotes ?? 'Hiện trường đã kiểm tra: Nguồn điện 1 pha 220V ổn định, áp lực nước đạt 2.5 bar, vị trí tủ điều khiển đảm bảo che mưa nắng.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Modal Top Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF062326),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF10B981), size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('HỒ SƠ KHẢO SÁT: ${r.requestId}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('Kỹ thuật viên thực địa SmartFarm',
                                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Modal Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Card 1: Thông tin chủ trại & Liên hệ
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.contact_phone, color: Color(0xFF0284C7), size: 16),
                                  SizedBox(width: 6),
                                  Text('THÔNG TIN LIÊN HỆ & LỊCH HẸN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Người liên hệ: ${r.contactName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('Số điện thoại: ${r.contactPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              const SizedBox(height: 4),
                              Text('Thời gian hẹn: ${r.preferredDate}', style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('📞 Đang gọi cho khách hàng: ${r.contactPhone}')),
                                        );
                                      },
                                      icon: const Icon(Icons.call, size: 16, color: Color(0xFF10B981)),
                                      label: const Text('Gọi Điện Ngay', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981))),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF10B981)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('💬 Đang mở tin nhắn SMS gửi tới ${r.contactPhone}')),
                                        );
                                      },
                                      icon: const Icon(Icons.sms_outlined, size: 16, color: Color(0xFF0284C7)),
                                      label: const Text('Gửi Tin Nhắn', style: TextStyle(fontSize: 11.5, color: Color(0xFF0284C7))),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF0284C7)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card 2: Thông số Mặt Bằng Zone & Dự toán tham khảo
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.map_outlined, color: Color(0xFF10B981), size: 16),
                                  SizedBox(width: 6),
                                  Text('THÔNG SỐ MẶT BẰNG & MÔ PHỎNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('${r.farmName} • ${r.zoneName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                              const SizedBox(height: 4),
                              Text('• Diện tích mặt bằng: ${r.areaM2.toInt()} m²', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                              Text('• Giống cây trồng: ${r.cropName}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                              Text('• Dự toán mô phỏng ban đầu: ${r.estimatedCostVND.toInt()} đ (Giả định tham khảo)',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                                child: Text('Ghi chú của chủ trại: "${r.note}"',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card 3: Checklist Khảo Sát Thực Địa
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.checklist_rtl_rounded, color: Color(0xFFD97706), size: 16),
                                  SizedBox(width: 6),
                                  Text('CHECKLIST TIÊU CHUẨN HIỆN TRƯỜNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD97706))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _checkItem('1. Nguồn cấp điện lưới / Dự phòng: 220V/380V ổn định', true),
                              _checkItem('2. Áp lực nguồn nước cấp: Tối thiểu 2.0 bar cho béc tưới', true),
                              _checkItem('3. Độ phủ sóng LoRa SX1278 RSSI: Đạt chuẩn > -95 dBm', true),
                              _checkItem('4. Vị trí gắn tủ Gateway trung tâm có che chắn mưa nắng', true),
                              _checkItem('5. Đo đạc thực tế đường ống chính & van điện từ 24V/220V', true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card 4: Nhập Biên Bản / Kết quả Khảo sát của KTV
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.rate_review_outlined, color: Color(0xFF0F172A), size: 16),
                                  SizedBox(width: 6),
                                  Text('BIÊN BẢN & GHI CHÚ KỸ THUẬT VIÊN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: noteCtrl,
                                maxLines: 3,
                                readOnly: r.status == 'COMPLETED',
                                decoration: InputDecoration(
                                  hintText: 'Nhập kết quả khảo sát thực tế...',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.all(12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Nút hành động
                        if (r.status != 'COMPLETED') ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                provider.completeInspectionRequest(r.requestId, inspectionNotes: noteCtrl.text);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🎯 Đã hoàn tất biên bản khảo sát và đồng bộ về máy chủ Admin!'),
                                    backgroundColor: Color(0xFF065F46),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('XÁC NHẬN HOÀN TẤT KHẢO SÁT THỰC ĐỊA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Center(
                              child: Text(
                                '✅ Hồ sơ khảo sát này đã được KTV nghiệm thu và hoàn tất',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _checkItem(String text, bool checked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: checked ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  void _showCreateRequestModal(BuildContext context, FarmProvider provider) {
    final zones = provider.zones;
    if (zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có zone nào được tạo trong trang trại')),
      );
      return;
    }

    String selectedZoneId = zones.first.zoneId;
    final nameCtrl = TextEditingController(text: 'Lê Văn An');
    final phoneCtrl = TextEditingController(text: '0912 345 678');
    final noteCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: '28/10/2026');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final currentZone = zones.firstWhere((z) => z.zoneId == selectedZoneId, orElse: () => zones.first);

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tạo Yêu Cầu Khảo Sát / Kỹ Thuật',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                        ),
                        IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZoneId,
                      decoration: InputDecoration(
                        labelText: 'Chọn Nhà màng / Zone khảo sát *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: zones.map((z) {
                        return DropdownMenuItem(
                          value: z.zoneId,
                          child: Text('${z.name.split(' - ').first} (${z.areaM2.toInt()} m² - ${z.currentCrop})', style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedZoneId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Người liên hệ *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại *',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateCtrl,
                      decoration: InputDecoration(
                        labelText: 'Thời gian mong muốn khảo sát',
                        hintText: 'VD: 28/10/2026',
                        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Nội dung yêu cầu / Ghi chú cho KTV',
                        hintText: 'Ví dụ: Cần bổ sung van điện từ tưới bù áp, kiểm tra cột sóng LoRa...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng điền họ tên và số điện thoại')),
                            );
                            return;
                          }

                          provider.submitInspectionRequest(
                            zoneId: currentZone.zoneId,
                            zoneName: currentZone.name,
                            areaM2: currentZone.areaM2,
                            cropName: currentZone.currentCrop,
                            estimatedCostVND: 15000000,
                            contactName: nameCtrl.text.trim(),
                            contactPhone: phoneCtrl.text.trim(),
                            preferredDate: dateCtrl.text.trim(),
                            note: noteCtrl.text.trim().isEmpty ? 'Yêu cầu kiểm tra mặt bằng và đo sóng LoRa' : noteCtrl.text.trim(),
                          );

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🎉 Đã gửi yêu cầu khảo sát thành công! Admin sẽ tiếp nhận và điều phối KTV.'),
                              backgroundColor: Color(0xFF065F46),
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text('GỬI YÊU CẦU ĐẾN ADMIN', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

