import 'package:flutter/material.dart';
import 'screens/login_register_screen.dart';
import 'screens/home_screen.dart';
import 'utils/local_storage_util.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  void setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  void _onLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogoutSuccess() async {
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
        bool isExpired = Jwt.isExpired(token);
        if (!isExpired) {
          setState(() {
            _isLoggedIn = true; // Directs user to HomeScreen
          });
        }
      } catch (e) {
        print("JWT validation failed: $e");
      }
    }

    setState(() {
      _isCheckingLogin = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkStoredToken();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? false;
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
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