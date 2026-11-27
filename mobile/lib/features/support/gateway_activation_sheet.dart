import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import 'gateway_activation_logic.dart';
import '../../core/services/api_service.dart' show kAllowGatewaySimulation;

/// Bảng "Kích hoạt Gateway": liệt kê Gateway trong kho KTV kèm trạng thái đăng ký; Gateway đã đăng ký thì kích hoạt cho yêu cầu;
/// chưa có phần cứng thật thì "Mô phỏng Gateway" (app đóng vai thiết bị tự đăng ký rồi kích hoạt). Đóng bảng trả true khi đã
/// kích hoạt được một Gateway.
class GatewayActivationSheet extends StatefulWidget {
  final Future<List<GatewayChoice>> Function() load;
  final Future<void> Function(GatewayChoice) activate;
  final Future<String> Function() simulate;
  const GatewayActivationSheet({
    super.key,
    required this.load,
    required this.activate,
    required this.simulate,
  });

  @override
  State<GatewayActivationSheet> createState() => _GatewayActivationSheetState();
}

class _GatewayActivationSheetState extends State<GatewayActivationSheet> {
  List<GatewayChoice> _items = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final done = await action();
      if (!mounted) return;
      if (done != null) {
        Navigator.pop(context, true);
        return;
      }
      await _reload();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kích hoạt Gateway cho yêu cầu này',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Làm mới',
                    onPressed: _busy || _loading ? null : _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const Text(
                'Gateway thật tự đăng ký khi bật nguồn và có mạng; bạn chỉ cần kích hoạt cho yêu cầu. Chưa có phần cứng thì dùng Mô phỏng.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Kho của bạn chưa có Gateway nào. Nhờ Admin giao Gateway cho tài khoản kỹ thuật viên.',
                    style: TextStyle(color: Color(0xFFB45309)),
                  ),
                )
              else
                for (final g in _items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[${g.code}] ${g.name}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (g.serial != null || g.mac != null)
                            Text(
                              [
                                if (g.serial != null) 'Serial ${g.serial}',
                                if (g.mac != null) 'MAC ${g.mac}',
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            g.statusText,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: g.canActivate
                                  ? const Color(0xFF047857)
                                  : Colors.black54,
                            ),
                          ),
                          if (g.canActivate)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: FilledButton(
                                key: ValueKey('activate-${g.hardwareItemId}'),
                                onPressed: _busy
                                    ? null
                                    : () => _run(() async {
                                        await widget.activate(g);
                                        return 'ok';
                                      }),
                                child: const Text('Kích hoạt cho yêu cầu này'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFBE123C)),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_message!),
                ),
              const SizedBox(height: 8),
              if (kAllowGatewaySimulation)
                OutlinedButton.icon(
                  key: const ValueKey('simulate-gateway'),
                  onPressed: _busy || _loading
                      ? null
                      : () => _run(() async {
                          final msg = await widget.simulate();
                          return msg;
                        }),
                  icon: const Icon(Icons.science_outlined),
                  label: Text(
                    _busy
                        ? 'Đang xử lý…'
                        : 'Mô phỏng Gateway (chưa có phần cứng)',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
