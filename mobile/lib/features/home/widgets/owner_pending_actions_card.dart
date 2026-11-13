import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../support/service_board_logic.dart';
import '../../support/support_requests_screen.dart';

/// Thẻ "Việc cần bạn xử lý" trên trang chủ Owner: các yêu cầu lắp đặt đang chờ chính Owner (ký hợp đồng + cọc 30%,
/// ký nghiệm thu + 70%), mọi Zone của trang trại. Bấm vào một dòng để mở thẳng hợp đồng. Không có việc chờ hoặc đọc lỗi thì ẩn
/// (không hiện số giả).
class OwnerPendingActionsCard extends StatefulWidget {
  final List<ZoneModel> zones;
  const OwnerPendingActionsCard({super.key, required this.zones});

  @override
  State<OwnerPendingActionsCard> createState() =>
      _OwnerPendingActionsCardState();
}

class _Pending {
  final Map<String, dynamic> request;
  final String action;
  const _Pending(this.request, this.action);
}

class _OwnerPendingActionsCardState extends State<OwnerPendingActionsCard> {
  List<_Pending> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await SupportApi.getServiceRequests();
      final infos = await Future.wait([
        for (final r in all) loadOwnerRequestInfo(r),
      ]);
      final out = <_Pending>[];
      for (var i = 0; i < all.length; i++) {
        final n = infos[i].next;
        if (n != null && n.needsAction) out.add(_Pending(all[i], n.text));
      }
      if (mounted) setState(() => _items = out);
    } catch (_) {
      // Thẻ thông báo là phụ: lỗi mạng thì không chặn trang chủ.
    }
  }

  String _zoneName(Map<String, dynamic> r) {
    final id = '${r['zoneId'] ?? ''}'.toLowerCase();
    final z = widget.zones
        .where((z) => z.zoneId.toLowerCase() == id)
        .firstOrNull;
    return z == null ? '' : z.name;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final shown = _items.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: const Color(0xFFFCD34D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    size: 18,
                    color: Color(0xFFB45309),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Việc cần bạn xử lý (${_items.length})',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final p in shown)
              InkWell(
                onTap: () => showServiceRequestDetail(
                  context,
                  p.request,
                  onChanged: _load,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceTitle(p.request),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (_zoneName(p.request).isNotEmpty)
                                  _zoneName(p.request),
                                p.action,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Color(0xFF92400E),
                      ),
                    ],
                  ),
                ),
              ),
            if (_items.length > shown.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                child: Text(
                  'và ${_items.length - shown.length} việc khác trong "Yêu cầu & Hợp đồng"',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
