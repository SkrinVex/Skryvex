import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.post('/auth/register', {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
      }, auth: false);
      if (res['message'] != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyScreen(email: _emailCtrl.text.trim()),
            ),
          );
        }
      } else {
        setState(() => _error = res['error'] as String? ?? 'Ошибка регистрации');
      }
    } catch (e) {
      setState(() => _error = 'Нет соединения с сервером');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Создать аккаунт',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 4),
                const Text('Введите данные для регистрации',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Имя'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите имя';
                    if (v.trim().length < 2) return 'Имя слишком короткое (минимум 2 символа)';
                    if (v.trim().length > 50) return 'Имя слишком длинное (максимум 50 символов)';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
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
                    hintText: 'Пароль (минимум 6 символов)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < 6) return 'Пароль минимум 6 символов';
                    if (v.length > 128) return 'Пароль слишком длинный';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                _loading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
                    : ElevatedButton(onPressed: _register, child: const Text('Зарегистрироваться')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
