part of '../zone_operations_screens.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 1. Lịch sử điều khiển thiết bị chấp hành
// ═══════════════════════════════════════════════════════════════════════════
class ActuatorHistoryScreen extends StatelessWidget {
  final ZoneModel zone;
  const ActuatorHistoryScreen({super.key, required this.zone});

  static const _statusVi = {
    'Pending': ('Chờ gửi', Color(0xFFD97706)),
    'Sent': ('Đã gửi', Color(0xFF0284C7)),
    'Acknowledged': ('Thiết bị đã nhận', _green),
    'Failed': ('Thất bại', _red),
    'TimedOut': ('Quá thời gian', _red),
    'Cancelled': ('Đã hủy', _muted),
  };
  static const _sourceVi = {
    'Manual': 'Thủ công',
    'Schedule': 'Lịch',
    'AutoRule': 'Luật tự động',
    'AI_APPROVED': 'AI (đã duyệt)',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FarmProvider>();
    final names = {
      for (final a in provider.actuators.where((a) => a.zoneId.toLowerCase() == zone.zoneId.toLowerCase()))
        a.actuatorId.toLowerCase(): a.name,
    };
    return Scaffold(
      appBar: AppBar(title: Text('Lịch sử điều khiển · ${zone.name}', style: const TextStyle(fontSize: 15))),
      body: _AsyncList<List<Map<String, dynamic>>>(
        load: () => AutomationApi.getActuatorHistory(zone.zoneId),
        builder: (context, items, _) {
          if (items.isEmpty) return _empty('Chưa có lệnh điều khiển nào trong 7 ngày qua.', Icons.history);
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = items[i];
              final status = _statusVi['${c['status']}'] ?? ('${c['status']}', _muted);
              final on = '${c['action']}' == 'TurnOn';
              final name =
                  names['${c['actuatorId']}'.toLowerCase()] ?? 'Thiết bị ${'${c['actuatorId']}'.split('-').first}';
              final secs = (c['durationSeconds'] as num?)?.toInt() ?? 0;
              final error = c['errorMessage'] ?? c['errorCode'];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(on ? Icons.play_circle_outline : Icons.stop_circle_outlined, color: on ? _green : _red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${on ? 'BẬT' : 'TẮT'} · $name',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_fmtTime(c['queuedAtUtc'])} · ${_sourceVi['${c['triggerSource']}'] ?? c['triggerSource']}'
                            '${on && secs > 0 ? ' · ${(secs / 60).ceil()} phút' : ''}',
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('$error', style: const TextStyle(fontSize: 11, color: _red)),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.$2.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.$1,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: status.$2),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
