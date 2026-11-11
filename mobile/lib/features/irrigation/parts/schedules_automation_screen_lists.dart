part of '../schedules_automation_screen.dart';

extension _SchedulesAutomationScreenStateLists on _SchedulesAutomationScreenState {
  Widget _buildAutoRulesTab(BuildContext context, FarmProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Issue 2 Explanation Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tự Động Hóa Thực Sự (Closed-Loop Automation)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF062326), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Các AutoRule bên dưới chạy 100% tự động trên Cloud/Edge ngay khi cảm biến vi phạm ngưỡng, KHÔNG cần con người nhấn xác nhận. Chỉ có khuyến nghị AI phức tạp mới yêu cầu duyệt.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey[700], height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...provider.automationRules.map((rule) => _buildRuleCard(context, provider, rule)),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildRuleCard(BuildContext context, FarmProvider provider, AutomationRuleModel rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rule.isActive ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
          width: rule.isActive ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ),
              Switch(
                value: rule.isActive,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                onChanged: (val) async {
                  if (!_canConfigSchedule(provider)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Bạn chưa được cấp quyền cấu hình tự động hóa (CAN_CONFIG_SCHEDULE)!'),
                        backgroundColor: Color(0xFFE11D48),
                      ),
                    );
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  final error = await provider.toggleAutomationRule(rule.ruleId);
                  if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
                },
              ),
            ],
          ),
          Text(
            rule.zoneName,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF062326), borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'IF (NẾU)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${rule.parameterCode} ${rule.operator} ${rule.thresholdValue}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'THEN (THÌ)',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${rule.actionType} ${rule.actuatorName}${rule.actionDurationMinutes > 0 ? " trong ${rule.actionDurationMinutes} phút" : ""}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF064E3B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      rule.isActive ? Icons.check_circle : Icons.pause_circle_outline,
                      size: 14,
                      color: rule.isActive ? const Color(0xFF10B981) : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        rule.isActive ? 'Đang chạy tự động' : 'Tạm dừng',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rule.isActive ? const Color(0xFF10B981) : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('AutoRule • Cloud Engine', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesTab(BuildContext context, FarmProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...provider.schedules.map((sch) => _buildScheduleCard(context, provider, sch)),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildScheduleCard(BuildContext context, FarmProvider provider, ScheduleModel sch) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: sch.isActive ? const Color(0xFF062326).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sch.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                ),
              ),
              Switch(
                value: sch.isActive,
                activeThumbColor: const Color(0xFF10B981),
                activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.3),
                onChanged: (val) async {
                  if (!_canConfigSchedule(provider)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Bạn chưa được cấp quyền cấu hình lịch tưới (CAN_CONFIG_SCHEDULE)!'),
                        backgroundColor: Color(0xFFE11D48),
                      ),
                    );
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await provider.toggleScheduleEnabled(sch.scheduleId, val);
                  if (!ok) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Không cập nhật được lịch tưới. Kiểm tra kết nối và quyền rồi thử lại.'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          Text('${sch.zoneName} • ${sch.actuatorName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF062326).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Color(0xFF062326)),
                    const SizedBox(width: 6),
                    Text(
                      '${sch.startTime} (${sch.durationMinutes} phút)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF062326)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.repeat, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        sch.daysOfWeek.join(', '),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF064E3B)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
