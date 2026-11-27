import 'dart:convert';
import 'package:flutter/material.dart';

/// Modal hiển thị dự toán thuật toán Tổ ong bất biến (JSON Snapshot) đã lưu cùng yêu cầu triển khai IoT.
/// Đồng bộ 100% với EstimateSnapshotModal.tsx trên Web.
class EstimateSnapshotDialog extends StatelessWidget {
  final String snapshotJson;

  const EstimateSnapshotDialog({super.key, required this.snapshotJson});

  static Future<void> show(BuildContext context, String snapshotJson) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EstimateSnapshotDialog(snapshotJson: snapshotJson),
    );
  }

  Map<String, dynamic>? get _data {
    try {
      final decoded = jsonDecode(snapshotJson);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  String _formatVnd(num value) {
    final s = value.round().toString();
    final parts = <String>[];
    for (int i = s.length; i > 0; i -= 3) {
      final start = (i - 3 < 0) ? 0 : i - 3;
      parts.insert(0, s.substring(start, i));
    }
    return '${parts.join('.')} đ';
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      final intVal = value.round();
      final s = intVal.toString();
      final chunks = <String>[];
      for (int i = s.length; i > 0; i -= 3) {
        final start = (i - 3 < 0) ? 0 : i - 3;
        chunks.insert(0, s.substring(start, i));
      }
      return chunks.join('.');
    }
    final s = value.toString();
    final parts = s.split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? ',${parts[1]}' : '';
    final chunks = <String>[];
    for (int i = intPart.length; i > 0; i -= 3) {
      final start = (i - 3 < 0) ? 0 : i - 3;
      chunks.insert(0, intPart.substring(start, i));
    }
    return '${chunks.join('.')}$decPart';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calculate_rounded,
                      color: Color(0xFF047857),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Dự toán thuật toán Tổ ong đã lưu',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: data == null
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Chưa có dữ liệu dự toán thuật toán được lưu cho yêu cầu này.',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 4-Card Summary Grid
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  'Diện tích',
                                  '${_formatNumber(data['areaM2'] ?? 0)} m²',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  'Gateway',
                                  '${data['gateways'] ?? 0}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  'Sensor Node',
                                  '${data['sensors'] ?? 0}',
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _statCard(
                                  'Actuator',
                                  '${data['actuators'] ?? 0}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Algorithm Banner
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.hive_outlined,
                                      size: 18,
                                      color: Color(0xFF047857),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mạng Tổ ong · ${data['algorithmVersion'] ?? 'v1'}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bán kính ${data['sensingRadiusM'] ?? '—'}m/node · Hệ số phủ biên ${data['boundaryFactor'] ?? '—'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatVnd(data['totalCostVnd'] ?? 0),
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Items List
                          const Text(
                            'Chi tiết hạng mục dự toán:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                children: [
                                  for (
                                    int i = 0;
                                    i <
                                        (data['estimateItems'] as List? ??
                                                const [])
                                            .length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        color: Color(0xFFF1F5F9),
                                      ),
                                    _itemRow(
                                      (data['estimateItems'] as List)[i]
                                          as Map<String, dynamic>,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final name = '${item['name'] ?? item['role'] ?? ''}';
    final role = '${item['role'] ?? ''}';
    final qty = item['quantity'] ?? 1;
    final unitPrice = item['unitPrice'] as num?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$role · $qty thiết bị',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            unitPrice != null && unitPrice > 0 ? _formatVnd(unitPrice) : '—',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
