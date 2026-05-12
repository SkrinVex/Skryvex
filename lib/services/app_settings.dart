import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  bool _compactNav = false;
  ThemeColor _themeColor = ThemeColor.orange;

  bool get compactNav => _compactNav;
  ThemeColor get themeColor => _themeColor;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _compactNav = prefs.getBool('compact_nav') ?? false;
    final colorName = prefs.getString('theme_color') ?? 'orange';
    _themeColor = ThemeColor.values.firstWhere(
      (c) => c.name == colorName,
      orElse: () => ThemeColor.orange,
    );
    notifyListeners();
  }

  Future<void> setCompactNav(bool value) async {
    _compactNav = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('compact_nav', value);
  }

  Future<void> setThemeColor(ThemeColor color) async {
    _themeColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_color', color.name);
  }
}

enum ThemeColor {
  orange(Color(0xFFE8A87C), 'Оранжевый'),
  pink(Color(0xFFE8A0B8), 'Розовый'),
  purple(Color(0xFFC4A8E8), 'Фиолетовый'),
  red(Color(0xFFE89090), 'Красный'),
  blue(Color(0xFFA8C8E8), 'Синий'),
  green(Color(0xFFB8E8A8), 'Зелёный');

  final Color color;
  final String label;
  const ThemeColor(this.color, this.label);

  Color get dim => Color.lerp(color, const Color(0xFF000000), 0.3)!;
}
