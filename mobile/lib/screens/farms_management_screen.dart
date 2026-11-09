import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import '../widgets/mini_gis_map_picker.dart';
import '../widgets/create_season_sheet.dart';
import 'zone_detail_screen.dart';
import 'crop_profiles_screen.dart';
import 'workforce_screen.dart';
import 'contracts_depreciation_screen.dart';
import 'farming_seasons_screen.dart';

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
            Text('Quản Lý Nông Trại & Khu Vực', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Multi-Farm & Hierarchical Zoning (Issue 5)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          if (provider.currentRole == 'OWNER') ...[
            IconButton(
              icon: const Icon(Icons.assignment_outlined, color: Colors.white),
              tooltip: 'Hợp đồng Zone & Khấu hao',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined, color: Colors.white),
              tooltip: 'Quản lý Nông dân & Nhân sự',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkforceScreen())),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Multi-tenant info banner (addresses Issue 5)
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
                      const Text(
                        'Tổ chức: Green Valley Agriculture Corp (Tenant-01)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF062326)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dữ liệu phân cấp: Tenant ➔ Nông Trại ➔ Thửa Đất (Field) ➔ Khu Vực (Zone). Các nông trại và khu vực được cô lập hoàn toàn logic.',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey[700], height: 1.3),
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
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
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
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractsDepreciationScreen())),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
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
            const SizedBox(height: 8),
            // Banner Quản lý Khung Vụ Mùa Canh Tác
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FarmingSeasonsScreen())),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khung Mùa Vụ Canh Tác (Farming Seasons)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kế hoạch vụ mùa Đông Xuân, Hè Thu theo năm và liên kết đợt trồng',
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
              const Text('DANH SÁCH NÔNG TRẠI (FARMS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
              TextButton.icon(
                onPressed: () => _showAddFarmDialog(context, provider),
                icon: const Icon(Icons.add_business, size: 16, color: Color(0xFF10B981)),
                label: const Text('Thêm Farm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
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
              const Text('PHÂN KHU THỬA ĐẤT (FIELDS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
              TextButton.icon(
                onPressed: () => _showAddFieldDialog(context, provider),
                icon: const Icon(Icons.add_chart, size: 16, color: Color(0xFF0284C7)),
                label: const Text('Thêm Thửa (Field)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
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
                              content: Text(isFieldSelected ? 'Đã bỏ lọc thửa đất (hiển thị tất cả)' : 'Đang lọc xem: ${f.name}'),
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
              const Text('CÁC NHÀ MÀNG TRONG LÔ / TRANG TRẠI (ZONES)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.8)),
              TextButton.icon(
                onPressed: () => CropProfilesScreen.showCreateZone(context, provider),
                icon: const Icon(Icons.add_home_work_outlined, size: 16, color: Color(0xFF10B981)),
                label: const Text('+ Thêm Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
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
      floatingActionButton: provider.currentRole == 'OWNER'
          ? FloatingActionButton.extended(
              onPressed: () => _showAddFarmDialog(context, provider),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business, size: 20),
              label: const Text('Thêm Trang Trại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : null,
    );
  }

  Widget _buildFarmCard(BuildContext context, FarmModel farm, FarmProvider provider) {
    final isCurrent = farm.farmId == provider.selectedFarmId;

    return InkWell(
      onTap: () {
        provider.selectFarm(farm.farmId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chọn: ${farm.name}'),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.agriculture, color: isCurrent ? const Color(0xFF059669) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(farm.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isCurrent ? const Color(0xFF065F46) : const Color(0xFF0F172A))),
                      if (isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Đang chọn', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(farm.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text('Diện tích: ${(farm.totalAreaM2 / 10000).toStringAsFixed(1)} ha (${farm.totalAreaM2.toInt()} m²)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                ],
              ),
            ),
            if (isCurrent)
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldItem(String name, String sub, String count, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.layers_outlined, color: isSelected ? Colors.white : const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(count, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(BuildContext context, ZoneModel zone, bool isSelected, int zoneIndex, VoidCallback onSelect) {
    return GestureDetector(
      onTap: () {
        onSelect();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ZoneDetailScreen(zone: zone, zoneIndex: zoneIndex),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF062326) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18)
                      else
                        const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCBD5E1)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (zone.needsSeason)
                    Row(
                      children: [
                        const Expanded(child: Text('Chưa có vụ đang canh tác.', style: TextStyle(fontSize: 11, color: Color(0xFFB45309)))),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                          onPressed: () async {
                            final created = await showCreateSeasonSheet(context, zone);
                            if (created == true && context.mounted) await context.read<FarmProvider>().fetchFromApi();
                          },
                          child: const Text('+ Tạo vụ mùa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  Text('Cây trồng: ${zone.currentCrop} • ${zone.currentStage}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildZoneMiniMetric(Icons.water_drop, zone.telemetryIsFresh ? '${zone.currentSoilMoisture}%' : '—', const Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      _buildZoneMiniMetric(Icons.thermostat, zone.telemetryIsFresh ? '${zone.currentTemp}°C' : '—', const Color(0xFFD97706)),
                      const SizedBox(width: 10),
                      _buildZoneMiniMetric(Icons.crop_square, '${zone.areaM2.toInt()} m²', const Color(0xFF64748B)),
                    ],
                  ),
                  // Assignee info (if available)
                  if (zone.assignedWorkerName != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_pin_circle_outlined, size: 12, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            '${zone.assignedWorkerName} • ${zone.workerRole ?? ''}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0369A1)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneMiniMetric(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ─── Modal Thêm Trang Trại Mới ───
  void _showAddFarmDialog(BuildContext context, FarmProvider provider) {
    final nextNum = provider.farms.length + 1;
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    // Khởi tạo tọa độ mặc định
    double currentLat = 11.8341;
    double currentLng = 108.5724;

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
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.add_business, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 10),
                  Text('Thêm Nông Trại Mới (Farm)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Khởi tạo cơ sở sản xuất mới thuộc tổ chức Green Valley Corp.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              const Text('Tên Nông Trại *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Nông trại Công nghệ cao',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Địa Chỉ Thực Địa *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: addressCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Xã/Phường, Huyện, Tỉnh thành',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
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
                    child: const Text('Chạm bản đồ để dời tâm', style: TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MiniGISMapPicker(
                initialCenter: LatLng(currentLat, currentLng),
                level: 'FARM',
                height: 250,
                onCenterChanged: (newCoord) {
                  currentLat = newCoord.latitude;
                  currentLng = newCoord.longitude;
                },
                onAddressResolved: (newAddress) {
                  // Cập nhật trực tiếp — KHÔNG dùng setModalState để tránh rebuild lại map
                  if (addressCtrl.text != newAddress) {
                    addressCtrl.text = newAddress;
                  }
                },
                onRegionNameResolved: (regionShortName) {
                  final newName = 'Nông trại CNC $regionShortName (Cơ sở 0$nextNum)';
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
                      onPressed: () {
                        final name = nameCtrl.text.trim().isEmpty ? 'Nông trại 0$nextNum' : nameCtrl.text.trim();
                        final address = addressCtrl.text.trim();

                        provider.addFarm(
                          name: name,
                          address: address,
                          latitude: currentLat,
                          longitude: currentLng,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Đã thêm thành công trang trại: "$name" và chuyển vùng làm việc!'),
                            backgroundColor: const Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Tạo Trang Trại', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // ─── Modal Thêm Thửa Đất (Field) Mới ───
  void _showAddFieldDialog(BuildContext context, FarmProvider provider) {
    final nextNum = provider.fieldsForCurrentFarm.length + 1;
    final nameCtrl = TextEditingController(text: 'Lô đất C$nextNum (Khu Canh Tác Mới)');
    final descCtrl = TextEditingController(text: 'Quy hoạch cụm nhà màng thông minh chuẩn VietGAP');
    final areaCtrl = TextEditingController(text: '12000');

    List<LatLng>? fieldPolygon;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
          ),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.add_chart, color: Color(0xFF0284C7), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Thêm Thửa Đất / Phân Khu (Field)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Thuộc trang trại: ${provider.currentFarm.name}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Tên Thửa Đất / Lô Đất *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Lô đất C3 (Khu Dưa Lưới)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Mô Tả Hạ Tầng / Loại Đất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Hệ thống tưới ngầm, đất phù sa đỏ bazan...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Diện Tích Thửa (m²) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: areaCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '10000 (tương đương 1.0 ha)',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 14),

              // Bản đồ số GIS Vệ tinh phân khu (Field GIS Map)
              Row(
                children: [
                  const Icon(Icons.satellite_alt, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Tọa Độ & Ranh Giới Thửa Đất (GIS)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Thửa đất (Field)', style: TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MiniGISMapPicker(
                initialCenter: LatLng(provider.currentFarm.latitude, provider.currentFarm.longitude),
                level: 'FIELD',
                existingPolygons: provider.fieldsForCurrentFarm
                    .where((f) => f.polygon != null && f.polygon!.isNotEmpty)
                    .map((f) => {
                          'name': f.name,
                          'polygon': f.polygon,
                        })
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
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Kiểm tra chống chọn đè lên Thửa đất khác của Farm
                        if (fieldPolygon != null && fieldPolygon!.length >= 3) {
                          bool isInsidePoly(LatLng pt, List<LatLng> poly) {
                            final double px = pt.longitude;
                            final double py = pt.latitude;
                            bool inside = false;
                            for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
                              final double xi = poly[i].longitude;
                              final double yi = poly[i].latitude;
                              final double xj = poly[j].longitude;
                              final double yj = poly[j].latitude;
                              if (((yi > py) != (yj > py)) &&
                                  (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                                inside = !inside;
                              }
                            }
                            return inside;
                          }

                          final otherFields = provider.fieldsForCurrentFarm
                              .where((f) => f.polygon != null && f.polygon!.length >= 3);
                          for (final of in otherFields) {
                            final pts = of.polygon!;
                            final isOverlapping = fieldPolygon!.any((pt) => isInsidePoly(pt, pts)) ||
                                pts.any((pt) => isInsidePoly(pt, fieldPolygon!));
                            if (isOverlapping) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('⚠️ Ranh giới đang chồng đè lên "${of.name}"! Không thể tạo.'),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                              return;
                            }
                          }
                        }

                        final name = nameCtrl.text.trim().isEmpty ? 'Lô đất 0$nextNum' : nameCtrl.text.trim();
                        final desc = descCtrl.text.trim().isEmpty ? 'Khu quy hoạch chuẩn VietGAP' : descCtrl.text.trim();
                        final area = double.tryParse(areaCtrl.text) ?? 10000.0;

                        provider.addField(
                          farmId: provider.selectedFarmId,
                          name: name,
                          description: desc,
                          areaM2: area,
                          polygon: fieldPolygon,
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🎉 Đã thêm thành công thửa đất: "$name"!'),
                            backgroundColor: const Color(0xFF0284C7),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Tạo Thửa Đất', style: TextStyle(fontWeight: FontWeight.bold)),
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
);
  }
}

