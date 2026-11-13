part of '../deployment_screens.dart';

// ════════════════════════════════════════════════════════════════════════
//  TECHNICIAN: bảng việc (danh sách yêu cầu có tóm tắt, lọc, tìm kiếm, mức khẩn)
// ════════════════════════════════════════════════════════════════════════
class TechnicianDeploymentsScreen extends StatefulWidget {
  /// [embedded]: chỉ vẽ nội dung (không Scaffold/AppBar) để đặt trong tab của màn Dịch vụ.
  final bool embedded;
  const TechnicianDeploymentsScreen({super.key, this.embedded = false});

  @override
  State<TechnicianDeploymentsScreen> createState() =>
      _TechnicianDeploymentsScreenState();
}

class _TechnicianDeploymentsScreenState
    extends State<TechnicianDeploymentsScreen> {
  List<DeploymentRequest> _items = [];
  bool _loading = true;
  String? _error;
  BoardGroup? _group;
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _group = null;
      _query = '';
    });
  }

  Future<void> _open(DeploymentRequest r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeploymentRequestDetailScreen(
          requestId: r.requestId,
          technician: true,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(color: AppColors.surfaceMuted, child: _body());
    }
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: _appBar(
        'Công việc triển khai',
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const AppLoading(message: 'Đang tải yêu cầu...');
    }
    if (_error != null && _items.isEmpty) {
      return PullToRefresh(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            AppErrorState(
              message: 'Không tải được danh sách: $_error',
              onRetry: _load,
            ),
          ],
        ),
      );
    }

    final counts = boardCounts(_items);
    final visible = boardView(_items, group: _group, query: _query);
    final total = _items.where((r) => r.status != 'Draft').length;
    final filtering = _group != null || _query.trim().isNotEmpty;

    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_error != null) _errorBanner(),
          _summary(counts),
          const SizedBox(height: AppSpacing.md),
          _searchField(),
          if (filtering && total > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hiển thị ${visible.length}/$total yêu cầu'
                      '${_group == null ? '' : ' · ${_group!.label}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Bỏ lọc'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon: Icons.assignment_outlined,
                message:
                    'Chưa có yêu cầu nào chờ tiếp nhận hoặc được giao cho bạn.\nKéo xuống để làm mới.',
              ),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon: Icons.search_off_outlined,
                message: 'Không có yêu cầu phù hợp với bộ lọc.',
                actionLabel: 'Bỏ lọc',
                onAction: _clearFilters,
              ),
            )
          else
            for (final r in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _RequestCard(request: r, onTap: () => _open(r)),
              ),
        ],
      ),
    );
  }

  Widget _errorBanner() => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(AppSpacing.radius),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 18, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Chưa làm mới được: $_error',
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _summary(Map<BoardGroup, int> counts) {
    Color colorOf(BoardGroup g) => switch (g) {
      BoardGroup.waiting => AppColors.warning,
      BoardGroup.active => AppColors.info,
      BoardGroup.maintenance => AppColors.danger,
      BoardGroup.done => AppColors.primaryDark,
    };
    IconData iconOf(BoardGroup g) => switch (g) {
      BoardGroup.waiting => Icons.inbox_outlined,
      BoardGroup.active => Icons.handyman_outlined,
      BoardGroup.maintenance => Icons.build_circle_outlined,
      BoardGroup.done => Icons.verified_outlined,
    };
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final g in BoardGroup.values)
              SizedBox(
                width: w,
                child: SummaryTile(
                  label: g.label,
                  count: counts[g] ?? 0,
                  color: colorOf(g),
                  icon: iconOf(g),
                  selected: _group == g,
                  onTap: () => setState(() => _group = _group == g ? null : g),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _searchField() => TextField(
    controller: _search,
    textInputAction: TextInputAction.search,
    onChanged: (v) => setState(() => _query = v),
    decoration: InputDecoration(
      hintText: 'Tìm theo Zone, trang trại, địa điểm, cây...',
      prefixIcon: const Icon(Icons.search, size: 20),
      suffixIcon: _query.isEmpty
          ? null
          : IconButton(
              tooltip: 'Xóa tìm kiếm',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}

/// Thẻ yêu cầu triển khai dùng lại ở tab "Công việc" cho các đợt chưa có phiếu dịch vụ.
class DeploymentRequestCard extends StatelessWidget {
  final DeploymentRequest request;
  final VoidCallback onTap;
  const DeploymentRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      _RequestCard(request: request, onTap: onTap);
}

/// Thẻ một yêu cầu: nơi lắp đặt, trạng thái, việc tiếp theo, kế hoạch thiết bị và tiến trình.
class _RequestCard extends StatelessWidget {
  final DeploymentRequest request;
  final VoidCallback onTap;
  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final c = r.context;
    final id = r.requestId;
    final title = c == null
        ? 'Yêu cầu ${id.length > 8 ? id.substring(0, 8) : id}'
        : '${c.zoneName} · ${c.farmName}';
    final where = c == null
        ? null
        : [
            c.fieldName,
            if (c.farmLocation != null && c.farmLocation!.isNotEmpty)
              c.farmLocation,
          ].whereType<String>().join(' · ');
    final detail = c == null
        ? 'Cần đo ${r.requiredParameters.length} thông số'
        : [
            '${c.zoneAreaM2.toStringAsFixed(0)} m²',
            if (c.cropName != null && c.cropName!.isNotEmpty) c.cropName,
          ].whereType<String>().join(' · ');
    final plan = r.planItems.isEmpty
        ? 'Chưa có kế hoạch thiết bị'
        : r.planItems.map((p) => '${p.quantity}× ${p.modelName}').join(', ');
    final hint = deploymentNextStepHint(r.status);
    final failed = r.status == 'MaintenanceRequired';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: _statusChip(r.status),
              ),
              if (where != null && where.isNotEmpty) ...[
                const SizedBox(height: 8),
                _line(Icons.place_outlined, where),
              ],
              const SizedBox(height: 4),
              _line(Icons.crop_square_outlined, detail),
              const SizedBox(height: 4),
              _line(Icons.devices_other_outlined, plan),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: failed ? AppColors.danger : AppColors.info,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: failed ? AppColors.danger : AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              DeploymentProgressBar(status: r.status, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: AppColors.textFaint),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}
