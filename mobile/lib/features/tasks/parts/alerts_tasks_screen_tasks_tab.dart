part of '../alerts_tasks_screen.dart';

extension _AlertsTasksScreenTasksTab on AlertsTasksScreen {
  List<Widget> _tasksTab(BuildContext context, FarmProvider farmProvider) {
    return [
      // Tasks Tab
      RefreshIndicator(
        onRefresh: farmProvider.fetchFromApi,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Quick Assign Task Banner for OWNER
            if (farmProvider.currentRole == 'OWNER') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF062326), Color(0xFF0F3B3F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF062326).withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add_task, color: Color(0xFF34D399), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giao Việc Cho Nông Dân',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Phân công trực tiếp theo khu vực nhà màng & theo dõi tiến độ',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _showQuickAssignTaskDialog(context, farmProvider),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Giao việc', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            if (farmProvider.tasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.checklist_rtl_rounded, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'Chưa có nhiệm vụ nào cần thực hiện',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ...farmProvider.tasks.map((task) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                          color: task.isCompleted ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${task.zoneName} • Hạn: ${task.dueDate}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                                if (task.assignedFarmerName != null && task.assignedFarmerName!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin_circle_outlined, size: 13, color: Color(0xFF0F766E)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Giao cho: ${task.assignedFarmerName}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F766E),
                                        ),
                                      ),
                                      if (task.priority.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: task.priority == 'HIGH'
                                                ? const Color(0xFFFEE2E2)
                                                : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            task.priority == 'HIGH' ? 'Ưu tiên cao' : 'Bình thường',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: task.priority == 'HIGH'
                                                  ? const Color(0xFFB91C1C)
                                                  : const Color(0xFFB45309),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                                TaskActions(task: task, isOwner: farmProvider.currentRole != 'FARMER'),
                                if (task.description != null && task.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    task.description!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
