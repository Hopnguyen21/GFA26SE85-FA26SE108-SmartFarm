import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';

class FarmerManagementScreen extends StatefulWidget {
  const FarmerManagementScreen({super.key});

  @override
  State<FarmerManagementScreen> createState() => _FarmerManagementScreenState();
}

class _FarmerManagementScreenState extends State<FarmerManagementScreen> {
  String _searchQuery = '';
  String _roleFilter = 'ALL'; // ALL, FARMER, TECH
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final currentFarm = provider.currentFarm;

    // Lọc theo Farm hiện tại của Owner
    final farmFarmers = provider.farmersForCurrentFarm;

    // Lọc tìm kiếm & bộ lọc
    final filteredList = farmFarmers.where((f) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = f.name.toLowerCase().contains(q) ||
            f.phone.toLowerCase().contains(q) ||
            f.email.toLowerCase().contains(q) ||
            f.username.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_roleFilter != 'ALL') {
        if (_roleFilter == 'TECH' && !f.role.contains('Kỹ thuật viên')) return false;
        if (_roleFilter == 'FARMER' && f.role.contains('Kỹ thuật viên')) return false;
      }
      if (_statusFilter == 'ACTIVE' && !f.isActive) return false;
      if (_statusFilter == 'INACTIVE' && f.isActive) return false;
      return true;
    }).toList();

    final activeCount = farmFarmers.where((f) => f.isActive).length;
    final techCount = farmFarmers.where((f) => f.role.contains('Kỹ thuật viên')).length;

    // Phân quyền bảo mật: Chỉ OWNER mới có quyền xem và quản lý danh sách Farmer
    if (provider.currentRole != 'OWNER') {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          title: const Text('Quản Lý Nông Dân & Tài Khoản', style: TextStyle(fontSize: 16)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gpp_bad_outlined, size: 48, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Không có quyền truy cập',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ Chủ trang trại (Farm Owner) mới được phép phân quyền, quản lý tài khoản và danh sách Nông dân thực địa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF062326),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
              'Quản Lý Nông Dân & Phân Quyền',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Trang trại: ${currentFarm.name}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF34D399)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Thêm tài khoản nông dân',
            onPressed: () => _showAddOrEditFarmerModal(context, provider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Thống kê nhanh & Trạng thái Real-time Sync
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF062326),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'ĐỒNG BỘ REAL-TIME (LORA / CLOUD)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF34D399),
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${provider.lastTelemetryReceivedAt.hour.toString().padLeft(2, '0')}:${provider.lastTelemetryReceivedAt.minute.toString().padLeft(2, '0')}:${provider.lastTelemetryReceivedAt.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatBadge('Tổng nhân sự', '${farmFarmers.length}', const Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    _buildStatBadge('Đang hoạt động', '$activeCount', const Color(0xFF34D399)),
                    const SizedBox(width: 8),
                    _buildStatBadge('Kỹ thuật viên', '$techCount', const Color(0xFFFBBF24)),
                  ],
                ),
              ],
            ),
          ),

          // Thanh tìm kiếm và bộ lọc nhanh
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, SĐT, email, tên đăng nhập...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Chips bộ lọc
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả vai trò', _roleFilter == 'ALL', () {
                        setState(() => _roleFilter = 'ALL');
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('Nông dân thực địa', _roleFilter == 'FARMER', () {
                        setState(() => _roleFilter = 'FARMER');
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('Kỹ thuật viên', _roleFilter == 'TECH', () {
                        setState(() => _roleFilter = 'TECH');
                      }),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                      const SizedBox(width: 10),
                      _buildFilterChip('Đang hoạt động', _statusFilter == 'ACTIVE', () {
                        setState(() => _statusFilter = _statusFilter == 'ACTIVE' ? 'ALL' : 'ACTIVE');
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('Đã khóa', _statusFilter == 'INACTIVE', () {
                        setState(() => _statusFilter = _statusFilter == 'INACTIVE' ? 'ALL' : 'INACTIVE');
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Danh sách Farmer Cards
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          farmFarmers.isEmpty
                              ? 'Chưa có nhân viên nào trong nông trại này'
                              : 'Không tìm thấy tài khoản phù hợp',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        if (farmFarmers.isEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _showAddOrEditFarmerModal(context, provider),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Thêm nông dân đầu tiên'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final farmer = filteredList[index];
                      return _buildFarmerCard(context, provider, farmer);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Cấp Tài Khoản Mới', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddOrEditFarmerModal(context, provider),
      ),
    );
  }

  Widget _buildStatBadge(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF047857) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerCard(BuildContext context, FarmProvider provider, FarmerModel farmer) {
    final isTech = farmer.role.contains('Kỹ thuật viên');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: farmer.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Name, Role badge, Status switch
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isTech
                      ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  child: Text(
                    farmer.name.split(' ').last.substring(0, 1),
                    style: TextStyle(
                      color: isTech ? const Color(0xFF0284C7) : const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              farmer.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: farmer.isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: farmer.isActive
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              farmer.isActive ? 'Đang hoạt động' : 'Tạm khóa',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: farmer.isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTech ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          farmer.role,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isTech ? const Color(0xFF0369A1) : const Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Chi tiết liên hệ & Tài khoản đăng nhập
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Icons.phone_outlined, 'Số điện thoại', farmer.phone),
                  const SizedBox(height: 6),
                  _buildDetailRow(Icons.email_outlined, 'Email', farmer.email.isEmpty ? 'Chưa cập nhật' : farmer.email),
                  const SizedBox(height: 6),
                  _buildDetailRow(
                    Icons.account_circle_outlined,
                    'Tên đăng nhập',
                    farmer.username.isEmpty ? 'farmer_${farmer.farmerId}' : farmer.username,
                    isMonospace: true,
                  ),
                  const SizedBox(height: 6),
                  _buildPasswordRow(context, farmer.password),
                ],
              ),
            ),

            // Các khu vực / Zone được phân công phụ trách
            if (farmer.assignedZoneNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.grid_view, size: 14, color: Color(0xFF059669)),
                  const SizedBox(width: 6),
                  const Text('Phụ trách:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: farmer.assignedZoneNames.map((zoneName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Text(
                            zoneName.split(' - ').first,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],

            // Hiển thị danh sách quyền hạn được cấp
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                const Text('Quyền hạn:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(width: 6),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: farmer.permissions.map((perm) {
                      final label = _getPermissionLabel(perm);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            // Hàng công cụ thao tác nhanh: Phân quyền, Đổi MK, Sửa, Khóa/Mở, Xóa
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAssignTaskDialog(context, provider, farmer),
                    icon: const Icon(Icons.add_task, size: 14, color: Color(0xFFD97706)),
                    label: const Text('Giao việc', style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showPermissionsDialog(context, provider, farmer),
                    icon: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFF059669)),
                    label: const Text('Phân quyền', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                  ),
                TextButton.icon(
                  onPressed: () => _showResetPasswordDialog(context, provider, farmer),
                  icon: const Icon(Icons.key, size: 14, color: Color(0xFF0284C7)),
                  label: const Text('Đổi MK', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                ),
                TextButton.icon(
                  onPressed: () => _showAddOrEditFarmerModal(context, provider, farmer: farmer),
                  icon: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF475569)),
                  label: const Text('Sửa', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                ),
                TextButton.icon(
                  onPressed: () {
                    provider.toggleFarmerStatus(farmer.farmerId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(farmer.isActive
                            ? '🔒 Đã tạm khóa tài khoản ${farmer.name}'
                            : '🔓 Đã kích hoạt lại tài khoản ${farmer.name}'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: farmer.isActive ? const Color(0xFFEF4444) : const Color(0xFF059669),
                      ),
                    );
                  },
                  icon: Icon(
                    farmer.isActive ? Icons.lock_outline : Icons.lock_open,
                    size: 14,
                    color: farmer.isActive ? const Color(0xFFE11D48) : const Color(0xFF059669),
                  ),
                  label: Text(
                    farmer.isActive ? 'Khóa' : 'Mở',
                    style: TextStyle(
                      fontSize: 11,
                      color: farmer.isActive ? const Color(0xFFE11D48) : const Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6)),
                ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Xóa tài khoản',
                    onPressed: () => _confirmDeleteFarmer(context, provider, farmer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isMonospace = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
              fontFamily: isMonospace ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRow(BuildContext context, String password) {
    return Row(
      children: [
        const Icon(Icons.password, size: 14, color: Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        const SizedBox(
          width: 90,
          child: Text('Mật khẩu mẫu', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(
            '••••••••',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: password));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📋 Đã sao chép mật khẩu: $password'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy, size: 10, color: Color(0xFF475569)),
                SizedBox(width: 3),
                Text('Copy MK', style: TextStyle(fontSize: 9.5, color: Color(0xFF475569), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showResetPasswordDialog(BuildContext context, FarmProvider provider, FarmerModel farmer) {
    final passController = TextEditingController(text: '${farmer.name.split(' ').last}@2026');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.key, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Text('Đổi MK: ${farmer.name}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập mật khẩu mới cho tài khoản nông dân:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passController,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (passController.text.trim().isNotEmpty) {
                provider.resetFarmerPassword(farmer.farmerId, passController.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔑 Đã cập nhật mật khẩu mới cho ${farmer.name}!'),
                    backgroundColor: const Color(0xFF0284C7),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }

  String _getPermissionLabel(String perm) {
    switch (perm) {
      case 'CAN_CONTROL_PUMP':
        return '⚡ Điều khiển Bơm/Quạt';
      case 'CAN_LOG_DIARY':
        return '📝 Ghi nhật ký canh tác';
      case 'CAN_VIEW_REPORTS':
        return '📊 Xem báo cáo VietGAP';
      case 'CAN_CONFIG_SCHEDULE':
        return '⏰ Cài lịch tự động';
      case 'CAN_MANAGE_HARDWARE':
        return '🔧 Cấu hình phần cứng IoT';
      default:
        return perm;
    }
  }

  void _showPermissionsDialog(BuildContext context, FarmProvider provider, FarmerModel farmer) {
    final availablePermissions = [
      {
        'key': 'CAN_CONTROL_PUMP',
        'title': 'Điều khiển Bơm & Quạt Thực Địa',
        'desc': 'Cho phép bật/tắt van tưới, máy bơm, quạt đối lưu trong Zone phụ trách',
        'icon': Icons.power_settings_new,
      },
      {
        'key': 'CAN_LOG_DIARY',
        'title': 'Ghi Nhật Ký Canh Tác VietGAP',
        'desc': 'Cho phép chấm công việc, ghi chép bón phân, tưới nước, thu hoạch',
        'icon': Icons.menu_book,
      },
      {
        'key': 'CAN_VIEW_REPORTS',
        'title': 'Xem Báo Cáo & Số Liệu Cảm Biến',
        'desc': 'Cho phép xem biểu đồ nhiệt độ, độ ẩm đất và xuất dữ liệu báo cáo',
        'icon': Icons.bar_chart,
      },
      {
        'key': 'CAN_CONFIG_SCHEDULE',
        'title': 'Cấu Hình Lịch Tưới & AutoRule',
        'desc': 'Cho phép tạo và kích hoạt quy tắc tưới tự động theo ngưỡng cảm biến',
        'icon': Icons.timer_outlined,
      },
      {
        'key': 'CAN_MANAGE_HARDWARE',
        'title': 'Cấu Hình Gateway & Node Cảm Biến',
        'desc': 'Quyền dành cho Kỹ thuật viên để cấu hình chu kỳ gửi LoRa, gán node',
        'icon': Icons.settings_input_antenna,
      },
    ];

    List<String> tempPermissions = List.from(farmer.permissions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân Quyền Farmer',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        farmer.name,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: Color(0xFF64748B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chỉ Chủ trang trại (Owner) mới có quyền cấp hoặc tước quyền các chức năng này đối với Farmer.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...availablePermissions.map((perm) {
                      final key = perm['key'] as String;
                      final isGranted = tempPermissions.contains(key);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isGranted ? const Color(0xFFF0FDF4) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isGranted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isGranted,
                          activeColor: const Color(0xFF059669),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          secondary: Icon(
                            perm['icon'] as IconData,
                            size: 20,
                            color: isGranted ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                          ),
                          title: Text(
                            perm['title'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isGranted ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Text(
                            perm['desc'] as String,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                if (!tempPermissions.contains(key)) tempPermissions.add(key);
                              } else {
                                tempPermissions.remove(key);
                              }
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Lưu Phân Quyền', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  provider.updateFarmer(
                    farmer.copyWith(permissions: tempPermissions),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🛡️ Đã cập nhật ${tempPermissions.length} quyền cho ${farmer.name}!'),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteFarmer(BuildContext context, FarmProvider provider, FarmerModel farmer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Xác nhận xóa tài khoản', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài khoản "${farmer.name}" khỏi hệ thống nông trại?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              provider.deleteFarmer(farmer.farmerId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ Đã xóa tài khoản ${farmer.name} thành công'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditFarmerModal(BuildContext context, FarmProvider provider, {FarmerModel? farmer}) {
    final isEditing = farmer != null;
    final nameCtrl = TextEditingController(text: farmer?.name ?? '');
    final phoneCtrl = TextEditingController(text: farmer?.phone ?? '');
    final emailCtrl = TextEditingController(text: farmer?.email ?? '');
    final usernameCtrl = TextEditingController(text: farmer?.username ?? '');
    final passCtrl = TextEditingController(text: farmer?.password ?? 'Farmer@12345');

    String selectedRole = farmer?.role ?? 'Nông dân Thực địa (CF2)';
    final roles = [
      'Nông dân Thực địa (CF2)',
      'Kỹ thuật viên IoT (CF1)',
      'Kỹ thuật viên Thổ nhưỡng',
      'Giám sát Nông trại',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        isEditing ? Icons.edit_note : Icons.person_add_alt_1,
                        color: const Color(0xFF10B981),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Chỉnh Sửa Hồ Sơ Farmer' : 'Cấp Tài Khoản Farmer Mới',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Trực thuộc: ${provider.currentFarm.name}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // Họ và tên
                  const Text('Họ và tên *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      hintText: 'VD: Nguyễn Văn Toàn',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vai trò
                  const Text('Vai trò công việc *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedRole,
                        items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedRole = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Số điện thoại & Email
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số điện thoại *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '0912 xxx xxx',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                            const Text('Email', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'email@agri.vn',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tài khoản đăng nhập
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tên đăng nhập *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: usernameCtrl,
                              decoration: InputDecoration(
                                hintText: 'farmer_username',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                            const Text('Mật khẩu *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: passCtrl,
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nút bấm
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Huỷ'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            final phone = phoneCtrl.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Vui lòng điền đủ Tên và Số điện thoại!'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                              return;
                            }

                            final email = emailCtrl.text.trim();
                            final username = usernameCtrl.text.trim().isEmpty
                                ? 'farmer_${phone.replaceAll(' ', '')}'
                                : usernameCtrl.text.trim();
                            final password = passCtrl.text.trim().isEmpty ? 'Farmer@12345' : passCtrl.text.trim();

                            if (isEditing) {
                              provider.updateFarmer(
                                farmer.copyWith(
                                  name: name,
                                  role: selectedRole,
                                  phone: phone,
                                  email: email,
                                  username: username,
                                  password: password,
                                ),
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🎉 Đã cập nhật hồ sơ cho $name!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            } else {
                              provider.addFarmer(
                                name: name,
                                role: selectedRole,
                                phone: phone,
                                email: email,
                                username: username,
                                password: password,
                              );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🎉 Đã tạo thành công tài khoản cho $name!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                          child: Text(isEditing ? 'Lưu Thay Đổi' : 'Tạo Tài Khoản Farmer', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAssignTaskDialog(BuildContext context, FarmProvider provider, FarmerModel farmer) {
    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có khu vực (Zone) nào để giao việc.')),
      );
      return;
    }

    String selectedZoneId = provider.zones.first.zoneId;
    if (farmer.assignedZoneNames.isNotEmpty) {
      final match = provider.zones.cast<ZoneModel?>().firstWhere(
        (z) => z != null && farmer.assignedZoneNames.any((name) => z.name.contains(name.split(' - ').first)),
        orElse: () => null,
      );
      if (match != null) selectedZoneId = match.zoneId;
    }

    final titleCtrl = TextEditingController(text: 'Tỉa cành & bấm ngọn chồi nách VietGAP');
    final descCtrl = TextEditingController(text: 'Kiểm tra hàng số 2 và 3, tỉa bớt lá già vàng và chồi nách không đạt.');
    String priority = 'HIGH';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    final quickPresets = [
      'Tưới nhỏ giọt & kiểm tra độ ẩm đất',
      'Tỉa cành & bấm ngọn chồi nách',
      'Châm dung dịch dinh dưỡng NPK',
      'Phun chế phẩm sinh học trừ sâu',
      'Thu hoạch và phân loại VietGAP',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final targetZone = provider.zones.firstWhere((z) => z.zoneId == selectedZoneId, orElse: () => provider.zones.first);

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add_task, color: Color(0xFFD97706), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Giao Việc Cho ${farmer.name}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Vai trò: ${farmer.role}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chọn Zone
                  const Text('Chọn Nhà màng / Khu vực thực hiện: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedZoneId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: provider.zones.map((z) => DropdownMenuItem(value: z.zoneId, child: Text('${z.name} (${z.currentCrop})', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedZoneId = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Gợi ý công việc nhanh
                  const Text('Mẫu công việc phổ biến:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: quickPresets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                titleCtrl.text = preset;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(preset, style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155))),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tiêu đề công việc
                  const Text('Tiêu đề công việc: *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ví dụ: Tỉa lá già, kiểm tra sâu bệnh...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mức ưu tiên
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Mức độ ưu tiên:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'LOW', child: Text('🟢 Bình thường', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'MEDIUM', child: Text('🟡 Trung bình', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'HIGH', child: Text('🔴 Khẩn cấp', style: TextStyle(fontSize: 12))),
                              ],
                              onChanged: (v) {
                                if (v != null) setModalState(() => priority = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Hạn hoàn thành:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: dueDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 90)),
                                );
                                if (picked != null) setModalState(() => dueDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontSize: 12)),
                                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Yêu cầu chi tiết
                  const Text('Yêu cầu chi tiết / Ghi chú:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Mô tả vị trí luống cây, lưu ý kỹ thuật...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Xác Nhận Giao Việc', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vui lòng nhập tiêu đề công việc!')),
                              );
                              return;
                            }
                            final dueStr = 'Ngày ${dueDate.day}/${dueDate.month}, 17:00';
                            provider.addTask(
                              title: titleCtrl.text.trim(),
                              zoneName: targetZone.name.split(' - ').first,
                              priority: priority,
                              dueDate: dueStr,
                              assignedFarmerId: farmer.farmerId,
                              assignedFarmerName: farmer.name,
                              description: descCtrl.text.trim(),
                              zoneId: selectedZoneId,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📋 Đã giao việc thành công cho ${farmer.name}!'),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
