part of '../crop_profiles_screen.dart';

void _showCreateZoneDialogImpl(BuildContext context, FarmProvider provider) {
  if (!provider.canManageFarmStructure) {
    showAppSnack(context, 'Chỉ chủ trang trại mới được tạo Farm, Thửa đất hoặc Zone.', error: true);
    return;
  }
  final nextZoneNum = provider.zones.length + 1;
  final nameController = TextEditingController(text: 'Nhà màng 0$nextZoneNum');
  final areaController = TextEditingController();
  String? selectedFarmerId; // không bắt buộc: gán nhân công qua quyền Zone sau khi tạo
  // Zone phải thuộc một thửa đất thật; không tạo trên lô giả.
  if (provider.fieldsForCurrentFarm.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trang trại chưa có thửa đất. Hãy tạo thửa đất trước khi tạo Zone.')));
    return;
  }
  String? selectedFieldId =
      provider.selectedFieldId ??
      (provider.fieldsForCurrentFarm.isNotEmpty ? provider.fieldsForCurrentFarm.first.fieldId : null);
  List<LatLng>? currentZonePolygon;
  // Chọn cây + hồ sơ canh tác (không bắt buộc). Dữ liệu từ API; lưu qua Vụ trồng sau khi Zone được tạo.
  final cropPlan = ZoneCropPlanController();
  var submitting = false;
  // Bản sao hồ sơ đã tạo ở lần bấm trước (tạo Zone lỗi giữa chừng) để dùng lại khi thử lại, tránh tạo trùng.
  String? preparedCloneId;
  String? preparedKey;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final fields = provider.fieldsForCurrentFarm;
        final selectedField = fields.where((f) => f.fieldId == selectedFieldId).firstOrNull ?? fields.firstOrNull;
        final targetFarmId = selectedField?.farmId ?? provider.selectedFarmId;
        final farmWorkers = provider.allFarmers
            .where((f) => f.farmId != null && f.farmId!.toLowerCase() == targetFarmId.toLowerCase())
            .toList();

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
          child: Padding(
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
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add_business, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tạo Zone mới',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '${provider.currentFarm.name}${selectedField == null ? '' : ' › ${selectedField.name}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  FormSection(
                    title: 'Thông tin Zone',
                    icon: Icons.crop_square_rounded,
                    subtitle: 'Zone thuộc một thửa đất của trang trại đang chọn.',
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey('field-$selectedFieldId'),
                        initialValue: selectedFieldId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Thửa đất (Field) *',
                          prefixIcon: Icon(Icons.layers_outlined, size: 20),
                        ),
                        items: [
                          for (final f in fields)
                            DropdownMenuItem<String>(
                              value: f.fieldId,
                              child: Text(
                                '${f.name} (${(f.areaM2 / 10000).toStringAsFixed(1)} ha)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedFieldId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Tên Zone *',
                          hintText: 'Ví dụ: Nhà màng 04',
                          prefixIcon: Icon(Icons.edit_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: areaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Diện tích (m²)',
                          helperText: 'Tự tính khi bạn vẽ ranh giới trên bản đồ bên dưới.',
                          prefixIcon: Icon(Icons.square_foot, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FormSection(
                    title: 'Nhân công phụ trách',
                    icon: Icons.person_pin_circle_outlined,
                    accent: const Color(0xFF0284C7),
                    subtitle: 'Không bắt buộc. Có thể phân công sau trong màn Zone.',
                    children: [
                      if (farmWorkers.isEmpty)
                        const Text(
                          'Farm này chưa có nhân công. Mời Farmer ở mục Quản lý nhân công rồi phân công sau.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          key: ValueKey('worker-$targetFarmId'),
                          initialValue: selectedFarmerId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Nhân công',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Chưa gán (để trống)')),
                            for (final w in farmWorkers)
                              DropdownMenuItem<String?>(
                                value: w.farmerId,
                                child: Text('${w.name} (${w.email})', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (val) => setModalState(() => selectedFarmerId = val),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FormSection(
                    title: 'Vị trí & ranh giới (GIS)',
                    icon: Icons.satellite_alt,
                    subtitle: 'Chạm bản đồ để vẽ ranh giới Zone trong thửa đất đã chọn.',
                    children: [
                      Builder(
                        builder: (_) {
                          final selectedField = fields.firstWhere(
                            (f) => f.fieldId == selectedFieldId,
                            orElse: () => fields.first,
                          );
                          final fieldPolygon = selectedField.polygon;

                          // Lấy danh sách các Zone đã có trên Thửa đất mẹ này
                          final existingZonesInField = provider.allZones
                              .where(
                                (z) => z.fieldId == selectedField.fieldId && z.polygon != null && z.polygon!.isNotEmpty,
                              )
                              .map((z) => {'name': z.name.split(' - ').first, 'polygon': z.polygon})
                              .toList();

                          return MiniGISMapPicker(
                            key: ValueKey('zone_picker_${selectedField.fieldId}'),
                            initialCenter: LatLng(provider.currentFarm.latitude, provider.currentFarm.longitude),
                            level: 'ZONE',
                            parentPolygon: fieldPolygon,
                            existingZones: existingZonesInField,
                            height: 250,
                            onPolygonChanged: (pts) {
                              currentZonePolygon = pts;
                            },
                            onAreaCalculated: (areaM2) {
                              areaController.text = areaM2.toStringAsFixed(0);
                              setModalState(() {});
                            },
                            onRegionNameResolved: (regionShortName) {
                              final newName = 'Nhà màng 0$nextZoneNum - Khu $regionShortName';
                              if (nameController.text != newName) {
                                nameController.text = newName;
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ZoneCropPlanSection(controller: cropPlan),
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
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: submitting
                              ? null
                              : () async {
                                  // Hồ sơ cây không hợp lệ thì dừng NGAY, trước khi tạo Zone (tránh Zone mồ côi).
                                  final planError = cropPlan.validate();
                                  if (planError != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(planError), backgroundColor: const Color(0xFFB45309)),
                                    );
                                    return;
                                  }
                                  // Kiểm tra nếu có polygon và polygon bị lòi ra ngoài Field hoặc đè lên Zone khác
                                  if (currentZonePolygon != null && currentZonePolygon!.length >= 3) {
                                    final selectedField = fields.firstWhere(
                                      (f) => f.fieldId == selectedFieldId,
                                      orElse: () => fields.first,
                                    );

                                    // Kiểm tra xem có đè lên Zone nào không
                                    final otherZones = provider.allZones.where(
                                      (z) =>
                                          z.fieldId == selectedField.fieldId &&
                                          z.polygon != null &&
                                          z.polygon!.length >= 3,
                                    );

                                    bool isInsidePoly(LatLng pt, List<LatLng> poly) {
                                      final double px = pt.longitude;
                                      final double py = pt.latitude;
                                      bool inside = false;
                                      for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
                                        final double xi = poly[i].longitude;
                                        final double yi = poly[i].latitude;
                                        final double xj = poly[j].longitude;
                                        final double yj = poly[j].latitude;
                                        if (((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                                          inside = !inside;
                                        }
                                      }
                                      return inside;
                                    }

                                    // 1. Kiểm tra lòi ra ngoài Thửa đất
                                    if (selectedField.polygon != null && selectedField.polygon!.length >= 3) {
                                      final isOutside = currentZonePolygon!.any(
                                        (pt) => !isInsidePoly(pt, selectedField.polygon!),
                                      );
                                      if (isOutside) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              '⚠️ Ranh giới Zone đang vượt ra ngoài Thửa đất! Vui lòng chỉnh lại vào trong.',
                                            ),
                                            backgroundColor: const Color(0xFFEF4444),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                        return;
                                      }
                                    }

                                    // 2. Kiểm tra đè lên Zone khác
                                    for (final oz in otherZones) {
                                      final pts = oz.polygon!;
                                      final isOverlapping =
                                          currentZonePolygon!.any((pt) => isInsidePoly(pt, pts)) ||
                                          pts.any((pt) => isInsidePoly(pt, currentZonePolygon!));
                                      if (isOverlapping) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '⚠️ Ranh giới đang chồng đè lên "${oz.name.split(' - ').first}"! Không thể tạo.',
                                            ),
                                            backgroundColor: const Color(0xFFEF4444),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                        return;
                                      }
                                    }
                                  }

                                  final zoneName = nameController.text.trim().isEmpty
                                      ? 'Nhà màng 0$nextZoneNum'
                                      : nameController.text.trim();
                                  final area = double.tryParse(areaController.text) ?? 0.0;
                                  final messenger = ScaffoldMessenger.of(context);
                                  // Hồ sơ được chọn: nhắc lại và xác nhận TRƯỚC khi tạo bản sao/Zone.
                                  if (cropPlan.selection.active && cropPlan.selection.profileId != null) {
                                    final sel = cropPlan.selection;
                                    final p = cropPlan.currentProfile;
                                    final ok = await confirmApplyProfile(
                                      ctx,
                                      zoneName: zoneName,
                                      profileName: sel.mode == ZoneProfileMode.custom
                                          ? sel.customName.trim()
                                          : '${p?['name'] ?? 'hồ sơ đã chọn'}',
                                      cropName: '${cropPlan.currentCrop?['name'] ?? p?['cropName'] ?? ''}',
                                      varietyName: p == null ? null : cropPlan.varietyNameOf(p),
                                      isSystem: p?['isSystemDefined'] == true,
                                      willClone: sel.mode == ZoneProfileMode.custom,
                                      stageCount: sel.stages.length,
                                    );
                                    if (!ok || !ctx.mounted) return;
                                  }
                                  setModalState(() => submitting = true);

                                  // 1) Chuẩn bị hồ sơ (sao chép + chỉnh nếu "Tùy chỉnh bản sao") TRƯỚC khi tạo Zone. Không tạo vụ mùa.
                                  String? profileId;
                                  var profileName = '';
                                  if (cropPlan.selection.active) {
                                    final sel = cropPlan.selection;
                                    final key =
                                        '${sel.profileId}|${sel.customName}|${sel.customDescription}|'
                                        '${[
                                          for (final st in sel.stages) '${st.durationDays}:${[for (final r in st.requirements) '${r.min},${r.max},${r.target}'].join(';')}',
                                        ].join('/')}';
                                    final prep = await prepareZoneProfile(
                                      selection: sel,
                                      reuseCloneId: preparedKey == key ? preparedCloneId : null,
                                    );
                                    if (prep.cloned && prep.profileId != null) {
                                      preparedCloneId = prep.profileId;
                                      preparedKey = key;
                                    }
                                    if (!prep.ok) {
                                      if (ctx.mounted) setModalState(() => submitting = false);
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${prep.error ?? 'Không chuẩn bị được hồ sơ.'} Dữ liệu bạn nhập được giữ nguyên, bấm "Tạo Zone" để thử lại.',
                                          ),
                                          backgroundColor: const Color(0xFFD97706),
                                        ),
                                      );
                                      return;
                                    }
                                    profileId = prep.profileId;
                                    profileName = sel.mode == ZoneProfileMode.custom
                                        ? sel.customName.trim()
                                        : '${cropPlan.currentProfile?['name'] ?? 'hồ sơ đã chọn'}';
                                  }

                                  // 2) Tạo Zone kèm hồ sơ gắn trực tiếp (backend lưu Zone.GrowthProfileId, không tạo PlantingSeason).
                                  final result = await provider.addNewZone(
                                    name: zoneName,
                                    areaM2: area,
                                    assignFarmerId: selectedFarmerId,
                                    customFieldId: selectedFieldId,
                                    polygon: currentZonePolygon,
                                    growthProfileId: profileId,
                                  );
                                  if (result.error != null) {
                                    if (ctx.mounted) setModalState(() => submitting = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          preparedCloneId != null && profileId == preparedCloneId
                                              ? '${result.error} (Hồ sơ riêng "$profileName" đã được tạo và sẽ được dùng lại khi bạn thử lại.)'
                                              : result.error!,
                                        ),
                                        backgroundColor: const Color(0xFFEF4444),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);

                                  final warning = result.warning;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        warning != null
                                            ? 'Đã tạo Zone "$zoneName". $warning'
                                            : profileId != null
                                            ? 'Đã tạo Zone "$zoneName" và gắn hồ sơ "$profileName". Chưa tạo vụ trồng: chỉ tạo vụ khi bắt đầu mùa vụ.'
                                            : 'Đã tạo Zone "$zoneName" (chưa gắn hồ sơ canh tác).',
                                      ),
                                      backgroundColor: warning == null
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD97706),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 7),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Tạo Zone', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ).then((_) {
    disposeControllersLater([nameController, areaController]);
    cropPlan.dispose();
  });
}
