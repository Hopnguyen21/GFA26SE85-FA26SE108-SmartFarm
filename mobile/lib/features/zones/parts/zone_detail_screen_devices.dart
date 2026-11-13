part of '../zone_detail_screen.dart';

extension _ZoneDetailScreenStateDevices on _ZoneDetailScreenState {
  // ─── Tab 2: Thiết bị ─────────────────────────────────────────
  Widget _buildDevicesTab(
    BuildContext context,
    FarmProvider provider,
    List<ActuatorModel> actuators,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node sensors header
          const Text(
            'TRẠM SENSOR NODE LORA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ZoneNodeSummaryCard(
            zoneId: widget.zone.zoneId,
            zoneName: widget.zone.name,
            canEditLocations:
                provider.currentRole == 'OWNER' ||
                provider.currentRole == 'TECHNICIAN',
          ),

          const SizedBox(height: 20),

          // Actuators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIẾT BỊ CHẤP HÀNH (${actuators.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                provider.canControlZone(widget.zone.zoneId)
                    ? (provider.currentRole == 'OWNER'
                          ? 'Toàn quyền'
                          : 'Được điều khiển')
                    : 'Chỉ xem',
                style: TextStyle(
                  fontSize: 11,
                  color: provider.canControlZone(widget.zone.zoneId)
                      ? const Color(0xFF059669)
                      : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          if (!provider.canControlZone(widget.zone.zoneId))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                provider.currentRole == 'FARMER'
                    ? 'Bạn chưa được chủ trang trại cấp quyền điều khiển thiết bị tại Zone này nên chỉ xem được trạng thái.'
                    : 'Vai trò của bạn không có quyền ra lệnh điều khiển thiết bị; chỉ xem trạng thái.',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ),
          const SizedBox(height: 10),

          if (actuators.isNotEmpty) ...[
            EmergencyStopButton(
              zoneId: widget.zone.zoneId,
              zoneName: widget.zone.name,
            ),
            const SizedBox(height: 12),
          ],

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _toolChip(
                Icons.history,
                'Lịch sử điều khiển',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActuatorHistoryScreen(zone: widget.zone),
                  ),
                ),
              ),
              if (provider.currentRole == 'OWNER')
                _toolChip(
                  Icons.event_repeat,
                  'Lịch tưới & đồng bộ',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZoneIrrigationPage(zone: widget.zone),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (actuators.isEmpty &&
              provider.actuatorErrorFor(widget.zone.zoneId) != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Không tải được thiết bị của Zone: ${provider.actuatorErrorFor(widget.zone.zoneId)}',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => provider.refreshCurrentZoneActuators(
                      zoneId: widget.zone.zoneId,
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else if (actuators.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.device_unknown_outlined,
                      size: 36,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chưa có thiết bị chấp hành nào được gán vào Zone này.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...actuators.map(
              (act) => _buildActuatorCard(context, provider, act),
            ),

          const SizedBox(height: 20),

          // Safety rule banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Giới hạn an toàn do máy chủ quyết định',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Thời lượng tối đa, khóa an toàn (interlock), hoãn do mưa và dữ liệu cảm biến quá cũ đều do máy chủ kiểm tra. Ứng dụng chỉ báo lệnh thành công khi thiết bị phản hồi; nếu bị từ chối sẽ hiện đúng lý do của máy chủ.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB45309),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorCard(
    BuildContext context,
    FarmProvider provider,
    ActuatorModel act,
  ) {
    IconData icon;
    switch (act.actuatorType) {
      case 'PUMP':
        icon = Icons.water;
        break;
      case 'FAN':
        icon = Icons.wind_power;
        break;
      case 'VALVE':
        icon = Icons.tune;
        break;
      default:
        icon = Icons.lightbulb;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: act.isRunning
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: act.isRunning ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: act.isRunning
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: act.isRunning
                  ? const Color(0xFF059669)
                  : const Color(0xFF64748B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  act.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  act.isRunning
                      ? '🟢 Đang bật — còn ${act.remainingMinutes} phút'
                      : '⚫ Đang tắt',
                  style: TextStyle(
                    fontSize: 11,
                    color: act.isRunning
                        ? const Color(0xFF059669)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Không có quyền: vô hiệu hóa công tắc (giải thích ở dòng quyền phía trên) thay vì cho bấm rồi báo lỗi.
          Switch.adaptive(
            value: act.isRunning,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: provider.canControlZone(act.zoneId)
                ? (_) {
                    HapticFeedback.mediumImpact();
                    toggleActuatorWithFeedback(
                      context,
                      provider,
                      act.actuatorId,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: const Color(0xFF065F46)),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      backgroundColor: const Color(0xFFECFDF5),
      side: const BorderSide(color: Color(0xFFA7F3D0)),
      onPressed: onTap,
    );
  }

  // ─── Tab 5: Hợp đồng & Hỗ trợ kỹ thuật (Owner/Technician) ───
  Widget _buildContractsSupportTab(ZoneModel zone, FarmProvider provider) {
    final isOwner = provider.canManageFarmStructure;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZoneContractsSection(
            key: ValueKey('contracts_${zone.zoneId}'),
            zone: zone,
            canManage: isOwner,
          ),
          const SizedBox(height: 12),
          ZoneSupportSection(
            key: ValueKey('support_${zone.zoneId}'),
            zone: zone,
            canCreate: isOwner,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
