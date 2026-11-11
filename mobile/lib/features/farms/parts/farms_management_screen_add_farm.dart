part of '../farms_management_screen.dart';

extension _FarmsManagementScreenAddFarm on FarmsManagementScreen {
  // ─── Modal Thêm Trang Trại Mới ───
  void _showAddFarmDialog(BuildContext context, FarmProvider provider) {
    if (!provider.canManageFarmStructure) {
      showAppSnack(context, 'Chỉ chủ trang trại mới được tạo Farm, Thửa đất hoặc Zone.', error: true);
      return;
    }
    final nextNum = provider.farms.length + 1;
    final draft = FarmCreateDraft(nextNum: nextNum);
    final nameCtrl = draft.nameCtrl;
    final addressCtrl = draft.addressCtrl;
    final addressSync = draft.addressSync;
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.add_business, color: Color(0xFF10B981), size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Thêm Nông Trại Mới (Farm)',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(farmCreateIntro(provider), style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),

                    const Text(
                      'Tên Nông Trại *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      onChanged: draft.nameSync.onUserChanged,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Nông trại Công nghệ cao',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Địa Chỉ Thực Địa *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: addressCtrl,
                      onChanged: addressSync.onUserChanged,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Xã/Phường, Huyện, Tỉnh thành',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    addressSync.statusLine(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([addressSync, draft]),
                        builder: (_, _) => TextButton.icon(
                          onPressed: addressSync.loading || !draft.pinConfirmed
                              ? null
                              : () => addressSync.retry(draft.lat, draft.lng),
                          icon: const Icon(Icons.place_outlined, size: 16),
                          label: const Text('Lấy tên địa điểm từ ghim'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bản đồ số GIS Vệ tinh thực tế (Real Satellite Map Picker)
                    Row(
                      children: [
                        const Icon(Icons.satellite_alt, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Vị Trí & Ranh Giới GIS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Chạm bản đồ để dời tâm',
                            style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MiniGISMapPicker(
                      initialCenter: const LatLng(farmMapViewLat, farmMapViewLng),
                      autoResolveOnInit: false,
                      level: 'FARM',
                      height: 250,
                      onCenterChanged: (newCoord) => draft.onPinChosen(newCoord.latitude, newCoord.longitude),
                      onAddressLoading: addressSync.onLoading,
                      onAddressFailed: addressSync.onFailed,
                      // Chỉ nhận tên địa điểm thật; không ghi đè địa chỉ người dùng đã tự gõ.
                      onAddressResolved: addressSync.onResolved,
                      onRegionNameResolved: (regionShortName) =>
                          draft.nameSync.suggest('Nông trại CNC $regionShortName (Cơ sở 0$nextNum)'),
                    ),
                    farmPinStatusLine(draft),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Huỷ', style: TextStyle(color: Color(0xFF475569))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ListenableBuilder(
                            listenable: draft,
                            builder: (_, _) => ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: draft.submitting
                                  ? null
                                  : () => runFarmCreate(
                                      sheetContext: ctx,
                                      messenger: messenger,
                                      provider: provider,
                                      draft: draft,
                                      totalAreaM2: 1000000.0,
                                    ),
                              icon: draft.submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check, size: 18),
                              label: Text(
                                draft.submitting ? 'Đang tạo…' : 'Tạo Trang Trại',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      disposeControllersLater([draft.nameCtrl, draft.addressCtrl]);
      Future.delayed(const Duration(milliseconds: 700), draft.dispose);
    });
  }
}
