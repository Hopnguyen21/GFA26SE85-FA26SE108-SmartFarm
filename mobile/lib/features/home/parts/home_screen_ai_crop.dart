part of '../home_screen.dart';

extension _HomeScreenAiCrop on HomeScreen {
  List<Widget> _aiRecommendationSection(
    BuildContext context,
    FarmProvider farmProvider,
    ZoneModel zone,
  ) {
    return [
      // Khuyến nghị AI thật của Zone đang chọn (từ lịch sử AI trên máy chủ)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ZoneAiAdviceCard(
          key: ValueKey(zone.zoneId),
          zoneId: zone.zoneId,
        ),
      ),
      const SizedBox(height: 14),
    ];
  }

  List<Widget> _activeCropSection(
    BuildContext context,
    FarmProvider farmProvider,
    ZoneModel zone,
  ) {
    return [
      // Active Crop & Cultivation Info Card
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ZoneDetailScreen(zone: zone)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Crop & Area
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          zone.currentCrop.contains('Cà chua')
                              ? '🍅'
                              : zone.currentCrop.contains('Dâu')
                              ? '🍓'
                              : '🫑',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.currentCrop,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  zone.currentStage,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '• ${zone.areaM2.toInt()} m²',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Assigned Worker Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'Phụ trách: ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              zone.assignedWorkerName ?? 'Chưa phân công',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (zone.workerRole != null) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '(${zone.workerRole!.split(' - ')[0]})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF0284C7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Growth Stages Pipeline
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'TIẾN ĐỘ 6 GIAI ĐOẠN CANH TÁC',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Chi tiết >',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Stage Progress Indicators
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stages = [
                          {'name': 'Gieo mầm', 'done': true, 'current': false},
                          {'name': 'Cây con', 'done': true, 'current': false},
                          {
                            'name': 'Sinh trưởng',
                            'done': true,
                            'current': false,
                          },
                          {
                            'name': 'Ra hoa',
                            'done': false,
                            'current':
                                zone.currentStage.contains('Ra hoa') ||
                                zone.currentStage.contains('Flowering'),
                          },
                          {
                            'name': 'Nuôi trái',
                            'done': false,
                            'current':
                                zone.currentStage.contains('Nuôi trái') ||
                                zone.currentStage.contains('Fruiting'),
                          },
                          {
                            'name': 'Thu hoạch',
                            'done': false,
                            'current': false,
                          },
                        ];

                        return Row(
                          children: List.generate(stages.length * 2 - 1, (
                            index,
                          ) {
                            if (index.isOdd) {
                              final prevIdx = index ~/ 2;
                              final isDone = stages[prevIdx]['done'] as bool;
                              return Expanded(
                                child: Container(
                                  height: 2,
                                  color: isDone
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFE2E8F0),
                                ),
                              );
                            }

                            final stageIdx = index ~/ 2;
                            final s = stages[stageIdx];
                            final isDone = s['done'] as bool;
                            final isCurrent = s['current'] as bool;

                            return Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCurrent
                                          ? const Color(0xFF059669)
                                          : isDone
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFF1F5F9),
                                      border: Border.all(
                                        color: isCurrent
                                            ? const Color(0xFF059669)
                                            : isDone
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFCBD5E1),
                                        width: isCurrent ? 2 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: isDone
                                          ? const Icon(
                                              Icons.check,
                                              size: 10,
                                              color: Color(0xFF059669),
                                            )
                                          : isCurrent
                                          ? Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Text(
                                              '${stageIdx + 1}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF94A3B8),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    s['name'] as String,
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isCurrent
                                          ? const Color(0xFF059669)
                                          : isDone
                                          ? const Color(0xFF334155)
                                          : const Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 20),
    ];
  }
}
