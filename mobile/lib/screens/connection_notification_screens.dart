import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/iot_deployment.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';

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
    final farmId = Provider.of<FarmProvider>(context, listen: false).selectedFarmId;
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
      final gateways = await ApiService.getFarmGateways(farmId);
      final states = await Future.wait(gateways.map((g) async {
        try {
          final r = await ApiService.getGatewayMqttStatus(g.gatewayId);
          return GatewayMqttState(g, r['mqttConnected'] == true, null, DateTime.now());
        } catch (e) {
          return GatewayMqttState(g, null, e.toString().replaceFirst('Exception: ', ''), DateTime.now());
        }
      }));
      if (mounted) setState(() => _states = states);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _hhmmss(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trạng thái MQTT'),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: 'Làm mới', onPressed: _loading ? null : _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626))),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                ])))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _states.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Trang trại này chưa có gateway nào.'))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: _states.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = _states[i];
                            final (label, color) = s.connected == null
                                ? ('Không xác định', const Color(0xFFD97706))
                                : s.connected!
                                    ? ('Đang kết nối', const Color(0xFF059669))
                                    : ('Mất kết nối', const Color(0xFFDC2626));
                            return Card(
                              child: ListTile(
                                leading: Icon(Icons.wifi, color: color),
                                title: Text(s.gateway.gatewaySerial.isEmpty ? s.gateway.macAddress : s.gateway.gatewaySerial),
                                subtitle: Text('${s.error ?? label} · cập nhật ${_hhmmss(s.checkedAt)}'),
                                trailing: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
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
      appBar: AppBar(title: const Text('Cài đặt thông báo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.notifications_active, color: Color(0xFF059669)),
            title: Text('Thông báo trong ứng dụng'),
            subtitle: Text('Đang hoạt động: nhận từ máy chủ (mục Cảnh báo & Thông báo).'),
          ),
          Divider(),
          ListTile(
            enabled: false,
            leading: Icon(Icons.phone_android),
            title: Text('Push notification'),
            subtitle: Text('Chưa khả dụng: backend chưa có dịch vụ gửi push và API đăng ký thiết bị.'),
            trailing: Switch(value: false, onChanged: null),
          ),
          ListTile(
            enabled: false,
            leading: Icon(Icons.sms_outlined),
            title: Text('Tin nhắn SMS'),
            subtitle: Text('Chưa khả dụng: backend chưa có dịch vụ gửi SMS và API lưu tuỳ chọn.'),
            trailing: Switch(value: false, onChanged: null),
          ),
          SizedBox(height: 12),
          Text(
            'API còn thiếu: lưu/đọc tuỳ chọn thông báo theo người dùng, đăng ký token thiết bị (FCM/APNs) và nhà cung cấp SMS.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
