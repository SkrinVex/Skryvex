import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  runApp(SkryvexApp(initialRoute: token != null ? '/home' : '/login'));
}

class SkryvexApp extends StatelessWidget {
  final String initialRoute;
  const SkryvexApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skryvex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: initialRoute,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
