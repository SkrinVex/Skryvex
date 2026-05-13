import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adaptive_layout.dart';
import 'chat_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'customization_screen.dart';
import 'channel_screen.dart';
import 'create_channel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _chatUnread = 0;

  void updateChatUnread(int count) {
    if (mounted && count != _chatUnread) setState(() => _chatUnread = count);
  }

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final compact = AppSettings.instance.compactNav;
    final accentColor = Theme.of(context).colorScheme.primary;
    final themeKey = AppSettings.instance.themeColor.name;
    final desktop = isDesktop(context);

    final tabs = [
      _ChatsTab(onUnreadChanged: updateChatUnread),
      const _CommunityTab(),
      const _SettingsTab(),
    ];

    if (desktop) {
      return Scaffold(
        body: Row(
          children: [
            // Боковая навигация с лейблами
            Container(
              width: 200,
              color: AppTheme.surface,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Text('Skryvex', style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                    const Divider(color: AppTheme.divider, height: 1),
                    const SizedBox(height: 8),
                    _SidebarItem(icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: 'Чаты', selected: _tab == 0, badge: _chatUnread, onTap: () => setState(() => _tab = 0)),
                    _SidebarItem(icon: Icons.explore_outlined, selectedIcon: Icons.explore, label: 'Сообщество', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                    _SidebarItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Настройки', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1, color: AppTheme.divider),
            // Контент — центрируем с ограничением ширины
            Expanded(
              child: IndexedStack(
                key: ValueKey(themeKey),
                index: _tab,
                children: tabs,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        key: ValueKey(themeKey),
        index: _tab,
        children: tabs,
      ),
      extendBody: true,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            height: compact ? 56 : null,
            backgroundColor: AppTheme.surface,
            indicatorColor: accentColor.withValues(alpha: 0.15),
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelBehavior: compact
                ? NavigationDestinationLabelBehavior.alwaysHide
                : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Badge(isLabelVisible: _chatUnread > 0, label: Text('$_chatUnread'), child: const Icon(Icons.chat_bubble_outline)),
                selectedIcon: Badge(isLabelVisible: _chatUnread > 0, label: Text('$_chatUnread'), child: const Icon(Icons.chat_bubble)),
                label: 'Чаты',
              ),
              const NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Сообщество'),
              const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _NavRailItem({required this.icon, required this.selectedIcon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 52, height: 52,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Icon(selected ? selectedIcon : icon, color: selected ? accent : AppTheme.textSecondary, size: 22),
            if (badge > 0) Positioned(
              top: 8, right: 8,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Center(child: Text('$badge', style: TextStyle(color: AppTheme.bg, fontSize: 9, fontWeight: FontWeight.bold))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;
  const _SidebarItem({required this.icon, required this.selectedIcon, required this.label, required this.selected, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(selected ? selectedIcon : icon, color: selected ? accent : AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: selected ? accent : AppTheme.textSecondary, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.normal))),
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: TextStyle(color: AppTheme.bg, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ]),
      ),
    );
  }
}

// ── Chats tab ──────────────────────────────────────────────────────────────

class _ChatsTab extends StatefulWidget {
  final void Function(int)? onUnreadChanged;
  const _ChatsTab({this.onUnreadChanged});

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
        final chats = data.map((e) => ChatModel.fromJson(e as Map<String, dynamic>)).toList();
        setState(() { _chats = chats; _loading = false; });
        final unread = chats.fold(0, (s, c) => s + c.unreadCount);
        widget.onUnreadChanged?.call(unread);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final desktop = isDesktop(context);
    Widget listBody = _loading
        ? Center(child: CircularProgressIndicator(color: AppTheme.orange))
        : _chats.isEmpty
            ? _empty()
            : RefreshIndicator(
                color: AppTheme.orange,
                backgroundColor: AppTheme.surface,
                onRefresh: () => _loadChats(forceRefresh: true),
                child: ListView.separated(
                  padding: EdgeInsets.only(bottom: desktop ? 24 : 80),
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
                            partnerAvatar: _chats[i].partnerAvatar,
                            isSelf: _chats[i].isSelf,
                          ),
                        ),
                      );
                      _loadChats();
                    },
                  ),
                ),
              );

    if (desktop) {
      listBody = Center(child: SizedBox(width: 680, child: listBody));
    }

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
      body: listBody,
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
    final accent = Theme.of(context).colorScheme.primary;

    final leading = chat.isSelf
        ? CircleAvatar(
            radius: 24,
            backgroundColor: accent.withValues(alpha: 0.15),
            child: Icon(Icons.bookmark, color: accent, size: 22),
          )
        : _Avatar(name: chat.partnerName, url: chat.partnerAvatar, cacheKey: 'avatar_${chat.partnerId}');

    final title = chat.isSelf ? 'Избранное' : chat.partnerName;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: leading,
      title: Text(title,
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
  final String? cacheKey;
  const _Avatar({required this.name, this.url, this.cacheKey});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppTheme.surfaceVariant,
      backgroundImage: url != null
          ? CachedNetworkImageProvider(url!, cacheKey: cacheKey ?? url)
          : null,
      child: url == null
          ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: AppTheme.orange, fontWeight: FontWeight.w600))
          : null,
    );
  }
}

// ── Community tab ──────────────────────────────────────────────────────────

class _CommunityTab extends StatefulWidget {
  const _CommunityTab();

  @override
  State<_CommunityTab> createState() => _CommunityTabState();
}

class _CommunityTabState extends State<_CommunityTab> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tabCtrl;
  List<ChannelModel> _subscribed = [];
  List<ChannelModel> _discover = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() { if (!_tabCtrl.indexIsChanging) setState(() {}); });
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.get('/channels/subscribed'),
        ApiService.get('/channels'),
      ]);
      if (!mounted) return;
      setState(() {
        _subscribed = (results[0] as List).map((e) => ChannelModel.fromJson(e as Map<String, dynamic>)).toList();
        _discover = (results[1] as List).map((e) => ChannelModel.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSubscribe(ChannelModel ch) async {
    if (ch.subscribed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Отписаться?', style: TextStyle(color: AppTheme.textPrimary)),
          content: Text('Вы больше не будете получать посты от @${ch.username}', style: const TextStyle(color: AppTheme.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отписаться', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      );
      if (ok != true) return;
      await ApiService.delete('/channels/${ch.id}/subscribe');
    } else {
      await ApiService.post('/channels/${ch.id}/subscribe', {});
    }
    _load();
  }

  Future<void> _openChannel(ChannelModel ch) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelScreen(channel: ch)));
    _load();
  }

  int get _totalUnread => _subscribed.fold(0, (s, c) => s + c.unreadCount);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final accent = Theme.of(context).colorScheme.primary;
    final isCatalog = _tabCtrl.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщество'),
        actions: [
          if (isCatalog)
            IconButton(icon: Icon(Icons.search, color: accent), onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => _ChannelSearchScreen(onOpen: _openChannel, onSubscribe: _toggleSubscribe)));
              _load();
            })
          else
            IconButton(
              icon: Icon(Icons.add, color: accent),
              onPressed: () async {
                final ch = await Navigator.push<ChannelModel>(context, MaterialPageRoute(builder: (_) => const CreateChannelScreen()));
                if (ch != null) _load();
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            height: 40,
            width: isDesktop(context) ? 280 : double.infinity,
            decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabCtrl,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppTheme.bg,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
              tabs: [
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Мои каналы'),
                  if (_totalUnread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.bg.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                      child: Text('$_totalUnread', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ])),
                const Tab(text: 'Каталог'),
              ],
            ),
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : TabBarView(controller: _tabCtrl, children: [
              RefreshIndicator(
                color: accent, backgroundColor: AppTheme.surface,
                onRefresh: _load,
                child: _subscribed.isEmpty
                    ? _empty('Вы не подписаны ни на один канал', 'Найдите каналы во вкладке «Каталог»')
                    : _desktopWrap(ListView.separated(
                        padding: EdgeInsets.only(bottom: isDesktop(context) ? 24 : 80),
                        itemCount: _subscribed.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: AppTheme.divider),
                        itemBuilder: (_, i) => _ChannelTile(channel: _subscribed[i], onTap: () => _openChannel(_subscribed[i]), onSubscribe: () => _toggleSubscribe(_subscribed[i])),
                      )),
              ),
              RefreshIndicator(
                color: accent, backgroundColor: AppTheme.surface,
                onRefresh: _load,
                child: _discover.isEmpty
                    ? _empty('Каналов пока нет', 'Создайте первый канал!')
                    : _desktopWrap(ListView.separated(
                        padding: EdgeInsets.only(bottom: isDesktop(context) ? 24 : 80),
                        itemCount: _discover.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: AppTheme.divider),
                        itemBuilder: (_, i) => _ChannelTile(channel: _discover[i], onTap: () => _openChannel(_discover[i]), onSubscribe: () => _toggleSubscribe(_discover[i])),
                      )),
              ),
            ]),
    );
  }

  Widget _desktopWrap(Widget child) {
    if (!isDesktop(context)) return child;
    return Center(child: SizedBox(width: 680, child: child));
  }

  Widget _empty(String title, String sub) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.explore_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
    const SizedBox(height: 16),
    Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
    const SizedBox(height: 8),
    Text(sub, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13)),
  ]));
}

class _ChannelTile extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  const _ChannelTile({required this.channel, required this.onTap, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24, backgroundColor: AppTheme.surfaceVariant,
        backgroundImage: channel.avatarUrl != null
            ? CachedNetworkImageProvider(channel.avatarUrl!, cacheKey: 'ch_avatar_${channel.id}')
            : null,
        child: channel.avatarUrl == null
            ? Text(channel.name[0].toUpperCase(), style: TextStyle(color: accent, fontWeight: FontWeight.w600))
            : null,
      ),
      title: Text(channel.name, style: TextStyle(color: AppTheme.textPrimary, fontWeight: channel.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal)),
      subtitle: Text('@${channel.username} · ${channel.subscriberCount} подписчиков',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (channel.unreadCount > 0)
          Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(10)),
            child: Text('${channel.unreadCount}', style: TextStyle(color: AppTheme.bg, fontSize: 12, fontWeight: FontWeight.w600))),
        GestureDetector(
          onTap: onSubscribe,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: channel.subscribed ? AppTheme.surfaceVariant : accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(channel.subscribed ? 'Подписан' : 'Подписаться',
                style: TextStyle(color: channel.subscribed ? AppTheme.textSecondary : AppTheme.bg, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

// ── Channel search screen ──────────────────────────────────────────────────

class _ChannelSearchScreen extends StatefulWidget {
  final Future<void> Function(ChannelModel) onOpen;
  final Future<void> Function(ChannelModel) onSubscribe;
  const _ChannelSearchScreen({required this.onOpen, required this.onSubscribe});

  @override
  State<_ChannelSearchScreen> createState() => _ChannelSearchScreenState();
}

class _ChannelSearchScreenState extends State<_ChannelSearchScreen> {
  final _ctrl = TextEditingController();
  List<ChannelModel> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); _ctrl.dispose(); super.dispose(); }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) { setState(() => _results = []); return; }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loading = true);
      try {
        final data = await ApiService.get('/channels/search?q=${Uri.encodeComponent(q)}') as List;
        if (mounted) setState(() { _results = data.map((e) => ChannelModel.fromJson(e as Map<String, dynamic>)).toList(); _loading = false; });
      } catch (_) { if (mounted) setState(() => _loading = false); }
    });
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
            hintText: 'Поиск каналов...',
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
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, color: AppTheme.divider),
              itemBuilder: (_, i) => _ChannelTile(
                channel: _results[i],
                onTap: () => widget.onOpen(_results[i]),
                onSubscribe: () async {
                  await widget.onSubscribe(_results[i]);
                  _search(_ctrl.text);
                },
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
    final list = ListView(
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: Icon(Icons.person_outline, color: AppTheme.orange),
          title: const Text('Аккаунт', style: TextStyle(color: AppTheme.textPrimary)),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        ),
        const Divider(height: 1, indent: 16, color: AppTheme.divider),
        ListTile(
          leading: Icon(Icons.palette_outlined, color: AppTheme.orange),
          title: const Text('Кастомизация', style: TextStyle(color: AppTheme.textPrimary)),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomizationScreen())),
        ),
        const Divider(height: 1, indent: 16, color: AppTheme.divider),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.redAccent)),
          onTap: () => _logout(context),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: isDesktop(context)
          ? Center(child: SizedBox(width: 520, child: list))
          : list,
    );
  }
}
