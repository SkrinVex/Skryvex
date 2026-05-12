import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
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
    final settings = AppSettings.instance;
    final color = settings.themeColor;
    return MaterialApp(
      title: 'Skryvex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(color.color, color.dim),
      initialRoute: widget.initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
