import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app_links/app_links.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/group_invite_screen.dart';
import 'screens/channel_invite_screen.dart';
import 'screens/user_profile_screen.dart';
import 'services/app_settings.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppSettings.instance.load();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  runApp(SkryvexApp(initialRoute: token != null ? '/home' : '/login'));
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
    _initDeepLinks();
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
    // getInitialLink срабатывает до готовности навигатора — откладываем
    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleLink(uri));
      }
    });
  }

  void _handleLink(Uri uri) {
    // Группы: https://api.skrinvex.su/invite/:code  или  skryvex://invite/:code
    // Каналы: https://api.skrinvex.su/channel/:code  или  skryvex://channel/:code
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
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
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
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && uri.pathSegments.length == 2) {
          if (uri.pathSegments[0] == 'invite') {
            return MaterialPageRoute(builder: (_) => GroupInviteScreen(inviteCode: uri.pathSegments[1]));
          }
          if (uri.pathSegments[0] == 'channel') {
            return MaterialPageRoute(builder: (_) => ChannelInviteScreen(inviteCode: uri.pathSegments[1]));
          }
          if (uri.pathSegments[0] == 'u') {
            final id = uri.pathSegments[1];
            return MaterialPageRoute(builder: (_) => UserProfileScreen(
              userId: int.tryParse(id),
              username: int.tryParse(id) == null ? id : null,
            ));
          }
        }
        return null;
      },
    );
  }
}
