import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/farm_provider.dart';
import '../services/api_service.dart';

class ContractsDepreciationScreen extends StatefulWidget {
  final String? initialZoneId;
  final String? initialFarmId;
  final int initialTabIndex;

  const ContractsDepreciationScreen({
    super.key,
    this.initialZoneId,
    this.initialFarmId,
    this.initialTabIndex = 0,
  });

  @override
  State<ContractsDepreciationScreen> createState() => _ContractsDepreciationScreenState();
}

class _ContractsDepreciationScreenState extends State<ContractsDepreciationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _isLoading = false;
  List<ZoneContractModel> _contracts = [];
  List<DeviceDepreciationModel> _depreciations = [];
  List<ExpiringContractAlertModel> _expiringAlerts = [];

  String? _selectedFarmId;
  String? _selectedZoneId;
  String _contractStatusFilter = 'ALL';
  String _depreciationStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _selectedFarmId = widget.initialFarmId;
    _selectedZoneId = widget.initialZoneId;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final contracts = await ApiService.getZoneContracts(
        farmId: _selectedFarmId,
        zoneId: _selectedZoneId,
      );
      final depreciations = await ApiService.getDeviceDepreciations(
        farmId: _selectedFarmId,
        zoneId: _selectedZoneId,
      );
      final alerts = await ApiService.getExpiringContracts(
        farmId: _selectedFarmId,
        daysThreshold: 30,
      );

      if (mounted) {
        setState(() {
          _contracts = contracts;
          _depreciations = depreciations;
          _expiringAlerts = alerts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────
  // UI Build
  // ─────────────────────────────────────────
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
            Text('Hợp Đồng Thuê & Khấu Hao',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Zone Contracts & Device Depreciation',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.assignment_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('Hợp Đồng (${_contracts.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_down, size: 16),
                  const SizedBox(width: 6),
                  Text('Khấu Hao (${_depreciations.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: _expiringAlerts.isNotEmpty,
                    label: Text('${_expiringAlerts.length}'),
                    backgroundColor: const Color(0xFFEF4444),
                    child: const Icon(Icons.alarm, size: 16),
                  ),
                  const SizedBox(width: 6),
                  const Text('Sắp Hết Hạn'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildContractsTab(provider, isOwner),
                _buildDepreciationsTab(provider, isOwner),
                _buildExpiringAlertsTab(provider),
              ],
            ),
      floatingActionButton: _buildFloatingActionButton(provider, isOwner),
    );
  }

  Widget? _buildFloatingActionButton(FarmProvider provider, bool isOwner) {
    final currentTab = _tabController.index;
    final isTech = provider.currentRole == 'TECHNICIAN';
    if (currentTab == 0 && isOwner) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
        label: const Text('Tạo Hợp Đồng Thuê', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateContractDialog(provider),
      );
    } else if (currentTab == 1 && (isOwner || isTech)) {
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.post_add, color: Color(0xFF10B981)),
        label: const Text('Thêm Hồ Sơ Khấu Hao', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateDepreciationDialog(provider),
      );
    }
    return null;
  }

  // ─────────────────────────────────────────
  // TAB 1: Danh sách Hợp đồng thuê Zone
  // ─────────────────────────────────────────
  Widget _buildContractsTab(FarmProvider provider, bool isOwner) {
    final filtered = _contracts.where((c) {
      if (_contractStatusFilter == 'ACTIVE') return c.isActive;
      if (_contractStatusFilter == 'EXPIRING') return c.isExpiringSoon;
      if (_contractStatusFilter == 'RENEWED') return c.status == 'Renewed';
      return true;
    }).toList();

    final totalMonthlyRent = _contracts
        .where((c) => c.isActive)
        .fold<double>(0, (sum, item) => sum + item.monthlyRentVnd);
    final totalDeposit = _contracts
        .where((c) => c.isActive)
        .fold<double>(0, (sum, item) => sum + item.depositVnd);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Metrics Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Doanh Thu Thuê/Tháng',
                  value: currencyFormat.format(totalMonthlyRent),
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF059669),
                  subText: '${_contracts.where((c) => c.isActive).length} hợp đồng hoạt động',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricCard(
                  title: 'Tổng Tiền Cọc Giữ',
                  value: currencyFormat.format(totalDeposit),
                  icon: Icons.savings_outlined,
                  iconColor: const Color(0xFF0284C7),
                  subText: 'Bảo chứng hợp đồng',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả (${_contracts.length})', _contractStatusFilter == 'ALL', () {
                  setState(() => _contractStatusFilter = 'ALL');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Đang hiệu lực (${_contracts.where((c) => c.isActive).length})',
                    _contractStatusFilter == 'ACTIVE', () {
                  setState(() => _contractStatusFilter = 'ACTIVE');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Sắp hết hạn (${_contracts.where((c) => c.isExpiringSoon).length})',
                    _contractStatusFilter == 'EXPIRING', () {
                  setState(() => _contractStatusFilter = 'EXPIRING');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Đã gia hạn (${_contracts.where((c) => c.status == 'Renewed').length})',
                    _contractStatusFilter == 'RENEWED', () {
                  setState(() => _contractStatusFilter = 'RENEWED');
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            _buildEmptyState('Không tìm thấy hợp đồng nào phù hợp bộ lọc.', Icons.assignment_late_outlined)
          else
            ...filtered.map((contract) => _buildContractCard(contract, isOwner)),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildContractCard(ZoneContractModel contract, bool isOwner) {
    Color statusBg = const Color(0xFFECFDF5);
    Color statusColor = const Color(0xFF059669);
    if (!contract.isActive) {
      statusBg = const Color(0xFFF1F5F9);
      statusColor = const Color(0xFF64748B);
    } else if (contract.isExpiringSoon) {
      statusBg = const Color(0xFFFEF3C7);
      statusColor = const Color(0xFFD97706);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: contract.isExpiringSoon ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: contract.isExpiringSoon ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _showContractDetailsModal(contract),
          borderRadius: BorderRadius.circular(14),
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
                            contract.contractNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          contract.zoneName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        contract.statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lessee info
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      'Bên thuê: ${contract.lesseeName}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    if (contract.lesseePhone != null && contract.lesseePhone!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('(${contract.lesseePhone})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Financial & dates row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Giá thuê / tháng',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(
                          currencyFormat.format(contract.monthlyRentVnd),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tiền đặt cọc',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(
                          currencyFormat.format(contract.depositVnd),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Thời hạn hợp đồng',
                            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        Text(
                          '${contract.startDate} ➔ ${contract.endDate}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),

                if (contract.isActive) ...[
                  const Divider(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            contract.isExpiringSoon ? Icons.warning_amber_rounded : Icons.schedule,
                            size: 14,
                            color: contract.isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            contract.daysRemaining > 0
                                ? 'Còn ${contract.daysRemaining} ngày'
                                : 'Đã đến hạn hợp đồng',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: contract.isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (isOwner)
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showRenewContractDialog(contract),
                              icon: const Icon(Icons.autorenew, size: 14, color: Color(0xFF059669)),
                              label: const Text('Gia hạn', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF059669)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAB 2: Theo dõi Khấu hao thiết bị
  // ─────────────────────────────────────────
  Widget _buildDepreciationsTab(FarmProvider provider, bool isOwner) {
    final totalOriginalCost = _depreciations.fold<double>(0, (sum, d) => sum + d.originalCostVnd);
    final totalAccumulated = _depreciations.fold<double>(0, (sum, d) => sum + d.accumulatedDepreciationVnd);
    final totalCurrentBookValue = _depreciations.fold<double>(0, (sum, d) => sum + d.currentBookValueVnd);

    final alertNearRenewal = _depreciations.where((d) => d.isNearContractRenewal).toList();
    final alertExpiringSoon = _depreciations.where((d) => d.remainingMonths > 0 && d.remainingMonths <= 3).toList();
    final alertFullyDepreciated = _depreciations.where((d) => d.remainingMonths <= 0).toList();
    final totalAlerts = alertNearRenewal.length + alertExpiringSoon.length + alertFullyDepreciated.length;

    final filtered = _depreciations.where((d) {
      if (_depreciationStatusFilter == 'ALERTS') {
        return d.isNearContractRenewal || d.remainingMonths <= 3;
      }
      if (_depreciationStatusFilter == 'ACTIVE') {
        return d.remainingMonths > 3;
      }
      if (_depreciationStatusFilter == 'COMPLETED') {
        return d.remainingMonths <= 0;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Depreciation Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062326), Color(0xFF0D474A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text('TỔNG QUAN TÀI SẢN & KHẤU HAO THIẾT BỊ',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nguyên giá đầu tư', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(currencyFormat.format(totalOriginalCost),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Đã trích khấu hao', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(currencyFormat.format(totalAccumulated),
                            style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Giá trị còn lại', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(currencyFormat.format(totalCurrentBookValue),
                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ⚠️ Cảnh báo Khấu hao nổi bật (Depreciation Alerts Banner)
          if (totalAlerts > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCD34D)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'CẢNH BÁO KHẤU HAO & HAO MÒN ($totalAlerts THIẾT BỊ)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (alertNearRenewal.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              '${alertNearRenewal.length} thiết bị thuộc Zone sắp gia hạn hợp đồng (≤ 45 ngày). Cần đánh giá độ hao mòn để bảo trì hoặc thay mới.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (alertExpiringSoon.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              '${alertExpiringSoon.length} thiết bị sắp hết thời gian trích khấu hao (còn ≤ 3 tháng).',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (alertFullyDepreciated.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            '${alertFullyDepreciated.length} thiết bị đã trích khấu hao 100% (Giá trị sổ sách = 0₫).',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tất cả (${_depreciations.length})', _depreciationStatusFilter == 'ALL', () {
                  setState(() => _depreciationStatusFilter = 'ALL');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Cần chú ý ($totalAlerts)', _depreciationStatusFilter == 'ALERTS', () {
                  setState(() => _depreciationStatusFilter = 'ALERTS');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Đang trích (${_depreciations.where((d) => d.remainingMonths > 3).length})',
                    _depreciationStatusFilter == 'ACTIVE', () {
                  setState(() => _depreciationStatusFilter = 'ACTIVE');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Đã trích hết (${alertFullyDepreciated.length})',
                    _depreciationStatusFilter == 'COMPLETED', () {
                  setState(() => _depreciationStatusFilter = 'COMPLETED');
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HỒ SƠ KHẤU HAO THIẾT BỊ (${filtered.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              Text('${_depreciations.where((d) => d.remainingMonths > 0).length} đang trích',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),

          if (filtered.isEmpty)
            _buildEmptyState('Không tìm thấy thiết bị nào theo bộ lọc.', Icons.memory_outlined)
          else
            ...filtered.map((depreciation) => _buildDepreciationCard(depreciation)),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildDepreciationCard(DeviceDepreciationModel d) {
    final progress = d.progressPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.memory, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.deviceName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('${d.zoneName} • MAC: ${d.hardwareAddress}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: d.remainingMonths > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  d.remainingMonths > 0 ? 'Còn ${d.remainingMonths} tháng' : 'Đã trích hết',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: d.remainingMonths > 0 ? const Color(0xFF059669) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Đã khấu hao: ${d.monthsElapsed} / ${d.depreciationLifetimeMonths} tháng',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text('${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              color: progress > 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 12),

          // Financial numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nguyên giá', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text(currencyFormat.format(d.originalCostVnd),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Khấu hao / tháng', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text(currencyFormat.format(d.monthlyDepreciationVnd),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Giá trị còn lại', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  Text(currencyFormat.format(d.currentBookValueVnd),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ],
          ),

          if (d.isNearContractRenewal) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text('Gần thời điểm gia hạn hợp đồng Zone. Cần đánh giá hao mòn.',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF92400E))),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // TAB 3: Cảnh báo Hết hạn (<30 ngày)
  // ─────────────────────────────────────────
  Widget _buildExpiringAlertsTab(FarmProvider provider) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notification_important, color: Color(0xFFDC2626), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CẢNH BÁO HẾT HẠN THUÊ VÙNG TRỒNG',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF991B1B))),
                      const SizedBox(height: 2),
                      Text(
                        'Các hợp đồng còn dưới 30 ngày cần liên hệ khách hàng để tiến hành gia hạn hoặc chuẩn bị bàn giao.',
                        style: TextStyle(fontSize: 11, color: Colors.red[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_expiringAlerts.isEmpty)
            _buildEmptyState('Hiện tại không có hợp đồng nào sắp hết hạn trong 30 ngày tới.', Icons.check_circle_outline)
          else
            ..._expiringAlerts.map((alert) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${alert.daysRemaining}d',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${alert.contractNumber} • ${alert.zoneName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('Hết hạn vào: ${alert.endDate} (${alert.farmName})',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            const SizedBox(height: 2),
                            Text('Giá trị hợp đồng: ${currencyFormat.format(alert.totalContractValueVnd)}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          final match = _contracts.where((c) => c.id == alert.contractId).firstOrNull;
                          if (match != null) {
                            _showContractDetailsModal(match);
                          }
                        },
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Modals & Dialogs
  // ─────────────────────────────────────────

  void _showContractDetailsModal(ZoneContractModel contract) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.contractNumber,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF062326))),
                    Text('${contract.farmName} ➔ ${contract.zoneName}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: contract.isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    contract.statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: contract.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            const Text('THÔNG TIN BÊN THUÊ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            _buildDetailRow('Họ và tên', contract.lesseeName),
            _buildDetailRow('Số điện thoại', contract.lesseePhone ?? 'Chưa cập nhật'),
            _buildDetailRow('Số CCCD/CMND', contract.lesseeIdentityNumber ?? 'Chưa cập nhật'),
            _buildDetailRow('Địa chỉ thường trú', contract.lesseeAddress ?? 'Chưa cập nhật'),

            const Divider(height: 24),
            const Text('ĐIỀU KHOẢN TÀI CHÍNH & THỜI HẠN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            _buildDetailRow('Giá thuê hàng tháng', currencyFormat.format(contract.monthlyRentVnd)),
            _buildDetailRow('Tiền cọc bảo chứng', currencyFormat.format(contract.depositVnd)),
            _buildDetailRow('Tổng giá trị hợp đồng', currencyFormat.format(contract.totalContractValueVnd)),
            _buildDetailRow('Ngày bắt đầu', contract.startDate),
            _buildDetailRow('Ngày kết thúc', contract.endDate),
            _buildDetailRow('Số ngày còn lại', '${contract.daysRemaining} ngày'),

            if (contract.cropType != null && contract.cropType!.isNotEmpty)
              _buildDetailRow('Cây trồng dự kiến', contract.cropType!),

            if (contract.specialTerms != null && contract.specialTerms!.isNotEmpty) ...[
              const Divider(height: 24),
              const Text('ĐIỀU KHOẢN ĐẶC BIỆT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Text(contract.specialTerms!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ],

            if (contract.renewals.isNotEmpty) ...[
              const Divider(height: 24),
              Text('LỊCH SỬ GIA HẠN (${contract.renewals.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              ...contract.renewals.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Gia hạn đến: ${r.newEndDate}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(currencyFormat.format(r.renewalValueVnd),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  void _showRenewContractDialog(ZoneContractModel contract) {
    String preset = '6_MONTHS';
    final rentController = TextEditingController(text: contract.monthlyRentVnd.toStringAsFixed(0));
    final discountController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          title: Text('Gia hạn HĐ ${contract.contractNumber}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn thời gian gia hạn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: preset,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: '6_MONTHS', child: Text('6 Tháng (Chuẩn vụ)')),
                    DropdownMenuItem(value: '1_YEAR', child: Text('1 Năm (12 tháng)')),
                    DropdownMenuItem(value: '3_YEARS', child: Text('3 Năm (Dài hạn)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => preset = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('Giá thuê mới / tháng (VNĐ):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: rentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Giá thuê mới'),
                ),
                const SizedBox(height: 12),
                const Text('Chiết khấu khách hàng thân thiết (%):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0 - 20%'),
                ),
                const SizedBox(height: 12),
                const Text('Ghi chú gia hạn:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Thỏa thuận thêm...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF062326), foregroundColor: Colors.white),
              onPressed: () async {
                final rent = double.tryParse(rentController.text) ?? contract.monthlyRentVnd;
                final discount = double.tryParse(discountController.text) ?? 0.0;
                Navigator.pop(ctx);
                final res = await ApiService.renewZoneContract(contract.id, {
                  'durationPreset': preset,
                  'newMonthlyRentVnd': rent,
                  'discountPercent': discount,
                  'notes': notesController.text.trim(),
                });
                if (!mounted) return;
                if (res != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gia hạn hợp đồng thành công!')));
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi gia hạn hợp đồng.')));
                }
              },
              child: const Text('Xác nhận gia hạn'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateContractDialog(FarmProvider provider) {
    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có Zone nào để tạo hợp đồng.')));
      return;
    }

    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trang trại chưa có Zone.')));
      return;
    }
    String selectedZoneId = provider.zones.first.zoneId;
    final lesseeNameCtrl = TextEditingController();
    final lesseePhoneCtrl = TextEditingController();
    final lesseeCccdCtrl = TextEditingController();
    final monthlyRentCtrl = TextEditingController(text: '3500000');
    final depositCtrl = TextEditingController(text: '7000000');
    final cropTypeCtrl = TextEditingController(text: 'Cà chua Beef thủy canh');
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 180));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          title: const Text('Tạo Hợp Đồng Thuê Zone', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chọn Zone thuê:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedZoneId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  items: provider.zones.map((z) => DropdownMenuItem(value: z.zoneId, child: Text(z.name, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedZoneId = val);
                  },
                ),
                const SizedBox(height: 10),
                const Text('Tên Bên Thuê (Khách hàng):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: lesseeNameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nguyễn Văn A')),
                const SizedBox(height: 10),
                const Text('Số điện thoại:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: lesseePhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0901234567')),
                const SizedBox(height: 10),
                const Text('Số CCCD/CMND:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: lesseeCccdCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '049...')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Giá thuê/tháng:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(controller: monthlyRentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tiền cọc:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextField(controller: depositCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder())),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Cây trồng dự kiến:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(controller: cropTypeCtrl, decoration: const InputDecoration(border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF062326), foregroundColor: Colors.white),
              onPressed: () async {
                if (lesseeNameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên bên thuê.')));
                  return;
                }
                final rent = double.tryParse(monthlyRentCtrl.text) ?? 3000000;
                final deposit = double.tryParse(depositCtrl.text) ?? 6000000;
                Navigator.pop(ctx);

                final res = await ApiService.createZoneContract(selectedZoneId, {
                  'farmId': provider.currentFarm.farmId,
                  'monthlyRentVnd': rent,
                  'depositVnd': deposit,
                  'totalContractValueVnd': rent * 6,
                  'startDate': DateFormat('yyyy-MM-dd').format(startDate),
                  'endDate': DateFormat('yyyy-MM-dd').format(endDate),
                  'lesseeName': lesseeNameCtrl.text.trim(),
                  'lesseePhone': lesseePhoneCtrl.text.trim(),
                  'lesseeIdentityNumber': lesseeCccdCtrl.text.trim(),
                  'cropType': cropTypeCtrl.text.trim(),
                });

                if (!mounted) return;
                if (res != null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tạo hợp đồng thuê thành công!')));
                  _loadData();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi khi tạo hợp đồng.')));
                }
              },
              child: const Text('Lưu Hợp Đồng'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDepreciationDialog(FarmProvider provider) {
    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa có Zone nào để trích khấu hao.')));
      return;
    }

    if (provider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trang trại chưa có Zone.')));
      return;
    }
    String selectedZoneId = provider.zones.first.zoneId;
    final costCtrl = TextEditingController(text: '15000000');
    final lifetimeCtrl = TextEditingController(text: '24');
    final notesCtrl = TextEditingController(text: 'Bộ cảm biến IoT & Gateway ESP32');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm Hồ Sơ Khấu Hao Thiết Bị', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nguyên giá thiết bị (VNĐ):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '15000000')),
              const SizedBox(height: 10),
              const Text('Thời gian trích khấu hao (Tháng):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: lifetimeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '24')),
              const SizedBox(height: 10),
              const Text('Mô tả thiết bị / Ghi chú:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(controller: notesCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF062326), foregroundColor: Colors.white),
            onPressed: () async {
              final cost = double.tryParse(costCtrl.text) ?? 10000000;
              final months = int.tryParse(lifetimeCtrl.text) ?? 24;
              Navigator.pop(ctx);

              final res = await ApiService.createDeviceDepreciation(selectedZoneId, {
                'deviceId': '3fa85f64-5717-4562-b3fc-2c963f66afa6', // generic IoT node
                'originalCostVnd': cost,
                'depreciationLifetimeMonths': months,
                'startDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'notes': notesCtrl.text.trim(),
              });

              if (!mounted) return;
              if (res != null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm hồ sơ khấu hao thành công!')));
                _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thêm hồ sơ khấu hao hoàn tất.')));
                _loadData();
              }
            },
            child: const Text('Lưu Hồ Sơ'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Reusable Widgets
  // ─────────────────────────────────────────
  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subText, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF062326) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF062326) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}
