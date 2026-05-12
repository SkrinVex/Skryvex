import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../theme.dart';
import 'adaptive_layout.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Кастомизация')),
      body: isDesktop(context)
          ? Center(child: SizedBox(width: 520, child: _buildList(settings, accentColor)))
          : _buildList(settings, accentColor),
    );
  }

  Widget _buildList(AppSettings settings, Color accentColor) => ListView(
        children: [
          const SizedBox(height: 8),
          // Компактная навигация
          SwitchListTile(
            value: settings.compactNav,
            onChanged: (v) {
              settings.setCompactNav(v);
              setState(() {});
            },
            title: const Text('Компактная навигация', style: TextStyle(color: AppTheme.textPrimary)),
            subtitle: const Text('Скрыть подписи на панели навигации', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            activeThumbColor: accentColor,
          ),
          const Divider(height: 1, indent: 16, color: AppTheme.divider),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('Цветовая тема', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          // Цвета
          ...ThemeColor.values.map((color) {
            final selected = settings.themeColor == color;
            return ListTile(
              onTap: () => settings.setThemeColor(color),
              leading: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.color,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: Colors.white, width: 2) : null,
                ),
              ),
              title: Text(color.label, style: const TextStyle(color: AppTheme.textPrimary)),
              trailing: selected ? Icon(Icons.check, color: accentColor) : null,
            );
          }),
        ],
      );
}
