import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  // Передаётся либо userId, либо username
  final int? userId;
  final String? username;
  // Если уже есть данные — передаём сразу
  final Map<String, dynamic>? initialData;

  const UserProfileScreen({super.key, this.userId, this.username, this.initialData})
      : assert(userId != null || username != null || initialData != null);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _openingChat = false;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    if (widget.initialData != null) {
      _data = widget.initialData;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _loadMyId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw != null && mounted) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      setState(() => _myId = j['id'] as int?);
    }
  }

  Future<void> _load() async {
    try {
      final identifier = widget.username ?? widget.userId.toString();
      final data = await ApiService.get('/auth/users/$identifier') as Map<String, dynamic>;
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat() async {
    if (_data == null || _openingChat) return;
    setState(() => _openingChat = true);
    try {
      final isSelf = _myId != null && _data!['id'] == _myId;
      final Map<String, dynamic> res;
      if (isSelf) {
        res = await ApiService.get('/chats/self') as Map<String, dynamic>;
      } else {
        res = await ApiService.post('/chats', {'userId': _data!['id']}, auth: true);
      }
      final chatId = res['chatId'] as int?;
      if (chatId != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(
          chatId: chatId,
          partnerName: isSelf ? 'Избранное' : _data!['name'] as String,
          partnerAvatar: isSelf ? null : _data!['avatar_url'] as String?,
          partnerId: isSelf ? null : _data!['id'] as int?,
          isSelf: isSelf,
        )));
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  void _copyLink() {
    if (_data == null) return;
    final username = _data!['username'] as String?;
    final id = _data!['id'];
    final link = 'https://api.skrinvex.su/u/${username ?? id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_data?['name'] as String? ?? 'Профиль'),
        actions: [
          if (_data != null)
            IconButton(icon: const Icon(Icons.link), onPressed: _copyLink),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _data == null
              ? const Center(child: Text('Пользователь не найден', style: TextStyle(color: AppTheme.textSecondary)))
              : _buildContent(accent),
    );
  }

  Widget _buildContent(Color accent) {
    final name = _data!['name'] as String;
    final username = _data!['username'] as String?;
    final avatarUrl = _data!['avatar_url'] as String?;
    final bio = _data!['bio'] as String?;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.surfaceVariant,
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl, cacheKey: 'u_profile_${_data!['id']}')
                : null,
            child: avatarUrl == null
                ? Text(name[0].toUpperCase(), style: TextStyle(color: accent, fontSize: 36, fontWeight: FontWeight.w600))
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(child: Text(name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600))),
        if (username != null) ...[
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '@$username'));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username скопирован')));
              },
              child: Text('@$username', style: TextStyle(color: accent, fontSize: 15)),
            ),
          ),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _openingChat ? null : _openChat,
          icon: _openingChat
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: AppTheme.bg, strokeWidth: 2))
              : const Icon(Icons.chat_bubble_outline),
          label: const Text('Написать сообщение'),
        ),
      ],
    );
  }
}
