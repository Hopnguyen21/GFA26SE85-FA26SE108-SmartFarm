import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'password_screens.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController(text: kDebugMode ? 'owner@smartfarm.demo' : '');
  final _passwordCtrl = TextEditingController(text: kDebugMode ? 'Demo@12345' : '');
  late final TextEditingController _serverCtrl;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showServerConfig = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: ApiService.baseUrl);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập email và mật khẩu.');
      return;
    }
    // Chỉ debug mới cho đổi máy chủ; release luôn dùng URL cấu hình lúc build.
    if (!kReleaseMode && _serverCtrl.text.isNotEmpty) {
      try {
        ApiService.setBaseUrl(_serverCtrl.text.trim());
      } catch (e) {
        setState(() => _errorMessage = 'URL máy chủ không hợp lệ.');
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiService.login(email, password);
      if (!mounted) return;
      if (result != null && !result.containsKey('error')) {
        widget.onLoginSuccess();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else if (result != null && result['error'] == 'unsupported_role') {
        setState(() => _errorMessage = result['message']?.toString() ?? 'Vai trò không được hỗ trợ.');
      } else if (result != null && result['error'] == 'network') {
        setState(() {
          _errorMessage =
              'Không thể kết nối máy chủ. Kiểm tra URL backend hoặc mạng.\n${result['message'] ?? ''}';
          _showServerConfig = !kReleaseMode;
        });
      } else {
        final statusCode = result?['error'];
        if (statusCode == 401 || statusCode == 400) {
          setState(() => _errorMessage = 'Email hoặc mật khẩu không đúng.');
        } else {
          setState(() => _errorMessage =
              'Đăng nhập thất bại (mã lỗi: $statusCode). Vui lòng thử lại.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Lỗi hệ thống: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF062326),
      body: Stack(
        children: [
          // Background ambient gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF059669).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo & Branding matching Frontend Topbar / LoginPage
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.eco, color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              const Text(
                                'SmartFarm',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Text(
                                  'AI CLOUD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6EE7B7),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nền tảng Nông nghiệp Thông minh · Chuẩn VietGAP',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),

                          // Login card matching Frontend LoginPage styling
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C2E32),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text(
                              'Đăng nhập tài khoản',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Truy cập hệ thống quản lý vi khí hậu và tự động hóa',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                            const SizedBox(height: 20),

                            // Email field
                            _buildLabel('Email / Tài khoản'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _emailCtrl,
                              hint: kDebugMode ? 'owner@smartfarm.demo' : 'ten@trangtrai.vn',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            _buildLabel('Mật khẩu'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _passwordCtrl,
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF64748B),
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              onSubmitted: (_) => _login(),
                            ),

                            // Error message
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7F1D1D).withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFF87171).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Color(0xFFF87171), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFF87171),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                                child: const Text('Quên mật khẩu?', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                              ),
                            ),

                            // Server config toggle
                            if (!kReleaseMode && _showServerConfig) ...[
                              const SizedBox(height: 14),
                              _buildLabel('URL Backend Server'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _serverCtrl,
                                hint: 'http://10.0.2.2:5144',
                                icon: Icons.dns_outlined,
                                keyboardType: TextInputType.url,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '• Android emulator: http://10.0.2.2:5144\n• Thiết bị thật (cùng WiFi): http://192.168.x.x:5144',
                                style: TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.5),
                              ),
                            ] else if (!kReleaseMode) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => setState(() => _showServerConfig = true),
                                child: const Text(
                                  'Cấu hình địa chỉ máy chủ →',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF10B981),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      const Color(0xFF10B981).withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Đăng nhập vào SmartFarm',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Register navigation link
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RegisterScreen(
                                        onRegisterSuccess: widget.onLoginSuccess,
                                      ),
                                    ),
                                  );
                                },
                                child: const Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Chưa có tài khoản? ',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    ),
                                    Text(
                                      'Đăng ký ngay',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quick Demo Account Selection Chips (Chỉ hiển thị trong môi trường Debug)
                      if (kDebugMode) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Tài khoản trải nghiệm nhanh (Debug Mode):',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.badge, size: 14, color: Color(0xFF10B981)),
                              label: const Text('👑 Chủ Trại (Owner)', style: TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: const Color(0xFF0C2E32),
                              side: const BorderSide(color: Color(0xFF10B981)),
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _emailCtrl.text = 'owner@smartfarm.demo';
                                  _passwordCtrl.text = 'Demo@12345';
                                });
                                _login();
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.person, size: 14, color: Color(0xFF38BDF8)),
                              label: const Text('🌾 Nông Dân (Farmer)', style: TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: const Color(0xFF0C2E32),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _emailCtrl.text = 'farmer@smartfarm.demo';
                                  _passwordCtrl.text = 'Demo@12345';
                                });
                                _login();
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.build_circle, size: 14, color: Color(0xFFFBBF24)),
                              label: const Text('🔧 Kỹ Thuật Viên', style: TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: const Color(0xFF0C2E32),
                              side: const BorderSide(color: Color(0xFFFBBF24)),
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _emailCtrl.text = 'technician@smartfarm.demo';
                                  _passwordCtrl.text = 'Demo@12345';
                                });
                                _login();
                              },
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.admin_panel_settings, size: 14, color: Color(0xFFA855F7)),
                              label: const Text('🛡️ Quản Trị (Admin)', style: TextStyle(fontSize: 11, color: Colors.white)),
                              backgroundColor: const Color(0xFF0C2E32),
                              side: const BorderSide(color: Color(0xFFA855F7)),
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _emailCtrl.text = 'admin@smartfarm.demo';
                                  _passwordCtrl.text = 'Demo@12345';
                                });
                                _login();
                              },
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      const Text(
                        'SmartFarm v1.0 · AI Powered · VietGAP Certified',
                        style: TextStyle(fontSize: 10, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF94A3B8),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF334155), fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF10B981)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0A2225),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFF10B981).withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFF10B981).withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
