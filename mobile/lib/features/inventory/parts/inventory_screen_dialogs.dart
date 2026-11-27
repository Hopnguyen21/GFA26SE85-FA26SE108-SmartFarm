part of '../inventory_screen.dart';

extension _InventoryScreenStateDialogs on _InventoryScreenState {
  /// Số thực người dùng gõ; chấp nhận dấu phẩy kiểu Việt (1,5). null khi không phải số hữu hạn.
  double? _parseQty(String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    return v != null && v.isFinite ? v : null;
  }

  void _showAdjustStockModal(
    BuildContext context,
    FarmProvider provider,
    MaterialInventoryModel item,
  ) {
    var busy = false;
    final qtyCtrl = TextEditingController(
      text: item.quantity.toStringAsFixed(
        item.quantity.truncateToDouble() == item.quantity ? 0 : 1,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Điều Chỉnh Số Lượng Tồn',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.materialName,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Số lượng tồn mới (${item.unit})',
                  hintText: 'Nhập số lượng thực tế trong kho',
                  suffixText: item.unit,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (busy)
                      return; // chặn bấm đúp: mỗi lần bấm là một dòng trong sổ kho
                    final messenger = ScaffoldMessenger.of(context);
                    final newQty = _parseQty(qtyCtrl.text);
                    if (newQty == null || newQty < 0) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Nhập số lượng tồn là một số không âm (ví dụ 12 hoặc 1,5).',
                          ),
                        ),
                      );
                      return;
                    }
                    final diff = newQty - item.quantity;
                    if (diff == 0) {
                      Navigator.pop(ctx);
                      return;
                    }
                    busy = true;
                    try {
                      String? error;
                      if (diff > 0) {
                        error = await provider.receiveStock(
                          item.inventoryId,
                          diff,
                        );
                      } else {
                        // Xuất kho phải ghi rõ Zone sử dụng để giữ lịch sử.
                        final zoneId = await showDialog<String>(
                          context: ctx,
                          builder: (dCtx) => SimpleDialog(
                            title: const Text(
                              'Xuất cho Zone nào?',
                              style: TextStyle(fontSize: 15),
                            ),
                            children: [
                              // Chỉ Zone của trang trại đang chọn: sổ kho thuộc từng trang trại, Zone trang trại khác sẽ bị backend từ chối.
                              for (final z in provider.allZones.where(
                                (z) => z.farmId == provider.selectedFarmId,
                              ))
                                SimpleDialogOption(
                                  onPressed: () =>
                                      Navigator.pop(dCtx, z.zoneId),
                                  child: Text(z.name),
                                ),
                            ],
                          ),
                        );
                        if (zoneId == null) return;
                        error = await provider.issueStock(
                          item.inventoryId,
                          -diff,
                          zoneId,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            error ??
                                'Đã cập nhật tồn kho: $newQty ${item.unit}',
                          ),
                        ),
                      );
                    } finally {
                      busy = false;
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'XÁC NHẬN CẬP NHẬT TỒN KHO',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => disposeControllersLater([qtyCtrl]));
  }

  void _showAddMaterialModal(BuildContext context, FarmProvider provider) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '100');
    final unitCtrl = TextEditingController(text: 'kg');
    final minStockCtrl = TextEditingController(text: '20');
    String selectedCat = 'FERTILIZER';
    var adding = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nhập Thêm Vật Tư Mới Vào Kho',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Đóng',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tên vật tư nông nghiệp *',
                      hintText:
                          'Ví dụ: Phân bón Kali Clorua, Hạt giống Ớt chuông...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCat,
                          decoration: InputDecoration(
                            labelText: 'Phân loại',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'FERTILIZER',
                              child: Text(
                                'Phân Bón',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'SEED',
                              child: Text(
                                'Hạt Giống',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'PESTICIDE',
                              child: Text(
                                'Thuốc Sinh Học',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'EQUIPMENT',
                              child: Text(
                                'Vật Tư & Tưới',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                          onChanged: (val) => setModalState(
                            () => selectedCat = val ?? 'FERTILIZER',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Số lượng nhập',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          decoration: InputDecoration(
                            labelText: 'Đơn vị tính (kg, lít, cuộn)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Mức tồn tối thiểu',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (adding) return; // chặn bấm đúp (tạo trùng vật tư)
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng nhập tên vật tư'),
                            ),
                          );
                          return;
                        }
                        // Số sai (chữ, âm) phải báo lỗi, không được lặng lẽ đổi thành 0 rồi vẫn tạo vật tư.
                        final qty = _parseQty(qtyCtrl.text);
                        final minStock = _parseQty(minStockCtrl.text);
                        if (qty == null ||
                            qty < 0 ||
                            minStock == null ||
                            minStock < 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Số lượng nhập và mức tồn tối thiểu phải là số không âm (ví dụ 100 hoặc 1,5).',
                              ),
                            ),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        adding = true;
                        final String? error;
                        try {
                          error = await provider.addInventoryItem(
                            materialName: name,
                            category: selectedCat,
                            quantity: qty,
                            unit: unitCtrl.text.trim(),
                            minimumStock: minStock,
                          );
                        } finally {
                          adding = false;
                        }
                        if (error != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error)),
                          );
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Đã thêm "$name" vào kho vật tư'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'LƯU VẬT TƯ VÀO KHO',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then(
      (_) =>
          disposeControllersLater([nameCtrl, qtyCtrl, unitCtrl, minStockCtrl]),
    );
  }

  void _showStockInsModal(BuildContext context, FarmProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.receipt_long,
                      color: Color(0xFF10B981),
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Phiếu Nhập Kho & Lịch Sử',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Danh sách phiếu nhập vật tư và thiết bị tại trang trại',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: TaskApi.getStockIns(provider.selectedFarmId),
                builder: (fCtx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Lỗi tải khác với "chưa có phiếu": không được hiển thị lỗi như danh sách rỗng.
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Không tải được phiếu nhập kho: ${userFacingError(snapshot.error!)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Chưa có phiếu nhập kho nào.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (lCtx, index) {
                      final item = list[index];
                      final code = item['stockInCode']?.toString() ?? 'PNK';
                      final supplier =
                          item['supplierName']?.toString() ?? 'Nội bộ';
                      final status =
                          item['statusText']?.toString() ?? 'Đã hoàn thành';
                      final totalAmount =
                          (item['totalAmount'] as num?)?.toDouble() ?? 0;
                      final details = (item['details'] as List?) ?? [];
                      final isCompleted =
                          status.contains('hoàn thành') ||
                          status == 'Completed';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isCompleted
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.business_outlined,
                                  size: 14,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    supplier,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (totalAmount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Tổng giá trị: ${totalAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} đ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                            const Divider(height: 16),
                            Text(
                              'Chi tiết hàng nhập (${details.length} mục):',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(height: 4),
                            for (final d in details)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• ${d['itemName'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${d['quantity'] ?? 0} ${d['unit'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F766E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
