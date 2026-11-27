import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/farm_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/user_error.dart';

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
      if (mounted) setState(() => _error = userFacingError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(String id, bool accept) async {
    setState(() => _busy = true);
    try {
      await AccountApi.respondInvitation(id, accept);
    } catch (e) {
      // Backend chưa xử lý (từ chối/hết hạn/xung đột): lời mời còn nguyên, báo lỗi để người dùng thử lại hoặc tải lại.
      if (mounted) {
        setState(() {
          _error = userFacingError(e);
          _busy = false;
        });
      }
      return;
    }
    // Từ đây backend ĐÃ ghi nhận câu trả lời. Các bước làm mới phiên bên dưới lỗi cũng không được báo như thể
    // chưa tham gia (trước đây bấm lại sẽ gặp 409 vì lời mời đã được chấp nhận).
    var sessionRefreshed = true;
    if (accept) {
      try {
        // Phiên cần token mới để mang thông tin Tenant/Farm vừa tham gia.
        await ApiService.refreshToken();
        if (mounted) await context.read<FarmProvider>().fetchFromApi();
      } catch (_) {
        sessionRefreshed = false;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !accept
              ? 'Đã từ chối lời mời.'
              : sessionRefreshed
              ? 'Đã tham gia trang trại. Chủ trang trại sẽ cấp quyền Zone cho bạn.'
              : 'Đã tham gia trang trại nhưng chưa làm mới được phiên. Hãy kéo để tải lại hoặc đăng nhập lại.',
        ),
      ),
    );
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  /// Lời mời đã quá hạn thì không cho chấp nhận (backend sẽ từ chối); thiếu ngày hết hạn thì để backend quyết định.
  bool _expired(Map<String, dynamic> inv) {
    final d = DateTime.tryParse('${inv['expiresAtUtc'] ?? ''}');
    return d != null && d.isBefore(DateTime.now().toUtc());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF062326),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lời Mời Tham Gia Farm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          // Danh sách ngắn/rỗng vẫn kéo để làm mới được (trên Android mặc định không cuộn được thì không kéo được).
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
              ),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFF10B981)),
                ),
              ),
            if (!_loading && _items.isEmpty && _error == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.mail_outline,
                          size: 32,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Bạn chưa có lời mời nào.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            for (final inv in _items)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Icon(
                            Icons.agriculture,
                            color: Color(0xFF047857),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv['farmName']?.toString() ?? 'Trang trại',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _expired(inv)
                                        ? 'Đã hết hạn: ${_date(inv['expiresAtUtc'])}'
                                        : 'Hết hạn: ${_date(inv['expiresAtUtc'])}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: _expired(inv)
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(color: Color(0xFFFECACA)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _respond(inv['id'].toString(), false),
                            child: const Text(
                              'Từ chối',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: _busy || _expired(inv)
                                ? null
                                : () => _respond(inv['id'].toString(), true),
                            child: const Text(
                              'Chấp nhận',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
