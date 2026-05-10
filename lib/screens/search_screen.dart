import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/auth/search?q=${Uri.encodeComponent(q)}') as List<dynamic>;
      setState(() => _results = data.cast<Map<String, dynamic>>());
    } catch (_) {
      setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(int userId, String name) async {
    try {
      final res = await ApiService.post('/chats', {'userId': userId}, auth: true);
      final chatId = res['chatId'] as int?;
      if (chatId != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: chatId, partnerName: name),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Поиск пользователей...',
            border: InputBorder.none,
            fillColor: Colors.transparent,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (_, i) {
                final u = _results[i];
                final name = u['name'] as String;
                final avatarUrl = u['avatar_url'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.surfaceVariant,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(name[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.orange))
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => _openChat(u['id'] as int, name),
                );
              },
            ),
    );
  }
}
