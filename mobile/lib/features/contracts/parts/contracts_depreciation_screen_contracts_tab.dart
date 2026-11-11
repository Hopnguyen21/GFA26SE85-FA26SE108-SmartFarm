part of '../contracts_depreciation_screen.dart';

extension _ContractsDepreciationScreenStateContractsTab on _ContractsDepreciationScreenState {
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
    final totalDeposit = _contracts.where((c) => c.isActive).fold<double>(0, (sum, item) => sum + item.depositVnd);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Phân biệt với cọc/nghiệm thu của yêu cầu dịch vụ kỹ thuật
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Text(
              'Đây là hợp đồng THUÊ ZONE cho bên thuê (tuỳ chọn, lập sau khi Zone đã có). '
              'Không phải tiền đặt cọc 30% / nghiệm thu 70% của báo giá lắp đặt thiết bị — '
              'phần đó nằm ở "Hỗ trợ kỹ thuật & Báo giá" và không phụ thuộc hợp đồng thuê Zone.',
              style: TextStyle(fontSize: 12, color: Color(0xFF0369A1), height: 1.4),
            ),
          ),
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
                  _rebuild(() => _contractStatusFilter = 'ALL');
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Đang hiệu lực (${_contracts.where((c) => c.isActive).length})',
                  _contractStatusFilter == 'ACTIVE',
                  () {
                    _rebuild(() => _contractStatusFilter = 'ACTIVE');
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Sắp hết hạn (${_contracts.where((c) => c.isExpiringSoon).length})',
                  _contractStatusFilter == 'EXPIRING',
                  () {
                    _rebuild(() => _contractStatusFilter = 'EXPIRING');
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Đã gia hạn (${_contracts.where((c) => c.status == 'Renewed').length})',
                  _contractStatusFilter == 'RENEWED',
                  () {
                    _rebuild(() => _contractStatusFilter = 'RENEWED');
                  },
                ),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
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
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          contract.zoneName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        contract.statusText,
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
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
                      Text('(${contract.lesseePhone})', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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
                        const Text('Giá thuê / tháng', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          currencyFormat.format(contract.monthlyRentVnd),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tiền đặt cọc', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        Text(
                          currencyFormat.format(contract.depositVnd),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Thời hạn hợp đồng', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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
                            contract.daysRemaining > 0 ? 'Còn ${contract.daysRemaining} ngày' : 'Đã đến hạn hợp đồng',
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
                              label: const Text(
                                'Gia hạn',
                                style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                              ),
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
}
