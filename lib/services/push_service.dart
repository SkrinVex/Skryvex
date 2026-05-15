import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_notifications.dart';

/// Payload из FCM data-only сообщения, ожидающий обработки навигации.
/// Устанавливается при cold-start до того, как виджет зарегистрировал onTap.
String? pendingNavigationPayload;

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // Data-only сообщение: приложение в фоне/закрыто — показываем уведомление сами
  await Firebase.initializeApp();
  await LocalNotifications.instance.init();
  final data = message.data;
  final title = data['title'] as String?;
  final body = data['body'] as String?;
  final payload = data['payload'] as String?;
  if (title != null && body != null && payload != null) {
    await LocalNotifications.instance.show(
      title: title,
      body: body,
      payload: payload,
      avatarUrl: data['avatarUrl'] as String?,
      senderName: _isSenderNameNeeded(payload, data) ? data['senderName'] as String? : null,
    );
  }
}

bool _isSenderNameNeeded(String payload, Map<String, dynamic> data) {
  return payload.startsWith('group:') && data['senderName'] != null;
}

class PushService {
  PushService._();
  static final instance = PushService._();

  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_bgHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      messaging.onTokenRefresh.listen(_register);

      // Foreground: data-only сообщения не показываются FCM автоматически — показываем сами
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      // Тап когда приложение было в фоне (не закрыто)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      // Тап когда приложение было закрыто (cold start)
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleMessage(initial);
    } catch (e) {
      debugPrint('[PushService] $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final data = message.data;
    final title = data['title'] as String?;
    final body = data['body'] as String?;
    final payload = data['payload'] as String?;
    if (title == null || body == null || payload == null) return;
    LocalNotifications.instance.show(
      title: title,
      body: body,
      payload: payload,
      avatarUrl: data['avatarUrl'] as String?,
      senderName: _isSenderNameNeeded(payload, data) ? data['senderName'] as String? : null,
    );
  }

  void _handleMessage(RemoteMessage message) {
    final payload = message.data['payload'] as String?;
    if (payload == null) return;
    if (LocalNotifications.instance.onTap != null) {
      LocalNotifications.instance.onTap!(payload);
    } else {
      // onTap ещё не зарегистрирован (cold start) — сохраняем для последующей обработки
      pendingNavigationPayload = payload;
    }
  }

  Future<void> deleteToken() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
    } catch (_) {}
  }

  Future<void> _register(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('fcm_token') == token) return;
      await ApiService.post('/auth/me/fcm-token', {'token': token, 'platform': 'android'}, auth: true);
      await prefs.setString('fcm_token', token);
    } catch (_) {}
  }
}
