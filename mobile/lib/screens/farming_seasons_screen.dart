import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';

class FarmingSeasonsScreen extends StatefulWidget {
  const FarmingSeasonsScreen({super.key});

  @override
  State<FarmingSeasonsScreen> createState() => _FarmingSeasonsScreenState();
}

class _FarmingSeasonsScreenState extends State<FarmingSeasonsScreen> {
  bool _isLoading = false;
  List<FarmingSeasonModel> _seasons = [];
  int _selectedYear = 2026;
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.getFarmingSeasons(
        year: _selectedYear,
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _seasons = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final isOwner = provider.currentRole == 'OWNER';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Khung Mùa Vụ Canh Tác',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Farming Seasons Management',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadSeasons,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // Year selector dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF062326).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      isDense: true,
                      items: [2024, 2025, 2026, 2027].map((y) {
                        return DropdownMenuItem<int>(
                          value: y,
                          child: Text('Năm $y', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedYear = val);
                          _loadSeasons();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Status chip filters
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tất cả', _selectedStatus == 'ALL', () {
                          setState(() => _selectedStatus = 'ALL');
                          _loadSeasons();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Đang canh tác', _selectedStatus == 'Active', () {
                          setState(() => _selectedStatus = 'Active');
                          _loadSeasons();
                        }),
                        const SizedBox(width: 6),
                        _buildFilterChip('Đã kết thúc', _selectedStatus == 'Completed', () {
                          setState(() => _selectedStatus = 'Completed');
                          _loadSeasons();
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                : RefreshIndicator(
                    onRefresh: _loadSeasons,
                    color: const Color(0xFF10B981),
                    child: _seasons.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.calendar_month_outlined, size: 54, color: Color(0xFFCBD5E1)),
                                    SizedBox(height: 12),
                                    Text('Không có mùa vụ canh tác nào.',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _seasons.length,
                            itemBuilder: (ctx, index) {
                              final season = _seasons[index];
                              return _buildSeasonCard(season, isOwner);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, color: Color(0xFF10B981)),
              label: const Text('Thêm Vụ Mùa Mới', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _showCreateSeasonDialog,
            )
          : null,
    );
  }

  Widget _buildSeasonCard(FarmingSeasonModel season, bool isOwner) {
    final isActive = season.status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFFE2E8F0)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF062326),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        season.code,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      season.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Đang diễn ra' : 'Đã kết thúc',
                    style: TextStyle(
                      color: isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (season.description != null && season.description!.isNotEmpty) ...[
              Text(season.description!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              const SizedBox(height: 8),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${season.startDate} ➔ ${season.endDate}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.eco_outlined, size: 12, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text('${season.plantingSeasonsCount} Đợt trồng',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ],
                  ),
                ),
              ],
            ),

            if (isOwner) ...[
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditSeasonDialog(season),
                    icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF64748B)),
                    label: const Text('Chỉnh sửa', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteSeason(season),
                    icon: const Icon(Icons.archive_outlined, size: 14, color: Color(0xFFDC2626)),
                    label: const Text('Lưu trữ', style: TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF062326) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF062326) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showCreateSeasonDialog() {
    final codeCtrl = TextEditingController(text: 'VU-2026-DX01');
    final nameCtrl = TextEditingController(text: 'Vụ Đông Xuân 2026');
    final descCtrl = TextEditingController(text: 'Khung vụ mùa canh tác chính vùng Đà Lạt');
    DateTime startDate = DateTime(2026, 1, 1);
    DateTime endDate = DateTime(2026, 4, 30);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          title: const Text('Thêm Vụ Mùa Canh Tác Mới', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mã vụ mùa (Code):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: codeCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'VU-2026-DX01')),
                const SizedBox(height: 10),
                const Text('Tên vụ mùa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Vụ Đông Xuân 2026')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ngày bắt đầu:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setModalState(() => startDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                              child: Text(DateFormat('yyyy-MM-dd').format(startDate), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ngày kết thúc:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) setModalState(() => endDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                              child: Text(DateFormat('yyyy-MM-dd').format(endDate), style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Mô tả mục tiêu vụ mùa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF062326), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final res = await ApiService.createFarmingSeason({
                  'code': codeCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'year': startDate.year,
                  'startDate': DateFormat('yyyy-MM-dd').format(startDate),
                  'endDate': DateFormat('yyyy-MM-dd').format(endDate),
                  'description': descCtrl.text.trim(),
                  'status': 'Active',
                });
                if (!mounted) return;
                if (res != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo vụ mùa thành công!')));
                  _loadSeasons();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi tạo vụ mùa.')));
                }
              },
              child: const Text('Lưu Vụ Mùa'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSeasonDialog(FarmingSeasonModel season) {
    final nameCtrl = TextEditingController(text: season.name);
    final descCtrl = TextEditingController(text: season.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sửa ${season.code}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tên vụ mùa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(controller: nameCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const Text('Mô tả:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF062326), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await ApiService.updateFarmingSeason(season.id, {
                'name': nameCtrl.text.trim(),
                'code': season.code,
                'year': season.year,
                'startDate': season.startDate,
                'endDate': season.endDate,
                'description': descCtrl.text.trim(),
                'status': season.status,
              });
              if (!mounted) return;
              if (res != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật vụ mùa thành công!')));
                _loadSeasons();
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSeason(FarmingSeasonModel season) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lưu trữ Vụ mùa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn lưu trữ và kết thúc vụ mùa "${season.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deleteFarmingSeason(season.id);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu trữ vụ mùa.')));
                _loadSeasons();
              }
            },
            child: const Text('Lưu trữ'),
          ),
        ],
      ),
    );
  }
}
