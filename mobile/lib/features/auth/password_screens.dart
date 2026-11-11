import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/export_utils.dart';

String _errText(Object e) => e is UnsupportedApiException
    ? 'Máy chủ SmartFarm chưa hỗ trợ chức năng này (thiếu API backend). Vui lòng liên hệ quản trị viên.'
    : e.toString().replaceFirst('Exception: ', '');

InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
  labelText: label,
  suffixIcon: suffix,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
);

/// Quên mật khẩu: bước 1 nhập email, bước 2 nhập mã (token/OTP) + mật khẩu mới.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _done = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _sendCode() async {
    if (_busy) return;
    if (!_emailOk) {
      setState(() => _error = 'Email không hợp lệ.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountApi.forgotPassword(_email.text.trim());
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    final tokenText = _token.text.trim();
    final rule = validateNewPassword(_newPass.text);
    String? err;
    if (tokenText.isEmpty) {
      err = 'Vui lòng nhập mã xác nhận.';
    } else if (rule != null) {
      err = rule;
    } else if (_newPass.text != _confirm.text) {
      err = 'Mật khẩu xác nhận không khớp.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountApi.resetPassword(email: _email.text.trim(), token: tokenText, newPassword: _newPass.text);
      if (mounted) {
        _token.clear();
        _newPass.clear();
        _confirm.clear();
        setState(() => _done = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: _done
              ? Column(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 56),
                    const SizedBox(height: 12),
                    const Text(
                      'Đặt lại mật khẩu thành công. Hãy đăng nhập bằng mật khẩu mới.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Về đăng nhập')),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _email,
                      enabled: !_codeSent && !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: _dec('Email tài khoản'),
                    ),
                    const SizedBox(height: 12),
                    if (!_codeSent)
                      FilledButton(
                        onPressed: _busy ? null : _sendCode,
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Gửi mã xác nhận'),
                      )
                    else ...[
                      const Text(
                        'Nếu email tồn tại, mã xác nhận đã được gửi. Nhập mã và mật khẩu mới.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _token,
                        enabled: !_busy,
                        decoration: _dec('Mã xác nhận (token/OTP)'),
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPass,
                        enabled: !_busy,
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: _dec(
                          'Mật khẩu mới',
                          suffix: IconButton(
                            tooltip: 'Hiện hoặc ẩn mật khẩu',
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirm,
                        enabled: !_busy,
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: _dec('Xác nhận mật khẩu mới'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _reset,
                        child: _busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Đặt lại mật khẩu'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const Key('password-error'),
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Đổi mật khẩu trong Hồ sơ.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    String? err;
    if (_current.text.isEmpty) {
      err = 'Vui lòng nhập mật khẩu hiện tại.';
    } else {
      err = validateNewPassword(_newPass.text);
      if (err == null && _newPass.text != _confirm.text) err = 'Mật khẩu xác nhận không khớp.';
      if (err == null && _newPass.text == _current.text) err = 'Mật khẩu mới phải khác mật khẩu hiện tại.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AccountApi.changePassword(currentPassword: _current.text, newPassword: _newPass.text);
      if (mounted) {
        _current.clear();
        _newPass.clear();
        _confirm.clear();
        setState(() => _done = true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toggle = IconButton(
      tooltip: 'Hiện hoặc ẩn mật khẩu',
      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Đổi mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: _done
              ? Column(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 56),
                    const SizedBox(height: 12),
                    const Text('Đã đổi mật khẩu thành công.'),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _current,
                      enabled: !_busy,
                      obscureText: _obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: _dec('Mật khẩu hiện tại', suffix: toggle),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newPass,
                      enabled: !_busy,
                      obscureText: _obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: _dec('Mật khẩu mới'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: _obscure,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: _dec('Xác nhận mật khẩu mới'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Đổi mật khẩu'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const Key('password-error'),
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
