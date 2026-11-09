import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import 'contracts_depreciation_screen.dart';

class EquipmentOrdersScreen extends StatelessWidget {
  const EquipmentOrdersScreen({super.key});

  static const _statusMap = <String, (String, Color)>{
    'AWAITING_PAYMENT': ('💳 Chờ đặt cọc 30%', Color(0xFFD97706)),
    'CONFIRMED': ('📦 Đã cọc 30% - Đang xuất kho', Color(0xFF0284C7)),
    'DISPATCHING': ('🚚 Đang giao hàng & lắp đặt', Color(0xFF7C3AED)),
    'AWAITING_FINAL_PAYMENT': ('🧾 Chờ nghiệm thu & thanh toán 70%', Color(0xFFEA580C)),
    'CANCELLED': ('⛔ Đã hủy', Color(0xFFDC2626)),
    'COMPLETED': ('✅ Đã nghiệm thu (100%)', Color(0xFF10B981)),
  };

  String _formatVND(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)} Tr VNĐ';
    }
    return '${amount.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} VNĐ';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final orders = provider.equipmentOrders;
    final awaitingCount = orders.where((o) => o.status == 'AWAITING_PAYMENT').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Đơn Hàng Thiết Bị & Đặt Cọc',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Hợp Đồng Thuê & Khấu Hao',
            icon: const Icon(Icons.analytics_outlined, color: Color(0xFF10B981)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen(initialTabIndex: 1)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Thông tin
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062326), Color(0xFF0F4C47)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF34D399), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUY TRÌNH XÁC NHẬN & ĐẶT CỌC 30%',
                            style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            awaitingCount > 0
                                ? 'Có $awaitingCount đơn hàng cần Owner thanh toán cọc 30%'
                                : 'Tất cả các đơn hàng đã được xác nhận cọc',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Sau khi KTV khảo sát thực địa xong, đơn hàng sẽ được gửi cho Chủ trại xác nhận.\n'
                  '• Chủ trại thanh toán trước 30% để giữ hàng và kích hoạt đội kỹ thuật xuống lắp đặt.\n'
                  '• 70% còn lại thanh toán sau khi bàn giao nghiệm thu vận hành thực tế.',
                  style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Text('Chưa có đơn hàng thiết bị nào', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            ...orders.map((order) => _buildOrderCard(context, provider, order)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, FarmProvider provider, EquipmentOrderModel order) {
    final statusInfo = _statusMap[order.status] ?? ('—', const Color(0xFF64748B));
    final statusColor = statusInfo.$2;
    final isAwaiting = order.status == 'AWAITING_PAYMENT';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, size: 16, color: Color(0xFF0F172A)),
                    const SizedBox(width: 6),
                    Text(order.orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      statusInfo.$1,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
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
                  order.zoneName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                ),
                Text(
                  '${order.farmName} • Khởi tạo từ: ${order.requestId} (${order.createdAt})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),

                // Tóm tắt danh mục thiết bị
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      ...order.items.take(3).map((it) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '• ${it.name}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${it.quantity} ${it.unit}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          )),
                      if (order.items.length > 3)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '... và thêm ${order.items.length - 3} thiết bị khác',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF0284C7), fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Bảng tính Tiền & Đặt cọc 30%
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Tổng giá trị đơn hàng:', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatVND(order.totalAmountVND), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.stars_rounded, size: 14, color: Color(0xFFD97706)),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text('CẦN ĐẶT CỌC (30%):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatVND(order.depositAmountVND),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFD97706)),
                          ),
                        ],
                      ),
                      const Divider(height: 10, color: Color(0xFFFDE68A)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text('Còn lại sau nghiệm thu (70%):', style: TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatVND(order.remainingAmountVND), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),

                if (order.paymentProofNote != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '🧾 ${order.paymentProofNote}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF065F46), height: 1.3),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Button Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showContractDocumentModal(context, provider, order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.description_outlined, size: 15, color: Color(0xFFD97706)),
                        label: const Text('Xem Hợp Đồng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOrderDetailSheet(context, provider, order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                        ),
                        icon: const Icon(Icons.list_alt, size: 15),
                        label: const Text('Chi Tiết Vật Tư', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                if (isAwaiting) ...[
                  const SizedBox(height: 8),
                  if (provider.currentRole == 'OWNER')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showPaymentModal(context, provider, order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Xác Nhận & Cọc 30%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('⏳ Đang chờ Chủ trang trại (Owner) xác nhận & đặt cọc 30%', style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
                    ),
                ] else if (order.status == 'CONFIRMED' && provider.currentRole == 'TECHNICIAN') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        provider.startOrderInstallation(order.orderId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🚚 KTV đã nhận hàng và bắt đầu chuyển xuống hiện trường lắp đặt!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.local_shipping_outlined, size: 16),
                      label: const Text('Xuất Kho & Lắp Đặt', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else if (order.status == 'DISPATCHING' && provider.currentRole == 'TECHNICIAN') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        provider.handoverOrder(order.orderId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📋 Đã hoàn tất lắp đặt & gửi biên bản bàn giao nghiệm thu cho Owner!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.handshake_outlined, size: 16),
                      label: const Text('Bàn Giao Nghiệm Thu', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else if (order.status == 'AWAITING_FINAL_PAYMENT') ...[
                  const SizedBox(height: 8),
                  if (provider.currentRole == 'OWNER')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showFinalPaymentModal(context, provider, order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Nghiệm Thu & Thanh Toán 70% Cuối', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('⏳ Đã bàn giao lắp đặt — Chờ Owner nghiệm thu & thanh toán 70%', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                    ),
                ] else if (order.status == 'COMPLETED') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContractsDepreciationScreen(
                              initialFarmId: order.farmId,
                              initialZoneId: order.zoneId,
                              initialTabIndex: 1,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF14B8A6)),
                        backgroundColor: const Color(0xFFF0FDFA),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.trending_down, size: 16, color: Color(0xFF0D9488)),
                      label: const Text(
                        'Theo Dõi Khấu Hao & Lịch Đổi Thiết Bị',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                if (isAwaiting) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        provider.cancelOrder(order.orderId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Đã hủy đơn hàng ${order.orderId}')),
                        );
                      },
                      child: const Text('Hủy đơn hàng', style: TextStyle(color: Color(0xFFEF4444), fontSize: 11)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Modal Xem Đầy Đủ Chi Tiết Đơn Hàng ───
  void _showOrderDetailSheet(BuildContext context, FarmProvider provider, EquipmentOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
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
                      const Icon(Icons.receipt_long, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text('CHI TIẾT ĐƠN HÀNG: ${order.orderId}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(order.zoneName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${order.farmName} • Phiếu khảo sát gốc: ${order.requestId}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  const Text('DANH MỤC THIẾT BỊ ĐÃ KHẢO SÁT & CHỐT PHƯƠNG ÁN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
                  const SizedBox(height: 8),

                  ...order.items.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                                Text('${item.quantity} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(item.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Đơn giá: ${_formatVND(item.unitPriceVND)}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                Text(_formatVND(item.totalPriceVND), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: 14),
                  // Bảng tính
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tổng tiền thiết bị:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text(_formatVND(order.totalAmountVND), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Đợt 1: Đặt cọc xác nhận (30%):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                            Text(_formatVND(order.depositAmountVND), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Đợt 2: Nghiệm thu bàn giao (70%):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text(_formatVND(order.remainingAmountVND), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showContractDocumentModal(context, provider, order);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18, color: Color(0xFFD97706)),
                      label: const Text('XEM VĂN BẢN HỢP ĐỒNG ĐIỆN TỬ (ĐẦY ĐỦ)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (order.status == 'AWAITING_PAYMENT')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPaymentModal(context, provider, order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('TIẾN HÀNH ĐẶT CỌC 30%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modal Xem Toàn Văn Bản Hợp Đồng Điện Tử ───
  void _showContractDocumentModal(BuildContext context, FarmProvider provider, EquipmentOrderModel order) {
    final isAwaiting = order.status == 'AWAITING_PAYMENT';
    final isAwaitingFinal = order.status == 'AWAITING_FINAL_PAYMENT';
    final isCompleted = order.status == 'COMPLETED';
    final isConfirmed = order.status == 'CONFIRMED' || order.status == 'DISPATCHING';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.90,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF062326),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'HỢP ĐỒNG ĐIỆN TỬ SMARTFARM',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
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

            // Scrollable Contract Document Paper
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Quốc hiệu & Tiêu ngữ
                      const Text(
                        'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Độc lập – Tự do – Hạnh phúc',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(width: 120, height: 1, color: const Color(0xFFCBD5E1)),
                      const SizedBox(height: 14),

                      // Tên Hợp Đồng & Số HĐ
                      const Text(
                        'HỢP ĐỒNG CUNG CẤP & TRIỂN KHAI\nTHIẾT BỊ IOT NÔNG NGHIỆP THÔNG MINH',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF065F46), height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mã số Hợp đồng: HĐ-SF-${order.orderId}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Ngày lập: ${order.createdAt.split(' ').first}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      // Các bên tham gia
                      _buildContractPartySection(
                        partyRole: 'BÊN A (BÊN ĐẶT HÀNG / CHỦ TRANG TRẠI)',
                        name: 'Đại diện Chủ Trang Trại (Farm Owner)',
                        farmName: order.farmName,
                        zoneTarget: 'Khu vực lắp đặt: ${order.zoneName}',
                      ),
                      const SizedBox(height: 12),
                      _buildContractPartySection(
                        partyRole: 'BÊN B (ĐƠN VỊ TRIỂN KHAI / SMARTFARM PLATFORM)',
                        name: 'Công ty Cổ phần Nông nghiệp Thông minh SmartFarm',
                        farmName: 'Hệ thống Nền tảng IoT Nông nghiệp Công nghệ cao',
                        zoneTarget: 'Đại diện kỹ thuật: Đội ngũ Kỹ thuật viên Thực địa SmartFarm',
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      // Điều 1: Danh mục thiết bị
                      _buildContractArticleTitle('ĐIỀU 1. DANH MỤC THIẾT BỊ & PHẠM VI LẮP ĐẶT'),
                      const SizedBox(height: 6),
                      const Text(
                        'Bên B cung ứng và lắp đặt hoàn thiện thiết bị IoT đo đạc vi khí hậu theo khảo sát hiện trường chuẩn VietGAP cho Bên A:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.4),
                      ),
                      const SizedBox(height: 8),

                      // Bảng tóm tắt thiết bị
                      ...order.items.map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Text('Bảo hành 24 tháng chính hãng • ${item.description}', style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ],
                            ),
                          )),

                      const SizedBox(height: 14),

                      // Điều 2: Giá trị và phương thức thanh toán
                      _buildContractArticleTitle('ĐIỀU 2. GIÁ TRỊ HỢP ĐỒNG & THANH TOÁN 2 PHA'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TỔNG GIÁ TRỊ HỢP ĐỒNG:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                Text(_formatVND(order.totalAmountVND), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                              ],
                            ),
                            const Divider(height: 14, color: Color(0xFFBBF7D0)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Đợt 1: Tạm ứng cọc 30% khi ký HĐ:', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                Text(
                                  '${_formatVND(order.depositAmountVND)} ${!isAwaiting ? '✅ (ĐÃ CỌC)' : '⏳ (CHỜ CỌC)'}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !isAwaiting ? const Color(0xFF059669) : const Color(0xFFD97706)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Đợt 2: Nghiệm thu bàn giao 70%:', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                                Text(
                                  '${_formatVND(order.remainingAmountVND)} ${isCompleted ? '✅ (HOÀN TẤT)' : '⏳ (KHI NGHIỆM THU)'}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCompleted ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Điều 3: Trách nhiệm & Nghiệm thu
                      _buildContractArticleTitle('ĐIỀU 3. BẢO HÀNH & KÝ NGHIỆM THU ĐIỆN TỬ'),
                      const SizedBox(height: 6),
                      const Text(
                        '1. Bên B cam kết thiết bị hoạt động ổn định, kết nối sóng LoRaWAN tầm xa 2.5km, đồng bộ dữ liệu thời gian thực lên Dashboard.\n'
                        '2. Sau khi hoàn thành lắp đặt, Bên A và Bên B tiến hành đo thử nghiệm và ký Biên bản Nghiệm thu điện tử trên ứng dụng SmartFarm.\n'
                        '3. Thiết bị được bảo hành kỹ thuật 24 tháng theo quy định.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.45),
                      ),

                      const SizedBox(height: 18),

                      // Con dấu điện tử xác nhận
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFFECFDF5)
                              : isConfirmed
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCompleted || isConfirmed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isCompleted || isConfirmed ? Icons.verified : Icons.pending_actions,
                              color: isCompleted || isConfirmed ? const Color(0xFF059669) : const Color(0xFFD97706),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isCompleted
                                        ? 'CHỨNG THỰC: HỢP ĐỒNG ĐÃ HOÀN TẤT 100%'
                                        : isConfirmed
                                            ? 'CHỨNG THỰC: ĐÃ KÝ SỐ & ĐẶT CỌC 30% HỢP LỆ'
                                            : 'DỰ THẢO: CHỜ KÝ HỢP ĐỒNG & THANH TOÁN 30%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted || isConfirmed ? const Color(0xFF065F46) : const Color(0xFFB45309),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isCompleted
                                        ? 'Biên bản bàn giao nghiệm thu và toàn bộ chứng từ thanh toán đã được lưu trữ số hóa trên SmartFarm Cloud.'
                                        : isConfirmed
                                            ? 'Hợp đồng có hiệu lực pháp lý từ thời điểm ghi nhận khoản tạm ứng 30%. Kỹ thuật viên đã xuất kho thiết bị.'
                                            : 'Vui lòng xác nhận và đặt cọc 30% để hợp đồng chính thức có hiệu lực thi công.',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer action buttons
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Đóng', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  if (isAwaiting) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showPaymentModal(context, provider, order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('ĐẶT CỌC 30% KÝ HĐ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ] else if (isAwaitingFinal) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showFinalPaymentModal(context, provider, order);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('NGHIỆM THU & CỌC 70%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractPartySection({
    required String partyRole,
    required String name,
    required String farmName,
    required String zoneTarget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(partyRole, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          Text(farmName, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          Text(zoneTarget, style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContractArticleTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46), letterSpacing: 0.3),
      ),
    );
  }

  // ─── Modal Thanh Toán Đặt Cọc 30% ───
  void _showPaymentModal(BuildContext context, FarmProvider provider, EquipmentOrderModel order) {
    String selectedMethod = 'BANK_TRANSFER';
    final noteCtrl = TextEditingController(text: 'Chuyển khoản cọc 30% đơn hàng ${order.orderId}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Xác Nhận & Đặt Cọc 30%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('Thanh toán để kích hoạt quy trình giao hàng & lắp đặt', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Số tiền cọc
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SỐ TIỀN CỌC 30%:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            Text('Tương đương 30% giá trị hợp đồng', style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D))),
                          ],
                        ),
                        Text(
                          _formatVND(order.depositAmountVND),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Chọn phương thức thanh toán *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 8),

                  _paymentMethodTile(
                    method: 'BANK_TRANSFER',
                    title: 'Chuyển khoản Ngân hàng (Vietcombank QR)',
                    subtitle: 'STK: 0071001234567 • CTCP Nông Nghiệp Thông Minh',
                    icon: Icons.account_balance,
                    isSelected: selectedMethod == 'BANK_TRANSFER',
                    onSelect: () => setModalState(() => selectedMethod = 'BANK_TRANSFER'),
                  ),
                  const SizedBox(height: 8),
                  _paymentMethodTile(
                    method: 'VNPAY',
                    title: 'Cổng VNPAY / Ví điện tử MoMo',
                    subtitle: 'Quét mã thanh toán tức thời qua Smart Banking',
                    icon: Icons.qr_code_scanner,
                    isSelected: selectedMethod == 'VNPAY',
                    onSelect: () => setModalState(() => selectedMethod = 'VNPAY'),
                  ),
                  const SizedBox(height: 8),
                  _paymentMethodTile(
                    method: 'CASH',
                    title: 'Nộp tiền mặt cho Kỹ thuật viên phụ trách',
                    subtitle: 'KTV ký biên nhận thu tiền cọc trực tiếp tại vườn',
                    icon: Icons.payments_outlined,
                    isSelected: selectedMethod == 'CASH',
                    onSelect: () => setModalState(() => selectedMethod = 'CASH'),
                  ),

                  const SizedBox(height: 14),
                  const Text('Ghi chú giao dịch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        provider.confirmOrderWithDeposit(
                          order.orderId,
                          paymentMethod: selectedMethod,
                          proofNote: 'Đã cọc 30% (${_formatVND(order.depositAmountVND)}) qua $selectedMethod. ${noteCtrl.text}',
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Đã xác nhận đơn hàng và thanh toán cọc 30% thành công cho ${order.orderId}!'),
                            backgroundColor: const Color(0xFF065F46),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text('XÁC NHẬN THANH TOÁN ${_formatVND(order.depositAmountVND)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Modal Thanh Toán 70% Nghiệm Thu ───
  void _showFinalPaymentModal(BuildContext context, FarmProvider provider, EquipmentOrderModel order) {
    String selectedMethod = 'BANK_TRANSFER';
    final noteCtrl = TextEditingController(text: 'Nghiệm thu bàn giao hoàn tất và thanh toán 70% còn lại đơn ${order.orderId}');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.task_alt, color: Color(0xFF059669), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Nghiệm Thu & Thanh Toán 70%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('Thanh toán đợt cuối để hoàn tất hợp đồng thiết bị', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Số tiền thanh toán 70%
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SỐ TIỀN THANH TOÁN (70%):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            Text('Nghiệm thu đủ 100% hợp đồng', style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D))),
                          ],
                        ),
                        Text(
                          _formatVND(order.remainingAmountVND),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Chọn phương thức thanh toán *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 8),

                  _paymentMethodTile(
                    method: 'BANK_TRANSFER',
                    title: 'Chuyển khoản Ngân hàng (Vietcombank QR)',
                    subtitle: 'STK: 0071001234567 • CTCP Nông Nghiệp Thông Minh',
                    icon: Icons.account_balance,
                    isSelected: selectedMethod == 'BANK_TRANSFER',
                    onSelect: () => setModalState(() => selectedMethod = 'BANK_TRANSFER'),
                  ),
                  const SizedBox(height: 8),
                  _paymentMethodTile(
                    method: 'VNPAY',
                    title: 'Cổng VNPAY / Ví điện tử MoMo',
                    subtitle: 'Quét mã thanh toán tức thời qua Smart Banking',
                    icon: Icons.qr_code_scanner,
                    isSelected: selectedMethod == 'VNPAY',
                    onSelect: () => setModalState(() => selectedMethod = 'VNPAY'),
                  ),
                  const SizedBox(height: 8),
                  _paymentMethodTile(
                    method: 'CASH',
                    title: 'Thanh toán tiền mặt cho KTV tại vườn',
                    subtitle: 'KTV ký biên lai xác nhận thu đủ 100%',
                    icon: Icons.payments_outlined,
                    isSelected: selectedMethod == 'CASH',
                    onSelect: () => setModalState(() => selectedMethod = 'CASH'),
                  ),

                  const SizedBox(height: 14),
                  const Text('Ghi chú nghiệm thu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        provider.payFinalOrder(order.orderId, paymentMethod: selectedMethod);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Đã hoàn tất thanh toán 70% còn lại cho đơn hàng ${order.orderId}! Hệ thống đã bàn giao 100%.'),
                            backgroundColor: const Color(0xFF065F46),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text('XÁC NHẬN THANH TOÁN ${_formatVND(order.remainingAmountVND)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _paymentMethodTile({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155))),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
