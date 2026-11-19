import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/iot_deployment.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/state_views.dart' show friendlyError;
import '../../core/utils/paging.dart';
import '../../core/widgets/page_bar.dart';
import '../inventory/stock_out_screen.dart';
import 'technician_stock_logic.dart';
import '../../core/utils/user_error.dart';

/// Trung tâm Quản lý Thiết bị & Phần cứng của Kỹ thuật viên (Đầy đủ tính năng như Web):
/// 1. Gateway ESP32: Quản lý Gateway đã enrollment, MQTT heartbeat, kiểm tra cấu hình, enrollment mới.
/// 2. Kho & Xuất kho IoT: Kho linh kiện cá nhân KTV, nhận/trả kho và lập phiếu xuất kho thiết bị.
class TechnicianDevicesScreen extends StatefulWidget {
  const TechnicianDevicesScreen({super.key});

  @override
  State<TechnicianDevicesScreen> createState() =>
      _TechnicianDevicesScreenState();
}

class _TechnicianDevicesScreenState extends State<TechnicianDevicesScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Quản Lý Thiết Bị & Phần Cứng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFF94A3B8),
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 13),
            tabs: [
              Tab(
                icon: Icon(Icons.router_outlined, size: 18),
                text: 'Gateway ESP32',
              ),
              Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Kho & Xuất kho',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_GatewaysTab(), _SparePartsAndStockOutTab()],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: GATEWAY ESP32 (Tương đương GatewaysPage.tsx + GatewayEnrollmentPage.tsx)
// ─────────────────────────────────────────────────────────────────────────────

class _GatewaysTab extends StatefulWidget {
  const _GatewaysTab();

  @override
  State<_GatewaysTab> createState() => _GatewaysTabState();
}

class _GatewaysTabState extends State<_GatewaysTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _gateways = [];
  final Map<String, Map<String, dynamic>> _details = {};
  final Set<String> _inspecting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await DeploymentApi.getTechnicianDeploymentRequests();
      final farmIds = requests
          .map((r) => r.farmId)
          .where((id) => id.isNotEmpty)
          .toSet();

      final results = await Future.wait(
        farmIds.map(
          (id) => DeploymentApi.getFarmGatewaysRaw(
            id,
          ).catchError((_) => <Map<String, dynamic>>[]),
        ),
      );
      final all = results.expand((list) => list).toList();

      // Loại bỏ gateway trùng lặp theo ID
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final g in all) {
        final id = '${g['gatewayId'] ?? g['id'] ?? ''}';
        if (id.isNotEmpty && !seen.contains(id)) {
          seen.add(id);
          unique.add(g);
        }
      }

      if (mounted) {
        setState(() {
          _gateways = unique;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingError(e);
          _loading = false;
        });
      }
    }
  }

  bool _hasHeartbeat(Map<String, dynamic> gateway) {
    final lastSeenStr = gateway['lastSeenAtUtc']?.toString();
    if (lastSeenStr == null || lastSeenStr.isEmpty) return false;
    final lastSeen = DateTime.tryParse(lastSeenStr);
    if (lastSeen == null) return false;
    final intervalSec =
        (gateway['telemetryIntervalSec'] as num?)?.toInt() ?? 60;
    final timeout = Duration(seconds: intervalSec > 0 ? intervalSec + 30 : 90);
    return DateTime.now().toUtc().difference(lastSeen) <= timeout;
  }

  Future<void> _inspect(String id) async {
    setState(() => _inspecting.add(id));
    try {
      final mqtt = await SupportApi.getGatewayMqttStatus(
        id,
      ).catchError((_) => <String, dynamic>{});
      final config = await DeploymentApi.getGatewayFirmwareConfig(
        id,
      ).catchError((_) => <String, dynamic>{});
      if (mounted) {
        setState(() {
          _details[id] = {'mqtt': mqtt, 'config': config};
          _inspecting.remove(id);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _inspecting.remove(id));
    }
  }

  Future<void> _openEnrollmentDialog() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _GatewayEnrollmentSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _gateways.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    final totalEnrolled = _gateways.length;
    final onlineCount = _gateways.where(_hasHeartbeat).length;
    final provisionedCount = _gateways
        .where((x) => '${x['status']}'.toLowerCase() == 'provisioned')
        .length;
    final configuredCount = _gateways
        .where(
          (x) =>
              (x['configVersion'] as num? ?? 0) > 0 ||
              x['configuredAtUtc'] != null,
        )
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner hành động đầu trang
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quản lý Gateway ESP32',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Theo dõi Gateway đã enrollment và kiểm tra MQTT heartbeat thực tế.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openEnrollmentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Enrollment'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Thẻ KPI chuẩn Web
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _kpiCard(
                'Đã enrollment',
                '$totalEnrolled',
                const Color(0xFF0F172A),
                const Color(0xFFF1F5F9),
              ),
              _kpiCard(
                'MQTT heartbeat thật',
                '$onlineCount',
                const Color(0xFF047857),
                const Color(0xFFECFDF5),
              ),
              _kpiCard(
                'Provisioned',
                '$provisionedCount',
                const Color(0xFF0284C7),
                const Color(0xFFF0F9FF),
              ),
              _kpiCard(
                'Có cấu hình',
                '$configuredCount',
                const Color(0xFF7C3AED),
                const Color(0xFFF5F3FF),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
              ),
            ),

          if (_gateways.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.router_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có Gateway nào được enrollment.'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _openEnrollmentDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Khai báo Gateway mới ngay'),
                  ),
                ],
              ),
            )
          else
            ..._gateways.map((g) {
              final id = '${g['gatewayId'] ?? g['id'] ?? ''}';
              final serial =
                  '${g['gatewaySerial'] ?? g['serialNumber'] ?? 'Gateway'}';
              final mac = '${g['macAddress'] ?? '—'}';
              final fw = '${g['firmwareVersion'] ?? '—'}';
              final cfgVer = g['configVersion'] ?? 0;
              final isOnline = _hasHeartbeat(g);
              final d = _details[id];
              final isBusy = _inspecting.contains(id);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.router,
                                    size: 20,
                                    color: isOnline
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        'MAC: $mac · ID: $id',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isOnline
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOnline
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isOnline ? 'Online' : 'Provisioned',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOnline
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Firmware: $fw · Config v$cfgVer',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline
                            ? 'MQTT heartbeat: ${g['lastSeenAtUtc'] ?? 'Vừa nhận'}'
                            : 'Chưa nhận MQTT heartbeat thật',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isOnline
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Nút kiểm tra trạng thái
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: isBusy ? null : () => _inspect(id),
                            icon: isBusy
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.settings_outlined, size: 14),
                            label: const Text('Kiểm tra trạng thái'),
                            style: OutlinedButton.styleFrom(
                              textStyle: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (d != null) ...[
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
                                    Icons.wifi,
                                    size: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Dữ liệu MQTT:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    d['mqtt']?['connected'] == true
                                        ? 'Đã kết nối'
                                        : 'Chưa kết nối',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shield_outlined,
                                    size: 14,
                                    color: Color(0xFF047857),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Node Registry: ${d['config']?['nodes'] is List ? (d['config']['nodes'] as List).length : 0} nodes',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color textCol, Color bgCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textCol.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textCol.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayEnrollmentSheet extends StatefulWidget {
  const _GatewayEnrollmentSheet();

  @override
  State<_GatewayEnrollmentSheet> createState() =>
      _GatewayEnrollmentSheetState();
}

class _GatewayEnrollmentSheetState extends State<_GatewayEnrollmentSheet> {
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _gwParts = [];
  List<DeploymentRequest> _depRequests = [];
  String? _selectedHardwareId;
  String? _selectedDepId;
  final _macCtrl = TextEditingController();
  final _chipCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  Map<String, dynamic>? _enrollmentResult;

  @override
  void initState() {
    super.initState();
    _loadPrereqs();
  }

  Future<void> _loadPrereqs() async {
    setState(() => _busy = true);
    try {
      final parts = await DeploymentApi.getTechnicianSpareParts();
      final deps = await DeploymentApi.getTechnicianDeploymentRequests();
      if (mounted) {
        setState(() {
          _gwParts = parts
              .where(
                (p) => '${p['category']}'.toUpperCase().contains('GATEWAY'),
              )
              .toList();
          _depRequests = deps;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onPickHardware(String? id) {
    setState(() {
      _selectedHardwareId = id;
      final item = _gwParts.where((p) => '${p['id']}' == id).firstOrNull;
      if (item != null) {
        _macCtrl.text = '${item['macAddress'] ?? ''}';
        _serialCtrl.text = '${item['serialNumber'] ?? item['code'] ?? ''}';
        final macClean = _macCtrl.text
            .replaceAll(RegExp(r'[^0-9A-Fa-f]'), '')
            .toUpperCase();
        _chipCtrl.text = 'ESP32-$macClean';
      }
    });
  }

  Future<void> _enroll() async {
    final mac = _macCtrl.text.trim();
    final chip = _chipCtrl.text.trim();
    if (mac.isEmpty || chip.isEmpty) {
      setState(() => _error = 'Vui lòng nhập MAC Address và Chip ID.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await DeploymentApi.simulateGatewayAutoEnroll(
        macAddress: mac,
        chipId: chip,
        gatewaySerial: _serialCtrl.text.trim().isNotEmpty
            ? _serialCtrl.text.trim()
            : null,
      );
      if (mounted) {
        setState(() {
          _enrollmentResult = res;
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Đăng ký thất bại: ${userFacingError(e)}';
          _busy = false;
        });
      }
    }
  }

  Future<void> _activate() async {
    if (_enrollmentResult == null || _selectedDepId == null) {
      setState(() => _error = 'Vui lòng chọn Yêu cầu triển khai.');
      return;
    }
    final enrollmentId = '${_enrollmentResult!['id']}';
    final dep = _depRequests
        .where((d) => d.requestId == _selectedDepId)
        .firstOrNull;
    if (dep == null || dep.farmId.isEmpty) {
      setState(() => _error = 'Yêu cầu không hợp lệ.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DeploymentApi.activateGatewayEnrollment(
        enrollmentId,
        farmId: dep.farmId,
        deploymentRequestId: dep.requestId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã kích hoạt Gateway ESP32 vào Farm thành công!'),
            backgroundColor: Color(0xFF047857),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kích hoạt thất bại: ${userFacingError(e)}';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gateway Enrollment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Text(
              'Đăng ký Gateway mới (MAC/Serial) và kích hoạt vào Farm/Deployment Request.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBE123C),
                  ),
                ),
              ),

            // Bước 1: Chọn từ kho
            const Text(
              '1. Chọn Gateway từ kho KTV:',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedHardwareId,
              hint: const Text(
                'Chọn linh kiện Gateway',
                style: TextStyle(fontSize: 13),
              ),
              items: _gwParts
                  .map(
                    (p) => DropdownMenuItem(
                      value: '${p['id']}',
                      child: Text(
                        '${p['name']} (${p['code']})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _busy ? null : _onPickHardware,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _macCtrl,
              decoration: InputDecoration(
                labelText: 'MAC Address',
                hintText: 'AA:BB:CC:DD:EE:FF',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _chipCtrl,
              decoration: InputDecoration(
                labelText: 'Chip ID',
                hintText: 'ESP32-123456',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _serialCtrl,
              decoration: InputDecoration(
                labelText: 'Gateway Serial',
                hintText: 'GW-01',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Nút đăng ký
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _enroll,
                icon: const Icon(Icons.how_to_reg, size: 16),
                label: const Text('Bước 1: Tự đăng ký Gateway (Auto-Enroll)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bước 2: Kích hoạt vào Farm
            if (_enrollmentResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF047857),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đã đăng ký: ${_enrollmentResult!['gatewaySerial'] ?? _enrollmentResult!['macAddress']}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '2. Kích hoạt vào Yêu cầu triển khai:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedDepId,
                hint: const Text(
                  'Chọn Deployment Request',
                  style: TextStyle(fontSize: 13),
                ),
                items: _depRequests.map((d) {
                  final id = d.requestId;
                  final shortId = id.length >= 8 ? id.substring(0, 8) : id;
                  return DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      'Yêu cầu #$shortId (${d.status})',
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _selectedDepId = v),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _activate,
                  icon: const Icon(Icons.power_settings_new, size: 16),
                  label: const Text('Bước 2: Kích hoạt Gateway vào Farm'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4: KHO & XUẤT KHO IOT (Tương đương InventoryPage.tsx + StockOutsPage.tsx)
// ─────────────────────────────────────────────────────────────────────────────

class _SparePartsAndStockOutTab extends StatefulWidget {
  const _SparePartsAndStockOutTab();

  @override
  State<_SparePartsAndStockOutTab> createState() =>
      _SparePartsAndStockOutTabState();
}

class _SparePartsAndStockOutTabState extends State<_SparePartsAndStockOutTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _parts = [];
  bool _busy = false;
  String _query = '';
  StockCategory _cat = StockCategory.all;
  int _page = 0; // trang của danh sách kho (10 mục/trang)

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await DeploymentApi.getTechnicianSpareParts();
      if (mounted) {
        setState(() {
          _parts = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userFacingError(e);
          _loading = false;
        });
      }
    }
  }

  /// Nhận thiết bị từ kho chính = LẬP PHIẾU XUẤT KHO (Draft → Gửi duyệt); Admin duyệt và hoàn thành trên web thì thiết bị mới
  /// chuyển vào kho của KTV lập phiếu. (KTV không tự gán hàng cho mình: API gán trực tiếp chỉ dành cho Admin.)
  Future<void> _receive() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const StockOutScreen(openCreate: true)),
    );
    if (mounted) await _load();
  }

  Future<void> _managePart(Map<String, dynamic> p) async {
    final name = p['name'] ?? 'Linh kiện';
    final code = p['code'] ?? '';
    final id = '${p['id']}';
    final currentStock = (p['quantityInStock'] as num?)?.toInt() ?? 0;
    final unit = p['unit'] ?? 'Cái';
    final ident = p['serialNumber'] ?? p['macAddress'] ?? 'Theo lô';
    final isFaulty = '${p['status']}'.toLowerCase() == 'faulty';
    int adjustQty = 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Quản lý: $name',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mã: $code',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                              fontSize: 13,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isFaulty
                                  ? const Color(0xFFFEE2E2)
                                  : (currentStock <= 0
                                        ? const Color(0xFFF1F5F9)
                                        : const Color(0xFFD1FAE5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isFaulty
                                  ? 'Báo lỗi'
                                  : (currentStock <= 0
                                        ? 'Đã cấp hết'
                                        : 'Đang giữ'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isFaulty
                                    ? const Color(0xFFDC2626)
                                    : (currentStock <= 0
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF065F46)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Định danh: $ident',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'Tồn kho hiện tại: $currentStock $unit',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Người thực hiện: Kỹ thuật viên hiện tại',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Số lượng điều chỉnh:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: adjustQty > 1
                          ? () => setSheetState(() => adjustQty--)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$adjustQty',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed:
                          adjustQty < (currentStock > 0 ? currentStock : 99)
                          ? () => setSheetState(() => adjustQty++)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _busy = true);
                        try {
                          await DeploymentApi.reportHardwareFault(id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Đã báo cáo thiết bị lỗi: $code'),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                          await _load();
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi: ${userFacingError(e)}'),
                              ),
                            );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                      icon: const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Color(0xFFDC2626),
                      ),
                      label: const Text(
                        'Báo cáo lỗi',
                        style: TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _return(p);
                      },
                      icon: const Icon(Icons.replay_rounded, size: 16),
                      label: const Text('Trả về kho'),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã điều chỉnh $adjustQty $unit.'),
                            backgroundColor: const Color(0xFF047857),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Lưu điều chỉnh'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _return(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trả linh kiện vào kho'),
        content: Text(
          'Xác nhận hoàn trả "${p['name']}" (x${(p['quantityInStock'] as num?)?.toInt() ?? 0}) về kho chính? Số lượng được cộng lại vào kho chính.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await DeploymentApi.returnHardwareItem('${p['id']}');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã trả linh kiện về kho chính.')),
        );
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không trả được: ${friendlyError(e)}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _kpi(String label, String value, Color fg, Color bg, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              Text(
                label,
                maxLines: 2,
                style: TextStyle(fontSize: 10.5, color: fg),
              ),
            ],
          ),
        ),
      );

  IconData _iconOf(StockCategory c) => switch (c) {
    StockCategory.gateway => Icons.router_outlined,
    StockCategory.node => Icons.developer_board,
    StockCategory.sensor => Icons.sensors,
    _ => Icons.memory_outlined,
  };

  Widget _partCard(Map<String, dynamic> p) {
    final rawPrice = p['unitPrice'] as num?;
    final priceText = rawPrice != null && rawPrice > 0
        ? NumberFormat.currency(
            locale: 'vi_VN',
            symbol: '₫',
            decimalDigits: 0,
          ).format(rawPrice)
        : null;
    final qty = partQty(p);
    final faulty = isFaultyPart(p);
    final cat = stockCategoryOf(p);
    final ident = p['serialNumber'] ?? p['macAddress'];
    final (badge, badgeFg, badgeBg) = faulty
        ? ('Báo lỗi', const Color(0xFFDC2626), const Color(0xFFFEE2E2))
        : (qty <= 0
              ? ('Đã cấp hết', const Color(0xFF64748B), const Color(0xFFF1F5F9))
              : ('Đang giữ', const Color(0xFF065F46), const Color(0xFFD1FAE5)));
    return Card(
      key: ValueKey('part-${p['id']}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: faulty
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    faulty ? Icons.warning_amber_rounded : _iconOf(cat),
                    color: faulty
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF334155),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p['code']} · ${cat.label}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        ident == null ? 'Hàng theo lô' : 'Định danh: $ident',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (priceText != null)
                        Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'x$qty',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _busy ? null : () => _managePart(p),
                  icon: const Icon(Icons.tune, size: 15),
                  label: const Text('Quản lý'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _busy || qty <= 0 ? null : () => _return(p),
                  icon: const Icon(Icons.undo, size: 15),
                  label: const Text('Trả kho'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = summarizeStock(_parts);
    final counts = countByCategory(_parts);
    final shown = sortNewestFirst(
      filterStock(_parts, query: _query, category: _cat),
      (p) => parseTime(p['createdAtUtc']),
    );
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Nhận thiết bị từ kho chính = lập phiếu xuất kho
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF047857)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF047857).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.outbox_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phiếu xuất kho thiết bị IoT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lập phiếu để nhận thiết bị từ kho chính; Admin hoàn thành thì thiết bị vào kho của bạn.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey('receive-from-main'),
                        onPressed: _busy ? null : _receive,
                        icon: const Icon(Icons.add, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Nhận từ kho chính'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF065F46),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StockOutScreen(),
                            ),
                          );
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Phiếu của tôi'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Kho của tôi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          Text(
            'Thiết bị đang giữ trước khi ra hiện trường. Gắn Node sẽ trừ thiết bị khỏi kho này.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),

          if (_parts.isNotEmpty) ...[
            Row(
              key: const ValueKey('stock-kpis'),
              children: [
                _kpi(
                  'Loại đang giữ',
                  '${summary.kinds}',
                  const Color(0xFF065F46),
                  const Color(0xFFD1FAE5),
                  Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 8),
                _kpi(
                  'Tổng số thiết bị',
                  '${summary.units}',
                  const Color(0xFF1D4ED8),
                  const Color(0xFFDBEAFE),
                  Icons.numbers,
                ),
                const SizedBox(width: 8),
                _kpi(
                  'Báo lỗi',
                  '${summary.faulty}',
                  summary.faulty > 0
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFF64748B),
                  summary.faulty > 0
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFF1F5F9),
                  Icons.warning_amber_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('stock-search'),
              decoration: InputDecoration(
                hintText: 'Tìm theo mã, tên, serial, MAC…',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) => setState(() {
                _query = v;
                _page = 0;
              }),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in StockCategory.values)
                    if (c == StockCategory.all || (counts[c] ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          key: ValueKey('stock-cat-${c.name}'),
                          label: Text('${c.label} (${counts[c] ?? 0})'),
                          selected: _cat == c,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) => setState(() {
                            _cat = c;
                            _page = 0;
                          }),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFBE123C),
                      ),
                    ),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            ),

          if (_loading && _parts.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_parts.isEmpty)
            Container(
              key: const ValueKey('stock-empty'),
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 44,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kho của bạn đang trống.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lập phiếu xuất kho để nhận thiết bị từ kho chính.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Không có thiết bị phù hợp bộ lọc.')),
            )
          else
            ...pageSlice(shown, _page).map(_partCard),
          PageBar(
            page: _page,
            total: shown.length,
            onPage: (p) => setState(() => _page = p),
          ),

          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.history, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hàng đã gắn vào Node rời khỏi kho này; hàng trả kho được cộng lại vào kho chính.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
