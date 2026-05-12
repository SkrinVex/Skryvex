import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'adaptive_layout.dart';
import 'register_screen.dart';
import 'verify_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.post('/auth/login', {
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      }, auth: false);

      if (res['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res['token'] as String);
        await prefs.setString('user', jsonEncode(res['user']));
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else if (res['error'] == 'Email не подтверждён') {
        // Перекидываем на верификацию
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyScreen(email: _emailCtrl.text.trim()),
            ),
          );
        }
      } else {
        setState(() => _error = res['error'] as String? ?? 'Ошибка входа');
      }
    } catch (_) {
      setState(() => _error = 'Нет соединения с сервером');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text('Skryvex', style: TextStyle(color: AppTheme.orange, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text('Войдите в аккаунт', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          const SizedBox(height: 36),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Email'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Введите email';
              if (!_emailRe.hasMatch(v.trim())) return 'Некорректный формат email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Пароль',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) { if (v == null || v.isEmpty) return 'Введите пароль'; return null; },
            onFieldSubmitted: (_) => _login(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Забыли пароль?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          _loading
              ? Center(child: CircularProgressIndicator(color: AppTheme.orange))
              : ElevatedButton(onPressed: _login, child: const Text('Войти')),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Нет аккаунта? Зарегистрироваться'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: desktop
            ? adaptiveFormBody(context: context, child: formContent)
            : Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 28), child: formContent)),
      ),
    );
  }
}
