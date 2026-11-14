part of '../farmer_dashboard_screen.dart';

extension _FarmerDashboardWidgets on _FarmerDashboardScreenState {
  Widget _buildHero(
    FarmProvider provider,
    int zoneCount,
    int todoCount,
    int overdueCount,
    int reviewCount,
    int alertCount,
  ) {
    final fullName = provider.me?['fullName']?.toString().trim() ?? '';
    final name = fullName.isNotEmpty ? fullName : 'Nông dân';
    final farmName = provider.currentFarm.name.isNotEmpty
        ? provider.currentFarm.name
        : 'Trang trại Nông nghiệp Công nghệ cao';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF119653), Color(0xFF0F874A), Color(0xFF0A5E33)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kGreen.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pill('NÔNG DÂN THỰC ĐỊA • SMARTFARM'),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 13,
                color: Color(0xFFD1FAE5),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  farmName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD1FAE5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: provider.isLoadingApi ? null : () => _sync(provider),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
            icon: provider.isLoadingApi
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, size: 14),
            label: Text(
              provider.isLoadingApi ? 'Đang đồng bộ...' : 'Đồng bộ dữ liệu',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Xin chào, $name!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hôm nay bạn đang phụ trách $zoneCount khu vực nhà màng. '
            'Có $todoCount công việc cần thực hiện '
            '(${overdueCount > 0 ? '$overdueCount việc quá hạn' : 'tất cả đúng tiến độ'}).',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFFD1FAE5),
            ),
          ),
          const SizedBox(height: 12),
          _buildWeather(provider),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _kpi(
                  'Việc cần làm',
                  '$todoCount',
                  Icons.assignment_outlined,
                  Colors.white,
                  suffix: overdueCount > 0 ? '$overdueCount quá hạn' : null,
                  onTap: () => _rebuild(() => _filter = _TaskFilter.todo),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpi(
                  'Chờ chủ duyệt',
                  '$reviewCount',
                  Icons.schedule,
                  const Color(0xFFFDE68A),
                  onTap: () => _rebuild(() => _filter = _TaskFilter.review),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _kpi(
                  'Cảnh báo mở',
                  '$alertCount',
                  Icons.shield_outlined,
                  alertCount > 0 ? const Color(0xFFFDA4AF) : Colors.white,
                  onTap: () => _openAlertsTasks(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _kpi(
                  'Zone phụ trách',
                  '$zoneCount',
                  Icons.eco_outlined,
                  Colors.white,
                  onTap: () {
                    // Cuộn tới danh sách khu vực ngay trên trang này.
                    final ctx = _zonesKey.currentContext;
                    if (ctx != null) {
                      Scrollable.ensureVisible(
                        ctx,
                        duration: const Duration(milliseconds: 300),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );

  Widget _kpi(
    String label,
    String value,
    IconData icon,
    Color valueColor, {
    String? suffix,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD1FAE5),
                    ),
                  ),
                ),
                Icon(icon, size: 15, color: Colors.white),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: valueColor,
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      suffix,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDA4AF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Thời tiết thật của trang trại; chưa có dữ liệu thì nói rõ, không dựng số giả.
  Widget _buildWeather(FarmProvider provider) {
    final w = provider.farmWeather;
    final has = w != null && w['temperature'] != null;
    String num0(String key, {String unit = '', int digits = 0}) {
      final v = w?[key];
      return v is num ? '${v.toStringAsFixed(digits)}$unit' : '--';
    }

    final condition = has
        ? (w['weatherDescription']?.toString() ?? 'Khí hậu địa phương')
        : (provider.isLoadingWeather ? 'Đang cập nhật...' : 'Chưa có dữ liệu');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, size: 14, color: Color(0xFFFCD34D)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Thời tiết thực địa',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA7F3D0),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  condition,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    has ? num0('temperature', unit: '°C', digits: 1) : '--°C',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _wxLine(
                    Icons.water_drop,
                    'Độ ẩm',
                    num0('humidity', unit: '%'),
                  ),
                  _wxLine(
                    Icons.air,
                    'Gió',
                    num0('windSpeed', unit: ' km/h', digits: 1),
                  ),
                ],
              ),
            ],
          ),
          if (w?['precipitationProbability'] is num) ...[
            const SizedBox(height: 6),
            _wxLine(
              Icons.grain,
              'Khả năng mưa',
              num0('precipitationProbability', unit: '%'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _wxLine(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 1),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF7DD3FC)),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Color(0xFFD1FAE5)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _quickTile(
    IconData icon,
    Color bg,
    Color fg,
    String title,
    String sub,
    VoidCallback onTap, {
    Color border = const Color(0xFFE2E8F0),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    FarmProvider provider,
    List<ZoneModel> zones,
    int todoCount,
    int alertCount,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickTile(
                Icons.power_settings_new,
                const Color(0xFFD1FAE5),
                _kGreen,
                'Bật tưới nhanh',
                'Chuẩn an toàn BR-SAFE-01',
                () => _openIrrigation(provider, zones),
                border: const Color(0xFFA7F3D0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickTile(
                Icons.assignment_outlined,
                const Color(0xFFE0F2FE),
                const Color(0xFF0369A1),
                'Công việc của tôi',
                '$todoCount việc đang chờ',
                () => _openAlertsTasks(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _quickTile(
                Icons.place_outlined,
                const Color(0xFFFEF3C7),
                const Color(0xFFB45309),
                'Bản đồ GIS & Node',
                'Xem vị trí cảm biến thực địa',
                () => _goTab(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickTile(
                Icons.shield_outlined,
                const Color(0xFFFFE4E6),
                const Color(0xFFBE123C),
                'Cảnh báo vi khí hậu',
                '$alertCount thông báo nóng',
                () => _openAlertsTasks(1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Backend chỉ trả zoneId của cảnh báo (không có tên Zone): tra tên từ danh sách Zone được phân công.
  Widget _buildAlertBanner(
    List<AlertModel> open,
    Map<String, String> zoneNames,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: Color(0xFFE11D48),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phát hiện ${open.length} cảnh báo vi phạm ngưỡng vi khí hậu tại nhà màng!',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final a in open.take(3))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.zoneName.isNotEmpty
                              ? a.zoneName
                              : (zoneNames[a.zoneId] ?? 'Khu vực'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          a.severity,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    a.message.isNotEmpty ? a.message : a.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openAlertsTasks(1),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
              ),
              child: const Text('Kiểm tra ngay ➔'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    final f = _feedback!;
    final fg = f.ok ? const Color(0xFF065F46) : const Color(0xFF9F1239);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: f.ok ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: f.ok ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            f.ok ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              f.message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          InkWell(
            onTap: () => _rebuild(() => _feedback = null),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
