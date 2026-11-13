part of '../deployment_screens.dart';

// ════════════════════════════════════════════════════════════════════════
//  TECHNICIAN: danh sách yêu cầu
// ════════════════════════════════════════════════════════════════════════
class TechnicianDeploymentsScreen extends StatefulWidget {
  const TechnicianDeploymentsScreen({super.key});

  @override
  State<TechnicianDeploymentsScreen> createState() =>
      _TechnicianDeploymentsScreenState();
}

class _TechnicianDeploymentsScreenState
    extends State<TechnicianDeploymentsScreen> {
  List<DeploymentRequest> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await DeploymentApi.getTechnicianDeploymentRequests();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _appBar('Yêu cầu triển khai thiết bị'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Không tải được danh sách: $_error'),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              )
            : _items.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa có yêu cầu nào chờ tiếp nhận hoặc được giao cho bạn.',
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = _items[i];
                  return Card(
                    child: ListTile(
                      title: Text(
                        r.context == null
                            ? 'Yêu cầu ${r.requestId.substring(0, 8)} · cần đo ${r.requiredParameters.length} thông số'
                            : '${r.context!.zoneName} · ${r.context!.farmName}',
                      ),
                      subtitle: Text(
                        r.planItems
                            .map((p) => '${p.quantity}× ${p.modelName}')
                            .join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _statusChip(r.status),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeploymentRequestDetailScreen(
                              requestId: r.requestId,
                              technician: true,
                            ),
                          ),
                        );
                        _load();
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
