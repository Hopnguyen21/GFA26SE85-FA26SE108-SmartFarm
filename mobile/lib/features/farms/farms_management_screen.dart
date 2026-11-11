import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';
import '../../core/widgets/mini_gis_map_picker.dart';
import 'farm_create_logic.dart';
import '../crops/widgets/create_season_sheet.dart';
import '../zones/zone_detail_screen.dart';
import '../crops/crop_profiles_screen.dart';
import '../workforce/workforce_screen.dart';
import '../contracts/contracts_depreciation_screen.dart';
import 'farm_setup_wizard_screen.dart';
import '../../core/widgets/dispose_later.dart';

part 'parts/farms_management_screen_cards.dart';
part 'parts/farms_management_screen_add_farm.dart';
part 'parts/farms_management_screen_add_field.dart';

class FarmsManagementScreen extends StatelessWidget {
  const FarmsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản Lý Nông Trại & Khu Vực',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Multi-Farm & Hierarchical Zoning (Issue 5)',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          if (provider.currentRole == 'OWNER') ...[
            IconButton(
              icon: const Icon(Icons.assignment_outlined, color: Colors.white),
              tooltip: 'Hợp đồng Zone & Khấu hao',
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
              tooltip: 'Quản lý Nông dân & Nhân sự',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkforceScreen())),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.fetchFromApi,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Tổ chức lấy từ backend (GET /tenants/me); không có dữ liệu thì không hiển thị.
            if (provider.tenantName != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF062326).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF062326).withValues(alpha: 0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.corporate_fare, color: Color(0xFF062326), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổ chức: ${provider.tenantName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF062326)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Dữ liệu phân cấp: Tổ chức ➔ Nông trại ➔ Thửa đất (Field) ➔ Khu vực (Zone).',
                            style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (provider.currentRole == 'OWNER') ...[
              const SizedBox(height: 12),
              // Banner Quản lý nhân sự & tài khoản Farmer
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkforceScreen())),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.badge_outlined, color: Color(0xFF0D9488), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quản lý Tài Khoản & Nông Dân (Farmers)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${provider.farmersForCurrentFarm.length} nhân sự thuộc ${provider.currentFarm.name}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Banner Quản lý Hợp Đồng & Khấu Hao Thiết Bị
              InkWell(
                onTap: () =>
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF059669), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hợp Đồng Thuê Vùng Trồng & Khấu Hao',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Quản lý hợp đồng Zone, điều khoản bên thuê và khấu hao tài sản',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'DANH SÁCH NÔNG TRẠI (FARMS)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (provider.currentRole == 'OWNER')
                  IconButton(
                    tooltip: 'Thiết lập nhanh: Farm → Lô → Zone → Vụ → IoT',
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmSetupWizardScreen())),
                    icon: const Icon(Icons.auto_fix_high, size: 18, color: Color(0xFF10B981)),
                    visualDensity: VisualDensity.compact,
                  ),
                if (provider.canManageFarmStructure)
                  TextButton.icon(
                    onPressed: () => _showAddFarmDialog(context, provider),
                    icon: const Icon(Icons.add_business, size: 16, color: Color(0xFF10B981)),
                    label: const Text(
                      'Thêm Farm',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            ...provider.farms.map((farm) => _buildFarmCard(context, farm, provider)),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PHÂN KHU THỬA ĐẤT (FIELDS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                if (provider.canManageFarmStructure)
                  TextButton.icon(
                    onPressed: () => _showAddFieldDialog(context, provider),
                    icon: const Icon(Icons.add_chart, size: 16, color: Color(0xFF0284C7)),
                    label: const Text(
                      'Thêm Thửa (Field)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ...provider.fieldsForCurrentFarm.asMap().entries.map((entry) {
                    final i = entry.key;
                    final f = entry.value;
                    final isFieldSelected = provider.selectedFieldId == f.fieldId;
                    final fieldZoneCount = provider.allZones.where((z) => z.fieldId == f.fieldId).length;

                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 16),
                        InkWell(
                          onTap: () {
                            provider.selectField(isFieldSelected ? null : f.fieldId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isFieldSelected ? 'Đã bỏ lọc thửa đất (hiển thị tất cả)' : 'Đang lọc xem: ${f.name}',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: _buildFieldItem(
                            f.name,
                            '${f.description} • ${(f.areaM2 / 10000).toStringAsFixed(1)} ha',
                            '$fieldZoneCount Nhà màng',
                            isSelected: isFieldSelected,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CÁC NHÀ MÀNG TRONG LÔ / TRANG TRẠI (ZONES)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
                if (provider.canManageFarmStructure)
                  TextButton.icon(
                    onPressed: () => CropProfilesScreen.showCreateZone(context, provider),
                    icon: const Icon(Icons.add_home_work_outlined, size: 16, color: Color(0xFF10B981)),
                    label: const Text(
                      '+ Thêm Zone',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                    ),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            ...provider.zones.asMap().entries.map((entry) {
              final idx = entry.key;
              final zone = entry.value;
              final isSelected = provider.selectedZoneIndex == idx;
              return _buildZoneCard(context, zone, isSelected, idx, () => provider.selectZone(idx));
            }),
          ],
        ),
      ),
      floatingActionButton: provider.currentRole == 'OWNER'
          ? FloatingActionButton.extended(
              onPressed: () => CropProfilesScreen.showCreateZone(context, provider),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_home_work_outlined, size: 20),
              label: const Text('Tạo Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : null,
    );
  }
}
