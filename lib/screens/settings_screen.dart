// screens/settings_screen.dart
import '../utils/local_storage_util.dart';
import '../main.dart';
import 'community_screen.dart';
import 'activities_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

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

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogoutSuccess;
  const SettingsScreen({super.key, required this.onLogoutSuccess});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    checkTokenExp();
    _loadThemePreference();
  }

  void checkTokenExp() async {
    // Check if the token is still valid, if not, redirect to login page;
    void checkToken() async {
      final authData = await LocalStorageUtil.getAuthData();
      final tokenExp = authData['tokenExp'];

      if (tokenExp == null) {
        // No expiration info, redirect to login
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final expiration = int.tryParse(tokenExp);
      if (expiration == null) {
        Navigator.pushReplacementNamed(context, '/');
        return;
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (now >= expiration) {
        widget.onLogoutSuccess();
      }
    }
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() {
      _isDarkMode = value;
    });

    // Trigger a rebuild of the app with new theme
    final brightness = value ? ThemeMode.dark : ThemeMode.light;
    MyApp.of(context).setThemeMode(brightness);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontFamily: 'Handler',
                fontSize: 45.0,
              ),
            ),
            Icon(
              Icons.settings,
              size: 45.0,
            ),
          ]
      )),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: _isDarkMode,
            onChanged: _toggleDarkMode,
            secondary: const Icon(Icons.dark_mode),
          ),
        ],
      ),
    );
  }
}