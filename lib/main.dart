import 'package:flutter/material.dart';
import 'screens/login_register_screen.dart';
import 'screens/home_screen.dart';
import 'utils/local_storage_util.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
//TODO: guardar na base de dados local "util" o user id, token id e expiration date do token

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>()!;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;
  bool _isCheckingLogin = true;

  ThemeMode _themeMode = ThemeMode.light;

  Timer? _logoutTimer;

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
  }

  void setThemeMode(ThemeMode mode) {
    saveThemeMode(mode);
    setState(() {
      _themeMode = mode;
    });
  }

  void _onLoginSuccess() async {
    await _checkStoredToken();
    setState(() =>
      _isLoggedIn = true
    );
  }

  void _onLogoutSuccess() async {
    _logoutTimer?.cancel();
    await LocalStorageUtil.clearAuthData(); // Clear the data of the user using the app
    setState(() {
      _isLoggedIn = false;
    });
  }

  // Checks if the token of the user is still valid
  // Set the log in as true to skip the login screen
  Future<void> _checkStoredToken() async {
    final data = await LocalStorageUtil.getAuthData();
    final token = data['tokenID'];
    final exp = data['tokenExp'];

    if (token != null && exp != null) {
      try {
        final expiryDate = DateTime.fromMillisecondsSinceEpoch(int.parse(exp) * 1000);
        final now = DateTime.now();

        if (expiryDate.isAfter(now)) {
          _startAutoLogoutTimer(expiryDate);
          _isLoggedIn = true;
        }
      } catch (e) {
        print("Error validating JWT: $e");
      }
    }

    setState(() => _isCheckingLogin = false);
  }

  void _startAutoLogoutTimer(DateTime expiryDate) {
    final now = DateTime.now();
    final duration = expiryDate.difference(now);

    _logoutTimer?.cancel(); // Clear any existing timer
    _logoutTimer = Timer(duration, () {
      _onLogoutSuccess();
      _showSessionExpiredDialog();
    });
  }

  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Session Expired"),
        content: const Text("Your session has expired. Please log in again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkStoredToken();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? ThemeMode.system.index;
    setThemeMode(ThemeMode.values[themeIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: _isCheckingLogin
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _isLoggedIn
            ? HomeScreen(onLogoutSuccess: _onLogoutSuccess)
            : LoginRegisterScreen(onLoginSuccess: _onLoginSuccess),
    );
  }
}