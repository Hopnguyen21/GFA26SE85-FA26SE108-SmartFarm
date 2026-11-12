part of '../farms_management_screen.dart';

extension _FarmsManagementScreenAddField on FarmsManagementScreen {
  // ─── Modal Thêm Thửa Đất (Field) Mới ───
  void _showAddFieldDialog(BuildContext context, FarmProvider provider) {
    if (!provider.canManageFarmStructure) {
      showAppSnack(
        context,
        'Chỉ chủ trang trại mới được tạo Farm, Thửa đất hoặc Zone.',
        error: true,
      );
      return;
    }
    final nextNum = provider.fieldsForCurrentFarm.length + 1;
    final nameCtrl = TextEditingController(
      text: 'Lô đất C$nextNum (Khu Canh Tác Mới)',
    );
    final descCtrl = TextEditingController(
      text: 'Quy hoạch cụm nhà màng thông minh chuẩn VietGAP',
    );
    final areaCtrl = TextEditingController(text: '12000');

    List<LatLng>? fieldPolygon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.add_chart,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thêm Thửa Đất / Phân Khu (Field)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Thuộc trang trại: ${provider.currentFarm.name}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Tên Thửa Đất / Lô Đất *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Lô đất C3 (Khu Dưa Lưới)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Mô Tả Hạ Tầng / Loại Đất',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Hệ thống tưới ngầm, đất phù sa đỏ bazan...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Diện Tích Thửa (m²) *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: areaCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '10000 (tương đương 1.0 ha)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bản đồ số GIS Vệ tinh phân khu (Field GIS Map)
                  Row(
                    children: [
                      const Icon(
                        Icons.satellite_alt,
                        size: 16,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Tọa Độ & Ranh Giới Thửa Đất (GIS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0284C7,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Thửa đất (Field)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MiniGISMapPicker(
                    initialCenter: LatLng(
                      provider.currentFarm.latitude,
                      provider.currentFarm.longitude,
                    ),
                    level: 'FIELD',
                    existingPolygons: provider.fieldsForCurrentFarm
                        .where(
                          (f) => f.polygon != null && f.polygon!.isNotEmpty,
                        )
                        .map((f) => {'name': f.name, 'polygon': f.polygon})
                        .toList(),
                    height: 250,
                    onPolygonChanged: (pts) {
                      fieldPolygon = pts;
                    },
                    onAreaCalculated: (areaM2) {
                      areaCtrl.text = areaM2.toStringAsFixed(0);
                    },
                    onRegionNameResolved: (regionShortName) {
                      final newName = 'Lô đất C$nextNum - Khu $regionShortName';
                      if (nameCtrl.text != newName) {
                        nameCtrl.text = newName;
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Huỷ',
                            style: TextStyle(color: Color(0xFF475569)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            // Kiểm tra chống chọn đè lên Thửa đất khác của Farm
                            if (fieldPolygon != null &&
                                fieldPolygon!.length >= 3) {
                              bool isInsidePoly(LatLng pt, List<LatLng> poly) {
                                final double px = pt.longitude;
                                final double py = pt.latitude;
                                bool inside = false;
                                for (
                                  int i = 0, j = poly.length - 1;
                                  i < poly.length;
                                  j = i++
                                ) {
                                  final double xi = poly[i].longitude;
                                  final double yi = poly[i].latitude;
                                  final double xj = poly[j].longitude;
                                  final double yj = poly[j].latitude;
                                  if (((yi > py) != (yj > py)) &&
                                      (px <
                                          (xj - xi) * (py - yi) / (yj - yi) +
                                              xi)) {
                                    inside = !inside;
                                  }
                                }
                                return inside;
                              }

                              final otherFields = provider.fieldsForCurrentFarm
                                  .where(
                                    (f) =>
                                        f.polygon != null &&
                                        f.polygon!.length >= 3,
                                  );
                              for (final of in otherFields) {
                                final pts = of.polygon!;
                                final isOverlapping =
                                    fieldPolygon!.any(
                                      (pt) => isInsidePoly(pt, pts),
                                    ) ||
                                    pts.any(
                                      (pt) => isInsidePoly(pt, fieldPolygon!),
                                    );
                                if (isOverlapping) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '⚠️ Ranh giới đang chồng đè lên "${of.name}"! Không thể tạo.',
                                      ),
                                      backgroundColor: const Color(0xFFEF4444),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                            }

                            final name = nameCtrl.text.trim().isEmpty
                                ? 'Lô đất 0$nextNum'
                                : nameCtrl.text.trim();
                            final desc = descCtrl.text.trim().isEmpty
                                ? 'Khu quy hoạch chuẩn VietGAP'
                                : descCtrl.text.trim();
                            final area = double.tryParse(areaCtrl.text) ?? 0.0;

                            final err = await provider.addField(
                              farmId: provider.selectedFarmId,
                              name: name,
                              description: desc,
                              areaM2: area,
                              polygon: fieldPolygon,
                            );
                            if (err != null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: const Color(0xFFEF4444),
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
                                  '🎉 Đã thêm thành công thửa đất: "$name"!',
                                ),
                                backgroundColor: const Color(0xFF0284C7),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(
                            'Tạo Thửa Đất',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
    ).then((_) => disposeControllersLater([nameCtrl, descCtrl, areaCtrl]));
  }
}
