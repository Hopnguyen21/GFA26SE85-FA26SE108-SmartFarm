import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';

/// Widget hiển thị mô hình mạng tổ ong (Lục giác - Honeycomb IoT Topology)
/// Đồng bộ 100% với cấu trúc tính toán & thẩm mỹ trên Frontend (CreateFarmWizard.tsx)
class HoneycombTopologyCard extends StatefulWidget {
  final HoneycombTopologySimulation simulation;
  final bool initialExpanded;
  final VoidCallback? onAdjustTapped;

  const HoneycombTopologyCard({
    super.key,
    required this.simulation,
    this.initialExpanded = true,
    this.onAdjustTapped,
  });

  @override
  State<HoneycombTopologyCard> createState() => _HoneycombTopologyCardState();
}

class _HoneycombTopologyCardState extends State<HoneycombTopologyCard> {
  bool _showMeshVisualizer = true;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  String _formatVND(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)} Tr ₫';
    }
    return '${(amount / 1000).toStringAsFixed(0)}k ₫';
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.simulation;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Card chuẩn FE (Emerald Gradient) ──
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F766E),
                    Color(0xFF10B981),
                    Color(0xFF059669),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'Ước tính Thiết bị IoT & Chi phí',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${sim.cropIcon} ${sim.cropName.split(' ')[0]}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bố trí theo mô hình mạng tổ ong (Lục giác) trên diện tích ${sim.areaM2.toInt()} m²',
                          style: const TextStyle(
                            color: Color(0xFFD1FAE5),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 3 Khối thiết bị chính (Gateway - Sensor - Actuator) ──
                  Row(
                    children: [
                      // LoRa Gateway
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFBAE6FD),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.wifi,
                                  color: Color(0xFF0369A1),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${sim.gateways}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF075985),
                                ),
                              ),
                              const Text(
                                'LoRa Gateway',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              const Divider(
                                height: 1,
                                color: Color(0xFFE0F2FE),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatVND(sim.gateways * sim.gatewayUnitPrice),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Sensor Node
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.radio,
                                  color: Color(0xFF047857),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${sim.sensors}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              const Text(
                                'Sensor Node',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              const Divider(
                                height: 1,
                                color: Color(0xFFD1FAE5),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatVND(sim.sensors * sim.sensorUnitPrice),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Actuators
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.bolt,
                                  color: Color(0xFFB45309),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${sim.actuators}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              const Text(
                                'Van / Bơm',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              const Divider(
                                height: 1,
                                color: Color(0xFFFEF3C7),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatVND(
                                  sim.actuators * sim.actuatorUnitPrice,
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Nút Bật/Tắt Bản đồ Mạng Tổ Ong Trực Quan ──
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showMeshVisualizer = !_showMeshVisualizer;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showMeshVisualizer
                                ? Icons.layers_clear_outlined
                                : Icons.layers_outlined,
                            size: 16,
                            color: const Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showMeshVisualizer
                                ? 'Thu gọn sơ đồ mạng tổ ong'
                                : 'Xem sơ đồ mạng tổ ong (Lục giác)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${sim.hexagonCells} Ô lục giác',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Sơ đồ Mạng Lục Giác Canvas ──
                  if (_showMeshVisualizer) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 170,
                      decoration: BoxDecoration(
                        color: const Color(0xFF062326),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF062326,
                            ).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: HoneycombMeshPainter(
                                cellCount: sim.hexagonCells,
                                gatewayCount: sim.gateways,
                                sensorCount: sim.sensors,
                              ),
                            ),
                          ),
                          // Badge Chú thích góc
                          Positioned(
                            top: 8,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.wifi_tethering,
                                    size: 12,
                                    color: Color(0xFF34D399),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LoRa Topology • 2.5km • ${sim.areaM2.toInt()}m²',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Legend Bar dưới đáy
                          Positioned(
                            bottom: 6,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF04181B,
                                ).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _LegendItem(
                                    color: Color(0xFF38BDF8),
                                    label: 'LoRa GW',
                                  ),
                                  _LegendItem(
                                    color: Color(0xFF34D399),
                                    label: 'Sensor Node',
                                  ),
                                  _LegendItem(
                                    color: Color(0xFFFBBF24),
                                    label: 'Actuator',
                                  ),
                                  _LegendItem(
                                    color: Color(0xFF64748B),
                                    label: 'Ô 500m²',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ── Bảng Chi tiết Báo giá Phần cứng (Tham khảo) chuẩn FE ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: const Color(0xFFF1F5F9),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: Color(0xFF475569),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Chi tiết Báo giá Phần cứng (Tham khảo)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildQuoteRow(
                          icon: Icons.wifi,
                          iconColor: const Color(0xFF0284C7),
                          title: 'LoRa Gateway × ${sim.gateways}',
                          amount: sim.gateways * sim.gatewayUnitPrice,
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildQuoteRow(
                          icon: Icons.radio,
                          iconColor: const Color(0xFF059669),
                          title: 'Sensor Node × ${sim.sensors}',
                          amount: sim.sensors * sim.sensorUnitPrice,
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildQuoteRow(
                          icon: Icons.bolt,
                          iconColor: const Color(0xFFD97706),
                          title: 'Van/Bơm Actuator × ${sim.actuators}',
                          amount: sim.actuators * sim.actuatorUnitPrice,
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        _buildQuoteRow(
                          icon: Icons.build_outlined,
                          iconColor: const Color(0xFF64748B),
                          title: 'Phí lắp đặt & cấu hình (flat)',
                          amount: sim.installationFee,
                        ),
                        // Total Row (Emerald highlight)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            border: Border(
                              top: BorderSide(color: Color(0xFFA7F3D0)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.trending_up,
                                    size: 16,
                                    color: Color(0xFF065F46),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Tổng ước tính:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatVND(sim.totalDeviceCostVND),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                  Text(
                                    'Dao động: ${_formatVND(sim.minCostVND)} – ${_formatVND(sim.maxCostVND)}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Template VietGAP info ──
                  if (sim.growthCycle.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.eco,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Chu kỳ sinh trưởng & Điều kiện (${sim.cropName.split(' ')[0]})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildTemplateRow('Chu kỳ:', sim.growthCycle),
                          _buildTemplateRow('Dinh dưỡng:', sim.nutritionInfo),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTemplateRow(
                                  'Nhiệt độ:',
                                  sim.tempRange,
                                ),
                              ),
                              Expanded(
                                child: _buildTemplateRow(
                                  'Độ ẩm:',
                                  sim.humidityRange,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTemplateRow(
                                  'Ánh sáng:',
                                  sim.lightRequirement,
                                ),
                              ),
                              Expanded(
                                child: _buildTemplateRow(
                                  'Thời vụ:',
                                  sim.seasonDuration,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // ── Disclaimer Box chuẩn FE ──
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Color(0xFFD97706),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ Lưu ý: Ước tính giá có thể lệch với đơn giá của Kỹ thuật viên',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Chi phí trên chỉ mang tính tham khảo dựa trên mô hình tổ ong tiêu chuẩn. Đơn giá thực tế sẽ do Kỹ thuật viên Platform khảo sát thực địa và chốt trong Hợp đồng điện tử.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFB45309),
                                  height: 1.3,
                                ),
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
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double amount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ],
          ),
          Text(
            _formatVND(amount),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 9),
        ),
      ],
    );
  }
}

/// CustomPainter vẽ mạng tổ ong (Lục giác) chuẩn xác với LoRa Gateway tại tâm
class HoneycombMeshPainter extends CustomPainter {
  final int cellCount;
  final int gatewayCount;
  final int sensorCount;

  HoneycombMeshPainter({
    required this.cellCount,
    required this.gatewayCount,
    required this.sensorCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 4);
    const radius = 24.0; // Bán kính mỗi ô lục giác
    final h = radius * math.sqrt(3);

    final hexBorderPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final hexFillPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final centerHexFillPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final loraCirclePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final loraBorderPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Vẽ vùng phủ sóng LoRa RF tỏa ra từ tâm
    canvas.drawCircle(center, radius * 2.8, loraCirclePaint);
    canvas.drawCircle(center, radius * 2.8, loraBorderPaint);

    // 2. Tọa độ các ô lục giác bao quanh tâm (mô hình tổ ong)
    final hexOffsets = <Offset>[
      center, // Ô trung tâm (Gateway)
      Offset(center.dx, center.dy - h),
      Offset(center.dx + radius * 1.5, center.dy - h / 2),
      Offset(center.dx + radius * 1.5, center.dy + h / 2),
      Offset(center.dx, center.dy + h),
      Offset(center.dx - radius * 1.5, center.dy + h / 2),
      Offset(center.dx - radius * 1.5, center.dy - h / 2),
      Offset(center.dx, center.dy - 2 * h),
      Offset(center.dx + radius * 3, center.dy),
      Offset(center.dx - radius * 3, center.dy),
    ];

    final drawCount = math.min(cellCount + 1, hexOffsets.length);

    // Đường nối LoRa Mesh RF từ các sensor về Gateway
    final linePaint = Paint()
      ..color = const Color(0xFF34D399).withValues(alpha: 0.35)
      ..strokeWidth = 0.9;

    for (int i = 1; i < drawCount; i++) {
      canvas.drawLine(center, hexOffsets[i], linePaint);
    }

    // Vẽ từng lục giác
    for (int i = 0; i < drawCount; i++) {
      final p = hexOffsets[i];
      final path = Path();
      for (int corner = 0; corner < 6; corner++) {
        final angle = (corner * 60 + 30) * math.pi / 180;
        final x = p.dx + radius * math.cos(angle);
        final y = p.dy + radius * math.sin(angle);
        if (corner == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      canvas.drawPath(path, i == 0 ? centerHexFillPaint : hexFillPaint);
      canvas.drawPath(path, hexBorderPaint);

      // Điểm Node tại tâm ô
      if (i == 0) {
        // Gateway tại tâm
        final gwPaint = Paint()..color = const Color(0xFF38BDF8);
        canvas.drawCircle(p, 5.5, gwPaint);
        final gwRing = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(p, 7.5, gwRing);
      } else {
        // Sensor Node
        final sensorDot = Paint()..color = const Color(0xFF10B981);
        canvas.drawCircle(p, 3.5, sensorDot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HoneycombMeshPainter oldDelegate) {
    return oldDelegate.cellCount != cellCount ||
        oldDelegate.gatewayCount != gatewayCount ||
        oldDelegate.sensorCount != sensorCount;
  }
}
