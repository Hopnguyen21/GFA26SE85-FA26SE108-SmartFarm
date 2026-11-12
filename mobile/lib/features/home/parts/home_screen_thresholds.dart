part of '../home_screen.dart';

extension _HomeScreenThresholds on HomeScreen {
  // ─── Modal Cài Đặt Ngưỡng An Toàn & Kích Hoạt Thiết Bị (Threshold Setting) ───
  void _showThresholdSettingsModal(BuildContext context, dynamic zone) {
    final provider = Provider.of<FarmProvider>(context, listen: false);
    double minTemp = 18.0;
    double maxTemp = 28.0;
    double minSoil = 60.0;
    double maxSoil = 80.0;
    bool autoFan = true;
    bool autoPump = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cài Đặt Ngưỡng Tự Động (AutoRule)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${zone.name} • Tiêu chuẩn VietGAP',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nhiệt độ không khí
                  Container(
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.thermostat,
                                  color: Color(0xFFEA580C),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Dải nhiệt độ tối ưu:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${minTemp.toInt()}°C - ${maxTemp.toInt()}°C',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFFEA580C),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(minTemp, maxTemp),
                          min: 10,
                          max: 38,
                          divisions: 28,
                          activeColor: const Color(0xFFEA580C),
                          inactiveColor: const Color(0xFFFED7AA),
                          labels: RangeLabels(
                            '${minTemp.toInt()}°C',
                            '${maxTemp.toInt()}°C',
                          ),
                          onChanged: (values) {
                            setModalState(() {
                              minTemp = values.start;
                              maxTemp = values.end;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tự bật Quạt đối lưu khi > Max:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Switch(
                              value: autoFan,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) =>
                                  setModalState(() => autoFan = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Độ ẩm đất
                  Container(
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.water_drop,
                                  color: Color(0xFF0284C7),
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Dải độ ẩm đất (Soil):',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${minSoil.toInt()}% - ${maxSoil.toInt()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                        RangeSlider(
                          values: RangeValues(minSoil, maxSoil),
                          min: 30,
                          max: 95,
                          divisions: 65,
                          activeColor: const Color(0xFF0284C7),
                          inactiveColor: const Color(0xFFBAE6FD),
                          labels: RangeLabels(
                            '${minSoil.toInt()}%',
                            '${maxSoil.toInt()}%',
                          ),
                          onChanged: (values) {
                            setModalState(() {
                              minSoil = values.start;
                              maxSoil = values.end;
                            });
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tự bật Bơm tưới khi < Min:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Switch(
                              value: autoPump,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (val) =>
                                  setModalState(() => autoPump = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Nút Lưu và Nút Mở trang AutoRule đầy đủ
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SchedulesAutomationScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            foregroundColor: const Color(0xFF0284C7),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.flash_on, size: 16),
                          label: const Text(
                            'Tất cả AutoRule',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final error = await provider.updateZoneThresholds(
                              zoneId: zone.zoneId,
                              maxTemp: maxTemp,
                              minSoil: minSoil,
                              maxSoil: maxSoil,
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
                              SnackBar(
                                content: Text(
                                  '✅ Đã lưu cấu hình ngưỡng cho ${zone.name}: Nhiệt độ ${minTemp.toInt()}–${maxTemp.toInt()}°C, Độ ẩm ${minSoil.toInt()}–${maxSoil.toInt()}%!',
                                ),
                                backgroundColor: const Color(0xFF059669),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text(
                            'Lưu Ngưỡng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
