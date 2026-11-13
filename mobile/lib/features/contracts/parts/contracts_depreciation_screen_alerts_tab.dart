part of '../contracts_depreciation_screen.dart';

extension _ContractsDepreciationScreenStateAlertsTab
    on _ContractsDepreciationScreenState {
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
                const Icon(
                  Icons.notification_important,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CẢNH BÁO HẾT HẠN THUÊ VÙNG TRỒNG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Color(0xFF991B1B),
                        ),
                      ),
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
            _buildEmptyState(
              'Hiện tại không có hợp đồng nào sắp hết hạn trong 30 ngày tới.',
              Icons.check_circle_outline,
            )
          else
            ..._expiringAlerts.map(
              (alert) => Container(
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${alert.contractNumber} • ${alert.zoneName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hết hạn vào: ${alert.endDate} (${alert.farmName})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Giá trị hợp đồng: ${currencyFormat.format(alert.totalContractValueVnd)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xem chi tiết',
                      icon: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        final match = _contracts
                            .where((c) => c.id == alert.contractId)
                            .firstOrNull;
                        if (match != null) {
                          _showContractDetailsModal(match);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
