import '../services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/farm_provider.dart';
import '../models/models.dart';

class SchedulesAutomationScreen extends StatefulWidget {
  const SchedulesAutomationScreen({super.key});

  @override
  State<SchedulesAutomationScreen> createState() => _SchedulesAutomationScreenState();
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
    if (provider.currentRole == 'OWNER' || provider.currentRole == 'TECHNICIAN') return true;
    final currentFarmer = provider.farmersForCurrentFarm.isNotEmpty ? provider.farmersForCurrentFarm.first : null;
    return currentFarmer?.permissions.contains('CAN_CONFIG_SCHEDULE') ?? false;
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
            Tab(icon: Icon(Icons.flash_on, size: 18), text: 'Auto-Rules (IF-THEN)'),
            Tab(icon: Icon(Icons.schedule, size: 18), text: 'Lịch Cron Định kỳ'),
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
              label: const Text('Thêm Mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : null,
    );
  }

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF062326),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('IF (NẾU)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('THEN (THÌ)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
              Text(
                'AutoRule • Cloud Engine',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                  provider.toggleSchedule(sch.scheduleId);
                },
              ),
            ],
          ),
          Text(
            '${sch.zoneName} • ${sch.actuatorName}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
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

  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tạo Cấu Hình Mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.flash_on, color: Color(0xFF10B981)),
                ),
                title: const Text('Thêm AutoRule (IF-THEN)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tự động hóa theo ngưỡng cảm biến không cần xác nhận'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateRuleDialog(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF062326).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.schedule, color: Color(0xFF062326)),
                ),
                title: const Text('Thêm Lịch Tưới Định Kỳ (Cron)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Lên lịch tưới tự động theo giờ cố định hàng ngày'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateScheduleDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateRuleDialog(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    String selectedParam = 'Độ ẩm đất (SOIL_MOISTURE)';
    String selectedOp = '<';
    double threshold = 60.0;
    String selectedActuator = 'Bơm Tưới Nhỏ Giọt';
    String selectedAction = 'BẬT (ON)';
    int duration = 15;
    String selectedZone = provider.zones.isNotEmpty ? provider.zones.first.name : 'Nhà màng 01';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(modalCtx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Thiết Lập AutoRule Mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const Text('Hệ thống tự động kích hoạt thiết bị khi cảm biến vi phạm ngưỡng', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 16),

                    // Chọn Zone
                    const Text('Khu vực áp dụng:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZone,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: provider.zones.map((z) => DropdownMenuItem(value: z.name, child: Text(z.name, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) { if (v != null) setModalState(() => selectedZone = v); },
                    ),
                    const SizedBox(height: 12),

                    // Điều kiện IF
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ĐIỀU KIỆN (IF):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF062326))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedParam,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Độ ẩm đất (SOIL_MOISTURE)', child: Text('Độ ẩm đất', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Nhiệt độ không khí (AIR_TEMP)', child: Text('Nhiệt độ', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Độ ẩm không khí (AIR_HUMIDITY)', child: Text('Độ ẩm khí', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Cường độ sáng (LIGHT_LUX)', child: Text('Ánh sáng', style: TextStyle(fontSize: 12))),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setModalState(() {
                                        selectedParam = v;
                                        if (v.contains('AIR_TEMP')) {
                                          threshold = 30.0;
                                          selectedOp = '>';
                                        } else if (v.contains('SOIL_MOISTURE')) {
                                          threshold = 60.0;
                                          selectedOp = '<';
                                        } else if (v.contains('LIGHT_LUX')) {
                                          threshold = 500.0;
                                          selectedOp = '<';
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedOp,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: '<', child: Text('<', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: '>', child: Text('>', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: '<=', child: Text('<=', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    DropdownMenuItem(value: '>=', child: Text('>=', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  ],
                                  onChanged: (v) { if (v != null) setModalState(() => selectedOp = v); },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: threshold.toInt().toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelText: 'Ngưỡng',
                                    labelStyle: const TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (v) {
                                    final parsed = double.tryParse(v);
                                    if (parsed != null) threshold = parsed;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Hành động THEN
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('HÀNH ĐỘNG THỰC THI (THEN):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedActuator,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Bơm Tưới Nhỏ Giọt', child: Text('Bơm tưới', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Quạt Thông Gió Đối Lưu', child: Text('Quạt thông gió', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Đèn LED Quang Hợp', child: Text('Đèn LED', style: TextStyle(fontSize: 12))),
                                    DropdownMenuItem(value: 'Van Xả Nước Tự Động', child: Text('Van xả', style: TextStyle(fontSize: 12))),
                                  ],
                                  onChanged: (v) { if (v != null) setModalState(() => selectedActuator = v); },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedAction,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'BẬT (ON)', child: Text('BẬT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                                    DropdownMenuItem(value: 'TẮT (OFF)', child: Text('TẮT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red))),
                                  ],
                                  onChanged: (v) { if (v != null) setModalState(() => selectedAction = v); },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: duration.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    labelText: 'Phút',
                                    labelStyle: const TextStyle(fontSize: 11),
                                  ),
                                  onChanged: (v) {
                                    final parsed = int.tryParse(v);
                                    if (parsed != null) duration = parsed;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Huỷ'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Kích Hoạt AutoRule', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final zone = provider.zones.where((z) => z.name == selectedZone).firstOrNull;
                              final wanted = selectedActuator.contains('Quạt')
                                  ? 'FAN'
                                  : selectedActuator.contains('Đèn')
                                      ? 'GROW_LIGHT'
                                      : selectedActuator.contains('Van') ? 'VALVE' : 'PUMP';
                              final actuator = provider.actuators
                                  .where((a) => a.zoneId == zone?.zoneId && a.actuatorType == wanted)
                                  .firstOrNull;
                              if (zone == null || actuator == null) {
                                messenger.showSnackBar(const SnackBar(content: Text('Zone này chưa có thiết bị chấp hành phù hợp nên chưa tạo được rule.')));
                                return;
                              }
                              final parameter = selectedParam.contains('SOIL')
                                  ? 'SoilMoisture'
                                  : selectedParam.contains('TEMP')
                                      ? 'Temperature'
                                      : selectedParam.contains('HUMIDITY') ? 'AirHumidity' : 'LightIntensity';
                              final error = await provider.addAutomationRule(zone.zoneId, {
                                'name': '$selectedAction $selectedActuator khi $selectedParam $selectedOp $threshold',
                                'parameterCode': parameter,
                                'operator': switch (selectedOp) {
                                  '<' => 'LessThan',
                                  '<=' => 'LessThanOrEqual',
                                  '>=' => 'GreaterThanOrEqual',
                                  _ => 'GreaterThan',
                                },
                                'threshold': threshold,
                                'actuatorId': actuator.actuatorId,
                                'action': selectedAction.contains('OFF') ? 'TurnOff' : 'TurnOn',
                                'durationSeconds': (duration * 60).clamp(1, 1800),
                              });
                              if (error != null) {
                                messenger.showSnackBar(SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)));
                                return;
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('✅ Đã tạo và kích hoạt AutoRule.'),
                                  backgroundColor: Color(0xFF059669),
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
            );
          },
        );
      },
    );
  }

  void _showCreateScheduleDialog(BuildContext context) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    String selectedZone = provider.zones.isNotEmpty ? provider.zones.first.name : 'Nhà màng 01';
    String selectedActuator = 'Bơm Tưới Nhỏ Giọt';
    String name = 'Lịch tưới định kỳ hàng ngày';
    String startTime = '06:00';
    int duration = 15;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Tạo Lịch Tưới Định Kỳ (Cron)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Tên lịch', border: OutlineInputBorder()),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: startTime,
                      decoration: const InputDecoration(labelText: 'Giờ bắt đầu (HH:mm)', border: OutlineInputBorder()),
                      onChanged: (v) => startTime = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: duration.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Thời lượng (phút)', border: OutlineInputBorder()),
                      onChanged: (v) {
                        final p = int.tryParse(v);
                        if (p != null) duration = p;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF062326), foregroundColor: Colors.white),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final zone = provider.zones.where((z) => z.name == selectedZone).firstOrNull;
                final wanted = selectedActuator.contains('Quạt')
                    ? 'FAN'
                    : selectedActuator.contains('Đèn')
                        ? 'GROW_LIGHT'
                        : selectedActuator.contains('Van') ? 'VALVE' : 'PUMP';
                final actuator = provider.actuators
                    .where((a) => a.zoneId == zone?.zoneId && a.actuatorType == wanted)
                    .firstOrNull;
                if (zone == null || actuator == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Zone này chưa có thiết bị chấp hành phù hợp.')));
                  return;
                }
                if (name.trim().isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên lịch.')));
                  return;
                }
                try {
                  await ApiService.createSchedule(
                    zoneId: zone.zoneId,
                    actuatorId: actuator.actuatorId,
                    name: name.trim(),
                    startTime: startTime.trim(),
                    durationMinutes: duration,
                  );
                  await provider.fetchSchedules(zoneId: zone.zoneId);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: const Color(0xFFEF4444)));
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  const SnackBar(content: Text('✅ Đã tạo lịch tưới trên máy chủ.'), backgroundColor: Color(0xFF062326)),
                );
              },
              child: const Text('Lưu Lịch'),
            ),
          ],
        );
      },
    );
  }
}
