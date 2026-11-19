part of '../zone_detail_screen.dart';

extension _ZoneDetailScreenStateCultivation on _ZoneDetailScreenState {
  // ─── Tab 3: Canh tác ─────────────────────────────────────────
  Widget _buildCultivationTab(
    BuildContext context,
    FarmProvider provider,
    ZoneModel zone,
  ) {
    final isOwner = provider.canManageFarmStructure;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dữ liệu canh tác lấy từ API, tách rõ: thuộc Zone / hồ sơ gắn cho Zone / vụ trồng.
          ZoneCultivationInfoCard(
            key: ValueKey('cultivation_${zone.zoneId}'),
            zone: zone,
            version: _cultivationVersion,
          ),
          ZoneYieldCard(
            key: ValueKey('yield_${zone.zoneId}'),
            zone: zone,
            version: _cultivationVersion,
            onChanged: () => _refreshCultivation(provider),
          ),
          // Vụ trồng của chính Zone này (không cần rời màn hình); thao tác trên từng vụ theo trạng thái.
          ZoneSeasonsSection(
            key: ValueKey('seasons_${zone.zoneId}'),
            zone: zone,
            version: _cultivationVersion,
            onChanged: () => _refreshCultivation(provider),
          ),
          const SizedBox(height: 12),
          // Nhân công được phân công đúng Zone này.
          ZoneWorkersSection(
            key: ValueKey('workers_${zone.zoneId}'),
            zone: zone,
            onAssign: isOwner
                ? () => _showAssignWorkerSheet(context, provider, zone)
                : null,
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZoneProfilePage(zone: zone),
                    ),
                  );
                  await _refreshCultivation(provider);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: const Color(0xFF15803D),
                  side: const BorderSide(color: Color(0xFF15803D), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: const Color(0xFFF0FDF4),
                ),
                icon: const Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: Color(0xFF15803D),
                ),
                label: const Text(
                  'Hồ sơ canh tác của Zone',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Chọn hoặc sửa hồ sơ canh tác của Zone KHÔNG tạo vụ trồng. Muốn bắt đầu một vụ: dùng "Tạo vụ trồng cho Zone này" ở trên.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CropProfilesScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF047857),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                icon: const Icon(Icons.local_florist_outlined, size: 16),
                label: const Text('Mở Thư viện cây trồng'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ZoneCultivationLive(
            key: ValueKey('live_${zone.zoneId}_$_cultivationVersion'),
            zoneId: zone.zoneId,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Sau khi gắn hồ sơ/tạo vụ/ghi sản lượng: tải lại dữ liệu Zone từ máy chủ rồi dựng lại thẻ canh tác (cùng zoneId).
  Future<void> _refreshCultivation(FarmProvider provider) async {
    await provider.fetchFromApi();
    if (mounted) _rebuild(() => _cultivationVersion++);
  }

  Future<void> _showAssignWorkerSheet(
    BuildContext context,
    FarmProvider provider,
    ZoneModel zone,
  ) async {
    // Danh sách lấy từ Farm sở hữu Zone này (zone.farmId), không phải Farm đang chọn toàn cục.
    if (!provider.canManageFarmStructure) return;
    var farmWorkers = provider.farmersForFarm(zone.farmId);
    if (farmWorkers.isEmpty) {
      if (provider.selectedFarmId.toLowerCase() != zone.farmId.toLowerCase()) {
        provider.selectFarm(zone.farmId);
      }
      await provider.fetchFromApi();
      if (!context.mounted) return;
      farmWorkers = provider.farmersForFarm(zone.farmId);
    }
    if (farmWorkers.isEmpty) {
      final farmName = provider.farms
          .where((f) => f.farmId.toLowerCase() == zone.farmId.toLowerCase())
          .map((f) => f.name)
          .firstOrNull;
      final invite = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'Trang trại chưa có nhân công',
            style: TextStyle(fontSize: 15),
          ),
          content: Text(
            '${farmName == null ? 'Trang trại của Zone này' : 'Trang trại "$farmName"'} chưa có Farmer nào đang hoạt động. '
            'Nhân công gắn với từng trang trại: Farmer của trang trại khác không phân công được. '
            'Hãy mời Farmer vào đúng trang trại này (lời mời cần được Farmer chấp nhận), rồi quay lại phân công Zone.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Để sau'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mời nhân công'),
            ),
          ],
        ),
      );
      if (invite != true || !context.mounted) return;
      // Màn Quản lý Nhân công làm việc trên trang trại đang chọn: chọn đúng trang trại của Zone trước khi mở.
      provider.selectFarm(zone.farmId);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkforceScreen(initialFarmId: zone.farmId),
        ),
      );
      await _refreshCultivation(provider);
      return;
    }

    final targetZoneId = zone.zoneId.toLowerCase();
    final draft = <String, bool?>{
      for (final w in farmWorkers)
        w.farmerId: w.zoneAccess
            .where((a) => a.zoneId.toLowerCase() == targetZoneId)
            .map((a) => a.canControl)
            .firstOrNull,
    };

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Phân công nhân công cho ${zone.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn nhân sự phụ trách chăm sóc và điều khiển thiết bị cho Zone này:',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                for (final w in farmWorkers) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF15803D),
                    title: Text(
                      w.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      '${w.email}\n${draft[w.farmerId] == null ? 'Chưa được phân công Zone này' : (draft[w.farmerId] == true ? 'Xem, nhận việc & điều khiển thiết bị' : 'Chỉ xem & nhận việc')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    isThreeLine: true,
                    value: draft[w.farmerId] != null,
                    onChanged: (v) => setLocal(
                      () => draft[w.farmerId] = v == true ? false : null,
                    ),
                  ),
                  if (draft[w.farmerId] != null)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.only(left: 24),
                      activeThumbColor: const Color(0xFF15803D),
                      title: const Text(
                        'Quyền điều khiển thiết bị',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: draft[w.farmerId] == true,
                      onChanged: (v) => setLocal(() => draft[w.farmerId] = v),
                    ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    child: const Text('Lưu phân công'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved != true || !context.mounted) return;

    // Mỗi nhân công một lệnh PUT riêng: ghi nhận thành công/thất bại từng người, chỉ đổi quyền của Zone này.
    final ok = <String>[];
    final failed = <String>[];
    for (final w in farmWorkers) {
      final currentSetting = draft[w.farmerId];
      final oldAssigned = w.zoneAccess.any(
        (a) => a.zoneId.toLowerCase() == targetZoneId,
      );
      final oldCanControl = w.zoneAccess
          .where((a) => a.zoneId.toLowerCase() == targetZoneId)
          .map((a) => a.canControl)
          .firstOrNull;
      final changed =
          (currentSetting == null && oldAssigned) ||
          (currentSetting != null &&
              (!oldAssigned || oldCanControl != currentSetting));
      if (!changed) continue;
      try {
        await AccountApi.updateFarmerZoneAccess(w.farmerId, [
          for (final a in w.zoneAccess)
            if (a.zoneId.toLowerCase() != targetZoneId)
              {'zoneId': a.zoneId, 'canControl': a.canControl},
          if (currentSetting != null)
            {'zoneId': zone.zoneId, 'canControl': currentSetting},
        ]);
        ok.add(w.name);
      } catch (e) {
        failed.add('${w.name}: ${userFacingError(e)}');
      }
    }
    // Luôn tải lại để giao diện phản ánh đúng backend (kể cả khi có thao tác lỗi).
    await provider.fetchFromApi();
    if (!context.mounted) return;
    final message = failed.isEmpty
        ? (ok.isEmpty
              ? 'Không có thay đổi nào.'
              : 'Đã cập nhật phân công: ${ok.join(', ')}.')
        : 'Đã cập nhật: ${ok.isEmpty ? 'không ai' : ok.join(', ')}. Lỗi: ${failed.join('; ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed.isEmpty
            ? const Color(0xFF047857)
            : const Color(0xFFD97706),
        duration: Duration(seconds: failed.isEmpty ? 4 : 8),
      ),
    );
  }
}
