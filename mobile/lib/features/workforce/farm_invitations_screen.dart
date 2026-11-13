import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';

/// Farmer xem và trả lời lời mời tham gia Farm. Chấp nhận chỉ đưa Farmer vào Farm, không tự cấp quyền Zone.
class FarmInvitationsScreen extends StatefulWidget {
  const FarmInvitationsScreen({super.key});

  @override
  State<FarmInvitationsScreen> createState() => _FarmInvitationsScreenState();
}

class _FarmInvitationsScreenState extends State<FarmInvitationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AccountApi.getMyInvitations();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(String id, bool accept) async {
    setState(() => _busy = true);
    try {
      await AccountApi.respondInvitation(id, accept);
      if (accept) {
        // Phiên cần token mới để mang thông tin Tenant/Farm vừa tham gia.
        await ApiService.refreshToken();
        if (mounted) await context.read<FarmProvider>().fetchFromApi();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Đã tham gia trang trại. Chủ trang trại sẽ cấp quyền Zone cho bạn.'
                : 'Đã từ chối lời mời.',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lời mời tham gia Farm')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
              ),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_loading && _items.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bạn chưa có lời mời nào.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final inv in _items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['farmName']?.toString() ?? 'Trang trại',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hết hạn: ${_date(inv['expiresAtUtc'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _respond(inv['id'].toString(), false),
                              child: const Text('Từ chối'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _respond(inv['id'].toString(), true),
                              child: const Text('Chấp nhận'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    return d == null
        ? '—'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
