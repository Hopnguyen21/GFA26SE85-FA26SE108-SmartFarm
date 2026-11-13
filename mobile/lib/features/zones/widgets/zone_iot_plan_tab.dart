import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/iot_deployment.dart';
import '../../../core/providers/farm_provider.dart';
import '../../../core/services/api_service.dart';
import '../../devices/deployment_screens.dart';
import '../../crops/widgets/create_season_sheet.dart';
import '../../devices/deployment_request_send_screen.dart';
import 'zone_honeycomb_estimate_card.dart';

/// Tab "Triển khai IoT" của Zone, dữ liệu 100% từ backend:
/// - GET  /zones/{id}/iot-requirements       → nhu cầu đo theo cây/diện tích của Zone
/// - GET  /deployment-requests?zoneId=       → các yêu cầu triển khai đã gửi cho Zone này
/// Có thêm bảng dự toán (thuật toán Tổ ong, đơn giá từ backend); báo giá chính thức do kỹ thuật viên lập sau khảo sát.
class ZoneIotPlanTab extends StatefulWidget {
  final String zoneId;
  final String zoneName;
  final double areaM2;
  final String cropName;

  /// Chu vi bao lồi ranh giới Zone (m), null nếu Zone chưa vẽ ranh giới.
  final double? perimeterM;
  const ZoneIotPlanTab({
    super.key,
    required this.zoneId,
    required this.zoneName,
    this.areaM2 = 0,
    this.cropName = '',
    this.perimeterM,
  });

  @override
  State<ZoneIotPlanTab> createState() => _ZoneIotPlanTabState();
}

class _PlanData {
  final IotRequirements? requirements;
  final List<DeploymentRequest> requests;
  final bool needsActiveSeason;
  const _PlanData(
    this.requirements,
    this.requests, {
    this.needsActiveSeason = false,
  });
}

class _ZoneIotPlanTabState extends State<ZoneIotPlanTab> {
  late Future<_PlanData> _future = _load();
  int _reloadCount =
      0; // kéo để làm mới sẽ tải lại cả danh mục thiết bị/đơn giá của bảng dự toán

  @override
  void didUpdateWidget(covariant ZoneIotPlanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.zoneId != widget.zoneId) _future = _load();
  }

  Future<_PlanData> _load() async {
    // Only the owner view loads owner deployment requests. Technician requests use
    // TechnicianDeploymentsScreen; do not fire an unauthorized owner API call here.
    if (context.read<FarmProvider>().currentRole != 'OWNER') {
      return const _PlanData(null, []);
    }
    // Read existing requests independently. A Zone without an InProgress season is a normal
    // setup state, not a reason to discard its deployment history or leak an async exception.
    final results = await Future.wait<Object?>([
      DeploymentApi.getIotRequirements(
        widget.zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
      DeploymentApi.getOwnerDeploymentRequests(
        zoneId: widget.zoneId,
      ).then<Object?>((v) => v).catchError((Object e) => e),
    ]);
    final requirements = results[0];
    final requests = results[1];
    if (requests is! List<DeploymentRequest>) {
      if (requests is Object) throw requests;
      throw Exception('Không tải được yêu cầu triển khai của Zone.');
    }
    if (requirements is Exception) {
      final message = requirements.toString().toLowerCase();
      if (message.contains('no inprogress planting season') ||
          message.contains('no in-progress planting season')) {
        return _PlanData(null, requests, needsActiveSeason: true);
      }
      throw requirements;
    }
    if (requirements is! IotRequirements) {
      throw Exception('Máy chủ trả về nhu cầu đo của Zone không hợp lệ.');
    }
    return _PlanData(requirements, requests);
  }

  Future<void> _reload() async {
    final f = _load();
    setState(() {
      _future = f;
      _reloadCount++;
    });
    try {
      await f;
    } catch (_) {
      // Lỗi được hiển thị bởi FutureBuilder.
    }
  }

  Future<void> _createSeasonForThisZone() async {
    final provider = context.read<FarmProvider>();
    final zone = provider.allZones
        .where((z) => z.zoneId == widget.zoneId)
        .firstOrNull;
    if (zone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy Zone này. Hãy tải lại danh sách Zone.'),
        ),
      );
      return;
    }
    final created = await showCreateSeasonSheet(context, zone);
    if (created != true || !mounted) return;
    await context.read<FarmProvider>().fetchFromApi();
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã tạo vụ trồng. Nhu cầu và đề xuất thiết bị đang được cập nhật.',
        ),
      ),
    );
  }

  static const _statusLabel = {
    'Draft': 'Bản nháp',
    'Submitted': 'Đã gửi',
    'Accepted': 'Đã tiếp nhận',
    'Surveying': 'Đang khảo sát',
    'Surveyed': 'Đã khảo sát',
    'PlanConfirmed': 'Đã chốt kế hoạch',
    'Installing': 'Đang lắp đặt',
    'Completed': 'Hoàn tất',
    'Failed': 'Thất bại',
    'Cancelled': 'Đã hủy',
  };

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.8,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final role = context.watch<FarmProvider>().currentRole;
    if (role == 'FARMER') {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Kế hoạch lắp đặt thiết bị IoT do chủ trang trại và kỹ thuật viên thực hiện.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    final isOwner = role == 'OWNER';
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isOwner)
            FutureBuilder<_PlanData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return _card(
                    Column(
                      children: [
                        Text(
                          'Không tải được kế hoạch IoT: ${snap.error.toString().replaceFirst('Exception: ', '')}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                final d = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.areaM2 > 0)
                      ZoneHoneycombEstimateCard(
                        key: ValueKey('${widget.zoneId}-$_reloadCount'),
                        zoneId: widget.zoneId,
                        perimeterM: widget.perimeterM,
                        areaM2: widget.areaM2,
                        cropName: widget.cropName,
                        measurementParameters:
                            d.requirements?.parameters ?? const [],
                        measurementSource: d.needsActiveSeason
                            ? 'Zone chưa có mùa vụ đang canh tác'
                            : 'Thông số áp dụng của mùa vụ đang canh tác trong Zone',
                      ),
                    _title('NHU CẦU ĐO CỦA ZONE'),
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (d.needsActiveSeason)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Zone chưa có vụ trồng đang canh tác (InProgress), nên chưa xác định được nhu cầu đo và thiết bị phù hợp. Hãy tạo hoặc kích hoạt mùa vụ trước.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            Text(
                              'Diện tích: ${d.requirements!.zoneAreaM2.toStringAsFixed(0)} m²',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (d.requirements!.parameters.isEmpty)
                              const Text(
                                'Vụ trồng hiện tại chưa có thông số môi trường áp dụng.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final p in d.requirements!.parameters)
                                    Chip(
                                      label: Text(
                                        measurementLabel(p),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                          ],
                        ],
                      ),
                    ),
                    _title('YÊU CẦU TRIỂN KHAI ĐÃ GỬI (${d.requests.length})'),
                    if (d.requests.isEmpty)
                      _card(
                        const Text(
                          'Chưa có yêu cầu triển khai nào cho Zone này.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    for (final r in d.requests)
                      _card(
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _statusLabel[r.status] ?? r.status,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${r.planItems.fold<int>(0, (s, i) => s + i.quantity)} thiết bị trong kế hoạch'
                            '${(r.ownerNotes ?? '').isEmpty ? '' : '\n${r.ownerNotes}'}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeploymentRequestDetailScreen(
                                  requestId: r.requestId,
                                  technician: false,
                                ),
                              ),
                            );
                            if (mounted) _reload();
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          FutureBuilder<_PlanData>(
            future: _future,
            builder: (context, snapshot) {
              final needsSeason = snapshot.data?.needsActiveSeason == true;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: needsSeason
                      ? _createSeasonForThisZone
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isOwner
                                  ? DeploymentRequestSendScreen(
                                      zoneId: widget.zoneId,
                                    )
                                  : const TechnicianDeploymentsScreen(),
                            ),
                          );
                          if (mounted && isOwner) _reload();
                        },
                  icon: Icon(
                    needsSeason ? Icons.add_circle_outline : Icons.send_rounded,
                    size: 18,
                  ),
                  label: Text(
                    needsSeason
                        ? 'Tạo vụ trồng để lập yêu cầu thiết bị'
                        : isOwner
                        ? 'Xem thông tin & gửi yêu cầu triển khai IoT'
                        : 'Xem yêu cầu triển khai được giao',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
