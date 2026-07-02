import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../main.dart' show DashboardPage;

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLoggedIn,
  });

  final VoidCallback? onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final hasToken = await _authService.hasToken();
    if (!mounted) return;
    if (hasToken) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    }
  }


  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Username và Password')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _authService.login(
        username: username,
        password: password,
      );


      if (!mounted) return;

      widget.onLoggedIn?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng nhập thành công!')),
      );

      // Chuyển hướng ngay sau khi login thành công
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardPage()),
      );
    } catch (e) {
      if (!mounted) return;

      final rawMessage = e.toString().replaceAll('Exception: ', '').trim();
      String localizedMessage;

      if (rawMessage.contains('Incorrect username or password!')) {
        localizedMessage = 'Tài khoản hoặc mật khẩu không chính xác. Vui lòng thử lại!';
      } else if (rawMessage.contains('Unable to connect to server')) {
        localizedMessage =
            'Không thể kết nối tới máy chủ. Vui lòng kiểm tra lại kết nối mạng!';
      } else {
        localizedMessage = 'Đăng nhập thất bại. Vui lòng thử lại sau!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            localizedMessage,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        FocusScope.of(context).nextFocus();
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _handleLogin,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_isSubmitting ? 'Đang đăng nhập...' : 'Login'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Lưu token vào SharedPreferences với key: auth_token',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

