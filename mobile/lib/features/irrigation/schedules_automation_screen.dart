import '../../core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart';

part 'parts/schedules_automation_screen_lists.dart';
part 'parts/schedules_automation_screen_create_rule.dart';
part 'parts/schedules_automation_screen_create_schedule.dart';

class SchedulesAutomationScreen extends StatefulWidget {
  const SchedulesAutomationScreen({super.key});

  @override
  State<SchedulesAutomationScreen> createState() =>
      _SchedulesAutomationScreenState();
}

class _SchedulesAutomationScreenState extends State<SchedulesAutomationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _canConfigSchedule(FarmProvider provider) {
    // Backend API SchedulesController & AutoRulesController chỉ cho phép FarmOwner cấu hình.
    return provider.currentRole == 'OWNER';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context);
    final canConfig = _canConfigSchedule(provider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lập lịch & Tự động hóa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Schedules & WHEN-IF-THEN AutoRules',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(
              icon: Icon(Icons.flash_on, size: 18),
              text: 'Auto-Rules (IF-THEN)',
            ),
            Tab(
              icon: Icon(Icons.schedule, size: 18),
              text: 'Lịch Cron Định kỳ',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAutoRulesTab(context, provider),
          _buildSchedulesTab(context, provider),
        ],
      ),
      floatingActionButton: canConfig
          ? FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context),
              backgroundColor: const Color(0xFF062326),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Thêm Mới',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          : null,
    );
  }
}
