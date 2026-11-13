import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';
import 'device_health_loader.dart';

/// Tình trạng thiết bị IoT (gateway & node) theo dữ liệu thật của backend.
/// Phát hiện lỗi theo thời gian im lặng (last seen + timeout), không đếm gói rớt vì LoRa mất gói là bình thường.
class DeviceHealthScreen extends StatefulWidget {
  const DeviceHealthScreen({super.key});

  @override
  State<DeviceHealthScreen> createState() => _DeviceHealthScreenState();
}

class _DeviceHealthScreenState extends State<DeviceHealthScreen> {
  Future<List<DeviceHealthModel>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    final f = loadDeviceHealth(context.read<FarmProvider>());
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // Lỗi được hiển thị bởi FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Sức Khỏe Thiết Bị IoT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _reload,
            tooltip: 'Tải lại từ máy chủ',
          ),
        ],
      ),
      body: FutureBuilder<List<DeviceHealthModel>>(
        future: _future,
        builder: (context, snap) {
          if (_future == null || snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 36,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Không tải được tình trạng thiết bị: ${snap.error.toString().replaceFirst('Exception: ', '')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final devices = snap.data!;
          final online = devices
              .where((d) => d.healthStatus == 'ONLINE')
              .length;
          final warning = devices
              .where((d) => d.healthStatus == 'WARNING')
              .length;
          final offline = devices
              .where((d) => d.healthStatus == 'OFFLINE')
              .length;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'ONLINE',
                        online,
                        const Color(0xFF059669),
                        const Color(0xFFECFDF5),
                        Icons.wifi,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryCard(
                        'CẢNH BÁO',
                        warning,
                        const Color(0xFFD97706),
                        const Color(0xFFFFFBEB),
                        Icons.signal_wifi_statusbar_connected_no_internet_4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryCard(
                        'OFFLINE',
                        offline,
                        const Color(0xFFDC2626),
                        const Color(0xFFFEF2F2),
                        Icons.wifi_off,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Text(
                    'Trạng thái tính theo thời điểm nhận dữ liệu gần nhất so với chu kỳ gửi của từng thiết bị:\n'
                    '• ≤ 3× chu kỳ → ONLINE\n'
                    '• 3–12× chu kỳ → CẢNH BÁO (mất sóng tạm thời)\n'
                    '• > 12× chu kỳ hoặc chưa từng nhận dữ liệu → OFFLINE (cần kiểm tra thực địa)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0369A1),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'DANH SÁCH THIẾT BỊ (${devices.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có gateway hoặc node nào được lắp đặt.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ...devices.map((device) => _DeviceCard(device: device)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(
    String label,
    int count,
    Color color,
    Color bgColor,
    IconData icon,
  ) {
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
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      case 'ONLINE':
        return const Color(0xFF059669);
      case 'WARNING':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFFDC2626);
    }
  }

  Color get _statusBgColor {
    switch (device.healthStatus) {
      case 'ONLINE':
        return const Color(0xFFECFDF5);
      case 'WARNING':
        return const Color(0xFFFFFBEB);
      default:
        return const Color(0xFFFEF2F2);
    }
  }

  IconData get _deviceIcon {
    switch (device.type) {
      case 'GATEWAY':
        return Icons.router;
      case 'SENSOR_NODE':
        return Icons.sensors;
      default:
        return Icons.electrical_services;
    }
  }

  Color get _batteryColor {
    final pct = device.batteryPercent;
    if (pct == null) return const Color(0xFF64748B);
    if (pct > 60) return const Color(0xFF059669);
    if (pct > 25) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String get _timeoutExplanation {
    final seen = device.lastSeenAt;
    if (seen == null) return 'Chưa nhận được dữ liệu nào từ thiết bị này.';
    final gapSecs = DateTime.now().difference(seen).inSeconds;
    final warningThreshold = device.expectedIntervalSeconds * 3;
    final criticalThreshold = device.expectedIntervalSeconds * 12;
    switch (device.healthStatus) {
      case 'ONLINE':
        return 'Còn ${warningThreshold - gapSecs}s nữa đến ngưỡng cảnh báo';
      case 'WARNING':
        return 'Mất tín hiệu ${device.lastSeenText} (cảnh báo > ${warningThreshold}s, nghiêm trọng > ${criticalThreshold}s)';
      default:
        return 'Mất liên lạc ${device.lastSeenText} – cần kiểm tra thực địa.';
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
          color: device.healthStatus == 'ONLINE'
              ? const Color(0xFFE2E8F0)
              : _statusColor.withValues(alpha: 0.4),
          width: device.healthStatus == 'ONLINE' ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
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
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      device.nodeId,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  device.healthStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _stat(Icons.access_time, 'Lần cuối', device.lastSeenText),
              _stat(
                Icons.signal_cellular_alt,
                'RSSI',
                device.signalRssi == null
                    ? '—'
                    : '${device.signalRssi!.toInt()} dBm',
              ),
              _stat(
                Icons.battery_full,
                'Pin',
                device.batteryPercent == null
                    ? '—'
                    : '${device.batteryPercent}%',
                valueColor: _batteryColor,
              ),
              _stat(
                Icons.timer,
                'Chu kỳ',
                '${device.expectedIntervalSeconds}s',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _timeoutExplanation,
            style: TextStyle(fontSize: 11, color: _statusColor),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
