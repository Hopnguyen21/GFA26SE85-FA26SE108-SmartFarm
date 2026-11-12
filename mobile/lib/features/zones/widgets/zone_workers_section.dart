import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Nhân công/Người phụ trách CỦA ZONE đang mở: chỉ những người có quyền truy cập đúng Zone này (zoneAccess), không phải toàn bộ
/// nhân công của Farm. Chỉ Owner gán/đổi/gỡ (backend: PUT /users/{id}/zone-access, FarmOwner); Farmer/Technician chỉ xem.
class ZoneWorkersSection extends StatefulWidget {
  final ZoneModel zone;

  /// Mở hộp thoại gán/đổi nhân công (chỉ Owner thấy nút).
  final Future<void> Function()? onAssign;
  const ZoneWorkersSection({super.key, required this.zone, this.onAssign});

  @override
  State<ZoneWorkersSection> createState() => _ZoneWorkersSectionState();
}

class _ZoneWorkersSectionState extends State<ZoneWorkersSection> {
  String? _busyId;
  String? _error;

  Future<void> _remove(FarmProvider provider, FarmerModel w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Gỡ nhân công khỏi Zone?',
          style: TextStyle(fontSize: 15),
        ),
        content: Text(
          '"${w.name}" sẽ không còn xem/nhận việc/điều khiển tại Zone "${widget.zone.name}". '
          'Quyền với các Zone khác của họ giữ nguyên.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gỡ khỏi Zone'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final target = widget.zone.zoneId.toLowerCase();
    setState(() {
      _busyId = w.farmerId;
      _error = null;
    });
    try {
      // Gửi lại toàn bộ quyền khác của nhân công, chỉ bỏ Zone này.
      await AccountApi.updateFarmerZoneAccess(w.farmerId, [
        for (final a in w.zoneAccess)
          if (a.zoneId.toLowerCase() != target)
            {'zoneId': a.zoneId, 'canControl': a.canControl},
      ]);
      await provider.fetchFromApi();
    } catch (e) {
      if (mounted)
        setState(
          () => _error =
              'Không gỡ được: ${e.toString().replaceFirst('Exception: ', '')}',
        );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FarmProvider>();
    final isOwner = provider.canManageFarmStructure;
    // Zone mới nhất theo ID (tên người phụ trách do API Zone trả).
    final live =
        provider.allZones
            .where(
              (z) => z.zoneId.toLowerCase() == widget.zone.zoneId.toLowerCase(),
            )
            .firstOrNull ??
        widget.zone;
    final workers = provider
        .getWorkersForZone(live.zoneId)
        .where((w) => w.isActive)
        .toList();
    final hasLegacyName = workers.isEmpty && live.assignedWorkerName != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_pin_circle,
                size: 16,
                color: Color(0xFF0284C7),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'NHÂN CÔNG / NGƯỜI PHỤ TRÁCH ZONE NÀY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0284C7),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (workers.isEmpty && !hasLegacyName)
            const Text(
              'Chưa phân công',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _muted,
              ),
            ),
          if (hasLegacyName)
            Text(
              '${live.assignedWorkerName} · ${live.workerRole ?? 'Nông dân'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          for (final w in workers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        Text(
                          '${w.role}${w.phone.isEmpty ? '' : ' · ${w.phone}'}'
                          '${w.zoneAccess.any((a) => a.zoneId.toLowerCase() == live.zoneId.toLowerCase() && a.canControl) ? ' · được điều khiển thiết bị' : ' · chỉ xem & nhận việc'}',
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  if (isOwner)
                    _busyId == w.farmerId
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => _remove(provider, w),
                            child: const Text('Gỡ'),
                          ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
              ),
            ),
          if (isOwner && widget.onAssign != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busyId != null ? null : widget.onAssign,
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: Text(
                  workers.isEmpty && !hasLegacyName
                      ? 'Phân công ngay'
                      : 'Gán / đổi nhân công',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
