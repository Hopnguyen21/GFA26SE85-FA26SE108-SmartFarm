import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import 'node_provisioning_flow.dart';

/// Bảng "Cấp phát Node": liệt kê Node trong KHO CỦA KTV (loại khớp dòng hợp đồng lên đầu); chạm một dòng, xác nhận địa chỉ phần
/// cứng rồi cấp phát — backend trừ thiết bị đó khỏi kho KTV. Đóng bảng trả true khi cấp phát xong.
class NodeProvisionSheet extends StatefulWidget {
  final String slotLabel;
  final bool actuator;

  /// Mã hàng của dòng hợp đồng đang chấm: hàng kho cùng mã là đúng thiết bị đã ghi trong hợp đồng.
  final String? slotCode;

  /// Loại (true = điều khiển, false = cảm biến) của MỌI dòng Node trong hợp đồng, theo mã hàng (in hoa). Dùng để biết loại của
  /// hàng kho chưa gán vai trò: hợp đồng đã nói rõ mã đó là cảm biến hay điều khiển nên không bắt KTV xác nhận lại.
  final Map<String, bool> contractKinds;
  final Future<List<NodeChoice>> Function(Set<String> taken) load;
  final Future<void> Function(NodeChoice node, String address) provision;
  const NodeProvisionSheet({
    super.key,
    required this.slotLabel,
    required this.actuator,
    this.slotCode,
    this.contractKinds = const {},
    required this.load,
    required this.provision,
  });

  @override
  State<NodeProvisionSheet> createState() => _NodeProvisionSheetState();
}

class _NodeProvisionSheetState extends State<NodeProvisionSheet> {
  List<NodeChoice> _items = const [];
  bool _loading = true;
  String? _busyId;
  final Set<String> _taken =
      {}; // địa chỉ backend đã báo trùng: gợi ý lại sang số kế tiếp
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Hàng kho cùng mã với dòng hợp đồng đang chấm.
  bool _isExact(NodeChoice n) =>
      widget.slotCode != null &&
      widget.slotCode!.trim().isNotEmpty &&
      n.code.trim().toUpperCase() == widget.slotCode!.trim().toUpperCase();

  /// Loại thật của hàng (true = điều khiển): vai trò/chủng loại kho trước, không có thì theo mã trong hợp đồng; null = không rõ.
  bool? _actuatorOf(NodeChoice n) {
    if (n.roleKnown) return n.isActuator;
    return widget.contractKinds[n.code.trim().toUpperCase()];
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load(_taken);
      // Tự gợi ý theo hợp đồng: đúng mã của dòng → cùng loại với dòng → chưa rõ loại. Hàng ĐÃ biết là khác loại thì không đưa ra.
      int rank(NodeChoice n) {
        if (_isExact(n)) return 0;
        final k = _actuatorOf(n);
        if (k == null) return 2;
        return k == widget.actuator ? 1 : 3;
      }

      r.removeWhere((n) => rank(n) == 3);
      r.sort((a, b) => rank(a).compareTo(rank(b)));
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _askAddress(NodeChoice n) async {
    final ctrl = TextEditingController(text: n.suggestedAddress);
    String? err;
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text(
            'Địa chỉ phần cứng của Node',
            style: TextStyle(fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '[${n.code}] ${n.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('node-address'),
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ phần cứng (in trên thiết bị)',
                  errorText: err,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              key: const ValueKey('node-address-ok'),
              onPressed: () {
                final e = validateNodeAddress(ctrl.text);
                if (e != null) {
                  setLocal(() => err = e);
                  return;
                }
                Navigator.pop(ctx, ctrl.text.trim());
              },
              child: const Text('Cấp phát'),
            ),
          ],
        ),
      ),
    );
    // Không dispose ngay: hộp thoại còn chạy hiệu ứng đóng và vẫn dựng ô nhập (controller nhỏ, tự thu gom).
    return v;
  }

  Future<void> _pick(NodeChoice n) async {
    final address = await _askAddress(n);
    if (address == null || !mounted) return;
    setState(() {
      _busyId = n.hardwareItemId;
      _error = null;
    });
    try {
      await widget.provision(n, address);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (isAddressConflict(e)) {
        // Địa chỉ trùng với thiết bị ở nơi khác: ghi nhớ, gợi ý lại địa chỉ kế tiếp rồi để KTV chọn lại.
        _taken.add(address.toUpperCase());
        await _reload();
        if (mounted) {
          setState(
            () => _error =
                'Địa chỉ $address đã được dùng ở nơi khác. Đã gợi ý địa chỉ kế tiếp, hãy chọn lại.',
          );
        }
      } else {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busyId != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cấp phát Node · ${widget.slotLabel}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: busy || _loading ? null : _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const Text(
                'Chọn Node trong kho của bạn. Cấp phát xong, thiết bị được trừ khỏi kho kỹ thuật viên của bạn.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Kho của bạn chưa có Node phù hợp với dòng này (cùng loại cảm biến/điều khiển trong hợp đồng). Tạo phiếu xuất kho (Kho & Xuất kho IoT) để nhận Node từ kho chính; Admin duyệt và hoàn thành phiếu thì Node vào kho của bạn.',
                    style: TextStyle(color: Color(0xFFB45309)),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _items[i];
                      final match =
                          _isExact(n) || _actuatorOf(n) == widget.actuator;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          key: ValueKey('node-${n.hardwareItemId}'),
                          enabled: !busy,
                          onTap: busy ? null : () => _pick(n),
                          leading: Icon(
                            widget.actuator ? Icons.bolt : Icons.sensors,
                            color: match ? const Color(0xFF047857) : null,
                          ),
                          title: Text(
                            '[${n.code}] ${n.name}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            [
                              if (n.serial != null) 'Serial ${n.serial}',
                              'Trong kho: ${n.quantity}',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: _busyId == n.hardwareItemId
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFBE123C)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
