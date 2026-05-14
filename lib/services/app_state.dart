import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppState extends ChangeNotifier {
  static final instance = AppState._();
  AppState._();

  bool _maintenance = false;
  bool _banned = false;
  bool _restricted = false;
  String? _banReason;

  bool get maintenance => _maintenance;
  bool get banned => _banned;
  bool get restricted => _restricted;
  String? get banReason => _banReason;

  Future<bool> checkHealth() async {
    try {
      final res = await http.get(
        Uri.parse('https://api.skrinvex.su/api/health'),
      ).timeout(const Duration(seconds: 8));
      bool ok = false;
      if (res.statusCode == 200) {
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          ok = data['status'] == 'ok';
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

  void clearAccountFlags() {
    _banned = false;
    _restricted = false;
    _banReason = null;
    notifyListeners();
  }
}
