part of '../home_screen.dart';

extension _HomeScreenSelectors on HomeScreen {
  // ─── Modal Chọn Nông Trại Khác ───
  void _showFarmSelectorModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.corporate_fare, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Chọn Nông Trại Canh Tác',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (provider.canManageFarmStructure)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showQuickAddFarmDialog(context, provider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Thêm Farm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Chuyển đổi giữa các cơ sở sản xuất thuộc doanh nghiệp.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: provider.farms.map((farm) {
                      final isSelected = farm.farmId == provider.selectedFarmId;
                      final farmZones = provider.allZones.where((z) => z.farmId == farm.farmId).length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.agriculture,
                                color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                              ),
                            ),
                            title: Text(
                              farm.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(farm.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text(
                                  '$farmZones nhà màng • ${(farm.totalAreaM2 / 10000).toStringAsFixed(1)} ha',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22)
                                : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
                            onTap: () {
                              provider.selectFarm(farm.farmId);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đã chuyển sang: ${farm.name}'),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Modal Chọn / Lọc Thửa Đất (Field) ───
  void _showFieldSelectorModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final fields = provider.fieldsForCurrentFarm;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.layers_outlined, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn Thửa Đất (Field)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Thuộc: ${provider.currentFarm.name}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (provider.canManageFarmStructure)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showQuickAddFieldDialog(context, provider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text(
                          'Thêm Lô',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Option: Tất cả các thửa
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: provider.selectedFieldId == null ? const Color(0xFFF0F9FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: provider.selectedFieldId == null ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            width: provider.selectedFieldId == null ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                            leading: const Icon(Icons.select_all, color: Color(0xFF0284C7)),
                            title: const Text(
                              'Tất cả các thửa đất',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Hiển thị toàn bộ ${provider.allZones.where((z) => z.farmId == provider.selectedFarmId).length} nhà màng trong trang trại',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            trailing: provider.selectedFieldId == null
                                ? const Icon(Icons.check_circle, color: Color(0xFF0284C7), size: 20)
                                : null,
                            onTap: () {
                              provider.selectField(null);
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ),

                      ...fields.map((field) {
                        final isSelected = field.fieldId == provider.selectedFieldId;
                        final fieldZones = provider.allZones.where((z) => z.fieldId == field.fieldId).length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: const Icon(Icons.landscape_outlined, color: Color(0xFF0369A1)),
                              title: Text(
                                field.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFF0C4A6E) : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    field.description,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$fieldZones nhà màng • ${(field.areaM2 / 10000).toStringAsFixed(1)} ha',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Color(0xFF0284C7), size: 20)
                                  : null,
                              onTap: () {
                                provider.selectField(field.fieldId);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã lọc theo thửa: ${field.name}'),
                                    backgroundColor: const Color(0xFF0284C7),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Modal Chọn / Chuyển Nhà Màng (Zone) ───
  void _showZoneSelectorModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final zones = provider.zones;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grid_view_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chọn Nhà Màng Canh Tác (Zone)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Trang trại: ${provider.currentFarm.name}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (provider.canManageFarmStructure)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          CropProfilesScreen.showCreateZone(context, provider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text(
                          'Thêm Zone',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: zones.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final z = zones[index];
                      final isSelected = index == provider.selectedZoneIndex;

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFECFDF5) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.eco,
                                color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    z.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF065F46) : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'ĐANG XEM',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text(
                                  'Cây trồng: ${z.currentCrop} • ${z.currentStage}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '${(z.areaM2).toStringAsFixed(0)} m²',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• Thửa: ${z.fieldName}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 22)
                                : const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
                            onTap: () {
                              provider.selectZone(index);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Đang hiển thị dữ liệu: ${z.name}'),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
