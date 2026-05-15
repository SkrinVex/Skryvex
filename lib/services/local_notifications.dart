import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

typedef NotificationTapCallback = void Function(String payload);

class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationTapCallback? onTap;

  static bool get _supported => !kIsWeb && (Platform.isLinux || Platform.isAndroid);

  Future<void> init({NotificationTapCallback? onTap}) async {
    if (!_supported) return;
    if (onTap != null) this.onTap = onTap;
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: LinuxInitializationSettings(defaultActionName: 'Открыть'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) this.onTap?.call(r.payload!);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );
    _initialized = true;
  }

  Future<void> show({
    required String title,
    required String body,
    required String payload,
    String? avatarUrl,
    String? senderName, // только для групп: имя отправителя
  }) async {
    if (!_supported || !_initialized) return;

    Uint8List? avatarBytes;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(avatarUrl)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) avatarBytes = res.bodyBytes;
      } catch (_) {}
    }

    final largeIcon = avatarBytes != null ? ByteArrayAndroidBitmap(avatarBytes) : null;
    final senderIcon = avatarBytes != null ? ByteArrayAndroidIcon(avatarBytes) : null;

    final androidDetails = AndroidNotificationDetails(
      'messages', 'Сообщения',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: largeIcon,
      styleInformation: MessagingStyleInformation(
        const Person(name: 'Вы'),
        conversationTitle: title,
        groupConversation: senderName != null,
        messages: [
          Message(
            body,
            DateTime.now(),
            Person(name: senderName ?? title, icon: senderIcon),
          ),
        ],
      ),
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        linux: const LinuxNotificationDetails(),
      ),
      payload: payload,
    );
  }
}

@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse response) {
  // Handled when app resumes via onDidReceiveNotificationResponse
}
