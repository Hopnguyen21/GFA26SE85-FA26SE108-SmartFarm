import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import 'zone_access_logic.dart';

/// Quản lý nhân công theo Farm: mời Farmer đã có tài khoản, theo dõi lời mời, cấp quyền Zone.
/// Mọi dữ liệu đi qua API; ứng dụng không tự tạo tài khoản hay mật khẩu nhân công.
class WorkforceScreen extends StatefulWidget {
  const WorkforceScreen({super.key});

  @override
  State<WorkforceScreen> createState() => _WorkforceScreenState();
}

class _WorkforceScreenState extends State<WorkforceScreen> {
  List<Map<String, dynamic>> _invitations = [];
  bool _busy = false;
  String? _error;

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvitations());
  }

  Future<void> _loadInvitations() async {
    final farmId = context.read<FarmProvider>().selectedFarmId;
    if (farmId.isEmpty) return;
    try {
      final items = await AccountApi.getFarmInvitations(farmId);
      if (mounted) {
        setState(() {
          _invitations = items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite(String farmId) async {
    final ctrl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mời Farmer vào trang trại', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email tài khoản Farmer', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Gửi lời mời')),
        ],
      ),
    );
    ctrl.dispose();
    if (email == null || email.isEmpty) return;
    await _run(() async {
      await AccountApi.inviteFarmer(farmId, email);
      await _loadInvitations();
    }, 'Đã gửi lời mời tới $email.');
  }

  Future<void> _editZones(FarmerModel farmer, List<ZoneModel> zones) async {
    final draft = <String, bool?>{
      for (final z in zones)
        z.zoneId: farmer.zoneAccess.where((a) => a.zoneId == z.zoneId).map((a) => a.canControl).firstOrNull,
    };
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quyền Zone của ${farmer.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                if (zones.isEmpty) const Text('Trang trại này chưa có Zone.'),
                for (final z in zones) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(z.name, style: const TextStyle(fontSize: 13)),
                    subtitle: const Text('Xem & nhận việc', style: TextStyle(fontSize: 11)),
                    value: draft[z.zoneId] != null,
                    onChanged: (v) => setLocal(() => draft[z.zoneId] = v == true ? false : null),
                  ),
                  if (draft[z.zoneId] != null)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.only(left: 24),
                      title: const Text('Điều khiển thiết bị', style: TextStyle(fontSize: 12)),
                      value: draft[z.zoneId] == true,
                      onChanged: (v) => setLocal(() => draft[z.zoneId] = v),
                    ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu quyền')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final provider = context.read<FarmProvider>();
    await _run(() async {
      await AccountApi.updateFarmerZoneAccess(
        farmer.farmerId,
        mergeZoneAccessPayload(
          existing: [for (final a in farmer.zoneAccess) (zoneId: a.zoneId, canControl: a.canControl)],
          editableZoneIds: {for (final z in zones) z.zoneId},
          draft: draft,
        ),
      );
      await provider.fetchFromApi();
    }, 'Đã cập nhật quyền Zone cho ${farmer.name}.');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    if (provider.currentRole != 'OWNER') {
      return Scaffold(
        appBar: AppBar(title: const Text('Quản lý Nhân công')),
        body: const Center(child: Text('Chỉ chủ trang trại được quản lý nhân công.')),
      );
    }
    final farmId = provider.selectedFarmId;
    final zones = provider.allZones.where((z) => z.farmId == farmId).toList();
    final members = provider.allFarmers.where((f) => f.farmId == farmId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Nhân công')),
      floatingActionButton: provider.farms.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _invite(farmId),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Thêm nhân công'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.fetchFromApi();
          await _loadInvitations();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            if (provider.farms.isEmpty)
              const Text('Chưa có trang trại nào.')
            else
              DropdownButtonFormField<String>(
                initialValue: provider.farms.any((f) => f.farmId == farmId) ? farmId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nông trại', border: OutlineInputBorder()),
                items: [
                  for (final f in provider.farms)
                    DropdownMenuItem(
                      value: f.farmId,
                      child: Text(f.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  provider.selectFarm(v);
                  await provider.fetchFromApi();
                  await _loadInvitations();
                },
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
            ],
            const SizedBox(height: 16),
            Text('Nhân công (${members.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Trang trại này chưa có nhân công. Mời Farmer bằng email; họ xuất hiện ở đây sau khi chấp nhận.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            for (final m in members)
              Card(
                child: ListTile(
                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('${m.email}\n${_accessSummary(m, zones)}', style: const TextStyle(fontSize: 12)),
                  isThreeLine: true,
                  trailing: TextButton(
                    onPressed: _busy ? null : () => _editZones(m, zones),
                    child: const Text('Quyền Zone'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Lời mời (${_invitations.where((i) => i['status'] == 'Pending').length} đang chờ)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final inv in _invitations)
              Card(
                child: ListTile(
                  title: Text(inv['email']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(inv['status']?.toString() ?? '', style: const TextStyle(fontSize: 11)),
                  trailing: inv['status'] == 'Pending'
                      ? Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Gửi lại',
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await AccountApi.invitationAction(inv['id'].toString(), 'resend');
                                      await _loadInvitations();
                                    }, 'Đã gửi lại lời mời.'),
                            ),
                            IconButton(
                              tooltip: 'Hủy',
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      await AccountApi.invitationAction(inv['id'].toString(), 'cancel');
                                      await _loadInvitations();
                                    }, 'Đã hủy lời mời.'),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _accessSummary(FarmerModel m, List<ZoneModel> zones) {
    final names = [
      for (final a in m.zoneAccess)
        for (final z in zones.where((z) => z.zoneId == a.zoneId)) z.name,
    ];
    return names.isEmpty ? 'Chưa có quyền Zone nào, chưa thể được giao việc.' : names.join(', ');
  }
}
