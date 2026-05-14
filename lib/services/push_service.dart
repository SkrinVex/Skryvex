import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage _) async {}

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

      // Тап на уведомление когда приложение открыто (foreground)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      // Тап когда приложение было закрыто
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleMessage(initial);
    } catch (e) {
      debugPrint('[PushService] $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    final payload = message.data['payload'] as String?;
    if (payload != null) {
      LocalNotifications.instance.onTap?.call(payload);
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
