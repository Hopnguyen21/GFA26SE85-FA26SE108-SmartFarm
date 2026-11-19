part of '../deployment_screens.dart';

// ════════════════════════════════════════════════════════════════════════
//  OWNER: danh sách các yêu cầu triển khai IoT đã gửi (mọi Zone của Tenant)
//  Không tạo yêu cầu ở đây: yêu cầu luôn gắn với MỘT Zone nên được gửi từ chính Zone đó
//  (Zone → tab "Triển khai IoT" → xem thông tin & gửi yêu cầu), không phải chọn Zone lại.
// ════════════════════════════════════════════════════════════════════════
class OwnerDeploymentRequestsScreen extends StatefulWidget {
  const OwnerDeploymentRequestsScreen({super.key});

  @override
  State<OwnerDeploymentRequestsScreen> createState() =>
      _OwnerDeploymentRequestsScreenState();
}

class _OwnerDeploymentRequestsScreenState
    extends State<OwnerDeploymentRequestsScreen> {
  List<DeploymentRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _requests.isEmpty;
      _error = null;
    });
    try {
      final list = await DeploymentApi.getOwnerDeploymentRequests();
      if (mounted) setState(() => _requests = list);
    } catch (e) {
      // Lỗi tải được báo rõ, không hiện thành "chưa có yêu cầu nào".
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title(DeploymentRequest r) {
    final c = r.context;
    return c == null ? 'Yêu cầu lắp đặt IoT' : '${c.zoneName} · ${c.farmName}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _appBar(
        'Yêu cầu triển khai IoT',
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _requests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Không tải được danh sách yêu cầu: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _requests.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 40),
                        Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có yêu cầu triển khai nào.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Để gửi yêu cầu mới, mở Zone cần lắp thiết bị → tab "Triển khai IoT" → "Xem thông tin & gửi yêu cầu".',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    )
                  : PagedList<DeploymentRequest>(
                      padding: const EdgeInsets.all(16),
                      // yêu cầu không có ngày tạo riêng: lấy mốc quyết định đầu tiên trong lịch sử
                      items: sortNewestFirst(
                        _requests,
                        (r) => r.history.isEmpty
                            ? null
                            : parseTime(r.history.first.decidedAtUtc),
                      ),
                      itemGap: 10,
                      itemBuilder: (context, r) {
                        final total = r.estimateItems.fold<double>(
                          0,
                          (a, e) => a + e.lineTotal,
                        );
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DeploymentRequestDetailScreen(
                                          requestId: r.requestId,
                                          technician: false,
                                        ),
                                  ),
                                );
                                _load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFA7F3D0),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.sensors,
                                        color: Color(0xFF047857),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _title(r),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              'Cần đo ${r.requiredParameters.length} thông số',
                                              if (r.estimateItems.isNotEmpty)
                                                'dự toán ~${formatVnd(total)}',
                                            ].join(' · '),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusChip(r.status),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
