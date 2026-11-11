part of '../landing_screen.dart';

extension _LandingScreenStateConsult on _LandingScreenState {
  void _showConsultModal(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final areaController = TextEditingController();
    String selectedProvince = 'Lâm Đồng (Đà Lạt)';
    bool isSubmitted = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: isSubmitted
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 54),
                        const SizedBox(height: 12),
                        const Text(
                          'Gửi Yêu Cầu Thành Công!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF062326)),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kỹ thuật viên SmartFarm sẽ liên hệ lại với bạn trong vòng 15 phút để tư vấn khảo sát thực địa.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF062326),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 45),
                          ),
                          child: const Text('Đóng'),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.eco, color: Color(0xFF10B981), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tư Vấn Khảo Sát Nông Trang',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF062326),
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
                          const Text(
                            'Để lại thông tin để kỹ sư phần cứng LoRa liên hệ tư vấn cấu hình thiết bị tối ưu.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Họ và tên chủ trang trại',
                              labelStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.person_outline, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại (Zalo)',
                              labelStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: areaController,
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Diện tích (ha/m²)',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    prefixIcon: const Icon(Icons.landscape_outlined, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedProvince,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF062326)),
                                  items: const [
                                    DropdownMenuItem(value: 'Lâm Đồng (Đà Lạt)', child: Text('Lâm Đồng')),
                                    DropdownMenuItem(value: 'Đắk Lắk', child: Text('Đắk Lắk')),
                                    DropdownMenuItem(value: 'Gia Lai', child: Text('Gia Lai')),
                                    DropdownMenuItem(value: 'Sơn La', child: Text('Sơn La')),
                                    DropdownMenuItem(value: 'Tỉnh khác', child: Text('Khác')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => selectedProvince = val);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Khu vực',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(const SnackBar(content: Text('Vui lòng điền họ tên và số điện thoại')));
                                return;
                              }
                              setModalState(() => isSubmitted = true);
                            },
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text('Gửi Yêu Cầu Khảo Sát'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF062326),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    ).then((_) => disposeControllersLater([nameController, phoneController, areaController]));
  }
}
