import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_service.dart';
import 'register_screen.dart';
import 'password_screens.dart';
import '../../core/utils/user_error.dart';

const _green = Color(0xFF119653);
const _rememberedEmailKey = 'login_remembered_email';
const _showDemoAccounts = bool.fromEnvironment(
  'SHOW_DEMO_ACCOUNTS',
  defaultValue: !kReleaseMode,
);

/// Màn đăng nhập, bố cục và hành vi theo trang `LoginPage` của web: khối thương hiệu xanh, form "Đăng nhập Hệ thống",
/// ghi nhớ email, Quên mật khẩu / Đăng ký, thông báo thành công sau khi đăng ký hoặc đặt lại mật khẩu (kèm điền sẵn email),
/// thông báo lỗi lấy từ backend và (chỉ khi debug) chuyển nhanh vai trò demo.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  /// Điền sẵn email và hiện thông báo thành công (sau khi đăng ký) như `location.state` của web.
  final String? initialEmail;
  final String? initialMessage;
  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    this.initialEmail,
    this.initialMessage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _serverCtrl;
  bool _obscurePassword = true;
  bool _remember = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _showServerConfig = false;

  @override
  void initState() {
    super.initState();
    final fromRegister = widget.initialEmail != null;
    _emailCtrl = TextEditingController(
      text: widget.initialEmail ?? (kDebugMode ? 'owner@smartfarm.demo' : ''),
    );
    _passwordCtrl = TextEditingController(
      text: fromRegister ? '' : (kDebugMode ? 'Demo@12345' : ''),
    );
    _serverCtrl = TextEditingController(text: ApiService.baseUrl);
    _successMessage = widget.initialMessage;
    if (!fromRegister) _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  /// "Ghi nhớ": chỉ nhớ email (không bao giờ lưu mật khẩu) để lần sau điền sẵn.
  Future<void> _loadRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_rememberedEmailKey);
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _emailCtrl.text = saved;
          _passwordCtrl.text = '';
          _remember = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRememberedEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_remember) {
        await prefs.setString(_rememberedEmailKey, email);
      } else {
        await prefs.remove(_rememberedEmailKey);
      }
    } catch (_) {}
  }

  Future<bool> _saveServerUrl({bool showConfirmation = false}) async {
    try {
      await ApiService.saveDebugBaseUrl(_serverCtrl.text);
      if (mounted && showConfirmation) {
        FocusScope.of(context).unfocus();
        setState(() {
          _errorMessage = null;
          _successMessage = 'Đã lưu địa chỉ máy chủ.';
        });
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _successMessage = null;
          _errorMessage = error is FormatException
              ? 'URL máy chủ không hợp lệ.'
              : 'Không lưu được địa chỉ máy chủ.';
        });
      }
      return false;
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _successMessage = null;
        _errorMessage = 'Vui lòng nhập email và mật khẩu.';
      });
      return;
    }
    // Chỉ debug mới cho đổi máy chủ; release luôn dùng URL cấu hình lúc build.
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      if (!kReleaseMode && !await _saveServerUrl()) return;
      if (!mounted) return;
      final result = await ApiService.login(email, password);
      if (!mounted) return;
      if (result != null && !result.containsKey('error')) {
        await _saveRememberedEmail(email);
        if (!mounted) return;
        widget.onLoginSuccess();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else if (result != null && result['error'] == 'unsupported_role') {
        setState(
          () => _errorMessage =
              result['message']?.toString() ?? 'Vai trò không được hỗ trợ.',
        );
      } else if (result != null && result['error'] == 'network') {
        setState(() {
          _errorMessage =
              'Không thể kết nối máy chủ. Kiểm tra URL backend hoặc mạng.\n${result['message'] ?? ''}';
          _showServerConfig = !kReleaseMode;
        });
      } else {
        final statusCode = result?['error'];
        // Như web: ưu tiên lý do cụ thể của backend (vd. tài khoản bị khóa tạm thời); không có thì dùng câu mặc định.
        final detail = result?['detail']?.toString();
        if (detail != null && detail.isNotEmpty) {
          setState(() => _errorMessage = detail);
        } else if (statusCode == 401 || statusCode == 400) {
          setState(
            () => _errorMessage =
                'Đăng nhập thất bại. Vui lòng kiểm tra email và mật khẩu.',
          );
        } else {
          setState(
            () => _errorMessage =
                'Đăng nhập thất bại (mã lỗi: $statusCode). Vui lòng thử lại.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Lỗi hệ thống: ${userFacingError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Quên mật khẩu: đặt lại xong thì điền sẵn email, xóa mật khẩu và báo thành công (như `onSuccessReset` của web).
  Future<void> _openForgotPassword() async {
    final resetEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
    if (!mounted || resetEmail == null) return;
    setState(() {
      if (resetEmail.isNotEmpty) _emailCtrl.text = resetEmail;
      _passwordCtrl.text = '';
      _errorMessage = null;
      _successMessage =
          'Đặt lại mật khẩu thành công! Hãy nhập mật khẩu mới để đăng nhập.';
    });
  }

  /// Đăng ký: xong thì điền sẵn email, xóa mật khẩu và báo thành công (như `registeredEmail` của web).
  Future<void> _openRegister() async {
    final email = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted || email == null) return;
    setState(() {
      _emailCtrl.text = email;
      _passwordCtrl.text = '';
      _errorMessage = null;
      _successMessage =
          'Đăng ký tài khoản thành công! Hãy nhập mật khẩu của bạn để đăng nhập.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              if (isWide) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 5, child: _brandCardDesktop()),
                              Expanded(
                                flex: 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: _formContent(isWide: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              // Giao diện Mobile / Màn hình hẹp (< 768px): Header gọn gàng + Card đăng nhập
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _brandCardMobile(),
                        const SizedBox(height: 12),
                        _formCardMobile(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Banner thương hiệu tinh gọn cho mobile: vừa vặn khung nhìn, không chiếm quá nhiều diện tích.
  Widget _brandCardMobile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF064E3B), _green, Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SmartFarm SaaS',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nền tảng Quản lý Nông nghiệp Thông minh Tích hợp AI',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFD1FAE5),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chipBadge(Icons.shield_outlined, 'PostgreSQL RLS'),
              _chipBadge(Icons.sensors, 'LoRa 433MHz'),
              _chipBadge(Icons.auto_awesome, 'AI Nông học Gemini'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipBadge(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF6EE7B7)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFECFDF5),
          ),
        ),
      ],
    ),
  );

  /// Cột thương hiệu của web (Desktop / Màn hình rộng): logo, tiêu đề, mô tả và ba điểm nổi bật.
  Widget _brandCardDesktop() {
    Widget bullet(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, size: 16, color: Color(0xFF6EE7B7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFD1FAE5),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_green, Color(0xFF047857), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SmartFarm SaaS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Nền tảng Quản lý Nông nghiệp Thông minh Tích hợp AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Giải pháp SaaS đa người thuê (Multi-tenant) kết hợp viễn thám LoRa 433MHz, tự động hóa điều khiển vi khí hậu thích ứng theo thời kỳ sinh trưởng và Trợ lý AI Nông học Gemini.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFD1FAE5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              bullet('Bảo mật Tenant Isolation chuẩn PostgreSQL RLS'),
              bullet('Cơ chế Crop-aware điều khiển vi khí hậu thông minh'),
              bullet('Tư vấn Nông học AI RAG chuẩn VietGAP/GlobalGAP'),
            ],
          ),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            width: double.infinity,
            child: const Text(
              'SmartFarm Enterprise Platform © 2026. All rights reserved.',
              style: TextStyle(fontSize: 12, color: Color(0xFFA7F3D0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner({
    required String text,
    required IconData icon,
    required Color bg,
    required Color border,
    required Color fg,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: fg, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _formCardMobile() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: _formContent(isWide: false),
    );
  }

  Widget _formContent({required bool isWide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đăng nhập Hệ thống',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Nhập tài khoản của bạn để truy cập Workspace',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _isLoading ? null : _openRegister,
              style: TextButton.styleFrom(
                foregroundColor: _green,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Đăng ký ngay',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (_successMessage != null)
          _banner(
            text: _successMessage!,
            icon: Icons.check_circle,
            bg: const Color(0xFFECFDF5),
            border: const Color(0xFFA7F3D0),
            fg: const Color(0xFF065F46),
          ),
        if (_errorMessage != null)
          _banner(
            text: _errorMessage!,
            icon: Icons.error_outline,
            bg: const Color(0xFFFFF1F2),
            border: const Color(0xFFFECDD3),
            fg: const Color(0xFFBE123C),
          ),
        const SizedBox(height: 18),
        _label('Email / Tên đăng nhập'),
        const SizedBox(height: 6),
        _field(
          controller: _emailCtrl,
          hint: 'tenban@example.com',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _label('Mật khẩu'),
        const SizedBox(height: 6),
        _field(
          controller: _passwordCtrl,
          hint: 'Mật khẩu của bạn...',
          icon: Icons.vpn_key_outlined,
          obscureText: _obscurePassword,
          onSubmitted: (_) => _login(),
          suffixIcon: IconButton(
            tooltip: 'Hiện hoặc ẩn mật khẩu',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFF94A3B8),
              size: 18,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: _isLoading
                    ? null
                    : () => setState(() => _remember = !_remember),
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _remember,
                        activeColor: _green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: _isLoading
                            ? null
                            : (v) => setState(() => _remember = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ghi nhớ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isLoading ? null : _openForgotPassword,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '•',
                        style: TextStyle(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isLoading ? null : _openRegister,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            'Đăng ký?',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!kReleaseMode && _showServerConfig) ...[
          const SizedBox(height: 12),
          _label('URL Backend Server'),
          const SizedBox(height: 6),
          _field(
            controller: _serverCtrl,
            hint: 'http://10.0.2.2:5144',
            icon: Icons.dns_outlined,
            keyboardType: TextInputType.url,
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => _saveServerUrl(showConfirmation: true),
            child: const Text('Lưu địa chỉ máy chủ'),
          ),
          const SizedBox(height: 4),
          const Text(
            '• Android emulator: http://10.0.2.2:5144\n• Thiết bị thật (cùng WiFi): http://192.168.x.x:5144',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ] else if (!kReleaseMode) ...[
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showServerConfig = true),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune, size: 14, color: _green),
                SizedBox(width: 4),
                Text(
                  'Cấu hình địa chỉ máy chủ →',
                  style: TextStyle(
                    fontSize: 12,
                    color: _green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _green.withValues(alpha: 0.6),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
              shadowColor: _green.withValues(alpha: 0.35),
            ),
            child: _isLoading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Đang xác thực...',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đăng nhập ngay',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 17),
                    ],
                  ),
          ),
        ),
        // 3 tài khoản mẫu (mật khẩu chung của dữ liệu seed): hiện ở bản debug/profile; bản release
        // chỉ hiện khi build với --dart-define=SHOW_DEMO_ACCOUNTS=true (dùng cho buổi demo).
        if (_showDemoAccounts) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.how_to_reg, size: 14, color: _green),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CHUYỂN NHANH VAI TRÒ (QUICK SWITCH)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final cardWidth = c.maxWidth > 350
                  ? (c.maxWidth - 8) / 2
                  : c.maxWidth;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _roleButton(
                    '1. Technician',
                    'Triển khai & Cấp phát IoT',
                    'technician@smartfarm.demo',
                    Icons.engineering_outlined,
                    const Color(0xFF0369A1),
                    const Color(0xFFF0F9FF),
                    const Color(0xFFBAE6FD),
                    cardWidth,
                  ),
                  _roleButton(
                    '2. Farm Owner',
                    'Chủ Nông trang Tenant Root',
                    'owner@smartfarm.demo',
                    Icons.admin_panel_settings_outlined,
                    const Color(0xFF065F46),
                    const Color(0xFFECFDF5),
                    const Color(0xFFA7F3D0),
                    cardWidth,
                  ),
                  _roleButton(
                    '3. Farmer / Worker',
                    'Công nhân thực địa',
                    'farmer@smartfarm.demo',
                    Icons.agriculture_outlined,
                    const Color(0xFF92400E),
                    const Color(0xFFFFFBEB),
                    const Color(0xFFFDE68A),
                    cardWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  /// Nút vai trò demo (chỉ debug), màu theo từng vai trò như web.
  Widget _roleButton(
    String title,
    String subtitle,
    String email,
    IconData icon,
    Color fg,
    Color bg,
    Color border,
    double width,
  ) => SizedBox(
    width: width,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isLoading
          ? null
          : () {
              setState(() {
                _emailCtrl.text = email;
                _passwordCtrl.text = 'Demo@12345';
              });
              _login();
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border, width: 0.6),
              ),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: fg.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF334155),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      enableSuggestions: !obscureText,
      autocorrect: false,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF64748B)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: border(const Color(0xFFE2E8F0)),
        enabledBorder: border(const Color(0xFFE2E8F0)),
        focusedBorder: border(_green, 1.8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
