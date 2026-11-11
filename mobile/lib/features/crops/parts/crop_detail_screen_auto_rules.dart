part of '../crop_detail_screen.dart';

extension _CropDetailScreenStateAutoRules on _CropDetailScreenState {
  Widget _buildAutoRuleTab(DefaultCropProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explanation
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF062326), Color(0xFF0D4A35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AutoRule Engine (CF3)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Khi áp dụng Profile này, hệ thống tự động tạo các quy tắc dưới đây. Bơm/quạt sẽ hoạt động KHÔNG CẦN xác nhận tay – chỉ gửi notify cho bạn.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Auto Rules for each stage
          ...profile.growthStages.asMap().entries.map((entry) {
            final stage = entry.value;
            final req = stage.requirements;
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
                    children: [
                      Text(stage.iconEmoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        stage.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text(
                        'Ngày ${stage.startDayFromPlanting}–${stage.endDayFromPlanting}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ruleRow(
                    '💧 Tưới tự động',
                    'Độ ẩm đất < ${req.soilMoistureMin.toInt()}%',
                    req.irrigationDurationMin > 0
                        ? '→ Bật bơm ${req.irrigationDurationMin} phút × ${req.irrigationFrequencyPerDay}lần/ngày'
                        : '→ Lịch tưới xem ở mục Lịch tưới của hồ sơ',
                  ),
                  const SizedBox(height: 6),
                  _ruleRow(
                    '🌡️ Ngưỡng nhiệt độ',
                    'Ngoài ${req.tempMin.toInt()}–${req.tempMax.toInt()}°C',
                    '→ Cần xem xét làm mát/sưởi (ứng dụng không tự phát lệnh)',
                  ),
                ],
              ),
            );
          }),

          // Note about Human-in-loop for AI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.psychology, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Advisory (CF4) – Human-in-the-loop',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Các tình huống phức tạp (bệnh lá, thời tiết bất thường, giai đoạn chuyển vụ) → AI đề xuất và BẠN phê duyệt trước khi thực thi. AutoRule xử lý các ngưỡng đơn giản hoàn toàn tự động.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF78350F), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(String title, String condition, String action) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text('NẾU: $condition', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(
            'THÌ: $action',
            style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
