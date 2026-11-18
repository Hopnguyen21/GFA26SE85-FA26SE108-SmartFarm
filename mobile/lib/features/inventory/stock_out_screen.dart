import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/paging.dart';
import '../../core/widgets/paged_list.dart';
import '../../core/widgets/state_views.dart';
import '../support/service_board_logic.dart';
import 'stock_out_logic.dart';

/// Yêu cầu lắp đặt chưa đóng mà phiếu có thể thuộc về (liên kết `serviceRequestId`): có liên kết thì Admin duyệt xong KTV mới
/// được Gắn Node ở đúng yêu cầu đó.
typedef InstallRequestRef = ({String id, String title, String zoneId});

/// "Phiếu xuất kho thiết bị IoT" của kỹ thuật viên, theo trang Quản lý Nhập & Xuất Kho trên web: chọn trang trại, tìm kiếm,
/// lọc trạng thái, danh sách phiếu (mã, Zone nhận, số loại/số cái, người lập, ngày lập, trạng thái), tạo phiếu, chi tiết phiếu
/// (xóa khi nháp/đã hủy, gửi duyệt, hủy khi chờ duyệt). Duyệt và hoàn thành xuất kho là việc của Admin trên web.
class StockOutScreen extends StatefulWidget {
  /// Mở thẳng bảng lập phiếu mới (từ nút "Nhận thiết bị từ kho chính" của kho KTV).
  final bool openCreate;
  const StockOutScreen({super.key, this.openCreate = false});

  @override
  State<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends State<StockOutScreen> {
  String? _farmId;
  bool _loading = false;
  String? _error;
  List<StockOutDoc> _docs = const [];
  List<Map<String, dynamic>> _hardware = const [];
  List<InstallRequestRef> _requests = const [];
  String _query = '';
  StockOutStatus? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<FarmProvider>();
      final farms = p.farms;
      if (farms.isNotEmpty) {
        final sel = farms.where((f) => f.farmId == p.selectedFarmId);
        _farmId = (sel.isNotEmpty ? sel.first : farms.first).farmId;
        _load().then((_) {
          if (mounted && widget.openCreate) _create();
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _load() async {
    final farmId = _farmId;
    if (farmId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        StockOutApi.getFarmStockOuts(farmId),
        DeploymentApi.getHardwareItems(),
        _installRequests(farmId),
      ]);
      if (!mounted || _farmId != farmId) return;
      setState(() {
        _docs = [
          for (final j in results[0] as List<Map<String, dynamic>>)
            StockOutDoc.fromJson(j),
        ];
        _hardware = results[1] as List<Map<String, dynamic>>;
        _requests = results[2] as List<InstallRequestRef>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Yêu cầu lắp đặt chưa đóng của trang trại này được giao cho KTV (backend chỉ trả yêu cầu được phân công). Lỗi thì không liên kết được.
  Future<List<InstallRequestRef>> _installRequests(String farmId) async {
    try {
      final all = await SupportApi.getServiceRequests();
      return [
        for (final r in all)
          if ('${r['farmId']}' == farmId &&
              serviceKindOf(r) == ServiceKind.installation &&
              !isClosedStatus('${r['status'] ?? ''}'))
            (
              id: '${r['id']}',
              title: serviceTitle(r),
              zoneId: '${r['zoneId'] ?? ''}',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  String? _requestTitle(StockOutDoc d) {
    final id = d.serviceRequestId?.toLowerCase();
    if (id == null) return null;
    final m = _requests.where((r) => r.id.toLowerCase() == id).firstOrNull;
    return m?.title ??
        'Yêu cầu #${id.substring(0, id.length < 8 ? id.length : 8)}';
  }

  Color _color(StockOutStatus s) => switch (s) {
    StockOutStatus.completed => const Color(0xFF047857),
    StockOutStatus.approved => const Color(0xFF1D4ED8),
    StockOutStatus.pending => const Color(0xFFB45309),
    StockOutStatus.cancelled => const Color(0xFFBE123C),
    StockOutStatus.draft => const Color(0xFF475569),
  };

  Widget _statusBadge(StockOutStatus s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: _color(s).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _color(s).withValues(alpha: 0.4)),
    ),
    child: Text(
      s.label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: _color(s),
      ),
    ),
  );

  Future<void> _create() async {
    final farmId = _farmId;
    if (farmId == null) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateStockOutSheet(farmId: farmId, hardware: _hardware),
    );
    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo phiếu xuất kho (Bản nháp).')),
        );
      }
    }
  }

  Future<void> _open(StockOutDoc d) async {
    final farmId = _farmId;
    if (farmId == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _StockOutDetailScreen(
          farmId: farmId,
          doc: d,
          requestTitle: _requestTitle(d),
          badge: _statusBadge(d.status),
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Widget _card(StockOutDoc d) => Container(
    margin: EdgeInsets.zero,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _statusBadge(d.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                d.zoneText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (_requestTitle(d) != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Thuộc yêu cầu: ${_requestTitle(d)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF0369A1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                d.summary,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Người lập: ${d.createdByName} · ${fmtDateTime(d.createdAt)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _body(List<StockOutDoc> shown) {
    if (_loading && _docs.isEmpty) {
      return const AppLoading(message: 'Đang tải danh sách phiếu xuất kho…');
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: shown.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 80),
                Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: Colors.black26,
                ),
                SizedBox(height: 8),
                Center(
                  child: Text('Không có phiếu xuất kho thiết bị nào phù hợp.'),
                ),
              ],
            )
          : PagedList<StockOutDoc>(
              // đổi bộ lọc/tìm kiếm thì về trang đầu
              key: ValueKey('$_query|${_filter?.name}'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
              items: sortNewestFirst(shown, (d) => d.createdAt),
              itemGap: 8,
              itemBuilder: (_, d) => _card(d),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farms = context.watch<FarmProvider>().farms;
    final shown = filterStockOuts(_docs, query: _query, status: _filter);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Phiếu xuất kho thiết bị IoT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _farmId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              onPressed: _loading ? null : _create,
              icon: const Icon(Icons.add),
              label: const Text(
                'Tạo phiếu xuất kho',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: farms.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có trang trại nào để lập phiếu xuất kho. Trang trại chỉ hiện khi bạn được Admin phân công một yêu cầu ở đó.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('farm-$_farmId'),
                    initialValue: _farmId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Trang trại',
                      prefixIcon: Icon(Icons.apartment),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final f in farms)
                        DropdownMenuItem(
                          value: f.farmId,
                          child: Text(f.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null || v == _farmId) return;
                      setState(() {
                        _farmId = v;
                        _docs = const [];
                      });
                      _load();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo mã phiếu, Zone, ghi chú…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Tất cả'),
                          selected: _filter == null,
                          onSelected: (_) => setState(() => _filter = null),
                        ),
                      ),
                      for (final s in StockOutStatus.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(s.label),
                            selected: _filter == s,
                            onSelected: (_) => setState(() => _filter = s),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _body(shown)),
              ],
            ),
    );
  }
}

class _StockOutDetailScreen extends StatefulWidget {
  final String farmId;
  final StockOutDoc doc;
  final String? requestTitle;
  final Widget badge;
  const _StockOutDetailScreen({
    required this.farmId,
    required this.doc,
    required this.badge,
    this.requestTitle,
  });

  @override
  State<_StockOutDetailScreen> createState() => _StockOutDetailScreenState();
}

class _StockOutDetailScreenState extends State<_StockOutDetailScreen> {
  bool _busy = false;

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Không'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!await _confirm(
      'Gửi duyệt',
      'Gửi phiếu ${widget.doc.code} cho Admin duyệt? Sau khi gửi bạn không sửa được nội dung phiếu.',
    )) {
      return;
    }
    await _run(
      () async =>
          StockOutApi.setStatus(widget.farmId, widget.doc.id, 'Pending'),
      'Đã gửi phiếu cho Admin duyệt.',
    );
  }

  Future<void> _cancel() async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối / Hủy phiếu'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Ghi chú / lý do (không bắt buộc)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Không'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hủy phiếu'),
          ),
        ],
      ),
    );
    final reason = ctl.text.trim();
    if (ok != true) return;
    await _run(
      () async => StockOutApi.setStatus(
        widget.farmId,
        widget.doc.id,
        'Cancelled',
        notes: reason.isEmpty ? null : reason,
      ),
      'Đã hủy phiếu.',
    );
  }

  Future<void> _delete() async {
    if (!await _confirm(
      'Xóa phiếu',
      'Bạn có chắc muốn xóa phiếu xuất kho này? Thao tác không thể hoàn tác.',
    )) {
      return;
    }
    await _run(
      () async => StockOutApi.delete(widget.farmId, widget.doc.id),
      'Đã xóa phiếu.',
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _line(StockOutLine l) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Tồn kho hiện tại: ${fmtQty(l.currentStock)} ${l.unit}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (l.notes != null)
                  Text(
                    l.notes!,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
              ],
            ),
          ),
          Text(
            '× ${fmtQty(l.quantity)} ${l.unit}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        title: Text(
          'Phiếu xuất kho #${d.code}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [widget.badge]),
          const SizedBox(height: 12),
          if (widget.requestTitle != null)
            _row('Thuộc yêu cầu', widget.requestTitle!),
          _row('Khu vực / Zone nhận', d.zoneText),
          _row('Người lập phiếu', d.createdByName),
          if (d.createdAt != null) _row('Ngày lập', fmtDateTime(d.createdAt)),
          if (d.approvedByName != null) _row('Người duyệt', d.approvedByName!),
          if (d.completedAt != null)
            _row('Hoàn tất xuất kho lúc', fmtDateTime(d.completedAt)),
          if (d.notes != null) _row('Mục đích / Ghi chú', d.notes!),
          const Divider(height: 24),
          const Text(
            'Danh sách thiết bị',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final l in d.lines) _line(l),
          const SizedBox(height: 12),
          if (d.status == StockOutStatus.pending)
            const Text(
              'Phiếu đang chờ Admin duyệt. Duyệt và hoàn tất xuất kho do Admin thực hiện trên web.',
              style: TextStyle(color: Color(0xFFB45309), fontSize: 13),
            ),
          if (d.status == StockOutStatus.approved)
            Text(
              d.serviceRequestId == null
                  ? 'Admin đã duyệt phiếu. Hoàn tất xuất kho do Admin thực hiện trên web.'
                  : 'Admin đã duyệt phiếu. Mở yêu cầu này ở tab Công việc để bấm "Gắn Node"; hoàn tất xuất kho do Admin thực hiện trên web.',
              style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 13),
            ),
          if (d.status == StockOutStatus.pending && d.serviceRequestId != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Admin duyệt xong thì nút "Gắn Node" của yêu cầu này mới mở.',
                style: TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 12),
          if (d.canSend)
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: const Icon(Icons.send),
              label: const Text('Gửi duyệt'),
            ),
          if (d.canCancel)
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Từ chối / Hủy'),
            ),
          if (d.canDelete)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBE123C),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa phiếu'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row {
  String? itemId;
  int quantity = 1;
}

class _CreateStockOutSheet extends StatefulWidget {
  final String farmId;
  final List<Map<String, dynamic>> hardware;
  const _CreateStockOutSheet({required this.farmId, required this.hardware});

  @override
  State<_CreateStockOutSheet> createState() => _CreateStockOutSheetState();
}

class _CreateStockOutSheetState extends State<_CreateStockOutSheet> {
  final _notes = TextEditingController();
  final _rows = <_Row>[_Row()];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  // Chỉ hàng ở kho chính (không lẫn hàng đã giao KTV / lỗi / đã triển khai).
  late final List<Map<String, dynamic>> _choices = warehouseChoices(
    widget.hardware,
  );

  Map<String, dynamic>? _item(String? id) =>
      widget.hardware.where((h) => '${h['id']}' == id).firstOrNull;

  String _label(Map<String, dynamic> h) {
    final model = '${h['model'] ?? ''}'.trim();
    final ident = '${h['serialNumber'] ?? h['macAddress'] ?? ''}'.trim();
    return '[${h['code']}] ${h['name']}${model.isEmpty ? '' : ' - $model'}${ident.isEmpty ? '' : ' · $ident'}';
  }

  /// Các thiết bị chọn được ở dòng [r]: mỗi thiết bị chỉ chọn một lần (bỏ những cái đã chọn ở dòng khác).
  List<Map<String, dynamic>> _available(_Row r) => [
    for (final it in _choices)
      if ('${it['id']}' == r.itemId ||
          !_rows.any((o) => o.itemId == '${it['id']}'))
        it,
  ];

  /// Dòng phụ của mục menu: model, định danh, tồn kho (hoặc lý do không chọn được).
  String _detail(Map<String, dynamic> it) {
    final model = '${it['model'] ?? ''}'.trim();
    final ident = '${it['serialNumber'] ?? it['macAddress'] ?? ''}'.trim();
    final stock = 'Tồn: ${fmtQty(_stock(it))}';
    return [
      if (model.isNotEmpty) model,
      if (ident.isNotEmpty) ident,
      isIssuableAsIs(it) ? stock : '$stock · cần tách từng serial',
    ].join(' · ');
  }

  /// Chọn thiết bị cho dòng: hàng theo serial luôn số lượng 1; hàng số lượng không vượt tồn.
  void _select(_Row r, String? id) {
    r.itemId = id;
    final h = _item(id);
    if (h == null) return;
    if (isSerialTracked(h)) {
      r.quantity = 1;
    } else {
      final stock = _stock(h).toInt();
      if (r.quantity > stock) r.quantity = stock < 1 ? 1 : stock;
    }
  }

  num _stock(Map<String, dynamic>? h) => (h?['quantityInStock'] as num?) ?? 0;

  Future<void> _submit() async {
    final valid = [
      for (final r in _rows)
        if (r.itemId != null && r.quantity > 0) r,
    ];
    if (valid.isEmpty) {
      setState(
        () =>
            _error = 'Vui lòng chọn ít nhất một vật tư với số lượng lớn hơn 0.',
      );
      return;
    }
    for (final r in valid) {
      final h = _item(r.itemId);
      if (stockAfterIssue(_stock(h), r.quantity) < 0) {
        setState(
          () => _error =
              'Không đủ tồn kho cho ${_label(h ?? {})}: tồn ${fmtQty(_stock(h))}, xuất ${r.quantity}.',
        );
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StockOutApi.create(
        widget.farmId,
        zoneId: null,
        notes: _notes.text.trim(),
        details: [
          for (final r in valid)
            {'inventoryItemId': r.itemId, 'quantity': r.quantity, 'notes': ''},
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tạo phiếu xuất kho thiết bị IoT',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Ghi chú / Mục đích xuất kho thiết bị',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Danh sách thiết bị xuất kho',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_Row())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm thiết bị'),
                ),
              ],
            ),
            for (var i = 0; i < _rows.length; i++) _rowEditor(i),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFBE123C)),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Hủy bỏ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Đang tạo…' : 'Tạo phiếu xuất kho'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowEditor(int i) {
    final r = _rows[i];
    final h = _item(r.itemId);
    final after = h == null ? null : stockAfterIssue(_stock(h), r.quantity);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('item-$i-${r.itemId}'),
            initialValue: r.itemId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Chọn thiết bị xuất kho',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            // Mục menu cao theo nội dung (tên đầy đủ 2 dòng + tồn kho), không cắt thành "…".
            itemHeight: null,
            menuMaxHeight: 420,
            items: [
              for (final it in _available(r))
                DropdownMenuItem(
                  value: '${it['id']}',
                  enabled: isIssuableAsIs(it),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '[${it['code']}] ${it['name']}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _detail(it),
                          style: TextStyle(
                            fontSize: 12,
                            color: isIssuableAsIs(it)
                                ? const Color(0xFF475569)
                                : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            // Ô đã chọn (đóng) hiện một dòng: mã + tên.
            selectedItemBuilder: (_) => [
              for (final it in _available(r))
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _label(it),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _select(r, v)),
          ),
          if (_choices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Kho chính hiện không còn thiết bị nào để xuất.',
                style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (h != null && isSerialTracked(h))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Số lượng: 1 (hàng theo serial)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else ...[
                IconButton(
                  onPressed: r.quantity > 1
                      ? () => setState(() => r.quantity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${r.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  // không cho vượt tồn (chưa chọn thiết bị thì chưa biết tồn)
                  onPressed: h == null || r.quantity < _stock(h)
                      ? () => setState(() => r.quantity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
              const Spacer(),
              if (after != null)
                Flexible(
                  child: Text(
                    after < 0
                        ? 'Vượt tồn kho ${fmtQty(-after)}'
                        : 'Tồn kho sau xuất: ${fmtQty(after)}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: after < 0
                          ? const Color(0xFFBE123C)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
              if (_rows.length > 1)
                IconButton(
                  onPressed: () => setState(() => _rows.removeAt(i)),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFBE123C),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
