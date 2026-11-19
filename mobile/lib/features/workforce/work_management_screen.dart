import 'package:flutter/material.dart';
import '../tasks/alerts_tasks_screen.dart';
import 'workforce_screen.dart';

/// Tab "Công việc" của Chủ trang trại: giao/theo dõi nhiệm vụ và quản lý nhân công (mời Farmer, phân quyền Zone) ở một chỗ.
class WorkManagementScreen extends StatelessWidget {
  const WorkManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF062326),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Công Việc & Nhân Công',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          bottom: TabBar(
            indicatorColor: Color(0xFF10B981),
            indicatorWeight: 3,
            labelColor: Color(0xFF10B981),
            unselectedLabelColor: Color(0xFF94A3B8),
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              _tab(Icons.checklist, 'Công Việc'),
              _tab(Icons.groups_2_outlined, 'Nhân Công'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [TasksTabView(), WorkforceScreen(embedded: true)],
        ),
      ),
    );
  }

  /// Tab một hàng (biểu tượng cạnh chữ) cho thanh tiêu đề gọn hơn kiểu biểu tượng xếp trên chữ.
  static Widget _tab(IconData icon, String label) => Tab(
    height: 44,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)],
    ),
  );
}
