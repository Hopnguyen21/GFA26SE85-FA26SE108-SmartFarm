import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../contracts/zone_contract_forms.dart';
import '../../support/support_requests_screen.dart';
import '../../../core/utils/user_error.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Hợp đồng thuê CỦA ZONE đang mở (GET /zones/{zoneId}/contracts), không phải toàn bộ hợp đồng của Farm. Có lọc phòng thủ theo
/// `zoneId`. Owner xem hợp đồng và chuyển sang yêu cầu hỗ trợ để lập hợp đồng qua kỹ thuật viên. Farmer không có quyền xem hợp đồng nên không hiển thị phần này.
class ZoneContractsSection extends StatefulWidget {
  final ZoneModel zone;
  final bool canManage;
  const ZoneContractsSection({
    super.key,
    required this.zone,
    required this.canManage,
  });

  @override
  State<ZoneContractsSection> createState() => _ZoneContractsSectionState();
}

class _ZoneContractsSectionState extends State<ZoneContractsSection> {
  bool _loading = true;
  String? _error;
  List<ZoneContractModel> _contracts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ZoneContractsSection old) {
    super.didUpdateWidget(old);
    if (old.zone.zoneId != widget.zone.zoneId) _load();
  }

  Future<void> _load() async {
    final zoneId = widget.zone.zoneId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await ContractApi.getZoneContracts(zoneId: zoneId);
      if (!mounted || widget.zone.zoneId != zoneId) return;
      setState(() {
        _contracts = [
          for (final c in all)
            if (c.zoneId.toLowerCase() == zoneId.toLowerCase()) c,
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportRequestsScreen(zone: widget.zone),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                size: 16,
                color: Color(0xFF047857),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'HỢP ĐỒNG CỦA ZONE NÀY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF047857),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tải lại',
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Không tải được hợp đồng: $_error',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            )
          else if (_contracts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Zone chưa có hợp đồng. Hãy gửi yêu cầu để kỹ thuật viên khảo sát, lập báo giá và hợp đồng cho Owner xem, ký xác nhận.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            )
          else
            for (final c in _contracts)
              InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ZoneContractDetailScreen(
                        contract: c,
                        canRenew: false,
                      ),
                    ),
                  );
                  if (mounted) await _load();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.contractNumber.isEmpty
                                  ? 'Hợp đồng'
                                  : c.contractNumber,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c.startDate.isEmpty ? '—' : c.startDate} → ${c.endDate.isEmpty ? '—' : c.endDate}'
                              '${c.lesseeName.isEmpty ? '' : ' · ${c.lesseeName}'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          c.statusText.isEmpty ? c.status : c.statusText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: _muted),
                    ],
                  ),
                ),
              ),
          if (widget.canManage)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF047857),
                    side: const BorderSide(color: Color(0xFF047857)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  onPressed: _loading ? null : _create,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Gửi yêu cầu hỗ trợ kỹ thuật'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
