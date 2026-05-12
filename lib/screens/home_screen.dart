import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _ChatsTab(),
          _CommunityTab(),
          _SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.orange.withValues(alpha: 0.15),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: AppTheme.orange),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppTheme.orange),
            label: 'Сообщество',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppTheme.orange),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

// ── Chats tab ──────────────────────────────────────────────────────────────

class _ChatsTab extends StatefulWidget {
  const _ChatsTab();

  @override
  State<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<_ChatsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<ChatModel> _chats = [];
  bool _loading = true;
  WebSocketChannel? _ws;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _connectWs() async {
    if (_ws != null) {
      // Уже подключены — просто джойнимся в новые чаты
      for (final chat in _chats) {
        _ws!.sink.add(jsonEncode({'type': 'join', 'chatId': chat.id}));
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    _ws = WebSocketChannel.connect(Uri.parse('${ApiService.wsBase}?token=$token'));
    _ws!.stream.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg['type'] == 'message') _refreshChatsBackground();
    }, onError: (_) {}, onDone: () {});
    for (final chat in _chats) {
      _ws!.sink.add(jsonEncode({'type': 'join', 'chatId': chat.id}));
    }
  }

  @override
  void dispose() {
    _ws?.sink.close();
    super.dispose();
  }

  Future<void> _loadChats({bool forceRefresh = false}) async {
    // Показываем кэш мгновенно
    if (!forceRefresh) {
      final cached = await CacheService.loadChats();
      if (cached != null && mounted) {
        setState(() {
          _chats = cached.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
        // Обновляем в фоне без индикатора
        await _refreshChatsBackground();
        _connectWs();
        return;
      }
    }
    setState(() => _loading = true);
    await _refreshChatsBackground();
    _connectWs();
  }

  Future<void> _refreshChatsBackground() async {
    try {
      final data = await ApiService.get('/chats') as List<dynamic>;
      await CacheService.saveChats(data);
      if (mounted) {
        setState(() {
          _chats = data.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skryvex'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textSecondary),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
              _loadChats();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
          : _chats.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: AppTheme.orange,
                  backgroundColor: AppTheme.surface,
                  onRefresh: () => _loadChats(forceRefresh: true),
                  child: ListView.separated(
                    itemCount: _chats.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, indent: 72, color: AppTheme.divider),
                    itemBuilder: (_, i) => _ChatTile(
                      chat: _chats[i],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: _chats[i].id,
                              partnerName: _chats[i].partnerName,
                            ),
                          ),
                        );
                        _loadChats();
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('Нет чатов', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Найдите пользователя через поиск',
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
      );
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.unreadCount > 0;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(name: chat.partnerName, url: chat.partnerAvatar),
      title: Text(chat.partnerName,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          )),
      subtitle: chat.lastMessage != null
          ? Text(chat.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUnread
                    ? AppTheme.textPrimary.withValues(alpha: 0.8)
                    : AppTheme.textSecondary,
                fontSize: 13,
              ))
          : null,
      trailing: hasUnread
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTheme.orange, borderRadius: BorderRadius.circular(10)),
              child: Text('${chat.unreadCount}',
                  style: const TextStyle(
                      color: AppTheme.bg, fontSize: 12, fontWeight: FontWeight.w600)),
            )
          : null,
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? url;
  const _Avatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppTheme.surfaceVariant,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w600))
          : null,
    );
  }
}

// ── Community tab ──────────────────────────────────────────────────────────

class _CommunityTab extends StatelessWidget {
  const _CommunityTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сообщество')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined,
                size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text('В разработке',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ── Settings tab ───────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Выйти из аккаунта?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Вы уверены, что хотите выйти?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Выйти',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Выйти из аккаунта',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
