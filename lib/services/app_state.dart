import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppState extends ChangeNotifier {
  static final instance = AppState._();
  AppState._();

  bool _maintenance = false;
  bool _banned = false;
  bool _restricted = false;
  bool _updateRequired = false;
  String? _banReason;

  bool get maintenance => _maintenance;
  bool get banned => _banned;
  bool get restricted => _restricted;
  bool get updateRequired => _updateRequired;
  String? get banReason => _banReason;

  Future<bool> checkHealth({String? currentVersion}) async {
    try {
      final res = await http.get(
        Uri.parse('https://api.skrinvex.su/api/health'),
      ).timeout(const Duration(seconds: 8));
      bool ok = false;
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          ok = data['status'] == 'ok';
          // Проверка минимальной версии
          if (ok && currentVersion != null && data['min_version'] != null) {
            final minVer = data['min_version'] as String;
            if (_isOutdated(currentVersion, minVer)) {
              _updateRequired = true;
              notifyListeners();
              return true; // сервер доступен, но нужно обновление
            }
          }
        } catch (_) {}
      }
      if (_maintenance != !ok) {
        _maintenance = !ok;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      if (!_maintenance) {
        _maintenance = true;
        notifyListeners();
      }
      return false;
    }
  }

  // Сравнивает версии вида "1.2.3"
  bool _isOutdated(String current, String minimum) {
    final c = current.split('.').map(int.tryParse).toList();
    final m = minimum.split('.').map(int.tryParse).toList();
    for (var i = 0; i < m.length; i++) {
      final cv = i < c.length ? (c[i] ?? 0) : 0;
      final mv = m[i] ?? 0;
      if (cv < mv) return true;
      if (cv > mv) return false;
    }
    return false;
  }

  void setBanned({String? reason}) {
    if (!_banned || _banReason != reason) {
      _banned = true;
      _banReason = reason;
      notifyListeners();
    }
  }

  void setRestricted() {
    if (!_restricted) { _restricted = true; notifyListeners(); }
  }

  void clearUpdateRequired() {
    if (_updateRequired) { _updateRequired = false; notifyListeners(); }
  }

  void setUpdateRequired() {
    if (!_updateRequired) { _updateRequired = true; notifyListeners(); }
  }

  void clearAccountFlags() {
    _banned = false;
    _restricted = false;
    _banReason = null;
    notifyListeners();
  }
}
