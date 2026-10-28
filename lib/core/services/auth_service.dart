import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agency_head/core/network/api_service.dart';

class AuthService {
  static const String _userKey = 'user_data';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userKey);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Try unified login endpoint (POST api/login) which handles all roles (1, 2, 4, 5, 6)
      Map<String, dynamic> response;
      try {
        response = await ApiService.login(email, password);
      } catch (_) {
        // Fallback to manager_login
        response = await ApiService.managerLogin(email, password);
      }

      if (response['status'] == true && response['data'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(response['data']));
      }
      return response;
    } catch (e) {
      return {'status': false, 'message': 'Login failed: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
