part of '../crop_detail_screen.dart';

extension _CropDetailScreenStateApplyZone on _CropDetailScreenState {
  /// Gắn hồ sơ canh tác này cho một Zone (Zone.GrowthProfileId). KHÔNG tạo vụ trồng và không có khái niệm mùa vụ chung:
  /// muốn bắt đầu một vụ, dùng "Tạo vụ trồng" trong màn Vụ trồng của Zone. Có hộp xác nhận trước khi lưu.
  void _showApplyToZoneModal(BuildContext context, DefaultCropProfile profile) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có khu vực (Zone) nào. Vui lòng tạo Zone trước!'),
        ),
      );
      return;
    }
    // Chỉ Owner được gắn hồ sơ (backend: PUT /zones/{id} chỉ cho FarmOwner).
    if (!provider.canManageFarmStructure) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chỉ chủ trang trại mới gắn được hồ sơ canh tác cho Zone.',
          ),
        ),
      );
      return;
    }

    var selectedZoneId =
        provider.zones.any((z) => z.zoneId == provider.currentZone.zoneId)
        ? provider.currentZone.zoneId
        : provider.zones.first.zoneId;
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final zone = provider.zones.firstWhere(
              (z) => z.zoneId == selectedZoneId,
            );
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
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
                    const SizedBox(height: 14),
                    Text(
                      'Gắn hồ sơ "${profile.name}" cho Zone',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chỉ gắn hồ sơ canh tác cho Zone, không tạo vụ trồng.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZoneId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Zone',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final z in provider.zones)
                          DropdownMenuItem(
                            value: z.zoneId,
                            child: Text(
                              '${z.name} (cây hiện tại: ${z.currentCrop})',
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) {
                              if (v != null)
                                setModalState(() => selectedZoneId = v);
                            },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${profile.emoji} ${profile.name} · giống ${profile.variety} · ${profile.growthStages.length} giai đoạn',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (zone.growthProfileName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Zone đang dùng hồ sơ "${zone.growthProfileName}"; hồ sơ này sẽ được thay thế.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.pop(ctx),
                            child: const Text('Huỷ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Gắn hồ sơ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    final ok = await confirmApplyProfile(
                                      ctx,
                                      zoneName: zone.name,
                                      profileName: profile.name,
                                      cropName: profile.name,
                                      varietyName: profile.variety.isEmpty
                                          ? null
                                          : profile.variety,
                                      isSystem: false,
                                      willClone: false,
                                      stageCount: profile.growthStages.length,
                                      currentProfileName:
                                          zone.growthProfileName,
                                    );
                                    if (!ok || !ctx.mounted) return;
                                    setModalState(() => saving = true);
                                    final err = await provider.applyCropProfile(
                                      profile.cropId,
                                      targetZoneId: selectedZoneId,
                                    );
                                    if (err != null) {
                                      if (ctx.mounted)
                                        setModalState(() => saving = false);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(err),
                                            backgroundColor: const Color(
                                              0xFFEF4444,
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã gắn hồ sơ "${profile.name}" cho ${zone.name}. Chưa tạo vụ trồng.',
                                        ),
                                        backgroundColor: const Color(
                                          0xFF059669,
                                        ),
                                      ),
                                    );
                                  },
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
    );
  }
}
