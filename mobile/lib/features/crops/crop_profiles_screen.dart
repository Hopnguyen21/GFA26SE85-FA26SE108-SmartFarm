import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/form_section.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../core/widgets/mini_gis_map_picker.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';
import '../zones/zone_crop_plan_applier.dart';
import '../zones/zone_crop_plan_controller.dart';
import '../zones/zone_crop_plan_logic.dart';
import '../zones/widgets/zone_crop_plan_section.dart';
import '../zones/widgets/zone_profile_detail_page.dart';
import '../../core/services/api_service.dart';
import 'crop_detail_screen.dart';
import '../reports/vietgap_documents_screen.dart';
import '../../core/widgets/dispose_later.dart';
part 'parts/crop_profiles_screen_create_zone_dialog.dart';
part 'parts/crop_profiles_screen_card.dart';

class CropProfilesScreen extends StatefulWidget {
  final bool autoOpenCreateZone;

  const CropProfilesScreen({super.key, this.autoOpenCreateZone = false});

  /// Cho phép gọi trực tiếp modal Tạo Zone từ bất kỳ đâu
  static void showCreateZone(BuildContext context, FarmProvider provider) {
    _CropProfilesScreenState.showCreateZoneDialog(context, provider);
  }

  @override
  State<CropProfilesScreen> createState() => _CropProfilesScreenState();
}

class _CropProfilesScreenState extends State<CropProfilesScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenCreateZone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final provider = Provider.of<FarmProvider>(context, listen: false);
          showCreateZoneDialog(context, provider);
        }
      });
    }
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF062326) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF062326)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF062326).withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final isFarmer = provider.currentRole == 'FARMER';
    final role = ApiService.userRole?.toLowerCase();
    // Kho tài liệu VietGAP chỉ dành cho PlatformAdmin (khớp frontend và backend).
    final canReviewVietGapDocuments =
        ApiService.isAuthenticated && role == 'platformadmin';

    final profiles = provider.defaultCropProfiles.where((p) {
      if (_selectedCategory != 'ALL' && p.realCropId != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.nameEn.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.variety.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thư Viện Cây Trồng VietGAP',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Quy trình kỹ thuật, sâu bệnh & ngưỡng vi khí hậu',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          if (canReviewVietGapDocuments)
            IconButton(
              tooltip: 'Tài liệu VietGAP',
              icon: const Icon(
                Icons.library_books_outlined,
                color: Colors.white,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VietGapDocumentsScreen(),
                ),
              ),
            ),
          Container(
            margin: EdgeInsets.only(right: isFarmer ? 14 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF10B981), width: 0.5),
            ),
            child: Text(
              '${provider.defaultCropProfiles.length} loại cây',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Chỉ FarmOwner được tạo Zone (backend: POST /fields/{id}/zones chỉ cho FarmOwner)
          if (provider.canManageFarmStructure) ...[
            IconButton(
              tooltip: 'Tạo Zone Mới',
              icon: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF10B981),
              ),
              onPressed: () => showCreateZoneDialog(context, provider),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Top Library Intro Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF062326),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CẨM NANG QUY TRÌNH CÂY TRỒNG VIETGAP',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tra cứu giai đoạn phát triển, sâu bệnh hại và ngưỡng tự động hóa cho từng loại cây.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm cây trồng (Tên, giống, VietGAP)...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Xóa nội dung tìm kiếm',
                        icon: const Icon(
                          Icons.clear,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // Category Quick Chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  'Tất cả',
                  _selectedCategory == 'ALL',
                  () => setState(() => _selectedCategory = 'ALL'),
                ),
                // Bộ lọc theo cây trồng thật trong thư viện (lấy từ API)
                for (final crop in {
                  for (final p in provider.defaultCropProfiles)
                    p.realCropId: '${p.emoji} ${p.name}',
                }.entries) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    crop.value,
                    _selectedCategory == crop.key,
                    () => setState(() => _selectedCategory = crop.key),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Profile List
          Expanded(
            child: profiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🌱', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          provider.defaultCropProfiles.isEmpty
                              ? 'Chưa tải được thư viện cây trồng từ máy chủ'
                              : 'Không tìm thấy cây trồng nào',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return _CropProfileCard(
                        profile: profile,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CropDetailScreen(profile: profile),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static void showCreateZoneDialog(
    BuildContext context,
    FarmProvider provider,
  ) => _showCreateZoneDialogImpl(context, provider);
}
