import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:app_links/app_links.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/group_invite_screen.dart';
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
    String? inviteCode;
    if (uri.scheme == 'https' && uri.host == 'api.skrinvex.su' &&
        uri.pathSegments.length == 2 && uri.pathSegments[0] == 'invite') {
      inviteCode = uri.pathSegments[1];
    } else if (uri.scheme == 'skryvex' && uri.host == 'invite' && uri.pathSegments.isNotEmpty) {
      inviteCode = uri.pathSegments[0];
    }
    if (inviteCode == null) return;
    final code = inviteCode;
    // push поверх текущего стека — чтобы назад возвращало на HomeScreen, а не выходило из приложения
    _navKey.currentState?.push(MaterialPageRoute(
      builder: (_) => GroupInviteScreen(inviteCode: code),
    ));
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
        if (uri != null && uri.pathSegments.length == 2 && uri.pathSegments[0] == 'invite') {
          return MaterialPageRoute(builder: (_) => GroupInviteScreen(inviteCode: uri.pathSegments[1]));
        }
        return null;
      },
    );
  }
}
