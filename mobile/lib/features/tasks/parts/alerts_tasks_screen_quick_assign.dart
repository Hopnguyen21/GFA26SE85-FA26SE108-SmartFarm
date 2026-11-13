part of '../alerts_tasks_screen.dart';

extension _AlertsTasksScreenQuickAssign on AlertsTasksScreen {
  void _showQuickAssignTaskDialog(
    BuildContext context,
    FarmProvider farmProvider,
  ) {
    final farmers = farmProvider.farmersForCurrentFarm;
    if (farmers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có danh sách Nông dân để giao việc'),
        ),
      );
      return;
    }

    // Không dùng Zone giả: chưa có Zone thật thì không mở form giao việc.
    if (farmProvider.zones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trang trại chưa có Zone để giao việc')),
      );
      return;
    }

    String selectedFarmerId = farmers.first.farmerId;
    String selectedZoneId = farmProvider.zones.first.zoneId;
    final titleCtrl = TextEditingController(
      text: 'Tưới nhỏ giọt & kiểm tra độ ẩm đất',
    );
    final descCtrl = TextEditingController();
    String priority = 'HIGH';
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    final presets = [
      'Tưới nhỏ giọt & kiểm tra độ ẩm đất',
      'Tỉa cành & bấm ngọn chồi nách',
      'Châm dung dịch dinh dưỡng NPK',
      'Phun chế phẩm sinh học phòng trừ sâu',
      'Thu hoạch và phân loại VietGAP',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final targetZone = farmProvider.zones.firstWhere(
            (z) => z.zoneId == selectedZoneId,
            orElse: () => farmProvider.zones.first,
          );
          final targetFarmer = farmers.firstWhere(
            (f) => f.farmerId == selectedFarmerId,
            orElse: () => farmers.first,
          );

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_add,
                          color: Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giao Việc Cho Nông Dân',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Phân công công việc theo từng khu vực',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Chọn Nông dân
                  const Text(
                    'Chọn Nông dân phụ trách: *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedFarmerId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: farmers
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.farmerId,
                            child: Text(
                              '${f.name} (${f.role})',
                              style: const TextStyle(fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => selectedFarmerId = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Chọn Nhà màng
                  if (farmProvider.zones.isNotEmpty) ...[
                    const Text(
                      'Chọn Nhà màng / Khu vực thực hiện: *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedZoneId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: farmProvider.zones
                          .map(
                            (z) => DropdownMenuItem(
                              value: z.zoneId,
                              child: Text(
                                '${z.name} (${z.currentCrop})',
                                style: const TextStyle(fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedZoneId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Mẫu việc nhanh
                  const Text(
                    'Mẫu công việc phổ biến:',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presets.map((preset) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () =>
                                setModalState(() => titleCtrl.text = preset),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                preset,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tiêu đề
                  const Text(
                    'Tiêu đề công việc: *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập nội dung công việc...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mức ưu tiên & Hạn hoàn thành
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mức độ ưu tiên:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'LOW',
                                  child: Text(
                                    '🟢 Bình thường',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'MEDIUM',
                                  child: Text(
                                    '🟡 Trung bình',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'HIGH',
                                  child: Text(
                                    '🔴 Khẩn cấp',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null)
                                  setModalState(() => priority = v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hạn hoàn thành:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: modalCtx,
                                  initialDate: dueDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 90),
                                  ),
                                );
                                if (picked != null)
                                  setModalState(() => dueDate = picked);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ghi chú
                  const Text(
                    'Yêu cầu chi tiết / Ghi chú:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Mô tả chi tiết kỹ thuật...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          child: const Text('Hủy'),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(
                            'Xác Nhận Giao Việc',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            if (titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Vui lòng nhập tiêu đề công việc!',
                                  ),
                                ),
                              );
                              return;
                            }
                            final dueStr =
                                'Ngày ${dueDate.day}/${dueDate.month}, 17:00';
                            final messenger = ScaffoldMessenger.of(context);
                            final error = await farmProvider.addTask(
                              title: titleCtrl.text.trim(),
                              zoneName: targetZone.name.split(' - ').first,
                              priority: priority,
                              dueDate: dueStr,
                              assignedFarmerId: targetFarmer.farmerId,
                              assignedFarmerName: targetFarmer.name,
                              description: descCtrl.text.trim(),
                              zoneId: selectedZoneId,
                              dueAt: DateTime(
                                dueDate.year,
                                dueDate.month,
                                dueDate.day,
                                17,
                              ),
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
                            if (modalCtx.mounted) Navigator.pop(modalCtx);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '📋 Đã giao việc cho ${targetFarmer.name}!',
                                ),
                                backgroundColor: const Color(0xFF059669),
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
      ),
    ).then((_) => disposeControllersLater([titleCtrl, descCtrl]));
  }
}
