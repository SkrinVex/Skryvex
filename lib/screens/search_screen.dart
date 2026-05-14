import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/api_service.dart';
import 'user_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() => _results = []); return; }
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/auth/search?q=${Uri.encodeComponent(q.trim())}') as List<dynamic>;
      if (mounted) setState(() => _results = data.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Имя или @username...',
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            filled: false,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : ListView.separated(
              itemCount: _results.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (_, i) {
                final u = _results[i];
                final name = u['name'] as String;
                final username = u['username'] as String?;
                final avatarUrl = u['avatar_url'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.surfaceVariant,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl, cacheKey: 'u_${u['id']}')
                        : null,
                    child: avatarUrl == null
                        ? Text(name[0].toUpperCase(), style: TextStyle(color: accent))
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(color: AppTheme.textPrimary)),
                  subtitle: username != null
                      ? Text('@$username', style: TextStyle(color: accent, fontSize: 12))
                      : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(initialData: u),
                  )),
                );
              },
            ),
    );
  }
}
