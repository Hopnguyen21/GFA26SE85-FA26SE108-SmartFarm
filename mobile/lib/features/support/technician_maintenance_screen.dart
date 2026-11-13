import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/models/models.dart' show ZoneModel;
import '../../core/models/iot_deployment.dart' show deploymentStatusLabels;
import '../devices/widgets/deployment_progress_bar.dart'
    show deploymentStatusColor;
import 'quotation_editor.dart' show formatMoney;
import '../../core/services/api_service.dart';
import '../../core/services/app_role.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/summary_tile.dart';
import '../devices/deployment_screens.dart' show DeploymentRequestDetailScreen;
import '../devices/widgets/install_progress_card.dart';
import 'node_placement_logic.dart';
import 'node_placement_screen.dart';
import 'placed_nodes_screen.dart';
import 'install_flow_stepper.dart';
import 'support_requests_screen.dart' show QuotationPanel;
import 'service_board_logic.dart';

const Map<String, String> serviceStatusLabels = {
  'Open': 'Mới tạo',
  'Assigned': 'Đã giao',
  'InProgress': 'Đang xử lý',
  'Diagnosed': 'Đã chẩn đoán',
  'WorkCompleted': 'Đã sửa/thay xong',
  'Verified': 'Đã kiểm tra kết nối',
  'Resolved': 'Đã giải quyết',
  'Closed': 'Đã đóng',
};
const _statusByIndex = [
  'Open',
  'Assigned',
  'InProgress',
  'Diagnosed',
  'WorkCompleted',
  'Verified',
  'Resolved',
  'Closed',
];
const _resolutionByIndex = ['Maintenance', 'Repair', 'Replacement'];

/// Màu nhãn trạng thái yêu cầu bảo trì: việc chờ nhận (vàng), đang làm (xanh dương), đã xong việc (xanh lá), đã đóng (xám).
Color serviceStatusColor(String status) => switch (status) {
  'Open' || 'Assigned' => AppColors.warning,
  'InProgress' || 'Diagnosed' => AppColors.info,
  'WorkCompleted' || 'Verified' => AppColors.primaryDark,
  _ => AppColors.textMuted,
};
const Map<String, String> resolutionLabels = {
  'Maintenance': 'Bảo trì',
  'Repair': 'Sửa chữa',
  'Replacement': 'Thay thế thiết bị',
};

/// Backend có thể trả enum dạng chuỗi hoặc số; chuẩn hoá về tên.
String enumName(dynamic v, List<String> byIndex) {
  if (v is int && v >= 0 && v < byIndex.length) return byIndex[v];
  return '${v ?? ''}';
}

String serviceStatusOf(Map<String, dynamic> r) =>
    enumName(r['status'], _statusByIndex);
String resolutionOf(Map<String, dynamic> r) =>
    enumName(r['resolutionAction'], _resolutionByIndex);

/// Danh sách yêu cầu dịch vụ được giao cho Kỹ thuật viên: lắp đặt mới và bảo trì/sửa chữa (backend lọc theo người dùng).
/// Có ô tóm tắt, lọc, tìm kiếm, sắp theo mức khẩn; với yêu cầu lắp đặt còn hiện giai đoạn báo giá/hợp đồng và số node đã chấm.
class TechnicianMaintenanceScreen extends StatefulWidget {
  /// [embedded]: chỉ vẽ nội dung (không Scaffold/AppBar) để đặt trong tab của màn Dịch vụ.
  final bool embedded;
  const TechnicianMaintenanceScreen({super.key, this.embedded = false});

  @override
  State<TechnicianMaintenanceScreen> createState() =>
      _TechnicianMaintenanceScreenState();
}

class _TechnicianMaintenanceScreenState
    extends State<TechnicianMaintenanceScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  ServiceFilter? _filter;
  final _search = TextEditingController();
  String _query = '';
  // Tải thêm cho yêu cầu lắp đặt chưa đóng. Chỉ hiện khi đã tải được: không điền số giả khi thiếu dữ liệu.
  final Map<String, int> _nodesByZone = {};
  final Map<String, String?> _quoteStatusById = {};
  final Map<String, double> _quoteTotalById = {};
  final Map<String, String> _depStatusById =
      {}; // chỉ khi liên kết đúng Farm/Zone

  bool get _isTech =>
      parseAppRole(ApiService.userRole) == AppRole.platformTechnician;

  @override
  void initState() {
    super.initState();
    if (_isTech) _load();
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
      final list = await SupportApi.getServiceRequests();
      if (mounted) setState(() => _items = list);
      unawaited(_loadExtras(list));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Số node đã chấm theo Zone và trạng thái báo giá cho các yêu cầu lắp đặt chưa đóng. Lỗi từng mục bị bỏ qua (mục đó không hiện).
  Future<void> _loadExtras(List<Map<String, dynamic>> items) async {
    final installs = [
      for (final r in items)
        if (serviceKindOf(r) == ServiceKind.installation &&
            !isClosedStatus(serviceStatusOf(r)))
          r,
    ];
    final zoneIds = {
      for (final r in installs)
        if ('${r['zoneId'] ?? ''}'.isNotEmpty) '${r['zoneId']}',
    };
    Future<void> nodes(String zoneId) async {
      try {
        final locs = await FarmApi.getDeviceMapLocations(zoneId);
        _nodesByZone[zoneId] = locs.length;
      } catch (_) {}
    }

    Future<void> quote(String id) async {
      try {
        final q = await SupportApi.getQuotation(id);
        _quoteStatusById[id] = q?.status;
        if (q != null) _quoteTotalById[id] = q.totalAmount;
      } catch (_) {}
    }

    // Trạng thái triển khai gắn kèm, chỉ nhận khi cùng Farm/Zone với phiếu (giống cảnh báo liên kết sai trên web).
    Future<void> deployment(Map<String, dynamic> r) async {
      final depId = '${r['deploymentRequestId'] ?? ''}';
      if (depId.isEmpty || depId.startsWith('00000000-')) return;
      try {
        final d = await DeploymentApi.getDeploymentRequest(
          depId,
          technician: true,
        );
        if (d.farmId == '${r['farmId'] ?? ''}' &&
            d.zoneId == '${r['zoneId'] ?? ''}') {
          _depStatusById['${r['id']}'] = d.status;
        }
      } catch (_) {}
    }

    await Future.wait([
      for (final z in zoneIds) nodes(z),
      for (final r in installs)
        if ('${r['id'] ?? ''}'.isNotEmpty) quote('${r['id']}'),
      for (final r in installs)
        if ('${r['id'] ?? ''}'.isNotEmpty) deployment(r),
    ]);
    if (mounted) setState(() {});
  }

  FarmProvider? _providerOrNull() {
    try {
      return Provider.of<FarmProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  /// "Zone · Trang trại" nếu tìm được (kỹ thuật viên chỉ có Zone của trang trại được giao); không có thì null.
  String? _whereOf(Map<String, dynamic> r) {
    final zoneId = '${r['zoneId'] ?? ''}'.toLowerCase();
    if (zoneId.isEmpty) return null;
    final p = _providerOrNull();
    final zone = p?.allZones
        .where((z) => z.zoneId.toLowerCase() == zoneId)
        .firstOrNull;
    if (zone == null) return null;
    return [
      zone.name,
      zone.farmName,
    ].where((s) => s.trim().isNotEmpty).join(' · ');
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _filter = null;
      _query = '';
    });
  }

  Future<void> _open(Map<String, dynamic> r) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceRequestDetailScreen(requestId: '${r['id']}'),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTech) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yêu cầu dịch vụ')),
        body: const Center(child: Text('Chức năng dành cho Kỹ thuật viên.')),
      );
    }
    if (widget.embedded) {
      return ColoredBox(color: AppColors.surfaceMuted, child: _body());
    }
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        title: const Text('Yêu cầu dịch vụ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
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
            AppErrorState(message: _error!, onRetry: _load),
          ],
        ),
      );
    }

    final counts = serviceCounts(_items, serviceStatusOf);
    final visible = serviceView(
      _items,
      statusOf: serviceStatusOf,
      filter: _filter,
      query: _query,
      nameOf: (r) => _whereOf(r) ?? '',
    );
    final filtering = _filter != null || _query.trim().isNotEmpty;

    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_error != null) _errorBanner(),
          _summary(counts),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo mô tả, mã lỗi, Zone, trang trại...',
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
          ),
          if (filtering && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hiển thị ${visible.length}/${_items.length} yêu cầu'
                      '${_filter == null ? '' : ' · ${_filter!.label}'}',
                      style: const TextStyle(
                        fontSize: 13,
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
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon: Icons.build_circle_outlined,
                message:
                    'Chưa có công việc lắp đặt hoặc bảo trì nào được giao.\nKéo xuống để làm mới.',
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
                child: _card(r),
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
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ),
        TextButton(onPressed: _load, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _summary(Map<ServiceFilter, int> counts) {
    Color colorOf(ServiceFilter f) => switch (f) {
      ServiceFilter.installation => AppColors.info,
      ServiceFilter.maintenance => AppColors.warning,
      ServiceFilter.ready => AppColors.primaryDark,
      ServiceFilter.closed => AppColors.textMuted,
    };
    IconData iconOf(ServiceFilter f) => switch (f) {
      ServiceFilter.installation => Icons.bolt_outlined,
      ServiceFilter.maintenance => Icons.build_outlined,
      ServiceFilter.ready => Icons.task_alt_outlined,
      ServiceFilter.closed => Icons.lock_outline,
    };
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final f in ServiceFilter.values)
              SizedBox(
                width: w,
                child: SummaryTile(
                  label: f.label,
                  count: counts[f] ?? 0,
                  color: colorOf(f),
                  icon: iconOf(f),
                  selected: _filter == f,
                  onTap: () =>
                      setState(() => _filter = _filter == f ? null : f),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _badge(String text, Color color, {bool mono = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: color,
        fontFamily: mono ? 'monospace' : null,
      ),
    ),
  );

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
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
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );

  /// Ngày tạo lấy từ mục lịch sử đầu tiên (API phiếu không trả ngày tạo riêng); không có thì không hiện.
  String? _createdDate(Map<String, dynamic> r) {
    final h = r['history'];
    if (h is! List || h.isEmpty || h.first is! Map) return null;
    final t = '${(h.first as Map)['createdAtUtc'] ?? ''}';
    if (t.length < 10) return null;
    final p = t.substring(0, 10).split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : null;
  }

  Widget _card(Map<String, dynamic> r) {
    final status = serviceStatusOf(r);
    final kind = serviceKindOf(r);
    final installation = kind == ServiceKind.installation;
    final title = serviceTitle(r);
    final desc = '${r['description'] ?? ''}'.trim();
    final where = _whereOf(r);
    final id = '${r['id'] ?? ''}';
    final nodes = _nodesByZone['${r['zoneId'] ?? ''}'];
    final closed = isClosedStatus(status);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(r),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: serviceStatusColor(status), width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(
                      installation ? 'Lắp đặt mới' : 'Bảo trì / sửa chữa',
                      installation ? AppColors.info : AppColors.warning,
                    ),
                    _badge(
                      serviceStatusLabels[status] ?? status,
                      serviceStatusColor(status),
                    ),
                    if (installation && _depStatusById.containsKey(id))
                      _badge(
                        'Triển khai: ${deploymentStatusLabels[_depStatusById[id]] ?? _depStatusById[id]}',
                        deploymentStatusColor(_depStatusById[id]!),
                      ),
                    if (installation &&
                        !closed &&
                        _quoteStatusById.containsKey(id))
                      _badge(
                        contractStageLabel(_quoteStatusById[id]),
                        _stageColor(_quoteStatusById[id]),
                      ),
                    if (!installation && '${r['failureCode'] ?? ''}'.isNotEmpty)
                      _badge(
                        '${r['failureCode']}',
                        AppColors.textMuted,
                        mono: true,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                if (where != null) _line(Icons.place_outlined, where),
                if (desc.isNotEmpty && desc != '$title.' && desc != title)
                  _line(Icons.notes_outlined, desc),
                if (installation && !closed && nodes != null)
                  _line(
                    Icons.sensors_outlined,
                    '$nodes node đã chấm trên bản đồ',
                  ),
                if (installation && _quoteTotalById[id] != null)
                  _line(
                    Icons.payments_outlined,
                    'Tổng HĐ: ${formatMoney(_quoteTotalById[id]!)}',
                  ),
                if (_createdDate(r) != null)
                  _line(Icons.event_outlined, 'Ngày tạo: ${_createdDate(r)}'),
                // Chỉ hiện khi đã đọc được CẢ báo giá và triển khai gắn đúng Farm/Zone; thiếu dữ liệu thì không đoán bước.
                if (installation &&
                    (closed ||
                        (_quoteStatusById.containsKey(id) &&
                            _depStatusById.containsKey(id))))
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.infoSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Việc tiếp theo: ${installNextAction(serviceStatus: status, quotationStatus: _quoteStatusById[id], deploymentStatus: _depStatusById[id], closed: closed)}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.info,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ServiceRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const ServiceRequestDetailScreen({super.key, required this.requestId});

  @override
  State<ServiceRequestDetailScreen> createState() =>
      _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState
    extends State<ServiceRequestDetailScreen> {
  Map<String, dynamic>? _req;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String?
  _depStatus; // trạng thái triển khai gắn kèm (null: chưa đọc được hoặc liên kết sai)
  String? _quoteStatus; // trạng thái báo giá (null: chưa có hoặc chưa tải được)
  bool _quoteKnown = false;
  int? _nodes; // số node đã chấm trên bản đồ của Zone (null: không tải được)

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
      final r = await SupportApi.getServiceRequest(widget.requestId);
      if (mounted) setState(() => _req = r);
      unawaited(_loadExtras(r));
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Báo giá và số node đã chấm cho phiếu lắp đặt (phục vụ phần đầu trang); lỗi thì bỏ qua, không điền số giả.
  Future<void> _loadExtras(Map<String, dynamic> r) async {
    if (serviceKindOf(r) != ServiceKind.installation) return;
    // Dữ liệu cọc cũ không được giữ lại khi tải lại: khoá cho tới khi backend xác nhận lại (lỗi tải = vẫn khoá).
    if (mounted) {
      setState(() {
        _quoteStatus = null;
        _quoteKnown = false;
      });
    }
    final zoneId = '${r['zoneId'] ?? ''}';
    String? quote;
    var known = false;
    int? nodes;
    await Future.wait([
      () async {
        try {
          quote = (await SupportApi.getQuotation(widget.requestId))?.status;
          known = true;
        } catch (_) {}
      }(),
      () async {
        if (zoneId.isEmpty) return;
        try {
          nodes = (await FarmApi.getDeviceMapLocations(zoneId)).length;
        } catch (_) {}
      }(),
    ]);
    if (!mounted) return;
    setState(() {
      _quoteStatus = quote;
      _quoteKnown = known;
      _nodes = nodes;
    });
  }

  /// Zone của phiếu trong danh sách đã tải (null nếu không tìm được, ví dụ Zone ngoài phạm vi được giao).
  ZoneModel? _zoneOf(Map<String, dynamic> r) {
    final zoneId = '${r['zoneId'] ?? ''}'.toLowerCase();
    if (zoneId.isEmpty) return null;
    try {
      return Provider.of<FarmProvider>(
        context,
        listen: false,
      ).allZones.where((z) => z.zoneId.toLowerCase() == zoneId).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  bool get _depositPaid => const {
    'SignedByOwner',
    'DepositPaid',
    'Completed',
  }.contains(_quoteStatus);

  /// Cổng "Gắn Node" dùng chung (thẻ, chi tiết, điều hướng, màn Gắn Node): chỉ theo hợp đồng/cọc do backend xác nhận,
  /// phiếu và triển khai chưa kết thúc, triển khai gắn đúng Farm/Zone. Không phụ thuộc Xác nhận kế hoạch/Đang lắp đặt.
  NodePlacementGate _gate(
    Map<String, dynamic> r, {
    String? quotationStatus,
    bool? quotationLoaded,
  }) {
    final depId = '${r['deploymentRequestId'] ?? ''}';
    return checkNodePlacement(
      serviceStatus: serviceStatusOf(r),
      quotationLoaded: quotationLoaded ?? _quoteKnown,
      quotationStatus: quotationStatus ?? _quoteStatus,
      deploymentStatus: _depStatus,
      linkValid:
          _depStatus != null &&
          depId.isNotEmpty &&
          !depId.startsWith('00000000-0000-0000-'),
    );
  }

  /// Mở màn Gắn Node trên bản đồ GIS của Zone. Trước khi mở đọc LẠI hợp đồng/cọc từ backend: đọc lỗi thì không mở
  /// (không dùng quyền cũ). Sau khi quay về tải lại toàn bộ, không tự đẩy trạng thái triển khai nào.
  Future<void> _openNodes(Map<String, dynamic> r) async {
    String? freshStatus;
    var fresh = false;
    try {
      freshStatus = (await SupportApi.getQuotation(widget.requestId))?.status;
      fresh = true;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _quoteStatus = freshStatus;
      _quoteKnown = fresh;
    });
    final gate = _gate(r, quotationStatus: freshStatus, quotationLoaded: fresh);
    if (!gate.allowed) {
      _snack(gate.message);
      return;
    }
    final zoneId = '${r['zoneId'] ?? ''}';
    final dep = '${r['deploymentRequestId'] ?? ''}';
    if (zoneId.isEmpty || dep.isEmpty) {
      _snack(
        'Phiếu chưa gắn Zone hoặc yêu cầu triển khai nên chưa gắn Node được.',
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NodePlacementScreen(
          serviceRequestId: widget.requestId,
          farmId: '${r['farmId'] ?? _zoneOf(r)?.farmId ?? ''}',
          zoneId: zoneId,
          deploymentRequestId: dep,
          zone: _zoneOf(r),
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// Nút trong khung "Thao tác thực địa kỹ thuật": "Gắn Node" khi cổng cho phép; chưa đủ điều kiện thì chip khoá nêu đúng
  /// lý do; công việc đã kết thúc thì không có nút nào.
  List<Widget> _fieldButtons(Map<String, dynamic> r) {
    final gate = _gate(r);
    final finished =
        gate.block == NodePlacementBlock.serviceFinished ||
        gate.block == NodePlacementBlock.deploymentFinished;
    return [
      if (gate.allowed)
        FilledButton.icon(
          onPressed: () => _openNodes(r),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0369A1),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.my_location, size: 18),
          label: Text(
            _nodes == null ? 'Gắn Node' : 'Gắn Node ($_nodes đã có vị trí)',
          ),
        )
      else if (!finished)
        Chip(
          backgroundColor: const Color(0xFF1E293B),
          side: const BorderSide(color: Color(0xFFB45309)),
          avatar: const Icon(
            Icons.lock_outline,
            size: 16,
            color: Color(0xFFFBBF24),
          ),
          label: Text(
            gate.block == NodePlacementBlock.unpaid
                ? 'Chờ Owner ký & cọc 30% mới gắn Node'
                : gate.message,
            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13),
          ),
        ),
      // Xem Node đã chấm và tình trạng: chỉ xem nên dùng được ở mọi giai đoạn, kể cả khi đã hoàn tất.
      OutlinedButton.icon(
        onPressed: () => _openPlacedNodes(r),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFF64748B)),
        ),
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: const Text('Xem Node'),
      ),
    ];
  }

  /// Mở màn xem các Node đã chấm trong Zone của phiếu và tình trạng của chúng (chỉ xem).
  Future<void> _openPlacedNodes(Map<String, dynamic> r) async {
    final zoneId = '${r['zoneId'] ?? ''}';
    if (zoneId.isEmpty) {
      _snack('Phiếu chưa gắn Zone nên chưa xem được Node.');
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacedNodesScreen(
          zoneId: zoneId,
          farmId: '${r['farmId'] ?? _zoneOf(r)?.farmId ?? ''}',
          zone: _zoneOf(r),
        ),
      ),
    );
  }

  /// "Zone · Trang trại" nếu tìm được trong danh sách đã tải; không có thì null.
  String? _where(Map<String, dynamic> r) {
    final zoneId = '${r['zoneId'] ?? ''}'.toLowerCase();
    if (zoneId.isEmpty) return null;
    try {
      final zone = Provider.of<FarmProvider>(
        context,
        listen: false,
      ).allZones.where((z) => z.zoneId.toLowerCase() == zoneId).firstOrNull;
      if (zone == null) return null;
      return [
        zone.name,
        zone.farmName,
      ].where((s) => s.trim().isNotEmpty).join(' · ');
    } catch (_) {
      return null;
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(
    Future<Map<String, dynamic>> Function() call,
    String okMsg,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await call();
      if (!mounted) return;
      setState(() => _req = r);
      _snack(okMsg);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _form(
    String title,
    List<(String key, String label, bool required)> fields,
  ) async {
    final ctrls = {for (final f in fields) f.$1: TextEditingController()};
    String? err;
    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in fields)
                  TextField(
                    controller: ctrls[f.$1],
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(labelText: f.$2),
                  ),
                if (err != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      err!,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                for (final f in fields) {
                  if (f.$3 && ctrls[f.$1]!.text.trim().isEmpty) {
                    setLocal(() => err = 'Vui lòng nhập: ${f.$2}');
                    return;
                  }
                }
                Navigator.pop(ctx, {
                  for (final e in ctrls.entries) e.key: e.value.text.trim(),
                });
              },
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
    return res;
  }

  Future<void> _diagnose() async {
    final v = await _form('Chẩn đoán sự cố', [
      ('notes', 'Ghi chú kiểm tra', true),
      ('diag', 'Kết luận chẩn đoán', true),
    ]);
    if (v == null || !mounted) return;
    var action = 'Repair';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Hướng xử lý'),
          content: DropdownButtonFormField<String>(
            initialValue: action,
            items: [
              for (final e in resolutionLabels.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (x) => setLocal(() => action = x ?? action),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => SupportApi.serviceRequestAction(widget.requestId, 'diagnosis', {
        'inspectionNotes': v['notes'],
        'diagnosis': v['diag'],
        'resolutionAction': action,
      }),
      'Đã ghi nhận chẩn đoán.',
    );
  }

  Future<void> _recordWork() async {
    final v = await _form('Ghi nhận kết quả sửa chữa', [
      ('work', 'Công việc đã thực hiện', true),
    ]);
    if (v == null) return;
    await _run(
      () => SupportApi.serviceRequestAction(widget.requestId, 'work', {
        'workPerformed': v['work'],
      }),
      'Đã ghi nhận công việc.',
    );
  }

  Future<void> _connectionTest() async {
    var succeeded = true;
    final rssi = TextEditingController();
    final latency = TextEditingController();
    final errCode = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Kết quả kiểm tra kết nối'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập kết quả bạn quan sát được trên thiết bị. App không tự suy ra kết nối thành công.',
                  style: TextStyle(fontSize: 13),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kết nối thành công'),
                  value: succeeded,
                  onChanged: (x) => setLocal(() => succeeded = x),
                ),
                TextField(
                  controller: rssi,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'RSSI (tuỳ chọn)',
                  ),
                ),
                TextField(
                  controller: latency,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Độ trễ ms (tuỳ chọn)',
                  ),
                ),
                if (!succeeded)
                  TextField(
                    controller: errCode,
                    decoration: const InputDecoration(labelText: 'Mã lỗi'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
    final body = <String, dynamic>{
      'succeeded': succeeded,
      'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
      if (num.tryParse(rssi.text.trim()) != null)
        'rssi': num.parse(rssi.text.trim()),
      if (int.tryParse(latency.text.trim()) != null)
        'roundTripLatencyMs': int.parse(latency.text.trim()),
      if (!succeeded && errCode.text.trim().isNotEmpty)
        'errorCode': errCode.text.trim(),
    };
    rssi.dispose();
    latency.dispose();
    errCode.dispose();
    if (ok != true) return;
    await _run(
      () => SupportApi.serviceRequestAction(
        widget.requestId,
        'connection-tests',
        body,
      ),
      'Đã ghi nhận kết quả kiểm tra.',
    );
  }

  /// Thay nóng: chọn thiết bị mới trong cùng zone → xác nhận cũ/mới/zone → gọi API hot-swap.
  Future<void> _hotSwap(Map<String, dynamic> r) async {
    final zoneId = '${r['zoneId']}';
    final oldId = '${r['currentDeviceId'] ?? r['originalDeviceId'] ?? ''}';
    if (oldId.isEmpty) {
      _snack('Yêu cầu chưa gắn thiết bị cần thay.');
      return;
    }
    List<Map<String, dynamic>> devices;
    try {
      devices = await SupportApi.listZoneDevices(zoneId);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    final candidates = devices
        .where((d) => '${d['deviceId']}' != oldId)
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      _snack(
        'Zone chưa có thiết bị thay thế khả dụng. Cần cấp phát thiết bị mới trước.',
      );
      return;
    }
    String? newId;
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Thay nóng thiết bị'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thiết bị cũ: $oldId',
                  style: const TextStyle(fontSize: 13),
                ),
                Text('Zone: $zoneId', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: newId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Thiết bị thay thế',
                  ),
                  items: [
                    for (final d in candidates)
                      DropdownMenuItem(
                        value: '${d['deviceId']}',
                        child: Text(
                          '${d['hardwareAddress'] ?? d['deviceId']} · ${d['status'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (x) => setLocal(() => newId = x),
                ),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (tuỳ chọn)',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Backend chịu trách nhiệm giữ liên kết dữ liệu lịch sử của thiết bị cũ.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: newId == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận thay nóng'),
            ),
          ],
        ),
      ),
    );
    final noteText = notes.text.trim();
    notes.dispose();
    if (confirmed != true || newId == null) return;
    await _run(
      () => SupportApi.hotSwapDevice(
        zoneId: zoneId,
        oldDeviceId: oldId,
        serviceRequestId: widget.requestId,
        newDeviceId: newId!,
        notes: noteText.isEmpty ? null : noteText,
      ),
      'Đã gửi yêu cầu thay nóng thiết bị.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _req != null && serviceKindOf(_req!) == ServiceKind.installation
              ? 'Chi tiết lắp đặt'
              : 'Chi tiết yêu cầu',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loading || _busy ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _req == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error ?? 'Không có dữ liệu',
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            )
          : _body(_req!),
    );
  }

  Widget _body(Map<String, dynamic> r) {
    final st = serviceStatusOf(r);
    final res = resolutionOf(r);
    final history =
        (r['history'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final isInstall = serviceKindOf(r) == ServiceKind.installation;
    final depId = '${r['deploymentRequestId'] ?? ''}';
    final actions = <Widget>[];
    void add(String label, VoidCallback f) => actions.add(
      FilledButton(onPressed: _busy ? null : f, child: Text(label)),
    );
    // Phiếu lắp đặt không có thiết bị để chẩn đoán/kiểm tra/đóng: chỉ nhận việc ở đây, phần còn lại ở khối Tiến độ lắp đặt.
    switch (isInstall ? '' : st) {
      case 'Assigned':
        add(
          'Nhận việc',
          () => _run(
            () => SupportApi.serviceRequestAction(widget.requestId, 'accept'),
            'Đã nhận việc.',
          ),
        );
      case 'InProgress':
        add('Ghi chẩn đoán', _diagnose);
      case 'Diagnosed':
        add('Ghi kết quả sửa chữa', _recordWork);
        if (res == 'Replacement') add('Thay nóng thiết bị', () => _hotSwap(r));
      case 'WorkCompleted':
        add('Ghi kết quả kiểm tra kết nối', _connectionTest);
      case 'Verified':
        add(
          'Đóng yêu cầu',
          () => _run(
            () => SupportApi.serviceRequestAction(widget.requestId, 'close'),
            'Đã đóng yêu cầu.',
          ),
        );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(r, st, res, isInstall),
          if (isInstall)
            InstallFlowStepper(
              quotationStatus: _quoteStatus,
              deploymentStatus: _depStatus,
              closed: isClosedStatus(st),
            ),
          if (isInstall &&
              depId.isNotEmpty &&
              depId != '00000000-0000-0000-0000-000000000000')
            InstallProgressCard(
              depositPaid: _depositPaid,
              // Việc tiếp theo chỉ hiện khi đã đọc được báo giá và triển khai (không đoán bước khi thiếu dữ liệu).
              headline:
                  (_quoteKnown && _depStatus != null) ||
                      isClosedStatus(serviceStatusOf(r))
                  ? installNextAction(
                      serviceStatus: serviceStatusOf(r),
                      quotationStatus: _quoteStatus,
                      deploymentStatus: _depStatus,
                      closed: isClosedStatus(serviceStatusOf(r)),
                    )
                  : null,
              extraActions: _fieldButtons(r),
              deploymentRequestId: depId,
              farmId: '${r['farmId'] ?? ''}',
              zoneId: '${r['zoneId'] ?? ''}',
              onStatus: (s) {
                if (mounted && s != _depStatus) setState(() => _depStatus = s);
              },
              onOpenDetail: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeploymentRequestDetailScreen(
                    requestId: depId,
                    technician: true,
                  ),
                ),
              ),
            ),
          if (isInstall)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: QuotationPanel(
                  serviceRequestId: widget.requestId,
                  deploymentRequestId: depId.isEmpty ? null : depId,
                  farmName: _zoneOf(r)?.farmName,
                  zoneName: _zoneOf(r)?.name,
                  onChanged: () => _loadExtras(r),
                  zone: _zoneOf(r),
                ),
              ),
            ),
          if ('${r['inspectionNotes'] ?? ''}'.isNotEmpty)
            _kv('Ghi chú kiểm tra', '${r['inspectionNotes']}'),
          if ('${r['diagnosis'] ?? ''}'.isNotEmpty)
            _kv('Chẩn đoán', '${r['diagnosis']}'),
          if ('${r['workPerformed'] ?? ''}'.isNotEmpty)
            _kv('Công việc đã làm', '${r['workPerformed']}'),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (actions.isEmpty)
            Text(
              isInstall
                  ? 'Phiếu lắp đặt được đóng khi chủ trang trại ký nghiệm thu.'
                  : 'Không có thao tác khả dụng ở trạng thái này.',
              style: TextStyle(fontSize: 13),
            )
          else
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          const Divider(height: 32),
          const Text(
            'Lịch sử xử lý',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Chưa có lịch sử.'),
            ),
          for (final h in history)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${h['eventType']} → ${enumName(h['toStatus'], _statusByIndex)}',
              ),
              subtitle: Text(
                '${h['createdAtUtc'] ?? ''}${(h['notes'] ?? '').toString().isEmpty ? '' : '\n${h['notes']}'}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color, {bool mono = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
        fontFamily: mono ? 'monospace' : null,
      ),
    ),
  );

  /// Phần đầu trang giống thẻ yêu cầu trên web: loại yêu cầu, trạng thái dịch vụ, hợp đồng (lắp đặt), tiêu đề dễ đọc,
  /// nơi lắp đặt, số node đã chấm. Không hiện mã lỗi thô cho phiếu lắp đặt; không bịa số liệu khi chưa tải được.
  Widget _header(
    Map<String, dynamic> r,
    String st,
    String res,
    bool isInstall,
  ) {
    final where = _where(r);
    final title = serviceTitle(r);
    final description = '${r['description'] ?? ''}'.trim();
    final history = (r['history'] as List?) ?? const [];
    final created = history.isEmpty
        ? ''
        : '${(history.first as Map)['createdAtUtc'] ?? ''}';
    final createdDate = created.length >= 10 ? created.substring(0, 10) : '';
    final id = '${r['id'] ?? widget.requestId}';
    Widget meta(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _pill(
                  isInstall ? 'Lắp đặt thiết bị mới' : 'Bảo trì / sửa chữa',
                  isInstall ? AppColors.primaryDark : AppColors.warning,
                ),
                _pill(
                  'Dịch vụ: ${serviceStatusLabels[st] ?? st}',
                  serviceStatusColor(st),
                ),
                if (isInstall && _quoteKnown)
                  _pill(
                    'Hợp đồng: ${contractStageLabel(_quoteStatus)}',
                    _stageColor(_quoteStatus),
                  ),
                if (res.isNotEmpty)
                  _pill(resolutionLabels[res] ?? res, AppColors.info),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            if (!isInstall && '${r['failureCode'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 4),
              _pill('${r['failureCode']}', AppColors.textMuted, mono: true),
            ],
            if (where != null) meta(Icons.location_on_outlined, where),
            if (isInstall && _nodes != null)
              meta(Icons.hub_outlined, '$_nodes node đã chấm trên bản đồ'),
            if (createdDate.isNotEmpty)
              meta(Icons.event_outlined, 'Ngày tạo: $createdDate'),
            meta(Icons.tag, '#${id.length > 8 ? id.substring(0, 8) : id}'),
            if (description.isNotEmpty && description != title) ...[
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(v),
      ],
    ),
  );
}

/// Màu giai đoạn hợp đồng như pill web: xám chưa tạo, cam chờ Owner cọc, xanh đã cọc/nghiệm thu.
Color _stageColor(String? s) => switch (s) {
  null || '' || 'Draft' => AppColors.textMuted,
  'Completed' || 'SignedByOwner' || 'DepositPaid' => AppColors.primaryDark,
  _ => AppColors.warning,
};
