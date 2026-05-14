import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// Payload для навигации: "chat:123", "group:456", "channel:789"
typedef NotificationTapCallback = void Function(String payload);

class LocalNotifications {
  LocalNotifications._();
  static final instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationTapCallback? onTap;

  static bool get _supported => !kIsWeb && (Platform.isLinux || Platform.isAndroid);

  Future<void> init({NotificationTapCallback? onTap}) async {
    if (!_supported || _initialized) return;
    this.onTap = onTap;
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: const LinuxInitializationSettings(defaultActionName: 'Открыть'),
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null) this.onTap?.call(r.payload!);
      },
    );
    _initialized = true;
  }

  Future<void> show({
    required String title,
    required String body,
    required String payload,
    String? avatarUrl,
  }) async {
    if (!_supported || !_initialized) return;

    Uint8List? avatarBytes;
    if (avatarUrl != null) {
      try {
        final res = await http.get(Uri.parse(avatarUrl)).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) avatarBytes = res.bodyBytes;
      } catch (_) {}
    }

    final androidDetails = AndroidNotificationDetails(
      'messages', 'Сообщения',
      importance: Importance.high,
      priority: Priority.high,
      largeIcon: avatarBytes != null ? ByteArrayAndroidBitmap(avatarBytes) : null,
      styleInformation: avatarBytes != null
          ? BigPictureStyleInformation(ByteArrayAndroidBitmap(avatarBytes), hideExpandedLargeIcon: true)
          : null,
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
