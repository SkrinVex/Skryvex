import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.post('/auth/forgot-password', {
        'email': _emailCtrl.text.trim(),
      }, auth: false);
      // Всегда показываем успех — сервер не раскрывает существование аккаунта
      setState(() => _sent = true);
    } catch (_) {
      setState(() => _error = 'Нет соединения с сервером');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сброс пароля')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _sent ? _successState() : _formState(),
        ),
      ),
    );
  }

  Widget _formState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Забыли пароль?',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Введите email — мы отправим ссылку для сброса пароля',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: 28),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          _loading
              ? Center(child: CircularProgressIndicator(color: AppTheme.orange))
              : ElevatedButton(onPressed: _submit, child: const Text('Отправить ссылку')),
        ],
      ),
    );
  }

  Widget _successState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 64, color: AppTheme.orange),
          const SizedBox(height: 20),
          const Text('Письмо отправлено',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            'Если аккаунт с адресом ${_emailCtrl.text.trim()} существует,\nна него придёт ссылка для сброса пароля.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Вернуться ко входу'),
          ),
        ],
      ),
    );
  }
}
