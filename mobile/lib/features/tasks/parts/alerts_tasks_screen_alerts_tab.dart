part of '../alerts_tasks_screen.dart';

extension _AlertsTasksScreenAlertsTab on AlertsTasksScreen {
  List<Widget> _alertsTab(BuildContext context, FarmProvider farmProvider) {
    return [
      // Alerts Tab
      RefreshIndicator(
        onRefresh: farmProvider.fetchFromApi,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Cảnh Báo Tài Sản & Hợp Đồng (Zone & Khấu Hao)
            if (farmProvider.currentRole == 'OWNER') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFD97706), size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'CẢNH BÁO HỢP ĐỒNG & KHẤU HAO THIẾT BỊ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFB45309),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Hệ thống tự động theo dõi các hợp đồng thuê nhà màng sắp đến kỳ gia hạn (< 30 ngày) và thiết bị IoT chuẩn bị hết hạn trích khấu hao để lập kế hoạch thay thế.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF062326),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF10B981)),
                            label: const Text(
                              'Xem Cảnh Báo Hợp Đồng & Khấu Hao',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ContractsDepreciationScreen(initialTabIndex: 2),
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
            ],
            ...farmProvider.alerts.map((alt) {
              final isCritical = alt.severity == 'CRITICAL';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isCritical ? const Color(0xFFF87171) : const Color(0xFFFBBF24),
                                ),
                              ),
                              child: Text(
                                isCritical ? 'NGUY CẤP' : 'CẢNH BÁO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                            if (alt.isBoundaryViolation) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF60A5FA)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_off, size: 10, color: Color(0xFF2563EB)),
                                    SizedBox(width: 3),
                                    Text(
                                      'RANH GIỚI GIS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(alt.time, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alt.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(alt.message, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (alt.isAcknowledged)
                          const Text(
                            '✓ Đã xác nhận xử lý',
                            style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF062326),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await farmProvider.acknowledgeAlert(alt.alertId);
                              if (!ok) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Không xác nhận được cảnh báo. Kiểm tra kết nối và thử lại.'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Xác nhận đã xem', style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }
}
