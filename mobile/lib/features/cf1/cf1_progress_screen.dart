import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/state_views.dart';
import '../contracts/contracts_depreciation_screen.dart';
import '../zones/zone_operations_screens.dart' show ZonePlantingSeasonsScreen;
import '../devices/deployment_screens.dart';
import '../farms/farms_management_screen.dart';
import '../farms/farm_setup_wizard_screen.dart';
import '../workforce/workforce_screen.dart';
import 'cf1_progress_logic.dart';

/// Hướng dẫn & tiến độ CF1 cho FarmOwner. Trạng thái lấy từ server; bước nào không tải được sẽ báo rõ.
class Cf1ProgressScreen extends StatefulWidget {
  const Cf1ProgressScreen({super.key});

  @override
  State<Cf1ProgressScreen> createState() => _Cf1ProgressScreenState();
}

class _Step {
  final String title;
  final String hint;
  final IconData icon;
  final Cf1StepState state;
  final String? detail;
  final WidgetBuilder open;
  const _Step(this.title, this.hint, this.icon, this.state, this.open, {this.detail});
}

class _Cf1ProgressScreenState extends State<Cf1ProgressScreen> {
  bool _loading = true;
  List<_Step> _steps = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<T?> _try<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final p = context.read<FarmProvider>();
    if (!p.canManageFarmStructure) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final farmId = p.selectedFarmId;
    final zones = p.allZones.where((z) => z.farmId == farmId).toList();
    final seasons = await _try(() => CropApi.getPlantingSeasons(farmId: farmId));
    final contracts = await _try(() => ContractApi.getZoneContracts(farmId: farmId));
    final invitations = await _try(() => AccountApi.getFarmInvitations(farmId));
    final deployments = await _try(() => DeploymentApi.getOwnerDeploymentRequests());
    if (!mounted) return;
    final farmers = p.allFarmers.where((f) => f.farmId == farmId).toList();
    final pending = invitations?.where((i) => i['status']?.toString() == 'Pending').length;
    final statuses = deployments?.where((d) => d.farmId == farmId).map((d) => d.status).toList();
    final fields = p.fieldsForCurrentFarm.length;

    setState(() {
      _steps = [
        _Step(
          'Trang trại → Lô đất → Zone',
          'Tạo cấu trúc Farm, Field, Zone (kèm ranh giới nếu có).',
          Icons.agriculture,
          structureState(farms: p.farms.length, fields: fields, zones: zones.length),
          (_) => const FarmsManagementScreen(),
          detail: '${p.farms.length} trang trại · $fields lô · ${zones.length} Zone (trang trại đang chọn)',
        ),
        _Step(
          'Vụ trồng',
          'Chọn cây trồng và hồ sơ sinh trưởng có giai đoạn cho Zone.',
          Icons.grass,
          seasonState(zones: zones.length, seasons: seasons?.length),
          // Vụ trồng thuộc từng Zone: mở danh sách vụ của Zone đầu tiên (chưa có Zone thì về quản lý cấu trúc).
          (_) => zones.isEmpty ? const FarmsManagementScreen() : ZonePlantingSeasonsScreen(zone: zones.first),
          detail: seasons == null ? null : '${seasons.length} vụ',
        ),
        _Step(
          'Hợp đồng thuê Zone (tuỳ chọn)',
          'Chỉ cần khi cho bên thứ ba thuê Zone. Triển khai IoT không phụ thuộc bước này.',
          Icons.description_outlined,
          contractState(contracts: contracts?.length),
          (_) => const ContractsDepreciationScreen(),
          detail: contracts == null ? null : '${contracts.length} hợp đồng',
        ),
        _Step(
          'Nhân công (Farmer)',
          'Mời Farmer và cấp quyền cho đúng Zone.',
          Icons.groups_outlined,
          staffState(
            farmers: farmers.length,
            farmersWithoutZoneAccess: farmers.where((f) => f.zoneAccess.isEmpty).length,
            pendingInvitations: pending,
          ),
          (_) => const WorkforceScreen(),
          detail: '${farmers.length} Farmer${pending == null ? '' : ' · $pending lời mời đang chờ'}',
        ),
        _Step(
          'Triển khai IoT',
          'Gửi yêu cầu, kỹ thuật viên khảo sát, lắp đặt, gán thiết bị vào Zone, kiểm tra kết nối.',
          Icons.sensors,
          deploymentState(statuses),
          (_) => const DeploymentPlanningScreen(),
          detail: statuses == null ? null : '${statuses.length} yêu cầu',
        ),
      ];
      _loading = false;
    });
  }

  Color _color(Cf1StepState s) => switch (s) {
    Cf1StepState.done => const Color(0xFF16A34A),
    Cf1StepState.inProgress => const Color(0xFF0284C7),
    Cf1StepState.needsAction => const Color(0xFFDC2626),
    _ => const Color(0xFF94A3B8),
  };

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<FarmProvider>().canManageFarmStructure;
    return Scaffold(
      appBar: AppBar(title: const Text('Tiến độ thiết lập CF1')),
      body: !owner
          ? const AppEmptyState(icon: Icons.lock_outline, message: 'Chỉ chủ trang trại xem được tiến độ thiết lập.')
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  Card(
                    color: const Color(0xFF064E3B).withValues(alpha: 0.08),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.auto_awesome, size: 20),
                      ),
                      title: const Text(
                        'Wizard thiết lập trọn gói (1 chạm)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF064E3B)),
                      ),
                      subtitle: const Text(
                        'Khởi tạo nhanh Trang trại → Lô đất → Zone → Vụ trồng → Yêu cầu IoT trong 1 giao dịch.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF047857)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF10B981)),
                      onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmSetupWizardScreen())),
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < _steps.length; i++) _card(i + 1, _steps[i]),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Trạng thái lấy từ máy chủ. "Chưa tải được" nghĩa là chưa đọc được dữ liệu của bước đó, '
                      'không phải đã hoàn tất.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card(int n, _Step s) {
    final c = _color(s.state);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.12),
          child: Icon(s.icon, color: c, size: 20),
        ),
        title: Text('$n. ${s.title}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text('${s.hint}${s.detail == null ? '' : '\n${s.detail}'}', style: const TextStyle(fontSize: 12)),
        isThreeLine: true,
        trailing: Text(
          cf1StateLabel(s.state),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: s.open)),
      ),
    );
  }
}
