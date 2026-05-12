import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const _base = 'https://api.skrinvex.su/api';
  static const baseUrl = 'https://api.skrinvex.su/api';
  static const wsBase = 'wss://api.skrinvex.su/ws';

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final t = prefs.getString('token');
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(auth: auth),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<dynamic> get(String path) async {
    final res = await http.get(
      Uri.parse('$_base$path'),
      headers: await _headers(),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(
      Uri.parse('$_base$path'),
      headers: await _headers(),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> uploadFile(
    String path,
    Uint8List bytes,
    String filename,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final dio = Dio();
    final resp = await dio.post(
      '$_base$path',
      data: FormData.fromMap({'avatar': MultipartFile.fromBytes(bytes, filename: filename)}),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return resp.data as Map<String, dynamic>;
  }
}
