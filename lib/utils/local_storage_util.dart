import 'package:shared_preferences/shared_preferences.dart';

// Saves locally the four fields of the current user in use
class LocalStorageUtil {
  static Future<void> saveAuthData({
    required String tokenID,
    required String tokenExp,
    required String userRole,
    required String userID,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tokenID', tokenID);
    await prefs.setString('tokenExp', tokenExp);
    await prefs.setString('userRole', userRole);
    await prefs.setString('userID', userID);
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokenID');
    await prefs.remove('tokenExp');
    await prefs.remove('userRole');
    await prefs.remove('userID');
  }

  static Future<Map<String, String?>> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tokenID': prefs.getString('tokenID'),
      'tokenExp': prefs.getString('tokenExp'),
      'userRole': prefs.getString('userRole'),
      'userID': prefs.getString('userID'),
    };
  }
}
