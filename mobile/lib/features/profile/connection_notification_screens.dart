import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/user_error.dart';

class GatewayMqttState {
  final IotGateway gateway;
  final bool? connected; // null = không lấy được
  final String? error;
  final DateTime checkedAt;
  GatewayMqttState(this.gateway, this.connected, this.error, this.checkedAt);
}

/// Trạng thái MQTT lấy từ backend (GET /gateways/{id}/mqtt-status). App không kết nối trực tiếp tới broker.
class MqttStatusScreen extends StatefulWidget {
  const MqttStatusScreen({super.key});

  @override
  State<MqttStatusScreen> createState() => _MqttStatusScreenState();
}

class _MqttStatusScreenState extends State<MqttStatusScreen> {
  List<GatewayMqttState> _states = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    if (provider.currentRole != 'OWNER' &&
        provider.currentRole != 'TECHNICIAN') {
      setState(() {
        _loading = false;
        _error =
            'Bạn không có quyền xem trạng thái MQTT (Yêu cầu tài khoản Chủ trang trại hoặc Kỹ thuật viên).';
      });
      return;
    }
    final farmId = provider.selectedFarmId;
    if (farmId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Chưa chọn trang trại.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final gateways = await DeploymentApi.getFarmGateways(farmId);
      final states = await Future.wait(
        gateways.map((g) async {
          try {
            final r = await SupportApi.getGatewayMqttStatus(g.gatewayId);
            return GatewayMqttState(
              g,
              r['mqttConnected'] == true,
              null,
              DateTime.now(),
            );
          } catch (e) {
            final msg = userFacingError(e);
            final is403 =
                msg.contains('403') || msg.toLowerCase().contains('forbidden');
            return GatewayMqttState(
              g,
              null,
              is403 ? 'Không có quyền truy cập trạng thái MQTT (403)' : msg,
              DateTime.now(),
            );
          }
        }),
      );
      if (mounted) setState(() => _states = states);
    } catch (e) {
      if (mounted) {
        final msg = userFacingError(e);
        final is403 =
            msg.contains('403') || msg.toLowerCase().contains('forbidden');
        setState(
          () => _error = is403
              ? 'Bạn không có quyền xem trạng thái MQTT (403 Forbidden - Yêu cầu tài khoản Chủ trang trại hoặc Kỹ thuật viên).'
              : msg,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Trạng Thái MQTT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _states.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text('Trang trại này chưa có gateway nào.'),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _states.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _states[i];
                        final (label, color) = s.connected == null
                            ? ('Không xác định', const Color(0xFFD97706))
                            : s.connected!
                            ? ('Đang kết nối', const Color(0xFF047857))
                            : ('Mất kết nối', const Color(0xFFDC2626));
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.wifi,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.gateway.gatewaySerial.isEmpty
                                            ? s.gateway.macAddress
                                            : s.gateway.gatewaySerial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${s.error ?? label} · cập nhật ${_hhmmss(s.checkedAt)}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

/// Cài đặt thông báo. Backend hiện chỉ có hộp thư thông báo trong ứng dụng; chưa có dịch vụ Push/SMS
/// và chưa có API lưu tuỳ chọn, nên các tuỳ chọn đó được hiển thị là chưa khả dụng (không giả lập đã bật).
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Cài Đặt Thông Báo',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: const [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(
                      Icons.notifications_active,
                      color: Color(0xFF047857),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Thông báo trong ứng dụng',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    'Đang hoạt động: nhận từ máy chủ (mục Cảnh báo & Thông báo).',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  enabled: false,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(
                      Icons.phone_android,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Push notification',
                    style: TextStyle(fontSize: 13.5),
                  ),
                  subtitle: Text(
                    'Chưa khả dụng: backend chưa có dịch vụ gửi push và API đăng ký thiết bị.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  trailing: Switch(value: false, onChanged: null),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  enabled: false,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFFF1F5F9),
                    child: Icon(
                      Icons.sms_outlined,
                      color: Color(0xFF94A3B8),
                      size: 20,
                    ),
                  ),
                  title: Text('Tin nhắn SMS', style: TextStyle(fontSize: 13.5)),
                  subtitle: Text(
                    'Chưa khả dụng: backend chưa có dịch vụ gửi SMS và API lưu tuỳ chọn.',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  trailing: Switch(value: false, onChanged: null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Ghi chú hệ thống: Tuỳ chọn thông báo thời gian thực được đồng bộ trực tiếp từ máy chủ SmartFarm Core.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
