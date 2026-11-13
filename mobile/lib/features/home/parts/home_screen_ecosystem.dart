part of '../home_screen.dart';

extension _HomeScreenEcosystem on HomeScreen {
  List<Widget> _ecosystemSection(
    BuildContext context,
    FarmProvider farmProvider,
    ZoneModel zone,
  ) {
    return [
      // ─── FE-ALIGNED ECOSYSTEM SOLUTIONS CARDS (Solutions Ribbon) ───
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'HỆ SINH THÁI NÔNG NGHIỆP SỐ (FE ECOSYSTEM)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'VietGAP 4.0',
                style: TextStyle(
                  color: Color(0xFF065F46),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            // Sol 1: GIS Map
            _buildEcosystemFeatureCard(
              icon: Icons.map_outlined,
              iconBg: const Color(0xFF062326),
              iconColor: const Color(0xFF10B981),
              title: 'Bản Đồ GIS',
              subtitle: 'Phân tầng Farm ➔ Lô ➔ Zone',
            ),
            // Sol 2: Hardware LoRa
            _buildEcosystemFeatureCard(
              icon: Icons.cell_tower,
              iconBg: const Color(0xFF065F46),
              iconColor: Colors.white,
              title: 'Trạm LoRa 2.5km',
              subtitle: 'Pin mặt trời 3 năm liên tục',
            ),
            // Sol 3: Auto Microclimate
            _buildEcosystemFeatureCard(
              icon: Icons.water_drop_outlined,
              iconBg: const Color(0xFF0284C7),
              iconColor: Colors.white,
              title: 'Tự Động Vi Khí Hậu',
              subtitle: 'Lập lịch Cron & IF-THEN',
            ),
            // Sol 4: Electronic Contract
            _buildEcosystemFeatureCard(
              icon: Icons.verified_user_outlined,
              iconBg: const Color(0xFFD97706),
              iconColor: Colors.white,
              title: 'Hợp Đồng Điện Tử',
              subtitle: 'Cọc 30% - Nghiệm thu 70%',
            ),
          ],
        ),
      ),
    ];
  }

  // Helper for FE Ecosystem Feature Card
  Widget _buildEcosystemFeatureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
