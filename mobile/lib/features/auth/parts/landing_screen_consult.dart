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
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: isSubmitted
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF10B981),
                          size: 54,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa gửi được yêu cầu tư vấn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF062326),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ứng dụng chưa có kênh gửi yêu cầu tư vấn lên máy chủ nên thông tin của bạn CHƯA được gửi đi. Hãy đăng ký tài khoản Chủ trang trại để gửi yêu cầu khảo sát và lắp đặt.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF062326),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.eco,
                                      color: Color(0xFF10B981),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Đăng ký Tư vấn & Khảo sát Thực địa',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF062326),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Đóng',
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const Text(
                            'Để lại thông tin để tham khảo giải pháp. Lưu ý: ứng dụng chưa gửi được yêu cầu tư vấn lên máy chủ; hãy đăng ký tài khoản để gửi yêu cầu khảo sát.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Họ và tên chủ trang trại / đại diện',
                              labelStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại liên hệ (Zalo)',
                              labelStyle: const TextStyle(fontSize: 12),
                              prefixIcon: const Icon(
                                Icons.phone_outlined,
                                size: 18,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
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
                                    labelText: 'Diện tích trang trại',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    prefixIcon: const Icon(
                                      Icons.landscape_outlined,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedProvince,
                                  isExpanded: true,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF062326),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Lâm Đồng (Đà Lạt)',
                                      child: Text('Lâm Đồng (Đà Lạt)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Đắk Lắk',
                                      child: Text('Đắk Lắk'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Gia Lai',
                                      child: Text('Gia Lai'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Sơn La',
                                      child: Text('Sơn La (Mộc Châu)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Đồng Nai',
                                      child: Text('Đồng Nai'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Tỉnh thành khác',
                                      child: Text('Tỉnh thành khác'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(
                                        () => selectedProvince = val,
                                      );
                                    }
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'Tỉnh / Thành phố',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (nameController.text.trim().isEmpty ||
                                  phoneController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vui lòng điền họ tên và số điện thoại',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => isSubmitted = true);
                              // Như web: hiện xác nhận 2,5 giây rồi tự đóng.
                              Future.delayed(
                                const Duration(milliseconds: 2500),
                                () {
                                  if (ctx.mounted && Navigator.canPop(ctx)) {
                                    Navigator.pop(ctx);
                                  }
                                },
                              );
                            },
                            icon: const Icon(Icons.send, size: 16),
                            label: const Text(
                              'Xác nhận gửi thông tin khảo sát',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF062326),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    ).then(
      (_) => disposeControllersLater([
        nameController,
        phoneController,
        areaController,
      ]),
    );
  }
}
