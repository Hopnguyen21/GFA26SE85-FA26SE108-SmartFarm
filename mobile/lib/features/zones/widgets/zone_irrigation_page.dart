import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import 'zone_irrigation_panel.dart';

/// Lịch tưới của MỘT Zone, gom ba loại lịch tách biệt: lịch mẫu của hồ sơ gắn trên Zone, lịch tùy chỉnh theo ngày của vụ,
/// và lịch điều khiển thiết bị (ControlSchedule) cùng nút đồng bộ. Luôn dùng bản Zone mới nhất theo `zoneId`.
class ZoneIrrigationPage extends StatelessWidget {
  final ZoneModel zone;
  const ZoneIrrigationPage({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final live =
        context
            .watch<FarmProvider>()
            .allZones
            .where((z) => z.zoneId.toLowerCase() == zone.zoneId.toLowerCase())
            .firstOrNull ??
        zone;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lịch tưới · ${live.name}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ZoneIrrigationPanel(
          key: ValueKey('irrigation_${live.zoneId}'),
          zone: live,
        ),
      ),
    );
  }
}
