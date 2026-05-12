import 'dart:convert';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw != null) {
      final u = UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _setUser(u);
    }
    try {
      final data = await ApiService.get('/auth/me') as Map<String, dynamic>;
      final u = UserModel.fromJson(data);
      _setUser(u);
      await prefs.setString('user', jsonEncode(u.toJson()));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _setUser(UserModel u) {
    _user = u;
    _nameCtrl.text = u.name;
    _usernameCtrl.text = u.username ?? '';
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    if (name.isEmpty) return;

    // Валидация username
    if (username.isNotEmpty) {
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(username)) {
        _showError('Username: только латиница, цифры и _');
        return;
      }
      if (username.length < 3 || username.length > 30) {
        _showError('Username: от 3 до 30 символов');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final data = await ApiService.patch('/auth/me', {
        'name': name,
        if (username.isNotEmpty) 'username': username,
      });
      if (data['error'] != null) {
        _showError(data['error'] as String);
        return;
      }
      final u = UserModel.fromJson(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(u.toJson()));
      if (mounted) {
        setState(() => _user = u);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
        );
      }
    } catch (_) {
      _showError('Ошибка сохранения');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _uploadingAvatar = true);
    try {
      final data = await ApiService.uploadFile('/auth/me/avatar', bytes, file.name);
      if (data['error'] != null) { _showError(data['error'] as String); return; }
      final u = UserModel.fromJson(data);
      // Инвалидируем старый кеш аватара
      await CachedNetworkImage.evictFromCache('avatar_me');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(u.toJson()));
      if (mounted) setState(() => _user = u);
    } catch (_) {
      _showError('Ошибка загрузки аватара');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2))
                  : Text('Сохранить', style: TextStyle(color: AppTheme.orange)),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.orange))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Аватар
                Center(
                  child: GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppTheme.surfaceVariant,
                          backgroundImage: _user?.avatarUrl != null
                              ? CachedNetworkImageProvider(_user!.avatarUrl!, cacheKey: 'avatar_me')
                              : null,
                          child: _user?.avatarUrl == null
                              ? Text(
                                  _user?.name.isNotEmpty == true ? _user!.name[0].toUpperCase() : '?',
                                  style: TextStyle(color: AppTheme.orange, fontSize: 32, fontWeight: FontWeight.w600),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(color: AppTheme.orange, shape: BoxShape.circle),
                            child: _uploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(color: AppTheme.bg, strokeWidth: 2),
                                  )
                                : const Icon(Icons.camera_alt, color: AppTheme.bg, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: _BlurredEmail(email: _user?.email ?? '')),
                const SizedBox(height: 32),
                // Имя
                const Text('Имя', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(hintText: 'Ваше имя'),
                ),
                const SizedBox(height: 20),
                // Username
                const Text('Username', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLength: 30,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'username (необязательно)',
                    prefixText: '@',
                    prefixStyle: TextStyle(color: AppTheme.orange),
                    counterText: '',
                  ),
                ),
              ],
            ),
    );
  }
}

class _BlurredEmail extends StatefulWidget {
  final String email;
  const _BlurredEmail({required this.email});

  @override
  State<_BlurredEmail> createState() => _BlurredEmailState();
}

class _BlurredEmailState extends State<_BlurredEmail> {
  bool _revealed = false;

  String get _masked {
    final at = widget.email.indexOf('@');
    if (at < 0) return widget.email;
    final local = widget.email.substring(0, at);
    final domain = widget.email.substring(at); // @domain.com
    final visible = local.length > 3 ? local.substring(local.length - 3) : local;
    return '•••$visible$domain';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _revealed = !_revealed),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            _revealed ? widget.email : _masked,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          if (!_revealed)
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.transparent,
                  child: Text(_masked,
                    style: const TextStyle(color: Colors.transparent, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
