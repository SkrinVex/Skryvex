import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Простой кэш на SharedPreferences с TTL
class CacheService {
  static const _chatsTtl = Duration(minutes: 5);
  static const _messagesTtl = Duration(minutes: 2);

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> _set(String key, dynamic data, Duration ttl) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode({
      'data': data,
      'expires': DateTime.now().add(ttl).millisecondsSinceEpoch,
    }));
  }

  static Future<dynamic> _get(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (DateTime.now().millisecondsSinceEpoch > (map['expires'] as int)) {
      await prefs.remove(key);
      return null;
    }
    return map['data'];
  }

  // Чаты
  static Future<void> saveChats(List<dynamic> chats) =>
      _set('cache_chats', chats, _chatsTtl);

  static Future<List<dynamic>?> loadChats() async {
    final data = await _get('cache_chats');
    return data != null ? List<dynamic>.from(data as List) : null;
  }

  static Future<void> invalidateChats() async {
    final prefs = await _prefs;
    await prefs.remove('cache_chats');
  }

  // Сообщения
  static Future<void> saveMessages(int chatId, List<dynamic> messages) =>
      _set('cache_messages_$chatId', messages, _messagesTtl);

  static Future<List<dynamic>?> loadMessages(int chatId) async {
    final data = await _get('cache_messages_$chatId');
    return data != null ? List<dynamic>.from(data as List) : null;
  }

  static Future<void> invalidateMessages(int chatId) async {
    final prefs = await _prefs;
    await prefs.remove('cache_messages_$chatId');
  }

  // Флаг показа предупреждения о TTL медиа
  static Future<bool> hasShownMediaTtlWarning() async {
    final prefs = await _prefs;
    return prefs.getBool('shown_media_ttl_warning') ?? false;
  }

  static Future<void> setMediaTtlWarningShown() async {
    final prefs = await _prefs;
    await prefs.setBool('shown_media_ttl_warning', true);
  }
}
