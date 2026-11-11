part of '../inventory_screen.dart';

extension _InventoryScreenStateDialogs on _InventoryScreenState {
  void _showAdjustStockModal(BuildContext context, FarmProvider provider, MaterialInventoryModel item) {
    final qtyCtrl = TextEditingController(
      text: item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Điều Chỉnh Số Lượng Tồn',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(item.materialName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Số lượng tồn mới (${item.unit})',
                  hintText: 'Nhập số lượng thực tế trong kho',
                  suffixText: item.unit,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final newQty = double.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
                    final diff = newQty - item.quantity;
                    final messenger = ScaffoldMessenger.of(context);
                    if (diff == 0 || newQty < 0) {
                      Navigator.pop(ctx);
                      return;
                    }
                    String? error;
                    if (diff > 0) {
                      error = await provider.receiveStock(item.inventoryId, diff);
                    } else {
                      // Xuất kho phải ghi rõ Zone sử dụng để giữ lịch sử.
                      final zoneId = await showDialog<String>(
                        context: ctx,
                        builder: (dCtx) => SimpleDialog(
                          title: const Text('Xuất cho Zone nào?', style: TextStyle(fontSize: 15)),
                          children: [
                            for (final z in provider.allZones)
                              SimpleDialogOption(onPressed: () => Navigator.pop(dCtx, z.zoneId), child: Text(z.name)),
                          ],
                        ),
                      );
                      if (zoneId == null) return;
                      error = await provider.issueStock(item.inventoryId, -diff, zoneId);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    messenger.showSnackBar(
                      SnackBar(content: Text(error ?? 'Đã cập nhật tồn kho: $newQty ${item.unit}')),
                    );
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('XÁC NHẬN CẬP NHẬT TỒN KHO', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => disposeControllersLater([qtyCtrl]));
  }

  void _showAddMaterialModal(BuildContext context, FarmProvider provider) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '100');
    final unitCtrl = TextEditingController(text: 'kg');
    final minStockCtrl = TextEditingController(text: '20');
    String selectedCat = 'FERTILIZER';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nhập Thêm Vật Tư Mới Vào Kho',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tên vật tư nông nghiệp *',
                      hintText: 'Ví dụ: Phân bón Kali Clorua, Hạt giống Ớt chuông...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCat,
                          decoration: InputDecoration(
                            labelText: 'Phân loại',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'FERTILIZER',
                              child: Text('Phân Bón', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: 'SEED',
                              child: Text('Hạt Giống', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: 'PESTICIDE',
                              child: Text('Thuốc Sinh Học', style: TextStyle(fontSize: 12)),
                            ),
                            DropdownMenuItem(
                              value: 'EQUIPMENT',
                              child: Text('Vật Tư & Tưới', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          onChanged: (val) => setModalState(() => selectedCat = val ?? 'FERTILIZER'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Số lượng nhập',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          decoration: InputDecoration(
                            labelText: 'Đơn vị tính (kg, lít, cuộn)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Mức tồn tối thiểu',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên vật tư')));
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        final error = await provider.addInventoryItem(
                          materialName: name,
                          category: selectedCat,
                          quantity: double.tryParse(qtyCtrl.text.trim()) ?? 0,
                          unit: unitCtrl.text.trim(),
                          minimumStock: double.tryParse(minStockCtrl.text.trim()) ?? 0,
                        );
                        if (error != null) {
                          messenger.showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(SnackBar(content: Text('Đã thêm "$name" vào kho vật tư')));
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('LƯU VẬT TƯ VÀO KHO', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) => disposeControllersLater([nameCtrl, qtyCtrl, unitCtrl, minStockCtrl]));
  }
}
