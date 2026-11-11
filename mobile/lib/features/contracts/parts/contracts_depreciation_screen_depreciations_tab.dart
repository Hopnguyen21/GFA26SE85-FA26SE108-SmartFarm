part of '../contracts_depreciation_screen.dart';

extension _ContractsDepreciationScreenStateDepreciationsTab on _ContractsDepreciationScreenState {
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
                    Text(
                      'TỔNG QUAN TÀI SẢN & KHẤU HAO THIẾT BỊ',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
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
                        Text(
                          currencyFormat.format(totalOriginalCost),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Đã trích khấu hao', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(totalAccumulated),
                          style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Giá trị còn lại', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                        const SizedBox(height: 2),
                        Text(
                          currencyFormat.format(totalCurrentBookValue),
                          style: const TextStyle(color: Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.bold),
                        ),
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
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
                          const Text(
                            '• ',
                            style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                          ),
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
                          const Text(
                            '• ',
                            style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                          ),
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
                        const Text(
                          '• ',
                          style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold),
                        ),
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
                  _rebuild(() => _depreciationStatusFilter = 'ALL');
                }),
                const SizedBox(width: 8),
                _buildFilterChip('Cần chú ý ($totalAlerts)', _depreciationStatusFilter == 'ALERTS', () {
                  _rebuild(() => _depreciationStatusFilter = 'ALERTS');
                }),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Đang trích (${_depreciations.where((d) => d.remainingMonths > 3).length})',
                  _depreciationStatusFilter == 'ACTIVE',
                  () {
                    _rebuild(() => _depreciationStatusFilter = 'ACTIVE');
                  },
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Đã trích hết (${alertFullyDepreciated.length})',
                  _depreciationStatusFilter == 'COMPLETED',
                  () {
                    _rebuild(() => _depreciationStatusFilter = 'COMPLETED');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HỒ SƠ KHẤU HAO THIẾT BỊ (${filtered.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
              ),
              Text(
                '${_depreciations.where((d) => d.remainingMonths > 0).length} đang trích',
                style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold),
              ),
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
                      Text(
                        d.deviceName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${d.zoneName} • MAC: ${d.hardwareAddress}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
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
              Text(
                'Đã khấu hao: ${d.monthsElapsed} / ${d.depreciationLifetimeMonths} tháng',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
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
                  const Text('Nguyên giá', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text(
                    currencyFormat.format(d.originalCostVnd),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Khấu hao / tháng', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text(
                    currencyFormat.format(d.monthlyDepreciationVnd),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Giá trị còn lại', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text(
                    currencyFormat.format(d.currentBookValueVnd),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ],
          ),

          if (d.isNearContractRenewal) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Gần thời điểm gia hạn hợp đồng Zone. Cần đánh giá hao mòn.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
