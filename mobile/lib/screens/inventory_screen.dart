import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import '../widgets/dispose_later.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _selectedCategory = 'ALL';
  String _searchQuery = '';

  static const _categoryMap = <String, (String, IconData, Color)>{
    'ALL': ('Tất Cả', Icons.all_inclusive, Color(0xFF0F766E)),
    'FERTILIZER': ('Phân Bón', Icons.eco, Color(0xFF10B981)),
    'SEED': ('Hạt Giống', Icons.grain, Color(0xFFF59E0B)),
    'PESTICIDE': ('Thuốc BVTV Sinh Học', Icons.medical_services_outlined, Color(0xFFE11D48)),
    'EQUIPMENT': ('Vật Tư & Phụ Tùng', Icons.build_outlined, Color(0xFF0284C7)),
  };

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final items = provider.inventoryItemsForCurrentFarm;
    final lowStockCount = provider.lowStockCount;

    final filteredItems = items.where((item) {
      final matchesCategory = _selectedCategory == 'ALL' || item.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          item.materialName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kho Vật Tư & Phân Bón',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Trang trại: ${provider.currentFarm.name}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
            tooltip: 'Nhập thêm vật tư',
            onPressed: () => _showAddMaterialModal(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF062326),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF34D399), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tổng Danh Mục', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                                Text('${items.length} Loại', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lowStockCount > 0
                              ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: lowStockCount > 0
                                ? const Color(0xFFF87171).withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: lowStockCount > 0
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                    : const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                lowStockCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                color: lowStockCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF34D399),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Sắp Hết Hàng', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                                Text(
                                  lowStockCount > 0 ? '$lowStockCount Dưới Mức' : 'Đủ Định Mức',
                                  style: TextStyle(
                                    color: lowStockCount > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Box
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Tìm kiếm vật tư, mã hàng, vị trí lưu...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Category Chips Filter
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _categoryMap.entries.map((entry) {
                final isSelected = _selectedCategory == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value.$1),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = entry.key),
                    selectedColor: const Color(0xFF062326),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF062326) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              }).toList(),
            ),
          ),

          // Inventory List View
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Không tìm thấy vật tư nào trong kho',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showAddMaterialModal(context, provider),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm vật tư mới'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, idx) {
                      final item = filteredItems[idx];
                      return _buildInventoryCard(context, provider, item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: provider.currentRole == 'OWNER'
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMaterialModal(context, provider),
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nhập Vật Tư', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : null,
    );
  }

  Widget _buildInventoryCard(BuildContext context, FarmProvider provider, MaterialInventoryModel item) {
    final catInfo = _categoryMap[item.category] ?? ('Khác', Icons.category, const Color(0xFF64748B));
    final isLow = item.isLowStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLow ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
          width: isLow ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code, Category, Status Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: catInfo.$3.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(catInfo.$2, size: 11, color: catInfo.$3),
                      const SizedBox(width: 4),
                      Text(
                        catInfo.$1,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catInfo.$3),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isLow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'SẮP HẾT HÀNG',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'ĐỦ ĐỊNH MỨC',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Material Name & Details
            Text(
              item.materialName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),

            // Quantity & Min Stock Info
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(text: 'Tồn kho: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        TextSpan(
                          text: '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                          style: TextStyle(
                            color: isLow ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: ' (Định mức tối thiểu: ${item.minimumStock.toStringAsFixed(0)} ${item.unit})',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            const Divider(height: 16),

            // Actions: Adjust Stock
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showAdjustStockModal(context, provider, item),
                  icon: const Icon(Icons.edit_note, size: 16, color: Color(0xFF0284C7)),
                  label: const Text('Điều chỉnh / Xuất nhập kho', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: const Color(0xFFF0F9FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustStockModal(BuildContext context, FarmProvider provider, MaterialInventoryModel item) {
    final qtyCtrl = TextEditingController(text: item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1));

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
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.materialName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
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
                    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Đã cập nhật tồn kho: $newQty ${item.unit}')));
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
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
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
                            DropdownMenuItem(value: 'FERTILIZER', child: Text('Phân Bón', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'SEED', child: Text('Hạt Giống', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'PESTICIDE', child: Text('Thuốc Sinh Học', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'EQUIPMENT', child: Text('Vật Tư & Tưới', style: TextStyle(fontSize: 12))),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập tên vật tư')),
                          );
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
