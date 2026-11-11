part of '../contracts_depreciation_screen.dart';

extension _ContractsDepreciationScreenStateActions on _ContractsDepreciationScreenState {
  /// Zone thuộc trang trại đang xem (bộ lọc farm của màn hình, mặc định trang trại đang chọn).
  List<ZoneModel> _farmZones(FarmProvider provider) {
    // Ngữ cảnh Zone: chỉ Zone đang xem, không chọn được Zone khác.
    final locked = widget.lockedZone;
    if (locked != null) return [locked];
    final farmId = _selectedFarmId ?? provider.selectedFarmId;
    return provider.allZones.where((z) => z.farmId == farmId).toList();
  }

  Future<void> _showContractDetailsModal(ZoneContractModel contract) async {
    final isOwner = context.read<FarmProvider>().currentRole == 'OWNER';
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneContractDetailScreen(contract: contract, canRenew: isOwner),
      ),
    );
    if (changed == true && mounted) _loadData();
  }

  Future<void> _showRenewContractDialog(ZoneContractModel contract) async {
    final updated = await showRenewContractSheet(context, contract);
    if (updated == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã gia hạn HĐ ${updated.contractNumber} đến ${updated.endDate} · tổng ${currencyFormat.format(updated.totalContractValueVnd)}.',
        ),
        backgroundColor: const Color(0xFF059669),
      ),
    );
    _loadData();
  }

  Future<void> _showCreateContractDialog(FarmProvider provider) async {
    if (!provider.canManageFarmStructure) return;
    final zone = widget.lockedZone ?? _farmZones(provider).where((z) => z.zoneId == _selectedZoneId).firstOrNull;
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => SupportRequestsScreen(zone: zone)));
    if (mounted) _loadData();
  }

  Future<void> _showCreateDepreciationDialog(FarmProvider provider) async {
    final zones = _farmZones(provider);
    if (zones.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trang trại chưa có Zone để trích khấu hao.')));
      return;
    }
    final ok = await showCreateDepreciationSheet(
      context,
      zones: zones,
      deviceIdsWithDepreciation: _depreciations.map((d) => d.deviceId).toSet(),
      initialZoneId: _selectedZoneId,
    );
    if (ok != true || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã thêm hồ sơ khấu hao.'), backgroundColor: Color(0xFF059669)));
    _loadData();
  }
}
