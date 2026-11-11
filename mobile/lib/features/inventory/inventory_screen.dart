import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';
import '../../core/widgets/dispose_later.dart';

part 'parts/inventory_screen_card.dart';
part 'parts/inventory_screen_dialogs.dart';

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
      final matchesQuery = _searchQuery.isEmpty || item.materialName.toLowerCase().contains(_searchQuery.toLowerCase());
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
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tổng Danh Mục',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${items.length} Loại',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sắp Hết Hàng',
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    lowStockCount > 0 ? '$lowStockCount Dưới Mức' : 'Đủ Định Mức',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: lowStockCount > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
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
                      side: BorderSide(color: isSelected ? const Color(0xFF062326) : const Color(0xFFE2E8F0)),
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
                : RefreshIndicator(
                    onRefresh: provider.fetchFromApi,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, idx) {
                        final item = filteredItems[idx];
                        return _buildInventoryCard(context, provider, item);
                      },
                    ),
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
}
