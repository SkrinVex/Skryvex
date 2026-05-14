import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app_links/app_links.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/group_invite_screen.dart';
import 'screens/channel_invite_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/update_screen.dart';
import 'services/app_settings.dart';
import 'services/app_state.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppSettings.instance.load();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final info = await PackageInfo.fromPlatform();
  final healthy = await AppState.instance.checkHealth(currentVersion: info.version);
  runApp(SkryvexApp(
    initialRoute: (!healthy || token == null) ? '/login' : '/home',
  ));
}

class SkryvexApp extends StatefulWidget {
  final String initialRoute;
  const SkryvexApp({super.key, required this.initialRoute});

  @override
  State<SkryvexApp> createState() => _SkryvexAppState();
}

class _SkryvexAppState extends State<SkryvexApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_rebuild);
    AppState.instance.addListener(_rebuild);
    _initDeepLinks();
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleLink(uri));
      }
    });
  }

  void _handleLink(Uri uri) {
    String? inviteCode;
    String? channelCode;

    if (uri.scheme == 'https' && uri.host == 'api.skrinvex.su' && uri.pathSegments.length == 2) {
      if (uri.pathSegments[0] == 'invite') inviteCode = uri.pathSegments[1];
      else if (uri.pathSegments[0] == 'channel') channelCode = uri.pathSegments[1];
    } else if (uri.scheme == 'skryvex' && uri.pathSegments.isNotEmpty) {
      if (uri.host == 'invite') inviteCode = uri.pathSegments[0];
      else if (uri.host == 'channel') channelCode = uri.pathSegments[0];
      else if (uri.host == 'user') {
        final id = uri.pathSegments[0];
        _navKey.currentState?.push(MaterialPageRoute(builder: (_) => UserProfileScreen(userId: int.tryParse(id), username: int.tryParse(id) == null ? id : null)));
        return;
      }
    }

    if (inviteCode != null) {
      final code = inviteCode;
      _navKey.currentState?.push(MaterialPageRoute(builder: (_) => GroupInviteScreen(inviteCode: code)));
    } else if (channelCode != null) {
      final code = channelCode;
      _navKey.currentState?.push(MaterialPageRoute(builder: (_) => ChannelInviteScreen(inviteCode: code)));
    }
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_rebuild);
    AppState.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final state = AppState.instance;
    final color = settings.themeColor;

    return MaterialApp(
      title: 'Skryvex',
      navigatorKey: _navKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(color.color, color.dim),
      initialRoute: widget.initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
      onGenerateRoute: (s) {
        final uri = Uri.tryParse(s.name ?? '');
        if (uri != null && uri.pathSegments.length == 2) {
          if (uri.pathSegments[0] == 'invite') return MaterialPageRoute(builder: (_) => GroupInviteScreen(inviteCode: uri.pathSegments[1]));
          if (uri.pathSegments[0] == 'channel') return MaterialPageRoute(builder: (_) => ChannelInviteScreen(inviteCode: uri.pathSegments[1]));
          if (uri.pathSegments[0] == 'u') {
            final id = uri.pathSegments[1];
            return MaterialPageRoute(builder: (_) => UserProfileScreen(userId: int.tryParse(id), username: int.tryParse(id) == null ? id : null));
          }
        }
        return null;
      },
      builder: (context, child) {
        // Maintenance overlay — поверх всего
        if (state.maintenance) {
          return const _MaintenanceScreen();
        }
        // Требуется обновление
        if (state.updateRequired) {
          return const UpdateScreen();
        }
        // Restricted — тот же экран что и maintenance (доступ закрыт, но без retry)
        if (state.restricted) {
          return _MaintenanceScreen(
            title: 'Доступ ограничен',
            message: 'Доступ к вашему аккаунту временно ограничен администратором.',
            icon: Icons.lock_outline_rounded,
            showRetry: false,
            onLogout: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user');
              state.clearAccountFlags();
              _navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
            },
          );
        }
        // Banned — экран с причиной и кнопкой выйти
        if (state.banned) {
          return _AccountBannedScreen(
            reason: state.banReason,
            onDismiss: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('token');
              await prefs.remove('user');
              state.clearAccountFlags();
              _navKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
            },
          );
        }
        return child!;
      },
    );
  }
}

class _MaintenanceScreen extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final bool showRetry;
  final VoidCallback? onLogout;

  const _MaintenanceScreen({
    this.title = 'Сервис недоступен',
    this.message = 'Ведутся технические работы.\nПопробуйте позже.',
    this.icon = Icons.cloud_off_rounded,
    this.showRetry = true,
    this.onLogout,
  });

  @override
  State<_MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<_MaintenanceScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    await AppState.instance.checkHealth();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 64, color: AppTheme.textSecondary),
              const SizedBox(height: 20),
              Text(widget.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(widget.message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 28),
              if (widget.showRetry)
                _checking
                    ? CircularProgressIndicator(color: AppTheme.orange)
                    : ElevatedButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('Повторить')),
              if (widget.onLogout != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: widget.onLogout, child: const Text('Выйти из аккаунта', style: TextStyle(color: AppTheme.textSecondary))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountBannedScreen extends StatelessWidget {
  final String? reason;
  final VoidCallback onDismiss;
  const _AccountBannedScreen({required this.onDismiss, this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text('Аккаунт заблокирован', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Ваш аккаунт был заблокирован администратором.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              if (reason != null && reason!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('Причина: $reason', textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('Выйти из аккаунта'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
