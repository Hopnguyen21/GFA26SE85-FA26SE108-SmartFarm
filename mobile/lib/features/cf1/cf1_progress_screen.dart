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
  const _Step(
    this.title,
    this.hint,
    this.icon,
    this.state,
    this.open, {
    this.detail,
  });
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
    final seasons = await _try(
      () => CropApi.getPlantingSeasons(farmId: farmId),
    );
    final contracts = await _try(
      () => ContractApi.getZoneContracts(farmId: farmId),
    );
    final invitations = await _try(() => AccountApi.getFarmInvitations(farmId));
    final deployments = await _try(
      () => DeploymentApi.getOwnerDeploymentRequests(),
    );
    if (!mounted) return;
    final farmers = p.allFarmers.where((f) => f.farmId == farmId).toList();
    final pending = invitations
        ?.where((i) => i['status']?.toString() == 'Pending')
        .length;
    final statuses = deployments
        ?.where((d) => d.farmId == farmId)
        .map((d) => d.status)
        .toList();
    final fields = p.fieldsForCurrentFarm.length;

    setState(() {
      _steps = [
        _Step(
          'Trang trại → Lô đất → Zone',
          'Tạo cấu trúc Farm, Field, Zone (kèm ranh giới nếu có).',
          Icons.agriculture,
          structureState(
            farms: p.farms.length,
            fields: fields,
            zones: zones.length,
          ),
          (_) => const FarmsManagementScreen(),
          detail:
              '${p.farms.length} trang trại · $fields lô · ${zones.length} Zone (trang trại đang chọn)',
        ),
        _Step(
          'Vụ trồng',
          'Chọn cây trồng và hồ sơ sinh trưởng có giai đoạn cho Zone.',
          Icons.grass,
          seasonState(zones: zones.length, seasons: seasons?.length),
          // Vụ trồng thuộc từng Zone: mở danh sách vụ của Zone đầu tiên (chưa có Zone thì về quản lý cấu trúc).
          (_) => zones.isEmpty
              ? const FarmsManagementScreen()
              : ZonePlantingSeasonsScreen(zone: zones.first),
          detail: seasons == null ? null : '${seasons.length} vụ',
        ),
        _Step(
          'Hợp đồng của Zone (tuỳ chọn)',
          'Xem và quản lý hợp đồng cũ, hiện tại của Zone. Triển khai IoT không phụ thuộc bước này.',
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
            farmersWithoutZoneAccess: farmers
                .where((f) => f.zoneAccess.isEmpty)
                .length,
            pendingInvitations: pending,
          ),
          (_) => const WorkforceScreen(),
          detail:
              '${farmers.length} Farmer${pending == null ? '' : ' · $pending lời mời đang chờ'}',
        ),
        _Step(
          'Triển khai IoT',
          'Gửi yêu cầu, kỹ thuật viên khảo sát, lắp đặt, gán thiết bị vào Zone, kiểm tra kết nối.',
          Icons.sensors,
          deploymentState(statuses),
          (_) => const OwnerDeploymentRequestsScreen(),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tiến độ thiết lập CF1',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !owner
          ? const AppEmptyState(
              icon: Icons.lock_outline,
              message: 'Chỉ chủ trang trại xem được tiến độ thiết lập.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF064E3B), Color(0xFF0D4A35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF064E3B,
                          ).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FarmSetupWizardScreen(),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFF34D399),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wizard thiết lập trọn gói (1 chạm)',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Khởi tạo nhanh Trang trại → Lô đất → Zone → Vụ trồng → Yêu cầu IoT trong 1 giao dịch.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFA7F3D0),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Color(0xFF34D399),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _steps.length; i++)
                    _card(i + 1, _steps[i]),
                  const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
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
    final isDone = s.state == Cf1StepState.done;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
          width: isDone ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              Navigator.push(context, MaterialPageRoute(builder: s.open)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(s.icon, color: c, size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              '$n. ${s.title}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: c.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              cf1StateLabel(s.state),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: c,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.hint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                      if (s.detail != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.detail!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
