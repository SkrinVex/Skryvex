import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Только Linux (и Android как fallback для foreground-пушей)
  static bool get _supported => !kIsWeb && (Platform.isLinux || Platform.isAndroid);

  Future<void> init() async {
    if (!_supported || _initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> show({required String title, required String body}) async {
    if (!_supported || !_initialized) return;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages', 'Сообщения',
          importance: Importance.high,
          priority: Priority.high,
        ),
        linux: LinuxNotificationDetails(),
      ),
    );
  }
}
