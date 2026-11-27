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
            // Kỹ thuật viên chỉ chấm/sửa vị trí node qua màn Gắn Node của phiếu lắp đặt (có cổng phiếu xuất kho đã duyệt);
            // ở đây chỉ Owner được sửa toạ độ trực tiếp.
            canEditLocations: provider.currentRole == 'OWNER',
          ),

          const SizedBox(height: 20),

          // Actuators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ĐIỀU KHIỂN RƠ-LE BƠM/QUẠT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      relaySummary(actuators),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    provider.canControlZone(widget.zone.zoneId)
                        ? (provider.currentRole == 'OWNER'
                              ? 'Toàn quyền'
                              : 'Được điều khiển')
                        : 'Chỉ xem',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: provider.canControlZone(widget.zone.zoneId)
                          ? const Color(0xFF047857)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
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
          const SizedBox(height: 6),

          if (actuators.isNotEmpty) ...[
            EmergencyStopButton(
              zoneId: widget.zone.zoneId,
              zoneName: widget.zone.name,
            ),
            const SizedBox(height: 8),
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
          const SizedBox(height: 8),

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

    final place = actuatorPlaceLabel(
      act,
      provider.actuators.where((x) => x.zoneId == act.zoneId),
    );
    final notReady = actuatorNotReadyReason(act);

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: act.isRunning ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: act.isRunning
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: act.isRunning ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: act.isRunning
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: act.isRunning
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: act.isRunning
                  ? const Color(0xFF047857)
                  : const Color(0xFF64748B),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  act.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (place != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1.5),
                    child: Text(
                      place,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          color: notReady != null || act.awaitingAck
                              ? const Color(0xFFD97706)
                              : (act.isRunning
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF94A3B8)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notReady ??
                              (act.awaitingAck
                                  ? 'Đã gửi lệnh — chờ gateway xác nhận'
                                  : act.isRunning
                                  ? 'Đang bật — còn ${act.remainingMinutes} phút'
                                  : 'Đang tắt'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: notReady != null
                                ? const Color(0xFFD97706)
                                : (act.isRunning
                                      ? const Color(0xFF047857)
                                      : const Color(0xFF64748B)),
                            fontWeight: act.isRunning
                                ? FontWeight.w700
                                : FontWeight.w500,
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Không có quyền: vô hiệu hóa công tắc (giải thích ở dòng quyền phía trên) thay vì cho bấm rồi báo lỗi.
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: act.isRunning,
              activeThumbColor: const Color(0xFF10B981),
              onChanged: provider.canControlZone(act.zoneId) && notReady == null
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
          ),
        ],
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 17, color: const Color(0xFF047857)),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF064E3B),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
