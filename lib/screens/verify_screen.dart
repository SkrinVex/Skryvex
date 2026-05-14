import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/api_service.dart';
import '../services/push_service.dart';
import 'adaptive_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VerifyScreen extends StatefulWidget {
  final String email;
  const VerifyScreen({super.key, required this.email});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.post('/auth/verify', {
        'email': widget.email,
        'code': _codeCtrl.text.trim(),
      });
      if (res['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', res['token'] as String);
        await prefs.setString('user', jsonEncode(res['user']));
        await PushService.instance.init();
        if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        setState(() => _error = res['error'] as String? ?? 'Неверный код');
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Введите код', style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Мы отправили 6-значный код на\n${widget.email}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
        const SizedBox(height: 32),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(hintText: '000000'),
          onChanged: (v) { if (v.length == 6) _verify(); },
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        _loading
            ? Center(child: CircularProgressIndicator(color: AppTheme.orange))
            : ElevatedButton(onPressed: _verify, child: const Text('Подтвердить')),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Подтверждение')),
      body: SafeArea(
        child: desktop
            ? adaptiveFormBody(context: context, child: content)
            : Padding(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24), child: content),
      ),
    );
  }
}
