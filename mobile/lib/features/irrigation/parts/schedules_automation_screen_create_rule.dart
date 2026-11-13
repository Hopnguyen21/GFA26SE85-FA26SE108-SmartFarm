part of '../schedules_automation_screen.dart';

extension _SchedulesAutomationScreenStateCreateRule
    on _SchedulesAutomationScreenState {
  void _showAddDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tạo Cấu Hình Mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on, color: Color(0xFF10B981)),
                ),
                title: const Text(
                  'Thêm AutoRule (IF-THEN)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Tự động hóa theo ngưỡng cảm biến không cần xác nhận',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateRuleDialog(context);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF062326).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.schedule, color: Color(0xFF062326)),
                ),
                title: const Text(
                  'Thêm Lịch Tưới Định Kỳ (Cron)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Lên lịch tưới tự động theo giờ cố định hàng ngày',
                ),
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
    String selectedZone = provider.zones.isNotEmpty
        ? provider.zones.first.name
        : 'Nhà màng 01';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Thiết Lập AutoRule Mới',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Text(
                      'Hệ thống tự động kích hoạt thiết bị khi cảm biến vi phạm ngưỡng',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),

                    // Chọn Zone
                    const Text(
                      'Khu vực áp dụng:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZone,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: provider.zones
                          .map(
                            (z) => DropdownMenuItem(
                              value: z.name,
                              child: Text(
                                z.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedZone = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Điều kiện IF
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ĐIỀU KIỆN (IF):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF062326),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedParam,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Độ ẩm đất (SOIL_MOISTURE)',
                                      child: Text(
                                        'Độ ẩm đất',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Nhiệt độ không khí (AIR_TEMP)',
                                      child: Text(
                                        'Nhiệt độ',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Độ ẩm không khí (AIR_HUMIDITY)',
                                      child: Text(
                                        'Độ ẩm khí',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Cường độ sáng (LIGHT_LUX)',
                                      child: Text(
                                        'Ánh sáng',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      setModalState(() {
                                        selectedParam = v;
                                        if (v.contains('AIR_TEMP')) {
                                          threshold = 30.0;
                                          selectedOp = '>';
                                        } else if (v.contains(
                                          'SOIL_MOISTURE',
                                        )) {
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: '<',
                                      child: Text(
                                        '<',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '>',
                                      child: Text(
                                        '>',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '<=',
                                      child: Text(
                                        '<=',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '>=',
                                      child: Text(
                                        '>=',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null)
                                      setModalState(() => selectedOp = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: threshold.toInt().toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HÀNH ĐỘNG THỰC THI (THEN):',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedActuator,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Bơm Tưới Nhỏ Giọt',
                                      child: Text(
                                        'Bơm tưới',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Quạt Thông Gió Đối Lưu',
                                      child: Text(
                                        'Quạt thông gió',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Đèn LED Quang Hợp',
                                      child: Text(
                                        'Đèn LED',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Van Xả Nước Tự Động',
                                      child: Text(
                                        'Van xả',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null)
                                      setModalState(() => selectedActuator = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedAction,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'BẬT (ON)',
                                      child: Text(
                                        'BẬT',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'TẮT (OFF)',
                                      child: Text(
                                        'TẮT',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    if (v != null)
                                      setModalState(() => selectedAction = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: duration.toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                            label: const Text(
                              'Kích Hoạt AutoRule',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final zone = provider.zones
                                  .where((z) => z.name == selectedZone)
                                  .firstOrNull;
                              final wanted = selectedActuator.contains('Quạt')
                                  ? 'FAN'
                                  : selectedActuator.contains('Đèn')
                                  ? 'GROW_LIGHT'
                                  : selectedActuator.contains('Van')
                                  ? 'VALVE'
                                  : 'PUMP';
                              final actuator = provider.actuators
                                  .where(
                                    (a) =>
                                        a.zoneId == zone?.zoneId &&
                                        a.actuatorType == wanted,
                                  )
                                  .firstOrNull;
                              if (zone == null || actuator == null) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Zone này chưa có thiết bị chấp hành phù hợp nên chưa tạo được rule.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              final parameter = selectedParam.contains('SOIL')
                                  ? 'SoilMoisture'
                                  : selectedParam.contains('TEMP')
                                  ? 'Temperature'
                                  : selectedParam.contains('HUMIDITY')
                                  ? 'AirHumidity'
                                  : 'LightIntensity';
                              final error = await provider.addAutomationRule(
                                zone.zoneId,
                                {
                                  'name':
                                      '$selectedAction $selectedActuator khi $selectedParam $selectedOp $threshold',
                                  'parameterCode': parameter,
                                  'operator': switch (selectedOp) {
                                    '<' => 'LessThan',
                                    '<=' => 'LessThanOrEqual',
                                    '>=' => 'GreaterThanOrEqual',
                                    _ => 'GreaterThan',
                                  },
                                  'threshold': threshold,
                                  'actuatorId': actuator.actuatorId,
                                  'action': selectedAction.contains('OFF')
                                      ? 'TurnOff'
                                      : 'TurnOn',
                                  'durationSeconds': (duration * 60).clamp(
                                    1,
                                    1800,
                                  ),
                                },
                              );
                              if (error != null) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(error),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Đã tạo và kích hoạt AutoRule.',
                                  ),
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
}
