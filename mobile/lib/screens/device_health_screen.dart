import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';

/// Màn hình Device Health – Giải quyết Vấn đề 4
/// Sử dụng Timeout-based detection thay vì miss-packet counting
class DeviceHealthScreen extends StatefulWidget {
  const DeviceHealthScreen({super.key});

  @override
  State<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends State<DeviceHealthScreen> {
  // Refresh để cập nhật healthStatus theo thời gian thực
  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final devices = provider.deviceHealthList;

    final online = devices.where((d) => d.healthStatus == 'ONLINE').length;
    final warning = devices.where((d) => d.healthStatus == 'WARNING').length;
    final offline = devices.where((d) => d.healthStatus == 'OFFLINE').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sức Khỏe Thiết Bị IoT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Timeout-based Detection (Vấn đề 4)', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
            tooltip: 'Làm mới trạng thái',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Bar
            Row(
              children: [
                Expanded(child: _summaryCard('ONLINE', online, const Color(0xFF059669), const Color(0xFFECFDF5), Icons.wifi)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard('CẢNH BÁO', warning, const Color(0xFFD97706), const Color(0xFFFFFBEB), Icons.signal_wifi_statusbar_connected_no_internet_4)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard('OFFLINE', offline, const Color(0xFFDC2626), const Color(0xFFFEF2F2), Icons.wifi_off)),
              ],
            ),

            const SizedBox(height: 16),

            // Explanation about timeout mechanism
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF0284C7)),
                      SizedBox(width: 8),
                      Text('Cơ chế phát hiện lỗi (Đã sửa theo phản biện GV)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '✅ ĐÚNG: Dùng Last Seen Timestamp + Timeout\n'
                    '   • < 3× chu kỳ gửi → ONLINE\n'
                    '   • 3–12× chu kỳ gửi → CẢNH BÁO (mất sóng tạm thời)\n'
                    '   • > 12× chu kỳ gửi → OFFLINE (cần kiểm tra thực địa)\n\n'
                    '❌ SAI (đã bỏ): Đếm số lần miss gói tin liên tiếp\n'
                    '   → LoRa RF môi trường mất gói bình thường do nhiễu',
                    style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text('DANH SÁCH THIẾT BỊ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
            const SizedBox(height: 10),

            ...devices.map((device) => _DeviceCard(device: device)),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, int count, Color color, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceHealthModel device;

  const _DeviceCard({required this.device});

  Color get _statusColor {
    switch (device.healthStatus) {
      case 'ONLINE': return const Color(0xFF059669);
      case 'WARNING': return const Color(0xFFD97706);
      default: return const Color(0xFFDC2626);
    }
  }

  Color get _statusBgColor {
    switch (device.healthStatus) {
      case 'ONLINE': return const Color(0xFFECFDF5);
      case 'WARNING': return const Color(0xFFFFFBEB);
      default: return const Color(0xFFFEF2F2);
    }
  }

  IconData get _deviceIcon {
    switch (device.type) {
      case 'GATEWAY': return Icons.router;
      case 'SENSOR_NODE': return Icons.sensors;
      default: return Icons.electrical_services;
    }
  }

  Color get _batteryColor {
    if (device.batteryPercent > 60) return const Color(0xFF059669);
    if (device.batteryPercent > 25) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String get _timeoutExplanation {
    final gapSecs = DateTime.now().difference(device.lastSeenAt).inSeconds;
    final warningThreshold = device.expectedIntervalSeconds * 3;
    final criticalThreshold = device.expectedIntervalSeconds * 12;

    if (device.healthStatus == 'ONLINE') {
      return 'Còn ${warningThreshold - gapSecs}s nữa đến ngưỡng Warning';
    } else if (device.healthStatus == 'WARNING') {
      return 'Mất tín hiệu ${device.lastSeenText} (Warning >${warningThreshold}s, Critical >${criticalThreshold}s)';
    } else {
      return 'Mất liên lạc >${device.lastSeenText} – Cần kiểm tra thực địa ngay!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: device.healthStatus == 'ONLINE' ? const Color(0xFFE2E8F0) : _statusColor.withValues(alpha: 0.4),
          width: device.healthStatus == 'ONLINE' ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _statusBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_deviceIcon, color: _statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    Text(device.nodeId, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _statusBgColor, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(device.healthStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats Row
          Row(
            children: [
              _stat(Icons.access_time, 'Last Seen', device.lastSeenText),
              const SizedBox(width: 16),
              _stat(Icons.signal_cellular_alt, 'RSSI', '${device.signalRssi.toInt()} dBm'),
              const SizedBox(width: 16),
              _stat(Icons.battery_full, 'Pin', '${device.batteryPercent}%', valueColor: _batteryColor),
              const SizedBox(width: 16),
              _stat(Icons.timer, 'Chu kỳ', '${device.expectedIntervalSeconds}s'),
            ],
          ),

          const SizedBox(height: 10),

          // Timeout explanation
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _statusBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  device.healthStatus == 'ONLINE' ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  size: 14, color: _statusColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_timeoutExplanation, style: TextStyle(fontSize: 10, color: _statusColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor ?? const Color(0xFF0F172A))),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
      ],
    );
  }
}
