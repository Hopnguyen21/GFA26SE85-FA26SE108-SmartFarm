import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/mini_gis_map_picker.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';
import '../widgets/honeycomb_topology_widget.dart';
import '../services/api_service.dart';
import 'crop_detail_screen.dart';
import 'vietgap_documents_screen.dart';

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
      if (_selectedCategory != 'ALL' && p.cropId != _selectedCategory) {
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
              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
          // Chỉ OWNER và TECHNICIAN mới được tạo Zone mới
          if (!isFarmer) ...[
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
                const SizedBox(width: 8),
                _buildFilterChip(
                  '🍅 Cà chua',
                  _selectedCategory == 'crop-tomato',
                  () => setState(() => _selectedCategory = 'crop-tomato'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '🍓 Dâu tây',
                  _selectedCategory == 'crop-strawberry',
                  () => setState(() => _selectedCategory = 'crop-strawberry'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '🥒 Dưa leo',
                  _selectedCategory == 'crop-cucumber',
                  () => setState(() => _selectedCategory = 'crop-cucumber'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '🫑 Ớt chuông',
                  _selectedCategory == 'crop-bellpepper',
                  () => setState(() => _selectedCategory = 'crop-bellpepper'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  '🍈 Dưa lưới',
                  _selectedCategory == 'crop-melon',
                  () => setState(() => _selectedCategory = 'crop-melon'),
                ),
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
                          'Không tìm thấy cây trồng nào',
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
  ) {
    final nextZoneNum = provider.zones.length + 1;
    final nameController = TextEditingController(
      text: 'Nhà màng 0$nextZoneNum',
    );
    final areaController = TextEditingController(text: '5000');
    final farmWorkers = provider.farmersForCurrentFarm;
    String? selectedFarmerId = farmWorkers.isNotEmpty
        ? farmWorkers.first.farmerId
        : null;
    String selectedCropId = provider.defaultCropProfiles.first.cropId;

    String? selectedFieldId =
        provider.selectedFieldId ??
        (provider.fieldsForCurrentFarm.isNotEmpty
            ? provider.fieldsForCurrentFarm.first.fieldId
            : null);
    List<LatLng>? currentZonePolygon;
    bool requestInspectionOnCreate = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final selectedCrop = provider.defaultCropProfiles.firstWhere(
            (p) => p.cropId == selectedCropId,
          );
          final fields = provider.fieldsForCurrentFarm;

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
                    const Row(
                      children: [
                        Icon(
                          Icons.add_business,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Tạo Mới Nhà Màng (Zone)',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Khởi tạo nhà màng con thuộc Lô đất và Farm: ${provider.currentFarm.name}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lựa chọn Thửa đất (Field) mà Zone này trực thuộc
                    const Text(
                      'Thuộc Thửa Đất / Phân Khu (Field) *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedFieldId,
                          icon: const Icon(
                            Icons.layers_outlined,
                            color: Color(0xFF0284C7),
                          ),
                          items: fields.map((f) {
                            return DropdownMenuItem<String>(
                              value: f.fieldId,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.map,
                                    size: 16,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${f.name} (${(f.areaM2 / 10000).toStringAsFixed(1)} ha)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0369A1),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedFieldId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tên Zone
                    const Text(
                      'Tên Nhà màng / Zone *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ví dụ: Nhà màng 04',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Diện tích & Nhân sự
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Diện tích (m²)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: areaController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 13),
                                onChanged: (_) {
                                  setModalState(() {});
                                },
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Người phụ trách *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: selectedFarmerId,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                    items: farmWorkers.map((w) {
                                      return DropdownMenuItem<String>(
                                        value: w.farmerId,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF0284C7,
                                                ).withValues(alpha: 0.12),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.person,
                                                size: 14,
                                                color: Color(0xFF0284C7),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                w.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(
                                          () => selectedFarmerId = val,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Chọn giống cây trồng từ thư viện
                    const Text(
                      'Chọn Cây Trồng Chuẩn VietGAP Ban Đầu *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCropId,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF062326),
                          ),
                          items: provider.defaultCropProfiles.map((p) {
                            return DropdownMenuItem<String>(
                              value: p.cropId,
                              child: Row(
                                children: [
                                  Text(
                                    p.emoji,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${p.name} (${p.variety.split(' / ').first}) – ${p.totalCycleDays} ngày',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedCropId = val);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedCrop.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ngưỡng ẩm VietGAP: ${selectedCrop.growthStages.first.requirements.soilMoistureMin.toInt()}% – ${selectedCrop.growthStages.first.requirements.soilMoistureMax.toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                                Text(
                                  'Tự động tạo Bơm tưới & Quạt đối lưu kèm AutoRule chuẩn ${selectedCrop.name}.',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bản đồ số GIS Vị trí Nhà Màng (Zone GIS Map)
                    Row(
                      children: [
                        const Icon(
                          Icons.satellite_alt,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Vị Trí & Ranh Giới Zone GIS',
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
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Nhà màng (Zone)',
                            style: TextStyle(
                              fontSize: 9.5,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final selectedField = fields.firstWhere(
                          (f) => f.fieldId == selectedFieldId,
                          orElse: () => fields.isNotEmpty
                              ? fields.first
                              : FieldModel(
                                  fieldId: 'field-01',
                                  farmId: provider.selectedFarmId,
                                  name: 'Lô đất 01',
                                  description: '',
                                  areaM2: 25000,
                                ),
                        );
                        final fieldPolygon = selectedField.polygon;

                        // Lấy danh sách các Zone đã có trên Thửa đất mẹ này
                        final existingZonesInField = provider.allZones
                            .where(
                              (z) =>
                                  z.fieldId == selectedField.fieldId &&
                                  z.polygon != null &&
                                  z.polygon!.isNotEmpty,
                            )
                            .map(
                              (z) => {
                                'name': z.name.split(' - ').first,
                                'polygon': z.polygon,
                              },
                            )
                            .toList();

                        return MiniGISMapPicker(
                          key: ValueKey('zone_picker_${selectedField.fieldId}'),
                          initialCenter: LatLng(
                            provider.currentFarm.latitude,
                            provider.currentFarm.longitude,
                          ),
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
                            final newName =
                                'Nhà màng 0$nextZoneNum - Khu $regionShortName';
                            if (nameController.text != newName) {
                              nameController.text = newName;
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Tóm tắt Mô phỏng Thiết bị & Chi phí theo Diện tích đã vẽ/nhập
                    Builder(
                      builder: (_) {
                        final currentArea =
                            double.tryParse(areaController.text) ?? 5000.0;
                        final sim = ZoneCostSimulation.calculate(
                          areaM2: currentArea,
                          cropName: selectedCrop.name,
                        );

                        return HoneycombTopologyCard(
                          simulation: sim.honeycomb,
                          initialExpanded: true,
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tùy chọn gửi Admin duyệt & điều Kỹ thuật viên xuống kiểm tra thực địa
                    InkWell(
                      onTap: () {
                        setModalState(() {
                          requestInspectionOnCreate =
                              !requestInspectionOnCreate;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: requestInspectionOnCreate
                              ? const Color(0xFFF0FDFA)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: requestInspectionOnCreate
                                ? const Color(0xFF0F766E)
                                : const Color(0xFFE2E8F0),
                            width: requestInspectionOnCreate ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              requestInspectionOnCreate
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: requestInspectionOnCreate
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gửi yêu cầu cho Admin duyệt & điều KTV thực địa',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Admin sẽ phân công Kỹ thuật viên IoT xuống đo đạc, kiểm tra mặt bằng thực tế.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              // Kiểm tra nếu có polygon và polygon bị lòi ra ngoài Field hoặc đè lên Zone khác
                              if (currentZonePolygon != null &&
                                  currentZonePolygon!.length >= 3) {
                                final selectedField = fields.firstWhere(
                                  (f) => f.fieldId == selectedFieldId,
                                  orElse: () => fields.isNotEmpty
                                      ? fields.first
                                      : FieldModel(
                                          fieldId: 'field-01',
                                          farmId: provider.selectedFarmId,
                                          name: 'Lô đất 01',
                                          description: '',
                                          areaM2: 25000,
                                        ),
                                );

                                // Kiểm tra xem có đè lên Zone nào không
                                final otherZones = provider.allZones.where(
                                  (z) =>
                                      z.fieldId == selectedField.fieldId &&
                                      z.polygon != null &&
                                      z.polygon!.length >= 3,
                                );

                                bool isInsidePoly(
                                  LatLng pt,
                                  List<LatLng> poly,
                                ) {
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

                                // 1. Kiểm tra lòi ra ngoài Thửa đất
                                if (selectedField.polygon != null &&
                                    selectedField.polygon!.length >= 3) {
                                  final isOutside = currentZonePolygon!.any(
                                    (pt) => !isInsidePoly(
                                      pt,
                                      selectedField.polygon!,
                                    ),
                                  );
                                  if (isOutside) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          '⚠️ Ranh giới Zone đang vượt ra ngoài Thửa đất! Vui lòng chỉnh lại vào trong.',
                                        ),
                                        backgroundColor: const Color(
                                          0xFFEF4444,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                // 2. Kiểm tra đè lên Zone khác
                                for (final oz in otherZones) {
                                  final pts = oz.polygon!;
                                  final isOverlapping =
                                      currentZonePolygon!.any(
                                        (pt) => isInsidePoly(pt, pts),
                                      ) ||
                                      pts.any(
                                        (pt) => isInsidePoly(
                                          pt,
                                          currentZonePolygon!,
                                        ),
                                      );
                                  if (isOverlapping) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '⚠️ Ranh giới đang chồng đè lên "${oz.name.split(' - ').first}"! Không thể tạo.',
                                        ),
                                        backgroundColor: const Color(
                                          0xFFEF4444,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }
                              }

                              final zoneName =
                                  nameController.text.trim().isEmpty
                                  ? 'Nhà màng 0$nextZoneNum'
                                  : nameController.text.trim();
                              final area =
                                  double.tryParse(areaController.text) ??
                                  5000.0;
                              final chosenFarmer = farmWorkers.firstWhere(
                                (w) => w.farmerId == selectedFarmerId,
                                orElse: () => farmWorkers.isNotEmpty
                                    ? farmWorkers.first
                                    : FarmerModel(
                                        farmerId: 'farmer-fallback',
                                        farmId: provider.selectedFarmId,
                                        name: 'Trần Văn Bình',
                                        role: 'Nông dân Thực địa',
                                        phone: '',
                                      ),
                              );

                              provider.addNewZone(
                                name: '$zoneName - ${selectedCrop.name}',
                                areaM2: area,
                                cropProfileId: selectedCropId,
                                assignedWorkerName: chosenFarmer.name,
                                workerRole: chosenFarmer.role,
                                customFieldId: selectedFieldId,
                                polygon: currentZonePolygon,
                              );

                              if (requestInspectionOnCreate) {
                                final sim = ZoneCostSimulation.calculate(
                                  areaM2: area,
                                  cropName: selectedCrop.name,
                                );
                                provider.submitInspectionRequest(
                                  zoneId: provider.currentZone.zoneId,
                                  zoneName: '$zoneName - ${selectedCrop.name}',
                                  areaM2: area,
                                  cropName: selectedCrop.name,
                                  estimatedCostVND: sim.totalEquipmentCostVND,
                                  contactName: chosenFarmer.name,
                                  contactPhone: chosenFarmer.phone.isNotEmpty
                                      ? chosenFarmer.phone
                                      : '0908 123 456',
                                  preferredDate:
                                      '${DateTime.now().add(const Duration(days: 2)).day}/${DateTime.now().month}/${DateTime.now().year} (Sáng)',
                                  note:
                                      'Yêu cầu khảo sát thực địa đo đạc mặt bằng khi khởi tạo $zoneName.',
                                );
                              }

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    requestInspectionOnCreate
                                        ? '🎉 Đã tạo "$zoneName" & gửi yêu cầu khảo sát thực địa cho Admin duyệt!'
                                        : '🎉 Đã tạo thành công "$zoneName" gán cây ${selectedCrop.emoji} ${selectedCrop.name}!',
                                  ),
                                  backgroundColor: const Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Tạo Zone & Áp Dụng',
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
      ),
    );
  }
}

class _CropProfileCard extends StatelessWidget {
  final DefaultCropProfile profile;
  final VoidCallback onTap;

  const _CropProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final firstStage = profile.growthStages.first;
    final lastStage = profile.growthStages.last;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hàng 1: Icon lớn, Tên giống & Badge Chu kỳ ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Center(
                        child: Text(
                          profile.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.isApplied) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'ĐANG TRỒNG',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF062326),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${profile.totalCycleDays} ngày',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profile.nameEn} • Giống: ${profile.variety.split(' / ').first}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 12,
                                      color: Color(0xFF059669),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tiêu chuẩn VietGAP',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: profile.difficulty == 'DỄ'
                                      ? const Color(0xFFECFDF5)
                                      : profile.difficulty == 'KHÓ'
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: profile.difficulty == 'DỄ'
                                        ? const Color(0xFFA7F3D0)
                                        : profile.difficulty == 'KHÓ'
                                        ? const Color(0xFFFECACA)
                                        : const Color(0xFFFDE68A),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  profile.difficulty,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: profile.difficulty == 'DỄ'
                                        ? const Color(0xFF059669)
                                        : profile.difficulty == 'KHÓ'
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFD97706),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${profile.growthStages.length} giai đoạn',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Text(
                  profile.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 14),

                // ── Hàng 2: Khối thông số vi khí hậu trực quan ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      // Độ ẩm đất
                      Expanded(
                        child: _metricColumn(
                          icon: Icons.water_drop,
                          iconColor: const Color(0xFF0284C7),
                          label: 'Độ ẩm đất',
                          value:
                              '${firstStage.requirements.soilMoistureMin.toInt()}%–${firstStage.requirements.soilMoistureMax.toInt()}%',
                          caption: 'Ngưỡng an toàn',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // Nhiệt độ
                      Expanded(
                        child: _metricColumn(
                          icon: Icons.thermostat,
                          iconColor: const Color(0xFFEA580C),
                          label: 'Nhiệt độ',
                          value:
                              '${firstStage.requirements.tempMin.toInt()}–${firstStage.requirements.tempMax.toInt()}°C',
                          caption: 'Tối ưu sinh trưởng',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: const Color(0xFFE2E8F0),
                      ),
                      // Lượng tưới
                      Expanded(
                        child: _metricColumn(
                          icon: Icons.alarm,
                          iconColor: const Color(0xFF059669),
                          label: 'Chế độ tưới',
                          value:
                              '${firstStage.requirements.irrigationDurationMin}p / lần',
                          caption:
                              '${firstStage.requirements.irrigationFrequencyPerDay} lần/ngày',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Hàng 3: Timeline chu kỳ tóm tắt (Giai đoạn đầu -> thu hoạch) ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text(
                        firstStage.iconEmoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${firstStage.name} → ${lastStage.name}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricColumn({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String caption,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          caption,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
